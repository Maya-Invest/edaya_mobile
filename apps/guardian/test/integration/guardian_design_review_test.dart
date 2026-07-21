@Tags(['design-review'])
library;

import 'dart:io';

import 'package:edaya_guardian/features/academic/grade_details_dialog.dart';
import 'package:edaya_guardian/features/academic/report_card_details_dialog.dart';
import 'package:edaya_guardian/features/academic/widgets/grade_summary_cards.dart';
import 'package:edaya_guardian/features/academic/widgets/report_card_tile.dart';
import 'package:edaya_guardian/features/account/account_sheet.dart';
import 'package:edaya_guardian/features/calendar/attendance_list_page.dart';
import 'package:edaya_guardian/features/calendar/calendar_page.dart';
import 'package:edaya_guardian/features/calendar/session_details_dialog.dart';
import 'package:edaya_guardian/features/calendar/widgets/school_event_tile.dart';
import 'package:edaya_guardian/features/context/academic_year_picker_sheet.dart';
import 'package:edaya_guardian/features/fees/payment_details_dialog.dart';
import 'package:edaya_guardian/features/fees/widgets/fees_summary_card.dart';
import 'package:edaya_guardian/features/inbox/message_details_dialog.dart';
import 'package:edaya_guardian/features/inbox/widgets/inbox_delivery_tile.dart';
import 'package:edaya_guardian/features/my_students/my_students_sheet.dart';
import 'package:edaya_integration_tests/edaya_integration_tests.dart';
import 'package:edaya_shared/edaya_shared.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:levit_flutter/levit_flutter.dart';

import 'support/design_review_capture.dart';
import 'support/design_review_config.dart';
import 'support/design_review_environment.dart';
import 'support/design_review_index.dart';
import 'support/guardian_probe_bundle.dart';
import 'support/guardian_widget_test_harness.dart';
import 'support/integration_test_lifecycle.dart';
import 'support/live_api_test_binding.dart';
import 'support/pump_guardian_page.dart';
import 'support/pump_until_found.dart';

Future<void> main() async {
  LiveApiWidgetTestBinding();
  Levit.enableAutoLinking();

  final apiError = await resolveDesignReviewApiSkipReason();
  if (apiError != null) {
    test('guardian design review pack', () {
      fail(apiError);
    });
    return;
  }

  setUpAll(configureDesignReviewEnvironment);
  tearDownAll(resetDesignReviewEnvironment);

  testWidgets('generates local design review pack', (tester) async {
    final language = designReviewLanguage();
    final localeSlug = language.name;
    final localeLabel = designReviewLocaleLabel(language);

    final outputDir = guardianDesignReviewOutputDirectory();
    if (outputDir.existsSync()) {
      outputDir.deleteSync(recursive: true);
    }
    outputDir.createSync(recursive: true);

    final config = IntegrationConfig.fromEnvironment();
    final shots = <DesignReviewShot>[];
    var guardianEmail = config.email;

    Future<void> captureCurrent({
      required GuardianWidgetTestHarness harness,
      required DesignReviewFormFactor formFactor,
      required String slug,
      required String title,
      required String description,
    }) async {
      await configureDesignReviewViewport(tester, formFactor);
      harness.viewportSize = designReviewLogicalSize(formFactor);
      await tester.pump();

      final file = designReviewShotFile(
        outputDir,
        formFactor: formFactor.slug,
        locale: localeSlug,
        slug: slug,
      );
      await captureDesignReviewShot(
        tester,
        file,
        logicalSize: designReviewLogicalSize(formFactor),
      );
      shots.add(
        DesignReviewShot(
          relativePath: '${formFactor.slug}-$localeSlug/$slug.png',
          title: title,
          description: description,
        ),
      );
    }

    for (final formFactor in DesignReviewFormFactor.values) {
      final layoutLabel =
          formFactor == DesignReviewFormFactor.phone ? 'phone' : 'tablet';

      final guestHarness = await GuardianWidgetTestHarness.createGuest(
        language: language,
      );
      await pumpGuardianLoginShell(tester, guestHarness, formFactor: formFactor);
      await captureCurrent(
        harness: guestHarness,
        formFactor: formFactor,
        slug: '00-login',
        title: 'Login ($layoutLabel, $localeLabel)',
        description: 'Guardian sign-in screen.',
      );
      await resetIntegrationTestSurface(tester);
      await resetIntegrationTestViewport(tester);
      Levit.reset();

      final harness = await GuardianWidgetTestHarness.create(language: language);
      final probes = await GuardianProbeBundle.load(harness);
      guardianEmail = harness.profile!.email;

      await pumpGuardianShellUntil<CalendarPage>(
        tester,
        harness,
        formFactor: formFactor,
      );
      await pumpUntilCalendarHasSessions(
        tester,
        preferDay: probes.sessionProbe?.sessionDay,
      );
      await captureCurrent(
        harness: harness,
        formFactor: formFactor,
        slug: '01-calendar',
        title: 'Calendar — timetable ($layoutLabel, $localeLabel)',
        description: 'Week view with seeded lesson sessions.',
      );

      if (probes.calendar.calendarEvents.isNotEmpty) {
        await pumpGuardianShellUntil<CalendarPage>(
          tester,
          harness,
          formFactor: formFactor,
        );
        await openCalendarEventsView(tester);
        final eventNearReference = calendarEventNearReference(
          probes.calendar.calendarEvents,
        );
        if (eventNearReference != null) {
          final eventDay = DateTime.parse(
            eventNearReference['startDate'] as String,
          );
          await pumpUntilCalendarHasEvents(tester, preferDay: eventDay);
        }
        if (tester.any(find.byType(SchoolEventTile))) {
          await captureCurrent(
            harness: harness,
            formFactor: formFactor,
            slug: '02-calendar-events',
            title: 'Calendar — events ($layoutLabel, $localeLabel)',
            description: 'School events for the active period.',
          );
        }
      }

      await pumpGuardianRoute(
        tester,
        harness,
        location: '/calendar/attendance',
        formFactor: formFactor,
      );
      await pumpUntilRouteReady(tester, find.byType(AttendanceListPage));
      await captureCurrent(
        harness: harness,
        formFactor: formFactor,
        slug: '03-attendance-list',
        title: 'Attendance list ($layoutLabel, $localeLabel)',
        description: 'All attendance records for the active student.',
      );

      final calendarSession = probes.calendarSession;
      if (calendarSession != null) {
        await pumpGuardianRoute(
          tester,
          harness,
          location: '/calendar/session-details',
          extra: calendarSession,
          formFactor: formFactor,
        );
        await pumpUntilRouteReady(tester, find.byType(SessionDetailsDialog));
        await captureCurrent(
          harness: harness,
          formFactor: formFactor,
          slug: '04-session-details',
          title: 'Session details ($layoutLabel, $localeLabel)',
          description: 'Lesson session summary dialog.',
        );
      }

      await openAcademicTab(tester, harness, formFactor: formFactor);
      await captureCurrent(
        harness: harness,
        formFactor: formFactor,
        slug: '05-academic-progress',
        title: 'Academic — progress ($layoutLabel, $localeLabel)',
        description: 'Curriculum progress for the active student.',
      );

      await openAcademicTab(tester, harness, formFactor: formFactor);
      await openAcademicLogbookTab(tester);
      await captureCurrent(
        harness: harness,
        formFactor: formFactor,
        slug: '06-academic-logbook',
        title: 'Academic — logbook ($layoutLabel, $localeLabel)',
        description: 'Session log entries for the active student.',
      );

      await openEvaluationsTab(tester, harness, formFactor: formFactor);
      if (probes.academic.academicPeriods.isNotEmpty &&
          probes.academic.assessmentResults.isNotEmpty) {
        await pumpUntilFound(tester, find.byType(GradeSummaryCards));
      }
      await captureCurrent(
        harness: harness,
        formFactor: formFactor,
        slug: '07-evaluations-grades',
        title: 'Evaluations — grades ($layoutLabel, $localeLabel)',
        description: 'Grade summaries for the active period.',
      );

      if (probes.academic.reportCards.isNotEmpty) {
        await openEvaluationsTab(tester, harness, formFactor: formFactor);
        await openEvaluationsReportsView(tester);
        await pumpUntilFound(tester, find.byType(ReportCardTile));
        await captureCurrent(
          harness: harness,
          formFactor: formFactor,
          slug: '08-evaluations-reports',
          title: 'Evaluations — report cards ($layoutLabel, $localeLabel)',
          description: 'Published report cards for the active student.',
        );
      }

      final gradedEntry = probes.firstGradedEntry;
      if (gradedEntry != null) {
        await pumpGuardianRoute(
          tester,
          harness,
          location: '/evaluations/grade-details',
          extra: gradedEntry,
          formFactor: formFactor,
        );
        await pumpUntilRouteReady(tester, find.byType(GradeDetailsDialog));
        await captureCurrent(
          harness: harness,
          formFactor: formFactor,
          slug: '09-grade-details',
          title: 'Grade details ($layoutLabel, $localeLabel)',
          description: 'Assessment grade breakdown.',
        );
      }

      final reportCard = probes.firstReportCardSummary;
      if (reportCard != null) {
        await pumpGuardianRoute(
          tester,
          harness,
          location: '/evaluations/report-card-details',
          extra: reportCard,
          formFactor: formFactor,
        );
        await pumpUntilRouteReady(
          tester,
          find.byType(ReportCardDetailsDialog),
        );
        await captureCurrent(
          harness: harness,
          formFactor: formFactor,
          slug: '10-report-card-details',
          title: 'Report card details ($layoutLabel, $localeLabel)',
          description: 'Published report card summary.',
        );
      }

      await openFeesTab(tester, harness, formFactor: formFactor);
      await pumpUntilFound(tester, find.byType(FeesSummaryCard));
      await captureCurrent(
        harness: harness,
        formFactor: formFactor,
        slug: '11-fees',
        title: 'Fees ($layoutLabel, $localeLabel)',
        description: 'Billed fees and payment status.',
      );

      final payment = probes.firstPayment;
      if (payment != null) {
        await pumpGuardianRoute(
          tester,
          harness,
          location: '/fees/payment-details',
          extra: payment,
          formFactor: formFactor,
        );
        await pumpUntilRouteReady(tester, find.byType(PaymentDetailsDialog));
        await captureCurrent(
          harness: harness,
          formFactor: formFactor,
          slug: '12-payment-details',
          title: 'Payment details ($layoutLabel, $localeLabel)',
          description: 'Fee payment receipt details.',
        );
      }

      await openInboxTab(tester, harness, formFactor: formFactor);
      if (probes.inbox.deliveries.isNotEmpty) {
        await pumpUntilFound(tester, find.byType(InboxDeliveryTile));
      }
      await captureCurrent(
        harness: harness,
        formFactor: formFactor,
        slug: '13-inbox',
        title: 'Inbox ($layoutLabel, $localeLabel)',
        description: 'School message deliveries.',
      );

      final delivery = probes.firstInboxDelivery;
      if (delivery != null) {
        await pumpGuardianRoute(
          tester,
          harness,
          location: '/inbox/message',
          extra: delivery,
          formFactor: formFactor,
        );
        await pumpUntilRouteReady(tester, find.byType(MessageDetailsDialog));
        await captureCurrent(
          harness: harness,
          formFactor: formFactor,
          slug: '14-message-details',
          title: 'Message details ($layoutLabel, $localeLabel)',
          description: 'Inbox message content.',
        );
      }

      await pumpGuardianRoute(
        tester,
        harness,
        location: '/settings',
        formFactor: formFactor,
      );
      await pumpUntilFound(tester, find.byType(SettingsPage));
      await captureCurrent(
        harness: harness,
        formFactor: formFactor,
        slug: '15-settings',
        title: 'Settings ($layoutLabel, $localeLabel)',
        description: 'Language and app preferences.',
      );

      await pumpGuardianRoute(
        tester,
        harness,
        location: '/account',
        formFactor: formFactor,
      );
      await pumpUntilFound(tester, find.byType(AccountSheet));
      await captureCurrent(
        harness: harness,
        formFactor: formFactor,
        slug: '16-account',
        title: 'Account ($layoutLabel, $localeLabel)',
        description: 'Account actions sheet.',
      );

      await pumpGuardianRoute(
        tester,
        harness,
        location: '/account/profile',
        formFactor: formFactor,
      );
      await pumpUntilFound(tester, find.byType(AccountProfilePage));
      await captureCurrent(
        harness: harness,
        formFactor: formFactor,
        slug: '17-account-profile',
        title: 'Account profile ($layoutLabel, $localeLabel)',
        description: 'Editable guardian profile.',
      );

      await pumpGuardianRoute(
        tester,
        harness,
        location: '/my-students',
        formFactor: formFactor,
      );
      await pumpUntilFound(tester, find.byType(MyStudentsSheet));
      await captureCurrent(
        harness: harness,
        formFactor: formFactor,
        slug: '18-my-students',
        title: 'My students ($layoutLabel, $localeLabel)',
        description: 'Linked student switcher.',
      );

      await pumpGuardianRoute(
        tester,
        harness,
        location: '/academic-year-picker',
        formFactor: formFactor,
      );
      await pumpUntilFound(tester, find.byType(AcademicYearPickerSheet));
      await captureCurrent(
        harness: harness,
        formFactor: formFactor,
        slug: '19-academic-year-picker',
        title: 'Academic year picker ($layoutLabel, $localeLabel)',
        description: 'School year selection sheet.',
      );

      await resetIntegrationTestSurface(tester);
      await resetIntegrationTestViewport(tester);
      Levit.reset();
    }

    writeDesignReviewPack(
      outputDir: outputDir,
      shots: shots,
      guardianEmail: guardianEmail,
      apiBaseUrl: config.baseUrl,
      localeLabel: localeLabel,
    );

    expect(shots, isNotEmpty);
    expect(File('${outputDir.path}/index.html').existsSync(), isTrue);
  });
}
