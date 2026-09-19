import 'package:edaya_shared/edaya_shared.dart';

import 'models/teacher_session.dart';

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
}) {
  final today = DateTime(now.year, now.month, now.day);
  final todaySessions = sessions
      .where((session) => session.occursOn(today))
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

bool isCalendarDayToday(DateTime day, [DateTime? reference]) {
  final now = reference ?? DateTime.now();
  return isSameCalendarDay(day, now);
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
