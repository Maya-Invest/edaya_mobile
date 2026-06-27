import 'entity_query.dart';

EntityQuery classGroupScope(String classGroupId) {
  return {'classGroupId': classGroupId};
}

EntityQuery studentScope(String studentId) {
  return {'studentId': studentId};
}

EntityQuery academicYearScope(String academicYearId) {
  return {'academicYearId': academicYearId};
}

EntityQuery sessionScope(String sessionId) {
  return {'sessionId': sessionId};
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

EntityQuery publishedReportCardsForStudent(String studentId) {
  return {
    'studentId': studentId,
    'status': 'published',
  };
}

EntityQuery studentFeesForStudent(String studentId) {
  return studentScope(studentId);
}

EntityQuery paymentsForStudentFees(List<String> studentFeeIds) {
  return recordsForField('studentFeeId', studentFeeIds);
}

EntityQuery deliveriesForSubject(String subjectId) {
  return {'subjectId': subjectId};
}
