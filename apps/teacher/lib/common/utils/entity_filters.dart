import 'package:edaya_shared/edaya_shared.dart';

EntityQuery academicPeriodsForYear(String academicYearId) {
  return academicYearScope(academicYearId);
}

EntityQuery staffAssignmentsForStaff(String staffId) {
  return {'staffId': staffId};
}

EntityQuery classSubjectsForTeacher(String staffId) {
  return {'teacherId': staffId};
}

EntityQuery sessionsForClassGroups(List<String> classGroupIds) {
  return recordsForField('classGroupId', classGroupIds);
}

EntityQuery activeEnrollmentsForClass(
  String classGroupId, {
  String? academicYearId,
}) {
  return {
    'classGroupId': classGroupId,
    'status': 'active',
    'academicYearId': ?academicYearId,
  };
}

EntityQuery assessmentsForClass(String classGroupId) {
  return classGroupScope(classGroupId);
}

EntityQuery assessmentsForClassPeriod(String classGroupId, String periodId) {
  return {'classGroupId': classGroupId, 'periodId': periodId};
}

EntityQuery assessmentsForClassSubjectPeriod(
  String classSubjectId,
  String periodId,
) {
  return {'classSubjectId': classSubjectId, 'periodId': periodId};
}

EntityQuery resultsForAssessment(String assessmentId) {
  return {'assessmentId': assessmentId};
}

EntityQuery publishedReportCardsForClassPeriod(
  String classGroupId,
  String periodId,
) {
  return {
    'classGroupId': classGroupId,
    'periodId': periodId,
    'status': 'published',
  };
}

EntityQuery logbookForClassSubject(String classGroupId, String classSubjectId) {
  return {'classGroupId': classGroupId, 'classSubjectId': classSubjectId};
}
