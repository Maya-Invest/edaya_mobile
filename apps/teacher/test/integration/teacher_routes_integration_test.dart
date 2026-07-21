@Tags(['integration'])
library;

import 'package:edaya_integration_tests/edaya_integration_tests.dart';
import 'package:edaya_shared/edaya_shared.dart';
import 'package:edaya_teacher/features/account/account_sheet.dart';
import 'package:edaya_teacher/features/calendar/calendar_page.dart';
import 'package:edaya_teacher/features/context/class_filter_sheet.dart';
import 'package:edaya_teacher/features/evaluations/evaluation_create_sheet.dart';
import 'package:edaya_teacher/features/evaluations/evaluations_page.dart';
import 'package:edaya_teacher/features/evaluations/marks_entry_sheet.dart';
import 'package:edaya_teacher/features/report_cards/report_card_comment_sheet.dart';
import 'package:edaya_teacher/features/report_cards/report_card_roster_sheet.dart';
import 'package:edaya_teacher/features/report_cards/report_cards_page.dart';
import 'package:edaya_teacher/features/session/attendance_flow_page.dart';
import 'package:edaya_teacher/features/session/session_details_sheet.dart';
import 'package:edaya_teacher/features/teaching/teaching_page.dart';
import 'package:edaya_teacher/navigation/teacher_route_paths.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:levit_flutter/levit_flutter.dart';

import 'support/integration_test_lifecycle.dart';
import 'support/live_api_test_binding.dart';
import 'support/pump_teacher_page.dart';
import 'support/pump_until_found.dart';
import 'support/teacher_probe_bundle.dart';
import 'support/teacher_widget_test_harness.dart';

Future<void> main() async {
  LiveApiWidgetTestBinding();
  Levit.enableAutoLinking();

  final skip = await resolveIntegrationSkipReason();
  if (skip != null) {
    testWidgets('teacher routes integration', (tester) async {}, skip: true);
    return;
  }

  group('teacher routes (ci-t1)', _teacherRoutesSuite);
}

void _teacherRoutesSuite() {
  late TeacherWidgetTestHarness harness;
  late TeacherProbeBundle probes;

  setUpAll(() async {
    harness = await TeacherWidgetTestHarness.create();
    probes = await TeacherProbeBundle.load(harness);
  });

  group('auth and account', () {
    testWidgets('/login redirects authenticated users to calendar', (
      tester,
    ) async {
      await pumpTeacherRoute(tester, harness, location: '/login');
      await pumpUntilFound(tester, find.byType(CalendarPage));
      expectNoCapturedFlutterErrors(tester);
    });

    testWidgets('/settings opens settings page', (tester) async {
      await pumpTeacherRoute(tester, harness, location: '/settings');
      await pumpUntilFound(tester, find.byType(SettingsPage));
      expectNoCapturedFlutterErrors(tester);
    });

    testWidgets('/account opens account sheet', (tester) async {
      await pumpTeacherRoute(tester, harness, location: '/account');
      await pumpUntilFound(tester, find.byType(AccountSheet));
      expectNoCapturedFlutterErrors(tester);
    });

    testWidgets('/account/profile opens profile page', (tester) async {
      await pumpTeacherRoute(tester, harness, location: '/account/profile');
      await pumpUntilFound(tester, find.byType(AccountProfilePage));
      expectNoCapturedFlutterErrors(tester);
    });
  });

  group('shell tabs', () {
    testWidgets('/calendar opens calendar tab', (tester) async {
      await pumpTeacherRoute(tester, harness, location: TeacherRoutePaths.calendar);
      await pumpUntilFound(tester, find.byType(CalendarPage));
      expectNoCapturedFlutterErrors(tester);
    });

    testWidgets('/evaluations opens evaluations tab', (tester) async {
      await pumpTeacherRoute(tester, harness, location: TeacherRoutePaths.evaluations);
      await pumpUntilFound(tester, find.byType(EvaluationsPage));
      expectNoCapturedFlutterErrors(tester);
    });

    testWidgets('/teaching opens teaching tab', (tester) async {
      await pumpTeacherRoute(tester, harness, location: TeacherRoutePaths.teaching);
      await pumpUntilFound(tester, find.byType(TeachingPage));
      expectNoCapturedFlutterErrors(tester);
    });

    testWidgets('/report-cards opens report cards tab', (tester) async {
      await pumpTeacherRoute(
        tester,
        harness,
        location: TeacherRoutePaths.reportCards,
      );
      await pumpUntilFound(tester, find.byType(ReportCardsPage));
      expectNoCapturedFlutterErrors(tester);
    });

    testWidgets('/class-filter opens class filter sheet', (tester) async {
      await pumpTeacherRoute(tester, harness, location: '/class-filter');
      await pumpUntilFound(tester, find.byType(ClassFilterSheet));
      expectNoCapturedFlutterErrors(tester);
    });
  });

  group('calendar routes', () {
    testWidgets('/calendar/sessions/:id loads session details', (tester) async {
      final session = probes.sessionProbe;
      expect(session, isNotNull, reason: 'seed must expose a lesson session');

      await pumpTeacherRoute(
        tester,
        harness,
        location: TeacherRoutePaths.session(session!.lessonSessionId),
      );
      await pumpUntilRouteReady(tester, find.byType(SessionDetailsSheet));
      expectNoCapturedFlutterErrors(tester);
    });

    testWidgets('/calendar/session-details opens session details with extra', (
      tester,
    ) async {
      final session = probes.resolvedSession;
      expect(session, isNotNull, reason: 'seed must resolve a teacher session');

      await pumpTeacherRoute(
        tester,
        harness,
        location: '/calendar/session-details',
        extra: session,
      );
      await pumpUntilFound(tester, find.byType(SessionDetailsSheet));
      expectNoCapturedFlutterErrors(tester);
    });

    testWidgets('/calendar/attendance-flow opens attendance flow with extra', (
      tester,
    ) async {
      final session = probes.resolvedSession;
      expect(session, isNotNull, reason: 'seed must resolve a teacher session');

      await pumpTeacherRoute(
        tester,
        harness,
        location: '/calendar/attendance-flow',
        extra: session,
      );
      await pumpUntilRouteReady(tester, find.byType(AttendanceFlowPage));
      expectNoCapturedFlutterErrors(tester);
    });
  });

  group('evaluation routes', () {
    testWidgets('/evaluations/create opens create sheet', (tester) async {
      await pumpTeacherRoute(tester, harness, location: '/evaluations/create');
      await pumpUntilFound(tester, find.byType(EvaluationCreateSheet));
      expectNoCapturedFlutterErrors(tester);
    });

    testWidgets('/evaluations/assessments/:id/marks loads marks entry', (
      tester,
    ) async {
      final assessmentId = probes.firstAssessmentId;
      expect(assessmentId, isNotNull, reason: 'seed must expose an assessment');

      await pumpTeacherRoute(
        tester,
        harness,
        location: TeacherRoutePaths.assessmentMarks(assessmentId!),
      );
      await pumpUntilRouteReady(tester, find.byType(MarksEntrySheet));
      expectNoCapturedFlutterErrors(tester);
    });

    testWidgets('/evaluations/marks opens marks entry with extra', (
      tester,
    ) async {
      final evaluation = probes.evaluationSummary;
      expect(evaluation, isNotNull, reason: 'seed must resolve an evaluation');

      await pumpTeacherRoute(
        tester,
        harness,
        location: '/evaluations/marks',
        extra: evaluation,
      );
      await pumpUntilFound(tester, find.byType(MarksEntrySheet));
      expectNoCapturedFlutterErrors(tester);
    });
  });

  group('report card routes', () {
    testWidgets(
      '/report-cards/classes/:classGroupId/periods/:periodId/roster loads roster',
      (tester) async {
        final rosterArgs = probes.reportCardRosterArgs;
        expect(rosterArgs, isNotNull, reason: 'seed must expose report cards');

        await pumpTeacherRoute(
          tester,
          harness,
          location: TeacherRoutePaths.reportCardRoster(
            classGroupId: rosterArgs!.classGroupId,
            periodId: rosterArgs.periodId,
          ),
        );
        await pumpUntilRouteReady(tester, find.byType(ReportCardRosterSheet));
        expectNoCapturedFlutterErrors(tester);
      },
    );

    testWidgets(
      '/report-cards/results/:resultId/students/:studentId/comment loads comment sheet',
      (tester) async {
        final comment = probes.reportCardCommentProbe;
        expect(comment, isNotNull, reason: 'seed must expose a report card');

        await pumpTeacherRoute(
          tester,
          harness,
          location: TeacherRoutePaths.reportCardComment(
            resultId: comment!.resultId,
            studentId: comment.studentId,
          ),
        );
        await pumpUntilRouteReady(tester, find.byType(ReportCardCommentSheet));
        expectNoCapturedFlutterErrors(tester);
      },
    );

    testWidgets('/report-cards/roster opens roster with extra', (tester) async {
      final rosterArgs = probes.reportCardRosterArgs;
      expect(rosterArgs, isNotNull, reason: 'seed must expose report cards');

      await pumpTeacherRoute(
        tester,
        harness,
        location: '/report-cards/roster',
        extra: rosterArgs,
      );
      await pumpUntilFound(tester, find.byType(ReportCardRosterSheet));
      expectNoCapturedFlutterErrors(tester);
    });

    testWidgets('/report-cards/roster/comment opens comment with extra', (
      tester,
    ) async {
      final routeArgs = probes.reportCardCommentRouteArgs;
      expect(routeArgs, isNotNull, reason: 'seed must expose a report card');

      await pumpTeacherRoute(
        tester,
        harness,
        location: '/report-cards/roster/comment',
        extra: routeArgs,
      );
      await pumpUntilFound(tester, find.byType(ReportCardCommentSheet));
      expectNoCapturedFlutterErrors(tester);
    });
  });
}
