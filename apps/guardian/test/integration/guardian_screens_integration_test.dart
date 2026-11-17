@Tags(['integration'])
library;

import 'package:edaya_api_client/edaya_api_client.dart';
import 'package:edaya_guardian_v2/app/workspace_shell.dart';
import 'package:edaya_guardian_v2/design/components/list_row.dart';
import 'package:edaya_guardian_v2/design/components/summary_metric.dart';
import 'package:edaya_guardian_v2/features/calendar/session_detail_page.dart';
import 'package:edaya_guardian_v2/features/context/student_context_controller.dart';
import 'package:edaya_guardian_v2/features/fees/fees_page.dart';
import 'package:edaya_guardian_v2/features/fees/models/fee_formatting.dart';
import 'package:edaya_shared/edaya_shared.dart' show lookupAppLocalizations;
import 'package:edaya_guardian_v2/features/fees/payment_detail_page.dart';
import 'package:edaya_guardian_v2/features/home/home_page.dart';
import 'package:edaya_guardian_v2/features/inbox/inbox_routes.dart';
import 'package:edaya_guardian_v2/features/inbox/message_detail_page.dart';
import 'package:edaya_guardian_v2/features/scolarite/subject_grades_page.dart';
import 'package:edaya_integration_tests/edaya_integration_tests.dart';
import 'package:flutter/widgets.dart';
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
    testWidgets('guardian screens integration', (tester) async {}, skip: true);
    return;
  }

  group('guardian two children (ci-g1)', () {
    _mariamKoneSuite();
  });

  group('guardian multiple children (ci-g4)', () {
    _koffiYaoSuite();
  });
}

void _mariamKoneSuite() {
  late GuardianWidgetTestHarness harness;
  late GuardianProbeBundle probes;
  late PortalSession readSession;
  late PortalSession owner;

  setUpAll(() async {
    harness = await GuardianWidgetTestHarness.create();
    probes = await GuardianProbeBundle.load(harness);
    readSession = harness.portalSession!;
    owner = await PortalSession.signIn(
      config: IntegrationConfig.fromEnvironment().withSchoolOwnerEmail(),
      actorKind: 'staff',
      academicYearId: harness.profile!.academicYearId,
    );
  });

  setUp(() async {
    harness = await GuardianWidgetTestHarness.create(
      authenticatedSession: readSession,
    );
  });

  group('calendar', () {
    testWidgets(
      '[guardian-v2.calendarpage-shows-week-controls-and-seeded-sessions] CalendarPage shows week controls and seeded sessions',
      (tester) async {
        await openCalendarTab(tester, harness);
        await pumpUntilFound(tester, find.byTooltip('Semaine suivante'));

        expect(probes.sessionProbe, isNotNull);

        await pumpUntilCalendarHasSessions(
          tester,
          preferDay: probes.sessionProbe?.sessionDay,
        );
        expect(find.byType(ListRow), findsWidgets);
      },
    );

    testWidgets(
      '[guardian-v2.session-row-opens-session-detail-page] session row opens session detail page',
      (tester) async {
        final session = probes.sessionProbe;
        expect(session, isNotNull);

        await openCalendarTab(tester, harness);
        await pumpUntilCalendarHasSessions(
          tester,
          preferDay: session!.sessionDay,
        );

        await tapSessionRow(tester);
        await tester.pump();
        await pumpUntilFound(tester, find.byType(SessionDetailPage));
        await pumpUntilFound(tester, find.text('Horaire'));
        expect(find.text('Séance introuvable'), findsNothing);
      },
    );

    testWidgets(
      '[guardian-v2.attendancelistpage-loads-student-attendance-records] AttendanceListPage loads student attendance records',
      (tester) async {
        await openAttendancePage(tester, harness);

        expect(find.text('Présences'), findsWidgets);

        expect(
          probes.attendance,
          isNotEmpty,
          reason: 'Required attendance fixture',
        );
        await pumpUntilFound(tester, find.byType(ListRow));
        expect(find.byType(ListRow), findsWidgets);
      },
    );
  });

  group('student switch', () {
    testWidgets(
      '[guardian-v2.context-sheet-switches-active-linked-student] context sheet switches active linked student',
      (tester) async {
        final switchProbe = probes.studentSwitchProbe;
        expect(switchProbe, isNotNull);

        await openCalendarTab(tester, harness);
        await openChildPicker(tester, harness);

        await tapAlternateStudent(tester, switchProbe!);

        await expectSwitchedStudent(tester, harness, switchProbe);
      },
    );
  });

  group('scolarité', () {
    testWidgets(
      '[guardian-v2.progress-overview] Progress overview shows programme progress from live API',
      (tester) async {
        expect(probes.academic.classSubjects, isNotEmpty);

        await pumpGuardianRoute(
          tester,
          harness,
          location: '/scolarite/progress',
        );

        await pumpUntilFound(
          tester,
          find.textContaining('% du programme couvert'),
          timeout: const Duration(seconds: 45),
        );
        expect(find.textContaining('% du programme couvert'), findsWidgets);
      },
    );

    testWidgets(
      '[guardian-v2.grade-detail-page-shows-assessed-title-from-live-api] grade detail page shows assessed title from live API',
      (tester) async {
        final entry = probes.firstGradedEntry;
        expect(
          entry,
          isNotNull,
          reason: 'The fixture must contain a published grade',
        );

        await pumpGuardianRoute(
          tester,
          harness,
          location: '/grade/${entry!.id}',
        );
        await pumpUntilFound(tester, find.byType(SubjectGradesPage));
        await pumpUntilFound(tester, find.text(entry.title));
        expect(find.text(entry.title), findsWidgets);
        expect(
          harness
              .router
              .routeInformationProvider
              .value
              .uri
              .queryParameters['mark'],
          entry.id,
        );
      },
    );

    testWidgets(
      '[guardian-v2.resultspage-lists-published-report-cards-when-present] ResultsPage lists published report cards when present',
      (tester) async {
        await openScolariteTab(tester, harness);

        expect(
          probes.academic.reportCards,
          isNotEmpty,
          reason: 'The fixture must contain a published report card',
        );

        await pumpUntilFound(tester, find.text('Bulletin publié'));
        expect(find.text('Bulletin publié'), findsWidgets);
      },
    );
  });

  group('fees', () {
    testWidgets(
      '[guardian-v2.feespage-loads-billed-fees-from-the-live-api] FeesPage loads billed fees from the live API',
      (tester) async {
        await openFeesTab(tester, harness);
        await pumpUntilFound(tester, find.text('Résumé'));

        expect(find.byType(SummaryMetric), findsWidgets);

        expect(
          probes.fees.studentCharges,
          isNotEmpty,
          reason: 'Required billing fixture',
        );
        final firstFeeName =
            probes.fees.studentCharges.first['label'] as String;
        expect(firstFeeName, isNotEmpty);
        await pumpUntilFound(tester, find.text(firstFeeName));
        expect(find.text(firstFeeName), findsWidgets);
      },
    );

    testWidgets(
      '[guardian-v2.payment-detail-page-shows-fee-label-from-live-api] payment detail page shows fee label from live API',
      (tester) async {
        final payment = probes.firstPayment;
        expect(payment, isNotNull);

        await pumpGuardianRoute(
          tester,
          harness,
          location: '/fees/payment/${payment!.id}',
        );
        final labels = lookupAppLocalizations(harness.appLocale);
        final detail = find.byType(PaymentDetailPage);
        await pumpUntilFound(
          tester,
          find.descendant(
            of: detail,
            matching: find.text(
              formatMoney(payment.amount, payment.currency, labels.localeName),
            ),
          ),
        );
        expect(
          find.descendant(
            of: detail,
            matching: find.text(formatPaymentKind(labels, payment.kind)),
          ),
          findsWidgets,
        );
        final fee = find.descendant(
          of: detail,
          matching: find.byWidgetPredicate(
            (widget) =>
                widget is SummaryMetric && widget.label == labels.navFees,
          ),
        );
        final chargeLabels = probes.fees.studentCharges
            .map((row) => row['label'])
            .toSet();
        expect(
          tester.widget<SummaryMetric>(fee).value.split(', '),
          everyElement(isIn(chargeLabels)),
        );
      },
    );
  });

  group('inbox', () {
    testWidgets(
      '[guardian-v2.inboxpage-lists-guardian-message-deliveries] InboxPage lists guardian message deliveries',
      (tester) async {
        await openInboxTab(tester, harness);

        expect(
          probes.inbox.deliveries,
          isNotEmpty,
          reason: 'Required inbox fixture',
        );
        final titles = probes.inbox.deliveries
            .map((delivery) => delivery['title'])
            .toSet();
        final visibleDeliveries = find.byWidgetPredicate(
          (widget) => widget is Text && titles.contains(widget.data),
        );
        await pumpUntilFound(tester, visibleDeliveries);
        expect(visibleDeliveries, findsWidgets);
        expect(
          visibleDeliveries.evaluate().length,
          lessThanOrEqualTo(probes.inbox.deliveries.length),
        );
      },
    );

    testWidgets(
      '[guardian-v2.message-detail-page-shows-delivery-title-from-live-api] message detail page shows delivery title from live API',
      (tester) async {
        final delivery = await createInboxFixture(
          owner,
          subjectId: harness.context!.authUserId,
          actorId: harness.context!.grants.actorId,
          actorKind: 'guardian',
        );
        expect(delivery['readAt'], isNull);
        final id = delivery['id'] as String;
        await pumpGuardianRoute(
          tester,
          harness,
          location: inboxMessagePath(id),
        );
        await pumpUntilFound(tester, find.byType(MessageDetailPage));
        final title = find.text(delivery['title'] as String);
        await pumpUntilFound(tester, title);
        expect(title, findsWidgets);
        await pumpUntilFound(tester, find.text('Integration message body'));
        final deadline = DateTime.now().add(const Duration(seconds: 15));
        Map<String, dynamic> persisted;
        do {
          await tester.pump(const Duration(milliseconds: 100));
          persisted = await readSession.schoolClient.messageDeliveries.one({
            'id': id,
          });
        } while (persisted['status'] != 'read' &&
            DateTime.now().isBefore(deadline));
        expect(persisted['status'], 'read');
        expect(persisted['readAt'], isNotNull);
        expect(persisted['recipientId'], harness.context!.grants.actorId);
      },
    );
  });
}

void _koffiYaoSuite() {
  late GuardianWidgetTestHarness harness;
  late GuardianProbeBundle probes;
  late PortalSession readSession;

  setUpAll(() async {
    harness = await GuardianWidgetTestHarness.create(
      profile: GuardianPortalProfile.koffiYao,
    );
    probes = await GuardianProbeBundle.load(harness);
    readSession = harness.portalSession!;
  });

  setUp(() async {
    harness = await GuardianWidgetTestHarness.create(
      profile: GuardianPortalProfile.koffiYao,
      authenticatedSession: readSession,
    );
  });

  testWidgets(
    '[guardian-v2.multi-child-shell-loads-home-for-primary-student] multi-child shell loads home for primary student',
    (tester) async {
      await pumpGuardianShellUntil<HomePage>(tester, harness);

      expect(find.byType(WorkspaceShell), findsOneWidget);
      expect(find.byType(HomePage), findsOneWidget);
      expect(harness.context!.linkedStudents.length, greaterThan(1));
    },
  );

  testWidgets(
    '[guardian-v2.multi-child-calendar-shows-week-controls] multi-child calendar shows week controls',
    (tester) async {
      await openCalendarTab(tester, harness);
      await pumpUntilFound(tester, find.byTooltip('Semaine suivante'));
      expect(find.byTooltip('Semaine suivante'), findsOneWidget);
    },
  );

  testWidgets(
    '[guardian-v2.multi-child-guardian-switches-linked-student] multi-child guardian switches linked student',
    (tester) async {
      final switchProbe = probes.studentSwitchProbe;
      expect(switchProbe, isNotNull);

      await openCalendarTab(tester, harness);
      await openChildPicker(tester, harness);

      await tapAlternateStudent(tester, switchProbe!);
      await expectSwitchedStudent(tester, harness, switchProbe);
    },
  );

  testWidgets(
    '[guardian-v2.multi-child-fees-page-renders-summary] multi-child fees page renders summary',
    (tester) async {
      await openFeesTab(tester, harness);
      await pumpUntilFound(tester, find.byType(FeesPage));
      expect(find.byType(FeesPage), findsOneWidget);
      await pumpUntilFound(tester, find.text('Résumé'));
      expect(find.text('Résumé'), findsWidgets);
    },
  );
}

Future<void> expectSwitchedStudent(
  WidgetTester tester,
  GuardianWidgetTestHarness harness,
  GuardianStudentSwitchProbe probe,
) async {
  final card = find.byType(ChildContextCard);
  await pumpUntilFound(
    tester,
    find.descendant(of: card, matching: find.text(probe.alternateStudentName)),
  );
  expect(
    harness.scope.find<StudentContextController>().activeStudentId,
    probe.alternateStudentId,
  );
  expect(
    find.descendant(of: card, matching: find.text(probe.alternateStudentName)),
    findsOneWidget,
  );
  final alternate = harness.context!.linkedStudents.firstWhere(
    (row) => row['id'] == probe.alternateStudentId,
  );
  expect(alternate['id'], isNot(harness.profile!.primaryStudentId));
}
