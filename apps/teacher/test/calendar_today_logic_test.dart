import 'package:edaya_teacher/features/calendar/calendar_today_logic.dart';
import 'package:edaya_teacher/features/calendar/models/teacher_session.dart';
import 'package:edaya_shared/edaya_shared.dart';
import 'package:flutter_test/flutter_test.dart';

TeacherSession _session({
  required String id,
  required DateTime startsAt,
  required DateTime endsAt,
}) {
  return TeacherSession.fromOccurrence(
    TimetableOccurrence(
      id: id,
      kind: 'lesson',
      title: 'Math',
      subjectLabel: 'Math',
      startsAt: startsAt,
      endsAt: endsAt,
      classGroupId: 'cg-1',
      classSubjectId: 'cs-1',
    ),
    classLabel: '6A',
  );
}

void main() {
  test('resolveCalendarSessionFocus picks current and next sessions', () {
    final now = DateTime(2026, 4, 1, 10, 30);
    final focus = resolveCalendarSessionFocus(
      sessions: [
        _session(
          id: 'past',
          startsAt: DateTime(2026, 4, 1, 8),
          endsAt: DateTime(2026, 4, 1, 9),
        ),
        _session(
          id: 'current',
          startsAt: DateTime(2026, 4, 1, 10),
          endsAt: DateTime(2026, 4, 1, 11),
        ),
        _session(
          id: 'next',
          startsAt: DateTime(2026, 4, 1, 12),
          endsAt: DateTime(2026, 4, 1, 13),
        ),
      ],
      now: now,
    );

    expect(focus.current?.id, 'current');
    expect(focus.next?.id, 'next');
    expect(focus.todaySessions.map((session) => session.id), [
      'past',
      'current',
      'next',
    ]);
  });

  test('sessionsWithIncompleteAttendance filters only incomplete sessions', () {
    final sessions = [
      _session(
        id: 'complete',
        startsAt: DateTime(2026, 4, 1, 8),
        endsAt: DateTime(2026, 4, 1, 9),
      ),
      _session(
        id: 'open',
        startsAt: DateTime(2026, 4, 1, 10),
        endsAt: DateTime(2026, 4, 1, 11),
      ),
    ];

    final incomplete = sessionsWithIncompleteAttendance(
      todayLessonSessions: sessions,
      completionBySessionId: const {
        'complete': SessionAttendanceCompletion(
          sessionId: 'complete',
          recordedCount: 25,
          totalCount: 25,
        ),
        'open': SessionAttendanceCompletion(
          sessionId: 'open',
          recordedCount: 10,
          totalCount: 25,
        ),
      },
    );

    expect(incomplete.map((session) => session.id), ['open']);
  });
}
