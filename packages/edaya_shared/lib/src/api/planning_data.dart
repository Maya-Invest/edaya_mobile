import 'package:edaya_api_client/edaya_api_client.dart';

import '../common/models/timetable_occurrence.dart';
import '../common/utils/date_time_parse.dart';
import '../common/utils/entity_query.dart';

class PlanningDateRange {
  const PlanningDateRange({required this.startDate, required this.endDate});

  final String startDate;
  final String endDate;
}

PlanningDateRange defaultPlanningDateRange([DateTime? reference]) {
  final ref = (reference ?? DateTime.now()).toUtc();
  final start = DateTime.utc(ref.year, ref.month - 6, ref.day);
  final end = DateTime.utc(ref.year, ref.month + 6, ref.day);
  return PlanningDateRange(
    startDate: _toDateKey(start),
    endDate: _toDateKey(end),
  );
}

PlanningDateRange planningDateRangeForWeek(DateTime weekStart) {
  final start = weekStart.subtract(const Duration(days: 7));
  final end = weekStart.add(const Duration(days: 13));
  return PlanningDateRange(
    startDate: _toDateKey(start),
    endDate: _toDateKey(end),
  );
}

String _toDateKey(DateTime date) {
  final utc = DateTime.utc(date.year, date.month, date.day);
  return utc.toIso8601String().substring(0, 10);
}

List<String> _uniqueIds(Iterable<String?> ids) {
  return ids.whereType<String>().toSet().toList();
}

List<Map<String, dynamic>> _dedupeById(Iterable<Map<String, dynamic>> rows) {
  final seen = <String>{};
  final result = <Map<String, dynamic>>[];
  for (final row in rows) {
    final id = row['id'] as String?;
    if (id == null || seen.contains(id)) {
      continue;
    }
    seen.add(id);
    result.add(row);
  }
  return result;
}

/// Portal actors (guardians/students) cannot read staff or resource assignments.
/// Treat those lists as optional enrichment and keep timetable loading working.
Future<List<Map<String, dynamic>>> _optionalEntityList(
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

String? _lessonSessionIdForEvent(Map<String, dynamic> event) {
  if (event['kind'] != 'lesson') {
    return null;
  }
  return event['lessonSessionId'] as String? ?? event['id'] as String?;
}

String? _activitySessionIdForEvent(Map<String, dynamic> event) {
  if (event['kind'] != 'activity') {
    return null;
  }
  return event['activitySessionId'] as String? ?? event['id'] as String?;
}

String? _assessmentIdForEvent(Map<String, dynamic> event) {
  if (event['kind'] != 'assessment') {
    return null;
  }
  return event['assessmentId'] as String? ?? event['id'] as String?;
}

String _teacherName(
  List<Map<String, dynamic>> teacherAssignments,
  Map<String, Map<String, dynamic>> teachersById,
  bool Function(Map<String, dynamic> assignment) match,
  String fallback,
) {
  for (final assignment in teacherAssignments) {
    if (assignment['status'] != 'active') {
      continue;
    }
    if (!match(assignment)) {
      continue;
    }
    final teacherId = assignment['teacherId'] as String?;
    final teacher = teacherId == null ? null : teachersById[teacherId];
    if (teacher == null) {
      continue;
    }
    final firstName = teacher['firstName'] as String? ?? '';
    final lastName = teacher['lastName'] as String? ?? '';
    final fullName = '$firstName $lastName'.trim();
    if (fullName.isNotEmpty) {
      return fullName;
    }
  }
  return fallback;
}

String _resolveInstructorName({
  required List<Map<String, dynamic>> teacherAssignments,
  required Map<String, Map<String, dynamic>> teachersById,
  required List<Map<String, dynamic>> staffAssignments,
  required Map<String, Map<String, dynamic>> staffById,
  required bool Function(Map<String, dynamic> assignment) matchTeacher,
  required bool Function(Map<String, dynamic> assignment) matchStaff,
  required String fallback,
}) {
  final teacherLabel = _teacherName(
    teacherAssignments,
    teachersById,
    matchTeacher,
    '',
  );
  if (teacherLabel.isNotEmpty) {
    return teacherLabel;
  }
  return _staffName(staffAssignments, staffById, matchStaff, fallback);
}

String _staffName(
  List<Map<String, dynamic>> staffAssignments,
  Map<String, Map<String, dynamic>> staffById,
  bool Function(Map<String, dynamic> assignment) match,
  String fallback,
) {
  for (final assignment in staffAssignments) {
    if (!match(assignment)) {
      continue;
    }
    final staffId = assignment['staffId'] as String?;
    final teacher = staffId == null ? null : staffById[staffId];
    if (teacher == null) {
      continue;
    }
    final firstName = teacher['firstName'] as String? ?? '';
    final lastName = teacher['lastName'] as String? ?? '';
    final fullName = '$firstName $lastName'.trim();
    if (fullName.isNotEmpty) {
      return fullName;
    }
  }
  return fallback;
}

String _roomName(
  List<Map<String, dynamic>> resourceAssignments,
  Map<String, Map<String, dynamic>> resourceById,
  bool Function(Map<String, dynamic> assignment) match,
) {
  for (final assignment in resourceAssignments) {
    if (!match(assignment)) {
      continue;
    }
    final resourceId = assignment['resourceId'] as String?;
    final resource = resourceId == null ? null : resourceById[resourceId];
    final name = resource?['name'] as String?;
    if (name != null && name.isNotEmpty) {
      return name;
    }
  }
  return '—';
}

Future<List<TimetableOccurrence>> fetchClassTimetableOccurrences(
  SchoolClient client,
  String classGroupId, {
  PlanningDateRange? range,
  String unassignedTeacherLabel = '—',
}) async {
  final resolvedRange = range ?? defaultPlanningDateRange();

  try {
    return await _fetchFromTimetableQuery(
      client,
      classGroupId,
      resolvedRange,
      unassignedTeacherLabel: unassignedTeacherLabel,
    );
  } on ApiError catch (error) {
    if (error.status != 404) {
      rethrow;
    }
  }

  try {
    return await _fetchFromMaterializedSessions(
      client,
      classGroupId,
      resolvedRange,
    );
  } on ApiError catch (error) {
    if (error.status != 404) {
      rethrow;
    }
  }

  return const [];
}

Future<List<TimetableOccurrence>> _fetchFromTimetableQuery(
  SchoolClient client,
  String classGroupId,
  PlanningDateRange resolvedRange, {
  required String unassignedTeacherLabel,
}) async {
  final timetable = await client.getClassGroupTimetable({
    'classGroupId': classGroupId,
    'startDate': resolvedRange.startDate,
    'endDate': resolvedRange.endDate,
  });
  final events = (timetable['events'] as List<dynamic>? ?? const [])
      .whereType<Map<String, dynamic>>()
      .where((event) => event['classGroupId'] == classGroupId)
      .where(
        (event) =>
            const {'lesson', 'activity', 'assessment'}.contains(event['kind']),
      )
      .toList();

  if (events.isEmpty) {
    return const [];
  }

  final lessonSessionIds = _uniqueIds(events.map(_lessonSessionIdForEvent));
  final activitySessionIds = _uniqueIds(events.map(_activitySessionIdForEvent));

  final [
    lessonSessionsRaw,
    activitySessionsRaw,
    classSubjectsRaw,
    classGroupStaffAssignmentsRaw,
    classGroupResourceAssignmentsRaw,
  ] = await Future.wait([
    lessonSessionIds.isEmpty
        ? Future.value(<Map<String, dynamic>>[])
        : client.lessonSessions.list(entitiesByIds(lessonSessionIds)),
    activitySessionIds.isEmpty
        ? Future.value(<Map<String, dynamic>>[])
        : client.activitySessions.list(entitiesByIds(activitySessionIds)),
    _optionalEntityList(
      client.classSubjects.list(classGroupScope(classGroupId)),
    ),
    _optionalEntityList(
      client.staffAssignments.list(classGroupScope(classGroupId)),
    ),
    _optionalEntityList(
      client.resourceAssignments.list(classGroupScope(classGroupId)),
    ),
  ]);

  final lessonSessionsById = {
    for (final session in lessonSessionsRaw) session['id'] as String: session,
  };
  final activitySessionsById = {
    for (final session in activitySessionsRaw) session['id'] as String: session,
  };
  final activityIds = _uniqueIds([
    ...events.map((event) => event['activityId'] as String?),
    ...activitySessionsRaw.map((session) => session['activityId'] as String?),
  ]);
  final classSubjectIds = _uniqueIds(
    classSubjectsRaw.map((entry) => entry['id'] as String?),
  );
  final subjectIds = _uniqueIds(
    classSubjectsRaw.map((entry) => entry['subjectId'] as String?),
  );

  final [
    activitiesRaw,
    sessionStaffAssignmentsRaw,
    classSubjectStaffAssignmentsRaw,
    activityStaffAssignmentsRaw,
    sessionResourceAssignmentsRaw,
    activityResourceAssignmentsRaw,
    subjectsRaw,
    teacherAssignmentsRaw,
  ] = await Future.wait([
    activityIds.isEmpty
        ? Future.value(<Map<String, dynamic>>[])
        : client.activities.list(entitiesByIds(activityIds)),
    lessonSessionIds.isEmpty
        ? Future.value(<Map<String, dynamic>>[])
        : _optionalEntityList(
            client.staffAssignments.list(
              assignmentsForLessonSessions(lessonSessionIds),
            ),
          ),
    classSubjectIds.isEmpty
        ? Future.value(<Map<String, dynamic>>[])
        : _optionalEntityList(
            client.staffAssignments.list(
              assignmentsForClassSubjects(classSubjectIds),
            ),
          ),
    activitySessionIds.isEmpty
        ? Future.value(<Map<String, dynamic>>[])
        : _optionalEntityList(
            client.staffAssignments.list(
              assignmentsForActivitySessions(activitySessionIds),
            ),
          ),
    lessonSessionIds.isEmpty
        ? Future.value(<Map<String, dynamic>>[])
        : _optionalEntityList(
            client.resourceAssignments.list(
              assignmentsForLessonSessions(lessonSessionIds),
            ),
          ),
    activitySessionIds.isEmpty
        ? Future.value(<Map<String, dynamic>>[])
        : _optionalEntityList(
            client.resourceAssignments.list(
              assignmentsForActivitySessions(activitySessionIds),
            ),
          ),
    subjectIds.isEmpty
        ? Future.value(<Map<String, dynamic>>[])
        : _optionalEntityList(client.subjects.list(entitiesByIds(subjectIds))),
    classSubjectIds.isEmpty
        ? Future.value(<Map<String, dynamic>>[])
        : _optionalEntityList(
            client.teacherAssignments.list(
              assignmentsForClassSubjects(classSubjectIds),
            ),
          ),
  ]);

  final staffAssignmentsRaw = _dedupeById([
    ...classGroupStaffAssignmentsRaw,
    ...sessionStaffAssignmentsRaw,
    ...classSubjectStaffAssignmentsRaw,
    ...activityStaffAssignmentsRaw,
  ]);
  final resourceAssignmentsRaw = _dedupeById([
    ...classGroupResourceAssignmentsRaw,
    ...sessionResourceAssignmentsRaw,
    ...activityResourceAssignmentsRaw,
  ]);

  final staffIds = _uniqueIds(
    staffAssignmentsRaw.map((assignment) => assignment['staffId'] as String?),
  );
  final teacherIds = _uniqueIds(
    teacherAssignmentsRaw.map(
      (assignment) => assignment['teacherId'] as String?,
    ),
  );
  final resourceIds = _uniqueIds(
    resourceAssignmentsRaw.map(
      (assignment) => assignment['resourceId'] as String?,
    ),
  );

  final [staffMembersRaw, teachersRaw, resourcesRaw] = await Future.wait([
    staffIds.isEmpty
        ? Future.value(<Map<String, dynamic>>[])
        : _optionalEntityList(
            client.staffMembers.list(entitiesByIds(staffIds)),
          ),
    teacherIds.isEmpty
        ? Future.value(<Map<String, dynamic>>[])
        : _optionalEntityList(client.teachers.list(entitiesByIds(teacherIds))),
    resourceIds.isEmpty
        ? Future.value(<Map<String, dynamic>>[])
        : _optionalEntityList(
            client.resources.list(entitiesByIds(resourceIds)),
          ),
  ]);

  final staffById = {
    for (final member in staffMembersRaw) member['id'] as String: member,
  };
  final teachersById = {
    for (final teacher in teachersRaw) teacher['id'] as String: teacher,
  };
  final resourceById = {
    for (final resource in resourcesRaw) resource['id'] as String: resource,
  };
  final activitiesById = {
    for (final activity in activitiesRaw) activity['id'] as String: activity,
  };
  final subjectById = {
    for (final subject in subjectsRaw) subject['id'] as String: subject,
  };
  final classSubjectById = {
    for (final entry in classSubjectsRaw) entry['id'] as String: entry,
  };

  final occurrences = <TimetableOccurrence>[];
  for (final event in events) {
    final kind = event['kind'] as String? ?? 'lesson';
    final startsAt = parseApiDateTime(event['startsAt']);
    final endsAt = parseApiDateTime(event['endsAt']);
    if (startsAt == null || endsAt == null) {
      continue;
    }

    final title = event['title'] as String? ?? '';
    switch (kind) {
      case 'lesson':
        final lessonSessionId =
            _lessonSessionIdForEvent(event) ?? event['id'] as String;
        final lessonSession = lessonSessionsById[lessonSessionId];
        final classSubjectId =
            event['classSubjectId'] as String? ??
            lessonSession?['classSubjectId'] as String?;
        final classSubject = classSubjectId == null
            ? null
            : classSubjectById[classSubjectId];
        final subject = classSubject == null
            ? null
            : subjectById[classSubject['subjectId'] as String];
        occurrences.add(
          TimetableOccurrence(
            id: lessonSessionId,
            kind: 'lesson',
            title: title,
            subjectLabel: subject?['name'] as String? ?? title,
            startsAt: startsAt.toLocal(),
            endsAt: endsAt.toLocal(),
            classGroupId: classGroupId,
            classSubjectId: classSubjectId,
            status:
                event['status'] as String? ??
                lessonSession?['status'] as String?,
            room: _roomName(
              resourceAssignmentsRaw,
              resourceById,
              (entry) => entry['lessonSessionId'] == lessonSessionId,
            ),
            teacherName: _resolveInstructorName(
              teacherAssignments: teacherAssignmentsRaw,
              teachersById: teachersById,
              staffAssignments: staffAssignmentsRaw,
              staffById: staffById,
              matchTeacher: (entry) =>
                  entry['kind'] == 'subject' &&
                  classSubjectId != null &&
                  entry['classSubjectId'] == classSubjectId,
              matchStaff: (entry) =>
                  entry['lessonSessionId'] == lessonSessionId ||
                  (classSubjectId != null &&
                      entry['classSubjectId'] == classSubjectId),
              fallback: unassignedTeacherLabel,
            ),
          ),
        );
      case 'activity':
        final activitySessionId =
            _activitySessionIdForEvent(event) ?? event['id'] as String;
        final activitySession = activitySessionsById[activitySessionId];
        final activityId =
            event['activityId'] as String? ??
            activitySession?['activityId'] as String?;
        final activity = activityId == null ? null : activitiesById[activityId];
        final staffLabel = _resolveInstructorName(
          teacherAssignments: teacherAssignmentsRaw,
          teachersById: teachersById,
          staffAssignments: staffAssignmentsRaw,
          staffById: staffById,
          matchTeacher: (_) => false,
          matchStaff: (entry) =>
              entry['activitySessionId'] == activitySessionId,
          fallback: unassignedTeacherLabel,
        );
        occurrences.add(
          TimetableOccurrence(
            id: activitySessionId,
            kind: 'activity',
            title: title,
            subjectLabel: activity?['name'] as String? ?? title,
            startsAt: startsAt.toLocal(),
            endsAt: endsAt.toLocal(),
            classGroupId: classGroupId,
            status:
                event['status'] as String? ??
                activitySession?['status'] as String?,
            room: _roomName(
              resourceAssignmentsRaw,
              resourceById,
              (entry) => entry['activitySessionId'] == activitySessionId,
            ),
            teacherName:
                staffLabel == unassignedTeacherLabel &&
                    activity?['coach'] != null
                ? activity!['coach'] as String
                : staffLabel,
          ),
        );
      case 'assessment':
        final assessmentId =
            _assessmentIdForEvent(event) ?? event['id'] as String;
        final classSubjectId = event['classSubjectId'] as String?;
        final classSubject = classSubjectId == null
            ? null
            : classSubjectById[classSubjectId];
        final subject = classSubject == null
            ? null
            : subjectById[classSubject['subjectId'] as String];
        occurrences.add(
          TimetableOccurrence(
            id: assessmentId,
            kind: 'assessment',
            title: title,
            subjectLabel: subject?['name'] as String? ?? title,
            startsAt: startsAt.toLocal(),
            endsAt: endsAt.toLocal(),
            classGroupId: classGroupId,
            classSubjectId: classSubjectId,
            room: _roomName(
              resourceAssignmentsRaw,
              resourceById,
              (entry) => entry['assessmentId'] == assessmentId,
            ),
            teacherName: _resolveInstructorName(
              teacherAssignments: teacherAssignmentsRaw,
              teachersById: teachersById,
              staffAssignments: staffAssignmentsRaw,
              staffById: staffById,
              matchTeacher: (entry) =>
                  entry['kind'] == 'subject' &&
                  classSubjectId != null &&
                  entry['classSubjectId'] == classSubjectId,
              matchStaff: (entry) =>
                  entry['assessmentId'] == assessmentId ||
                  (classSubjectId != null &&
                      entry['classSubjectId'] == classSubjectId),
              fallback: unassignedTeacherLabel,
            ),
          ),
        );
    }
  }

  occurrences.sort((a, b) => a.startsAt.compareTo(b.startsAt));
  return occurrences;
}

Future<List<TimetableOccurrence>> _fetchFromMaterializedSessions(
  SchoolClient client,
  String classGroupId,
  PlanningDateRange range,
) async {
  final dateFilter = {
    '\$gte': '${range.startDate}T00:00:00.000Z',
    '\$lte': '${range.endDate}T23:59:59.999Z',
  };
  final scope = {...classGroupScope(classGroupId), 'startsAt': dateFilter};

  final results = await Future.wait([
    client.lessonSessions.list(scope),
    client.activitySessions.list(scope),
  ]);

  return _materializedSessionsToOccurrences(
    lessonRows: results[0],
    activityRows: results[1],
    classGroupId: classGroupId,
  );
}

List<TimetableOccurrence> _materializedSessionsToOccurrences({
  required List<Map<String, dynamic>> lessonRows,
  required List<Map<String, dynamic>> activityRows,
  required String classGroupId,
}) {
  final occurrences = <TimetableOccurrence>[];

  for (final row in lessonRows) {
    occurrences.add(
      _occurrenceFromSessionRow(
        row,
        classGroupId: classGroupId,
        kind: 'lesson',
      ),
    );
  }

  for (final row in activityRows) {
    occurrences.add(
      _occurrenceFromSessionRow(
        row,
        classGroupId: classGroupId,
        kind: 'activity',
      ),
    );
  }

  occurrences.sort((a, b) => a.startsAt.compareTo(b.startsAt));
  return occurrences;
}

TimetableOccurrence _occurrenceFromSessionRow(
  Map<String, dynamic> row, {
  required String classGroupId,
  required String kind,
}) {
  final startsAt = parseApiDateTime(row['startsAt']);
  final endsAt = parseApiDateTime(row['endsAt']);
  if (startsAt == null || endsAt == null) {
    throw FormatException('Session ${row['id']} has invalid dates');
  }

  final title =
      row['displayLabel'] as String? ?? row['title'] as String? ?? 'Session';
  return TimetableOccurrence(
    id: row['id'] as String,
    kind: kind,
    title: title,
    subjectLabel: title,
    startsAt: startsAt.toLocal(),
    endsAt: endsAt.toLocal(),
    classGroupId: classGroupId,
    classSubjectId: row['classSubjectId'] as String?,
    status: row['status'] as String?,
  );
}
