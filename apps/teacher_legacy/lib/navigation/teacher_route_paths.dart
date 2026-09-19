/// Canonical teacher-app routes that can be opened from notifications or links.
abstract final class TeacherRoutePaths {
  static const calendar = '/calendar';
  static const evaluations = '/evaluations';
  static const teaching = '/teaching';
  static const reportCards = '/report-cards';

  static String session(String sessionId) => '/calendar/sessions/$sessionId';

  static String assessmentMarks(String assessmentId) =>
      '/evaluations/assessments/$assessmentId/marks';

  static String reportCardRoster({
    required String classGroupId,
    required String periodId,
  }) => '/report-cards/classes/$classGroupId/periods/$periodId/roster';

  static String reportCardComment({
    required String resultId,
    required String studentId,
  }) => '/report-cards/results/$resultId/students/$studentId/comment';
}
