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

EntityQuery attendanceForSession(String sessionId) {
  return sessionScope(sessionId);
}

EntityQuery activeEnrollmentsForClass(String classGroupId) {
  return {
    'classGroupId': classGroupId,
    'status': 'active',
  };
}

EntityQuery assessmentsForClass(String classGroupId) {
  return classGroupScope(classGroupId);
}

EntityQuery assessmentsForClassPeriod(String classGroupId, String periodId) {
  return {
    'classGroupId': classGroupId,
    'periodId': periodId,
  };
}

EntityQuery resultsForAssessment(String assessmentId) {
  return {'assessmentId': assessmentId};
}

EntityQuery logbookForClassSubject(String classGroupId, String classSubjectId) {
  return {
    'classGroupId': classGroupId,
    'classSubjectId': classSubjectId,
  };
}
