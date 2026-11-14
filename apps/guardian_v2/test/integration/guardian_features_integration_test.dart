@Tags(['integration'])
library;

import 'package:edaya_guardian_v2/features/home/home_page.dart';
import 'package:edaya_api_client/edaya_api_client.dart';
import 'package:edaya_guardian_v2/features/family_feedback/family_feedback_page.dart';
import 'package:edaya_guardian_v2/features/calendar/calendar_page.dart';
import 'package:edaya_guardian_v2/features/scolarite/results_page.dart';
import 'package:edaya_guardian_v2/features/account/account_profile_page.dart'
    as guardian;
import 'package:edaya_guardian_v2/features/child_profile/child_profile_page.dart';
import 'package:edaya_guardian_v2/features/child_profile/child_profile_controller.dart';
import 'package:edaya_guardian_v2/features/scolarite/subject_grades_page.dart';
import 'package:edaya_guardian_v2/features/scolarite/subject_logbook_page.dart';
import 'package:edaya_guardian_v2/features/scolarite/progress_page.dart';
import 'package:edaya_guardian_v2/features/fees/fee_detail_page.dart';
import 'package:edaya_guardian_v2/features/fees/fees_controller.dart';
import 'package:edaya_guardian_v2/design/components/summary_metric.dart';
import 'package:edaya_guardian_v2/features/fees/models/fee_formatting.dart';
import 'package:edaya_guardian_v2/features/context/student_context_controller.dart';
import 'package:edaya_integration_tests/edaya_integration_tests.dart';
import 'package:edaya_shared/edaya_shared.dart';
import 'package:edaya_shared/src/features/settings/app_settings_models.dart';
import 'package:edaya_shared/src/features/settings/app_settings_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'support/design_review_environment.dart';
import 'package:levit_flutter/levit_flutter.dart';
import 'support/guardian_probe_bundle.dart';
import 'support/guardian_widget_test_harness.dart';
import 'support/live_api_test_binding.dart';
import 'support/pump_guardian_page.dart';
import 'support/pump_until_found.dart';

Future<void> main() async {
  LiveApiWidgetTestBinding();
  tz.initializeTimeZones();
  setUpAll(() async {
    await initializeDateFormatting('fr_FR');
    await loadDesignReviewFonts();
  });
  Levit.enableAutoLinking();
  final skip = await resolveIntegrationSkipReason();
  if (skip != null) {
    testWidgets('guardian features disabled', (_) async {}, skip: true);
    return;
  }
  late PortalSession session;
  late PortalSession owner;
  late GuardianWidgetTestHarness harness;
  late GuardianProbeBundle probes;
  late String logbookSubject;
  late String logbookTitle;
  setUpAll(() async {
    final baseline = await GuardianWidgetTestHarness.create();
    session = baseline.portalSession!;
    owner = await PortalSession.signIn(
      config: IntegrationConfig.fromEnvironment().withSchoolOwnerEmail(),
      actorKind: 'staff',
      academicYearId: baseline.profile!.academicYearId,
    );
    probes = await GuardianProbeBundle.load(baseline);
    expect(probes.academic.reportCards, isNotEmpty);
    expect(probes.firstGradedEntry, isNotNull);
    expect(probes.fees.studentCharges, isNotEmpty);
    final lessons = await session.schoolClient.lessonSessions.list({
      'classGroupId': baseline.profile!.primaryClassGroupId,
    });
    final progress = await session.schoolClient.classSubjectProgress.list(
      progressForLessonSessions(
        lessons.map((row) => row['id'] as String).toList(),
      ),
    );
    expect(
      progress,
      isNotEmpty,
      reason: 'Required recorded curriculum progress fixture',
    );
    final lesson = lessons.firstWhere(
      (row) => row['id'] == progress.first['lessonSessionId'],
    );
    final subject = probes.academic.classSubjects.firstWhere(
      (row) => row['id'] == lesson['classSubjectId'],
    );
    logbookSubject =
        probes.academic.subjects.firstWhere(
              (row) => row['id'] == subject['subjectId'],
            )['name']
            as String;
    logbookTitle = (lesson['displayLabel'] ?? lesson['title']) as String;
  });
  setUp(() async {
    harness = await GuardianWidgetTestHarness.create(
      authenticatedSession: session,
    );
  });

  testWidgets(
    '[guardian-v2.messaging.school] composes a childless school enquiry and receives the school reply',
    (tester) async {
      final subject = 'Opening hours ${DateTime.now().microsecondsSinceEpoch}';
      await pumpGuardianRoute(tester, harness, location: '/inbox');
      await pumpUntilFound(tester, find.text('Nouveau message'));
      await tester.tap(find.text('Nouveau message'));
      await pumpUntilFound(
        tester,
        find.byType(DropdownButtonFormField<String>),
      );
      await tester.enterText(
        find.byWidgetPredicate(
          (w) => w is TextField && w.decoration?.labelText == 'Objet',
        ),
        subject,
      );
      await tester.enterText(
        find.byWidgetPredicate(
          (w) => w is TextField && w.decoration?.labelText == 'Message',
        ),
        'When does the office open?',
      );
      await tester.tap(find.text('Envoyer'));
      await pumpUntilFound(tester, find.byType(ConversationPage));
      await pumpUntilFound(tester, find.text('When does the office open?'));
      final page = await session.schoolClient.runQuery('list-conversations', {
        'destination': 'school',
      });
      final row = (page['items'] as List).cast<Map>().firstWhere(
        (r) => r['subject'] == subject,
      );
      expect(row['studentId'], isNull);
      expect(row['status'], 'awaiting_school');
      await owner.schoolClient.runCommand('reply-conversation', {
        'conversationId': row['id'],
        'expectedVersion': row['version'],
        'requestId': 'answer-$subject',
        'body': 'The office opens at eight.',
      });
      await tester.tap(
        find.descendant(
          of: find.byType(ConversationPage),
          matching: find.byTooltip('Actualiser'),
        ),
      );
      await pumpUntilFound(tester, find.text('The office opens at eight.'));
    },
  );
  testWidgets(
    '[guardian-v2.report-card.detail] displays a published report with its real period and average',
    (tester) async {
      final card = probes.academic.reportCards.first;
      await pumpGuardianRoute(
        tester,
        harness,
        location: '/report-card/${card['id']}',
      );
      await pumpUntilFound(tester, find.text('Bulletin publié'));
      final periodId = card['periodId'] as String;
      final data = await session.schoolClient.runQuery(
        'get-guardian-period-results',
        {'studentId': harness.profile!.primaryStudentId, 'periodId': periodId},
      );
      expect(
        harness
            .router
            .routeInformationProvider
            .value
            .uri
            .queryParameters['period'],
        periodId,
      );
      expect(find.byKey(ValueKey(card['id'])), findsOneWidget);
      expect(find.text(resultLabel(data)), findsWidgets);
    },
  );

  testWidgets(
    '[guardian-v2.fees.detail] reads the selected charge and supports its legacy redirect',
    (tester) async {
      final fee = probes.fees.studentCharges.first;
      await pumpGuardianRoute(tester, harness, location: '/fee/${fee['id']}');
      await pumpUntilFound(tester, find.byType(FeeDetailPage));
      await pumpUntilFound(tester, find.text(fee['label'] as String));
      expect(find.text('Frais introuvables'), findsNothing);
      expect(
        harness.router.routeInformationProvider.value.uri.path,
        '/fees/fee/${fee['id']}',
      );
    },
  );

  testWidgets(
    '[guardian-v2.child.profile] shows the selected child and document section',
    (tester) async {
      final student = harness.context!.linkedStudents.firstWhere(
        (row) => row['id'] == harness.profile!.primaryStudentId,
      );
      await pumpGuardianRoute(tester, harness, location: '/child');
      await pumpUntilFound(tester, find.byType(ChildProfilePage));
      await pumpUntilFound(
        tester,
        find.text('${student['firstName']} ${student['lastName']}'),
      );
      expect(find.text('Photo'), findsWidgets);
      expect(student['photoUrl'], isNotEmpty);
      await pumpUntilFound(
        tester,
        find.descendant(
          of: find.byType(ChildProfilePage),
          matching: find.byWidgetPredicate(
            (widget) =>
                widget is CircleAvatar && widget.backgroundImage is MemoryImage,
          ),
        ),
      );
    },
  );

  testWidgets(
    '[guardian-v2.account.security] opens account security and reads verified identifiers',
    (tester) async {
      await pumpGuardianRoute(tester, harness, location: '/account/profile');
      await pumpUntilFound(tester, find.byType(guardian.AccountProfilePage));
      final security = find.text('Sécurité du compte');
      await pumpUntilFound(tester, security);
      await tester.ensureVisible(security);
      await tester.tap(security);
      await pumpUntilFound(tester, find.byType(AccountSecurityPage));
      await pumpUntilFound(tester, find.text(harness.profile!.email));
    },
  );

  testWidgets(
    '[guardian-v2.settings.persist] changes a preference through the UI and reloads storage',
    (tester) async {
      await pumpGuardianRoute(tester, harness, location: '/settings');
      await pumpUntilFound(tester, find.text('Ouvrir les paramètres complets'));
      await tester.tap(find.text('Ouvrir les paramètres complets'));
      await pumpUntilFound(tester, find.byType(RadioListTile<ThemePreference>));
      final dark = find.byWidgetPredicate(
        (widget) =>
            widget is RadioListTile<ThemePreference> &&
            widget.value == ThemePreference.dark,
      );
      await tester.tap(dark);
      final deadline = DateTime.now().add(const Duration(seconds: 10));
      while ((await AppSettingsStorage.load()).theme != ThemePreference.dark &&
          DateTime.now().isBefore(deadline)) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect((await AppSettingsStorage.load()).theme, ThemePreference.dark);
      Navigator.of(tester.element(dark)).pop();
      final closeDeadline = DateTime.now().add(const Duration(seconds: 10));
      while (tester.any(dark) && DateTime.now().isBefore(closeDeadline)) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(dark, findsNothing);
      await tester.tap(find.text('Ouvrir les paramètres complets'));
      await pumpUntilFound(tester, dark);
      expect(
        harness.scope.find<AppSettingsController>().theme.value,
        ThemePreference.dark,
      );
    },
  );

  testWidgets(
    '[guardian-v2.grades.subject] shows actual assessed work for a subject and period',
    (tester) async {
      final entry = probes.firstGradedEntry!;
      final assessment = await session.schoolClient.assessments.get(
        entry.assessmentId,
      );
      final subject = await session.schoolClient.classSubjects.get(
        assessment['classSubjectId'] as String,
      );
      await pumpGuardianRoute(
        tester,
        harness,
        location:
            '/scolarite/period/${entry.periodId}/subject/${subject['subjectId']}',
      );
      await pumpUntilFound(tester, find.byType(SubjectGradesPage));
      await pumpUntilFound(tester, find.text(entry.title));
      expect(find.text('Aucune évaluation'), findsNothing);
    },
  );

  testWidgets('[guardian-v2.progress.detail] opens programme progress', (
    tester,
  ) async {
    await pumpGuardianRoute(tester, harness, location: '/scolarite/progress');
    await pumpUntilFound(tester, find.byType(ProgressOverviewPage));
    final link = probes.academic.classSubjectMatters.first;
    final matter = probes.academic.subjectMatters.firstWhere(
      (row) => row['id'] == link['subjectMatterId'],
    );
    final classSubject = probes.academic.classSubjects.firstWhere(
      (row) => row['id'] == link['classSubjectId'],
    );
    final subject = probes.academic.subjects.firstWhere(
      (row) => row['id'] == classSubject['subjectId'],
    );
    await pumpUntilFound(tester, find.text(subject['name'] as String));
    await tester.ensureVisible(find.text(subject['name'] as String));
    await tester.tap(find.text(subject['name'] as String));
    await pumpUntilFound(tester, find.text(matter['name'] as String));
  });

  testWidgets(
    '[guardian-v2.logbook.subject] displays recorded lesson content for the selected subject',
    (tester) async {
      await pumpGuardianRoute(
        tester,
        harness,
        location:
            '/scolarite/subject/${Uri.encodeComponent(logbookSubject)}/cahier',
      );
      await pumpUntilFound(tester, find.byType(SubjectLogbookPage));
      await pumpUntilFound(tester, find.text(logbookTitle));
      expect(
        find.text('Aucune entrée pour cette matière'),
        findsNothing,
        reason: 'Required logbook fixture',
      );
    },
  );

  testWidgets(
    '[guardian-v2.inbox.read] opens a fresh delivery and persists its read receipt',
    (tester) async {
      final message = await createInboxFixture(
        owner,
        subjectId: harness.context!.authUserId,
        actorId: harness.context!.grants.actorId,
        actorKind: 'guardian',
      );
      await pumpGuardianRoute(tester, harness, location: '/inbox');
      await pumpUntilFound(tester, find.text(message['title'] as String));
      await tester.tap(find.text(message['title'] as String));
      await pumpUntilFound(tester, find.text('Integration message body'));
      final deadline = DateTime.now().add(const Duration(seconds: 15));
      Map<String, dynamic> saved;
      do {
        await tester.pump(const Duration(milliseconds: 100));
        saved = await session.schoolClient.messageDeliveries.get(
          message['id'] as String,
        );
      } while (saved['status'] != 'read' && DateTime.now().isBefore(deadline));
      expect(saved['status'], 'read');
      expect(saved['readAt'], isNotNull);
      harness.router.go('/message/${message['id']}');
      await pumpUntilFound(tester, find.text('Integration message body'));
      expect(harness.router.routeInformationProvider.value.uri.pathSegments, [
        'inbox',
        'message',
        message['id'],
      ]);
    },
  );

  testWidgets(
    '[guardian-v2.academics.redirects] legacy academic links resolve to the current hub',
    (tester) async {
      await pumpGuardianRoute(tester, harness, location: '/scolarite');
      for (final route in [
        '/scolarite',
        '/scolarite/bulletins',
        '/scolarite/programme',
        '/scolarite/cahier',
      ]) {
        harness.router.go(route);
        await pumpUntilFound(tester, find.byType(ResultsPage));
        expect(
          harness.router.routeInformationProvider.value.uri.path,
          '/scolarite/notes',
        );
      }
    },
  );

  testWidgets(
    '[guardian-v2.calendar.events] legacy event navigation resolves to the live calendar',
    (tester) async {
      await pumpGuardianRoute(tester, harness, location: '/calendar/events');
      await pumpUntilFound(tester, find.byType(CalendarPage));
      expect(
        harness.router.routeInformationProvider.value.uri.path,
        '/calendar',
      );
      expect(find.text('Erreur de chargement'), findsNothing);
    },
  );

  testWidgets(
    '[guardian-v2.feedback.submit] submits a complete questionnaire and reloads its receipt',
    (tester) async {
      final campaign = await createFeedbackFixture(
        owner,
        teacherId: 'ci-t1',
        classGroupId: harness.profile!.primaryClassGroupId,
        academicYearId: harness.profile!.academicYearId,
      );
      final id = campaign['id'] as String;
      addTearDown(() => disposeFeedbackFixture(owner, id));
      final studentId = harness.profile!.primaryStudentId;
      late GuardianFamilyFeedbackQuestionnaire questionnaire;
      try {
        questionnaire = await getGuardianFamilyFeedbackQuestionnaire(
          session.schoolClient,
          campaignId: id,
          studentId: studentId,
          locale: 'fr',
        );
      } on ApiError catch (error) {
        fail(
          'Feedback fixture ${campaign['classGroupId']}/$studentId failed: HTTP ${error.status} ${error.body}',
        );
      }
      expect(questionnaire.isOpen, isTrue);
      expect(questionnaire.instrument?.items, isNotEmpty);
      await pumpGuardianRoute(tester, harness, location: '/inbox/avis/$id');
      await pumpUntilFound(
        tester,
        find.byType(GuardianFamilyFeedbackQuestionnairePage),
      );
      final feedbackController = tester
          .element(
            find
                .descendant(
                  of: find.byType(GuardianFamilyFeedbackQuestionnairePage),
                  matching: find.byType(DataState),
                )
                .first,
          )
          .levit
          .find<GuardianFamilyFeedbackQuestionnaireController>();
      final dataState = find.descendant(
        of: find.byType(GuardianFamilyFeedbackQuestionnairePage),
        matching: find.byType(DataState),
      );
      Future<void> waitForLoad() async {
        await pumpUntilFound(
          tester,
          find.descendant(
            of: find.byType(GuardianFamilyFeedbackQuestionnairePage),
            matching: find.byWidgetPredicate(
              (widget) =>
                  widget is DataState &&
                  (widget.status == DataStatus.ready ||
                      widget.status == DataStatus.error),
            ),
          ),
        );
      }

      await waitForLoad();
      if (feedbackController.errorMessage.value.isNotEmpty) {
        final retry = find.descendant(
          of: dataState,
          matching: find.text('Réessayer'),
        );
        await tester.tap(retry);
        await tester.pump();
        await waitForLoad();
      }
      expect(
        feedbackController.questionnaire.value?.isOpen,
        isTrue,
        reason: feedbackController.errorMessage.value,
      );
      await pumpUntilFound(tester, find.byType(Scrollable));
      for (final item in questionnaire.instrument!.items) {
        final answer = find.byKey(ValueKey('feedback-${item.id}-4'));
        await tester.scrollUntilVisible(
          answer,
          180,
          scrollable: find.byType(Scrollable).last,
        );
        await Scrollable.ensureVisible(tester.element(answer), alignment: 0.5);
        await tester.pump(const Duration(milliseconds: 350));
        await tester.tap(answer);
        await tester.pump();
      }
      final submit = find.byKey(const ValueKey('feedback-submit'));
      await tester.scrollUntilVisible(
        submit,
        180,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.pump();
      expect(tester.widget<FilledButton>(submit).onPressed, isNotNull);
      await Scrollable.ensureVisible(tester.element(submit), alignment: 0.5);
      await tester.pump(const Duration(milliseconds: 350));
      await tester.tap(submit);
      final deadline = DateTime.now().add(const Duration(seconds: 20));
      var saved = questionnaire;
      while (!saved.isCompleted && DateTime.now().isBefore(deadline)) {
        await tester.pump(const Duration(milliseconds: 100));
        saved = await getGuardianFamilyFeedbackQuestionnaire(
          session.schoolClient,
          campaignId: id,
          studentId: studentId,
          locale: 'fr',
        );
      }
      expect(
        saved.isCompleted,
        isTrue,
        reason:
            'Feedback UI: ${feedbackController.errorMessage.value}; answers=${feedbackController.answers.value.length}/${questionnaire.instrument!.items.length}',
      );
      harness.router.go('/inbox');
      await tester.pump();
      harness.router.go('/inbox/avis/$id');
      await pumpUntilFound(
        tester,
        find.text('Votre réponse a été enregistrée.'),
      );
      expect(find.byKey(const ValueKey('feedback-submit')), findsNothing);
    },
  );

  testWidgets(
    '[guardian-v2.child.isolation] child switching replaces finance data and rejects an unrelated child',
    (tester) async {
      final alternate = probes.studentSwitchProbe;
      expect(alternate, isNotNull, reason: 'Required second linked child');
      final primaryRows = await session.schoolClient.studentCharges.list({
        'studentId': harness.profile!.primaryStudentId,
        'academicYearId': harness.profile!.academicYearId,
      });
      final alternateRows = await session.schoolClient.studentCharges.list({
        'studentId': alternate!.alternateStudentId,
        'academicYearId': harness.profile!.academicYearId,
      });
      expect(primaryRows, isNotEmpty);
      expect(alternateRows, isNotEmpty);
      final primaryIds = primaryRows.map((row) => row['id']).toSet();
      expect(
        alternateRows.every((row) => row['status'] == 'cancelled'),
        isTrue,
        reason: 'Required alternate child fixture has only cancelled charges',
      );
      final alternateIds = alternateRows
          .where((row) => row['status'] != 'cancelled')
          .map((row) => row['id'])
          .toSet();
      expect(primaryIds.intersection(alternateIds), isEmpty);
      await pumpGuardianRoute(tester, harness, location: '/fees');
      await pumpUntilFound(
        tester,
        find.text(primaryRows.first['label'] as String),
      );
      FeesController feesAt(Finder visible) =>
          tester.element(visible.first).levit.find<FeesController>();
      expect(
        feesAt(
          find.text(primaryRows.first['label'] as String),
        ).charges.value.map((row) => row.id).toSet(),
        primaryIds,
      );
      await openChildPicker(tester, harness);
      await tapAlternateStudent(tester, alternate);
      await pumpUntilFound(
        tester,
        find.descendant(
          of: find.byType(HomePage),
          matching: find.text(alternate.alternateStudentName),
        ),
      );
      expect(
        harness.scope.find<StudentContextController>().activeStudentId,
        alternate.alternateStudentId,
      );
      harness.router.push('/fees');
      final zeroTotal = find.byWidgetPredicate(
        (widget) =>
            widget is SummaryMetric &&
            widget.label == 'Attendu' &&
            widget.value == formatMoney(0, 'XOF'),
      );
      await pumpUntilFound(tester, zeroTotal);
      expect(
        feesAt(zeroTotal).charges.value.map((row) => row.id).toSet(),
        alternateIds,
      );
      expect(
        find.descendant(
          of: zeroTotal,
          matching: find.text(formatMoney(0, 'XOF')),
        ),
        findsOneWidget,
      );
      expect(find.text(primaryRows.first['label'] as String), findsNothing);
      final outsiders = await owner.schoolClient.students.list({});
      final linked = harness.context!.linkedStudents
          .map((row) => row['id'])
          .toSet();
      final outsider = outsiders.firstWhere(
        (row) => !linked.contains(row['id']),
      );
      await expectLater(
        session.schoolClient.getStudentFinanceSummary({
          'studentId': outsider['id'],
          'academicYearId': harness.profile!.academicYearId,
        }),
        throwsA(
          isA<ApiError>().having(
            (error) => error.status,
            'HTTP status',
            anyOf(403, 404),
          ),
        ),
      );
    },
  );

  testWidgets(
    '[guardian-v2.documents.read] reads an issued school certificate for the selected child',
    (tester) async {
      final enrollments = await owner.schoolClient.enrollments.list({
        'studentId': harness.profile!.primaryStudentId,
        'academicYearId': harness.profile!.academicYearId,
        'status': 'active',
      });
      expect(enrollments, isNotEmpty, reason: 'Required document enrollment');
      final paper = await requestDocumentIssuance(
        owner.schoolClient,
        templateKey: 'schooling-certificate.v1',
        sourceId: enrollments.first['id'] as String,
        studentId: harness.profile!.primaryStudentId,
        academicYearId: harness.profile!.academicYearId,
      );
      expect(paper.number, isNotNull);
      final ready = await waitForTerminalIssuance(owner.schoolClient, paper.id);
      expect(
        ready.isDownloadable,
        isTrue,
        reason:
            'Required certificate fixture: ${ready.status} ${ready.failureCode}',
      );
      await pumpGuardianRoute(tester, harness, location: '/child');
      await pumpUntilFound(tester, find.text('Photo'));
      final controller = tester
          .element(find.text('Photo'))
          .levit
          .find<ChildProfileController>();
      final deadline = DateTime.now().add(const Duration(seconds: 20));
      while (controller.leftoverPapers.value.every(
            (item) => item.id != paper.id,
          ) &&
          DateTime.now().isBefore(deadline)) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(
        controller.leftoverPapers.value.any((item) => item.id == paper.id),
        isTrue,
      );
      await tester.scrollUntilVisible(
        find.text(paper.number!),
        200,
        scrollable: find.byType(Scrollable).last,
      );
      expect(find.text('Certificat de scolarité'), findsWidgets);
      expect(find.text(paper.number!), findsOneWidget);
      final read = await getDocumentIssuance(session.schoolClient, paper.id);
      expect(read.studentId, harness.profile!.primaryStudentId);
    },
  );
}
