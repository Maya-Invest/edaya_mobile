@Tags(['integration'])
library;

import 'dart:async';
import 'package:flutter/services.dart';
import 'package:http/http.dart'
    show ClientException, BaseRequest, StreamedResponse;

import 'package:edaya_auth/edaya_auth.dart';
import 'package:edaya_teacher_v2/app/workspace_navigation.dart';
import 'package:edaya_teacher_v2/features/offline/teacher_outbox_controller.dart';
import 'package:edaya_api_client/edaya_api_client.dart';
import 'package:edaya_integration_tests/edaya_integration_tests.dart';
import 'package:edaya_shared/edaya_shared.dart';
import 'package:edaya_teacher_v2/features/home/home_lesson_list.dart';
import 'package:edaya_teacher_v2/features/home/home_timetable_controller.dart';
import 'package:edaya_teacher_v2/features/calendar/calendar_page.dart';
import 'package:edaya_teacher_v2/features/calendar/live_calendar_controller.dart';
import 'package:edaya_teacher_v2/features/context/teacher_context_controller.dart';
import 'package:edaya_teacher_v2/features/classes/daily_attendance_page.dart';
import 'package:edaya_teacher_v2/features/classes/teacher_discipline_page.dart';
import 'package:edaya_teacher_v2/features/evaluations/evaluations_page.dart';
import 'package:edaya_teacher_v2/features/evaluations/teacher_gradebook_page.dart';
import 'package:edaya_teacher_v2/features/evaluations/live_evaluations_controller.dart';
import 'package:edaya_teacher_v2/features/evaluations/live_marks_controller.dart';
import 'package:edaya_teacher_v2/features/evaluations/pupil_mark_correction_sheet.dart';
import 'package:edaya_teacher_v2/features/session/logbook_page.dart';
import 'package:edaya_teacher_v2/features/session/roll_call.dart';
import 'package:edaya_teacher_v2/design/components/surface_card.dart';
import 'package:edaya_teacher_v2/features/signature/signature_editor_page.dart';
import 'package:edaya_teacher_v2/features/signature/teacher_signature_controller.dart';
import 'package:edaya_teacher_v2/features/session/attendance_page.dart';
import 'package:edaya_teacher_v2/features/session/session_detail_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:levit_flutter/levit_flutter.dart';
import 'support/integration_test_lifecycle.dart';
import 'support/live_api_test_binding.dart';
import 'support/teacher_live_widget_test_harness.dart';

class _RegisterTransport extends SwitchableTransport {
  final statusClasses = <String?>[];
  int detailReads = 0;

  @override
  Future<StreamedResponse> send(BaseRequest request) {
    if (request.method == 'GET' &&
        request.url.path.endsWith('/daily-attendance-status')) {
      statusClasses.add(request.url.queryParameters['classGroupId']);
    }
    if (request.url.path.endsWith('/get-teacher-attendance-call'))
      detailReads++;
    return super.send(request);
  }
}

class _TimetableTransport extends SwitchableTransport {
  Completer<void>? holdNext;
  final held = Completer<void>();
  @override
  Future<StreamedResponse> send(BaseRequest request) async {
    if (request.url.path.endsWith('/get-teacher-timetable')) {
      if (offline)
        throw ClientException('Test timetable read unavailable', request.url);
      final gate = holdNext;
      if (gate != null) {
        holdNext = null;
        held.complete();
        await gate.future;
      }
    }
    return super.send(request);
  }
}

Future<void> until(WidgetTester tester, Finder finder) async {
  final deadline = DateTime.now().add(const Duration(seconds: 30));
  while (DateTime.now().isBefore(deadline)) {
    await tester.pump(const Duration(milliseconds: 100));
    if (tester.any(finder)) return;
    final bootstrapFailure = find.textContaining('Bootstrap failed:');
    if (tester.any(bootstrapFailure)) {
      fail(tester.widget<Text>(bootstrapFailure.first).data!);
    }
  }
  fail('Expected teacher workflow widget: $finder');
}

Future<void> reveal(WidgetTester tester, Finder finder) async {
  FocusManager.instance.primaryFocus?.unfocus();
  await tester.pump(const Duration(milliseconds: 350));
  await until(tester, finder);
  await Scrollable.ensureVisible(tester.element(finder), alignment: 0.5);
  await tester.pump(const Duration(milliseconds: 350));
  await until(tester, finder.hitTestable());
}

/// Exercise the same enabled action through its narrow-screen overflow menu.
Future<void> tapPageAction(WidgetTester tester, String label) async {
  final deadline = DateTime.now().add(const Duration(seconds: 30));
  while (DateTime.now().isBefore(deadline)) {
    await tester.pump(const Duration(milliseconds: 200));
    var target = find.text(label).hitTestable();
    final menu = find.byType(FloatingActionButton).hitTestable();
    if (!tester.any(target)) {
      final overflow = tester.any(menu)
          ? menu
          : find.byType(PopupMenuButton<String>);
      if (!tester.any(overflow)) continue;
      await tester.ensureVisible(overflow.first);
      await tester.tap(overflow.first);
      await tester.pump(const Duration(milliseconds: 300));
      target = find.text(label).hitTestable();
    }
    final enabled = find.ancestor(
      of: target,
      matching: find.byWidgetPredicate(
        (w) =>
            (w is ListTile && w.enabled) ||
            (w is FloatingActionButton && w.onPressed != null) ||
            (w is PopupMenuItem && w.enabled) ||
            (w is ButtonStyleButton && w.onPressed != null),
      ),
    );
    if (tester.any(target) && tester.any(enabled)) {
      await tester.tap(target.first);
      await tester.pump(const Duration(milliseconds: 300));
      return;
    }
    if (tester.any(find.byType(PopupMenuItem<int>)) ||
        tester.any(find.byType(PopupMenuItem<String>))) {
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump(const Duration(milliseconds: 300));
    }
  }
  fail('Enabled session action unavailable: $label');
}

Future<void> gone(WidgetTester tester, Type type) async {
  final deadline = DateTime.now().add(const Duration(seconds: 10));
  final finder = find.byType(type, skipOffstage: false);
  while (tester.any(finder) && DateTime.now().isBefore(deadline)) {
    await tester.pump(const Duration(milliseconds: 100));
  }
  expect(finder, findsNothing);
}

Future<T> persisted<T>(
  WidgetTester tester,
  Future<T> Function() read,
  bool Function(T) ready, {
  Duration timeout = const Duration(seconds: 20),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (true) {
    final value = await read();
    if (ready(value)) return value;
    if (DateTime.now().isAfter(deadline)) {
      fail('Expected persisted workflow result');
    }
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Finder field(String label) => find.byWidgetPredicate(
  (widget) => widget is TextField && widget.decoration?.labelText == label,
);

T findController<T extends LevitController>(
  WidgetTester tester,
  Finder finder,
) => tester
    .element(
      find.descendant(of: finder, matching: find.byType(Scrollable)).first,
    )
    .levit
    .find<T>();

Future<void> enterAllMarks(
  WidgetTester tester,
  String assessmentId,
  String score,
) async {
  final pane = find.byElementPredicate(
    (e) =>
        e.widget is EvaluationMarksPane &&
        (e.widget as EvaluationMarksPane).evaluationId == assessmentId &&
        ModalRoute.of(e)?.isCurrent == true,
  );
  await until(
    tester,
    find.descendant(of: pane, matching: find.byType(SingleChildScrollView)),
  );
  final controller = findController<LiveMarksController>(tester, pane);
  await persisted(
    tester,
    () async => controller.students.value,
    (rows) => rows.isNotEmpty,
  );
  final before = await harnessMarks(tester, controller);
  for (final pupil in controller.students.value) {
    final input = find.descendant(
      of: pane,
      matching: find.byKey(ValueKey('score-${pupil.studentId}')),
    );
    final scroll = find
        .descendant(of: pane, matching: find.byType(Scrollable))
        .first;
    if (!tester.any(input))
      await tester.scrollUntilVisible(input, 140, scrollable: scroll);
    await tester.ensureVisible(input);
    await tester.enterText(input, score);
    await tester.pump();
  }
  // Editing the roster does not mutate the confirmed controller rows.
  expect(controller.students.value.map((r) => r.score).toList(), before);
  FocusManager.instance.primaryFocus?.unfocus();
  await tester.pump();
  final save = find.descendant(
    of: pane,
    matching: find.widgetWithText(FilledButton, 'Enregistrer'),
  );
  await until(tester, save.hitTestable());
  await tester.tap(save);
  await persisted(tester, () async => !controller.writing.value, (v) => v);
  expect(controller.hasUnsaved, isFalse, reason: controller.saveMessage.value);
}

Future<List<double?>> harnessMarks(
  WidgetTester tester,
  LiveMarksController controller,
) async => controller.students.value.map((r) => r.score).toList();

Future<void> main() async {
  LiveApiWidgetTestBinding();
  Levit.enableAutoLinking();
  await initializeDateFormatting('fr_FR');
  final skip = await resolveIntegrationSkipReason();
  if (skip != null) {
    testWidgets('teacher workflows disabled', (_) async {}, skip: true);
    return;
  }
  const profile = TeacherPortalProfile.subjectTeacher;
  const markRemainingKey = ValueKey('roll-mark-remaining');
  final markRemaining = find.byKey(markRemainingKey);
  late TeacherLiveWidgetTestHarness harness;
  late PortalSession baseline;
  late PortalSession owner;
  setUpAll(() async {
    baseline = (await TeacherLiveWidgetTestHarness.create()).portalSession;
    owner = await PortalSession.signIn(
      config: IntegrationConfig.fromEnvironment().withSchoolOwnerEmail(),
      actorKind: 'staff',
      academicYearId: profile.academicYearId,
    );
  });
  setUp(() async {
    harness = await TeacherLiveWidgetTestHarness.create(
      authenticatedSession: baseline,
    );
  });
  Future<void> mount(WidgetTester tester, String route) async {
    await resetIntegrationTestSurface(tester);
    await configureDesignReviewViewport(tester, DesignReviewFormFactor.phone);
    addTearDown(() async {
      await resetIntegrationTestSurface(tester);
      await resetIntegrationTestViewport(tester);
    });
    await tester.pumpWidget(harness.buildRouterApp(initialRoute: route));
  }

  Future<Map<String, dynamic>> lessonFixture() async {
    final lessons = await owner.schoolClient.lessonSessions.list({
      'classSubjectId': profile.expectedClassSubjectIds.first,
    });
    expect(lessons, isNotEmpty, reason: 'Required assigned lesson fixture');
    final row = {
      ...lessons.first,
      'id': 'ui-lesson-${DateTime.now().microsecondsSinceEpoch}',
      'sessionNote': null,
    };
    row['displayLabel'] = row['id'];
    await owner.schoolClient.lessonSessions.save(row);
    return row;
  }

  testWidgets(
    '[teacher-v2.navigation.sheets] opens class and date pickers as routed sheets',
    (tester) async {
      await mount(tester, '/home');
      await until(tester, find.byKey(const ValueKey('home-profile')));
      await tester.tap(find.byIcon(Icons.expand_more).first);
      await until(tester, find.byType(ClassContextPicker));
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byType(BottomSheet), findsOneWidget);
      final assignment = harness.scope
          .find<TeacherContextController>()
          .activeAssignment!;
      await until(tester, find.text(assignment.label));
      expect(find.text('Toutes les classes'), findsNothing);
      await tester.tap(find.text(assignment.label).last);
      await gone(tester, ClassContextPicker);
      await tester.tap(find.text('Agenda').first);
      await until(tester, find.byType(CalendarPage));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.tap(find.byIcon(Icons.calendar_today_outlined).first);
      await until(tester, find.byType(CalendarDatePicker));
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byType(BottomSheet), findsOneWidget);
      harness.scope.find<GoRouter>().pop();
      await gone(tester, CalendarDatePicker);
      await tester.tap(find.widgetWithText(Tab, 'Historique'));
      await until(tester, find.byType(SessionHistoryPanel));
      final history = findController<SessionHistoryController>(
        tester,
        find.byType(SessionHistoryPanel),
      );
      await persisted(
        tester,
        () async => !history.busy.value,
        (ready) => ready,
      );
      expect(history.error.value, isFalse);
      expect(
        harness.scope
            .find<GoRouter>()
            .routeInformationProvider
            .value
            .uri
            .queryParameters['tab'],
        'history',
      );
      if (history.hasMore.value) {
        final entries = history.entries.value.length;
        await history.load();
        await tester.pump();
        expect(history.error.value, isFalse);
        expect(history.entries.value.length, greaterThanOrEqualTo(entries));
      }
      await harness.scope.find<TeacherContextController>().reloadContext();
      await tester.pump();
      expect(
        findController<SessionHistoryController>(
          tester,
          find.byType(SessionHistoryPanel),
        ),
        same(history),
      );
      expect(find.byType(CalendarPage), findsOneWidget);
      expect(
        harness.scope.find<GoRouter>().routeInformationProvider.value.uri.path,
        '/calendar',
      );
    },
  );

  test(
    '[teacher-v2.messaging.start] creates one selected-guardian conversation across retries',
    () async {
      final api = baseline.schoolClient;
      final recipients = await api.runQuery(
        'list-teacher-guardian-recipients',
        {'studentId': 'ci-s1', 'classGroupId': profile.primaryClassGroupId},
      );
      final guardians = (recipients['guardians'] as List).cast<Map>();
      expect(guardians, isNotEmpty);
      final guardian = guardians.first;
      final request = {
        'requestId': newSchoolRequestId(),
        'studentId': 'ci-s1',
        'classGroupId': profile.primaryClassGroupId,
        'guardianId': guardian['id'],
        'subject':
            'Teacher v2 initiation ${DateTime.now().microsecondsSinceEpoch}',
        'body': 'Question individuelle de test',
      };
      final first = await api.runCommand('start-teacher-conversation', request);
      final retried = await api.runCommand(
        'start-teacher-conversation',
        request,
      );
      expect(retried['id'], first['id']);
      final saved = await api.runQuery('get-conversation', {
        'conversationId': first['id'],
      });
      expect((saved['conversation'] as Map)['guardianId'], guardian['id']);
      expect((saved['conversation'] as Map)['status'], 'awaiting_guardian');
      expect((saved['messages'] as List).length, 1);
    },
  );

  test(
    '[teacher-v2.discipline.register] associates a pupil to a saved incident and reopens both records',
    () async {
      final api = baseline.schoolClient;
      final incidentId = newSchoolRequestId();
      final incident = {
        'id': incidentId,
        'schoolId': harness.context.grants.schoolId,
        'classGroupId': profile.primaryClassGroupId,
        'date': DateTime.now().toUtc().toIso8601String(),
        'kind': 'minor_infraction',
        'title': 'Teacher v2 incident',
        'description': 'Faits vérifiables',
      };
      await api.runCommand('record-incident', incident);
      final involvement = {
        'id': newSchoolRequestId(),
        'incidentId': incidentId,
        'studentId': 'ci-s1',
        'role': 'subject',
      };
      await api.runCommand('add-student-involvement', involvement);
      final saved = await api.incidents.get(incidentId);
      expect(saved['description'], incident['description']);
      final links = await api.studentIncidentInvolvements.list({
        'incidentId': incidentId,
      });
      expect(links.length, 1);
      expect(links.single['studentId'], 'ci-s1');
    },
  );

  testWidgets(
    '[teacher-v2.messaging.reply] receives an eligible guardian question and replies from the teacher inbox',
    (tester) async {
      final config = IntegrationConfig.fromEnvironment();
      const family = GuardianPortalProfile.mariamKone;
      final guardianSession = await PortalSession.signIn(
        config: config.withGuardianEmail(family.email),
        actorKind: 'guardian',
        academicYearId: profile.academicYearId,
      );
      await bootstrapGuardianPortal(guardianSession, family);
      final recipients = await guardianSession.schoolClient.runQuery(
        'list-conversation-recipients',
        {'studentId': family.primaryStudentId},
      );
      final target = (recipients['teachers'] as List).cast<Map>().firstWhere(
        (r) => r['id'] == harness.context.grants.actorId,
      );
      final subject = 'Homework ${DateTime.now().microsecondsSinceEpoch}';
      final conversation = await guardianSession.schoolClient
          .runCommand('start-conversation', {
            'requestId': subject,
            'destination': 'teacher',
            'teacherId': target['id'],
            'studentId': family.primaryStudentId,
            'subject': subject,
            'body': 'Which exercise should we complete?',
          });
      await mount(tester, '/inbox');
      await until(tester, find.text(subject));
      await tester.tap(find.text(subject));
      await until(tester, find.byType(ConversationPage));
      await until(tester, field('Répondre'));
      await tester.enterText(
        field('Répondre'),
        'Please complete exercise three.',
      );
      await tester.tap(find.text('Envoyer'));
      await persisted(
        tester,
        () => guardianSession.schoolClient.runQuery('get-conversation', {
          'conversationId': conversation['id'],
        }),
        (row) => (row['messages'] as List).any(
          (message) => message['body'] == 'Please complete exercise three.',
        ),
      );
    },
  );
  testWidgets(
    '[teacher-v2.attendance.save] records a complete roster and persists after reopening',
    (tester) async {
      final lesson = await lessonFixture();
      final id = lesson['id'] as String;
      final initialCall = await baseline.schoolClient.runQuery(
        'get-teacher-attendance-call',
        {
          'anchor': {'kind': 'lesson', 'lessonSessionId': id},
        },
      );
      expect(initialCall['students'] as List, isNotEmpty);
      await mount(tester, '/session/$id/attendance');
      await until(tester, find.byType(AttendanceStatusPicker));
      await until(
        tester,
        find
            .byWidgetPredicate((w) => w is ChoiceChip && w.onSelected != null)
            .hitTestable(),
      );
      final ordered = (initialCall['students'] as List).cast<Map>().toList()
        ..sort(
          (a, b) => "${a['firstName']} ${a['lastName']}".compareTo(
            "${b['firstName']} ${b['lastName']}",
          ),
        );
      final firstStudent = ordered.first;
      final fullName =
          "${firstStudent['firstName']} ${firstStudent['lastName']}";
      final pupilButton = find.byTooltip(fullName);
      final pupilCard = find
          .ancestor(of: pupilButton, matching: find.byType(SurfaceCard))
          .first;
      for (final label in ['Présent', 'Absent']) {
        final chip = find.descendant(
          of: pupilCard,
          matching: find.byWidgetPredicate(
            (w) => w is ChoiceChip && w.tooltip == label,
          ),
        );
        await reveal(tester, chip);
        await tester.tap(chip);
        await persisted(tester, () async {
          final snapshot = await baseline.schoolClient.runQuery(
            'get-teacher-attendance-call',
            {
              'anchor': {'kind': 'lesson', 'lessonSessionId': id},
            },
          );
          return (snapshot['entries'] as List)
              .whereType<Map>()
              .where((r) => r['studentId'] == firstStudent['id'])
              .firstOrNull?['status'];
        }, (status) => status == (label == 'Présent' ? 'present' : 'absent'));
      }
      await reveal(tester, pupilButton);
      await tester.tap(pupilButton);
      final selectedChip = find.descendant(
        of: find.byType(BottomSheet),
        matching: find.widgetWithText(ChoiceChip, 'Absent'),
      );
      await until(tester, selectedChip);
      expect(tester.widget<ChoiceChip>(selectedChip).selected, isTrue);
      await tester.tap(find.text('Fermer'));
      await gone(tester, BottomSheet);
      await tapPageAction(tester, 'Marquer les élèves restants présents');
      await until(tester, find.text('Présent'));
      expect(
        await baseline.schoolClient.attendance.list({'lessonSessionId': id}),
        isEmpty,
      );
      await tapPageAction(tester, 'Terminer l’appel');
      final call = await baseline.schoolClient.runQuery(
        'get-teacher-attendance-call',
        {
          'anchor': {'kind': 'lesson', 'lessonSessionId': id},
        },
      );
      final roster = call['students'] as List;
      final rows = await persisted(
        tester,
        () => baseline.schoolClient.attendance.list({'lessonSessionId': id}),
        (rows) =>
            rows.length == roster.length &&
            rows.every(
              (row) =>
                  row['status'] ==
                  (row['studentId'] == firstStudent['id']
                      ? 'absent'
                      : 'present'),
            ),
      );
      expect(rows.map((row) => row['studentId']).toSet().length, rows.length);
      harness.scope.find<GoRouter>().go('/home');
      await gone(tester, AttendancePage);
      harness.scope.find<GoRouter>().go('/session/$id/attendance');
      await until(tester, find.text('Présent'));
      expect(find.byType(AttendanceStatusPicker), findsNothing);
      expect(find.text('Présent'), findsWidgets);
    },
  );

  testWidgets(
    '[teacher-v2.daily-attendance.submit] homeroom daily call stays private until Finish',
    (tester) async {
      const homeroom = TeacherPortalProfile.homeroomTeacher;
      final session = await PortalSession.signIn(
        config: baseline.config.withTeacherEmail(homeroom.email),
        actorKind: 'teacher',
        academicYearId: homeroom.academicYearId,
      );
      final transport = _RegisterTransport();
      addTearDown(transport.close);
      final auth = AuthClient(
        baseUrl: session.config.authUrl,
        client: transport,
      )..restoreRenewalCredential(session.authClient.renewalCredential!);
      harness = await TeacherLiveWidgetTestHarness.create(
        profile: homeroom,
        authenticatedSession: PortalSession(
          config: session.config,
          authClient: auth,
          schoolClient: session.schoolClient,
          actorKind: 'teacher',
        ),
      );
      final teacherId = harness.context.grants.actorId;
      final original = await owner.schoolClient.classGroups.get('ci-6b');
      final classId = fixtureId('daily-class');
      await owner.schoolClient.classGroups.save({
        ...original,
        'id': classId,
        'name': classId,
        'attendanceMode': 'daily',
      });
      await owner.schoolClient.teacherAssignments.save({
        'id': fixtureId('daily-assignment'),
        'teacherId': teacherId,
        'academicYearId': profile.academicYearId,
        'classGroupId': classId,
        'kind': 'homeroom',
        'status': 'active',
      });
      final studentId = fixtureId('daily-student');
      await owner.schoolClient.registerStudent({
        'requestId': fixtureId('register'),
        'id': studentId,
        'schoolId': harness.context.grants.schoolId,
        'firstName': 'Integration',
        'lastName': studentId,
        'sendAccountInvitation': false,
        'createdAt': '2026-09-01T00:00:00.000Z',
      });
      await owner.schoolClient.enrollStudent({
        'id': fixtureId('daily-enrollment'),
        'studentId': studentId,
        'classGroupId': classId,
        'createdAt': '2026-09-01T00:00:00.000Z',
      });
      await mount(tester, '/home');
      await until(tester, find.byKey(const ValueKey('home-profile')));
      final context = harness.scope.find<TeacherContextController>();
      await context.selectClass(classId);
      expect(context.activeAssignment?.classGroupId, classId);
      await until(tester, find.text('Faire l’appel du jour'));
      expect(
        transport.statusClasses.where((id) => id == classId),
        hasLength(1),
      );
      expect(transport.detailReads, 0);
      await tapPageAction(tester, 'Faire l’appel du jour');
      await until(tester, find.byType(AttendanceStatusPicker));
      expect(transport.detailReads, greaterThan(0));
      final controller = findController<DailyAttendanceController>(
        tester,
        find.byType(DailyAttendancePage),
      );
      await persisted(
        tester,
        () async => !controller.busy.value && controller.rows.value.isNotEmpty,
        (ready) => ready,
      );
      await tester.pump();
      await tapPageAction(tester, 'Marquer les élèves restants présents');
      await until(tester, find.text('Présent'));
      await persisted(
        tester,
        () async => controller.busy.value,
        (busy) => !busy,
      );
      final call = await harness.portalSession.schoolClient.runQuery(
        'get-teacher-attendance-call',
        {'anchor': controller.anchor},
      );
      expect(call['submitted'], false);
      expect(call['records'], isEmpty);
      await tapPageAction(tester, 'Terminer l’appel');
      await persisted(
        tester,
        () => harness.portalSession.schoolClient.runQuery(
          'get-teacher-attendance-call',
          {'anchor': controller.anchor},
        ),
        (call) => call['submitted'] == true,
      );
      await persisted(
        tester,
        () async => controller.submitted.value && !controller.busy.value,
        (ready) => ready,
      );
      final pupilDetails = find.byTooltip('Integration $studentId');
      await until(tester, pupilDetails);
      await tester.ensureVisible(pupilDetails);
      await tester.tap(pupilDetails);
      await until(tester, find.text('Enregistrer le départ').hitTestable());
      await tester.tap(find.text('Enregistrer le départ'));
      final reopened = await persisted(
        tester,
        () => harness.portalSession.schoolClient.runQuery(
          'get-teacher-attendance-call',
          {'anchor': controller.anchor},
        ),
        (call) => (call['records'] as List).whereType<Map>().any(
          (r) => r['studentId'] == studentId && r['departedAt'] != null,
        ),
      );
      expect((reopened['records'] as List).single['status'], 'present');
      await gone(tester, BottomSheet);
      expect(find.byType(DailyAttendancePage), findsOneWidget);
      final detailReads = transport.detailReads;
      harness.scope.find<GoRouter>().pop();
      await until(tester, find.text('Consulter l’appel du jour'));
      expect(
        transport.statusClasses.where((id) => id == classId),
        hasLength(2),
      );
      expect(transport.detailReads, detailReads);
    },
  );

  testWidgets(
    '[teacher-v2.discipline.correction] takeover gates fact changes while follow-ups append immediately',
    (tester) async {
      final id = fixtureId('discipline');
      Future<String?> readSavedFacts() async {
        // A staff connection can expire while the teacher is working in the UI.
        // Only repeat the independent GET; never replay the teacher's command.
        try {
          return (await owner.schoolClient.incidents.get(id))['description']
              as String?;
        } on ClientException {
          return (await owner.schoolClient.incidents.get(id))['description']
              as String?;
        }
      }

      final teacherId = harness.context.grants.actorId;
      await owner.schoolClient.incidents.save({
        'id': id,
        'schoolId': harness.context.grants.schoolId,
        'classGroupId': profile.primaryClassGroupId,
        'reporterId': teacherId,
        'title': id,
        'description': 'Original facts',
        'kind': 'minor_infraction',
        'status': 'open',
        'date': DateTime.now().toUtc().toIso8601String(),
      });
      final roster = await owner.schoolClient.enrollments.list(
        activeEnrollmentsForClass(
          profile.primaryClassGroupId,
          academicYearId: profile.academicYearId,
        ),
      );
      await owner.schoolClient.studentIncidentInvolvements.save({
        'id': fixtureId('discipline-participant'),
        'incidentId': id,
        'studentId': roster.first['studentId'],
        'role': 'subject',
      });
      final visibleIncidents = await baseline.schoolClient.incidents.list({
        'classGroupId': profile.primaryClassGroupId,
        'reporterId': teacherId,
      });
      expect(
        visibleIncidents.any((row) => row['id'] == id),
        true,
        reason: 'Reported incident must be readable',
      );
      final visibleParticipants = await baseline
          .schoolClient
          .studentIncidentInvolvements
          .list({'incidentId': id});
      expect(visibleParticipants, isNotEmpty);
      await baseline.schoolClient.runQuery('get-teacher-workflow-state', {
        'proposal': {
          'workflow': 'discipline',
          'targetId': id,
          'title': id,
          'description': 'Original facts',
          'kind': 'minor_infraction',
          'studentIds': visibleParticipants
              .map((row) => row['studentId'])
              .toList(),
        },
      });
      for (final row in visibleIncidents.where(
        (row) => row['reporterId'] == teacherId,
      )) {
        final participants = await baseline
            .schoolClient
            .studentIncidentInvolvements
            .list({'incidentId': row['id']});
        try {
          await baseline.schoolClient.runQuery('get-teacher-workflow-state', {
            'proposal': {
              'workflow': 'discipline',
              'targetId': row['id'],
              'title': row['title'],
              'description': row['description'],
              'kind': row['kind'],
              'studentIds': participants.map((p) => p['studentId']).toList(),
            },
          });
        } catch (error) {
          throw StateError(
            'Authored incident eligibility failed for ${row['title']}: $error',
          );
        }
      }
      await mount(tester, '/classes/${profile.primaryClassGroupId}/discipline');
      await until(tester, find.byType(TeacherDisciplinePage));
      final list = findController<TeacherDisciplineController>(
        tester,
        find.byType(TeacherDisciplinePage),
      );
      await persisted(tester, () async => list.busy.value, (busy) => !busy);
      final summary = list.incidents.value.firstWhere((row) => row['id'] == id);
      expect(summary['locked'], false);
      expect(summary.containsKey('eligibility'), false);
      final link = find.text(id).hitTestable().first;
      await until(tester, link);
      await tester.tap(link);
      await until(tester, find.text('Original facts').hitTestable());
      final controller = findController<TeacherDisciplineController>(
        tester,
        find.byType(TeacherDisciplinePage).last,
      );
      expect(controller.incidentId, id);
      await persisted(
        tester,
        () async => controller.busy.value,
        (busy) => !busy,
      );
      expect(controller.message.value, isEmpty);
      var incident = controller.incidents.value.firstWhere(
        (row) => row['id'] == id,
      );
      expect(
        await controller.save(incident, {
          ...incident['proposal'] as Map,
          'description': 'Checked facts',
        }),
        true,
      );
      expect(await readSavedFacts(), 'Checked facts');
      await owner.schoolClient.runCommand('take-over-teacher-incident', {
        'requestId': fixtureId('takeover'),
        'incidentId': id,
      });
      await controller.load();
      incident = controller.incidents.value.firstWhere(
        (row) => row['id'] == id,
      );
      expect(
        await controller.save(incident, {
          ...incident['proposal'] as Map,
          'description': 'Corrected facts',
        }, reason: 'Original account checked'),
        true,
      );
      expect(await readSavedFacts(), 'Checked facts');
      expect(await controller.followUp(id, 'Family contacted'), true);
      final pending =
          controller.incidents.value.firstWhere(
                (row) => row['id'] == id,
              )['eligibility']
              as Map;
      final correction = (pending['corrections'] as List).single as Map;
      await owner.schoolClient.runCommand('approve-teacher-correction', {
        'requestId': fixtureId('approval'),
        'correctionId': correction['id'],
        'expectedVersion': correction['version'],
      });
      await controller.load();
      expect(
        controller.incidents.value.firstWhere(
          (row) => row['id'] == id,
        )['description'],
        'Corrected facts',
      );
      expect(
        ((controller.incidents.value.firstWhere(
                      (row) => row['id'] == id,
                    )['eligibility']
                    as Map)['history']
                as List)
            .any(
              (event) =>
                  event['action'] == 'follow_up' &&
                  event['payload']['text'] == 'Family contacted',
            ),
        true,
      );
      expect(find.byType(TeacherDisciplinePage).last, findsOneWidget);
    },
  );

  testWidgets(
    '[teacher-v2.logbook.save] records lesson content and family summary',
    (tester) async {
      final transport = SwitchableTransport();
      addTearDown(transport.close);
      final auth = AuthClient(
        baseUrl: baseline.config.authUrl,
        client: transport,
      )..restoreRenewalCredential(baseline.authClient.renewalCredential!);
      harness = await TeacherLiveWidgetTestHarness.create(
        authenticatedSession: PortalSession(
          config: baseline.config,
          authClient: auth,
          schoolClient: baseline.schoolClient,
          actorKind: 'teacher',
        ),
      );
      final lesson = await lessonFixture();
      final id = lesson['id'] as String;
      final content = 'Contenu $id';
      final family = 'Synthèse $id';
      final allocation = await owner.schoolClient.classSubjects.get(
        lesson['classSubjectId'] as String,
      );
      const chapterNames = ['Atelier équilibre', 'Atelier coordination'];
      final links = <String>[];
      for (final (index, name) in chapterNames.indexed) {
        final matterId = fixtureId('programme');
        await owner.schoolClient.configureSubjectMatter({
          'id': matterId,
          'subjectId': allocation['subjectId'],
          'name': name,
          'shortName': name,
          'sequenceOrder': index + 1,
        });
        final allocated = await owner.schoolClient.classSubjectMatters.list({
          'classSubjectId': allocation['id'],
        });
        links.add(
          allocated.firstWhere(
                (row) => row['subjectMatterId'] == matterId,
              )['id']
              as String,
        );
      }
      Future<Map<String, bool>> savedChapters() async => {
        for (final row in await owner.schoolClient.classSubjectProgress.list({
          'lessonSessionId': id,
        }))
          row['classSubjectMatterId'] as String: row['completed'] as bool,
      };
      Future<void> changeChapter(
        int index,
        bool completed, {
        bool add = false,
        bool locked = false,
      }) async {
        final action = add
            ? find.text('Ajouter un chapitre')
            : find.byTooltip('Modifier ${chapterNames[index]}');
        if (add) {
          await tapPageAction(tester, 'Ajouter un chapitre');
        } else {
          await until(tester, action);
          await reveal(tester, action);
          await tester.tap(action);
        }
        await until(tester, find.byType(LogbookForm));
        if (add) {
          final dropdown = find.byType(DropdownButtonFormField<String>);
          await until(tester, dropdown.hitTestable());
          await tester.tap(dropdown);
          await until(tester, find.text(chapterNames[index]).hitTestable());
          await tester.tap(find.text(chapterNames[index]).hitTestable().last);
        }
        final checkbox = find.widgetWithText(
          CheckboxListTile,
          'Chapitre terminé pendant cette séance',
        );
        await until(tester, checkbox);
        if (tester.widget<CheckboxListTile>(checkbox).value != completed)
          await tester.tap(checkbox);
        if (locked)
          await tester.enterText(
            field('Motif de la correction'),
            'Ajustement du chapitre',
          );
        final save = find.widgetWithText(
          FilledButton,
          locked ? 'Demander une correction' : 'Enregistrer',
        );
        await reveal(tester, save);
        await tester.tap(save);
        await gone(tester, LogbookForm);
      }

      await mount(tester, '/session/$id/logbook');
      await tapPageAction(tester, 'Créer une entrée');
      await until(tester, find.byType(LogbookForm));
      await until(tester, field('Contenu abordé'));
      await tester.enterText(field('Contenu abordé'), content);
      await tester.enterText(field('Objectifs'), 'Résoudre un problème');
      await tester.enterText(field('Devoirs'), 'Exercice 2');
      await reveal(tester, field('Synthèse familles'));
      await tester.enterText(field('Synthèse familles'), family);
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.tap(find.text('Fermer'));
      await gone(tester, LogbookForm);
      await until(tester, find.text('Brouillon local disponible'));
      expect(
        (await baseline.schoolClient.lessonSessions.get(id))['sessionNote'],
        isNull,
      );
      await changeChapter(0, false, add: true);
      await changeChapter(1, false, add: true);
      await changeChapter(0, true);
      expect(await savedChapters(), {links[0]: true, links[1]: false});
      expect(
        (await baseline.schoolClient.lessonSessions.get(id))['sessionNote'],
        isNull,
      );
      await tapPageAction(tester, 'Créer une entrée');
      await until(tester, field('Contenu abordé'));
      expect(
        tester.widget<TextField>(field('Contenu abordé')).controller!.text,
        content,
      );
      await reveal(tester, find.text('Enregistrer'));
      await tester.tap(find.text('Enregistrer'));
      final saved = await persisted(
        tester,
        () => baseline.schoolClient.lessonSessions.get(id),
        (row) => (row['sessionNote'] as String? ?? '').contains(family),
      );
      final decoded = decodeStructuredSessionNote(
        saved['sessionNote'] as String,
      );
      expect(decoded.content, content);
      expect(decoded.familySummary, family);
      harness.scope.find<GoRouter>().go('/home');
      await gone(tester, LogbookForm);
      harness.scope.find<GoRouter>().go('/session/$id/logbook');
      await until(tester, find.text(content));
      expect(find.text(family), findsOneWidget);
      final teacher = harness.scope.find<TeacherContextController>();
      await teacher.selectAssignment(
        teacher.assignments.value
            .firstWhere((a) => a.classSubjectId == lesson['classSubjectId'])
            .id,
      );
      harness.scope.find<GoRouter>().go('/progress');
      await gone(tester, SessionDetailPage);
      await until(tester, find.widgetWithText(Tab, 'Cahier de texte'));
      await tester.tap(find.widgetWithText(Tab, 'Cahier de texte'));
      final datedEntry = find.widgetWithText(ListTile, id);
      await until(tester, datedEntry);
      await reveal(tester, datedEntry);
      await tester.tap(datedEntry);
      await until(tester, find.text(content));
      expect(find.text(family), findsOneWidget);
      expect(await savedChapters(), {links[0]: true, links[1]: false});
      final validated = await owner.schoolClient.requestRoute<List<dynamic>>(
        'POST',
        '/core/commands/validate-teacher-logbook',
        body: {
          'requestId': fixtureId('validate-book'),
          'lessonSessionIds': [id],
        },
      );
      expect(validated, hasLength(1));
      harness.scope.find<GoRouter>().go('/home');
      await gone(tester, SessionDetailPage);
      harness.scope.find<GoRouter>().go('/session/$id/logbook');
      final entryOptions = find.byTooltip('Demander une modification');
      await reveal(tester, entryOptions);
      await tester.tap(entryOptions);
      await tester.pumpAndSettle();
      await tester.tap(
        find.widgetWithText(PopupMenuItem<String>, 'Demander une modification'),
      );
      await until(tester, field('Contenu abordé'));
      final revised = 'Révision $id';
      await tester.enterText(field('Contenu abordé'), revised);
      await reveal(tester, field('Motif de la correction'));
      await tester.enterText(
        field('Motif de la correction'),
        'Précision après validation',
      );
      await reveal(tester, find.text('Demander une correction'));
      await tester.tap(find.text('Demander une correction'));
      await gone(tester, LogbookForm);
      await until(tester, find.text('Correction en attente de validation'));
      expect(
        decodeStructuredSessionNote(
          (await baseline.schoolClient.lessonSessions.get(id))['sessionNote']
              as String,
        ).content,
        content,
      );
      expect(find.text(revised), findsOneWidget);
      // Queue the revision while writes are offline. Retrying the same edit
      // on reconnect must use its original request ID.
      transport.offline = true;
      final editChapter = find.byTooltip('Modifier ${chapterNames[0]}');
      await reveal(tester, editChapter);
      await tester.tap(editChapter);
      await until(tester, find.byType(LogbookForm));
      final checkbox = find.widgetWithText(
        CheckboxListTile,
        'Chapitre terminé pendant cette séance',
      );
      await reveal(tester, checkbox);
      await tester.tap(checkbox);
      await tester.enterText(
        field('Motif de la correction'),
        'Vérifié après la séance',
      );
      final submit = find.widgetWithText(
        FilledButton,
        'Demander une correction',
      );
      await reveal(tester, submit);
      await tester.tap(submit);
      await persisted(
        tester,
        () async => transport.blockedWrites,
        (count) => count > 0,
      );
      expect(await savedChapters(), {links[0]: true, links[1]: false});
      transport.offline = false;
      await reveal(tester, submit);
      await tester.tap(submit);
      await gone(tester, LogbookForm);
      final state = await baseline.schoolClient.runQuery(
        'get-teacher-workflow-state',
        {
          'proposal': {
            'workflow': 'logbook',
            'formatVersion': 2,
            'targetId': id,
            'sessionNote': null,
            'progress': [],
          },
        },
      );
      final correction = (state['corrections'] as List)
          .whereType<Map>()
          .singleWhere((row) => row['status'] == 'pending');
      expect(await savedChapters(), {links[0]: true, links[1]: false});
      await owner.schoolClient.runCommand('approve-teacher-correction', {
        'requestId': fixtureId('approve-book'),
        'correctionId': correction['id'],
        'expectedVersion': correction['version'],
      });
      expect(await savedChapters(), {links[0]: false, links[1]: false});
      expect(
        decodeStructuredSessionNote(
          (await baseline.schoolClient.lessonSessions.get(id))['sessionNote']
              as String,
        ).content,
        revised,
      );
    },
  );

  testWidgets(
    '[teacher-v2.evaluation.create-marks] creates an evaluation and saves marks through the form',
    (tester) async {
      final title = 'UI evaluation ${DateTime.now().microsecondsSinceEpoch}';
      await mount(tester, '/evaluations');
      final evaluations = harness.scope.find<LiveEvaluationsController>();
      await persisted(
        tester,
        () async =>
            !evaluations.isBusy.value &&
            evaluations.classSubjects.value.isNotEmpty &&
            evaluations.evaluations.value.isNotEmpty,
        (ready) => ready,
      );
      final termPicker = find.byWidgetPredicate(
        (widget) =>
            widget is DropdownButtonFormField<String> &&
            widget.decoration.labelText == 'Période',
      );
      await until(tester, termPicker.hitTestable());
      await tester.tap(termPicker);
      await tester.pump();
      await tester.scrollUntilVisible(
        find.text('Trimestre 2'),
        200,
        scrollable: find.byType(Scrollable).last,
      );
      await until(tester, find.text('Trimestre 2').hitTestable());
      await tester.tap(find.text('Trimestre 2').hitTestable().last);
      await tester.pump();
      harness.scope.find<GoRouter>().go('/evaluations/create');
      await until(tester, field('Titre'));
      await tester.enterText(field('Titre'), title);
      await reveal(tester, find.text('Créer'));
      await tester.tap(find.text('Créer'));
      final rows = await persisted(
        tester,
        () => baseline.schoolClient.assessments.list({'title': title}),
        (rows) => rows.isNotEmpty,
      );
      expect(rows, hasLength(1));
      expect(
        rows.single['periodId'],
        evaluations.periods.value.firstWhere(
          (period) => period['name'] == 'Trimestre 2',
        )['id'],
      );
      final id = rows.single['id'] as String;
      await gone(tester, EvaluationCreatePage);
      harness.scope.find<GoRouter>().go('/evaluations/$id/marks');
      await until(tester, find.byType(EvaluationMarksPane));
      final review = await baseline.schoolClient.getAssessmentMarksReview({
        'assessmentId': id,
      });
      final roster = (review['students'] as List).cast<Map>();
      expect(roster, isNotEmpty, reason: 'Required eligible grading roster');
      await enterAllMarks(tester, id, '20');
      final marks = await persisted(
        tester,
        () =>
            baseline.schoolClient.assessmentResults.list({'assessmentId': id}),
        (rows) =>
            rows.length == roster.length &&
            rows.every((row) => row['score'] == 20),
        // Explicit Save persists the complete batch.
        timeout: Duration(seconds: 20 + roster.length * 10),
      );
      expect(marks.map((row) => row['studentId']).toSet().length, marks.length);
      await persisted(
        tester,
        () async => !findController<LiveMarksController>(
          tester,
          find.byType(EvaluationMarksPane),
        ).writing.value,
        (ready) => ready,
      );
      await tester.pump();
      harness.scope.find<GoRouter>().go('/evaluations');
      await gone(tester, EvaluationMarksPane);
      harness.scope.find<GoRouter>().go('/evaluations/$id/marks');
      await until(tester, find.text(title));
      final reopened = findController<LiveMarksController>(
        tester,
        find.byType(EvaluationMarksPane),
      );
      await persisted(
        tester,
        () async => reopened.students.value,
        (rows) => rows.isNotEmpty && rows.every((r) => r.score == 20),
      );
      expect(find.byType(EvaluationMarksPane), findsOneWidget);
    },
  );

  testWidgets(
    '[teacher-v2.session.detail] opens an assigned lesson with its actual title',
    (tester) async {
      final transport = _TimetableTransport();
      addTearDown(transport.close);
      final auth = AuthClient(
        baseUrl: baseline.config.authUrl,
        client: transport,
      )..restoreRenewalCredential(baseline.authClient.renewalCredential!);
      harness = await TeacherLiveWidgetTestHarness.create(
        authenticatedSession: PortalSession(
          config: baseline.config,
          authClient: auth,
          schoolClient: baseline.schoolClient,
          actorKind: 'teacher',
        ),
      );
      await mount(tester, '/home');
      final tc = harness.scope.find<TeacherContextController>();
      await persisted(
        tester,
        () async => tc.assignments.value,
        (rows) => rows.any(
          (a) => a.classSubjectId == profile.expectedClassSubjectIds.first,
        ),
      );
      final initial = tc.assignments.value.firstWhere(
        (a) => a.classSubjectId == profile.expectedClassSubjectIds.first,
      );
      await tc.selectAssignment(initial.id);
      final section = find
          .descendant(
            of: find.byType(HomeLessonList),
            matching: find.byType(Column),
          )
          .first;
      await until(tester, section);
      final today = tester
          .element(section)
          .levit
          .find<HomeTimetableController>();
      await persisted(
        tester,
        () async => today.entries.value,
        (rows) => rows != null,
      );
      final lesson = await lessonFixture();
      final id = lesson['id'] as String;
      final now = DateTime.now().toUtc();
      await owner.schoolClient.lessonSessions.save({
        ...lesson,
        'timetableTeacherIds': [harness.context.grants.actorId],
        'startsAt': now.subtract(const Duration(minutes: 1)).toIso8601String(),
        'endsAt': now.add(const Duration(minutes: 45)).toIso8601String(),
      });
      final timetable = await baseline.schoolClient.getTeacherTimetable({
        'teacherId': harness.context.grants.actorId,
        'startDate': now
            .subtract(const Duration(days: 1))
            .toIso8601String()
            .substring(0, 10),
        'endDate': now
            .add(const Duration(days: 1))
            .toIso8601String()
            .substring(0, 10),
      });
      expect(
        (timetable['events'] as List).where((e) => e['id'] == id),
        hasLength(1),
      );
      final shortcut = find.byKey(ValueKey('home-lesson-$id'));
      // The controller's clock tests cover polling. Load the newly saved lesson now.
      await today.refresh();
      await persisted(
        tester,
        () async => tester.any(shortcut),
        (visible) => visible,
        timeout: const Duration(seconds: 80),
      );
      transport.offline = true;
      await today.refresh();
      await until(tester, find.text('Réessayer'));
      expect(shortcut, findsOneWidget);
      transport.offline = false;
      await today.refresh();
      await tester.pump();
      expect(today.failed.value, isFalse);
      await tester.ensureVisible(shortcut);
      await tester.tap(shortcut);
      await until(tester, find.widgetWithText(Tab, 'Appel'));
      expect(find.byType(BottomSheet), findsNothing);
      harness.scope.find<GoRouter>().go('/calendar');
      final row = find.byKey(ValueKey('agenda-lesson-$id'));
      await until(tester, row);
      await tester.ensureVisible(row);
      await tester.tap(row);
      await until(tester, find.widgetWithText(Tab, 'Cahier de texte'));
      await until(tester, find.byTooltip('Retour').hitTestable());
      await tester.tap(find.byTooltip('Retour').hitTestable());
      await until(tester, row);
      final other = tc.assignments.value.firstWhere(
        (a) => a.classGroupId != initial.classGroupId,
      );
      final calendar = harness.scope.find<LiveCalendarController>();
      final delayedRead = Completer<void>();
      transport.holdNext = delayedRead;
      final oldRequest = calendar.loadCalendarData();
      await transport.held.future.timeout(const Duration(seconds: 10));
      await tc.selectAssignment(other.id);
      await gone(tester, SessionDetailPage);
      await persisted(
        tester,
        () async => tester.any(row),
        (visible) => !visible,
      );
      delayedRead.complete();
      await oldRequest;
      expect(
        calendar.todaySessions.value.every(
          (lesson) => lesson.classGroupId == other.classGroupId,
        ),
        isTrue,
      );
      await tc.selectAssignment(initial.id);
      await until(tester, row);
      transport.offline = true;
      await calendar.loadCalendarData();
      await until(tester, find.text('Réessayer'));
      transport.offline = false;
      await tester.tap(find.text('Réessayer'));
      await until(tester, row);
    },
    timeout: const Timeout(Duration(minutes: 3)),
  );
  testWidgets(
    '[teacher-v2.calendar.read] renders the live calendar and date picker',
    (tester) async {
      await mount(tester, '/calendar');
      await until(tester, find.byType(CalendarPage));
      await until(tester, find.byIcon(Icons.calendar_today_outlined));
      await tester.tap(find.byIcon(Icons.calendar_today_outlined));
      await until(tester, find.byType(CalendarDatePicker));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.tap(find.text('Fermer').last);
      await gone(tester, CalendarDatePicker);
    },
  );

  testWidgets(
    '[teacher-v2.inbox.read] opening a fresh message persists read status',
    (tester) async {
      final message = await createInboxFixture(
        owner,
        subjectId: harness.authUserId,
        actorId: harness.context.grants.actorId,
        actorKind: 'teacher',
      );
      final id = message['id'] as String;
      await mount(tester, '/inbox');
      await until(tester, find.widgetWithText(Tab, 'Notifications'));
      await tester.tap(find.widgetWithText(Tab, 'Notifications'));
      await until(tester, find.text(message['title'] as String));
      await tester.pump(const Duration(milliseconds: 500));
      await reveal(tester, find.text(message['title'] as String));
      await until(tester, find.text(message['title'] as String).hitTestable());
      await tester.tap(find.text(message['title'] as String));
      await until(tester, find.text('Integration message body'));
      await persisted(
        tester,
        () => baseline.schoolClient.messageDeliveries.get(id),
        (row) => row['status'] == 'read' && row['readAt'] != null,
      );
      harness.scope.find<GoRouter>().go('/message/$id');
      await until(tester, find.text('Integration message body'));
      expect(
        harness.scope.find<GoRouter>().routeInformationProvider.value.uri.path,
        '/inbox/message/$id',
      );
    },
  );

  testWidgets(
    '[teacher-v2.account.security] reads verified identifiers in the account overlay',
    (tester) async {
      await mount(tester, '/account/profile');
      await until(tester, find.text('Sécurité du compte'));
      await reveal(tester, find.text('Sécurité du compte'));
      await tester.tap(find.text('Sécurité du compte'));
      await until(tester, find.byType(AccountSecurityPage));
      await until(tester, find.text(profile.email));
    },
  );

  testWidgets(
    '[teacher-v2.account.signature] draws, uploads, replaces, and removes a private signature',
    (tester) async {
      await mount(tester, '/account/profile');
      await until(tester, find.text('Signature'));
      await tester.tap(find.text('Signature'));
      await until(tester, find.text('Dessiner'));
      final teacherId = harness.context.grants.actorId;
      Future<void> draw() async {
        final drawButton = find.byWidgetPredicate(
          (widget) =>
              widget is OutlinedButton &&
              widget.key == const ValueKey('signature-draw') &&
              widget.onPressed != null,
        );
        await tester.scrollUntilVisible(
          find.byKey(const ValueKey('signature-draw')),
          -160,
          scrollable: find.byType(Scrollable).last,
        );
        await until(tester, drawButton);
        await tester.tap(drawButton);
        final surface = find.byKey(const ValueKey('signature-editor-surface'));
        await until(tester, surface);
        await until(tester, surface.hitTestable());
        await tester.drag(surface, const Offset(80, 24));
        await tester.pump();
        await tester.tap(find.text('Utiliser la signature'));
        await gone(tester, SignatureEditorPage);
        await until(tester, find.text('Aperçu avant enregistrement'));
        await tester.scrollUntilVisible(
          find.text('Enregistrer'),
          160,
          scrollable: find.byType(Scrollable).last,
        );
        final signatureController = tester
            .element(find.text('Aperçu avant enregistrement'))
            .levit
            .find<TeacherSignatureController>();
        await tester.tap(find.text('Enregistrer'));
        final deadline = DateTime.now().add(const Duration(seconds: 20));
        while (signatureController.saving.value &&
            DateTime.now().isBefore(deadline)) {
          await tester.pump(const Duration(milliseconds: 100));
        }
        expect(signatureController.error.value, isEmpty);
        await until(tester, find.text(systemL10n().teacherSignatureSaved));
      }

      await draw();
      final first = await baseline.schoolClient.teachers.get(teacherId);
      final firstId = first['signatureAttachmentId'];
      expect(firstId, isNotNull);
      await draw();
      final replaced = await baseline.schoolClient.teachers.get(teacherId);
      expect(replaced['signatureAttachmentId'], isNot(firstId));
      await tester.scrollUntilVisible(
        find.text('Supprimer la signature'),
        160,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.tap(find.text('Supprimer la signature'));
      final confirmRemoval = find.widgetWithText(
        FilledButton,
        'Supprimer la signature',
      );
      await until(tester, confirmRemoval);
      expect(find.byType(BottomSheet), findsOneWidget);
      await tester.tap(confirmRemoval);
      await until(tester, find.text(systemL10n().teacherSignatureRemoved));
      final cleared = await baseline.schoolClient.teachers.get(teacherId);
      expect(cleared['signatureAttachmentId'], isNull);
    },
  );

  for (final role in TeacherPortalProfile.demoCiProfiles) {
    testWidgets(
      '[teacher-v2.${role.kind.name}.report-card.comment] writes only permitted comments and reloads them',
      (tester) async {
        harness = await TeacherLiveWidgetTestHarness.create(profile: role);
        final card = await createReportCardFixture(
          owner,
          classGroupId: role.primaryClassGroupId,
          academicYearId: role.academicYearId,
        );
        final id = card['id'] as String;
        final route =
            '/evaluations/report-cards/${role.primaryClassGroupId}/${card['periodId']}';
        await mount(tester, '$route/${card['studentId']}');
        if (role.kind == TeacherPortalKind.homeroom) {
          await until(tester, find.byType(ReportCardCommentPage));
          await persisted(
            tester,
            () async => find
                .descendant(
                  of: find.byType(ReportCardCommentPage),
                  matching: find.byType(ListView),
                )
                .evaluate()
                .isNotEmpty,
            (ready) => ready,
          );
          await tester.scrollUntilVisible(
            field('Commentaire titulaire'),
            200,
            scrollable: find
                .descendant(
                  of: find.byType(ReportCardCommentPage),
                  matching: find.byType(Scrollable),
                )
                .last,
          );
        }
        await until(tester, find.byType(TextField));
        final homeroom = field('Commentaire titulaire');
        expect(
          homeroom,
          role.kind == TeacherPortalKind.homeroom
              ? findsOneWidget
              : findsNothing,
        );
        final input = role.kind == TeacherPortalKind.homeroom
            ? homeroom
            : find.byType(TextField).first;
        final comment = 'Comment $id';
        await tester.enterText(input, comment);
        FocusManager.instance.primaryFocus?.unfocus();
        await tester.pump();
        await tester.scrollUntilVisible(
          find.text('Enregistrer'),
          200,
          scrollable: find
              .descendant(
                of: find.byType(ListView),
                matching: find.byType(Scrollable),
              )
              .first,
        );
        await Scrollable.ensureVisible(
          tester.element(find.text('Enregistrer')),
          alignment: 0.5,
        );
        await until(tester, find.text('Enregistrer').hitTestable());
        await tester.tap(find.text('Enregistrer'));
        await persisted(
          tester,
          () => owner.schoolClient.results.get(id),
          (row) => row.toString().contains(comment),
        );
        await tester.tap(find.text('Fermer').last);
        await gone(tester, ReportCardCommentPage);
        harness.scope.find<GoRouter>().go('$route/${card['studentId']}');
        if (role.kind == TeacherPortalKind.homeroom) {
          final list = find.descendant(
            of: find.byType(ReportCardCommentPage),
            matching: find.byType(ListView),
          );
          await until(tester, list);
          await tester.scrollUntilVisible(
            find.text(comment),
            200,
            scrollable: find
                .descendant(of: list, matching: find.byType(Scrollable))
                .first,
          );
        }
        await until(tester, find.text(comment));
      },
    );
  }

  testWidgets(
    '[teacher-v2.homeroom.attendance-denied] homeroom access does not permit another subject attendance',
    (tester) async {
      harness = await TeacherLiveWidgetTestHarness.create(
        profile: TeacherPortalProfile.homeroomTeacher,
      );
      final lessons = await owner.schoolClient.lessonSessions.list({
        'classGroupId': 'ci-6b',
        'classSubjectId': 'ci-cs-6b-fr',
      });
      expect(lessons, isNotEmpty);
      await mount(tester, '/session/${lessons.first['id']}/attendance');
      await until(
        tester,
        find.text(
          lookupAppLocalizations(
            harness.appLocale,
          ).attendanceRecordingLessonOnly,
        ),
      );
      expect(markRemaining, findsNothing);
    },
  );

  testWidgets(
    '[teacher-v2.offline.retry] queues offline attendance and retries without duplicate records',
    (tester) async {
      final connections = StreamController<bool>.broadcast();
      addTearDown(connections.close);
      final transport = SwitchableTransport();
      addTearDown(transport.close);
      final auth = AuthClient(
        baseUrl: baseline.config.authUrl,
        client: transport,
      )..restoreRenewalCredential(baseline.authClient.renewalCredential!);
      final isolated = PortalSession(
        config: baseline.config,
        authClient: auth,
        schoolClient: baseline.schoolClient,
        actorKind: 'teacher',
      );
      harness = await TeacherLiveWidgetTestHarness.create(
        authenticatedSession: isolated,
      );
      harness.connections = connections.stream;
      final lesson = await lessonFixture();
      final id = lesson['id'] as String;
      final call = await baseline.schoolClient.runQuery(
        'get-teacher-attendance-call',
        {
          'anchor': {'kind': 'lesson', 'lessonSessionId': id},
        },
      );
      final roster = call['students'] as List;
      await mount(tester, '/session/$id/attendance');
      await until(tester, find.byType(AttendanceStatusPicker));
      await until(
        tester,
        find
            .byWidgetPredicate((w) => w is ChoiceChip && w.onSelected != null)
            .hitTestable(),
      );
      transport.offline = true;
      await tapPageAction(tester, 'Marquer les élèves restants présents');
      await until(tester, find.text('Présent'));
      await until(
        tester,
        find.byWidgetPredicate((w) => w is RollCall && w.pending),
      );
      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();
      expect(find.text('Réessayer'), findsNothing);
      expect(
        tester
            .widget<ListTile>(find.widgetWithText(ListTile, 'Terminer l’appel'))
            .enabled,
        isFalse,
      );
      Navigator.of(
        tester.element(find.widgetWithText(ListTile, 'Terminer l’appel')),
      ).pop();
      await tester.pumpAndSettle();
      final outbox = harness.scope.find<TeacherOutboxController>();
      transport.offline = false;
      connections.add(true);
      outbox.didChangeAppLifecycleState(AppLifecycleState.resumed);
      await until(
        tester,
        find.byWidgetPredicate(
          (w) => w is RollCall && !w.pending && !w.savingDraft,
        ),
      );
      expect(
        await baseline.schoolClient.attendance.list({'lessonSessionId': id}),
        isEmpty,
      );
      await tapPageAction(tester, 'Terminer l’appel');
      final saved = await persisted(
        tester,
        () => baseline.schoolClient.attendance.list({'lessonSessionId': id}),
        (rows) => rows.length == roster.length,
      );
      await persisted(
        tester,
        () async => outbox.summary.value.pendingCount,
        (count) => count == 0,
      );
      expect(saved.every((row) => row['status'] == 'present'), isTrue);
      expect(
        saved.map((row) => row['studentId']).toSet().length,
        roster.length,
      );
      expect(
        await outbox.syncPending(),
        0,
        reason: 'A repeated retry must be a no-op',
      );
      expect(
        (await baseline.schoolClient.attendance.list({
          'lessonSessionId': id,
        })).length,
        saved.length,
      );
    },
  );

  testWidgets(
    '[teacher-v2.feedback.read] reads campaign results and preserves confidentiality',
    (tester) async {
      final campaign = await createFeedbackFixture(
        owner,
        teacherId: harness.context.grants.actorId,
        classGroupId: profile.primaryClassGroupId,
        academicYearId: profile.academicYearId,
      );
      final id = campaign['id'] as String;
      addTearDown(() => disposeFeedbackFixture(owner, id));
      await expectLater(
        getTeacherFamilyFeedbackResult(baseline.schoolClient, id),
        throwsA(isA<ApiError>().having((error) => error.status, 'status', 403)),
      );
      await owner.schoolClient.runCommand('close-family-feedback-campaign', {
        'id': id,
        'requestId': fixtureId('close'),
      });
      await owner.schoolClient.runCommand('publish-family-feedback-campaign', {
        'id': id,
        'requestId': fixtureId('publish'),
      });
      final result = await getTeacherFamilyFeedbackResult(
        baseline.schoolClient,
        id,
      );
      expect(result.eligibleSlotCount, greaterThan(0));
      expect(result.completedSlotCount, 0);
      expect(result.overallSuppressed, isTrue);
      final summaries = await listTeacherFeedbackSummaries(
        baseline.schoolClient,
      );
      final summary = summaries.singleWhere((row) => row.campaignId == id);
      expect(summary.questions, isEmpty);
      await mount(tester, '/evaluations/avis/$id');
      await until(tester, find.text('0/${result.eligibleSlotCount} réponses'));
      await until(
        tester,
        find.text(
          "Les détails sont masqués tant que le seuil de confidentialité n'est pas atteint.",
        ),
      );
      harness.scope.find<GoRouter>().go('/home/avis/$id');
      await until(tester, find.text('0/${result.eligibleSlotCount} réponses'));
    },
  );

  testWidgets(
    '[teacher-v2.marks.correction] submits marks then requests and withdraws a correction without changing official scores',
    (tester) async {
      Future<void> revealCorrectionAction(Finder action) async {
        FocusManager.instance.primaryFocus?.unfocus();
        await tester.pump();
        final scroll = find
            .descendant(
              of: find.byType(PupilMarkCorrectionSheet),
              matching: find.byType(Scrollable),
            )
            .first;
        await tester.scrollUntilVisible(action, 180, scrollable: scroll);
        await reveal(tester, action);
      }

      final id = fixtureId('correction-assessment');
      final periods = await baseline.schoolClient.academicPeriods.list({
        'academicYearId': profile.academicYearId,
      });
      final period = periods.firstWhere((row) => row['name'] == 'Trimestre 2');
      Future<Map<String, dynamic>> readSummary() =>
          baseline.schoolClient.runQuery('get-teacher-subject-period-summary', {
            'classSubjectId': profile.expectedClassSubjectIds.first,
            'periodId': period['id'],
          });
      Map<String, dynamic> averages(Map summary) => {
        for (final pupil in summary['students'] as List)
          pupil['studentId'] as String: pupil['average'],
      };
      final beforeDraft = averages(await readSummary());
      final starts = DateTime.now().toUtc().add(const Duration(days: 1));
      await baseline.schoolClient.createAssessment({
        'id': id,
        'classGroupId': profile.primaryClassGroupId,
        'classSubjectId': profile.expectedClassSubjectIds.first,
        'periodId': period['id'],
        'title': id,
        'kind': 'quiz',
        'maxScore': 20,
        'coefficient': 1,
        'attachments': <Map<String, dynamic>>[],
        'createdAt': DateTime.now().toUtc().toIso8601String(),
        'startsAt': starts.toIso8601String(),
        'endsAt': starts.add(const Duration(hours: 1)).toIso8601String(),
      });
      await mount(tester, '/evaluations');
      final evaluations = harness.scope.find<LiveEvaluationsController>();
      await persisted(
        tester,
        () async =>
            evaluations.periods.value.any((item) => item['id'] == period['id']),
        (ready) => ready,
      );
      final termPicker = find.byWidgetPredicate(
        (widget) =>
            widget is DropdownButtonFormField<String> &&
            widget.decoration.labelText == 'Période',
      );
      await until(tester, termPicker.hitTestable());
      await tester.tap(termPicker);
      await tester.pump();
      await tester.scrollUntilVisible(
        find.text('Trimestre 2'),
        200,
        scrollable: find.byType(Scrollable).last,
      );
      await until(tester, find.text('Trimestre 2').hitTestable());
      await tester.tap(find.text('Trimestre 2').hitTestable().last);
      await tester.pump();
      harness.scope.find<GoRouter>().go('/evaluations/$id/marks');
      await until(tester, find.byType(EvaluationMarksPane));
      final roster = await baseline.schoolClient.enrollments.list(
        activeEnrollmentsForClass(
          profile.primaryClassGroupId,
          academicYearId: profile.academicYearId,
        ),
      );
      await enterAllMarks(tester, id, '20');
      final marks = await persisted(
        tester,
        () =>
            baseline.schoolClient.assessmentResults.list({'assessmentId': id}),
        (rows) =>
            rows.length == roster.length &&
            rows.every((row) => row['score'] == 20),
        timeout: Duration(seconds: 20 + roster.length * 10),
      );
      final draftSummary = await readSummary();
      expect(averages(draftSummary), beforeDraft);
      expect(
        (draftSummary['students'] as List).any(
          (pupil) => (pupil['contributions'] as List).any(
            (result) => result['assessmentId'] == id,
          ),
        ),
        isFalse,
      );
      await until(
        tester,
        find.byWidgetPredicate(
          (w) =>
              w is FilledButton &&
              w.onPressed != null &&
              w.child is Text &&
              (w.child as Text).data == 'Soumettre les notes',
        ),
      );
      await reveal(tester, find.text('Soumettre les notes'));
      await tester.tap(find.text('Soumettre les notes'));
      await persisted(
        tester,
        () => baseline.schoolClient.getAssessmentMarksReview({
          'assessmentId': id,
        }),
        (review) => (review['assessment'] as Map)['marksStatus'] == 'submitted',
      );
      await until(tester, find.text('Note officielle'));
      await until(tester, find.byTooltip('Options du résultat').hitTestable());
      final submittedSummary = await readSummary();
      final officialAverages = averages(submittedSummary);
      expect(
        (submittedSummary['students'] as List).any(
          (pupil) => (pupil['contributions'] as List).any(
            (result) => result['assessmentId'] == id,
          ),
        ),
        isTrue,
      );
      expect(find.text('Soumettre les notes'), findsNothing);
      await tester.tap(
        find.byTooltip('Options du résultat').hitTestable().first,
      );
      await until(tester, find.text('Modifier la note').hitTestable());
      await tester.tap(find.text('Modifier la note').hitTestable());
      await until(tester, find.byKey(const ValueKey('correction-score')));
      await tester.enterText(
        find.byKey(const ValueKey('correction-score')),
        '15',
      );
      final reason = 'Correction $id';
      await reveal(tester, field('Motif'));
      await tester.enterText(field('Motif'), reason);
      await tester.pump();
      final send = find.widgetWithText(FilledButton, 'Envoyer la demande');
      await revealCorrectionAction(send);
      await tester.tap(send);
      final review = await persisted(
        tester,
        () => baseline.schoolClient.getAssessmentMarksReview({
          'assessmentId': id,
        }),
        (review) => (review['corrections'] as List).isNotEmpty,
      );
      final proposal = (review['corrections'] as List).single as Map;
      expect(proposal['status'], 'pending');
      expect(proposal['reason'], reason);
      expect(averages(await readSummary()), officialAverages);
      expect(
        (await baseline.schoolClient.assessmentResults.list({
          'assessmentId': id,
        })).every((row) => row['score'] == 20),
        isTrue,
      );
      expect((proposal['changes'] as List), hasLength(1));
      expect((proposal['allowedActions'] as Map)['withdraw'], isTrue);
      final changedResultId =
          ((proposal['changes'] as List).single as Map)['resultId'];
      final pupilId =
          marks.singleWhere(
                (mark) => mark['id'] == changedResultId,
              )['studentId']
              as String;
      await gone(tester, BottomSheet);
      final editPupil = find.descendant(
        of: find.byKey(ValueKey(pupilId)),
        matching: find.byTooltip('Options du résultat'),
      );
      await reveal(tester, editPupil);
      await tester.tap(editPupil);
      await until(tester, find.text('Modifier la note').hitTestable());
      await tester.tap(find.text('Modifier la note').hitTestable());
      await until(tester, find.byType(PupilMarkCorrectionSheet));
      await tester.enterText(
        find.byKey(const ValueKey('correction-score')),
        '16',
      );
      final update = find.widgetWithText(
        FilledButton,
        'Mettre à jour la demande',
      );
      await revealCorrectionAction(update);
      await tester.tap(update);
      await persisted(
        tester,
        () => baseline.schoolClient.getAssessmentMarksReview({
          'assessmentId': id,
        }),
        (review) {
          final changes =
              ((review['corrections'] as List).single as Map)['changes']
                  as List;
          return ((changes.single as Map)['proposed'] as Map)['score'] == 16;
        },
      );
      await gone(tester, BottomSheet);
      await reveal(tester, editPupil);
      await tester.tap(editPupil);
      await until(tester, find.text('Modifier la note').hitTestable());
      await tester.tap(find.text('Modifier la note').hitTestable());
      await until(tester, find.byType(PupilMarkCorrectionSheet));
      await revealCorrectionAction(find.text('Retirer la demande'));
      await tester.tap(find.text('Retirer la demande'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Retirer la demande'));
      await persisted(
        tester,
        () => baseline.schoolClient.getAssessmentMarksReview({
          'assessmentId': id,
        }),
        (review) => (review['corrections'] as List).isEmpty,
      );
      expect(
        (await baseline.schoolClient.assessmentResults.list({
          'assessmentId': id,
        })).length,
        marks.length,
      );

      // Existing grouped requests must retain the other pupil and shared reason.
      await gone(tester, BottomSheet);
      final currentReview = await baseline.schoolClient
          .getAssessmentMarksReview({'assessmentId': id});
      final other = marks.firstWhere((mark) => mark['id'] != changedResultId);
      final sharedReason = 'Grouped correction $id';
      await baseline.schoolClient.requestAssessmentMarksCorrection({
        'requestId': newSchoolRequestId(),
        'assessmentId': id,
        'expectedRevision':
            (currentReview['assessment'] as Map)['marksRevision'],
        'expectedGradingRevision':
            (currentReview['gradingPolicy'] as Map?)?['revision'] ?? 0,
        'reason': sharedReason,
        'changes': [
          {
            'resultId': changedResultId,
            'proposed': {'score': 17, 'designation': 'scored', 'notes': null},
          },
          {
            'resultId': other['id'],
            'proposed': {'score': 18, 'designation': 'scored', 'notes': null},
          },
        ],
      });
      final paneContext = tester.element(
        find
            .descendant(
              of: find.byType(EvaluationMarksPane),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await paneContext.levit.find<LiveMarksController>().load();
      await tester.pump();
      await reveal(tester, editPupil);
      await tester.tap(editPupil);
      await until(tester, find.text('Modifier la note').hitTestable());
      await tester.tap(find.text('Modifier la note').hitTestable());
      await until(tester, find.byType(PupilMarkCorrectionSheet));
      expect(tester.widget<TextField>(field('Motif')).readOnly, isTrue);
      expect(
        tester.widget<TextField>(field('Motif')).controller!.text,
        sharedReason,
      );
      await tester.enterText(
        find.byKey(const ValueKey('correction-score')),
        '19',
      );
      await revealCorrectionAction(update);
      await tester.tap(update);
      final groupedReview = await persisted(
        tester,
        () => baseline.schoolClient.getAssessmentMarksReview({
          'assessmentId': id,
        }),
        (review) =>
            (((review['corrections'] as List).single as Map)['changes'] as List)
                .any(
                  (change) =>
                      change['resultId'] == changedResultId &&
                      change['proposed']['score'] == 19,
                ),
      );
      final grouped = (groupedReview['corrections'] as List).single as Map;
      expect(grouped['reason'], sharedReason);
      expect(grouped['changes'], hasLength(2));
      expect(
        (grouped['changes'] as List).singleWhere(
          (change) => change['resultId'] == other['id'],
        )['proposed']['score'],
        18,
      );
      await gone(tester, BottomSheet);
      await reveal(tester, editPupil);
      await tester.tap(editPupil);
      await until(tester, find.text('Modifier la note').hitTestable());
      await tester.tap(find.text('Modifier la note').hitTestable());
      await until(tester, find.byType(PupilMarkCorrectionSheet));
      await tester.scrollUntilVisible(
        find.text('Retirer la demande'),
        200,
        scrollable: find
            .descendant(
              of: find.byType(PupilMarkCorrectionSheet),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await reveal(tester, find.text('Retirer la demande'));
      await tester.tap(find.text('Retirer la demande'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Retirer la demande'));
      final remainingReview = await persisted(
        tester,
        () => baseline.schoolClient.getAssessmentMarksReview({
          'assessmentId': id,
        }),
        (review) =>
            (((review['corrections'] as List).single as Map)['changes'] as List)
                .length ==
            1,
      );
      final remaining = (remainingReview['corrections'] as List).single as Map;
      expect(remaining['id'], grouped['id']);
      expect(remaining['reason'], sharedReason);
      expect(averages(await readSummary()), officialAverages);
      expect(
        ((remaining['changes'] as List).single as Map)['resultId'],
        other['id'],
      );
      expect(
        (await baseline.schoolClient.assessmentResults.list({
          'assessmentId': id,
        })).every((row) => row['score'] == 20),
        isTrue,
      );
    },
  );
}
