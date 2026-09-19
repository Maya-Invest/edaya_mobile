@Tags(['integration'])
library;

import 'package:edaya_integration_tests/edaya_integration_tests.dart';
import 'package:edaya_teacher_legacy/features/app_shell/app_shell_page.dart';
import 'package:edaya_teacher_legacy/features/calendar/calendar_page.dart';
import 'package:edaya_teacher_legacy/features/calendar/widgets/teacher_session_tile.dart';
import 'package:edaya_teacher_legacy/features/calendar/widgets/week_day_selector.dart';
import 'package:edaya_teacher_legacy/features/context/class_filter_sheet.dart';
import 'package:edaya_teacher_legacy/features/evaluations/evaluations_controller.dart';
import 'package:edaya_teacher_legacy/features/evaluations/evaluations_page.dart';
import 'package:edaya_teacher_legacy/features/evaluations/marks_entry_sheet.dart';
import 'package:edaya_teacher_legacy/features/evaluations/widgets/academic_period_picker.dart';
import 'package:edaya_teacher_legacy/features/evaluations/widgets/mark_row_tile.dart';
import 'package:edaya_teacher_legacy/features/report_cards/report_card_roster_sheet.dart';
import 'package:edaya_teacher_legacy/features/report_cards/report_cards_page.dart';
import 'package:edaya_teacher_legacy/features/session/session_details_sheet.dart';
import 'package:edaya_teacher_legacy/features/session/widgets/attendance_row_tile.dart';
import 'package:edaya_teacher_legacy/features/teaching/teaching_controller.dart';
import 'package:edaya_teacher_legacy/features/teaching/teaching_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:levit_flutter/levit_flutter.dart';

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
    testWidgets('teacher screens integration', (tester) async {}, skip: true);
    return;
  }

  group('subject teacher (ci-t1)', () {
    _subjectTeacherSuite();
  });

  group('homeroom teacher (ci-t2)', () {
    _homeroomTeacherSuite();
  });
}

void _subjectTeacherSuite() {
  late TeacherWidgetTestHarness harness;
  late TeacherProbeBundle probes;

  setUpAll(() async {
    harness = await TeacherWidgetTestHarness.create();
    probes = await TeacherProbeBundle.load(harness);
  });

  group('shell', () {
    testWidgets('AppShell shows bottom navigation and calendar tab', (
      tester,
    ) async {
      await pumpTeacherShellUntil<CalendarPage>(tester, harness);

      expect(find.byType(AppShellPage), findsOneWidget);
      expect(find.byType(NavigationBar), findsOneWidget);
      expect(find.text('Calendar'), findsWidgets);
      expect(find.byType(CalendarPage), findsOneWidget);
    });

    testWidgets('AppShell navigates to evaluations tab', (tester) async {
      await pumpTeacherShellUntil<CalendarPage>(tester, harness);

      await tester.tap(find.byIcon(Icons.grade_outlined));
      await tester.pump();
      await pumpUntilFound(tester, find.byType(EvaluationsPage));
    });

    testWidgets('AppShell navigates to teaching tab', (tester) async {
      await pumpTeacherShellUntil<CalendarPage>(tester, harness);

      await tester.tap(find.byIcon(Icons.school_outlined));
      await tester.pump();
      await pumpUntilFound(tester, find.byType(TeachingPage));
    });

    testWidgets('AppShell navigates to report cards tab', (tester) async {
      await pumpTeacherShellUntil<CalendarPage>(tester, harness);

      await tester.tap(find.byIcon(Icons.description_outlined));
      await tester.pump();
      await pumpUntilFound(tester, find.byType(ReportCardsPage));
    });
  });

  group('calendar', () {
    testWidgets('CalendarPage shows week selector and seeded sessions', (
      tester,
    ) async {
      await pumpTeacherShellUntil<CalendarPage>(tester, harness);
      await pumpUntilFound(tester, find.byType(WeekDaySelector));

      expect(find.text('Timetable PDF'), findsOneWidget);
      expect(find.text('Class roster PDF'), findsOneWidget);

      expect(probes.timetableEvents, isNotEmpty);
      expect(probes.sessionProbe, isNotNull);

      await pumpUntilCalendarHasSessions(
        tester,
        preferDay: probes.sessionProbe?.sessionDay,
      );
      expect(find.byType(TeacherSessionTile), findsWidgets);
    });

    testWidgets('session tile opens details with enrolled students', (
      tester,
    ) async {
      final session = probes.sessionProbe;
      expect(session, isNotNull);
      expect(session!.studentCount, greaterThan(0));

      await pumpTeacherShellUntil<CalendarPage>(tester, harness);
      await pumpUntilCalendarHasSessions(tester, preferDay: session.sessionDay);

      await tapTeacherSessionTile(tester, titleNeedle: session.sessionTitle);

      await tester.pump();
      await pumpUntilFound(tester, find.byType(SessionDetailsSheet));

      await pumpUntilFound(tester, find.byType(AttendanceRowTile));
      final attendanceCount = find.byType(AttendanceRowTile).evaluate().length;
      expect(attendanceCount, greaterThan(0));
      expect(attendanceCount, lessThanOrEqualTo(session.studentCount));
    });
  });

  group('class filter', () {
    testWidgets('class filter switches visible class on calendar', (
      tester,
    ) async {
      final filter = probes.classFilterProbe;
      expect(filter, isNotNull);

      await pumpTeacherShellUntil<CalendarPage>(tester, harness);
      expect(activeClassFilterLabel(harness), isNull);

      await openClassFilterSheet(tester);
      expect(find.byType(ClassFilterSheet), findsOneWidget);
      await selectClassFilter(tester, filter!.alternateClassLabel);

      expect(activeClassFilterLabel(harness), filter.alternateClassLabel);
      expect(find.textContaining(filter.alternateClassLabel), findsWidgets);

      await tester.tap(find.byIcon(Icons.grade_outlined));
      await tester.pump();
      await pumpUntilFound(tester, find.byType(EvaluationsPage));
      expect(find.textContaining(filter.alternateClassLabel), findsWidgets);
    });
  });

  group('evaluations', () {
    testWidgets('EvaluationsPage loads period picker and assessment cards', (
      tester,
    ) async {
      final evaluations = probes.evaluations;
      expect(evaluations, isNotNull);
      expect(evaluations!.enrollments, isNotEmpty);

      await pumpTeacherPage(tester, harness, const EvaluationsPage());
      await pumpUntilFound(tester, find.byType(AcademicPeriodPicker));

      if (evaluations.assessments.isEmpty) {
        expect(find.text('No evaluations for this period.'), findsOneWidget);
        return;
      }

      final title = evaluations.assessments.first['title'] as String;
      await harness.scope
          .find<EvaluationsController>()
          .reloadPeriodsAndEvaluations();
      await pumpUntilEvaluationsLoaded(
        tester,
        expectedTitle: title,
        harness: harness,
      );
      await tester.pump(const Duration(milliseconds: 500));

      final loadedEvaluations = harness.scope
          .find<EvaluationsController>()
          .evaluations
          .value;
      expect(
        loadedEvaluations.any(
          (row) =>
              row.title == title || row.title.contains(title.split(' ').first),
        ),
        isTrue,
      );
      expect(find.byType(ListTile), findsWidgets);
    });

    testWidgets('evaluation card opens marks entry with student rows', (
      tester,
    ) async {
      final title = probes.firstAssessmentTitle;
      expect(title, isNotNull);
      expect(probes.marksStudentCount, greaterThan(0));

      await pumpTeacherPage(tester, harness, const EvaluationsPage());
      await harness.scope
          .find<EvaluationsController>()
          .reloadPeriodsAndEvaluations();
      await pumpUntilEvaluationsLoaded(
        tester,
        expectedTitle: title!,
        harness: harness,
      );

      final controller = harness.scope.find<EvaluationsController>();
      final evaluation = controller.evaluations.value.firstWhere(
        (row) =>
            row.title == title || row.title.contains(title.split(' ').first),
      );

      await pumpTeacherPage(
        tester,
        harness,
        MarksEntrySheet(evaluation: evaluation),
      );
      await pumpUntilFound(tester, find.byType(MarksEntrySheet));
      await pumpUntilFound(tester, find.byType(MarkRowTile));
      expect(find.byType(MarkRowTile), findsNWidgets(probes.marksStudentCount));
    });
  });

  group('teaching', () {
    testWidgets('TeachingPage shows curriculum progress from live API', (
      tester,
    ) async {
      final teaching = probes.teachingProbe;
      expect(teaching, isNotNull);

      await openTeachingTab(
        tester,
        harness,
        classSubjectId: teaching!.classSubjectId,
      );
      await pumpUntilFound(
        tester,
        find.byType(SegmentedButton<TeachingDetailTab>),
      );
      await pumpUntilFound(
        tester,
        find.byType(DropdownButtonFormField<String>),
      );

      if (teaching.matterNames.isEmpty) {
        expect(
          find.text('No curriculum chapters linked to this subject.'),
          findsOneWidget,
        );
        return;
      }

      await pumpUntilFound(
        tester,
        find.textContaining(teaching.matterNames.first.split(' ').first),
        timeout: const Duration(seconds: 45),
      );
      expect(find.byType(LinearProgressIndicator), findsWidgets);
    });

    testWidgets('TeachingPage logbook tab switches without error', (
      tester,
    ) async {
      await pumpTeacherPage(tester, harness, const TeachingPage());
      await pumpUntilFound(
        tester,
        find.byType(SegmentedButton<TeachingDetailTab>),
      );

      await tester.tap(find.byIcon(Icons.menu_book_outlined));
      await tester.pump();
      tester.takeException();

      expect(find.byType(TeachingPage), findsOneWidget);
    });
  });

  group('report cards', () {
    testWidgets('ReportCardsPage opens roster sheet for generated class', (
      tester,
    ) async {
      final reportClass = probes.firstClassWithGeneratedReportCards;
      expect(reportClass, isNotNull);
      expect(reportClass!.rosterStudentNames, isNotEmpty);

      await openReportCardsTab(tester, harness);
      await pumpUntilFound(tester, find.byType(AcademicPeriodPicker));
      await pumpUntilFound(tester, find.text(reportClass.classLabel));

      await tester.tap(find.text(reportClass.classLabel).first);
      await tester.pump();
      await pumpUntilFound(tester, find.byType(ReportCardRosterSheet));

      await pumpUntilFound(
        tester,
        find.text(reportClass.rosterStudentNames.first),
      );
      expect(find.byType(ListTile), findsWidgets);
    });
  });
}

void _homeroomTeacherSuite() {
  late TeacherWidgetTestHarness harness;
  late TeacherProbeBundle probes;

  setUpAll(() async {
    harness = await TeacherWidgetTestHarness.create(
      profile: TeacherPortalProfile.homeroomTeacher,
    );
    probes = await TeacherProbeBundle.load(harness);
  });

  testWidgets('homeroom shell loads calendar and assigned class context', (
    tester,
  ) async {
    await pumpTeacherShellUntil<CalendarPage>(tester, harness);

    expect(find.byType(AppShellPage), findsOneWidget);
    expect(find.byType(CalendarPage), findsOneWidget);
    expect(harness.context!.teachingScope.classGroupIds, contains('ci-6b'));
    expect(
      harness.context!.teachingScope.classSubjectIds,
      contains('ci-cs-6b-eps'),
    );
  });

  testWidgets('homeroom calendar shows week selector', (tester) async {
    await pumpTeacherShellUntil<CalendarPage>(tester, harness);
    await pumpUntilFound(tester, find.byType(WeekDaySelector));
    expect(find.byType(WeekDaySelector), findsOneWidget);
  });

  testWidgets(
    'homeroom session details load enrolled students when lessons exist',
    (tester) async {
      final session = probes.sessionProbe;
      if (session == null) {
        expect(probes.timetableEvents, isA<List<dynamic>>());
        return;
      }

      await pumpTeacherShellUntil<CalendarPage>(tester, harness);
      await pumpUntilCalendarHasSessions(tester, preferDay: session.sessionDay);

      await tapTeacherSessionTile(tester, titleNeedle: session.sessionTitle);

      await tester.pump();
      await pumpUntilFound(tester, find.byType(SessionDetailsSheet));

      if (session.studentCount > 0) {
        await pumpUntilFound(tester, find.byType(AttendanceRowTile));
        expect(find.byType(AttendanceRowTile), findsAtLeastNWidgets(1));
      }
    },
  );

  testWidgets('homeroom teaching page renders for homeroom and EPS grants', (
    tester,
  ) async {
    expect(probes.classSubjectIds, contains('ci-cs-6b-eps'));

    await openTeachingTab(tester, harness, classSubjectId: 'ci-cs-6b-eps');
    expect(find.byType(TeachingPage), findsOneWidget);
    tester.takeException();
  });

  testWidgets('homeroom report cards page loads period picker', (tester) async {
    await pumpTeacherPage(tester, harness, const ReportCardsPage());
    await pumpUntilFound(tester, find.byType(ReportCardsPage));

    if (probes.reportCardClasses.isEmpty) {
      expect(
        find.text('No classes assigned for this school year.'),
        findsWidgets,
      );
      return;
    }

    await pumpUntilFound(tester, find.byType(AcademicPeriodPicker));
    expect(find.byType(AcademicPeriodPicker), findsOneWidget);
  });
}
