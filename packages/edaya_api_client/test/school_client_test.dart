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
  for (final pageSize in [50, 500]) {
    test('loads ${pageSize + 1} rows through both consumer pages', () async {
      final first = List.generate(
        pageSize,
        (id) => <String, dynamic>{'id': '$id'},
      );
      final transport = RecordingTransport([
        first,
        [
          {'id': '$pageSize'},
        ],
      ]);
      final client = createSchoolClient(transport);
      final rows = await client.students.listAll({
        'schoolId': 'school',
      }, pageSize);
      expect(rows.length, pageSize + 1);
      expect(rows.last['id'], '$pageSize');
      expect((transport.requests[1]['body'] as Map)[r'$offset'], pageSize);
      expect((transport.requests[1]['body'] as Map)['schoolId'], 'school');
    });
  }

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
        () => client.studentCharges.batchDelete(ids: ['charge']),
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

  test('uses generated document command and download query paths', () async {
    final transport = RecordingTransport([
      {'id': 'iss-1', 'status': 'requested'},
      {
        'downloadUrl': 'https://example.test/doc.pdf',
        'fileName': 'bulletin.pdf',
        'issuanceId': 'iss-1',
        'expiresAt': '2026-01-01T00:00:00.000Z',
      },
    ]);
    final client = createSchoolClient(transport);

    await client.requestDocumentIssuance({
      'requestId': 'req-1',
      'templateKey': 'schooling-certificate.v1',
      'sourceId': 'enr-1',
    });
    await client.grantDocumentDownload({'id': 'iss-1'});

    expect(transport.requests, [
      {
        'method': 'POST',
        'path': '/core/commands/request-document-issuance',
        'body': {
          'requestId': 'req-1',
          'templateKey': 'schooling-certificate.v1',
          'sourceId': 'enr-1',
        },
      },
      {
        'method': 'POST',
        'path': '/core/queries/grant-document-download',
        'body': {'id': 'iss-1'},
      },
    ]);
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
      {
        'kind': 'guardian',
        'entity': {'id': 'guardian-1'},
      },
      {'invitations': <Map<String, dynamic>>[]},
      {
        'kind': 'guardian',
        'entity': {'id': 'guardian-1'},
      },
    ]);
    final client = createSchoolClient(transport);

    await client.previewInvitation(token: 'invite token/+');
    await client.acceptInvitation(token: 'invite token/+');
    await client.listMyInvitations();
    await client.acceptMyInvitation(invitationId: 'inv-1');

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
      {'method': 'GET', 'path': '/public/me/invitations', 'body': null},
      {
        'method': 'POST',
        'path': '/public/me/invitations/inv-1/accept',
        'body': null,
      },
    ]);
  });
}
