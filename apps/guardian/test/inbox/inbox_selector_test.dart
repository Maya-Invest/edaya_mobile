import 'package:edaya_guardian_v2/design/theme.dart';
import 'package:edaya_guardian_v2/features/inbox/inbox_page.dart';
import 'package:edaya_shared/edaya_shared.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:levit_flutter/levit_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

  test('PrototypeTheme selected segment uses EDAYA primary fill', () {
    final style = PrototypeTheme.light.segmentedButtonTheme.style!;
    expect(
      style.backgroundColor!.resolve({WidgetState.selected}),
      EdayaTokens.lightPrimary,
    );
    expect(
      style.foregroundColor!.resolve({WidgetState.selected}),
      EdayaTokens.lightPrimaryForeground,
    );
    expect(style.backgroundColor!.resolve({}), EdayaTokens.lightSecondary);
    expect(style.foregroundColor!.resolve({}), EdayaTokens.lightForeground);
  });

  testWidgets('messages and surveys use separate destinations', (tester) async {
    final auth = PrototypeWidgetTestHarness()..bootstrap(authenticated: true);
    await pumpPrototypeApp(
      tester,
      auth,
      formFactor: DesignReviewFormFactor.phone,
    );
    auth.router.go('/inbox');
    await tester.pumpAndSettle();
    expect(find.byType(InboxPage), findsOneWidget);
    expect(find.byType(SegmentedButton<bool>), findsNothing);
    auth.router.go('/inbox/avis');
    await tester.pumpAndSettle();
    expect(find.byType(InboxPage), findsOneWidget);
    expect(find.byType(SegmentedButton<bool>), findsNothing);
    await resetIntegrationTestSurface(tester);
    await resetIntegrationTestViewport(tester);
  });
}
