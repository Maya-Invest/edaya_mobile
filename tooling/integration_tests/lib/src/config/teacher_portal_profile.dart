/// Demo-ci teacher portal accounts used by live integration tests.
enum TeacherPortalKind { subject, homeroom }

class TeacherPortalProfile {
  const TeacherPortalProfile({
    required this.kind,
    required this.label,
    required this.email,
    required this.academicYearId,
    required this.primaryClassGroupId,
    required this.expectedClassGroupIds,
    required this.expectedClassSubjectIds,
  });

  final TeacherPortalKind kind;
  final String label;
  final String email;
  final String academicYearId;
  final String primaryClassGroupId;
  final List<String> expectedClassGroupIds;
  final List<String> expectedClassSubjectIds;

  static const subjectTeacher = TeacherPortalProfile(
    kind: TeacherPortalKind.subject,
    label: 'subject teacher (ci-t1)',
    email: 'a.toure@ecole-ci.edaya.dev',
    academicYearId: '2025-ci',
    primaryClassGroupId: 'ci-6a',
    expectedClassGroupIds: ['ci-6a', 'ci-5a'],
    expectedClassSubjectIds: ['ci-cs-6a-math', 'ci-cs-5a-math'],
  );

  static const homeroomTeacher = TeacherPortalProfile(
    kind: TeacherPortalKind.homeroom,
    label: 'homeroom teacher (ci-t2)',
    email: 'k.diomande@ecole-ci.edaya.dev',
    academicYearId: '2025-ci',
    primaryClassGroupId: 'ci-6b',
    expectedClassGroupIds: ['ci-6b'],
    expectedClassSubjectIds: [],
  );

  static const demoCiProfiles = [subjectTeacher, homeroomTeacher];
}
