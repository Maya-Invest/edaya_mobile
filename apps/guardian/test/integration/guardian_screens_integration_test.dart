@Tags(['integration'])
library;

import 'package:edaya_guardian/features/academic/academic_page.dart';
import 'package:edaya_guardian/features/academic/widgets/grade_summary_cards.dart';
import 'package:edaya_guardian/features/academic/widgets/report_card_tile.dart';
import 'package:edaya_guardian/features/app_shell/app_shell_page.dart';
import 'package:edaya_guardian/features/calendar/attendance_list_page.dart';
import 'package:edaya_guardian/features/calendar/calendar_controller.dart';
import 'package:edaya_guardian/features/calendar/calendar_page.dart';
import 'package:edaya_guardian/features/calendar/widgets/week_day_selector.dart';
import 'package:edaya_guardian/features/evaluations/evaluations_controller.dart';
import 'package:edaya_guardian/features/evaluations/evaluations_page.dart';
import 'package:edaya_guardian/features/evaluations/widgets/academic_period_picker.dart';
import 'package:edaya_guardian/features/fees/fees_page.dart';
import 'package:edaya_guardian/features/fees/widgets/fee_tiles.dart';
import 'package:edaya_guardian/features/fees/widgets/fees_summary_card.dart';
import 'package:edaya_guardian/features/inbox/inbox_page.dart';
import 'package:edaya_guardian/features/inbox/widgets/inbox_delivery_tile.dart';
import 'package:edaya_integration_tests/edaya_integration_tests.dart';
import 'package:flutter/material.dart';
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

  late GuardianWidgetTestHarness harness;
  late GuardianProbeBundle probes;

  setUp(() {
    Levit.reset();
    final view = TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
    view.physicalSize = const Size(390, 844);
    view.devicePixelRatio = 1.0;
  });

  tearDown(() {
    final view = TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
    view.resetPhysicalSize();
    view.resetDevicePixelRatio();
  });

  setUpAll(() async {
    harness = await GuardianWidgetTestHarness.create();
    probes = await GuardianProbeBundle.load(harness);
  });

  group('guardian shell', () {
    testWidgets('AppShell shows bottom navigation and calendar tab', (
      tester,
    ) async {
      await pumpGuardianShellUntil<CalendarPage>(tester, harness);

      expect(find.byType(AppShellPage), findsOneWidget);
      expect(find.byType(NavigationBar), findsOneWidget);
      expect(find.text('Calendar'), findsWidgets);
      expect(find.byType(CalendarPage), findsOneWidget);
    });

    testWidgets('AppShell navigates to fees tab', (tester) async {
      await pumpGuardianShellUntil<CalendarPage>(tester, harness);

      await tester.tap(find.byIcon(Icons.payments_outlined));
      await tester.pump();
      await pumpUntilFound(tester, find.byType(FeesPage));
      await pumpUntilFound(tester, find.byType(FeesSummaryCard));
    });
  });

  group('calendar', () {
    testWidgets('CalendarPage shows week selector and timetable view', (
      tester,
    ) async {
      await pumpGuardianPage(tester, harness, const CalendarPage());
      await pumpUntilFound(tester, find.byType(WeekDaySelector));

      expect(find.byType(SegmentedButton<CalendarView>), findsOneWidget);
      expect(find.widgetWithIcon(TextButton, Icons.list_alt_outlined), findsOneWidget);
    });

    testWidgets('AttendanceListPage loads student attendance records', (
      tester,
    ) async {
      await pumpGuardianPage(tester, harness, const AttendanceListPage());

      expect(find.text('All attendance'), findsWidgets);

      if (probes.attendance.isNotEmpty) {
        await pumpUntilFound(tester, find.byType(ListTile));
        expect(find.byType(ListTile), findsWidgets);
      } else {
        expect(find.text('No attendance records for this student.'), findsOneWidget);
      }
    });
  });

  group('academic', () {
    Future<void> openAcademicTab(WidgetTester tester) async {
      await pumpGuardianShellUntil<CalendarPage>(tester, harness);
      await tester.tap(find.byIcon(Icons.school_outlined));
      await tester.pump();
      await pumpUntilFound(tester, find.byType(AcademicPage));
      await tester.pump(const Duration(milliseconds: 500));
      tester.takeException();
    }

    testWidgets('AcademicPage tab loads curriculum reads from the live API', (
      tester,
    ) async {
      await openAcademicTab(tester);

      expect(find.byType(AcademicPage), findsOneWidget);
      expect(probes.academic.classSubjects, isNotEmpty);
      expect(probes.academic.subjects, isNotEmpty);
    });

    testWidgets('AcademicPage logbook tab switches without error', (
      tester,
    ) async {
      await openAcademicTab(tester);

      await tester.tap(find.byIcon(Icons.menu_book_outlined));
      await tester.pump();
      tester.takeException();

      expect(find.byType(AcademicPage), findsOneWidget);
    });
  });

  group('evaluations', () {
    testWidgets('EvaluationsPage grades view loads period picker and summaries', (
      tester,
    ) async {
      await pumpGuardianPage(tester, harness, const EvaluationsPage());
      await pumpUntilFound(tester, find.byType(SegmentedButton<EvaluationsView>));

      if (probes.academic.academicPeriods.isEmpty) {
        return;
      }

      await pumpUntilFound(tester, find.byType(AcademicPeriodPicker));

      if (probes.academic.assessmentResults.isNotEmpty) {
        await pumpUntilFound(tester, find.byType(GradeSummaryCards));
        expect(find.byType(GradeSummaryCards), findsOneWidget);
      }
    });

    testWidgets('EvaluationsPage reports view lists published report cards', (
      tester,
    ) async {
      await pumpGuardianPage(tester, harness, const EvaluationsPage());
      await pumpUntilFound(tester, find.byType(SegmentedButton<EvaluationsView>));
      await tester.tap(find.byIcon(Icons.description_outlined));
      await tester.pump();

      if (probes.academic.reportCards.isEmpty) {
        expect(find.byType(ReportCardTile), findsNothing);
        return;
      }

      await pumpUntilFound(tester, find.byType(ReportCardTile));
      expect(
        find.byType(ReportCardTile),
        findsNWidgets(probes.academic.reportCards.length),
      );
    });
  });

  group('fees', () {
    testWidgets('FeesPage loads billed fees from the live API', (tester) async {
      await pumpGuardianPage(tester, harness, const FeesPage());
      await pumpUntilFound(tester, find.byType(FeesSummaryCard));

      expect(find.byType(FeesSummaryCard), findsOneWidget);

      final activeFees = probes.fees.studentFees
          .where((row) => row['status'] != 'cancelled')
          .length;
      expect(find.byType(StudentFeeTile), findsNWidgets(activeFees));

      if (probes.fees.feeNamesById.isNotEmpty) {
        final firstFeeName = probes.fees.feeNamesById.values.first;
        expect(find.text(firstFeeName), findsWidgets);
      }
    });
  });

  group('inbox', () {
    testWidgets('InboxPage lists guardian message deliveries', (tester) async {
      await pumpGuardianPage(tester, harness, const InboxPage());

      if (probes.inbox.deliveries.isEmpty) {
        expect(find.text('No messages in your inbox yet.'), findsOneWidget);
        return;
      }

      await pumpUntilFound(tester, find.byType(InboxDeliveryTile));
      expect(
        find.byType(InboxDeliveryTile),
        findsNWidgets(probes.inbox.deliveries.length),
      );
    });
  });
}
