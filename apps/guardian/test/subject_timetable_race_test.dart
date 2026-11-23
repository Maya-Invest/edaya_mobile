import 'dart:async';

import 'package:edaya_api_client/edaya_api_client.dart' as api;
import 'package:edaya_auth/edaya_auth.dart';
import 'package:edaya_guardian_v2/features/calendar/calendar_controller.dart';
import 'package:edaya_guardian_v2/features/calendar/session_detail_controller.dart';
import 'package:edaya_guardian_v2/features/context/academic_year_controller.dart';
import 'package:edaya_guardian_v2/features/context/student_context_controller.dart';
import 'package:edaya_guardian_v2/features/home/home_controller.dart';
import 'package:edaya_guardian_v2/features/scolarite/subject_logbook_controller.dart';
import 'package:edaya_guardian_v2/features/my_students/linked_student.dart';
import 'package:edaya_shared/edaya_shared.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:levit_flutter/levit_flutter.dart';

class _Students implements StudentContextController {
  @override
  final activeStudent = LxVar<LinkedStudent?>(child('first'));
  @override
  final isLoading = LxVar(false);
  @override
  GuardianPupilSelection? get verifiedSelection => activeStudentId == null
      ? null
      : (
          accountId: 'account',
          schoolId: 'school',
          guardianId: 'guardian',
          academicYearId: 'year',
          studentId: activeStudentId!,
        );

  @override
  String? get activeStudentId => activeStudent.value?.id;
  @override
  String? get activeYearId => 'year';
  @override
  final classGroupId = LxVar<String?>('class');
  @override
  final classLabel = LxVar<String?>('Class');
  @override
  final isEnrolled = LxVar(true);
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Year implements AcademicYearController {
  @override
  final selectedYearId = LxVar<String?>('year');
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Session implements AppSessionController {
  @override
  final user = LxVar<AuthUser?>(null);
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

LinkedStudent child(String id) =>
    LinkedStudent(id: id, firstName: id, lastName: 'Child', status: 'active');

class _Transport implements api.Transport {
  final pending = <Completer<Map<String, dynamic>>>[];
  final students = <String>[];
  @override
  Future<T> request<T>(
    String method,
    String path, {
    api.TransportRequestOptions? options,
  }) async {
    if (path.endsWith('/get-student-timetable')) {
      students.add((options!.body as Map)['studentId'] as String);
      final response = Completer<Map<String, dynamic>>();
      pending.add(response);
      return await response.future as T;
    }
    return <Map<String, dynamic>>[] as T;
  }
}

class _LogbookTransport implements api.Transport {
  final sessionReads = <String>[];

  @override
  Future<T> request<T>(
    String method,
    String path, {
    api.TransportRequestOptions? options,
  }) async {
    if (path.endsWith('/get-student-subject-enrollments')) {
      return {
            'enrollments': [
              for (final id in ['one', 'two'])
                {'classSubjectId': id, 'enrolledAt': '2020-01-01'},
            ],
            'offerings': [
              for (final id in ['one', 'two'])
                {'id': id, 'classGroupId': 'class', 'subjectId': 'music'},
            ],
          }
          as T;
    }
    if (path.endsWith('/subjects/list'))
      return <Map<String, dynamic>>[
            {'id': 'music', 'name': 'Music'},
          ]
          as T;
    if (path.endsWith('/lesson-sessions/list'))
      sessionReads.add((options!.body as Map)['classSubjectId'] as String);
    return <Map<String, dynamic>>[] as T;
  }
}

class _DetailTransport implements api.Transport {
  final abortedStudents = <String>[];
  final pending = <Completer<Map<String, dynamic>>>[];
  Map<String, dynamic> lesson(String title) => {
    'occurrence': {
      'id': 'session',
      'kind': 'lesson',
      'title': title,
      'classSubjectId': 'music',
      'startsAt': '2026-10-01T10:00:00Z',
      'endsAt': '2026-10-01T11:00:00Z',
    },
  };
  @override
  Future<T> request<T>(
    String method,
    String path, {
    api.TransportRequestOptions? options,
  }) async {
    expect(method, 'GET');
    final uri = Uri.parse(path);
    expect(uri.path, '/core/guardian/calendar/occurrence');
    unawaited(
      options!.abortTrigger!.then(
        (_) => abortedStudents.add(uri.queryParameters['studentId']!),
      ),
    );
    final response = Completer<Map<String, dynamic>>();
    pending.add(response);
    return await response.future as T;
  }
}

Map<String, dynamic> timetable(String id) {
  final today = defaultCalendarDay();
  return {
    'events': [
      {
        'id': id,
        'kind': 'lesson',
        'title': id,
        'classGroupId': 'class',
        'classSubjectId': id,
        'startsAt': DateTime(
          today.year,
          today.month,
          today.day,
          10,
        ).toIso8601String(),
        'endsAt': DateTime(
          today.year,
          today.month,
          today.day,
          11,
        ).toIso8601String(),
      },
    ],
  };
}

Future<void> until(bool Function() ready) async {
  for (var i = 0; i < 100; i++) {
    if (ready()) return;
    await Future<void>.delayed(const Duration(milliseconds: 1));
  }
  fail('Timetable request did not finish');
}

void main() {
  test(
    'an offering ID chooses its own logbook when two offerings share a name',
    () async {
      final transport = _LogbookTransport();
      final students = _Students();
      final controller = SubjectLogbookController(
        subject: 'two',
        byId: true,
        studentContext: students,
        schoolClient: () => api.createSchoolClient(transport),
      );
      controller.onInit();
      addTearDown(controller.onClose);
      await until(
        () =>
            transport.sessionReads.isNotEmpty ||
            controller.errorMessage.value.isNotEmpty,
      );
      await until(() => !controller.isBusy.value);
      expect(transport.sessionReads, ['two']);
      expect(controller.subjectLabel.value, 'Music');
      expect(controller.errorMessage.value, isEmpty);
    },
  );

  test(
    'lesson detail reloads on a child switch without reusing an active task id',
    () async {
      final students = _Students();
      final transport = _DetailTransport();
      final controller = SessionDetailController(
        sessionId: 'session',
        academicYear: _Year(),
        studentContext: students,
        schoolClient: () => api.createSchoolClient(transport),
      );
      controller.onInit();
      addTearDown(controller.onClose);
      await until(() => transport.pending.length == 1);
      students.activeStudent(child('second'));
      await until(() => transport.pending.length == 2);
      await until(() => transport.abortedStudents.contains('first'));
      transport.pending[1].complete(transport.lesson('second'));
      await until(() => controller.session.value != null);
      transport.pending[0].complete(transport.lesson('first'));
      await until(() => !controller.isBusy.value);
      expect(controller.session.value?.title, 'second');
      expect(controller.errorMessage.value, isEmpty);
    },
  );

  for (final home in [false, true]) {
    test(
      '${home ? 'home' : 'calendar'} keeps the selected child timetable when earlier requests finish last',
      () async {
        final students = _Students();
        if (!home) students.isEnrolled(false);
        final year = _Year();
        final transport = _Transport();
        final calendar = CalendarController(
          studentContext: students,
          academicYear: year,
          schoolClient: () => api.createSchoolClient(transport),
        );
        final dashboard = HomeController(
          studentContext: students,
          academicYear: year,
          session: _Session(),
          schoolClient: () => api.createSchoolClient(transport),
        );
        final controller = home ? dashboard : calendar;
        controller.onInit();
        addTearDown(controller.onClose);
        await until(() => transport.pending.length == 1);
        students.activeStudent(child('second'));
        await until(() => transport.pending.length == 2);
        transport.pending[1].complete(timetable('music'));
        List<String> ids() => home
            ? dashboard.todayPlan.value?.sessions.map((s) => s.id).toList() ??
                  []
            : calendar.sessions.value.map((s) => s.id).toList();
        await until(() => ids().isNotEmpty);
        transport.pending[0].complete(timetable('painting'));
        await until(
          () => !(home ? dashboard.isBusy.value : calendar.isBusy.value),
        );
        expect(transport.students, ['first', 'second']);
        expect(ids(), ['music']);
        if (!home) expect(calendar.dataStatus, DataStatus.ready);
        students.activeStudent(null);
        await until(() => ids().isEmpty);
      },
    );
  }
}
