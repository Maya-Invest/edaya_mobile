import 'package:edaya_shared/edaya_shared.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('attendanceRecordPayload anchors lesson sessions like the web client', () {
    expect(
      attendanceRecordPayload(
        kind: 'lesson',
        occurrenceId: 'ls-1',
        studentId: 'stu-1',
        attendanceId: 'stu-1-ls-1',
        status: 'present',
        createdAt: '2026-01-10T09:00:00.000Z',
      ),
      {
        'id': 'stu-1-ls-1',
        'studentId': 'stu-1',
        'status': 'present',
        'createdAt': '2026-01-10T09:00:00.000Z',
        'lessonSessionId': 'ls-1',
      },
    );
  });
}
