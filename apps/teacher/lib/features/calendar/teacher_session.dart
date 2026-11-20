import 'package:edaya_shared/edaya_shared.dart';

class TeacherSession {
  const TeacherSession({
    required this.id,
    required this.title,
    required this.kind,
    required this.startsAt,
    required this.endsAt,
    required this.classGroupId,
    required this.classLabel,
    required this.subjectLabel,
    this.classSubjectId,
    this.status,
  });

  factory TeacherSession.fromOccurrence(
    TimetableOccurrence occurrence, {
    required String classLabel,
  }) {
    return TeacherSession(
      id: occurrence.id,
      title: occurrence.title,
      kind: occurrence.kind,
      startsAt: occurrence.startsAt,
      endsAt: occurrence.endsAt,
      classGroupId: occurrence.classGroupId,
      classLabel: classLabel,
      subjectLabel: occurrence.subjectLabel,
      classSubjectId: occurrence.classSubjectId,
      status: occurrence.status,
    );
  }

  final String id;
  final String title;
  final String kind;
  final DateTime startsAt;
  final DateTime endsAt;
  final String classGroupId;
  final String classLabel;
  final String subjectLabel;
  final String? classSubjectId;
  final String? status;

  bool occursOn(DateTime day) => isSameCalendarDay(startsAt, day);
}

/// Current session plus the next, or the next two when between lessons.
List<TeacherSession> homeLessonPreview(
  Iterable<TeacherSession> entries, {
  required DateTime now,
  required DateTime Function(DateTime) schoolTime,
  required Iterable<String> classIds,
}) {
  final eligible =
      entries
          .where(
            (session) =>
                session.kind == 'lesson' &&
                classIds.contains(session.classGroupId) &&
                !{'canceled', 'cancelled'}.contains(session.status) &&
                isSameCalendarDay(
                  schoolTime(session.startsAt),
                  schoolTime(now),
                ) &&
                session.endsAt.isAfter(now),
          )
          .toList()
        ..sort((a, b) => a.startsAt.compareTo(b.startsAt));
  final current = eligible.where((s) => !s.startsAt.isAfter(now)).lastOrNull;
  return [
    ?current,
    ...eligible
        .where((s) => s.startsAt.isAfter(now))
        .take(current == null ? 2 : 1),
  ];
}

class CalendarSessionFocus {
  const CalendarSessionFocus({
    this.current,
    this.next,
    required this.todaySessions,
  });

  final TeacherSession? current;
  final TeacherSession? next;
  final List<TeacherSession> todaySessions;
}

class SessionAttendanceCompletion {
  const SessionAttendanceCompletion({
    required this.sessionId,
    required this.recordedCount,
    required this.totalCount,
  });

  final String sessionId;
  final int recordedCount;
  final int totalCount;

  bool get isComplete => totalCount > 0 && recordedCount >= totalCount;
}

CalendarSessionFocus resolveCalendarSessionFocus({
  required List<TeacherSession> sessions,
  required DateTime now,
  DateTime Function(DateTime)? schoolTime,
}) {
  final today = schoolTime?.call(now) ?? now;
  final todaySessions =
      sessions
          .where(
            (session) => isSameCalendarDay(
              schoolTime?.call(session.startsAt) ?? session.startsAt,
              today,
            ),
          )
          .toList()
        ..sort((a, b) => a.startsAt.compareTo(b.startsAt));

  TeacherSession? current;
  for (final session in todaySessions) {
    if (!now.isBefore(session.startsAt) && now.isBefore(session.endsAt)) {
      current = session;
      break;
    }
  }

  TeacherSession? next;
  for (final session in todaySessions) {
    if (session.startsAt.isAfter(now)) {
      next = session;
      break;
    }
  }

  return CalendarSessionFocus(
    current: current,
    next: next,
    todaySessions: todaySessions,
  );
}

List<TeacherSession> sessionsWithIncompleteAttendance({
  required List<TeacherSession> todayLessonSessions,
  required Map<String, SessionAttendanceCompletion> completionBySessionId,
}) {
  return todayLessonSessions.where((session) {
    final completion = completionBySessionId[session.id];
    if (completion == null) {
      return true;
    }
    return !completion.isComplete;
  }).toList();
}
