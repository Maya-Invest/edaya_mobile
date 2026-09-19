/// Canonical teacher-app routes that can be opened from notifications or links.
abstract final class TeacherRoutePaths {
  static const home = '/home';
  static const calendar = '/calendar';
  static const classes = '/classes';
  static const evaluations = '/evaluations';
  static const inbox = '/inbox';
  static const settings = '/settings';
  static const account = '/account';

  static String session(String sessionId) => '/session/$sessionId';

  static String assessmentMarks(String assessmentId) =>
      '/evaluations/$assessmentId/marks';

  static String reportCardRoster({
    required String classGroupId,
    required String periodId,
  }) => '/evaluations/report-cards/$classGroupId/$periodId';

  static String reportCardComment({
    required String classGroupId,
    required String periodId,
    required String studentId,
  }) => '/evaluations/report-cards/$classGroupId/$periodId/$studentId';

  static String classWorkspace(String classGroupId) =>
      '/classes/$classGroupId';
}
