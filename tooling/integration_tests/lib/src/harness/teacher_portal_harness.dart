import 'package:edaya_api_client/edaya_api_client.dart';

import '../config/integration_config.dart';
import '../config/teacher_portal_profile.dart';
import 'portal_session.dart';

typedef EntityQuery = Map<String, dynamic>;

class TeacherTeachingScope {
  const TeacherTeachingScope({
    this.classGroupIds = const {},
    this.classSubjectIds = const {},
  });

  final Set<String> classGroupIds;
  final Set<String> classSubjectIds;
}

/// Resolved state after mirroring the teacher app bootstrap chain.
class TeacherPortalContext {
  const TeacherPortalContext({
    required this.profile,
    required this.grants,
    required this.academicYears,
    required this.teacherAssignments,
    required this.academicPeriods,
    required this.teachingScope,
    required this.assignedClassGroups,
    required this.classSubjects,
  });

  final TeacherPortalProfile profile;
  final EffectiveGrantsResponse grants;
  final List<Map<String, dynamic>> academicYears;
  final List<Map<String, dynamic>> teacherAssignments;
  final List<Map<String, dynamic>> academicPeriods;
  final TeacherTeachingScope teachingScope;
  final List<Map<String, dynamic>> assignedClassGroups;
  final List<Map<String, dynamic>> classSubjects;

  String? get firstPeriodId {
    if (academicPeriods.isEmpty) {
      return null;
    }
    return academicPeriods.first['id'] as String?;
  }

  /// Period used for grade write probes — demo-ci publishes Trimestre 1 only
  /// and leaves T1 bulletins unpublished so writes do not 409.
  String? get writeProbePeriodId {
    if (academicPeriods.isEmpty) {
      return null;
    }
    return academicPeriods.first['id'] as String?;
  }

  String get primaryClassGroupId => profile.primaryClassGroupId;
}

class TeacherSessionProbe {
  const TeacherSessionProbe({
    required this.lessonSessionId,
    required this.classGroupId,
    required this.classSubjectId,
    required this.enrollments,
    required this.students,
    required this.attendanceRows,
    required this.lessonSession,
    required this.classSubjectMatters,
    required this.classSubjectProgress,
  });

  final String lessonSessionId;
  final String classGroupId;
  final String? classSubjectId;
  final List<Map<String, dynamic>> enrollments;
  final List<Map<String, dynamic>> students;
  final List<Map<String, dynamic>> attendanceRows;
  final Map<String, dynamic> lessonSession;
  final List<Map<String, dynamic>> classSubjectMatters;
  final List<Map<String, dynamic>> classSubjectProgress;

  String? get firstStudentId {
    if (students.isEmpty) {
      return null;
    }
    return students.first['id'] as String?;
  }
}

class TeacherEvaluationsProbe {
  const TeacherEvaluationsProbe({
    required this.assessments,
    required this.enrollments,
    required this.assessmentResults,
    required this.classSubject,
    required this.subject,
  });

  final List<Map<String, dynamic>> assessments;
  final List<Map<String, dynamic>> enrollments;
  final List<Map<String, dynamic>> assessmentResults;
  final Map<String, dynamic>? classSubject;
  final Map<String, dynamic>? subject;
}

String isoDate(DateTime value) => value.toIso8601String().split('T').first;

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

EntityQuery teacherAssignmentsQuery({
  required String teacherId,
  required String academicYearId,
}) {
  return {'teacherId': teacherId, 'academicYearId': academicYearId};
}

EntityQuery academicPeriodsForYear(String academicYearId) {
  return {'academicYearId': academicYearId};
}

EntityQuery activeEnrollmentsForClass(
  String classGroupId, {
  required String academicYearId,
}) {
  return {
    'classGroupId': classGroupId,
    'status': 'active',
    'academicYearId': academicYearId,
  };
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

EntityQuery attendanceForLessonSession(String lessonSessionId) {
  return {'lessonSessionId': lessonSessionId};
}

TeacherTeachingScope teachingScopeFromAssignments(
  List<Map<String, dynamic>> assignments,
) {
  final classGroupIds = <String>{};
  final classSubjectIds = <String>{};

  for (final assignment in assignments) {
    final now = DateTime.now();
    final startsAt = assignment['startsAt'] == null
        ? null
        : DateTime.parse(assignment['startsAt'] as String);
    final endsAt = assignment['endsAt'] == null
        ? null
        : DateTime.parse(assignment['endsAt'] as String);
    if (assignment['status'] != 'active' ||
        (startsAt != null && startsAt.isAfter(now)) ||
        (endsAt != null && !endsAt.isAfter(now))) {
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

  return TeacherTeachingScope(
    classGroupIds: classGroupIds,
    classSubjectIds: classSubjectIds,
  );
}

Future<List<Map<String, dynamic>>> optionalEntityList(
  Future<List<Map<String, dynamic>>> future,
) async {
  try {
    return await future;
  } on ApiError catch (error) {
    if (error.status == 403) {
      return const [];
    }
    rethrow;
  }
}

/// Mirrors [TeacherContextController.reloadContext] + [AcademicYearController.loadYears].
Future<TeacherPortalContext> bootstrapTeacherPortal(
  PortalSession session,
  TeacherPortalProfile profile,
) async {
  final client = session.schoolClient;
  final grants = await client.effectiveGrants();

  final academicYears = await client.academicYears.list();
  final teacher = await client.teachers.get(grants.actorId);
  if (teacher.isEmpty) {
    throw StateError('teacher profile read returned empty payload');
  }

  final assignments = await client.teacherAssignments.list(
    teacherAssignmentsQuery(
      teacherId: grants.actorId,
      academicYearId: profile.academicYearId,
    ),
  );

  final academicPeriods = await client.academicPeriods.list(
    academicPeriodsForYear(profile.academicYearId),
  );

  final teachingScope = teachingScopeFromAssignments(assignments);

  final classSubjectRows = teachingScope.classSubjectIds.isEmpty
      ? <Map<String, dynamic>>[]
      : await client.classSubjects.list(
          entitiesByIds(teachingScope.classSubjectIds.toList()),
        );

  final allClassGroupIds = {
    ...teachingScope.classGroupIds,
    ...classSubjectRows.map((row) => row['classGroupId'] as String),
  };

  final assignedClassGroups = <Map<String, dynamic>>[];
  for (final classGroupId in allClassGroupIds) {
    assignedClassGroups.add(await client.classGroups.get(classGroupId));
  }

  return TeacherPortalContext(
    profile: profile,
    grants: grants,
    academicYears: academicYears,
    teacherAssignments: assignments,
    academicPeriods: academicPeriods,
    teachingScope: teachingScope,
    assignedClassGroups: assignedClassGroups,
    classSubjects: classSubjectRows,
  );
}

/// Mirrors [CalendarController.loadCalendarData] timetable reads per class.
Future<Map<String, List<dynamic>>> loadCalendarTimetables(
  SchoolClient client,
  Iterable<String> classGroupIds, {
  DateTime? referenceDay,
}) async {
  final anchor =
      referenceDay ?? IntegrationConfig.fromEnvironment().calendarReferenceDay;
  final startDate = isoDate(anchor.subtract(const Duration(days: 7)));
  final endDate = isoDate(anchor.add(const Duration(days: 14)));
  final eventsByClass = <String, List<dynamic>>{};

  for (final classGroupId in classGroupIds) {
    final timetable = await client.getClassGroupTimetable({
      'classGroupId': classGroupId,
      'startDate': startDate,
      'endDate': endDate,
    });
    eventsByClass[classGroupId] = timetable['events'] as List<dynamic>? ?? [];
  }

  return eventsByClass;
}

Future<String?> findLessonSessionId(
  List<dynamic> events, {
  String? classSubjectId,
}) async {
  for (final event in events) {
    if (event is! Map<String, dynamic>) {
      continue;
    }
    if (event['kind'] != 'lesson') {
      continue;
    }
    if (classSubjectId != null &&
        event['classSubjectId'] != null &&
        event['classSubjectId'] != classSubjectId) {
      continue;
    }
    return event['lessonSessionId'] as String? ?? event['id'] as String?;
  }
  return null;
}

/// Fallback when timetable query returns no lesson events (mirrors planning_data).
Future<String?> findMaterializedLessonSessionId(
  SchoolClient client,
  String classGroupId, {
  PlanningDateRange? range,
  String? classSubjectId,
}) async {
  final resolvedRange = range ?? _defaultPlanningDateRange();
  final dateFilter = {
    '\$gte': '${resolvedRange.startDate}T00:00:00.000Z',
    '\$lte': '${resolvedRange.endDate}T23:59:59.999Z',
  };
  final rows = await client.lessonSessions.list({
    'classGroupId': classGroupId,
    'classSubjectId': ?classSubjectId,
    'startsAt': dateFilter,
  });
  if (rows.isEmpty) {
    return null;
  }
  return rows.first['id'] as String?;
}

class PlanningDateRange {
  const PlanningDateRange({required this.startDate, required this.endDate});

  final String startDate;
  final String endDate;
}

PlanningDateRange _defaultPlanningDateRange() {
  final anchor = IntegrationConfig.fromEnvironment().calendarReferenceDay;
  return PlanningDateRange(
    startDate: isoDate(anchor.subtract(const Duration(days: 7))),
    endDate: isoDate(anchor.add(const Duration(days: 14))),
  );
}

/// Resolves a lesson session id from timetable events or materialized sessions.
Future<String?> resolveLessonSessionIdForClass(
  SchoolClient client, {
  required String classGroupId,
  required List<dynamic> timetableEvents,
  String? classSubjectId,
}) async {
  final fromTimetable = await findLessonSessionId(
    timetableEvents,
    classSubjectId: classSubjectId,
  );
  if (fromTimetable != null) {
    return fromTimetable;
  }
  return findMaterializedLessonSessionId(
    client, classGroupId, classSubjectId: classSubjectId,
  );
}

/// Mirrors [SessionDetailController.loadDetail] reads for a lesson session.
Future<TeacherSessionProbe> loadTeacherSessionDetail(
  SchoolClient client, {
  required String lessonSessionId,
  required String classGroupId,
  required String academicYearId,
}) async {
  final lessonSession = await client.lessonSessions.get(lessonSessionId);
  final classSubjectId = lessonSession['classSubjectId'] as String?;

  final enrollmentRows = await client.enrollments.list(
    activeEnrollmentsForClass(classGroupId, academicYearId: academicYearId),
  );
  final studentIds = enrollmentRows
      .map((row) => row['studentId'] as String?)
      .whereType<String>()
      .toList();
  final students = studentIds.isEmpty
      ? <Map<String, dynamic>>[]
      : await client.students.list(entitiesByIds(studentIds));

  final attendanceRows = await client.attendance.list(
    attendanceForLessonSession(lessonSessionId),
  );

  final classSubjectMatters = classSubjectId == null
      ? <Map<String, dynamic>>[]
      : await client.classSubjectMatters.list({
          'classSubjectId': classSubjectId,
        });

  final matterIds = classSubjectMatters
      .map((row) => row['subjectMatterId'] as String?)
      .whereType<String>()
      .toList();
  if (matterIds.isNotEmpty) {
    await client.subjectMatters.list(entitiesByIds(matterIds));
  }

  final classSubjectProgress = await client.classSubjectProgress.list({
    'lessonSessionId': lessonSessionId,
  });

  return TeacherSessionProbe(
    lessonSessionId: lessonSessionId,
    classGroupId: classGroupId,
    classSubjectId: classSubjectId,
    enrollments: enrollmentRows,
    students: students,
    attendanceRows: attendanceRows,
    lessonSession: lessonSession,
    classSubjectMatters: classSubjectMatters,
    classSubjectProgress: classSubjectProgress,
  );
}

/// Mirrors [EvaluationsController.loadEvaluations] reads for taught subjects.
Future<TeacherEvaluationsProbe> loadTeacherEvaluations(
  SchoolClient client, {
  required String classGroupId,
  required String periodId,
  required String academicYearId,
  required List<String> classSubjectIds,
}) async {
  final assessments = <Map<String, dynamic>>[];
  for (final classSubjectId in classSubjectIds) {
    final rows = await client.assessments.list(
      assessmentsForClassSubjectPeriod(classSubjectId, periodId),
    );
    assessments.addAll(rows);
  }
  final enrollments = await client.enrollments.list(
    activeEnrollmentsForClass(classGroupId, academicYearId: academicYearId),
  );

  final assessmentResults = assessments.isEmpty
      ? <Map<String, dynamic>>[]
      : await client.assessmentResults.list(
          resultsForAssessment(assessments.first['id'] as String),
        );

  Map<String, dynamic>? classSubject;
  Map<String, dynamic>? subject;
  if (assessments.isNotEmpty) {
    final classSubjectId = assessments.first['classSubjectId'] as String?;
    if (classSubjectId != null) {
      classSubject = await client.classSubjects.get(classSubjectId);
      final subjectId = classSubject['subjectId'] as String?;
      if (subjectId != null) {
        subject = await client.subjects.get(subjectId);
      }
    }
  }

  return TeacherEvaluationsProbe(
    assessments: assessments,
    enrollments: enrollments,
    assessmentResults: assessmentResults,
    classSubject: classSubject,
    subject: subject,
  );
}

/// Mirrors [SessionDetailController.recordAttendance] write + read-back.
Future<void> recordLessonAttendance(
  SchoolClient client, {
  required String lessonSessionId,
  required String studentId,
  String status = 'present',
}) async {
  final attendanceId = '$studentId-$lessonSessionId';
  await client.recordAttendance({
    'id': attendanceId,
    'studentId': studentId,
    'lessonSessionId': lessonSessionId,
    'status': status,
    'createdAt': DateTime.now().toUtc().toIso8601String(),
  });

  final rows = await client.attendance.list(
    attendanceForLessonSession(lessonSessionId),
  );
  final saved = rows.any(
    (row) => row['studentId'] == studentId && row['status'] == status,
  );
  if (!saved) {
    throw StateError(
      'attendance write did not persist for student $studentId on $lessonSessionId',
    );
  }
}

/// Mirrors evaluation create + mark entry writes for a subject teacher.
Future<void> probeTeacherEvaluationWrites(
  SchoolClient client, {
  required String classGroupId,
  required String classSubjectId,
  required String periodId,
  required String academicYearId,
}) async {
  final asmId = 'asm-it-${DateTime.now().millisecondsSinceEpoch}';
  final now = DateTime.now().toUtc();
  final startsAt = DateTime.utc(now.year, now.month, now.day, 9);
  await client.createAssessment({
    'id': asmId,
    'classGroupId': classGroupId,
    'classSubjectId': classSubjectId,
    'periodId': periodId,
    'title': 'Integration probe',
    'kind': 'quiz',
    'maxScore': 20,
    'coefficient': 1,
    'attachments': <Map<String, dynamic>>[],
    'createdAt': now.toIso8601String(),
    'startsAt': startsAt.toIso8601String(),
    'endsAt': startsAt.add(const Duration(hours: 1)).toIso8601String(),
  });

  final listed = await client.assessments.list(
    assessmentsForClassSubjectPeriod(classSubjectId, periodId),
  );
  if (!listed.any((row) => row['id'] == asmId)) {
    throw StateError('createAssessment did not appear in assessments.list');
  }

  final enrollments = await client.enrollments.list(
    activeEnrollmentsForClass(classGroupId, academicYearId: academicYearId),
  );
  if (enrollments.isEmpty) {
    throw StateError('expected enrollments for $classGroupId');
  }
  // Demo-ci seeds published report cards for all but the last-ranked student per
  // class; grade writes fail with 409 when the bulletin is published.
  final studentId = enrollments.last['studentId'] as String;

  await client.recordAssessmentResult({
    'id': 'ar-$asmId-$studentId',
    'studentId': studentId,
    'assessmentId': asmId,
    'score': 12,
    'createdAt': now.toIso8601String(),
  });

  final results = await client.assessmentResults.list(
    resultsForAssessment(asmId),
  );
  final saved = results.any(
    (row) => row['studentId'] == studentId && row['score'] == 12,
  );
  if (!saved) {
    throw StateError('recordAssessmentResult did not persist for $studentId');
  }
}

Future<void> loadTimetableEnrichment(
  SchoolClient client, {
  required String classGroupId,
  required String academicYearId,
  required List<dynamic> events,
}) async {
  final lessonSessionIds = <String>{};
  final activitySessionIds = <String>{};

  for (final event in events) {
    if (event is! Map<String, dynamic>) {
      continue;
    }
    if (event['kind'] == 'lesson') {
      final id = event['lessonSessionId'] as String? ?? event['id'] as String?;
      if (id != null) {
        lessonSessionIds.add(id);
      }
    }
    if (event['kind'] == 'activity') {
      final id =
          event['activitySessionId'] as String? ?? event['id'] as String?;
      if (id != null) {
        activitySessionIds.add(id);
      }
    }
  }

  if (lessonSessionIds.isNotEmpty) {
    await client.lessonSessions.list(entitiesByIds(lessonSessionIds.toList()));
  }
  if (activitySessionIds.isNotEmpty) {
    await client.activitySessions.list(
      entitiesByIds(activitySessionIds.toList()),
    );
  }

  await optionalEntityList(
    client.classSubjects.list({'classGroupId': classGroupId}),
  );
  await optionalEntityList(
    client.teacherAssignments.list({'academicYearId': academicYearId}),
  );
}
