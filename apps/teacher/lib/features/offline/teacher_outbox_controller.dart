import 'dart:async';
import 'package:flutter/widgets.dart';
import '../session/attendance_draft_queue.dart';

import 'package:edaya_api_client/edaya_api_client.dart';
import 'package:edaya_shared/edaya_shared.dart';
import 'package:levit_flutter/levit_flutter.dart';

class TeacherOutboxController extends LevitController
    with LevitReactiveTasksMixin, WidgetsBindingObserver {
  TeacherOutboxController({
    required TeacherOutboxStore outboxStore,
    required SchoolClientFactory schoolClient,
    TeacherOutboxContext? Function()? context,
    this.connections,
    this.scopedClient,
  }) : _outboxStore = outboxStore,
       _schoolClient = schoolClient,
       _context = context;

  final TeacherOutboxStore _outboxStore;
  final SchoolClientFactory _schoolClient;
  final TeacherOutboxContext? Function()? _context;

  final Stream<bool>? connections;
  final SchoolClient Function(TeacherOutboxContext context)? scopedClient;
  final registers =
      <
        AttendanceDraftQueue,
        ({String Function() id, Future<void> Function() refresh})
      >{};
  Future<void> _syncTail = Future.value();
  bool _autoScheduled = false;

  void _autoSync() {
    if (_context?.call() == null || _autoScheduled || isClosed) return;
    _autoScheduled = true;
    unawaited(
      syncPending(
        attendanceOnly: true,
      ).whenComplete(() => _autoScheduled = false),
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _autoSync();
  }

  @override
  void onClose() {
    WidgetsBinding.instance.removeObserver(this);
    registers.clear();
    super.onClose();
  }

  final conflicts = LxVar<List<TeacherOutboxEntry>>(const []);

  final summary = LxVar(const TeacherOutboxSummary(pendingCount: 0));

  @override
  void onInit() {
    super.onInit();
    WidgetsBinding.instance.addObserver(this);
    final subscription = connections?.distinct().listen((online) {
      if (online) _autoSync();
    }, onError: (Object _) {});
    if (subscription != null) autoDispose(subscription);
    autoDispose(summary);
    autoDispose(conflicts);
    unawaited(refreshSummary());
  }

  Future<void> refreshSummary() async {
    _outboxStore.bindContext(_context?.call());
    summary(await _outboxStore.summary());
    conflicts(
      (await _outboxStore.listPending())
          .where((entry) => !teacherOutboxEntryIsReplayable(entry))
          .toList(),
    );
  }

  Future<void> discardConflict(String id) async {
    _outboxStore.bindContext(_context?.call());
    final entries = await _outboxStore.listPending();
    if (!entries.any(
      (entry) => entry.id == id && !teacherOutboxEntryIsReplayable(entry),
    )) {
      return;
    }
    await _outboxStore.remove(id);
    for (final entry in registers.entries.toList()) {
      if (entry.value.id() == id)
        await entry.key.add(() async {
          await entry.value.refresh();
          return true;
        }, active: () => registers.containsKey(entry.key));
    }
    await refreshSummary();
  }

  Future<void> discardPending() async {
    _outboxStore.bindContext(_context?.call());
    await _outboxStore.discardBoundContext();
    await refreshSummary();
  }

  Future<int> syncPending({bool attendanceOnly = false}) {
    final context = _context?.call();
    final task = _syncTail.then((_) async {
      var count = 0;
      await runTask(() async {
        count = await _replay(context, attendanceOnly);
      });
      return count;
    });
    _syncTail = task.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return task;
  }

  Future<int> _replay(
    TeacherOutboxContext? context,
    bool attendanceOnly,
  ) async {
    bool active() =>
        !isClosed &&
        (context == null
            ? _context == null
            : _context?.call()?.matches(context) == true);
    if (!active()) return 0;
    _outboxStore.bindContext(context);
    final pending = await _outboxStore.listPending();
    if (!active()) return 0;
    final client = context != null && scopedClient != null
        ? scopedClient!(context)
        : _schoolClient();
    var count = 0;
    for (final entry in pending) {
      if (!active()) break;
      if (!teacherOutboxEntryMatchesContext(entry, context) ||
          !teacherOutboxEntryIsReplayable(entry))
        continue;
      final body = entry.payload['body'];
      final proposal = body is Map ? body['proposal'] : null;
      if (attendanceOnly &&
          entry.kind != TeacherOutboxKind.attendance &&
          !(proposal is Map && proposal['workflow'] == 'attendance'))
        continue;
      final open = registers.entries
          .where((r) => r.value.id() == entry.id)
          .firstOrNull;
      Future<bool> replay() async {
        if (!active()) return false;
        final latest = (await _outboxStore.listPending())
            .where(
              (r) =>
                  r.id == entry.id &&
                  teacherOutboxEntryMatchesContext(r, context),
            )
            .firstOrNull;
        if (!active() ||
            latest == null ||
            !teacherOutboxEntryIsReplayable(latest))
          return false;
        final saved = await _syncEntry(client, latest, active);
        if (active() &&
            open != null &&
            registers.containsKey(open.key) &&
            open.value.id() == entry.id) {
          if (saved ||
              (await _outboxStore.listPending()).any(
                (r) => r.id == entry.id && !teacherOutboxEntryIsReplayable(r),
              ))
            await open.value.refresh();
        }
        return saved;
      }

      final saved = open == null
          ? await replay()
          : await open.key.add(
              replay,
              active: () => active() && registers.containsKey(open.key),
            );
      if (saved) count++;
    }
    if (active()) await refreshSummary();
    return count;
  }

  Future<bool> _syncEntry(
    SchoolClient client,
    TeacherOutboxEntry entry,
    bool Function() active,
  ) async {
    Future<bool> stillCurrent() async {
      if (!active()) return false;
      final entries = await _outboxStore.listPending();
      return active() &&
          entries.any(
            (e) =>
                e.id == entry.id &&
                e.idempotencyKey == entry.idempotencyKey &&
                (e.payload['body'] as Map?)?['requestId'] ==
                    (entry.payload['body'] as Map?)?['requestId'] &&
                teacherOutboxEntryMatchesContext(e, entry.context),
          );
    }

    await _outboxStore.upsert(
      entry.copyWith(
        state: TeacherOutboxState.syncing,
        updatedAt: DateTime.now(),
      ),
    );

    try {
      await syncTeacherOutboxEntry(client, entry);
      if (!await stillCurrent()) return false;
      await _outboxStore.remove(entry.id);
      return true;
    } on Object catch (error) {
      if (!await stillCurrent()) return false;
      await _outboxStore.upsert(
        entry.copyWith(
          state: isRetryableTeacherWriteFailure(error)
              ? TeacherOutboxState.failed
              : TeacherOutboxState.conflict,
          attemptCount: entry.attemptCount + 1,
          lastError: '$error',
          updatedAt: DateTime.now(),
        ),
      );
      return false;
    }
  }
}
