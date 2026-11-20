/// Demo-ci guardian portal accounts used by live integration tests.
class GuardianPortalProfile {
  const GuardianPortalProfile({
    required this.label,
    required this.email,
    required this.academicYearId,
    required this.guardianId,
    required this.expectedStudentIds,
    required this.primaryStudentId,
    required this.primaryClassGroupId,
  });

  final String label;
  final String email;
  final String academicYearId;
  final String guardianId;
  final List<String> expectedStudentIds;
  final String primaryStudentId;
  final String primaryClassGroupId;

  static const mariamKone = GuardianPortalProfile(
    label: 'two children (ci-g1)',
    email: 'm.kone@mail.ci',
    academicYearId: '2025-ci',
    guardianId: 'ci-g1',
    expectedStudentIds: ['ci-s1', 'ci-s10'],
    primaryStudentId: 'ci-s1',
    primaryClassGroupId: 'ci-6a',
  );

  static const koffiYao = GuardianPortalProfile(
    label: 'multiple children (ci-g4)',
    email: 'k.yao@mail.ci',
    academicYearId: '2025-ci',
    guardianId: 'ci-g4',
    expectedStudentIds: ['ci-s4', 'ci-s7', 'ci-s8'],
    primaryStudentId: 'ci-s4',
    primaryClassGroupId: 'ci-6a',
  );

  static const demoCiProfiles = [mariamKone, koffiYao];
}
