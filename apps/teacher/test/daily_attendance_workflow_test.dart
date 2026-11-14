import 'dart:async';
import 'package:edaya_api_client/edaya_api_client.dart' as api;
import 'package:edaya_shared/edaya_shared.dart';
import 'package:edaya_teacher_v2/features/classes/daily_attendance_page.dart';
import 'package:flutter_test/flutter_test.dart';

class _Client extends Fake implements api.SchoolClient {
  final writes = <Map<String, dynamic>>[];
  bool submitted = false;
  bool offline = false;
  int reads = 0;
  @override
  Future<Map<String, dynamic>> runQuery(
    String name,
    Map<String, dynamic> input,
  ) async {
    reads++;
    return {
      'version': 2,
      'submitted': submitted,
      'students': [
        {'id': 'a', 'firstName': 'Ada', 'lastName': 'L'},
        {'id': 'b', 'firstName': 'Grace', 'lastName': 'H'},
      ],
      'entries': submitted
          ? [
              {'studentId': 'a', 'status': 'absent'},
              {'studentId': 'b', 'status': 'present'},
            ]
          : [],
      'records': submitted
          ? [
              {
                'id': 'record-a',
                'studentId': 'a',
                'status': 'absent',
                'workflowVersion': 5,
              },
            ]
          : [],
    };
  }

  @override
  Future<Map<String, dynamic>> runCommand(
    String name,
    Map<String, dynamic> input,
  ) async {
    writes.add({'command': name, ...input});
    if (offline) throw TimeoutException('offline');
    return {'version': 3};
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'finishing requires a full roster and marking remaining students preserves an absence',
    () async {
      final client = _Client();
      final controller = DailyAttendanceController(
        classId: 'class',
        client: () => client,
        outbox: InMemoryTeacherOutboxStore(),
      );
      await controller.load();
      await controller.finish();
      expect(client.writes, isEmpty);
      await controller.setStatus('a', 'absent');
      await controller.markRemainingPresent();
      expect(controller.rows.value.first['status'], 'absent');
      expect(controller.rows.value.last['status'], 'present');
      expect(
        client.writes.every(
          (w) => w['command'] == 'save-teacher-attendance-draft',
        ),
        isTrue,
      );
    },
  );
  test(
    'offline correction uses cached official version and never overlays the official record',
    () async {
      final client = _Client()..submitted = true;
      final store = InMemoryTeacherOutboxStore();
      final controller = DailyAttendanceController(
        classId: 'class',
        client: () => client,
        outbox: store,
      );
      await controller.load();
      client.offline = true;
      final reads = client.reads;
      await controller.setStatus(
        'a',
        'present',
        reason: 'Original register checked',
        teacherExplanation: 'Entry error',
      );
      expect(client.reads, reads);
      expect(client.writes.single['expectedVersion'], 5);
      expect(controller.rows.value.first['status'], 'absent');
      final queued = (await store.listPending()).single;
      expect(queued.state, TeacherOutboxState.pending);
      expect(queued.payload['command'], 'request-teacher-correction');
    },
  );
}
