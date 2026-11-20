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
  int _summaryGeneration = 0;
  TeacherOutboxContext? _summaryContext;

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
    refreshBadge();
  }

  /// Refresh the optional badge without delaying navigation or offline replay.
  void refreshBadge() {
    unawaited(
      refreshSummary().catchError((Object error, StackTrace stack) {
        FlutterError.reportError(
          FlutterErrorDetails(
            exception: error,
            stack: stack,
            library: 'teacher offline queue',
          ),
        );
      }),
    );
  }

  Future<void> refreshSummary() async {
    final generation = ++_summaryGeneration;
    final context = _context?.call();
    final previous = _summaryContext;
    if (context == null
        ? previous != null
        : previous == null || !context.matches(previous)) {
      summary(const TeacherOutboxSummary(pendingCount: 0));
      conflicts(const []);
    }
    _summaryContext = context;
    _outboxStore.bindContext(context);
    final result = await (
      _outboxStore.summary(),
      _outboxStore.listConflicts(),
    ).wait;
    final current = _context?.call();
    if (generation != _summaryGeneration ||
        isClosed ||
        (context == null
            ? current != null
            : current == null || !context.matches(current)))
      return;
    summary(result.$1);
    conflicts(result.$2);
  }

  Future<void> discardConflict(String id) async {
    _outboxStore.bindContext(_context?.call());
    final conflict = await _outboxStore.findEntry(id);
    if (conflict == null ||
        (conflict.state != TeacherOutboxState.conflict &&
            conflict.state != TeacherOutboxState.rejected) ||
        !await _outboxStore.replaceIfCurrent(conflict, null))
      return;
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
    await _outboxStore.prepareReplay();
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
        final latest = await _outboxStore.findEntry(entry.id);
        if (!active() ||
            latest == null ||
            !teacherOutboxEntryMatchesContext(latest, context) ||
            !teacherOutboxEntryIsReplayable(latest))
          return false;
        final saved = await _syncEntry(client, latest, active);
        if (active() &&
            open != null &&
            registers.containsKey(open.key) &&
            open.value.id() == entry.id) {
          final updated = saved ? null : await _outboxStore.findEntry(entry.id);
          if (saved ||
              (updated != null && !teacherOutboxEntryIsReplayable(updated)))
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
    final claimed = entry.copyWith(
      state: TeacherOutboxState.syncing,
      updatedAt: DateTime.now(),
    );
    if (!await _outboxStore.replaceIfCurrent(entry, claimed)) return false;
    if (!active()) {
      await _outboxStore.replaceIfCurrent(claimed, entry);
      return false;
    }
    try {
      await syncTeacherOutboxEntry(client, entry);
    } on Object catch (error) {
      await _outboxStore.replaceIfCurrent(
        claimed,
        claimed.copyWith(
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
    return _outboxStore.replaceIfCurrent(claimed, null);
  }
}
