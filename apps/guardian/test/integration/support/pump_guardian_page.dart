import 'package:edaya_guardian_v2/app/workspace_shell.dart';
import 'package:edaya_guardian_v2/design/components/list_row.dart';
import 'package:edaya_guardian_v2/features/context/child_picker.dart';
import 'package:edaya_guardian_v2/features/calendar/attendance_page.dart';
import 'package:edaya_guardian_v2/features/calendar/calendar_controller.dart';
import 'package:edaya_guardian_v2/features/calendar/calendar_page.dart';
import 'package:edaya_guardian_v2/features/fees/fees_page.dart';
import 'package:edaya_guardian_v2/features/home/home_page.dart';
import 'package:edaya_guardian_v2/features/inbox/inbox_page.dart';
import 'package:edaya_guardian_v2/features/scolarite/results_page.dart';
import 'package:edaya_integration_tests/edaya_integration_tests.dart';
import 'package:edaya_guardian_v2/features/login/login_page.dart';
import 'package:edaya_shared/edaya_shared.dart' hide LoginPage;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:levit_flutter/levit_flutter.dart';

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
  addTearDown(() async {
    await resetIntegrationTestSurface(tester);
    await resetIntegrationTestViewport(tester);
  });
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
  addTearDown(() async {
    await resetIntegrationTestSurface(tester);
    await resetIntegrationTestViewport(tester);
  });
  await resetIntegrationTestSurface(tester);
  await configureDesignReviewViewport(tester, formFactor);
  harness.viewportSize = designReviewLogicalSize(formFactor);
  await tester.pumpWidget(harness.buildRouterApp(initialRoute: initialRoute));
  await pumpUntilFound(tester, find.byType(T));
}

/// Opens [location] through the real guardian router.
Future<void> pumpGuardianRoute(
  WidgetTester tester,
  GuardianWidgetTestHarness harness, {
  required String location,
  DesignReviewFormFactor formFactor = DesignReviewFormFactor.phone,
}) async {
  addTearDown(() async {
    await resetIntegrationTestSurface(tester);
    await resetIntegrationTestViewport(tester);
  });
  await resetIntegrationTestSurface(tester);
  await configureDesignReviewViewport(tester, formFactor);
  harness.viewportSize = designReviewLogicalSize(formFactor);
  await tester.pumpWidget(harness.buildRouterApp(initialRoute: location));
  await tester.pump();
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

Future<void> openHomeTab(
  WidgetTester tester,
  GuardianWidgetTestHarness harness, {
  DesignReviewFormFactor formFactor = DesignReviewFormFactor.phone,
}) async {
  await pumpGuardianShellUntil<HomePage>(
    tester,
    harness,
    initialRoute: '/home',
    formFactor: formFactor,
  );
}

Future<void> openCalendarTab(
  WidgetTester tester,
  GuardianWidgetTestHarness harness, {
  DesignReviewFormFactor formFactor = DesignReviewFormFactor.phone,
}) async {
  await pumpGuardianShellUntil<CalendarPage>(
    tester,
    harness,
    initialRoute: '/calendar',
    formFactor: formFactor,
  );
  await pumpUntilFound(tester, find.text('Toutes les présences'));
}

Future<void> openScolariteTab(
  WidgetTester tester,
  GuardianWidgetTestHarness harness, {
  DesignReviewFormFactor formFactor = DesignReviewFormFactor.phone,
}) async {
  await pumpGuardianShellUntil<ResultsPage>(
    tester,
    harness,
    initialRoute: '/scolarite/notes',
    formFactor: formFactor,
  );
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
  await pumpUntilFound(tester, find.text('Résumé'));
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
}

Future<void> openAttendancePage(
  WidgetTester tester,
  GuardianWidgetTestHarness harness, {
  DesignReviewFormFactor formFactor = DesignReviewFormFactor.phone,
}) async {
  await pumpGuardianShellUntil<AttendanceListPage>(
    tester,
    harness,
    initialRoute: '/attendance',
    formFactor: formFactor,
  );
}

/// Opens the child picker through the home context card.
Future<void> openChildPicker(
  WidgetTester tester,
  GuardianWidgetTestHarness harness,
) async {
  await harness.scope.find<AppSessionController>().refreshGrants();
  harness.router.go('/home');
  final card = find.byType(ChildContextCard);
  await pumpUntilFound(tester, card);
  await tester.ensureVisible(card);
  await tester.tap(card);
  await pumpUntilFound(tester, find.byType(ChildPicker));
}

CalendarController _calendarController(WidgetTester tester) {
  // Resolve from a descendant inside LScopedView's buildView (page element
  // itself sits above the controller scope).
  final element = tester.element(find.text('Toutes les présences'));
  return element.levit.find<CalendarController>();
}

/// Moves the live [CalendarController] to [day] and waits for data to load.
Future<void> navigateCalendarWeekToDay(
  WidgetTester tester,
  DateTime day,
) async {
  final controller = _calendarController(tester);
  final normalized = DateTime(day.year, day.month, day.day);
  controller.weekStart(startOfWeek(normalized));
  controller.selectDay(normalized);
  await controller.loadCalendarData();
  await tester.pump();

  final deadline = DateTime.now().add(const Duration(seconds: 20));
  while (DateTime.now().isBefore(deadline)) {
    await tester.pump(const Duration(milliseconds: 200));
    if (!controller.isBusy.value) {
      return;
    }
  }
  fail('Calendar data did not finish loading');
}

/// Navigates to [preferDay] via the calendar controller until a session row appears.
Future<void> pumpUntilCalendarHasSessions(
  WidgetTester tester, {
  DateTime? preferDay,
  String? titleNeedle,
  Duration timeout = const Duration(seconds: 45),
}) async {
  final targetDay = preferDay ?? integrationCalendarReferenceDay();
  await navigateCalendarWeekToDay(tester, targetDay);
  if (_sessionRows(tester, titleNeedle).evaluate().isNotEmpty) {
    return;
  }

  final controller = _calendarController(tester);
  final deadline = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(deadline)) {
    for (final day in controller.weekDays) {
      controller.selectDay(day);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      if (_sessionRows(tester, titleNeedle).evaluate().isNotEmpty) {
        return;
      }
    }

    controller.shiftWeek(1);
    await controller.loadCalendarData();
    await tester.pump(const Duration(milliseconds: 500));
    if (_sessionRows(tester, titleNeedle).evaluate().isNotEmpty) {
      return;
    }
  }

  fail('No calendar sessions visible');
}

Finder _sessionRows(WidgetTester tester, String? titleNeedle) {
  if (titleNeedle == null || titleNeedle.isEmpty) {
    return find.byWidgetPredicate((widget) {
      return widget is ListRow && widget.onTap != null;
    });
  }
  final needle = titleNeedle.split(' ').first;
  return find.byWidgetPredicate((widget) {
    if (widget is! ListRow) {
      return false;
    }
    return widget.title.contains(needle) ||
        (widget.subtitle?.contains(needle) ?? false);
  });
}

Future<void> tapSessionRow(WidgetTester tester, {String? titleNeedle}) async {
  final rows = _sessionRows(tester, titleNeedle);
  expect(rows, findsWidgets);
  await tester.tap(rows.first);
}

Future<void> tapAlternateStudent(
  WidgetTester tester,
  GuardianStudentSwitchProbe switchProbe,
) async {
  final fullName = find.text(switchProbe.alternateStudentName);
  await pumpUntilFound(tester, fullName);
  await tester.ensureVisible(fullName.first);
  await tester.tap(fullName.first);
}
