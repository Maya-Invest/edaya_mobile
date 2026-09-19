@Tags(['integration'])
library;

import 'package:edaya_integration_tests/edaya_integration_tests.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:levit_flutter/levit_flutter.dart';
import 'package:edaya_teacher/features/account/account_page.dart';
import 'package:edaya_teacher/features/calendar/calendar_page.dart';
import 'package:edaya_teacher/features/classes/classes_page.dart';
import 'package:edaya_teacher/features/evaluations/evaluations_page.dart';
import 'package:edaya_teacher/features/home/home_page.dart';
import 'package:edaya_teacher/features/inbox/inbox_page.dart';

import 'support/integration_test_lifecycle.dart';
import 'support/live_api_test_binding.dart';
import 'support/pump_prototype_page.dart';
import 'support/teacher_live_widget_test_harness.dart';

Future<void> main() async {
  LiveApiWidgetTestBinding();
  Levit.enableAutoLinking();

  final skip = await resolveIntegrationSkipReason();
  if (skip != null) {
    testWidgets('teacher routes integration', (tester) async {}, skip: true);
    return;
  }

  group('teacher routes', _teacherRoutesSuite);
}

void _teacherRoutesSuite() {
  late TeacherLiveWidgetTestHarness harness;

  setUpAll(() async {
    harness = await TeacherLiveWidgetTestHarness.create();
  });

  Future<void> open(WidgetTester tester, String location, Type pageType) async {
    await resetIntegrationTestSurface(tester);
    await configureDesignReviewViewport(tester, DesignReviewFormFactor.phone);
    harness.viewportSize = designReviewLogicalSize(
      DesignReviewFormFactor.phone,
    );
    await tester.pumpWidget(harness.buildRouterApp(initialRoute: location));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1500));
    await pumpUntilFound(tester, find.byType(pageType));
    expect(tester.takeException(), isNull);
  }

  testWidgets('/home opens Accueil', (tester) async {
    await open(tester, '/home', HomePage);
  });

  testWidgets('/calendar opens agenda', (tester) async {
    await open(tester, '/calendar', CalendarPage);
  });

  testWidgets('/classes opens class list', (tester) async {
    await open(tester, '/classes', ClassesPage);
  });

  testWidgets('/evaluations opens evaluations hub', (tester) async {
    await open(tester, '/evaluations', EvaluationsPage);
  });

  testWidgets('/inbox opens messages', (tester) async {
    await open(tester, '/inbox', InboxPage);
  });

  testWidgets('/account opens account', (tester) async {
    await open(tester, '/account', AccountPage);
  });

  testWidgets('/settings opens settings', (tester) async {
    await open(tester, '/settings', SettingsPage);
  });

  testWidgets('/account/profile opens profile', (tester) async {
    await open(tester, '/account/profile', AccountProfilePage);
  });
}
