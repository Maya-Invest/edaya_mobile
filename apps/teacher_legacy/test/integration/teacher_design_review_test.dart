@Tags(['design-review'])
library;

import 'dart:io';

import 'package:edaya_integration_tests/edaya_integration_tests.dart';
import 'package:edaya_shared/edaya_shared.dart';
import 'package:edaya_teacher_legacy/features/account/account_sheet.dart';
import 'package:edaya_teacher_legacy/features/calendar/calendar_page.dart';
import 'package:edaya_teacher_legacy/features/evaluations/evaluation_create_sheet.dart';
import 'package:edaya_teacher_legacy/features/evaluations/marks_entry_sheet.dart';
import 'package:edaya_teacher_legacy/features/evaluations/widgets/mark_row_tile.dart';
import 'package:edaya_teacher_legacy/features/report_cards/report_card_comment_sheet.dart';
import 'package:edaya_teacher_legacy/features/report_cards/report_card_roster_sheet.dart';
import 'package:edaya_teacher_legacy/features/session/attendance_flow_page.dart';
import 'package:edaya_teacher_legacy/features/session/session_details_sheet.dart';
import 'package:edaya_teacher_legacy/features/session/session_route_args.dart';
import 'package:edaya_teacher_legacy/features/session/widgets/attendance_row_tile.dart';
import 'package:edaya_teacher_legacy/navigation/teacher_route_paths.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:levit_flutter/levit_flutter.dart';

import 'support/design_review_capture.dart';
import 'support/design_review_config.dart';
import 'support/design_review_environment.dart';
import 'support/design_review_index.dart';
import 'support/integration_test_lifecycle.dart';
import 'support/live_api_test_binding.dart';
import 'support/pump_teacher_page.dart';
import 'support/pump_until_found.dart';
import 'support/teacher_probe_bundle.dart';
import 'support/teacher_widget_test_harness.dart';

Future<void> main() async {
  LiveApiWidgetTestBinding();
  Levit.enableAutoLinking();

  final apiError = await resolveDesignReviewApiSkipReason();
  if (apiError != null) {
    test('teacher design review pack', () {
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

    final outputDir = teacherDesignReviewOutputDirectory();
    if (outputDir.existsSync()) {
      outputDir.deleteSync(recursive: true);
    }
    outputDir.createSync(recursive: true);

    final config = IntegrationConfig.fromEnvironment();
    final shots = <DesignReviewShot>[];
    var teacherEmail = config.email;

    Future<void> captureCurrent({
      required TeacherWidgetTestHarness harness,
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

      final guestHarness = await TeacherWidgetTestHarness.createGuest(
        language: language,
      );
      await pumpTeacherLoginShell(tester, guestHarness, formFactor: formFactor);
      await captureCurrent(
        harness: guestHarness,
        formFactor: formFactor,
        slug: '00-login',
        title: 'Login ($layoutLabel, $localeLabel)',
        description: 'Staff sign-in screen.',
      );
      await resetIntegrationTestSurface(tester);
      await resetIntegrationTestViewport(tester);
      Levit.reset();

      final harness = await TeacherWidgetTestHarness.create(language: language);
      final probes = await TeacherProbeBundle.load(harness);
      teacherEmail = harness.profile!.email;

      await pumpTeacherShellUntil<CalendarPage>(
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
        title: 'Calendar ($layoutLabel, $localeLabel)',
        description: 'Week view with seeded sessions.',
      );

      await openEvaluationsTab(tester, harness, formFactor: formFactor);
      final assessmentTitle = probes.firstAssessmentTitle;
      if (assessmentTitle != null) {
        await pumpUntilEvaluationsLoaded(
          tester,
          expectedTitle: assessmentTitle,
          harness: harness,
        );
      }
      await captureCurrent(
        harness: harness,
        formFactor: formFactor,
        slug: '02-evaluations',
        title: 'Evaluations ($layoutLabel, $localeLabel)',
        description: 'Assessment list for the active period.',
      );

      await openTeachingTab(
        tester,
        harness,
        classSubjectId: probes.teachingProbe?.classSubjectId,
        formFactor: formFactor,
      );
      await tester.pump(const Duration(milliseconds: 1200));
      await captureCurrent(
        harness: harness,
        formFactor: formFactor,
        slug: '03-teaching-progress',
        title: 'Teaching — progress ($layoutLabel, $localeLabel)',
        description: 'Curriculum progress for an assigned subject.',
      );

      await openTeachingTab(
        tester,
        harness,
        classSubjectId: probes.teachingProbe?.classSubjectId,
        formFactor: formFactor,
      );
      await openTeachingLogbookTab(tester);
      await captureCurrent(
        harness: harness,
        formFactor: formFactor,
        slug: '04-teaching-logbook',
        title: 'Teaching — logbook ($layoutLabel, $localeLabel)',
        description: 'Session log entries for the selected subject.',
      );

      await openReportCardsTab(tester, harness, formFactor: formFactor);
      await captureCurrent(
        harness: harness,
        formFactor: formFactor,
        slug: '05-report-cards',
        title: 'Report cards ($layoutLabel, $localeLabel)',
        description: 'Class list for report-card comments.',
      );

      await pumpTeacherRoute(
        tester,
        harness,
        location: '/settings',
        formFactor: formFactor,
      );
      await pumpUntilFound(tester, find.byType(SettingsPage));
      await captureCurrent(
        harness: harness,
        formFactor: formFactor,
        slug: '06-settings',
        title: 'Settings ($layoutLabel, $localeLabel)',
        description: 'Language and app preferences.',
      );

      await pumpTeacherRoute(
        tester,
        harness,
        location: '/account',
        formFactor: formFactor,
      );
      await pumpUntilFound(tester, find.byType(AccountSheet));
      await captureCurrent(
        harness: harness,
        formFactor: formFactor,
        slug: '07-account',
        title: 'Account ($layoutLabel, $localeLabel)',
        description: 'Account actions sheet.',
      );

      await pumpTeacherRoute(
        tester,
        harness,
        location: '/account/profile',
        formFactor: formFactor,
      );
      await pumpUntilFound(tester, find.byType(AccountProfilePage));
      await captureCurrent(
        harness: harness,
        formFactor: formFactor,
        slug: '08-account-profile',
        title: 'Account profile ($layoutLabel, $localeLabel)',
        description: 'Editable teacher profile.',
      );

      await pumpTeacherShellUntil<CalendarPage>(
        tester,
        harness,
        formFactor: formFactor,
      );
      await openClassFilterSheet(tester);
      await captureCurrent(
        harness: harness,
        formFactor: formFactor,
        slug: '09-class-filter',
        title: 'Class filter ($layoutLabel, $localeLabel)',
        description: 'Filter calendar and lists by class.',
      );

      await pumpTeacherRoute(
        tester,
        harness,
        location: '/evaluations/create',
        formFactor: formFactor,
      );
      await pumpUntilFound(tester, find.byType(EvaluationCreateSheet));
      await captureCurrent(
        harness: harness,
        formFactor: formFactor,
        slug: '10-evaluation-create',
        title: 'Create evaluation ($layoutLabel, $localeLabel)',
        description: 'New assessment form.',
      );

      final session = probes.sessionProbe;
      if (session != null) {
        await pumpTeacherShellUntil<CalendarPage>(
          tester,
          harness,
          formFactor: formFactor,
        );
        await pumpUntilCalendarHasSessions(
          tester,
          preferDay: session.sessionDay,
        );
        await tapTeacherSessionTile(
          tester,
          titleNeedle: session.sessionTitle,
        );
        await tester.pump();
        await pumpUntilFound(tester, find.byType(SessionDetailsSheet));
        if (session.studentCount > 0) {
          await pumpUntilFound(tester, find.byType(AttendanceRowTile));
        }
        await captureCurrent(
          harness: harness,
          formFactor: formFactor,
          slug: '11-session-detail',
          title: 'Session detail ($layoutLabel, $localeLabel)',
          description: 'Attendance sheet for a seeded lesson.',
        );

        if (session.studentCount > 0) {
          await openAttendanceExceptionSheet(tester);
          await captureCurrent(
            harness: harness,
            formFactor: formFactor,
            slug: '12-attendance-exception',
            title: 'Attendance exception ($layoutLabel, $localeLabel)',
            description: 'Record absence, lateness, or excuse.',
          );
        }

        final resolvedSession = probes.resolvedSession;
        if (resolvedSession != null && session.studentCount > 0) {
          await pumpTeacherRoute(
            tester,
            harness,
            location: '/calendar/attendance-flow',
            extra: AttendanceFlowArgs(session: resolvedSession),
            formFactor: formFactor,
          );
          await pumpUntilRouteReady(tester, find.byType(AttendanceFlowPage));
          await captureCurrent(
            harness: harness,
            formFactor: formFactor,
            slug: '13-attendance-flow',
            title: 'Attendance flow ($layoutLabel, $localeLabel)',
            description: 'Swipe-based attendance capture.',
          );

          await pumpTeacherRoute(
            tester,
            harness,
            location: TeacherRoutePaths.session(session.lessonSessionId),
            formFactor: formFactor,
          );
          await pumpUntilRouteReady(tester, find.byType(SessionDetailsSheet));
          if (find
              .descendant(
                of: find.byType(SessionDetailsSheet),
                matching: find.byIcon(Icons.menu_book_outlined),
              )
              .evaluate()
              .isNotEmpty) {
            await openSessionLogbookSegment(tester);
            await captureCurrent(
              harness: harness,
              formFactor: formFactor,
              slug: '14-session-logbook',
              title: 'Session logbook ($layoutLabel, $localeLabel)',
              description: 'Structured lesson log for a session.',
            );
          }
        }
      }

      final assessmentId = probes.firstAssessmentId;
      if (assessmentId != null && probes.marksStudentCount > 0) {
        await pumpTeacherRoute(
          tester,
          harness,
          location: TeacherRoutePaths.assessmentMarks(assessmentId),
          formFactor: formFactor,
        );
        await pumpUntilRouteReady(tester, find.byType(MarksEntrySheet));
        await pumpUntilFound(tester, find.byType(MarkRowTile));
        await captureCurrent(
          harness: harness,
          formFactor: formFactor,
          slug: '15-marks-entry',
          title: 'Marks entry ($layoutLabel, $localeLabel)',
          description: 'Grade entry sheet for a seeded assessment.',
        );
      }

      final rosterArgs = probes.reportCardRosterArgs;
      if (rosterArgs != null) {
        await pumpTeacherRoute(
          tester,
          harness,
          location: TeacherRoutePaths.reportCardRoster(
            classGroupId: rosterArgs.classGroupId,
            periodId: rosterArgs.periodId,
          ),
          formFactor: formFactor,
        );
        await pumpUntilRouteReady(tester, find.byType(ReportCardRosterSheet));
        await captureCurrent(
          harness: harness,
          formFactor: formFactor,
          slug: '16-report-card-roster',
          title: 'Report card roster ($layoutLabel, $localeLabel)',
          description: 'Student list for report-card comments.',
        );
      }

      final comment = probes.reportCardCommentProbe;
      if (comment != null) {
        await pumpTeacherRoute(
          tester,
          harness,
          location: TeacherRoutePaths.reportCardComment(
            resultId: comment.resultId,
            studentId: comment.studentId,
          ),
          formFactor: formFactor,
        );
        await pumpUntilRouteReady(tester, find.byType(ReportCardCommentSheet));
        await captureCurrent(
          harness: harness,
          formFactor: formFactor,
          slug: '17-report-card-comment',
          title: 'Report card comment ($layoutLabel, $localeLabel)',
          description: 'Per-student report-card comment editor.',
        );
      }

      await resetIntegrationTestSurface(tester);
      await resetIntegrationTestViewport(tester);
      Levit.reset();
    }

    writeDesignReviewPack(
      outputDir: outputDir,
      shots: shots,
      teacherEmail: teacherEmail,
      apiBaseUrl: config.baseUrl,
      localeLabel: localeLabel,
    );

    expect(shots, isNotEmpty);
    expect(File('${outputDir.path}/index.html').existsSync(), isTrue);
  });
}
