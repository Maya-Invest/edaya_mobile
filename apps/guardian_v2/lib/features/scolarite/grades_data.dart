import 'package:edaya_api_client/edaya_api_client.dart' as api;
import 'package:edaya_shared/edaya_shared.dart';

class StudentGradeSources {
  const StudentGradeSources({
    required this.results,
    this.gradingPolicy,
    required this.assessmentById,
    required this.subjectNameByClassSubjectId,
  });

  final GradingPolicyView? gradingPolicy;
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

  GradingPolicyView? policy;
  try {
    final group = await client.classGroups.get(classGroupId);
    final level = await client.gradeLevels.get(group['gradeLevelId'] as String);
    final policies =
        ((level['gradingPolicies'] as List?) ?? const [])
            .whereType<Map>()
            .where((row) => row['academicYearId'] == group['academicYearId'])
            .toList()
          ..sort(
            (a, b) => (b['revision'] as num).compareTo(a['revision'] as num),
          );
    if (policies.isNotEmpty) {
      policy = GradingPolicyView(Map<String, dynamic>.from(policies.first));
    }
  } on Object {
    // Configured results will not fall back to legacy /20 calculations.
  }
  return StudentGradeSources(
    gradingPolicy: policy,
    results: resultRows,
    assessmentById: assessmentById,
    subjectNameByClassSubjectId: subjectNameByClassSubjectId,
  );
}
