import 'package:flutter_test/flutter_test.dart';
import 'package:edaya_teacher/common/utils/entity_query.dart';

void main() {
  test('teachingScopeFromStaffAssignments collects class, subject, and session targets', () {
    final scope = teachingScopeFromStaffAssignments([
      {
        'id': 'sa-class',
        'staffId': 'st1',
        'academicYearId': '2025',
        'classGroupId': 'cg-6a',
        'responsibility': 'Mathematics',
      },
      {
        'id': 'sa-subject',
        'staffId': 'st1',
        'academicYearId': '2025',
        'classSubjectId': 'cs-maths-6a',
        'responsibility': 'Mathematics',
      },
      {
        'id': 'sa-session',
        'staffId': 'st1',
        'academicYearId': '2025',
        'lessonSessionId': 'sess-extra',
        'responsibility': 'Mathematics',
      },
    ]);

    expect(scope.classGroupIds, {'cg-6a'});
    expect(scope.classSubjectIds, {'cs-maths-6a'});
    expect(scope.sessionIds, {'sess-extra'});
  });
}
