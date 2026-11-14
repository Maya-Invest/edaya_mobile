import 'package:edaya_shared/edaya_shared.dart';
import 'package:edaya_api_client/edaya_api_client.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'batch marks replay unchanged alongside legacy single entries',
    () async {
      final transport = _RecordingTransport();
      final entry = buildTeacherOutboxEntry(
        id: 'batch',
        kind: TeacherOutboxKind.mark,
        idempotencyKey: 'batch',
        payload: {
          'requestId': 'batch',
          'assessmentId': 'sheet',
          'expectedRevision': 3,
          'results': [
            {
              'id': 'r1',
              'studentId': 's1',
              'score': 12,
              'designation': 'scored',
            },
            {'id': 'r2', 'studentId': 's2', 'designation': 'absent'},
          ],
        },
      );
      final restored = TeacherOutboxEntry.fromJson(entry.toJson());
      await syncTeacherOutboxEntry(createSchoolClient(transport), restored);
      await syncTeacherOutboxEntry(createSchoolClient(transport), restored);
      expect(transport.bodies[0], transport.bodies[1]);
      expect(teacherMarkOutboxRows(restored).map((r) => r['studentId']), [
        's1',
        's2',
      ]);
    },
  );

  test(
    'distinct mark edits survive queueing and retries preserve command identity',
    () async {
      final store = InMemoryTeacherOutboxStore();
      final transport = _RecordingTransport();
      final client = createSchoolClient(transport);
      for (var revision = 0; revision < 2; revision++) {
        final requestId = 'edit-$revision';
        await store.enqueue(
          buildTeacherOutboxEntry(
            id: requestId,
            kind: TeacherOutboxKind.mark,
            idempotencyKey: requestId,
            payload: markOutboxPayload(
              requestId: requestId,
              expectedRevision: revision,
              assessmentId: 'sheet',
              studentId: 'student',
              resultId: 'result',
              score: 10.0 + revision,
            ),
          ),
        );
      }
      final pending = await store.listPending();
      expect(pending, hasLength(2));
      await syncTeacherOutboxEntry(client, pending[0]);
      await syncTeacherOutboxEntry(client, pending[0]);
      await syncTeacherOutboxEntry(client, pending[1]);
      expect(transport.bodies[0], equals(transport.bodies[1]));
      expect(transport.bodies.map((body) => body['requestId']), [
        'edit-0',
        'edit-0',
        'edit-1',
      ]);
      expect(transport.bodies.map((body) => body['expectedRevision']), [
        0,
        0,
        1,
      ]);
      await store.upsert(
        pending[1].copyWith(
          state: TeacherOutboxState.conflict,
          lastError: 'MARKS_REVISION_CONFLICT',
        ),
      );
      final conflict = (await store.listPending()).last;
      expect(conflict.state, TeacherOutboxState.conflict);
      expect(teacherOutboxEntryIsReplayable(conflict), isFalse);
      expect(conflict.payload, pending[1].payload);
      expect(
        isRetryableTeacherWriteFailure(
          ApiError(409, 'ASSESSMENT_MARKS_FROZEN'),
        ),
        isFalse,
      );
    },
  );

  test(
    'queued report comments reserve sequential versions across both commands',
    () {
      final first = buildTeacherOutboxEntry(
        id: 'edit',
        kind: TeacherOutboxKind.comment,
        idempotencyKey: 'edit',
        payload: {
          'homeroom': {
            'id': 'report',
            'requestId': 'edit:homeroom',
            'expectedVersion': 5,
            'teacherComment': 'Progress',
          },
          'sections': {
            'id': 'report',
            'requestId': 'edit:sections',
            'expectedVersion': 6,
            'sections': [],
          },
        },
      );
      expect(reportCommentNextVersion(5, 'report', [first]), 7);
      expect(reportCommentNextVersion(5, 'other-report', [first]), 5);
      expect(reportCommentNextVersion(9, 'report', [first]), 9);
      expect(
        reportCommentCommandBodies(first).map((body) => body['requestId']),
        ['edit:homeroom', 'edit:sections'],
      );
    },
  );

  test('teacherLogbookIdempotencyKey scopes note and matter entries', () {
    expect(
      teacherLogbookIdempotencyKey(lessonSessionId: 'ls-1'),
      'logbook:ls-1:note',
    );
    expect(
      teacherLogbookIdempotencyKey(
        lessonSessionId: 'ls-1',
        matterId: 'matter-1',
      ),
      'logbook:ls-1:matter-1',
    );
  });

  test('buildTeacherOutboxEntry stores pending state', () {
    final entry = buildTeacherOutboxEntry(
      id: 'mark-1',
      kind: TeacherOutboxKind.mark,
      idempotencyKey: 'edit-1',
      payload: markOutboxPayload(
        requestId: 'edit-1',
        expectedRevision: 0,
        assessmentId: 'asm-1',
        studentId: 'stu-1',
        score: 12,
      ),
    );

    expect(entry.state, TeacherOutboxState.pending);
    expect(entry.kind, TeacherOutboxKind.mark);
  });
  test(
    'workflow outbox retries preserve captured arrival time and review versions',
    () async {
      final transport = _RecordingTransport();
      final client = createSchoolClient(transport);
      for (final command in [
        'record-teacher-attendance-arrival',
        'revise-teacher-correction',
        'save-teacher-logbook',
        'append-incident-follow-up',
      ]) {
        final body = {
          'requestId': command,
          'expectedVersion': 4,
          'occurredAt': '2026-10-04T10:15:00Z',
        };
        final entry = buildTeacherOutboxEntry(
          id: command,
          kind: TeacherOutboxKind.correction,
          idempotencyKey: command,
          payload: {'command': command, 'body': body},
        );
        await syncTeacherOutboxEntry(client, entry);
        await syncTeacherOutboxEntry(client, entry);
        expect(transport.bodies[transport.bodies.length - 1], body);
        expect(transport.bodies[transport.bodies.length - 2], body);
      }
      final invalid = buildTeacherOutboxEntry(
        id: 'invalid',
        kind: TeacherOutboxKind.correction,
        idempotencyKey: 'invalid',
        payload: {'command': 'save-entity', 'body': {}},
      );
      await expectLater(
        syncTeacherOutboxEntry(client, invalid),
        throwsStateError,
      );
    },
  );
}

class _RecordingTransport implements Transport {
  final bodies = <Map<String, dynamic>>[];
  @override
  Future<T> request<T>(
    String method,
    String path, {
    TransportRequestOptions? options,
  }) async {
    bodies.add(Map<String, dynamic>.from(options!.body! as Map));
    if (path.endsWith('/record-assessment-results')) return <dynamic>[] as T;
    return <String, dynamic>{} as T;
  }
}
