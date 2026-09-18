import 'package:edaya_api_client/edaya_api_client.dart';
import 'package:edaya_integration_tests/edaya_integration_tests.dart';
import 'package:test/test.dart';

void main() {
  test('IntegrationConfig.fromEnvironment applies demo defaults', () {
    final config = IntegrationConfig.fromEnvironment();

    expect(config.authUrl, 'http://localhost:9900');
    expect(config.baseUrl, 'http://localhost:9999');
    expect(config.email, 'a.toure@ecole-ci.edaya.dev');
    expect(config.academicYearId, '2025-ci');
    expect(config.classGroupId, 'ci-6a');
    expect(
      config.calendarReferenceDate,
      IntegrationConfig.defaultCalendarReferenceDate,
    );
  });

  test('TeacherPortalProfile.demoCiProfiles includes subject and homeroom', () {
    expect(TeacherPortalProfile.demoCiProfiles, hasLength(2));
    expect(
      TeacherPortalProfile.demoCiProfiles.map((profile) => profile.kind),
      containsAll([TeacherPortalKind.subject, TeacherPortalKind.homeroom]),
    );
  });

  test(
    'GuardianPortalProfile.demoCiProfiles includes single and multi-child guardians',
    () {
      expect(GuardianPortalProfile.demoCiProfiles, hasLength(2));
      expect(
        GuardianPortalProfile.demoCiProfiles.map(
          (profile) => profile.guardianId,
        ),
        containsAll(['ci-g1', 'ci-g4']),
      );
      expect(GuardianPortalProfile.mariamKone.expectedStudentIds, [
        'ci-s1',
        'ci-s10',
      ]);
      expect(GuardianPortalProfile.koffiYao.expectedStudentIds, [
        'ci-s4',
        'ci-s7',
        'ci-s8',
      ]);
    },
  );

  test(
    'IntegrationConfig.defaultGuardianEmail matches guardian app dev default',
    () {
      expect(IntegrationConfig.defaultGuardianEmail, 'm.kone@mail.ci');
    },
  );

  test(
    'TeacherPortalContext.writeProbePeriodId prefers first academic period',
    () {
      const context = TeacherPortalContext(
        profile: TeacherPortalProfile.subjectTeacher,
        grants: EffectiveGrantsResponse(
          kind: 'teacher',
          actorId: 'ci-t1',
          schoolId: 'ci-school',
          assuranceLevel: 'standard',
          grants: [],
        ),
        academicYears: [],
        teacherAssignments: [],
        academicPeriods: [
          {'id': 'ci-2025-t1'},
          {'id': 'ci-2025-t2'},
          {'id': 'ci-2025-t3'},
        ],
        teachingScope: TeacherTeachingScope(
          classGroupIds: {},
          classSubjectIds: {},
        ),
        assignedClassGroups: [],
        classSubjects: [],
      );

      expect(context.firstPeriodId, 'ci-2025-t1');
      expect(context.writeProbePeriodId, 'ci-2025-t1');
    },
  );

  test('teachingScopeFromAssignments derives homeroom and subject ids', () {
    final scope = teachingScopeFromAssignments([
      {'status': 'active', 'kind': 'homeroom', 'classGroupId': 'ci-6b'},
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
