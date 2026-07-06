import 'package:edaya_integration_tests/edaya_integration_tests.dart';
import 'package:test/test.dart';

void main() {
  test('IntegrationConfig.fromEnvironment applies demo defaults', () {
    final config = IntegrationConfig.fromEnvironment();

    expect(config.baseUrl, 'http://localhost:9999');
    expect(config.email, 'a.toure@ecole-ci.edaya.dev');
    expect(config.password, 'DevPassword1!');
    expect(config.academicYearId, '2025-ci');
    expect(config.classGroupId, 'ci-6a');
  });

  test('TeacherPortalProfile.demoCiProfiles includes subject and homeroom', () {
    expect(TeacherPortalProfile.demoCiProfiles, hasLength(2));
    expect(
      TeacherPortalProfile.demoCiProfiles.map((profile) => profile.kind),
      containsAll([
        TeacherPortalKind.subject,
        TeacherPortalKind.homeroom,
      ]),
    );
  });

  test('teachingScopeFromAssignments derives homeroom and subject ids', () {
    final scope = teachingScopeFromAssignments([
      {
        'status': 'active',
        'kind': 'homeroom',
        'classGroupId': 'ci-6b',
      },
      {
        'status': 'active',
        'kind': 'subject',
        'classSubjectId': 'ci-cs-6a-math',
      },
      {
        'status': 'inactive',
        'kind': 'subject',
        'classSubjectId': 'ci-cs-5a-math',
      },
    ]);

    expect(scope.classGroupIds, {'ci-6b'});
    expect(scope.classSubjectIds, {'ci-cs-6a-math'});
  });
}
