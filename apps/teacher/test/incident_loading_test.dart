import 'dart:async';
import 'package:edaya_api_client/edaya_api_client.dart' as api;
import 'package:edaya_shared/edaya_shared.dart';
import 'package:edaya_teacher_v2/features/classes/teacher_discipline_page.dart';
import 'package:flutter_test/flutter_test.dart';

class _Incidents implements api.Transport {
  final paths = <String>[];
  bool failContinuation = false;
  bool denied = false;
  Completer<void>? hold;

  Map<String, dynamic> row(int id) => {
    'id': 'i$id',
    'title': 'Incident $id',
    'description': 'Notes',
    'status': 'open',
    'kind': 'positive',
    'date': '2026-05-01T12:00:00Z',
    'locked': id == 30,
  };

  @override
  Future<T> request<T>(
    String method,
    String path, {
    api.TransportRequestOptions? options,
  }) async {
    final uri = Uri.parse(path);
    paths.add(uri.path);
    Object data;
    if (uri.path.startsWith('/core/teacher/incidents')) {
      expect(method, 'GET');
      expect(uri.queryParameters['classGroupId'], 'c');
      if (denied) throw api.ApiError(403, 'Assignment removed');
    }
    if (uri.path.endsWith('/incidents/detail')) {
      expect(uri.queryParameters['incidentId'], 'i30');
      data = {
        'incident': row(30),
        'eligibility': {
          'locked': true,
          'version': 2,
          'corrections': [],
          'history': [],
          'official': {
            'studentIds': ['former'],
          },
          'context': {
            'students': [
              {'id': 'former', 'name': 'Former pupil'},
            ],
          },
        },
      };
    } else if (uri.path.endsWith('/teacher/incidents')) {
      final pending = hold;
      if (pending != null) await pending.future;
      final next = uri.queryParameters['cursor'] != null;
      if (next && failContinuation) throw api.ApiError(503, 'Try again');
      data = {
        'items': next ? [row(30)] : [for (var i = 0; i < 30; i++) row(i)],
        'nextCursor': next ? null : 'page-two',
      };
    } else if (uri.path.endsWith('/enrollments/list')) {
      data = [
        {'studentId': 'current'},
      ];
    } else if (uri.path.endsWith('/students/list')) {
      data = [
        {'id': 'current', 'firstName': 'A', 'lastName': 'B'},
      ];
    } else {
      throw StateError('Unexpected $path');
    }
    return data as T;
  }
}

void main() {
  TeacherDisciplineController create(
    _Incidents transport, {
    String? id,
    bool edit = false,
  }) => TeacherDisciplineController(
    classId: 'c',
    incidentId: id,
    editFacts: edit,
    client: () => api.createSchoolClient(transport),
    outbox: InMemoryTeacherOutboxStore(),
  );
  test(
    'the list reads one page, retries continuation and clears denied records',
    () async {
      final transport = _Incidents(), controller = create(transport);
      await controller.load();
      expect(transport.paths, ['/core/teacher/incidents']);
      expect(controller.incidents.value, hasLength(30));
      transport.failContinuation = true;
      await controller.load(more: true);
      expect(controller.readFailed.value, isTrue);
      expect(controller.nextCursor.value, 'page-two');
      expect(controller.incidents.value, hasLength(30));
      transport.failContinuation = false;
      await controller.load(more: true);
      expect(controller.incidents.value.last['locked'], true);
      expect(controller.incidents.value, hasLength(31));
      expect(controller.nextCursor.value, isNull);
      await controller.load();
      expect(controller.incidents.value, hasLength(31));
      transport.denied = true;
      await controller.load();
      expect(controller.incidents.value, isEmpty);
      controller.onClose();
    },
  );

  test(
    'direct detail reads one record and loads active pupil choices only for editing',
    () async {
      for (final edit in [false, true]) {
        final transport = _Incidents(),
            controller = create(transport, id: 'i30', edit: edit);
        await controller.load();
        expect(transport.paths, [
          '/core/teacher/incidents/detail',
          if (edit) ...[
            '/core/entities/enrollments/list',
            '/core/entities/students/list',
          ],
        ]);
        expect(controller.incidents.value.single['proposal'], {
          'studentIds': ['former'],
        });
        expect(controller.students.value.map((r) => r['id']), [
          'former',
          if (edit) 'current',
        ]);
        controller.onClose();
      }
    },
  );

  test(
    'late initial response cannot republish after a denied refresh',
    () async {
      final transport = _Incidents(), controller = create(transport);
      final held = transport.hold = Completer<void>();
      final old = controller.load();
      transport.denied = true;
      await controller.load();
      held.complete();
      await old;
      expect(controller.incidents.value, isEmpty);
      expect(controller.readFailed.value, isTrue);
      controller.onClose();
    },
  );
}
