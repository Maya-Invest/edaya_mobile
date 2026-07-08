import 'package:edaya_api_client/edaya_api_client.dart';
import 'package:edaya_shared/src/api/attendance_data.dart';
import 'package:flutter_test/flutter_test.dart';

class _QueuedAttendanceTransport implements Transport {
  _QueuedAttendanceTransport(this.responses);

  final List<Object?> responses;

  @override
  Future<T> request<T>(
    String method,
    String path, {
    TransportRequestOptions? options,
  }) async {
    final next = responses.removeAt(0);
    if (next is Exception) {
      throw next;
    }
    return next as T;
  }
}

void main() {
  test(
    'attendanceRecordPayload anchors lesson sessions like the web client',
    () {
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
    },
  );

  test(
    'listAttendanceForOccurrence treats legacy sessionId fallback 403 as empty',
    () async {
      final transport = _QueuedAttendanceTransport([
        const <Map<String, dynamic>>[],
        ApiError(403, const {'message': 'Operation is not permitted'}),
      ]);
      final client = createSchoolClient(transport);

      final rows = await listAttendanceForOccurrence(
        client.attendance,
        kind: 'lesson',
        occurrenceId: 'sch-ci-6a-math-wed:2026-07-07',
      );

      expect(rows, isEmpty);
    },
  );
}
