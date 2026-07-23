import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:edaya_guardian/features/calendar/calendar_page.dart';
import 'package:edaya_guardian/features/home/home_page.dart';
import 'package:edaya_guardian/features/scolarite/results_page.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:levit_flutter/levit_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:edaya_shared/edaya_shared.dart';

import '../integration/support/integration_test_lifecycle.dart';
import '../integration/support/prototype_widget_test_harness.dart';
import '../integration/support/pump_prototype_page.dart';

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    ApiBaseUrlConfig.configure(
      appDefaultUrl: 'http://localhost:9999',
    );
    await ApiBaseUrlConfig.load();
    await AppSettingsController.preload();
    Levit.enableAutoLinking();
    await initializeDateFormatting('fr_FR');
  });

  testWidgets('login home calendar scolarite navigate', (tester) async {
    final guest = PrototypeWidgetTestHarness()..bootstrap(authenticated: false);
    await pumpPrototypeApp(
      tester,
      guest,
      formFactor: DesignReviewFormFactor.phone,
    );
    guest.router.go('/login');
    await tester.pump();
    await pumpUntilFound(tester, find.text('Se connecter'));
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
      ('/scolarite/notes', ResultsPage),
    ]) {
      auth.router.go(entry.$1);
      await tester.pump();
      await pumpUntilFound(tester, find.byType(entry.$2));
    }
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
    // Material requires an index; theme + identical icons keep none visually selected.
    expect(bar.selectedIndex, 0);
    final destinations = bar.destinations.cast<NavigationDestination>();
    expect(destinations.length, 5);
    for (final d in destinations) {
      expect((d.selectedIcon as Icon).icon, (d.icon as Icon).icon);
    }
  });

  testWidgets('medium width paints brand app bar on list hubs', (tester) async {
    final auth = PrototypeWidgetTestHarness()..bootstrap(authenticated: true);
    await pumpPrototypeApp(
      tester,
      auth,
      formFactor: DesignReviewFormFactor.phone,
    );
    // Force medium band (rail, no detail drawer): 600 ≤ width < 1000.
    const medium = Size(800, 1024);
    tester.view.devicePixelRatio = 1.0;
    await tester.binding.setSurfaceSize(medium);
    tester.view.physicalSize = medium;
    addTearDown(() async {
      await resetIntegrationTestViewport(tester);
    });
    auth.router.go('/fees');
    await tester.pumpAndSettle();

    expect(find.byType(NavigationRail), findsOneWidget);
    expect(find.text('edaya'), findsOneWidget);
  });
}
