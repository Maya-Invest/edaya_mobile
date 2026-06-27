import 'entity_query.dart';

EntityQuery classGroupScope(String classGroupId) {
  return {'classGroupId': classGroupId};
}

EntityQuery academicYearScope(String academicYearId) {
  return {'academicYearId': academicYearId};
}

EntityQuery academicPeriodsForYear(String academicYearId) {
  return academicYearScope(academicYearId);
}

EntityQuery sessionScope(String sessionId) {
  return {'sessionId': sessionId};
}

EntityQuery studentScope(String studentId) {
  return {'studentId': studentId};
}

EntityQuery recordsForField(String field, List<String> ids) {
  if (ids.isEmpty) {
    return {
      field: {'\$in': ['__no_match__']},
    };
  }
  return {
    field: {'\$in': ids},
  };
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
