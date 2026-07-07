import 'package:flutter_test/flutter_test.dart';

import 'package:edaya_teacher/features/calendar/models/teacher_session.dart';

void main() {
  test('occursOn matches materialized timetable dates', () {
    final session = TeacherSession(
      id: 'sess-p1',
      title: 'Algebra basics',
      kind: 'lesson',
      startsAt: DateTime(2026, 5, 18, 8, 30),
      endsAt: DateTime(2026, 5, 18, 9, 30),
      classGroupId: 'class-6a',
      classLabel: '6A',
      subjectLabel: 'Mathematics',
      classSubjectId: 'cs-6a-math',
    );

    expect(session.occursOn(DateTime(2026, 5, 18)), isTrue);
    expect(session.occursOn(DateTime(2026, 5, 19)), isFalse);
  });
}
