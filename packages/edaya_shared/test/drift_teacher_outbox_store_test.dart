import 'package:drift/native.dart';
import 'package:edaya_shared/src/offline/drift_teacher_outbox_store.dart';
import 'package:edaya_shared/src/offline/teacher_outbox_database.dart';
import 'package:edaya_shared/src/offline/teacher_outbox_models.dart';
import 'package:edaya_shared/src/offline/teacher_outbox_store_shared_prefs.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('DriftTeacherOutboxStore dedupes by idempotency key', () async {
    final database = TeacherOutboxDatabase.forTesting(NativeDatabase.memory());
    final store = DriftTeacherOutboxStore(database);
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
    expect((await store.summary()).pendingCount, 1);
    await database.close();
  });

  test(
    'DriftTeacherOutboxStore migrates legacy SharedPreferences rows',
    () async {
      final legacyStore = SharedPrefsTeacherOutboxStore();
      final now = DateTime(2026, 4, 1, 9);
      await legacyStore.enqueue(
        TeacherOutboxEntry(
          id: 'legacy-1',
          kind: TeacherOutboxKind.attendance,
          idempotencyKey: 'attendance:ls-2:stu-2',
          payload: const {'studentId': 'stu-2', 'status': 'late'},
          state: TeacherOutboxState.pending,
          attemptCount: 0,
          createdAt: now,
          updatedAt: now,
        ),
      );

      final database = TeacherOutboxDatabase.forTesting(
        NativeDatabase.memory(),
      );
      final store = DriftTeacherOutboxStore(database);

      final pending = await store.listPending();
      expect(pending, hasLength(1));
      expect(pending.first.payload['status'], 'late');
      expect(await legacyStore.pendingCount(), 0);
      await database.close();
    },
  );
  test(
    'migration and late acknowledgements preserve profile and year boundaries',
    () async {
      final legacy = SharedPrefsTeacherOutboxStore();
      TeacherOutboxContext profile(String actor, String? year) =>
          TeacherOutboxContext(
            origin: 'https://school.invalid',
            subjectId: actor,
            actorKind: 'teacher',
            actorId: actor,
            schoolId: 's',
            academicYearId: year,
          );
      final a = profile('a', null),
          b = profile('a', 'year'),
          c = profile('b', null);
      final now = DateTime(2026, 1, 1);
      for (final (id, context) in [
        ('legacy', null),
        ('a', a),
        ('year', b),
        ('other', c),
      ]) {
        legacy.bindContext(context);
        await legacy.enqueue(
          TeacherOutboxEntry(
            id: id,
            kind: TeacherOutboxKind.mark,
            idempotencyKey: id,
            payload: {'value': id},
            state: id == 'year'
                ? TeacherOutboxState.conflict
                : TeacherOutboxState.pending,
            attemptCount: 0,
            createdAt: now,
            updatedAt: now,
          ),
        );
      }
      final db = TeacherOutboxDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      final store = DriftTeacherOutboxStore(db);
      for (final (id, context) in [
        ('legacy', null),
        ('a', a),
        ('year', b),
        ('other', c),
      ]) {
        store.bindContext(context);
        expect((await store.listPending()).map((e) => e.id), [id]);
        expect((await store.summary()).pendingCount, 1);
        expect(
          (await store.listConflicts()).map((e) => e.id),
          id == 'year' ? ['year'] : isEmpty,
        );
      }
      store.bindContext(a);
      final before = (await store.findEntry('a'))!;
      final claim = before.copyWith(state: TeacherOutboxState.syncing);
      expect(await store.replaceIfCurrent(before, claim), isTrue);
      store.bindContext(c);
      expect(await store.findEntry('a'), isNull);
      expect(await store.replaceIfCurrent(claim, null), isTrue);
      expect((await store.listPending()).single.id, 'other');
      store.bindContext(a);
      expect(await store.pendingCount(), 0);
    },
  );
}
