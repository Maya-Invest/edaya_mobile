import 'package:edaya_teacher_v2/features/calendar/teacher_session.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  DateTime at(int hours, [int minutes = 0]) =>
      DateTime.utc(2026, 11, 5, hours, minutes);
  TeacherSession lesson(
    String id,
    int start,
    int end, {
    String group = 'a',
    String? status,
  }) => TeacherSession(
    id: id,
    title: id,
    kind: 'lesson',
    startsAt: at(start),
    endsAt: at(end),
    classGroupId: group,
    classLabel: group,
    subjectLabel: 'Maths',
    status: status,
  );
  final sessions = [
    lesson('later', 14, 15, group: 'b'),
    lesson('current', 10, 11),
    lesson('cancelled', 11, 12, status: 'cancelled'),
    lesson('tomorrow', 34, 35),
  ];
  List<String> visible(DateTime now, {List<String> ids = const ['a', 'b']}) =>
      homeLessonPreview(
        sessions,
        now: now,
        schoolTime: (t) => t,
        classIds: ids,
      ).map((s) => s.id).toList();
  test('school-day lesson boundaries and authorized class filter', () {
    expect(visible(at(9, 59)), ['current', 'later']);
    expect(visible(at(10)), ['current', 'later']);
    expect(visible(at(11)), ['later']);
    expect(visible(at(10), ids: ['b']), ['later']);
    expect(visible(at(15)), isEmpty);
  });
  test('uses the school date when a session falls tomorrow in UTC', () {
    final entries = [lesson('late', 25, 26)];
    expect(
      homeLessonPreview(
        entries,
        now: at(23),
        schoolTime: (utc) => utc.subtract(const Duration(hours: 4)),
        classIds: ['a'],
      ).single.id,
      'late',
    );
  });
}
