import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:levit_flutter/levit_flutter.dart';
import 'package:teacher_prototype/features/calendar/calendar_page.dart';
import 'package:teacher_prototype/features/classes/classes_page.dart';
import 'package:teacher_prototype/features/evaluations/evaluations_page.dart';
import 'package:teacher_prototype/features/home/home_page.dart';
import 'package:teacher_prototype/features/inbox/inbox_page.dart';
import 'package:teacher_prototype/features/login/login_page.dart';
import 'package:teacher_prototype/features/session/session_detail_page.dart';

import '../integration/support/integration_test_lifecycle.dart';
import '../integration/support/prototype_widget_test_harness.dart';
import '../integration/support/pump_prototype_page.dart';

void main() {
  setUpAll(() async {
    Levit.enableAutoLinking();
    await initializeDateFormatting('fr_FR');
  });

  testWidgets('login home calendar classes evaluations navigate', (tester) async {
    final guest = PrototypeWidgetTestHarness()..bootstrap(authenticated: false);
    await pumpPrototypeApp(
      tester,
      guest,
      formFactor: DesignReviewFormFactor.phone,
    );
    guest.router.go('/login');
    await tester.pump();
    await pumpUntilFound(tester, find.byType(LoginPage));
    await resetIntegrationTestSurface(tester);

    final auth = PrototypeWidgetTestHarness()..bootstrap(authenticated: true);
    await pumpPrototypeApp(
      tester,
      auth,
      formFactor: DesignReviewFormFactor.phone,
    );
    for (final entry in [
      ('/home', HomePage),
      ('/calendar', CalendarPage),
      ('/classes', ClassesPage),
      ('/evaluations', EvaluationsPage),
      ('/inbox', InboxPage),
    ]) {
      auth.router.go(entry.$1);
      await tester.pump();
      await pumpUntilFound(tester, find.byType(entry.$2));
    }

    final sessionId = auth.store.sessions.first.id;
    auth.router.go('/session/$sessionId');
    await tester.pump();
    await pumpUntilFound(tester, find.byType(SessionDetailPage));
  });

  testWidgets('wide viewport shows NavigationRail', (tester) async {
    final auth = PrototypeWidgetTestHarness()..bootstrap(authenticated: true);
    await pumpPrototypeApp(
      tester,
      auth,
      formFactor: DesignReviewFormFactor.tablet,
    );
    auth.router.go('/home');
    await tester.pump();
    await pumpUntilFound(tester, find.byType(HomePage));
    expect(find.byType(NavigationRail), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
  });

  testWidgets('account clears primary tab selection', (tester) async {
    final auth = PrototypeWidgetTestHarness()..bootstrap(authenticated: true);
    await pumpPrototypeApp(
      tester,
      auth,
      formFactor: DesignReviewFormFactor.phone,
    );
    auth.router.go('/account');
    await tester.pumpAndSettle();

    final bar = tester.widget<NavigationBar>(find.byType(NavigationBar));
    expect(bar.selectedIndex, 0);
    final destinations = bar.destinations.cast<NavigationDestination>();
    expect(destinations.length, 5);
    for (final d in destinations) {
      expect((d.selectedIcon as Icon).icon, (d.icon as Icon).icon);
    }
  });
}
