import 'dart:async';

import 'package:edaya_shared/edaya_shared.dart';
import 'package:edaya_teacher_v2/features/offline/teacher_outbox_controller.dart';
import 'package:flutter_test/flutter_test.dart';

class DelayedSummaryStore extends InMemoryTeacherOutboxStore {
  Completer<void>? gate;

  @override
  Future<TeacherOutboxSummary> summary() async {
    final result = await super.summary();
    await gate?.future;
    return result;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'switching profiles clears the badge and discards a late count',
    () async {
      TeacherOutboxContext profile(String actor) => TeacherOutboxContext(
        origin: 'https://school.example',
        subjectId: actor,
        actorId: actor,
        actorKind: 'teacher',
        schoolId: 'school',
        academicYearId: 'year',
      );
      final store = DelayedSummaryStore();
      final a = profile('a'), b = profile('b');
      var current = a;
      final time = DateTime.utc(2026, 11, 18);
      final controller = TeacherOutboxController(
        outboxStore: store,
        schoolClient: () => throw StateError('Badge is offline'),
        context: () => current,
      );
      store.bindContext(a);
      for (final state in [
        TeacherOutboxState.pending,
        TeacherOutboxState.conflict,
      ]) {
        await store.enqueue(
          TeacherOutboxEntry(
            id: state.name,
            idempotencyKey: state.name,
            kind: TeacherOutboxKind.attendance,
            payload: const {},
            state: state,
            attemptCount: 0,
            createdAt: time,
            updatedAt: time,
          ),
        );
      }
      await controller.refreshSummary();
      expect(controller.summary.value.pendingCount, greaterThan(0));
      expect(controller.conflicts.value.single.id, 'conflict');
      final initialCount = controller.summary.value.pendingCount;
      final wait = store.gate = Completer<void>();
      current = b;
      final delayed = controller.refreshSummary();
      expect(controller.conflicts.value, isEmpty);
      expect(controller.summary.value.pendingCount, 0);
      await Future<void>.delayed(Duration.zero);
      store.gate = null;
      current = a;
      await controller.refreshSummary();
      wait.complete();
      await delayed;
      expect(controller.summary.value.pendingCount, initialCount);
      expect(controller.conflicts.value.single.id, 'conflict');
    },
  );
}
