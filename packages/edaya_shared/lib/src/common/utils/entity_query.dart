typedef EntityQuery = Map<String, dynamic>;

EntityQuery entitiesByIds(List<String> ids) {
  if (ids.isEmpty) {
    return {
      'id': {
        '\$in': ['__no_match__'],
      },
    };
  }

  return {
    'id': {'\$in': ids},
  };
}

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
      field: {
        '\$in': ['__no_match__'],
      },
    };
  }
  return {
    field: {'\$in': ids},
  };
}

EntityQuery recordsForFieldIds(String field, List<String> ids) {
  return recordsForField(field, ids);
}

EntityQuery assignmentsForLessonSessions(List<String> lessonSessionIds) {
  return recordsForFieldIds('lessonSessionId', lessonSessionIds);
}

EntityQuery assignmentsForActivitySessions(List<String> activitySessionIds) {
  return recordsForFieldIds('activitySessionId', activitySessionIds);
}

EntityQuery assignmentsForAssessments(List<String> assessmentIds) {
  return recordsForFieldIds('assessmentId', assessmentIds);
}

EntityQuery assignmentsForClassSubjects(List<String> classSubjectIds) {
  return recordsForFieldIds('classSubjectId', classSubjectIds);
}

EntityQuery progressForLessonSessions(List<String> lessonSessionIds) {
  return recordsForFieldIds('lessonSessionId', lessonSessionIds);
}

EntityQuery attendanceForOccurrence({
  required String kind,
  required String occurrenceId,
}) {
  final field = switch (kind) {
    'activity' => 'activitySessionId',
    'assessment' => 'assessmentId',
    _ => 'lessonSessionId',
  };
  return recordsForFieldIds(field, [occurrenceId]);
}
