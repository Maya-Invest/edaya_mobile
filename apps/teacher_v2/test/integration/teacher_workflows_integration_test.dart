@Tags(['integration'])
library;

import 'package:http/http.dart' show ClientException;

import 'package:edaya_auth/edaya_auth.dart';
import 'package:edaya_teacher_v2/app/workspace_navigation.dart';
import 'package:edaya_teacher_v2/features/offline/teacher_outbox_controller.dart';
import 'package:edaya_api_client/edaya_api_client.dart';
import 'package:edaya_integration_tests/edaya_integration_tests.dart';
import 'package:edaya_shared/edaya_shared.dart';
import 'package:edaya_shared/src/features/settings/app_settings_models.dart';
import 'package:edaya_shared/src/features/settings/app_settings_storage.dart';
import 'package:edaya_teacher_v2/features/calendar/calendar_page.dart';
import 'package:edaya_teacher_v2/features/context/teacher_context_controller.dart';
import 'package:edaya_teacher_v2/features/classes/daily_attendance_page.dart';
import 'package:edaya_teacher_v2/features/classes/teacher_discipline_page.dart';
import 'package:edaya_teacher_v2/features/account/account_page.dart' as account;
import 'package:edaya_teacher_v2/features/evaluations/evaluations_page.dart';
import 'package:edaya_teacher_v2/features/evaluations/teacher_gradebook_page.dart';
import 'package:edaya_teacher_v2/features/evaluations/live_evaluations_controller.dart';
import 'package:edaya_teacher_v2/features/evaluations/live_marks_controller.dart';
import 'package:edaya_teacher_v2/features/session/logbook_page.dart';
import 'package:edaya_teacher_v2/mock/mock_store.dart' show AttendanceStatus;
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
  await Scrollable.ensureVisible(tester.element(finder), alignment: 0.5);
  await tester.pump(const Duration(milliseconds: 350));
  await until(tester, finder.hitTestable());
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
    .element(find.descendant(of: finder, matching: find.byType(ListView)).first)
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
    find.descendant(of: pane, matching: find.byType(ListView)),
  );
  final controller = findController<LiveMarksController>(tester, pane);
  await persisted(
    tester,
    () async => controller.students.value,
    (rows) => rows.isNotEmpty,
  );
  for (final pupil in controller.students.value) {
    final name = find.descendant(
      of: pane,
      matching: find.byKey(ValueKey('mark-${pupil.studentId}')),
    );
    await until(
      tester,
      find.descendant(of: pane, matching: find.byType(ListView)),
    );
    final rosterScroll = find
        .descendant(of: pane, matching: find.byType(Scrollable))
        .first;
    if (!tester.any(name)) {
      await tester.scrollUntilVisible(name, 140, scrollable: rosterScroll);
    }
    await tester.ensureVisible(name);
    await until(tester, name.hitTestable());
    await tester.tap(name);
    await until(tester, find.byType(TextField));
    await tester.enterText(find.byType(TextField).first, score);
    final save = find.widgetWithText(FilledButton, 'Enregistrer');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.scrollUntilVisible(
      save,
      120,
      scrollable: find
          .descendant(
            of: find.descendant(
              of: find.byType(BottomSheet),
              matching: find.byType(ListView),
            ),
            matching: find.byWidgetPredicate(
              (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
            ),
          )
          .first,
    );
    await until(tester, save.hitTestable());
    await tester.tap(save);
    await gone(tester, BottomSheet);
    expect(pane, findsOneWidget);
    final deadline = DateTime.now().add(const Duration(seconds: 10));
    while (tester.any(find.byType(TextField)) &&
        DateTime.now().isBefore(deadline)) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.byType(TextField), findsNothing);
  }
}

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
      await until(tester, find.text('Mes espaces'));
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
      await until(tester, find.byType(DropdownButton<AttendanceStatus>));
      await until(tester, find.text('Tous présents').hitTestable());
      await tester.tap(find.text('Tous présents'));
      await until(tester, find.text('Présent'));
      expect(
        await baseline.schoolClient.attendance.list({'lessonSessionId': id}),
        isEmpty,
      );
      await until(
        tester,
        find.byWidgetPredicate(
          (widget) =>
              widget is FilledButton &&
              widget.onPressed != null &&
              widget.child is Text &&
              (widget.child as Text).data == 'Terminer',
        ),
      );
      await tester.tap(find.text('Terminer'));
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
            rows.every((row) => row['status'] == 'present'),
      );
      expect(rows.map((row) => row['studentId']).toSet().length, rows.length);
      harness.scope.find<GoRouter>().go('/home');
      await gone(tester, AttendancePage);
      harness.scope.find<GoRouter>().go('/session/$id/attendance');
      await until(tester, find.text('Présent'));
      expect(
        tester
            .widgetList<DropdownButton<AttendanceStatus>>(
              find.byType(DropdownButton<AttendanceStatus>),
            )
            .every((widget) => widget.value == AttendanceStatus.present),
        isTrue,
      );
    },
  );

  testWidgets(
    '[teacher-v2.daily-attendance.submit] homeroom daily call stays private until Finish',
    (tester) async {
      harness = await TeacherLiveWidgetTestHarness.create(
        profile: TeacherPortalProfile.homeroomTeacher,
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
      await mount(tester, '/classes/$classId/attendance');
      await until(tester, find.text('Marquer les autres présents'));
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
      await tester.tap(find.text('Marquer les autres présents'));
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
      await until(
        tester,
        find.byWidgetPredicate(
          (widget) =>
              widget is FilledButton &&
              widget.onPressed != null &&
              widget.child is Text &&
              (widget.child as Text).data == 'Terminer',
        ),
      );
      await tester.tap(find.text('Terminer'));
      await persisted(
        tester,
        () => harness.portalSession.schoolClient.runQuery(
          'get-teacher-attendance-call',
          {'anchor': controller.anchor},
        ),
        (call) => call['submitted'] == true,
      );
      expect(find.byType(DailyAttendancePage), findsOneWidget);
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
      final controller = findController<TeacherDisciplineController>(
        tester,
        find.byType(TeacherDisciplinePage),
      );
      await persisted(
        tester,
        () async => controller.busy.value,
        (busy) => !busy,
      );
      expect(controller.teacherId, teacherId);
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
      expect(find.byType(TeacherDisciplinePage), findsOneWidget);
    },
  );

  testWidgets(
    '[teacher-v2.logbook.save] records lesson content and family summary',
    (tester) async {
      final lesson = await lessonFixture();
      final id = lesson['id'] as String;
      final content = 'Contenu $id';
      final family = 'Synthèse $id';
      await mount(tester, '/session/$id/logbook');
      await until(tester, find.byType(LogbookForm));
      await until(tester, field('Contenu abordé'));
      await tester.enterText(field('Contenu abordé'), content);
      await tester.enterText(field('Objectifs'), 'Résoudre un problème');
      await tester.enterText(field('Devoirs'), 'Exercice 2');
      await reveal(tester, field('Synthèse familles'));
      await tester.enterText(field('Synthèse familles'), family);
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
      await gone(tester, LogbookPage);
      harness.scope.find<GoRouter>().go('/session/$id/logbook');
      await until(tester, find.text(content));
      expect(find.text(family), findsOneWidget);
      await harness.scope.find<TeacherContextController>().selectClass(
        profile.primaryClassGroupId,
      );
      harness.scope.find<GoRouter>().go('/progress');
      await until(tester, find.text(id));
      await reveal(tester, find.text(id));
      await tester.tap(find.text(id));
      await until(tester, field('Contenu abordé'));
      expect(
        tester.widget<TextField>(field('Contenu abordé')).controller!.text,
        content,
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
        // Fill persists one request per student; allow the entire batch to finish.
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
      final lessons = await baseline.schoolClient.lessonSessions.list({
        'classSubjectId': profile.expectedClassSubjectIds.first,
      });
      expect(lessons, isNotEmpty);
      final lesson = lessons.first;
      await mount(tester, '/session/${lesson['id']}');
      await until(tester, find.byType(SessionDetailPage));
      await until(tester, find.text('Cahier de texte'));
      expect(find.text('Séance introuvable'), findsNothing);
    },
  );
  testWidgets(
    '[teacher-v2.classes.list] returns a saved roster link to the teacher home',
    (tester) async {
      await mount(tester, '/classes');
      await until(tester, find.text('Mes espaces'));
      expect(find.text('Liste des élèves'), findsNothing);
      expect(
        harness.scope.find<GoRouter>().routeInformationProvider.value.uri.path,
        '/home',
      );
    },
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
      await until(tester, find.text('Établissement'));
      await tester.tap(find.text('Établissement'));
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

  testWidgets('[teacher-v2.settings.persist] saves the theme preference', (
    tester,
  ) async {
    await mount(tester, '/settings');
    await until(tester, find.byType(account.SettingsPage));
    final dark = find.byWidgetPredicate(
      (widget) =>
          widget is RadioListTile<ThemePreference> &&
          widget.value == ThemePreference.dark,
    );
    await until(tester, dark);
    await tester.tap(dark);
    await persisted(
      tester,
      AppSettingsStorage.load,
      (settings) => settings.theme == ThemePreference.dark,
    );
    await persisted(
      tester,
      () async => harness.scope.find<AppSettingsController>().theme.value,
      (theme) => theme == ThemePreference.dark,
    );
  });

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
        find.text('La saisie des présences est réservée aux séances de cours.'),
      );
      expect(find.text('Tous présents'), findsNothing);
    },
  );

  testWidgets(
    '[teacher-v2.offline.retry] queues offline attendance and retries without duplicate records',
    (tester) async {
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
      await until(tester, find.byType(DropdownButton<AttendanceStatus>));
      await until(tester, find.text('Tous présents').hitTestable());
      transport.offline = true;
      await tester.tap(find.text('Tous présents'));
      await until(tester, find.text('Présent'));
      await until(
        tester,
        find.byWidgetPredicate(
          (widget) =>
              widget is FilledButton &&
              widget.onPressed != null &&
              widget.child is Text &&
              (widget.child as Text).data == 'Terminer',
        ),
      );
      await tester.tap(find.text('Terminer'));
      final outbox = harness.scope.find<TeacherOutboxController>();
      await persisted(tester, () async {
        await outbox.refreshSummary();
        return outbox.summary.value.pendingCount;
      }, (count) => count == 1);
      expect(transport.blockedWrites, greaterThan(0));
      expect(
        await baseline.schoolClient.attendance.list({'lessonSessionId': id}),
        isEmpty,
      );
      harness.scope.find<GoRouter>().go('/settings');
      final settings = find.byType(account.SettingsPage);
      await until(tester, settings);
      final sync = find.descendant(
        of: settings,
        matching: find.text('Synchroniser'),
      );
      final list = find
          .descendant(of: settings, matching: find.byType(Scrollable))
          .first;
      await tester.scrollUntilVisible(sync, 350, scrollable: list);
      transport.offline = false;
      await reveal(tester, sync);
      await tester.tap(sync);
      await persisted(
        tester,
        () async => outbox.summary.value.pendingCount,
        (count) => count == 0,
      );
      expect(
        await baseline.schoolClient.attendance.list({'lessonSessionId': id}),
        isEmpty,
      );
      harness.scope.find<GoRouter>().go('/session/$id/attendance');
      await until(tester, find.text('Présent'));
      await until(
        tester,
        find.byWidgetPredicate(
          (widget) =>
              widget is FilledButton &&
              widget.onPressed != null &&
              widget.child is Text &&
              (widget.child as Text).data == 'Terminer',
        ),
      );
      await tester.tap(find.text('Terminer'));
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
      final id = fixtureId('correction-assessment');
      final periods = await baseline.schoolClient.academicPeriods.list({
        'academicYearId': profile.academicYearId,
      });
      final period = periods.firstWhere((row) => row['name'] == 'Trimestre 2');
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
      await until(
        tester,
        find.text('Les modifications sont soumises à approbation.'),
      );
      await tester.tap(find.text('Soumettre les notes'));
      await until(tester, find.byType(CheckboxListTile));
      final students = find.byType(CheckboxListTile);
      await tester.tap(students.first);
      await tester.pump();
      await tester.enterText(field('Valeur proposée'), '15');
      final reason = 'Correction $id';
      final reasonField = field('Motif de la correction');
      await reveal(tester, reasonField);
      await tester.enterText(reasonField, reason);
      await tester.pump();
      final send = find.descendant(
        of: find.byType(BottomSheet),
        matching: find.widgetWithText(FilledButton, 'Soumettre les notes'),
      );
      await reveal(tester, send);
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
      expect(
        (await baseline.schoolClient.assessmentResults.list({
          'assessmentId': id,
        })).every((row) => row['score'] == 20),
        isTrue,
      );
      await until(tester, find.text('Retirer ma demande'));
      await reveal(tester, find.text('Retirer ma demande'));
      await tester.tap(find.text('Retirer ma demande'));
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
    },
  );
}
