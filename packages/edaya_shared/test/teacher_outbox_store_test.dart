import 'package:edaya_shared/src/offline/teacher_outbox_store_shared_prefs.dart';
import 'package:edaya_shared/src/offline/teacher_outbox_models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('SharedPrefsTeacherOutboxStore dedupes by idempotency key', () async {
    final store = SharedPrefsTeacherOutboxStore(
      storageKey: 'test_outbox',
    );
    final now = DateTime(2026, 4, 1, 9);

    await store.enqueue(
      TeacherOutboxEntry(
        id: 'row-1',
        kind: TeacherOutboxKind.attendance,
        idempotencyKey: 'attendance:ls-1:stu-1',
        payload: const {'studentId': 'stu-1'},
        state: TeacherOutboxState.pending,
        attemptCount: 0,
        createdAt: now,
        updatedAt: now,
      ),
    );
    await store.enqueue(
      TeacherOutboxEntry(
        id: 'row-1-updated',
        kind: TeacherOutboxKind.attendance,
        idempotencyKey: 'attendance:ls-1:stu-1',
        payload: const {'studentId': 'stu-1', 'status': 'present'},
        state: TeacherOutboxState.pending,
        attemptCount: 1,
        createdAt: now,
        updatedAt: now,
      ),
    );

    final pending = await store.listPending();
    expect(pending, hasLength(1));
    expect(pending.first.payload['status'], 'present');
    expect(await store.pendingCount(), 1);
  });
}
