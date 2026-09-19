import 'package:flutter_test/flutter_test.dart';
import 'package:edaya_teacher_legacy/features/calendar/models/teacher_session.dart';
import 'package:edaya_shared/src/common/models/timetable_occurrence.dart';

void main() {
  test('lesson sessions support attendance recording', () {
    final lesson = TeacherSession.fromOccurrence(
      TimetableOccurrence(
        id: 'ls-1',
        kind: 'lesson',
        title: 'Math',
        subjectLabel: 'Math',
        startsAt: _date,
        endsAt: _date,
        classGroupId: 'cg-1',
      ),
      classLabel: '6A',
    );

    final activity = TeacherSession.fromOccurrence(
      TimetableOccurrence(
        id: 'as-1',
        kind: 'activity',
        title: 'Sport',
        subjectLabel: 'Sport',
        startsAt: _date,
        endsAt: _date,
        classGroupId: 'cg-1',
      ),
      classLabel: '6A',
    );

    expect(lesson.kind, 'lesson');
    expect(activity.kind, 'activity');
    expect(lesson.kind == 'lesson', isTrue);
    expect(activity.kind == 'lesson', isFalse);
  });
}

final _date = DateTime(2026, 1, 10, 9);
