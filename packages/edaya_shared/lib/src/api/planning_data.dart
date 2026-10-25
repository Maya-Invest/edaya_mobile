import 'package:edaya_api_client/edaya_api_client.dart';

import 'optional_entity_list.dart';
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

String _subjectLabelFromEvent(
  Map<String, dynamic> event, {
  required String title,
  String? enrichedLabel,
}) {
  final fromQuery = event['subjectLabel'] as String?;
  if (fromQuery != null && fromQuery.isNotEmpty) {
    return fromQuery;
  }
  if (enrichedLabel != null && enrichedLabel.isNotEmpty) {
    return enrichedLabel;
  }
  return title;
}

String _teacherNameFromEvent(
  Map<String, dynamic> event, {
  required List<Map<String, dynamic>> teacherAssignments,
  required Map<String, Map<String, dynamic>> teachersById,
  required bool Function(Map<String, dynamic> assignment) match,
  required String fallback,
}) {
  final fromQuery = event['teacherName'] as String?;
  if (fromQuery != null && fromQuery.isNotEmpty) {
    return fromQuery;
  }
  return _teacherName(teacherAssignments, teachersById, match, fallback);
}

/// Teacher-scoped projection already supplies authorized events and display labels.
Future<List<TimetableOccurrence>> fetchTeacherTimetableOccurrences(
  SchoolClient client,
  String teacherId, {
  required PlanningDateRange range,
}) async {
  final timetable = await client.getTeacherTimetable({
    'teacherId': teacherId,
    'startDate': range.startDate,
    'endDate': range.endDate,
  });
  final events = (timetable['events'] as List? ?? const []).cast<Map>();
  return events.map((event) {
    final startsAt = parseApiDateTime(event['startsAt']);
    final endsAt = parseApiDateTime(event['endsAt']);
    if (startsAt == null || endsAt == null) {
      throw const FormatException('Timetable event has invalid dates');
    }
    return TimetableOccurrence(
      id: event['id'] as String,
      kind: event['kind'] as String,
      title: event['title'] as String,
      subjectLabel: (event['subjectLabel'] ?? event['title']) as String,
      startsAt: startsAt,
      endsAt: endsAt,
      classGroupId: event['classGroupId'] as String,
      classSubjectId: event['classSubjectId'] as String?,
      status: event['status'] as String?,
      teacherName: event['teacherName'] as String?,
    );
  }).toList();
}

/// Student participation is resolved by the server across historical class placements.
Future<List<TimetableOccurrence>> fetchStudentTimetableOccurrences(
  SchoolClient client,
  String studentId, {
  PlanningDateRange? range,
}) async {
  final dates = range ?? defaultPlanningDateRange();
  final timetable = await client.getStudentTimetable({
    'studentId': studentId,
    'startDate': dates.startDate,
    'endDate': dates.endDate,
  });
  return (timetable['events'] as List<dynamic>? ?? const [])
      .whereType<Map<String, dynamic>>()
      .where((row) => row['status'] != 'cancelled')
      .map(
        (event) => TimetableOccurrence(
          id: event['id'] as String,
          kind: event['kind'] as String,
          title: event['title'] as String,
          subjectLabel: (event['subjectLabel'] ?? event['title']) as String,
          startsAt: parseApiDateTime(event['startsAt'])!,
          endsAt: parseApiDateTime(event['endsAt'])!,
          classGroupId: event['classGroupId'] as String,
          classSubjectId: event['classSubjectId'] as String?,
          status: event['status'] as String?,
          teacherName: event['teacherName'] as String?,
        ),
      )
      .toList();
}

Future<List<TimetableOccurrence>> fetchClassTimetableOccurrences(
  SchoolClient client,
  String classGroupId, {
  PlanningDateRange? range,
  String unassignedTeacherLabel = '—',

  /// Portal actors (guardian, teacher) cannot read staff workspace entities
  /// used only to enrich labels and teacher names. Skip those HTTP calls and
  /// rely on timetable event titles instead.
  bool enrichStaffWorkspace = true,
}) async {
  final resolvedRange = range ?? defaultPlanningDateRange();

  try {
    return await _fetchFromTimetableQuery(
      client,
      classGroupId,
      resolvedRange,
      unassignedTeacherLabel: unassignedTeacherLabel,
      enrichStaffWorkspace: enrichStaffWorkspace,
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
  required bool enrichStaffWorkspace,
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
  ] = await Future.wait([
    lessonSessionIds.isEmpty
        ? Future.value(<Map<String, dynamic>>[])
        : client.lessonSessions.list(entitiesByIds(lessonSessionIds)),
    activitySessionIds.isEmpty
        ? Future.value(<Map<String, dynamic>>[])
        : client.activitySessions.list(entitiesByIds(activitySessionIds)),
    enrichStaffWorkspace
        ? optionalEntityList(
            client.classSubjects.list(classGroupScope(classGroupId)),
          )
        : Future.value(<Map<String, dynamic>>[]),
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
    subjectsRaw,
    teacherAssignmentsRaw,
  ] = enrichStaffWorkspace
      ? await Future.wait([
          activityIds.isEmpty
              ? Future.value(<Map<String, dynamic>>[])
              : optionalEntityList(
                  client.activities.list(entitiesByIds(activityIds)),
                ),
          subjectIds.isEmpty
              ? Future.value(<Map<String, dynamic>>[])
              : optionalEntityList(
                  client.subjects.list(entitiesByIds(subjectIds)),
                ),
          classSubjectIds.isEmpty
              ? Future.value(<Map<String, dynamic>>[])
              : optionalEntityList(
                  client.teacherAssignments.list(
                    assignmentsForClassSubjects(classSubjectIds),
                  ),
                ),
        ])
      : [
          <Map<String, dynamic>>[],
          <Map<String, dynamic>>[],
          <Map<String, dynamic>>[],
        ];

  final teacherIds = enrichStaffWorkspace
      ? _uniqueIds(
          teacherAssignmentsRaw.map(
            (assignment) => assignment['teacherId'] as String?,
          ),
        )
      : const <String>[];

  final teachersRaw = !enrichStaffWorkspace || teacherIds.isEmpty
      ? <Map<String, dynamic>>[]
      : await optionalEntityList(
          client.teachers.list(entitiesByIds(teacherIds)),
        );
  final teachersById = {
    for (final teacher in teachersRaw) teacher['id'] as String: teacher,
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
            subjectLabel: _subjectLabelFromEvent(
              event,
              title: title,
              enrichedLabel: subject?['name'] as String?,
            ),
            startsAt: startsAt.toLocal(),
            endsAt: endsAt.toLocal(),
            classGroupId: classGroupId,
            classSubjectId: classSubjectId,
            status:
                event['status'] as String? ??
                lessonSession?['status'] as String?,
            teacherName: _teacherNameFromEvent(
              event,
              teacherAssignments: teacherAssignmentsRaw,
              teachersById: teachersById,
              match: (entry) =>
                  entry['kind'] == 'subject' &&
                  classSubjectId != null &&
                  entry['classSubjectId'] == classSubjectId,
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
        occurrences.add(
          TimetableOccurrence(
            id: activitySessionId,
            kind: 'activity',
            title: title,
            subjectLabel: _subjectLabelFromEvent(
              event,
              title: title,
              enrichedLabel: activity?['name'] as String?,
            ),
            startsAt: startsAt.toLocal(),
            endsAt: endsAt.toLocal(),
            classGroupId: classGroupId,
            status:
                event['status'] as String? ??
                activitySession?['status'] as String?,
            teacherName: _teacherNameFromEvent(
              event,
              teacherAssignments: teacherAssignmentsRaw,
              teachersById: teachersById,
              match: (_) => false,
              fallback: unassignedTeacherLabel,
            ),
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
            subjectLabel: _subjectLabelFromEvent(
              event,
              title: title,
              enrichedLabel: subject?['name'] as String?,
            ),
            startsAt: startsAt.toLocal(),
            endsAt: endsAt.toLocal(),
            classGroupId: classGroupId,
            classSubjectId: classSubjectId,
            teacherName: _teacherNameFromEvent(
              event,
              teacherAssignments: teacherAssignmentsRaw,
              teachersById: teachersById,
              match: (entry) =>
                  entry['kind'] == 'subject' &&
                  classSubjectId != null &&
                  entry['classSubjectId'] == classSubjectId,
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
