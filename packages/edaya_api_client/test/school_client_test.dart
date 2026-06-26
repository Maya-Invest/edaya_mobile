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
    requests.add({
      'method': method,
      'path': path,
      'body': options?.body,
    });
    return responses.removeAt(0) as T;
  }
}

void main() {
  test('uses generated entity paths and unwraps entity envelopes', () async {
    final transport = RecordingTransport([
      [
        {'data': {'id': 'subject-1', 'name': 'Mathematics'}},
      ],
      {'data': {'id': 'subject-1', 'name': 'Mathematics'}},
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
      client.students.delete(id: 'student-1'),
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
        'path': '/core/entities/students/delete',
        'body': {'id': 'student-1'},
      },
    ]);
  });

  test('uses generated command, query, and authorization paths', () async {
    final transport = RecordingTransport([
      {'studentId': 'student-1'},
      {'count': 2},
      {
        'kind': 'staff',
        'actorId': 'actor-1',
        'schoolId': 'school-1',
        'assuranceLevel': 'standard',
        'effectiveGrants': {
          'permissions': ['students:read'],
          'scopeGrants': [],
          'isElevated': false,
        },
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
  });
}
