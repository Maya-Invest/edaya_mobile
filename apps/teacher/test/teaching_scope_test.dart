import 'package:flutter_test/flutter_test.dart';
import 'package:edaya_teacher/common/utils/entity_query.dart';

void main() {
  test(
    'teachingScopeFromTeacherAssignments collects homeroom and subject targets',
    () {
      final scope = teachingScopeFromTeacherAssignments([
        {
          'id': 'ta-homeroom',
          'teacherId': 't1',
          'academicYearId': '2025',
          'kind': 'homeroom',
          'classGroupId': 'cg-6a',
          'status': 'active',
        },
        {
          'id': 'ta-subject',
          'teacherId': 't1',
          'academicYearId': '2025',
          'kind': 'subject',
          'classSubjectId': 'cs-maths-6a',
          'status': 'active',
        },
        {
          'id': 'ta-ended',
          'teacherId': 't1',
          'academicYearId': '2025',
          'kind': 'subject',
          'classSubjectId': 'cs-history-6a',
          'status': 'ended',
        },
      ]);

      expect(scope.classGroupIds, {'cg-6a'});
      expect(scope.classSubjectIds, {'cs-maths-6a'});
    },
  );

  test('future and expired assignments do not populate teacher context', () {
    final scope = teachingScopeFromTeacherAssignments([
      {
        'kind': 'subject',
        'status': 'active',
        'classSubjectId': 'expired',
        'endsAt': '2000-01-01T00:00:00Z',
      },
      {
        'kind': 'homeroom',
        'status': 'active',
        'classGroupId': 'future',
        'startsAt': '2999-01-01T00:00:00Z',
      },
    ]);
    expect(scope.classGroupIds, isEmpty);
    expect(scope.classSubjectIds, isEmpty);
  });

  test('removed assignments cannot survive in a second scope source', () {
    expect(teachingScopeFromTeacherAssignments([]).classSubjectIds, isEmpty);
    expect(teachingScopeFromTeacherAssignments([]).classGroupIds, isEmpty);
  });
}
