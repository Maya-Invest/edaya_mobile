import 'package:edaya_guardian_legacy/features/academic/academic_page.dart';
import 'package:edaya_guardian_legacy/features/calendar/calendar_controller.dart';
import 'package:edaya_guardian_legacy/features/calendar/calendar_page.dart';
import 'package:edaya_guardian_legacy/features/calendar/widgets/school_event_tile.dart';
import 'package:edaya_guardian_legacy/features/calendar/widgets/session_tile.dart';
import 'package:edaya_guardian_legacy/features/calendar/widgets/week_day_selector.dart';
import 'package:edaya_guardian_legacy/features/evaluations/evaluations_page.dart';
import 'package:edaya_guardian_legacy/features/fees/fees_page.dart';
import 'package:edaya_guardian_legacy/features/inbox/inbox_page.dart';
import 'package:edaya_integration_tests/edaya_integration_tests.dart';
import 'package:edaya_shared/edaya_shared.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'guardian_probe_bundle.dart';
import 'guardian_widget_test_harness.dart';
import 'integration_test_lifecycle.dart';
import 'pump_until_found.dart';

/// Pumps [page] inside the guardian integration harness and waits for it to mount.
Future<void> pumpGuardianPage<T extends Widget>(
  WidgetTester tester,
  GuardianWidgetTestHarness harness,
  T page, {
  DesignReviewFormFactor formFactor = DesignReviewFormFactor.phone,
}) async {
  await resetIntegrationTestSurface(tester);
  await configureDesignReviewViewport(tester, formFactor);
  harness.viewportSize = designReviewLogicalSize(formFactor);
  await tester.pumpWidget(harness.buildApp(Scaffold(body: page)));
  await pumpUntilFound(tester, find.byType(T));
}

/// Pumps the authenticated router shell and waits until [page] is visible.
Future<void> pumpGuardianShellUntil<T extends Widget>(
  WidgetTester tester,
  GuardianWidgetTestHarness harness, {
  String? initialRoute,
  DesignReviewFormFactor formFactor = DesignReviewFormFactor.phone,
}) async {
  await resetIntegrationTestSurface(tester);
  await configureDesignReviewViewport(tester, formFactor);
  harness.viewportSize = designReviewLogicalSize(formFactor);
  await tester.pumpWidget(
    harness.buildRouterApp(initialRoute: initialRoute),
  );
  await pumpUntilFound(tester, find.byType(T));
}

/// Opens [location] through the real guardian router (optionally with [extra]).
Future<void> pumpGuardianRoute(
  WidgetTester tester,
  GuardianWidgetTestHarness harness, {
  required String location,
  Object? extra,
  Duration settleDelay = const Duration(milliseconds: 1500),
  DesignReviewFormFactor formFactor = DesignReviewFormFactor.phone,
}) async {
  await resetIntegrationTestSurface(tester);
  await configureDesignReviewViewport(tester, formFactor);
  harness.viewportSize = designReviewLogicalSize(formFactor);
  await tester.pumpWidget(
    harness.buildRouterApp(initialRoute: location, initialExtra: extra),
  );
  await tester.pump();
  await tester.pump(settleDelay);
}

/// Pumps the login route with an unauthenticated harness.
Future<void> pumpGuardianLoginShell(
  WidgetTester tester,
  GuardianWidgetTestHarness harness, {
  DesignReviewFormFactor formFactor = DesignReviewFormFactor.phone,
}) async {
  await pumpGuardianRoute(
    tester,
    harness,
    location: '/login',
    formFactor: formFactor,
  );
  await pumpUntilFound(tester, find.byType(LoginPage));
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

Future<void> openAcademicTab(
  WidgetTester tester,
  GuardianWidgetTestHarness harness, {
  DesignReviewFormFactor formFactor = DesignReviewFormFactor.phone,
}) async {
  await pumpGuardianShellUntil<CalendarPage>(
    tester,
    harness,
    formFactor: formFactor,
  );
  await tester.tap(find.byIcon(Icons.school_outlined));
  await tester.pump();
  await pumpUntilFound(tester, find.byType(AcademicPage));
  await tester.pump(const Duration(milliseconds: 1200));
  tester.takeException();
}

Future<void> openAcademicLogbookTab(WidgetTester tester) async {
  await tester.tap(find.byIcon(Icons.menu_book_outlined));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 1200));
}

Future<void> openEvaluationsTab(
  WidgetTester tester,
  GuardianWidgetTestHarness harness, {
  DesignReviewFormFactor formFactor = DesignReviewFormFactor.phone,
}) async {
  await pumpGuardianShellUntil<EvaluationsPage>(
    tester,
    harness,
    initialRoute: '/evaluations',
    formFactor: formFactor,
  );
  await tester.pump(const Duration(milliseconds: 1200));
}

Future<void> openEvaluationsReportsView(WidgetTester tester) async {
  await tester.tap(find.byIcon(Icons.description_outlined));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 1200));
}

Future<void> openFeesTab(
  WidgetTester tester,
  GuardianWidgetTestHarness harness, {
  DesignReviewFormFactor formFactor = DesignReviewFormFactor.phone,
}) async {
  await pumpGuardianShellUntil<FeesPage>(
    tester,
    harness,
    initialRoute: '/fees',
    formFactor: formFactor,
  );
  await tester.pump(const Duration(milliseconds: 1200));
}

Future<void> openInboxTab(
  WidgetTester tester,
  GuardianWidgetTestHarness harness, {
  DesignReviewFormFactor formFactor = DesignReviewFormFactor.phone,
}) async {
  await pumpGuardianShellUntil<InboxPage>(
    tester,
    harness,
    initialRoute: '/inbox',
    formFactor: formFactor,
  );
  await tester.pump(const Duration(milliseconds: 1200));
}

Future<void> openCalendarEventsView(WidgetTester tester) async {
  await pumpUntilFound(tester, find.byType(SegmentedButton<CalendarView>));
  await tester.tap(find.byIcon(Icons.event));
  await tester.pump();
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
  if (tester.any(find.byType(SessionTile))) {
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
  DateTime? preferDay,
  Duration timeout = const Duration(seconds: 45),
}) async {
  final targetDay = preferDay ?? integrationCalendarReferenceDay();
  await navigateCalendarWeekToDay(tester, targetDay);
  await tester.pump(const Duration(milliseconds: 800));
  if (tester.any(find.byType(SchoolEventTile))) {
    return;
  }

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
  final icon = direction >= 0 ? Icons.chevron_right : Icons.chevron_left;
  final weekNav = find.byIcon(icon);
  if (weekNav.evaluate().isEmpty) {
    return;
  }
  await tester.tap(weekNav);
  await tester.pump();
}

DateTime _weekStart(DateTime day) {
  final normalized = DateTime(day.year, day.month, day.day);
  return normalized.subtract(Duration(days: normalized.weekday - DateTime.monday));
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

Future<void> navigateCalendarToDay(
  WidgetTester tester,
  DateTime day,
) async {
  await navigateCalendarWeekToDay(tester, day);
  if (tester.any(find.byType(SessionTile))) {
    return;
  }

  await pumpUntilCalendarHasSessions(tester);
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
