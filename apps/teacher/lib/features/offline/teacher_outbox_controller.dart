import 'dart:async';

import 'package:edaya_api_client/edaya_api_client.dart';
import 'package:edaya_shared/edaya_shared.dart';
import 'package:levit_flutter/levit_flutter.dart';

class TeacherOutboxController extends LevitController
    with LevitReactiveTasksMixin {
  TeacherOutboxController({
    required TeacherOutboxStore outboxStore,
    required SchoolClientFactory schoolClient,
    TeacherOutboxContext? Function()? context,
  }) : _outboxStore = outboxStore,
       _schoolClient = schoolClient,
       _context = context;

  final TeacherOutboxStore _outboxStore;
  final SchoolClientFactory _schoolClient;
  final TeacherOutboxContext? Function()? _context;

  final conflicts = LxVar<List<TeacherOutboxEntry>>(const []);

  final summary = LxVar(const TeacherOutboxSummary(pendingCount: 0));

  @override
  void onInit() {
    super.onInit();
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
    await refreshSummary();
  }

  Future<void> discardPending() async {
    _outboxStore.bindContext(_context?.call());
    await _outboxStore.discardBoundContext();
    await refreshSummary();
  }

  Future<int> syncPending() async {
    var syncedCount = 0;
    await runTask(() async {
      final activeContext = _context?.call();
      _outboxStore.bindContext(activeContext);
      final pending = await _outboxStore.listPending();
      if (pending.isEmpty) {
        await refreshSummary();
        return;
      }

      final client = _schoolClient();
      for (final entry in pending) {
        if (activeContext != null &&
            !teacherOutboxEntryMatchesContext(entry, activeContext)) {
          continue;
        }
        if (!teacherOutboxEntryIsReplayable(entry)) continue;
        final synced = await _syncEntry(client, entry);
        if (synced) {
          syncedCount++;
        }
      }
      await refreshSummary();
    });
    return syncedCount;
  }

  Future<bool> _syncEntry(SchoolClient client, TeacherOutboxEntry entry) async {
    await _outboxStore.upsert(
      entry.copyWith(
        state: TeacherOutboxState.syncing,
        updatedAt: DateTime.now(),
      ),
    );

    try {
      await syncTeacherOutboxEntry(client, entry);
      await _outboxStore.remove(entry.id);
      return true;
    } on Object catch (error) {
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
