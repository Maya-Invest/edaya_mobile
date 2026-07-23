@Tags(['integration'])
library;

import 'package:edaya_guardian/app/shell_page.dart';
import 'package:edaya_guardian/design/components/list_row.dart';
import 'package:edaya_guardian/design/components/summary_metric.dart';
import 'package:edaya_guardian/features/calendar/calendar_page.dart';
import 'package:edaya_guardian/features/calendar/session_detail_page.dart';
import 'package:edaya_guardian/features/context/student_context_controller.dart';
import 'package:edaya_guardian/features/fees/fees_page.dart';
import 'package:edaya_guardian/features/fees/payment_detail_page.dart';
import 'package:edaya_guardian/features/home/home_page.dart';
import 'package:edaya_guardian/features/inbox/inbox_page.dart';
import 'package:edaya_guardian/features/inbox/message_detail_page.dart';
import 'package:edaya_guardian/features/scolarite/grade_detail_page.dart';
import 'package:edaya_guardian/features/scolarite/results_page.dart';
import 'package:edaya_integration_tests/edaya_integration_tests.dart';
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

  setUpAll(() async {
    harness = await GuardianWidgetTestHarness.create();
    probes = await GuardianProbeBundle.load(harness);
  });

  group('shell', () {
    testWidgets('PrototypeShell shows bottom navigation and home tab', (
      tester,
    ) async {
      await pumpGuardianShellUntil<HomePage>(tester, harness);

      expectGuardianShellChrome();
      expect(find.byType(HomePage), findsOneWidget);
    });

    testWidgets('PrototypeShell navigates to agenda tab', (tester) async {
      await openCalendarTab(tester, harness);
      expect(find.byType(CalendarPage), findsOneWidget);
    });

    testWidgets('PrototypeShell navigates to scolarité tab', (tester) async {
      await openScolariteTab(tester, harness);
      tester.takeException();
      expect(find.byType(ResultsPage), findsOneWidget);
    });

    testWidgets('PrototypeShell navigates to fees tab', (tester) async {
      await openFeesTab(tester, harness);
      expect(find.byType(FeesPage), findsOneWidget);
      expect(find.text('Résumé'), findsWidgets);
    });

    testWidgets('PrototypeShell navigates to inbox tab', (tester) async {
      await openInboxTab(tester, harness);
      expect(find.byType(InboxPage), findsOneWidget);
    });
  });

  group('calendar', () {
    testWidgets('CalendarPage shows week controls and seeded sessions', (
      tester,
    ) async {
      await openCalendarTab(tester, harness);
      await pumpUntilFound(tester, find.byTooltip('Semaine suivante'));

      expect(probes.calendar.timetableEvents, isNotEmpty);
      expect(probes.sessionProbe, isNotNull);

      await pumpUntilCalendarHasSessions(
        tester,
        preferDay: probes.sessionProbe?.sessionDay,
        titleNeedle: probes.sessionProbe?.subjectLabel,
      );
      expect(find.byType(ListRow), findsWidgets);
    });

    testWidgets('session row opens session detail page', (tester) async {
      final session = probes.sessionProbe;
      expect(session, isNotNull);

      await openCalendarTab(tester, harness);
      await pumpUntilCalendarHasSessions(
        tester,
        preferDay: session!.sessionDay,
        titleNeedle: session.subjectLabel,
      );

      await tapSessionRow(tester, titleNeedle: session.subjectLabel);
      await tester.pump();
      await pumpUntilFound(tester, find.byType(SessionDetailPage));
      expect(
        find.textContaining(session.subjectLabel.split(' ').first),
        findsWidgets,
      );
    });

    testWidgets('AttendanceListPage loads student attendance records', (
      tester,
    ) async {
      await openAttendancePage(tester, harness);

      expect(find.text('Présences'), findsWidgets);

      if (probes.attendance.isNotEmpty) {
        await pumpUntilFound(tester, find.byType(ListRow));
        expect(find.byType(ListRow), findsWidgets);
      } else {
        expect(find.text('Aucune présence enregistrée'), findsOneWidget);
      }
    });
  });

  group('student switch', () {
    testWidgets('context sheet switches active linked student', (tester) async {
      final switchProbe = probes.studentSwitchProbe;
      expect(switchProbe, isNotNull);

      await openCalendarTab(tester, harness);
      await openStudentContextSheet(tester);

      await tapAlternateStudent(tester, switchProbe!);

      final deadline = DateTime.now().add(const Duration(seconds: 15));
      while (DateTime.now().isBefore(deadline)) {
        await tester.pump(const Duration(milliseconds: 200));
        final activeId = harness.scope
            .find<StudentContextController>()
            .activeStudent
            .value
            ?.id;
        if (activeId == switchProbe.alternateStudentId) {
          expect(activeId, switchProbe.alternateStudentId);
          return;
        }
      }

      fail('Timed out waiting for active student switch');
    });
  });

  group('scolarité', () {
    testWidgets('ResultsPage shows programme progress from live API', (
      tester,
    ) async {
      expect(probes.academic.classSubjects, isNotEmpty);

      await openScolariteTab(tester, harness);
      tester.takeException();

      await pumpUntilFound(
        tester,
        find.text('Avancement du programme'),
        timeout: const Duration(seconds: 45),
      );
      expect(find.text('Avancement du programme'), findsWidgets);
    });

    testWidgets('grade detail page shows assessed title from live API', (
      tester,
    ) async {
      final entry = probes.firstGradedEntry;
      expect(entry, isNotNull);

      await pumpGuardianRoute(
        tester,
        harness,
        location: '/grade/${entry!.id}',
      );
      await pumpUntilFound(tester, find.byType(GradeDetailPage));
      expect(find.textContaining(entry.title.split(' ').first), findsWidgets);
    });

    testWidgets('ResultsPage lists published report cards when present', (
      tester,
    ) async {
      await openScolariteTab(tester, harness);
      tester.takeException();

      if (probes.academic.reportCards.isEmpty) {
        return;
      }

      await pumpUntilFound(tester, find.text('Bulletin'));
      expect(find.text('Bulletin'), findsWidgets);
    });
  });

  group('fees', () {
    testWidgets('FeesPage loads billed fees from the live API', (tester) async {
      await openFeesTab(tester, harness);
      await pumpUntilFound(tester, find.text('Résumé'));

      expect(find.byType(SummaryMetric), findsWidgets);

      if (probes.fees.feeNamesById.isNotEmpty) {
        final firstFeeName = probes.fees.feeNamesById.values.first;
        expect(find.text(firstFeeName), findsWidgets);
      }
    });

    testWidgets('payment detail page shows fee label from live API', (
      tester,
    ) async {
      final payment = probes.firstPayment;
      expect(payment, isNotNull);

      await pumpGuardianRoute(
        tester,
        harness,
        location: '/fees/payment/${payment!.id}',
      );
      await pumpUntilFound(tester, find.byType(PaymentDetailPage));
      expect(find.text(payment.feeLabel), findsWidgets);
    });
  });

  group('inbox', () {
    testWidgets('InboxPage lists guardian message deliveries', (tester) async {
      await openInboxTab(tester, harness);

      if (probes.inbox.deliveries.isEmpty) {
        expect(
          find.text('Aucun message dans votre boîte de réception.'),
          findsOneWidget,
        );
        return;
      }

      await pumpUntilFound(tester, find.byType(ListRow));
      final tileCount = find.byType(ListRow).evaluate().length;
      expect(tileCount, greaterThan(0));
      expect(tileCount, lessThanOrEqualTo(probes.inbox.deliveries.length));
    });

    testWidgets('message detail page shows delivery title from live API', (
      tester,
    ) async {
      final delivery = probes.firstInboxDelivery;
      expect(delivery, isNotNull);

      await pumpGuardianRoute(
        tester,
        harness,
        location: '/inbox/message/${delivery!.id}',
      );
      await pumpUntilFound(tester, find.byType(MessageDetailPage));
      expect(
        find.textContaining(delivery.title.split(' ').first),
        findsWidgets,
      );
    });
  });
}

void _koffiYaoSuite() {
  late GuardianWidgetTestHarness harness;
  late GuardianProbeBundle probes;

  setUpAll(() async {
    harness = await GuardianWidgetTestHarness.create(
      profile: GuardianPortalProfile.koffiYao,
    );
    probes = await GuardianProbeBundle.load(harness);
  });

  testWidgets('multi-child shell loads home for primary student', (
    tester,
  ) async {
    await pumpGuardianShellUntil<HomePage>(tester, harness);

    expect(find.byType(PrototypeShell), findsOneWidget);
    expect(find.byType(HomePage), findsOneWidget);
    expect(harness.context!.linkedStudents.length, greaterThan(1));
  });

  testWidgets('multi-child calendar shows week controls', (tester) async {
    await openCalendarTab(tester, harness);
    await pumpUntilFound(tester, find.byTooltip('Semaine suivante'));
    expect(find.byTooltip('Semaine suivante'), findsOneWidget);
  });

  testWidgets('multi-child guardian switches linked student', (tester) async {
    final switchProbe = probes.studentSwitchProbe;
    expect(switchProbe, isNotNull);

    await openCalendarTab(tester, harness);
    await openStudentContextSheet(tester);

    await tapAlternateStudent(tester, switchProbe!);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 800));

    final activeId = harness.scope
        .find<StudentContextController>()
        .activeStudent
        .value
        ?.id;
    expect(activeId, switchProbe.alternateStudentId);
  });

  testWidgets('multi-child fees page renders summary', (tester) async {
    await openFeesTab(tester, harness);
    await pumpUntilFound(tester, find.byType(FeesPage));
    tester.takeException();
    expect(find.byType(FeesPage), findsOneWidget);
    expect(find.text('Résumé'), findsWidgets);
  });
}
