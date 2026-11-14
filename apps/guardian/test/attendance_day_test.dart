import 'package:edaya_guardian_v2/features/calendar/models/attendance_record.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('school attendance day does not shift to the device timezone', () {
    final record = AttendanceRecord.fromJson({
      'id': 'daily',
      'date': '2026-09-18T00:00:00.000Z',
      'status': 'present',
    });
    expect(record.date, DateTime.utc(2026, 9, 18));
    expect(record.date.day, 18);
    expect(record.occurrenceKind, 'daily');
    expect(record.occurrenceId, isEmpty);
  });

  test('session attendance keeps its exact occurrence anchor', () {
    final record = AttendanceRecord.fromJson({
      'id': 'lesson',
      'date': '2026-09-18T00:00:00.000Z',
      'status': 'absent',
      'lessonSessionId': 'lesson-18',
    });
    expect(record.occurrenceKind, 'lesson');
    expect(record.occurrenceId, 'lesson-18');
  });
}
