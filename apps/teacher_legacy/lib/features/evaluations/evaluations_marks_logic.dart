import 'models/evaluation_models.dart';

/// Returns false when a newer marks load or save invalidated [requestedGeneration].
bool shouldApplyMarksLoad(int requestedGeneration, int currentGeneration) {
  return requestedGeneration == currentGeneration;
}

bool canInputGradeForSubject({
  required String classSubjectId,
  required Set<String> taughtSubjectIds,
}) {
  return taughtSubjectIds.isEmpty || taughtSubjectIds.contains(classSubjectId);
}

bool shouldIncludeAssessmentForTeacher({
  required String classSubjectId,
  required Set<String> taughtSubjectIds,
}) {
  return taughtSubjectIds.isEmpty || taughtSubjectIds.contains(classSubjectId);
}

List<StudentMarkRow> applyStudentMark(
  List<StudentMarkRow> rows, {
  required String studentId,
  String? resultId,
  double? score,
  MarkSyncState? syncState,
}) {
  return rows
      .map(
        (entry) => entry.studentId == studentId
            ? entry.copyWith(
                resultId: resultId,
                score: score,
                syncState: syncState,
              )
            : entry,
      )
      .toList();
}

int countGradedStudents(List<StudentMarkRow> students) {
  return students.where((row) => row.score != null).length;
}

List<EvaluationSummary> patchEvaluationGradedCount({
  required List<EvaluationSummary> summaries,
  required String evaluationId,
  required List<StudentMarkRow> students,
}) {
  final gradedCount = students.where((row) => row.score != null).length;
  return summaries
      .map(
        (summary) => summary.id == evaluationId
            ? EvaluationSummary(
                id: summary.id,
                title: summary.title,
                classGroupId: summary.classGroupId,
                classSubjectId: summary.classSubjectId,
                periodId: summary.periodId,
                classLabel: summary.classLabel,
                subjectLabel: summary.subjectLabel,
                date: summary.date,
                maxScore: summary.maxScore,
                gradedCount: gradedCount,
                totalStudents: summary.totalStudents,
              )
            : summary,
      )
      .toList();
}
