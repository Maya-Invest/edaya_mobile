import 'package:edaya_api_client/edaya_api_client.dart';
import 'package:flutter_test/flutter_test.dart';

class RecordingTransport implements Transport {
  RecordingTransport(this.responses);

  final List<Object?> responses;
  final requests = <Map<String, Object?>>[];

  @override
  Future<T> request<T>(
    String method,
    String path, {
    TransportRequestOptions? options,
  }) async {
    requests.add({'method': method, 'path': path, 'body': options?.body});
    return responses.removeAt(0) as T;
  }
}

void main() {
  test('uses generated entity paths and unwraps entity envelopes', () async {
    final transport = RecordingTransport([
      [
        {
          'data': {'id': 'subject-1', 'name': 'Mathematics'},
        },
      ],
      {
        'data': {'id': 'subject-1', 'name': 'Mathematics'},
      },
      {'message': 'deleted'},
    ]);
    final client = createSchoolClient(transport);

    await expectLater(
      client.subjects.list({'schoolId': 'school-1'}),
      completion([
        {'id': 'subject-1', 'name': 'Mathematics'},
      ]),
    );
    await expectLater(
      client.subjects.save({'id': 'subject-1', 'name': 'Mathematics'}),
      completion({'id': 'subject-1', 'name': 'Mathematics'}),
    );
    await expectLater(
      client.subjects.delete(id: 'subject-1'),
      completion({'message': 'deleted'}),
    );

    expect(transport.requests, [
      {
        'method': 'POST',
        'path': '/core/entities/subjects/list',
        'body': {'schoolId': 'school-1'},
      },
      {
        'method': 'POST',
        'path': '/core/entities/subjects/save',
        'body': {'id': 'subject-1', 'name': 'Mathematics'},
      },
      {
        'method': 'POST',
        'path': '/core/entities/subjects/delete',
        'body': {'id': 'subject-1'},
      },
    ]);
  });

  test(
    'command-owned resources reject generic mutations without sending a request',
    () async {
      final transport = RecordingTransport([]);
      final client = createSchoolClient(transport);
      await expectLater(
        client.attachments.save({'id': 'attachment', 'status': 'ready'}),
        throwsStateError,
      );
      expect(
        () => client.attachments.delete(id: 'attachment'),
        throwsStateError,
      );
      expect(
        () => client.attachments.batchSave(entities: []),
        throwsStateError,
      );
      await expectLater(
        client.payments.save({'id': 'payment'}),
        throwsStateError,
      );
      expect(() => client.payments.delete(id: 'payment'), throwsStateError);
      expect(
        () => client.studentFees.batchDelete(ids: ['fee']),
        throwsStateError,
      );
      expect(
        () => client.enrollments.batchSave(entities: []),
        throwsStateError,
      );
      expect(transport.requests, isEmpty);
    },
  );

  test('uses generated command, query, and authorization paths', () async {
    final transport = RecordingTransport([
      {'studentId': 'student-1'},
      {'count': 2},
      {
        'kind': 'staff',
        'actorId': 'actor-1',
        'schoolId': 'school-1',
        'assuranceLevel': 'standard',
        'grants': [
          {
            'permission': 'QUERY_STUDENT_DETAIL_READ',
            'source': 'manual',
            'scopes': [
              {'kind': 'student', 'studentId': 'student-1'},
            ],
          },
        ],
      },
    ]);
    final client = createSchoolClient(transport);

    await client.registerStudent({
      'schoolId': 'school-1',
      'firstName': 'Ada',
      'lastName': 'Lovelace',
    });
    await client.getOverdueFeeCount({'schoolId': 'school-1'});
    final grants = await client.effectiveGrants();

    expect(transport.requests, [
      {
        'method': 'POST',
        'path': '/core/commands/register-student',
        'body': {
          'schoolId': 'school-1',
          'firstName': 'Ada',
          'lastName': 'Lovelace',
        },
      },
      {
        'method': 'POST',
        'path': '/core/queries/get-overdue-fee-count',
        'body': {'schoolId': 'school-1'},
      },
      {
        'method': 'GET',
        'path': '/core/authorization/effective-grants',
        'body': null,
      },
    ]);
    expect(grants.kind, 'staff');
    expect(grants.actorId, 'actor-1');
    expect(
      (grants.grants.single.scopes.single as StudentGrantScope).studentId,
      'student-1',
    );
  });

  test(
    'parses the same typed action grant representation for portal actors',
    () async {
      final transport = RecordingTransport([
        {
          'kind': 'teacher',
          'actorId': 'teacher-1',
          'schoolId': 'school-1',
          'assuranceLevel': 'standard',
          'grants': [
            {
              'permission': 'ATTENDANCE_RECORD',
              'source': 'relationship',
              'academicYearId': 'year',
              'scopes': [
                {
                  'kind': 'class_subject',
                  'classGroupId': 'cg-1',
                  'classSubjectId': 'cs-1',
                },
              ],
            },
          ],
        },
      ]);
      final grants = await createSchoolClient(transport).effectiveGrants();
      expect(grants.kind, 'teacher');
      expect(grants.grants.single.permission, 'ATTENDANCE_RECORD');
      expect(grants.grants.single.source, GrantSource.relationship);
      final scope =
          grants.grants.single.scopes.single as ClassSubjectGrantScope;
      expect(scope.classGroupId, 'cg-1');
      expect(scope.classSubjectId, 'cs-1');
      expect(grants.toJson().containsKey('scope'), isFalse);
    },
  );

  test('uses generated public invitation paths at the API root', () async {
    final transport = RecordingTransport([
      {
        'status': 'pending',
        'kind': 'guardian',
        'targetId': 'guardian-1',
        'schoolName': 'École',
        'inviteeName': 'Parent',
      },
      {'kind': 'guardian', 'entity': {'id': 'guardian-1'}},
    ]);
    final client = createSchoolClient(transport);

    await client.previewInvitation(token: 'invite token/+');
    await client.acceptInvitation(token: 'invite token/+');

    expect(transport.requests, [
      {
        'method': 'GET',
        'path': '/public/invitations/invite%20token%2F%2B',
        'body': null,
      },
      {
        'method': 'POST',
        'path': '/public/invitations/invite%20token%2F%2B/accept',
        'body': null,
      },
    ]);
  });
}
