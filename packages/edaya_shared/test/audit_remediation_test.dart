import 'package:drift/native.dart';
import 'package:edaya_api_client/edaya_api_client.dart';
import 'package:edaya_shared/edaya_shared.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test('mixed scales normalize each score to 20 before weighting', () {
    final average = normalizedAverageOutOf20(const [
      (score: 10, maxScore: 20, coefficient: 1),
      (score: 80, maxScore: 100, coefficient: 1),
    ]);
    expect(average, 13);
  });

  test('terminal write failures are not retried as offline work', () {
    expect(isRetryableTeacherWriteFailure(ApiError(503, 'offline')), isTrue);
    expect(isRetryableTeacherWriteFailure(ApiError(403, 'denied')), isFalse);
    expect(isRetryableTeacherWriteFailure(StateError('contract')), isFalse);
  });

  test('structured logbook notes decode for guardians and keep plain text', () {
    final encoded = encodeStructuredSessionNote(
      const StructuredLogbookContent(
        content: 'Fractions',
        objectives: ['Add'],
        homework: 'Ex 1',
        familySummary: 'Internal',
      ),
    );
    final decoded = decodeStructuredSessionNote(encoded);
    expect(decoded.guardianText, contains('Fractions'));
    expect(decoded.guardianText, contains('Ex 1'));
    expect(decoded.guardianText, isNot(contains('Internal')));
    expect(decodeStructuredSessionNote('Legacy note').content, 'Legacy note');
  });

  test('queued work stays with the account that created it', () async {
    final store = InMemoryTeacherOutboxStore();
    const first = TeacherOutboxContext(
      origin: 'https://school.example',
      subjectId: 'person-a',
      actorKind: 'teacher',
      actorId: 'teacher-a',
      schoolId: 'school-a',
    );
    const second = TeacherOutboxContext(
      origin: 'https://school.example',
      subjectId: 'person-b',
      actorKind: 'teacher',
      actorId: 'teacher-b',
      schoolId: 'school-a',
    );
    store.bindContext(first);
    await store.enqueue(
      buildTeacherOutboxEntry(
        id: 'mark-1',
        kind: TeacherOutboxKind.mark,
        idempotencyKey: 'mark:assessment:student',
        payload: {'score': 8},
      ),
    );
    store.bindContext(second);
    expect(await store.pendingCount(), 0);
    store.bindContext(first);
    expect(await store.pendingCount(), 1);
  });

  test('an interrupted sync returns to the pending queue', () async {
    final database = TeacherOutboxDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final store = DriftTeacherOutboxStore(database);
    final entry = buildTeacherOutboxEntry(
      id: 'entry',
      kind: TeacherOutboxKind.mark,
      idempotencyKey: 'mark:a:s',
      payload: {'score': 8},
    );
    await store.enqueue(entry);
    await store.upsert(entry.copyWith(state: TeacherOutboxState.syncing));
    final reopened = DriftTeacherOutboxStore(database);
    expect(await reopened.pendingCount(), 1);
    expect(
      (await reopened.findEntry(entry.id))?.state,
      TeacherOutboxState.syncing,
    );
    await reopened.prepareReplay();
    expect(
      (await reopened.findEntry(entry.id))?.state,
      TeacherOutboxState.pending,
    );
    final pending = (await reopened.findEntry(entry.id))!;
    final claim = pending.copyWith(state: TeacherOutboxState.syncing);
    expect(await reopened.replaceIfCurrent(pending, claim), isTrue);
    await reopened.prepareReplay();
    expect((await reopened.summary()).pendingCount, 1);
    expect(await reopened.listConflicts(), isEmpty);
    expect(
      (await reopened.findEntry(entry.id))?.state,
      TeacherOutboxState.syncing,
    );
    await reopened.upsert(entry.copyWith(state: TeacherOutboxState.failed));
    expect(await reopened.replaceIfCurrent(claim, null), isFalse);
    expect(
      (await reopened.findEntry(entry.id))?.state,
      TeacherOutboxState.failed,
    );
  });

  test('generic report-card saves are rejected without a command', () async {
    final transport = _RecordingTransport();
    final entry = buildTeacherOutboxEntry(
      id: 'comment',
      kind: TeacherOutboxKind.comment,
      idempotencyKey: 'comment:r:s',
      payload: {
        'resultPayload': {'id': 'result'},
      },
    );
    await expectLater(
      syncTeacherOutboxEntry(createSchoolClient(transport), entry),
      throwsStateError,
    );
    expect(transport.calls, isEmpty);
  });
}

class _RecordingTransport implements Transport {
  final calls = <String>[];

  @override
  Future<T> request<T>(
    String method,
    String path, {
    TransportRequestOptions? options,
  }) async {
    calls.add(path);
    return <String, dynamic>{} as T;
  }
}
