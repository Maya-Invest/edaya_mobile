import 'package:edaya_shared/edaya_shared.dart';

class TeachingScope {
  const TeachingScope({
    this.classGroupIds = const {},
    this.classSubjectIds = const {},
  });

  final Set<String> classGroupIds;
  final Set<String> classSubjectIds;
}

EntityQuery teacherAssignmentsForTeacherAndYear({
  required String teacherId,
  required String academicYearId,
}) {
  return {'teacherId': teacherId, 'academicYearId': academicYearId};
}

TeachingScope teachingScopeFromTeacherAssignments(
  List<Map<String, dynamic>> assignments,
) {
  final classGroupIds = <String>{};
  final classSubjectIds = <String>{};

  for (final assignment in assignments) {
    if (assignment['status'] != 'active') {
      continue;
    }

    final kind = assignment['kind'] as String?;
    final classGroupId = assignment['classGroupId'] as String?;
    final classSubjectId = assignment['classSubjectId'] as String?;

    if (kind == 'homeroom' && classGroupId != null && classGroupId.isNotEmpty) {
      classGroupIds.add(classGroupId);
    }
    if (kind == 'subject' &&
        classSubjectId != null &&
        classSubjectId.isNotEmpty) {
      classSubjectIds.add(classSubjectId);
    }
  }

  return TeachingScope(
    classGroupIds: classGroupIds,
    classSubjectIds: classSubjectIds,
  );
}

TeachingScope mergeTeachingScopes(
  TeachingScope primary,
  TeachingScope fallback,
) {
  if (primary.classGroupIds.isNotEmpty || primary.classSubjectIds.isNotEmpty) {
    return primary;
  }
  return fallback;
}

EntityQuery academicPeriodsForYear(String academicYearId) {
  return academicYearScope(academicYearId);
}

EntityQuery assessmentsForClassSubjectPeriod(
  String classSubjectId,
  String periodId,
) {
  return {'classSubjectId': classSubjectId, 'periodId': periodId};
}

EntityQuery resultsForAssessments(List<String> assessmentIds) {
  return recordsForField('assessmentId', assessmentIds);
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

EntityQuery deliveriesForSubject(String subjectId) {
  return {'subjectId': subjectId};
}

EntityQuery deliveriesForTeacher({
  required String subjectId,
  required String teacherId,
  required String schoolId,
}) {
  return {
    'subjectId': subjectId,
    'recipientKind': 'teacher',
    'recipientId': teacherId,
    'schoolId': schoolId,
  };
}

String academicPeriodLabel(Map<String, dynamic> period) {
  return period['name'] as String? ?? period['id'] as String;
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

String? currentAcademicPeriodId(List<Map<String, dynamic>> periods) {
  if (periods.isEmpty) {
    return null;
  }

  final date = DateTime.now();
  final calendarDay = DateTime(date.year, date.month, date.day);

  for (final period in periods) {
    final start = parseApiDateTime(period['startDate']);
    final end = parseApiDateTime(period['endDate']);
    if (start == null || end == null) {
      continue;
    }
    final startDay = DateTime(start.year, start.month, start.day);
    final endDay = DateTime(end.year, end.month, end.day);
    if (!calendarDay.isBefore(startDay) && !calendarDay.isAfter(endDay)) {
      return period['id'] as String;
    }
  }

  return periods.first['id'] as String;
}

List<Map<String, dynamic>> sortAcademicPeriods(
  List<Map<String, dynamic>> periods,
) {
  final sorted = periods.toList(growable: true)
    ..sort((a, b) {
      final aStart = parseApiDateTime(a['startDate']);
      final bStart = parseApiDateTime(b['startDate']);
      if (aStart == null || bStart == null) {
        return 0;
      }
      return aStart.compareTo(bStart);
    });
  return sorted;
}
