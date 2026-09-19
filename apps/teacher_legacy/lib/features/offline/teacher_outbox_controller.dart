import 'dart:async';

import 'package:edaya_api_client/edaya_api_client.dart';
import 'package:edaya_shared/edaya_shared.dart';
import 'package:levit_flutter/levit_flutter.dart';

import '../../common/observability/teacher_observability.dart';

class TeacherOutboxController extends LevitController
    with LevitReactiveTasksMixin {
  TeacherOutboxController({
    required TeacherOutboxStore outboxStore,
    required SchoolClientFactory schoolClient,
    TeacherObservability? observability,
  }) : _outboxStore = outboxStore,
       _schoolClient = schoolClient,
       _observability = observability ?? const TeacherObservability();

  final TeacherOutboxStore _outboxStore;
  final SchoolClientFactory _schoolClient;
  final TeacherObservability _observability;

  final summary = LxVar(const TeacherOutboxSummary(pendingCount: 0));

  @override
  void onInit() {
    super.onInit();
    autoDispose(summary);
    unawaited(refreshSummary());
  }

  Future<void> refreshSummary() async {
    summary(await _outboxStore.summary());
  }

  Future<int> syncPending() async {
    var syncedCount = 0;
    await runTask(() async {
      final pending = await _outboxStore.listPending();
      if (pending.isEmpty) {
        await refreshSummary();
        return;
      }

      final client = _schoolClient();

      for (final entry in pending) {
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
      _observability.recordOutboxSyncSuccess(entry.kind);
      return true;
    } on ApiError catch (error) {
      await _outboxStore.upsert(
        entry.copyWith(
          state: TeacherOutboxState.failed,
          attemptCount: entry.attemptCount + 1,
          lastError: '$error',
          updatedAt: DateTime.now(),
        ),
      );
      _observability.recordOutboxSyncFailure(entry.kind, error: '$error');
      return false;
    } on Object catch (error) {
      await _outboxStore.upsert(
        entry.copyWith(
          state: TeacherOutboxState.failed,
          attemptCount: entry.attemptCount + 1,
          lastError: '$error',
          updatedAt: DateTime.now(),
        ),
      );
      _observability.recordOutboxSyncFailure(entry.kind, error: '$error');
      return false;
    }
  }
}
