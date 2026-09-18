import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:edaya_guardian/design/components/parent_account_card.dart';
import 'package:edaya_guardian/design/components/student_context_card.dart';
import 'package:edaya_guardian/features/account/account_page.dart';
import 'package:edaya_guardian/features/calendar/calendar_page.dart';
import 'package:edaya_guardian/features/home/home_page.dart';
import 'package:edaya_guardian/features/scolarite/progress_page.dart';
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
    ApiBaseUrlConfig.configure(appDefaultUrl: 'http://localhost:9999');
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
    await pumpUntilFound(tester, find.text('Envoyer le code'));
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

  testWidgets('account pushes a full page on compact', (tester) async {
    final auth = PrototypeWidgetTestHarness()..bootstrap(authenticated: true);
    await pumpPrototypeApp(
      tester,
      auth,
      formFactor: DesignReviewFormFactor.phone,
    );
    auth.router.go('/home');
    await tester.pumpAndSettle();
    auth.router.go('/account');
    await tester.pumpAndSettle();

    expect(find.byType(AccountPage), findsOneWidget);
    expect(find.byTooltip('Retour'), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
    expect(
      tester
          .widget<NavigationBar>(
            find.byType(NavigationBar, skipOffstage: false),
          )
          .selectedIndex,
      0,
    );
  });

  testWidgets('header is wordmark plus child and parent cards', (tester) async {
    final auth = PrototypeWidgetTestHarness()..bootstrap(authenticated: true);
    await pumpPrototypeApp(
      tester,
      auth,
      formFactor: DesignReviewFormFactor.phone,
    );
    auth.router.go('/home');
    await tester.pumpAndSettle();

    expect(find.text('edaya'), findsOneWidget);
    expect(find.byTooltip('Aide'), findsNothing);
    expect(find.byIcon(Icons.help_outline), findsNothing);
    expect(find.byType(StudentContextCard), findsOneWidget);
    expect(find.byType(ParentAccountCard), findsOneWidget);
    expect(find.byTooltip('Mon compte'), findsOneWidget);
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

    expect(find.text('edaya'), findsOneWidget);
    expect(find.byType(NavigationRail), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
    expect(find.byTooltip('Aide'), findsNothing);
  });

  testWidgets('scolarite progress pushes a full page on compact', (
    tester,
  ) async {
    final auth = PrototypeWidgetTestHarness()..bootstrap(authenticated: true);
    await pumpPrototypeApp(
      tester,
      auth,
      formFactor: DesignReviewFormFactor.phone,
    );
    auth.router.go('/scolarite/notes');
    await tester.pumpAndSettle();
    auth.router.go('/scolarite/progress');
    await tester.pumpAndSettle();

    expect(find.byType(ProgressOverviewPage), findsOneWidget);
    expect(find.byTooltip('Retour'), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
    expect(find.byType(StudentContextCard), findsNothing);
    expect(
      tester
          .widget<NavigationBar>(
            find.byType(NavigationBar, skipOffstage: false),
          )
          .selectedIndex,
      2,
    );
  });
}
