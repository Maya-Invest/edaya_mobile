@Tags(['design-review'])
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:edaya_guardian/features/account/account_page.dart';
import 'package:edaya_guardian/features/account/account_profile_page.dart';
import 'package:edaya_guardian/features/account/settings_page.dart';
import 'package:edaya_guardian/features/calendar/attendance_page.dart';
import 'package:edaya_guardian/features/calendar/calendar_page.dart';
import 'package:edaya_guardian/features/calendar/session_detail_page.dart';
import 'package:edaya_guardian/features/fees/fee_detail_page.dart';
import 'package:edaya_guardian/features/fees/fees_page.dart';
import 'package:edaya_guardian/features/fees/payment_detail_page.dart';
import 'package:edaya_guardian/features/home/home_page.dart';
import 'package:edaya_guardian/features/inbox/inbox_page.dart';
import 'package:edaya_guardian/features/inbox/message_detail_page.dart';
import 'package:edaya_guardian/features/login/login_page.dart';
import 'package:edaya_guardian/features/scolarite/grade_detail_page.dart';
import 'package:edaya_guardian/features/scolarite/progress_page.dart';
import 'package:edaya_guardian/features/scolarite/report_card_page.dart';
import 'package:edaya_guardian/features/scolarite/results_page.dart';
import 'package:edaya_guardian/features/scolarite/subject_grades_page.dart';
import 'package:edaya_guardian/features/scolarite/subject_logbook_page.dart';
import 'package:edaya_shared/edaya_shared.dart'
    hide LoginPage, SettingsPage, AccountProfilePage;
import 'package:intl/date_symbol_data_local.dart';
import 'package:levit_flutter/levit_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/design_review_capture.dart';
import 'support/design_review_config.dart';
import 'support/design_review_environment.dart';
import 'support/design_review_index.dart';
import 'support/integration_test_lifecycle.dart';
import 'support/prototype_widget_test_harness.dart';
import 'support/pump_prototype_page.dart';

Future<void> main() async {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    Levit.enableAutoLinking();
    await initializeDateFormatting('fr_FR');
    await AppSettingsController.preload();
    await configureDesignReviewEnvironment();
  });
  tearDownAll(resetDesignReviewEnvironment);

  testWidgets(
    'generates local design review pack',
    (tester) async {
      final semantics = tester.ensureSemantics();
      try {
        final localeSlug = designReviewLocaleSlug();
        final localeLabel = designReviewLocaleLabel(localeSlug);

        final outputDir = guardianPrototypeDesignReviewOutputDirectory();
        if (outputDir.existsSync()) {
          for (final entry in outputDir.listSync()) {
            if (entry is Directory &&
                ['dark', 'large-text'].contains(
                  entry.uri.pathSegments.where((s) => s.isNotEmpty).last,
                )) {
              continue;
            }
            entry.deleteSync(recursive: true);
          }
        }
        outputDir.createSync(recursive: true);

        final shots = <DesignReviewShot>[];

        Future<void> captureCurrent({
          required PrototypeWidgetTestHarness harness,
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

        Future<void> navigateTo(
          PrototypeWidgetTestHarness harness,
          String location,
        ) async {
          harness.router.go(location);
          await tester.pump();
          await tester.pump(); // flush shell detail-drawer present callbacks
          await tester.pump(const Duration(milliseconds: 400));
        }

        const authenticatedRoutes =
            <
              ({
                String path,
                String slug,
                String title,
                String description,
                Type pageType,
              })
            >[
              (
                path: '/home',
                slug: '01-home',
                title: 'Home',
                description: 'Action centre with day plan and latest grades.',
                pageType: HomePage,
              ),
              (
                path: '/calendar',
                slug: '02-calendar',
                title: 'Calendar',
                description: 'Week agenda with lessons and school events.',
                pageType: CalendarPage,
              ),
              (
                path: '/attendance',
                slug: '03-attendance-list',
                title: 'Attendance list',
                description: 'Attendance records for the active student.',
                pageType: AttendanceListPage,
              ),
              (
                path: '/session/s1',
                slug: '04-session-details',
                title: 'Session details',
                description: 'Lesson session summary.',
                pageType: SessionDetailPage,
              ),
              (
                path: '/scolarite/notes',
                slug: '05-scolarite-results',
                title: 'Scolarité — results',
                description: 'Trimester results with subject averages.',
                pageType: ResultsPage,
              ),
              (
                path: '/scolarite/progress',
                slug: '06-scolarite-progress',
                title: 'Scolarité — progress',
                description: 'Curriculum progress by subject.',
                pageType: ProgressOverviewPage,
              ),
              (
                path: '/scolarite/period/t1/subject/francais',
                slug: '07-subject-grades',
                title: 'Subject grades',
                description: 'Individual evaluations for a subject.',
                pageType: SubjectGradesPage,
              ),
              (
                path: '/scolarite/subject/francais/cahier',
                slug: '08-subject-logbook',
                title: 'Subject logbook',
                description: 'Cahier de textes entries for a subject.',
                pageType: SubjectLogbookPage,
              ),
              (
                path: '/grade/g1',
                slug: '09-grade-details',
                title: 'Grade details',
                description: 'Single evaluation detail.',
                pageType: GradeDetailPage,
              ),
              (
                path: '/report-card/rc1',
                slug: '10-report-card-details',
                title: 'Report card details',
                description: 'Published trimester bulletin.',
                pageType: ReportCardDetailPage,
              ),
              (
                path: '/fees',
                slug: '11-fees',
                title: 'Fees',
                description: 'Fee summary, lines, and payments.',
                pageType: FeesPage,
              ),
              (
                path: '/fees/fee/f1',
                slug: '12-fee-details',
                title: 'Fee details',
                description: 'Fee line with installments and linked payments.',
                pageType: FeeDetailPage,
              ),
              (
                path: '/fees/payment/p1',
                slug: '13-payment-details',
                title: 'Payment details',
                description: 'Payment receipt.',
                pageType: PaymentDetailPage,
              ),
              (
                path: '/inbox',
                slug: '14-inbox',
                title: 'Inbox',
                description: 'School message deliveries.',
                pageType: InboxPage,
              ),
              (
                path: '/inbox/message/m1',
                slug: '15-message-details',
                title: 'Message details',
                description: 'Inbox message content.',
                pageType: MessageDetailPage,
              ),
              (
                path: '/settings',
                slug: '16-settings',
                title: 'Settings',
                description: 'App preferences.',
                pageType: SettingsPage,
              ),
              (
                path: '/account',
                slug: '17-account',
                title: 'Account',
                description: 'Account actions.',
                pageType: AccountPage,
              ),
              (
                path: '/account/profile',
                slug: '18-account-profile',
                title: 'Account profile',
                description: 'Editable guardian profile.',
                pageType: AccountProfilePage,
              ),
            ];

        for (final formFactor in DesignReviewFormFactor.values.where(
          (factor) =>
              designReviewTextScale() == 1 ||
              factor == DesignReviewFormFactor.phone,
        )) {
          final layoutLabel = formFactor.slug;

          final guestHarness = PrototypeWidgetTestHarness()
            ..bootstrap(authenticated: false);
          await pumpPrototypeApp(tester, guestHarness, formFactor: formFactor);
          await navigateTo(guestHarness, '/login');
          await pumpUntilFound(tester, find.byType(LoginPage));
          await captureCurrent(
            harness: guestHarness,
            formFactor: formFactor,
            slug: '00-login',
            title: 'Login ($layoutLabel, $localeLabel)',
            description: 'Guardian sign-in screen (prototype).',
          );
          await resetIntegrationTestSurface(tester);

          final harness = PrototypeWidgetTestHarness()
            ..bootstrap(authenticated: true);
          await pumpPrototypeApp(tester, harness, formFactor: formFactor);
          await navigateTo(harness, '/home');

          for (final route in authenticatedRoutes) {
            await navigateTo(harness, route.path);
            await pumpUntilFound(tester, find.byType(route.pageType));
            await captureCurrent(
              harness: harness,
              formFactor: formFactor,
              slug: route.slug,
              title: '${route.title} ($layoutLabel, $localeLabel)',
              description: route.description,
            );
          }

          await resetIntegrationTestSurface(tester);
          await resetIntegrationTestViewport(tester);
        }

        writeDesignReviewPack(
          outputDir: outputDir,
          shots: shots,
          localeLabel: localeLabel,
        );

        expect(shots, isNotEmpty);
        expect(File('${outputDir.path}/index.html').existsSync(), isTrue);
      } finally {
        semantics.dispose();
      }
    },
    timeout: const Timeout(Duration(minutes: 15)),
  );
}
