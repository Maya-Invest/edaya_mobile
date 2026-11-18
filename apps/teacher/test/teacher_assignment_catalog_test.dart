import 'package:edaya_api_client/edaya_api_client.dart';
import 'package:edaya_teacher_v2/features/context/teacher_assignment_catalog.dart';
import 'package:flutter_test/flutter_test.dart';

class _Transport implements Transport {
  final paths = <String>[];
  final rows = <Map<String, dynamic>>[
    {
      'id': 'teach',
      'status': 'active',
      'kind': 'subject',
      'classSubjectId': 'math',
    },
    {'id': 'hr', 'status': 'active', 'kind': 'homeroom', 'classGroupId': 'a'},
    {
      'id': 'hr-only',
      'status': 'active',
      'kind': 'homeroom',
      'classGroupId': 'b',
    },
  ];

  @override
  Future<T> request<T>(
    String method,
    String path, {
    TransportRequestOptions? options,
  }) async {
    final entity = path.split('/')[3];
    paths.add(entity);
    final all = switch (entity) {
      'teacher-assignments' => rows,
      'class-subjects' => [
        {'id': 'math', 'classGroupId': 'a', 'subjectId': 'sub'},
      ],
      'subjects' => [
        {'id': 'sub', 'name': 'Mathématiques'},
      ],
      'class-groups' => [
        {'id': 'a', 'name': '6e A', 'attendanceMode': 'session'},
        {'id': 'b', 'name': '6e B', 'attendanceMode': 'daily'},
      ],
      _ => throw StateError('Unexpected request: $path'),
    };
    final query = options!.body as Map;
    return all
            .skip(query[r'$offset'] as int)
            .take(query[r'$limit'] as int)
            .toList()
        as T;
  }
}

void main() {
  const scope = (account: 'u', school: 'one', actor: 'teacher', year: '2026');
  test(
    'Home batches class metadata and activation rechecks assignments while reusing scoped labels',
    () async {
      final transport = _Transport();
      final client = createSchoolClient(transport);
      final first = await readTeacherAssignmentCatalog(client, scope);
      expect(
        transport.paths,
        unorderedEquals([
          'teacher-assignments',
          'class-subjects',
          'subjects',
          'class-groups',
        ]),
      );
      expect(first.options.map((o) => o.label), [
        '6e A · Mathématiques · Homeroom teacher',
        '6e B · Homeroom teacher',
      ]);
      expect(first.classes.where((c) => c.dailyAttendance).single.id, 'b');
      transport.paths.clear();
      transport.rows.first['id'] = 'replacement';
      final selected = await readTeacherAssignmentCatalog(
        client,
        scope,
        previous: first,
      );
      expect(transport.paths, ['teacher-assignments']);
      expect(selected.classByAssignmentId['replacement'], 'a');
      expect(selected.classByAssignmentId.containsKey('teach'), isFalse);
      transport.rows.removeAt(0);
      final revoked = await readTeacherAssignmentCatalog(
        client,
        scope,
        previous: selected,
      );
      expect(revoked.options.map((o) => o.id), ['homeroom-a', 'homeroom-b']);
      expect(revoked.scope.classSubjectIds, isEmpty);
    },
  );

  test(
    'overlapping IDs in another school, year, actor or account cannot reuse the preview',
    () async {
      final transport = _Transport();
      final client = createSchoolClient(transport);
      final first = await readTeacherAssignmentCatalog(client, scope);
      for (final key in [
        (account: 'other', school: 'one', actor: 'teacher', year: '2026'),
        (account: 'u', school: 'two', actor: 'teacher', year: '2026'),
        (account: 'u', school: 'one', actor: 'other', year: '2026'),
        (account: 'u', school: 'one', actor: 'teacher', year: '2027'),
      ]) {
        transport.paths.clear();
        await readTeacherAssignmentCatalog(client, key, previous: first);
        expect(transport.paths, contains('class-groups'));
      }
    },
  );

  test('eligible assignments beyond the first page remain available', () async {
    final transport = _Transport();
    transport.rows.insertAll(
      0,
      List.generate(100, (i) => {'id': 'old-$i', 'status': 'inactive'}),
    );
    final data = await readTeacherAssignmentCatalog(
      createSchoolClient(transport),
      scope,
    );
    expect(
      transport.paths.where((p) => p == 'teacher-assignments'),
      hasLength(2),
    );
    expect(data.options.map((o) => o.id), ['math', 'homeroom-b']);
    expect(transport.paths.where((p) => p == 'class-groups'), hasLength(1));
  });
}
