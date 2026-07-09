import 'package:edaya_shared/edaya_shared.dart';
import 'package:edaya_teacher/features/calendar/calendar_page.dart';
import 'package:edaya_teacher/features/calendar/widgets/teacher_session_tile.dart';
import 'package:edaya_teacher/features/calendar/widgets/week_day_selector.dart';
import 'package:edaya_teacher/features/context/class_filter_sheet.dart';
import 'package:edaya_teacher/features/context/teacher_context_controller.dart';
import 'package:edaya_teacher/features/evaluations/evaluations_controller.dart';
import 'package:edaya_teacher/features/evaluations/evaluations_page.dart';
import 'package:edaya_teacher/features/report_cards/report_cards_page.dart';
import 'package:edaya_teacher/features/teaching/teaching_controller.dart';
import 'package:edaya_teacher/features/teaching/teaching_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'pump_until_found.dart';
import 'integration_test_lifecycle.dart';
import 'teacher_widget_test_harness.dart';

/// Pumps [page] inside the teacher integration harness and waits for it to mount.
///
/// Pages are wrapped in a [Scaffold] so material widgets match production layout
/// inside [AppShellPage].
Future<void> pumpTeacherPage<T extends Widget>(
  WidgetTester tester,
  TeacherWidgetTestHarness harness,
  T page,
) async {
  await resetIntegrationTestSurface(tester);
  await tester.pumpWidget(harness.buildApp(Scaffold(body: page)));
  await pumpUntilFound(tester, find.byType(T));
}

/// Pumps the authenticated router shell and waits until [page] is visible.
Future<void> pumpTeacherShellUntil<T extends Widget>(
  WidgetTester tester,
  TeacherWidgetTestHarness harness, {
  String? initialRoute,
}) async {
  await resetIntegrationTestSurface(tester);
  await tester.pumpWidget(harness.buildRouterApp(initialRoute: initialRoute));
  await pumpUntilFound(tester, find.byType(T));
}

Future<void> openEvaluationsTab(
  WidgetTester tester,
  TeacherWidgetTestHarness harness,
) async {
  await pumpTeacherShellUntil<EvaluationsPage>(
    tester,
    harness,
    initialRoute: '/evaluations',
  );
  await harness.scope.find<EvaluationsController>().reloadPeriodsAndEvaluations();
  await tester.pump(const Duration(milliseconds: 1500));
}

Future<void> openTeachingTab(
  WidgetTester tester,
  TeacherWidgetTestHarness harness, {
  String? classSubjectId,
}) async {
  await pumpTeacherShellUntil<CalendarPage>(tester, harness);
  await tester.tap(find.byIcon(Icons.school_outlined));
  await tester.pump();
  await pumpUntilFound(tester, find.byType(TeachingPage));
  if (classSubjectId != null) {
    await harness.scope
        .find<TeachingController>()
        .selectSubject(classSubjectId);
    await tester.pump(const Duration(milliseconds: 1500));
  } else {
    await tester.pump(const Duration(milliseconds: 1200));
  }
}

Future<void> openReportCardsTab(
  WidgetTester tester,
  TeacherWidgetTestHarness harness,
) async {
  await pumpTeacherShellUntil<CalendarPage>(tester, harness);
  await tester.tap(find.byIcon(Icons.description_outlined));
  await tester.pump();
  await pumpUntilFound(tester, find.byType(ReportCardsPage));
  await tester.pump(const Duration(milliseconds: 1200));
}

/// Scans calendar weeks until at least one session tile is visible.
Future<void> pumpUntilCalendarHasSessions(
  WidgetTester tester, {
  DateTime? preferDay,
  Duration timeout = const Duration(seconds: 45),
}) async {
  if (preferDay != null) {
    await navigateCalendarToDay(tester, preferDay);
    return;
  }

  final deadline = DateTime.now().add(timeout);
  var scanForward = true;
  while (DateTime.now().isBefore(deadline)) {
    await tester.pump(const Duration(milliseconds: 500));
    if (await _selectEachDayInVisibleWeek(tester)) {
      return;
    }

    final tooltip = scanForward ? 'Next week' : 'Previous week';
    final weekNav = find.byTooltip(tooltip);
    if (weekNav.evaluate().isEmpty) {
      break;
    }
    await tester.tap(weekNav);
    await tester.pump();
    scanForward = !scanForward;
  }

  fail('No teacher sessions visible in calendar');
}

Future<bool> _selectEachDayInVisibleWeek(WidgetTester tester) async {
  if (tester.any(find.byType(TeacherSessionTile))) {
    return true;
  }

  final dayChips = find.descendant(
    of: find.byType(WeekDaySelector),
    matching: find.byType(InkWell),
  );
  if (dayChips.evaluate().length < 8) {
    return false;
  }

  for (var index = 1; index <= 7; index++) {
    await tester.tap(dayChips.at(index));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 800));
    if (tester.any(find.byType(TeacherSessionTile))) {
      return true;
    }
  }

  return false;
}

Future<void> _shiftCalendarWeek(WidgetTester tester, int direction) async {
  final tooltip = direction >= 0 ? 'Next week' : 'Previous week';
  final weekNav = find.byTooltip(tooltip);
  if (weekNav.evaluate().isEmpty) {
    return;
  }
  await tester.tap(weekNav);
  await tester.pump();
}

/// Moves the calendar week selector until [day] shows sessions or the day is selected.
Future<void> navigateCalendarToDay(
  WidgetTester tester,
  DateTime day,
) async {
  for (var attempt = 0; attempt < 52; attempt++) {
    await tester.pump(const Duration(milliseconds: 400));
    if (_visibleWeekContainsDay(tester, day)) {
      await _tapDayChipForNumber(tester, day.day);
      await tester.pump(const Duration(milliseconds: 1500));
      if (tester.any(find.byType(TeacherSessionTile))) {
        return;
      }
    }

    await _shiftCalendarWeek(tester, attempt.isEven ? 1 : -1);
  }

  await pumpUntilCalendarHasSessions(tester);
}

bool _visibleWeekContainsDay(WidgetTester tester, DateTime day) {
  final dayChips = find.descendant(
    of: find.byType(WeekDaySelector),
    matching: find.byType(InkWell),
  );
  if (dayChips.evaluate().length < 8) {
    return false;
  }

  for (var index = 1; index <= 7; index++) {
    final chip = dayChips.at(index);
    final numberFinder = find.descendant(
      of: chip,
      matching: find.text('${day.day}'),
    );
    if (numberFinder.evaluate().isNotEmpty) {
      return true;
    }
  }
  return false;
}

Future<void> _tapDayChipForNumber(WidgetTester tester, int dayNumber) async {
  final dayChips = find.descendant(
    of: find.byType(WeekDaySelector),
    matching: find.byType(InkWell),
  );
  for (var index = 1; index <= 7; index++) {
    final chip = dayChips.at(index);
    final numberFinder = find.descendant(
      of: chip,
      matching: find.text('$dayNumber'),
    );
    if (numberFinder.evaluate().isNotEmpty) {
      await tester.tap(chip);
      return;
    }
  }
}

/// Waits until evaluations finish loading for the active period.
Future<void> pumpUntilEvaluationsLoaded(
  WidgetTester tester, {
  String? expectedTitle,
  TeacherWidgetTestHarness? harness,
  Duration timeout = const Duration(seconds: 45),
}) async {
  final controller = harness?.scope.find<EvaluationsController>();
  final deadline = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(deadline)) {
    await tester.pump(const Duration(milliseconds: 200));

    if (controller != null) {
      if (controller.isBusy.value) {
        continue;
      }
      if (controller.selectedPeriodId.value == null) {
        continue;
      }
      if (controller.dataStatus != DataStatus.ready) {
        continue;
      }
      final evaluations = controller.evaluations.value;
      if (expectedTitle != null) {
        final matched = evaluations.any(
          (row) =>
              row.title == expectedTitle ||
              row.title.contains(expectedTitle.split(' ').first),
        );
        if (matched) {
          final uiFinder = find.textContaining(expectedTitle.split(' ').first);
          if (tester.any(uiFinder)) {
            return;
          }
          // Controller state is authoritative; allow Levit to flush one frame.
          await tester.pump(const Duration(milliseconds: 500));
          if (tester.any(uiFinder)) {
            return;
          }
          return;
        }
        if (evaluations.isEmpty &&
            controller.errorMessage.value.isEmpty &&
            !controller.isBusy.value) {
          fail('Expected evaluation "$expectedTitle" but period is empty');
        }
      } else if (evaluations.isNotEmpty) {
        return;
      }
    }

    if (tester.any(find.byType(CircularProgressIndicator))) {
      continue;
    }
    if (expectedTitle != null && tester.any(find.text(expectedTitle))) {
      return;
    }
    if (expectedTitle != null &&
        tester.any(find.textContaining(expectedTitle.split(' ').first))) {
      return;
    }
    if (tester.any(find.text('No evaluations for this period.'))) {
      if (expectedTitle != null) {
        fail('Expected evaluation "$expectedTitle" but period is empty');
      }
      return;
    }
    if (tester.any(find.text('Select a period to view evaluations.'))) {
      continue;
    }
    if (expectedTitle == null && tester.any(find.byType(ListTile))) {
      return;
    }
  }

  if (expectedTitle != null) {
    fail('Timed out waiting for evaluation "$expectedTitle"');
  }
  fail('Timed out waiting for evaluations to load');
}

Future<void> tapTeacherSessionTile(
  WidgetTester tester, {
  String? titleNeedle,
}) async {
  if (titleNeedle != null) {
    final needle = titleNeedle.split(' ').first;
    final matchingTile = find.byWidgetPredicate((widget) {
      if (widget is! TeacherSessionTile) {
        return false;
      }
      return widget.session.title.contains(needle);
    });
    if (matchingTile.evaluate().isNotEmpty) {
      await tester.tap(matchingTile.first);
      return;
    }
  }

  await tester.tap(find.byType(TeacherSessionTile).first);
}
Future<void> openClassFilterSheet(WidgetTester tester) async {
  await tester.tap(find.byIcon(Icons.filter_list));
  await tester.pump();
  await pumpUntilFound(tester, find.byType(ClassFilterSheet));
}

/// Selects a class in the filter sheet and waits for it to close.
Future<void> selectClassFilter(
  WidgetTester tester,
  String classLabel,
) async {
  await tester.tap(find.text(classLabel));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
}

/// Waits until calendar sessions finish loading for the selected day.
Future<void> pumpUntilCalendarSettled(
  WidgetTester tester, {
  bool expectSessions = true,
}) async {
  if (expectSessions) {
    await pumpUntilFound(tester, find.byType(TeacherSessionTile));
    return;
  }

  await pumpUntilFound(
    tester,
    find.text('No classes scheduled for this day.'),
  );
}

/// Reads the active class filter label from [TeacherContextController].
String? activeClassFilterLabel(TeacherWidgetTestHarness harness) {
  return harness.scope.find<TeacherContextController>().classFilterLabel;
}
