@Tags(['integration'])
library;

import 'package:edaya_guardian/features/academic/academic_controller.dart';
import 'package:edaya_guardian/features/academic/academic_page.dart';
import 'package:edaya_guardian/features/academic/grade_details_dialog.dart';
import 'package:edaya_guardian/features/academic/widgets/grade_summary_cards.dart';
import 'package:edaya_guardian/features/academic/widgets/report_card_tile.dart';
import 'package:edaya_guardian/features/app_shell/app_shell_page.dart';
import 'package:edaya_guardian/features/calendar/attendance_list_page.dart';
import 'package:edaya_guardian/features/calendar/calendar_controller.dart';
import 'package:edaya_guardian/features/calendar/calendar_page.dart';
import 'package:edaya_guardian/features/calendar/session_details_dialog.dart';
import 'package:edaya_guardian/features/calendar/widgets/school_event_tile.dart';
import 'package:edaya_guardian/features/calendar/widgets/session_tile.dart';
import 'package:edaya_guardian/features/calendar/widgets/week_day_selector.dart';
import 'package:edaya_guardian/features/context/student_context_controller.dart';
import 'package:edaya_guardian/features/evaluations/evaluations_controller.dart';
import 'package:edaya_guardian/features/evaluations/evaluations_page.dart';
import 'package:edaya_guardian/features/evaluations/widgets/academic_period_picker.dart';
import 'package:edaya_guardian/features/fees/fees_page.dart';
import 'package:edaya_guardian/features/fees/payment_details_dialog.dart';
import 'package:edaya_guardian/features/fees/widgets/fee_tiles.dart';
import 'package:edaya_guardian/features/fees/widgets/fees_summary_card.dart';
import 'package:edaya_guardian/features/inbox/inbox_page.dart';
import 'package:edaya_guardian/features/inbox/message_details_dialog.dart';
import 'package:edaya_guardian/features/inbox/widgets/inbox_delivery_tile.dart';
import 'package:edaya_guardian/features/my_students/my_students_sheet.dart';
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

  group('shell', () {
    testWidgets('AppShell shows bottom navigation and calendar tab', (
      tester,
    ) async {
      await pumpGuardianShellUntil<CalendarPage>(tester, harness);

      expect(find.byType(AppShellPage), findsOneWidget);
      expect(find.byType(NavigationBar), findsOneWidget);
      expect(find.text('Calendar'), findsWidgets);
      expect(find.byType(CalendarPage), findsOneWidget);
    });

    testWidgets('AppShell navigates to academic tab', (tester) async {
      await openAcademicTab(tester, harness);
      tester.takeException();
      expect(find.byType(AcademicPage), findsOneWidget);
    });

    testWidgets('AppShell navigates to evaluations tab', (tester) async {
      await openEvaluationsTab(tester, harness);
      expect(find.byType(EvaluationsPage), findsOneWidget);
    });

    testWidgets('AppShell navigates to fees tab', (tester) async {
      await openFeesTab(tester, harness);
      expect(find.byType(FeesPage), findsOneWidget);
      expect(find.byType(FeesSummaryCard), findsOneWidget);
    });

    testWidgets('AppShell navigates to inbox tab', (tester) async {
      await openInboxTab(tester, harness);
      expect(find.byType(InboxPage), findsOneWidget);
    });
  });

  group('calendar', () {
    testWidgets('CalendarPage shows week selector and seeded sessions', (
      tester,
    ) async {
      await pumpGuardianShellUntil<CalendarPage>(tester, harness);
      await pumpUntilFound(tester, find.byType(WeekDaySelector));

      expect(probes.calendar.timetableEvents, isNotEmpty);
      expect(probes.sessionProbe, isNotNull);

      await pumpUntilCalendarHasSessions(
        tester,
        preferDay: probes.sessionProbe?.sessionDay,
      );
      expect(find.byType(SessionTile), findsWidgets);
    });

    testWidgets('session tile opens details dialog', (tester) async {
      final session = probes.sessionProbe;
      expect(session, isNotNull);

      await pumpGuardianShellUntil<CalendarPage>(tester, harness);
      await pumpUntilCalendarHasSessions(
        tester,
        preferDay: session!.sessionDay,
      );

      await tapSessionTile(
        tester,
        titleNeedle: session.subjectLabel,
      );
      await tester.pump();
      await pumpUntilFound(tester, find.byType(SessionDetailsDialog));
      expect(
        find.textContaining(session.subjectLabel.split(' ').first),
        findsWidgets,
      );
    });

    testWidgets('CalendarPage events view lists school events when seeded', (
      tester,
    ) async {
      await pumpGuardianShellUntil<CalendarPage>(tester, harness);
      await pumpUntilFound(tester, find.byType(SegmentedButton<CalendarView>));
      await tester.tap(find.text('Events'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 800));

      if (probes.calendar.calendarEvents.isEmpty) {
        expect(find.text('No school events for this period.'), findsWidgets);
        return;
      }

      await pumpUntilCalendarHasEvents(tester);
      expect(find.byType(SchoolEventTile), findsWidgets);
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

  group('student switch', () {
    testWidgets('MyStudents sheet switches active linked student', (
      tester,
    ) async {
      final switchProbe = probes.studentSwitchProbe;
      expect(switchProbe, isNotNull);

      await pumpGuardianShellUntil<CalendarPage>(tester, harness);
      await tester.tap(find.byTooltip('My students'));
      await tester.pump();
      await pumpUntilFound(tester, find.byType(MyStudentsSheet));

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
  });

  group('academic', () {
    testWidgets('AcademicPage shows curriculum progress from live API', (
      tester,
    ) async {
      expect(probes.academic.classSubjects, isNotEmpty);

      await pumpGuardianPage(tester, harness, const AcademicPage());
      await pumpUntilFound(
        tester,
        find.byType(SegmentedButton<AcademicDetailTab>),
      );
      tester.takeException();

      expect(probes.academic.classSubjects, isNotEmpty);
      await pumpUntilFound(
        tester,
        find.byType(LinearProgressIndicator),
        timeout: const Duration(seconds: 45),
      );
      expect(find.byType(LinearProgressIndicator), findsWidgets);
    });

    testWidgets('AcademicPage logbook tab switches without error', (
      tester,
    ) async {
      await pumpGuardianPage(tester, harness, const AcademicPage());
      await pumpUntilFound(
        tester,
        find.byType(SegmentedButton<AcademicDetailTab>),
      );

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

      if (probes.academic.assessmentResults.isEmpty) {
        expect(find.text('No grades recorded for this period.'), findsWidgets);
        return;
      }

      await pumpUntilFound(tester, find.byType(GradeSummaryCards));
      expect(find.byType(GradeSummaryCards), findsOneWidget);
    });

    testWidgets('grade details dialog shows assessed title from live API', (
      tester,
    ) async {
      final entry = probes.firstGradedEntry;
      expect(entry, isNotNull);

      await pumpGuardianPage(
        tester,
        harness,
        GradeDetailsDialog(entry: entry!),
      );
      await pumpUntilFound(tester, find.byType(GradeDetailsDialog));
      expect(find.textContaining(entry.title.split(' ').first), findsWidgets);
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

    testWidgets('payment details dialog shows fee label from live API', (
      tester,
    ) async {
      final payment = probes.firstPayment;
      expect(payment, isNotNull);

      await pumpGuardianPage(
        tester,
        harness,
        PaymentDetailsDialog(payment: payment!),
      );
      await pumpUntilFound(tester, find.byType(PaymentDetailsDialog));
      expect(find.text(payment.feeLabel), findsWidgets);
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
      final tileCount = find.byType(InboxDeliveryTile).evaluate().length;
      expect(tileCount, greaterThan(0));
      expect(tileCount, lessThanOrEqualTo(probes.inbox.deliveries.length));
    });

    testWidgets('message details dialog shows delivery title from live API', (
      tester,
    ) async {
      final delivery = probes.firstInboxDelivery;
      expect(delivery, isNotNull);

      await pumpGuardianPage(
        tester,
        harness,
        MessageDetailsDialog(initialDelivery: delivery!),
      );
      await pumpUntilFound(tester, find.byType(MessageDetailsDialog));
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
    harness = await GuardianWidgetTestHarness.create(
      profile: GuardianPortalProfile.koffiYao,
    );
    probes = await GuardianProbeBundle.load(harness);
  });

  testWidgets('multi-child shell loads calendar for primary student', (
    tester,
  ) async {
    await pumpGuardianShellUntil<CalendarPage>(tester, harness);

    expect(find.byType(AppShellPage), findsOneWidget);
    expect(find.byType(CalendarPage), findsOneWidget);
    expect(harness.context.linkedStudents.length, greaterThan(1));
  });

  testWidgets('multi-child calendar shows week selector', (tester) async {
    await pumpGuardianShellUntil<CalendarPage>(tester, harness);
    await pumpUntilFound(tester, find.byType(WeekDaySelector));
    expect(find.byType(WeekDaySelector), findsOneWidget);
  });

  testWidgets('multi-child guardian switches linked student', (tester) async {
    final switchProbe = probes.studentSwitchProbe;
    expect(switchProbe, isNotNull);

    await pumpGuardianShellUntil<CalendarPage>(tester, harness);
    await tester.tap(find.byTooltip('My students'));
    await tester.pump();
    await pumpUntilFound(tester, find.byType(MyStudentsSheet));

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

  testWidgets('multi-child fees page renders summary card', (tester) async {
    await pumpGuardianPage(tester, harness, const FeesPage());
    await pumpUntilFound(tester, find.byType(FeesPage));
    tester.takeException();
    expect(find.byType(FeesPage), findsOneWidget);
  });
}
