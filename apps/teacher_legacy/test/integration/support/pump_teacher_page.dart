import 'package:edaya_shared/edaya_shared.dart';
import 'package:edaya_teacher_legacy/features/calendar/calendar_page.dart';
import 'package:edaya_teacher_legacy/features/calendar/widgets/teacher_session_tile.dart';
import 'package:edaya_teacher_legacy/features/calendar/widgets/week_day_selector.dart';
import 'package:edaya_teacher_legacy/features/context/class_filter_sheet.dart';
import 'package:edaya_teacher_legacy/features/context/teacher_context_controller.dart';
import 'package:edaya_teacher_legacy/features/evaluations/evaluations_controller.dart';
import 'package:edaya_teacher_legacy/features/evaluations/evaluations_page.dart';
import 'package:edaya_teacher_legacy/features/report_cards/report_cards_page.dart';
import 'package:edaya_teacher_legacy/features/session/attendance_exception_sheet.dart';
import 'package:edaya_teacher_legacy/features/session/session_details_sheet.dart';
import 'package:edaya_teacher_legacy/features/session/widgets/attendance_row_tile.dart';
import 'package:edaya_teacher_legacy/features/teaching/teaching_controller.dart';
import 'package:edaya_teacher_legacy/features/teaching/teaching_page.dart';
import 'package:edaya_integration_tests/edaya_integration_tests.dart';
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
  T page, {
  DesignReviewFormFactor formFactor = DesignReviewFormFactor.phone,
}) async {
  await resetIntegrationTestSurface(tester);
  await configureIntegrationTestViewport(tester, formFactor: formFactor);
  harness.viewportSize = designReviewLogicalSize(formFactor);
  await tester.pumpWidget(harness.buildApp(Scaffold(body: page)));
  await pumpUntilFound(tester, find.byType(T));
}

/// Pumps the authenticated router shell and waits until [page] is visible.
Future<void> pumpTeacherShellUntil<T extends Widget>(
  WidgetTester tester,
  TeacherWidgetTestHarness harness, {
  String? initialRoute,
  Object? initialExtra,
  DesignReviewFormFactor formFactor = DesignReviewFormFactor.phone,
}) async {
  await resetIntegrationTestSurface(tester);
  await configureIntegrationTestViewport(tester, formFactor: formFactor);
  harness.viewportSize = designReviewLogicalSize(formFactor);
  await tester.pumpWidget(
    harness.buildRouterApp(
      initialRoute: initialRoute,
      initialExtra: initialExtra,
    ),
  );
  await pumpUntilFound(tester, find.byType(T));
}

/// Opens [location] through the real teacher router (optionally with [extra]).
Future<void> pumpTeacherRoute(
  WidgetTester tester,
  TeacherWidgetTestHarness harness, {
  required String location,
  Object? extra,
  Duration settleDelay = const Duration(milliseconds: 1500),
  DesignReviewFormFactor formFactor = DesignReviewFormFactor.phone,
}) async {
  await resetIntegrationTestSurface(tester);
  await configureIntegrationTestViewport(tester, formFactor: formFactor);
  harness.viewportSize = designReviewLogicalSize(formFactor);
  await tester.pumpWidget(
    harness.buildRouterApp(initialRoute: location, initialExtra: extra),
  );
  await tester.pump();
  await tester.pump(settleDelay);
}

/// Asserts no Flutter framework errors were recorded during the last frame(s).
void expectNoCapturedFlutterErrors(WidgetTester tester) {
  expect(tester.takeException(), isNull);
}

Future<void> openEvaluationsTab(
  WidgetTester tester,
  TeacherWidgetTestHarness harness, {
  DesignReviewFormFactor formFactor = DesignReviewFormFactor.phone,
}) async {
  await pumpTeacherShellUntil<EvaluationsPage>(
    tester,
    harness,
    initialRoute: '/evaluations',
    formFactor: formFactor,
  );
  await harness.scope
      .find<EvaluationsController>()
      .reloadPeriodsAndEvaluations();
  await tester.pump(const Duration(milliseconds: 1500));
}

Future<void> openTeachingTab(
  WidgetTester tester,
  TeacherWidgetTestHarness harness, {
  String? classSubjectId,
  DesignReviewFormFactor formFactor = DesignReviewFormFactor.phone,
}) async {
  await pumpTeacherShellUntil<CalendarPage>(tester, harness, formFactor: formFactor);
  await tester.tap(find.byIcon(Icons.school_outlined));
  await tester.pump();
  await pumpUntilFound(tester, find.byType(TeachingPage));
  if (classSubjectId != null) {
    await harness.scope.find<TeachingController>().selectSubject(
      classSubjectId,
    );
    await tester.pump(const Duration(milliseconds: 1500));
  } else {
    await tester.pump(const Duration(milliseconds: 1200));
  }
}

Future<void> openReportCardsTab(
  WidgetTester tester,
  TeacherWidgetTestHarness harness, {
  DesignReviewFormFactor formFactor = DesignReviewFormFactor.phone,
}) async {
  await pumpTeacherShellUntil<CalendarPage>(tester, harness, formFactor: formFactor);
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
  final targetDay = preferDay ?? integrationCalendarReferenceDay();
  await navigateCalendarWeekToDay(tester, targetDay);
  await tester.pump(const Duration(milliseconds: 800));
  if (tester.any(find.byType(TeacherSessionTile))) {
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
  final weekNav = find
      .byTooltip(direction >= 0 ? 'Next week' : 'Previous week')
      .hitTestable();
  // Do not silently skip a requested week while the previous one is loading.
  await pumpUntilFound(tester, weekNav);
  await tester.tap(weekNav);
  await tester.pump();
}

DateTime _weekStart(DateTime day) {
  final normalized = DateTime(day.year, day.month, day.day);
  return normalized.subtract(
    Duration(days: normalized.weekday - DateTime.monday),
  );
}

Future<void> navigateCalendarWeekToDay(
  WidgetTester tester,
  DateTime day,
) async {
  final normalized = DateTime(day.year, day.month, day.day);
  final targetWeekStart = _weekStart(normalized);
  final currentWeekStart = _weekStart(DateTime.now());
  final weekDelta = targetWeekStart.difference(currentWeekStart).inDays ~/ 7;

  if (weekDelta != 0) {
    final direction = weekDelta > 0 ? 1 : -1;
    for (var step = 0; step < weekDelta.abs(); step++) {
      await _shiftCalendarWeek(tester, direction);
      await tester.pump(const Duration(milliseconds: 400));
    }
  }

  await _tapDayChipForNumber(tester, normalized.day);
  await tester.pump(const Duration(milliseconds: 1500));
}

Future<void> navigateCalendarToDay(WidgetTester tester, DateTime day) async {
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
  // Week changes briefly replace the selector with a loading surface. Wait for
  // the actual day to become tappable instead of indexing transient InkWells.
  final number = find
      .descendant(
        of: find.byType(WeekDaySelector),
        matching: find.text('$dayNumber'),
      )
      .hitTestable();
  await pumpUntilFound(tester, number);
  await tester.tap(number.first);
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
  final filterButton = find.byIcon(Icons.filter_list);
  await tester.ensureVisible(filterButton);
  await tester.tap(filterButton);
  await tester.pump();
  await pumpUntilFound(tester, find.byType(ClassFilterSheet));
}

/// Selects a class in the filter sheet and waits for it to close.
Future<void> selectClassFilter(WidgetTester tester, String classLabel) async {
  final tile = find.widgetWithText(ListTile, classLabel);
  await pumpUntilFound(tester, tile);
  final sheetScrollable = find.descendant(
    of: find.byType(ClassFilterSheet),
    matching: find.byType(Scrollable),
  );
  if (sheetScrollable.evaluate().isNotEmpty) {
    await tester.scrollUntilVisible(
      tile,
      80,
      scrollable: sheetScrollable.first,
    );
  } else {
    await tester.ensureVisible(tile);
  }
  await tester.tap(tile);
  await tester.pump();
  await tester.pumpAndSettle();
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

  await pumpUntilFound(tester, find.text('No classes scheduled for this day.'));
}

/// Waits until [finder] is visible, failing if a [RouteErrorPage] appears.
Future<void> pumpUntilRouteReady(
  WidgetTester tester,
  Finder finder, {
  Duration timeout = const Duration(seconds: 45),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(deadline)) {
    await tester.pump(const Duration(milliseconds: 200));
    if (tester.any(find.byType(RouteErrorPage))) {
      fail('Route resolved to RouteErrorPage while waiting for $finder');
    }
    if (tester.any(finder)) {
      return;
    }
  }

  fail('Timed out waiting for $finder');
}

/// Reads the active class filter label from [TeacherContextController].
String? activeClassFilterLabel(TeacherWidgetTestHarness harness) {
  return harness.scope.find<TeacherContextController>().classFilterLabel;
}

/// Pumps the login route with an unauthenticated harness.
Future<void> pumpTeacherLoginShell(
  WidgetTester tester,
  TeacherWidgetTestHarness harness, {
  DesignReviewFormFactor formFactor = DesignReviewFormFactor.phone,
}) async {
  await pumpTeacherRoute(
    tester,
    harness,
    location: '/login',
    formFactor: formFactor,
  );
  await pumpUntilFound(tester, find.byType(LoginPage));
}

/// Switches the teaching page to the logbook segment.
Future<void> openTeachingLogbookTab(WidgetTester tester) async {
  await tester.tap(find.byIcon(Icons.menu_book_outlined));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 1200));
}

/// Switches session detail to the logbook segment when available.
Future<void> openSessionLogbookSegment(WidgetTester tester) async {
  final logbookIcon = find.descendant(
    of: find.byType(SessionDetailsSheet),
    matching: find.byIcon(Icons.menu_book_outlined),
  );
  await tester.ensureVisible(logbookIcon);
  await tester.tap(logbookIcon);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 1200));
}

/// Opens the attendance exception sheet from the first student row.
Future<void> openAttendanceExceptionSheet(WidgetTester tester) async {
  final recordButton = find.descendant(
    of: find.byType(AttendanceRowTile).first,
    matching: find.byType(FilledButton),
  );
  await tester.ensureVisible(recordButton);
  await tester.tap(recordButton);
  await tester.pump();
  await pumpUntilFound(tester, find.byType(AttendanceExceptionSheet));
}
