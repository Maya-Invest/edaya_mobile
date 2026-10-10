@Tags(['design-review'])
library;

import 'dart:io';

import 'package:edaya_shared/edaya_shared.dart'
    hide LoginPage, SettingsPage, AccountProfilePage;
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:levit_flutter/levit_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:edaya_teacher/features/account/account_page.dart';
import 'package:edaya_teacher/features/calendar/calendar_page.dart';
import 'package:edaya_teacher/features/classes/classes_page.dart';
import 'package:edaya_teacher/features/evaluations/evaluations_page.dart';
import 'package:edaya_teacher/features/evaluations/family_feedback_page.dart';
import 'package:edaya_teacher/features/home/home_page.dart';
import 'package:edaya_teacher/features/inbox/inbox_page.dart';
import 'package:edaya_teacher/features/login/login_page.dart';
import 'package:edaya_teacher/features/session/attendance_page.dart';
import 'package:edaya_teacher/features/session/logbook_page.dart';
import 'package:edaya_teacher/features/session/session_detail_page.dart';

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

        final outputDir = teacherPrototypeDesignReviewOutputDirectory();
        if (outputDir.existsSync()) {
          for (final entry in outputDir.listSync()) {
            if (entry is Directory &&
                ['dark', 'large-text'].contains(
                  entry.uri.pathSegments.where((s) => s.isNotEmpty).last,
                ))
              continue;
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
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 400));
        }

        final authenticatedRoutesBase =
            <
              ({
                String Function(PrototypeWidgetTestHarness) path,
                String slug,
                String title,
                String description,
                Type pageType,
              })
            >[
              (
                path: (_) => '/home',
                slug: '01-home',
                title: 'Home',
                description: 'Today action centre with incomplete tasks.',
                pageType: HomePage,
              ),
              (
                path: (_) => '/calendar',
                slug: '02-calendar',
                title: 'Calendar',
                description: 'Week agenda with teacher sessions.',
                pageType: CalendarPage,
              ),
              (
                path: (h) => '/session/${h.store.sessions.first.id}',
                slug: '03-session',
                title: 'Session details',
                description: 'Session summary with attendance and logbook.',
                pageType: SessionDetailPage,
              ),
              (
                path: (h) => '/session/${h.store.sessions.first.id}/attendance',
                slug: '04-attendance',
                title: 'Attendance',
                description: 'Roster attendance capture.',
                pageType: AttendancePage,
              ),
              (
                path: (h) => '/session/${h.store.sessions.first.id}/logbook',
                slug: '04b-logbook',
                title: 'Logbook',
                description: 'Structured lesson logbook and progress.',
                pageType: LogbookPage,
              ),
              (
                path: (_) => '/classes',
                slug: '05-classes',
                title: 'Classes',
                description: 'Assigned classes and subjects.',
                pageType: ClassesPage,
              ),
              (
                path: (h) => '/classes/${h.store.assignments.first.classId}',
                slug: '06-roster',
                title: 'Class roster',
                description: 'Students in the selected class.',
                pageType: ClassRosterPage,
              ),
              (
                path: (h) =>
                    '/classes/${h.store.assignments.first.classId}/student/${h.store.students.first.id}',
                slug: '06b-student-profile',
                title: 'Student profile',
                description: 'Student identity card in the class workspace.',
                pageType: StudentProfilePage,
              ),
              (
                path: (_) => '/evaluations',
                slug: '07-evaluations',
                title: 'Evaluations',
                description: 'Assessments and report-card hub.',
                pageType: EvaluationsPage,
              ),
              (
                path: (_) => '/evaluations/avis',
                slug: '07b-family-feedback',
                title: 'Family feedback list',
                description:
                    'Teacher family-feedback archive under Evaluations.',
                pageType: FamilyFeedbackListPage,
              ),
              (
                path: (h) =>
                    '/evaluations/avis/${h.store.familyFeedback.first.id}',
                slug: '07c-family-feedback-detail',
                title: 'Family feedback detail',
                description: 'Family-feedback result from the Evaluations hub.',
                pageType: FamilyFeedbackDetailPage,
              ),
              (
                path: (h) => '/home/avis/${h.store.familyFeedback.first.id}',
                slug: '07d-home-family-feedback',
                title: 'Home family feedback',
                description: 'Family-feedback result opened from Accueil.',
                pageType: FamilyFeedbackDetailPage,
              ),
              (
                path: (h) =>
                    '/evaluations/${h.store.evaluations.first.id}/marks',
                slug: '08-marks',
                title: 'Marks entry',
                description: 'Per-student marks for an evaluation.',
                pageType: MarksEntryPage,
              ),
              (
                path: (h) =>
                    '/evaluations/report-cards/${h.store.reportCardClasses.first.classId}/${h.store.reportCardClasses.first.periodId}',
                slug: '08b-bulletin-roster',
                title: 'Bulletin comments',
                description: 'Report-card comment roster for a class period.',
                pageType: ReportCardRosterPage,
              ),
              (
                path: (_) => '/inbox',
                slug: '09-inbox',
                title: 'Inbox',
                description: 'Teacher message list.',
                pageType: InboxPage,
              ),
              (
                path: (h) => '/inbox/message/${h.store.messages.first.id}',
                slug: '10-message',
                title: 'Message details',
                description: 'Inbox message content.',
                pageType: MessageDetailPage,
              ),
              (
                path: (_) => '/account',
                slug: '11-account',
                title: 'Account',
                description: 'Teacher account actions.',
                pageType: AccountPage,
              ),
              (
                path: (_) => '/settings',
                slug: '12-settings',
                title: 'Settings',
                description: 'Language, theme, timezone, and outbox sync.',
                pageType: SettingsPage,
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
            description: 'Teacher sign-in screen (prototype).',
          );
          await resetIntegrationTestSurface(tester);

          final harness = PrototypeWidgetTestHarness()
            ..bootstrap(authenticated: true);
          expect(harness.store.sessions, isNotEmpty);

          await pumpPrototypeApp(tester, harness, formFactor: formFactor);
          await navigateTo(harness, '/home');

          for (final route in authenticatedRoutesBase) {
            await navigateTo(harness, route.path(harness));
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
