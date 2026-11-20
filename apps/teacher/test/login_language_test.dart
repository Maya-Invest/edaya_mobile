import 'package:edaya_shared/edaya_shared.dart';
import 'package:edaya_teacher_v2/app/prototype_app_root.dart';
import 'package:edaya_teacher_v2/mock/mock_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('login language follows the selection and survives a restart', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await AppSettingsController.preload();
    Future<void> openLogin() async {
      await tester.pumpWidget(PrototypeAppRoot(store: MockStore()));
      await tester.pumpAndSettle();
    }

    await openLogin();
    const email = 'teacher@example.test';
    await tester.enterText(find.byType(TextField), email);
    final picker = find.byKey(const ValueKey('login-language'));
    await tester.tap(picker);
    await tester.pumpAndSettle();
    expect(find.text('English'), findsOneWidget);
    await tester.tap(find.text('Français'));
    await tester.pumpAndSettle();
    expect(find.text('FR'), findsOneWidget);
    expect(find.text('Connexion'), findsOneWidget);
    expect(find.text(email), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    await AppSettingsController.preload();
    await openLogin();
    expect(find.text('FR'), findsOneWidget);
    await tester.tap(picker);
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('login-language-fr')),
        matching: find.byIcon(Icons.check),
      ),
      findsOneWidget,
    );
    await tester.tap(find.text('English'));
    await tester.pumpAndSettle();
    expect(find.text('Sign in'), findsOneWidget);
  });
}
