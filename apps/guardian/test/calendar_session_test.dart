import 'package:edaya_guardian/common/utils/date_time_parse.dart';
import 'package:edaya_guardian/features/calendar/models/calendar_session.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('projectOntoDay maps recurring timetable slots by weekday', () {
    final session = CalendarSession(
      id: 'sess-p1',
      title: 'Algebra basics',
      kind: 'course',
      startsAt: DateTime(2026, 5, 11, 8, 30),
      endsAt: DateTime(2026, 5, 11, 9, 30),
      classSubjectId: 'cs-6a-math',
    );

    final projected = session.projectOntoDay(DateTime(2026, 6, 22));

    expect(projected, isNotNull);
    expect(projected!.startsAt, DateTime(2026, 6, 22, 8, 30));
    expect(projected.endsAt, DateTime(2026, 6, 22, 9, 30));
    expect(session.projectOntoDay(DateTime(2026, 6, 23)), isNull);
  });

  test('defaultCalendarDay prefers Monday on weekends', () {
    expect(
      defaultCalendarDay(DateTime(2026, 6, 27)),
      DateTime(2026, 6, 22),
    );
    expect(
      defaultCalendarDay(DateTime(2026, 6, 28)),
      DateTime(2026, 6, 22),
    );
    expect(
      defaultCalendarDay(DateTime(2026, 6, 25)),
      DateTime(2026, 6, 25),
    );
  });
}
