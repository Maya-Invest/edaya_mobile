import 'package:edaya_guardian/features/academic/academic_page.dart';
import 'package:edaya_guardian/features/calendar/calendar_page.dart';
import 'package:edaya_guardian/features/calendar/widgets/school_event_tile.dart';
import 'package:edaya_guardian/features/calendar/widgets/session_tile.dart';
import 'package:edaya_guardian/features/calendar/widgets/week_day_selector.dart';
import 'package:edaya_guardian/features/evaluations/evaluations_page.dart';
import 'package:edaya_guardian/features/fees/fees_page.dart';
import 'package:edaya_guardian/features/inbox/inbox_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'guardian_probe_bundle.dart';
import 'guardian_widget_test_harness.dart';
import 'pump_until_found.dart';

/// Pumps [page] inside the guardian integration harness and waits for it to mount.
///
/// Pages are wrapped in a [Scaffold] so material widgets match production layout
/// inside [AppShellPage].
Future<void> pumpGuardianPage<T extends Widget>(
  WidgetTester tester,
  GuardianWidgetTestHarness harness,
  T page,
) async {
  await tester.pumpWidget(harness.buildApp(Scaffold(body: page)));
  await pumpUntilFound(tester, find.byType(T));
}

/// Pumps the authenticated router shell and waits until [page] is visible.
Future<void> pumpGuardianShellUntil<T extends Widget>(
  WidgetTester tester,
  GuardianWidgetTestHarness harness, {
  String? initialRoute,
}) async {
  await tester.pumpWidget(harness.buildRouterApp(initialRoute: initialRoute));
  await pumpUntilFound(tester, find.byType(T));
}

Future<void> openAcademicTab(
  WidgetTester tester,
  GuardianWidgetTestHarness harness,
) async {
  await pumpGuardianShellUntil<CalendarPage>(tester, harness);
  await tester.tap(find.byIcon(Icons.school_outlined));
  await tester.pump();
  await pumpUntilFound(tester, find.byType(AcademicPage));
  await tester.pump(const Duration(milliseconds: 1200));
  tester.takeException();
}

Future<void> openEvaluationsTab(
  WidgetTester tester,
  GuardianWidgetTestHarness harness,
) async {
  await pumpGuardianShellUntil<EvaluationsPage>(
    tester,
    harness,
    initialRoute: '/evaluations',
  );
  await tester.pump(const Duration(milliseconds: 1200));
}

Future<void> openFeesTab(
  WidgetTester tester,
  GuardianWidgetTestHarness harness,
) async {
  await pumpGuardianShellUntil<FeesPage>(
    tester,
    harness,
    initialRoute: '/fees',
  );
  await tester.pump(const Duration(milliseconds: 1200));
}

Future<void> openInboxTab(
  WidgetTester tester,
  GuardianWidgetTestHarness harness,
) async {
  await pumpGuardianShellUntil<InboxPage>(
    tester,
    harness,
    initialRoute: '/inbox',
  );
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

  fail('No calendar sessions visible');
}

/// Scans calendar weeks until at least one school event tile is visible.
Future<void> pumpUntilCalendarHasEvents(
  WidgetTester tester, {
  Duration timeout = const Duration(seconds: 45),
}) async {
  final deadline = DateTime.now().add(timeout);
  var scanForward = true;
  while (DateTime.now().isBefore(deadline)) {
    await tester.pump(const Duration(milliseconds: 500));
    if (await _selectEachDayUntilTile(tester, SchoolEventTile)) {
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

  fail('No school events visible in calendar');
}

Future<bool> _selectEachDayUntilTile(
  WidgetTester tester,
  Type tileType,
) async {
  if (tester.any(find.byType(tileType))) {
    return true;
  }

  final dayChips = find.descendant(
    of: find.byType(WeekDaySelector),
    matching: find.byType(InkWell),
  );
  if (dayChips.evaluate().length < 7) {
    return false;
  }

  for (var index = 0; index < 7; index++) {
    await tester.tap(dayChips.at(index));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 800));
    if (tester.any(find.byType(tileType))) {
      return true;
    }
  }

  return false;
}

Future<bool> _selectEachDayInVisibleWeek(WidgetTester tester) async {
  return _selectEachDayUntilTile(tester, SessionTile);
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

Future<void> navigateCalendarToDay(
  WidgetTester tester,
  DateTime day,
) async {
  for (var attempt = 0; attempt < 52; attempt++) {
    await tester.pump(const Duration(milliseconds: 400));
    if (_visibleWeekContainsDay(tester, day)) {
      await _tapDayChipForNumber(tester, day.day);
      await tester.pump(const Duration(milliseconds: 1500));
      if (tester.any(find.byType(SessionTile))) {
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
  if (dayChips.evaluate().length < 7) {
    return false;
  }

  for (var index = 0; index < 7; index++) {
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
  for (var index = 0; index < 7; index++) {
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

Future<void> tapSessionTile(
  WidgetTester tester, {
  String? titleNeedle,
}) async {
  if (titleNeedle != null) {
    final needle = titleNeedle.split(' ').first;
    final matchingTile = find.byWidgetPredicate((widget) {
      if (widget is! SessionTile) {
        return false;
      }
      final label = widget.session.subjectLabel ?? widget.session.title;
      return label.contains(needle) || widget.session.title.contains(needle);
    });
    if (matchingTile.evaluate().isNotEmpty) {
      await tester.tap(matchingTile.first);
      return;
    }
  }

  await tester.tap(find.byType(SessionTile).first);
}

/// Waits until guardian grades finish loading for the active period.
Future<void> pumpUntilGradesLoaded(
  WidgetTester tester, {
  String? expectedAssessmentTitle,
  Duration timeout = const Duration(seconds: 45),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(deadline)) {
    await tester.pump(const Duration(milliseconds: 200));
    if (tester.any(find.byType(CircularProgressIndicator))) {
      continue;
    }
    if (expectedAssessmentTitle != null &&
        tester.any(find.textContaining(expectedAssessmentTitle.split(' ').first))) {
      return;
    }
    if (tester.any(find.text('No grades recorded for this period.'))) {
      if (expectedAssessmentTitle != null) {
        fail('Expected grade "$expectedAssessmentTitle" but period is empty');
      }
      return;
    }
    if (tester.any(find.text('Select a period to view evaluations.'))) {
      continue;
    }
    if (expectedAssessmentTitle == null &&
        tester.any(find.byType(ExpansionTile))) {
      return;
    }
  }

  if (expectedAssessmentTitle != null) {
    fail('Timed out waiting for grade "$expectedAssessmentTitle"');
  }
  fail('Timed out waiting for grades to load');
}

/// Taps a [SegmentedButton] segment identified by [label].
Future<void> tapSegmentLabel(WidgetTester tester, String label) async {
  await tester.tap(find.text(label));
  await tester.pump();
}

Future<void> tapAlternateStudent(
  WidgetTester tester,
  GuardianStudentSwitchProbe switchProbe,
) async {
  final fullName = find.text(switchProbe.alternateStudentName);
  if (fullName.evaluate().isNotEmpty) {
    await tester.tap(fullName.first);
    return;
  }

  final firstName = switchProbe.alternateStudentName.split(' ').first;
  await tester.tap(find.textContaining(firstName).first);
}
