import 'package:edaya_api_client/edaya_api_client.dart' as api;
import 'package:edaya_shared/edaya_shared.dart';

class StudentGradeSources {
  const StudentGradeSources({
    required this.results,
    required this.assessmentById,
    required this.subjectNameByClassSubjectId,
  });

  final List<Map<String, dynamic>> results;
  final Map<String, Map<String, dynamic>> assessmentById;
  final Map<String, String> subjectNameByClassSubjectId;
}

Future<StudentGradeSources> fetchStudentGradeSources({
  required api.SchoolClient client,
  required String studentId,
  required String classGroupId,
  required String subjectFallback,
}) async {
  final classSubjectRows = await client.classSubjects.list(
    catalogQuery(classGroupScope(classGroupId)),
  );
  final subjectIds = classSubjectRows
      .map((row) => row['subjectId'] as String?)
      .whereType<String>()
      .toSet()
      .toList();
  final subjectRows = subjectIds.isEmpty
      ? <Map<String, dynamic>>[]
      : await client.subjects.list(catalogQuery(entitiesByIds(subjectIds)));
  final subjectNameById = {
    for (final subject in subjectRows)
      subject['id'] as String:
          subject['name'] as String? ?? subject['id'] as String,
  };
  final subjectNameByClassSubjectId = {
    for (final classSubject in classSubjectRows)
      classSubject['id'] as String:
          subjectNameById[classSubject['subjectId'] as String] ??
          classSubject['subjectId'] as String? ??
          subjectFallback,
  };

  final resultRows = await client.assessmentResults.list(
    catalogQuery(studentScope(studentId)),
  );
  final assessmentIds = resultRows
      .map((row) => row['assessmentId'] as String?)
      .whereType<String>()
      .toSet()
      .toList();
  final assessmentRows = assessmentIds.isEmpty
      ? <Map<String, dynamic>>[]
      : await client.assessments.list(
          catalogQuery(entitiesByIds(assessmentIds)),
        );
  final assessmentById = {
    for (final assessment in assessmentRows)
      assessment['id'] as String: assessment,
  };

  return StudentGradeSources(
    results: resultRows,
    assessmentById: assessmentById,
    subjectNameByClassSubjectId: subjectNameByClassSubjectId,
  );
}
