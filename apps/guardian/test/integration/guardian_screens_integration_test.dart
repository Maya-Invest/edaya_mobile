@Tags(['integration'])
library;

import 'package:edaya_guardian/app/shell_page.dart';
import 'package:edaya_guardian/design/components/list_row.dart';
import 'package:edaya_guardian/design/components/student_context_card.dart';
import 'package:edaya_guardian/design/components/summary_metric.dart';
import 'package:edaya_guardian/features/calendar/calendar_page.dart';
import 'package:edaya_guardian/features/calendar/session_detail_page.dart';
import 'package:edaya_guardian/features/context/student_context_controller.dart';
import 'package:edaya_guardian/features/fees/fees_page.dart';
import 'package:edaya_guardian/features/fees/payment_detail_page.dart';
import 'package:edaya_guardian/features/home/home_page.dart';
import 'package:edaya_guardian/features/inbox/inbox_page.dart';
import 'package:edaya_guardian/features/inbox/inbox_routes.dart';
import 'package:edaya_guardian/features/inbox/message_detail_page.dart';
import 'package:edaya_guardian/features/scolarite/grade_detail_page.dart';
import 'package:edaya_guardian/features/scolarite/results_page.dart';
import 'package:edaya_integration_tests/edaya_integration_tests.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:levit_flutter/levit_flutter.dart';

import 'support/guardian_probe_bundle.dart';
import 'support/guardian_widget_test_harness.dart';
import 'support/live_api_test_binding.dart';
import 'support/pump_guardian_page.dart';
import 'support/pump_until_found.dart';

Future<void> main() async {
  LiveApiWidgetTestBinding();
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

  setUpAll(() async {
    harness = await GuardianWidgetTestHarness.create();
    probes = await GuardianProbeBundle.load(harness);
    readSession = harness.portalSession!;
  });

  setUp(() async {
    harness = await GuardianWidgetTestHarness.create(
      authenticatedSession: readSession,
    );
  });

  group('shell', () {
    testWidgets(
      '[guardian.prototypeshell-shows-bottom-navigation-and-home-tab] PrototypeShell shows bottom navigation and home tab',
      (tester) async {
        await pumpGuardianShellUntil<HomePage>(tester, harness);

        expectGuardianShellChrome();
        expect(find.byType(HomePage), findsOneWidget);
      },
    );

    testWidgets(
      '[guardian.prototypeshell-navigates-to-agenda-tab] PrototypeShell navigates to agenda tab',
      (tester) async {
        await openCalendarTab(tester, harness);
        expect(find.byType(CalendarPage), findsOneWidget);
      },
    );

    testWidgets(
      '[guardian.prototypeshell-navigates-to-scolarit-tab] PrototypeShell navigates to scolarité tab',
      (tester) async {
        await openScolariteTab(tester, harness);
        expect(find.byType(ResultsPage), findsOneWidget);
      },
    );

    testWidgets(
      '[guardian.prototypeshell-navigates-to-fees-tab] PrototypeShell navigates to fees tab',
      (tester) async {
        await openFeesTab(tester, harness);
        expect(find.byType(FeesPage), findsOneWidget);
        await pumpUntilFound(tester, find.text('Résumé'));
        expect(find.text('Résumé'), findsWidgets);
      },
    );

    testWidgets(
      '[guardian.prototypeshell-navigates-to-inbox-tab] PrototypeShell navigates to inbox tab',
      (tester) async {
        await openInboxTab(tester, harness);
        expect(find.byType(InboxPage), findsOneWidget);
      },
    );
  });

  group('calendar', () {
    testWidgets(
      '[guardian.calendarpage-shows-week-controls-and-seeded-sessions] CalendarPage shows week controls and seeded sessions',
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
      '[guardian.session-row-opens-session-detail-page] session row opens session detail page',
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
      '[guardian.attendancelistpage-loads-student-attendance-records] AttendanceListPage loads student attendance records',
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
      '[guardian.context-sheet-switches-active-linked-student] context sheet switches active linked student',
      (tester) async {
        final switchProbe = probes.studentSwitchProbe;
        expect(switchProbe, isNotNull);

        await openCalendarTab(tester, harness);
        await openStudentContextSheet(tester);

        await tapAlternateStudent(tester, switchProbe!);

        await expectSwitchedStudent(tester, harness, switchProbe);
      },
    );
  });

  group('scolarité', () {
    testWidgets(
      '[guardian.resultspage-shows-programme-progress-from-live-api] ResultsPage shows programme progress from live API',
      (tester) async {
        expect(probes.academic.classSubjects, isNotEmpty);

        await openScolariteTab(tester, harness);

        await pumpUntilFound(
          tester,
          find.text('Avancement du programme'),
          timeout: const Duration(seconds: 45),
        );
        expect(find.text('Avancement du programme'), findsWidgets);
      },
    );

    testWidgets(
      '[guardian.grade-detail-page-shows-assessed-title-from-live-api] grade detail page shows assessed title from live API',
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
        await pumpUntilFound(tester, find.byType(GradeDetailPage));
        await pumpUntilFound(tester, find.text(entry.title));
        expect(find.text(entry.title), findsWidgets);
      },
    );

    testWidgets(
      '[guardian.resultspage-lists-published-report-cards-when-present] ResultsPage lists published report cards when present',
      (tester) async {
        await openScolariteTab(tester, harness);

        expect(
          probes.academic.reportCards,
          isNotEmpty,
          reason: 'The fixture must contain a published report card',
        );

        await pumpUntilFound(tester, find.text('Bulletin'));
        expect(find.text('Bulletin'), findsWidgets);
      },
    );
  });

  group('fees', () {
    testWidgets(
      '[guardian.feespage-loads-billed-fees-from-the-live-api] FeesPage loads billed fees from the live API',
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
      '[guardian.payment-detail-page-shows-fee-label-from-live-api] payment detail page shows fee label from live API',
      (tester) async {
        final payment = probes.firstPayment;
        expect(payment, isNotNull);

        await pumpGuardianRoute(
          tester,
          harness,
          location: '/fees/payment/${payment!.id}',
        );
        await pumpUntilFound(tester, find.byType(PaymentDetailPage));
        await pumpUntilFound(tester, find.text('Montant'));
        expect(find.text('Frais'), findsWidgets);
      },
    );
  });

  group('inbox', () {
    testWidgets(
      '[guardian.inboxpage-lists-guardian-message-deliveries] InboxPage lists guardian message deliveries',
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
      '[guardian.message-detail-page-shows-delivery-title-from-live-api] message detail page shows delivery title from live API',
      (tester) async {
        final delivery = probes.firstInboxDelivery;
        expect(delivery, isNotNull);

        await pumpGuardianRoute(
          tester,
          harness,
          location: inboxMessagePath(delivery!.id),
        );
        await pumpUntilFound(tester, find.byType(MessageDetailPage));
        expect(
          find.textContaining(delivery.title.split(' ').first),
          findsWidgets,
        );
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
    '[guardian.multi-child-shell-loads-home-for-primary-student] multi-child shell loads home for primary student',
    (tester) async {
      await pumpGuardianShellUntil<HomePage>(tester, harness);

      expect(find.byType(PrototypeShell), findsOneWidget);
      expect(find.byType(HomePage), findsOneWidget);
      expect(harness.context!.linkedStudents.length, greaterThan(1));
    },
  );

  testWidgets(
    '[guardian.multi-child-calendar-shows-week-controls] multi-child calendar shows week controls',
    (tester) async {
      await openCalendarTab(tester, harness);
      await pumpUntilFound(tester, find.byTooltip('Semaine suivante'));
      expect(find.byTooltip('Semaine suivante'), findsOneWidget);
    },
  );

  testWidgets(
    '[guardian.multi-child-guardian-switches-linked-student] multi-child guardian switches linked student',
    (tester) async {
      final switchProbe = probes.studentSwitchProbe;
      expect(switchProbe, isNotNull);

      await openCalendarTab(tester, harness);
      await openStudentContextSheet(tester);

      await tapAlternateStudent(tester, switchProbe!);
      await expectSwitchedStudent(tester, harness, switchProbe);
    },
  );

  testWidgets(
    '[guardian.multi-child-fees-page-renders-summary] multi-child fees page renders summary',
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
  final card = find.byWidgetPredicate(
    (widget) =>
        widget is StudentContextCard &&
        widget.studentName == probe.alternateStudentName,
  );
  await pumpUntilFound(tester, card);
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
