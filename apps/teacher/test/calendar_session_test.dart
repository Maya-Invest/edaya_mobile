import 'package:flutter_test/flutter_test.dart';

import 'package:edaya_shared/edaya_shared.dart';
import 'package:edaya_teacher/features/calendar/models/teacher_session.dart';

void main() {
  test('projectOntoDay maps recurring timetable slots by weekday', () {
    final session = TeacherSession(
      id: 'sess-1',
      title: 'Maths',
      kind: 'course',
      startsAt: DateTime(2026, 5, 11, 9, 0),
      endsAt: DateTime(2026, 5, 11, 10, 0),
      classGroupId: '6a',
      classLabel: '6th — A',
      subjectLabel: 'Maths',
    );

    final projected = session.projectOntoDay(DateTime(2026, 5, 18));
    expect(projected, isNotNull);
    expect(projected!.startsAt.day, 18);
    expect(projected.startsAt.hour, 9);
  });

  test('defaultCalendarDay prefers Monday on weekends', () {
    final saturday = DateTime(2026, 5, 16);
    final monday = defaultCalendarDay(saturday);
    expect(monday.weekday, DateTime.monday);
  });
}
