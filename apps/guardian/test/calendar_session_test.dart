import 'package:edaya_shared/edaya_shared.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:edaya_guardian/features/calendar/models/calendar_session.dart';

void main() {
  test('occursOn matches materialized timetable dates', () {
    final session = CalendarSession(
      id: 'sess-p1',
      title: 'Algebra basics',
      kind: 'lesson',
      startsAt: DateTime(2026, 6, 22, 8, 30),
      endsAt: DateTime(2026, 6, 22, 9, 30),
      classSubjectId: 'cs-6a-math',
    );

    expect(session.occursOn(DateTime(2026, 6, 22)), isTrue);
    expect(session.occursOn(DateTime(2026, 6, 23)), isFalse);
  });

  test('defaultCalendarDay prefers Monday on weekends', () {
    expect(defaultCalendarDay(DateTime(2026, 6, 27)), DateTime(2026, 6, 22));
    expect(defaultCalendarDay(DateTime(2026, 6, 28)), DateTime(2026, 6, 22));
    expect(defaultCalendarDay(DateTime(2026, 6, 25)), DateTime(2026, 6, 25));
  });
}
