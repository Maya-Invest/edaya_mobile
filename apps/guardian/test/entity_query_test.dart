import 'package:edaya_api_client/edaya_api_client.dart';
import 'package:edaya_guardian/api/entity_query.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('studentIdsFromScopeGrants collects unique student scope ids', () {
    final ids = studentIdsFromScopeGrants([
      const ScopeGrant(
        permission: 'grade:read',
        scopeType: 'student',
        scopeEntityIds: ['student-1', 'student-2'],
      ),
      const ScopeGrant(
        permission: 'attendance:read',
        scopeType: 'student',
        scopeEntityIds: ['student-2'],
      ),
      const ScopeGrant(
        permission: 'grade:read',
        scopeType: 'class_group',
        scopeEntityIds: ['class-1'],
      ),
    ]);

    expect(ids, ['student-1', 'student-2']);
  });
}
