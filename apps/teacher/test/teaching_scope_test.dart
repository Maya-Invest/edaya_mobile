import 'package:edaya_api_client/edaya_api_client.dart';
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
      expect(scope.sessionIds, isEmpty);
    },
  );

  test('teachingScopeFromTeacherPortalScope reads grants scope payload', () {
    final scope = teachingScopeFromTeacherPortalScope(
      const TeacherPortalScope(
        classSubjectIds: ['cs-maths-6a'],
        homeroomClassGroupIds: ['cg-6a'],
      ),
    );

    expect(scope.classGroupIds, {'cg-6a'});
    expect(scope.classSubjectIds, {'cs-maths-6a'});
  });
}
