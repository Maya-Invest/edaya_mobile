import 'package:edaya_api_client/edaya_api_client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:edaya_teacher/common/utils/entity_query.dart';

void main() {
  test('teachingScopeFromScopeGrants collects class and session scopes', () {
    const grants = [
      ScopeGrant(
        permission: 'QUERY_TIMETABLE_READ',
        scopeType: 'class_group',
        scopeEntityIds: ['cg-6a'],
      ),
      ScopeGrant(
        permission: 'QUERY_TIMETABLE_READ',
        scopeType: 'course_assignment',
        scopeEntityIds: ['cs-maths-6a', 'cs-maths-6b'],
      ),
      ScopeGrant(
        permission: 'QUERY_TIMETABLE_READ',
        scopeType: 'session',
        scopeEntityIds: ['sess-extra'],
      ),
      ScopeGrant(
        permission: 'QUERY_STUDENT_READ',
        scopeType: 'student',
        scopeEntityIds: ['stu-1'],
      ),
    ];

    final scope = teachingScopeFromScopeGrants(grants);

    expect(scope.classGroupIds, {'cg-6a'});
    expect(scope.classSubjectIds, {'cs-maths-6a', 'cs-maths-6b'});
    expect(scope.sessionIds, {'sess-extra'});
  });
}
