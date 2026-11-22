import 'package:edaya_shared/src/features/settings/app_settings_models.dart'
    show ThemePreference;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:edaya_teacher_v2/app/workspace_navigation.dart';
import 'package:edaya_shared/edaya_shared.dart'
    show
        PersonAvatar,
        AppLocalizationsContext,
        AppSettingsStorage,
        AppSettingsController;
import 'package:edaya_teacher_v2/mock/mock_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:edaya_teacher_v2/features/home/home_page.dart';
import '../integration/support/integration_test_lifecycle.dart';
import '../integration/support/prototype_widget_test_harness.dart';
import '../integration/support/pump_prototype_page.dart';

void main() {
  testWidgets('[teacher-v2.settings.persist] saves the theme from settings', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await AppSettingsController.preload();
    final h = PrototypeWidgetTestHarness()..bootstrap(authenticated: true);
    await pumpPrototypeApp(tester, h);
    h.router.go('/settings');
    await tester.pumpAndSettle();

    final dark = find.byWidgetPredicate(
      (widget) =>
          widget is RadioListTile<ThemePreference> &&
          widget.value == ThemePreference.dark,
    );
    await tester.tap(dark);
    await tester.pumpAndSettle();
    expect((await AppSettingsStorage.load()).theme, ThemePreference.dark);

    expect(
      h.scope.find<AppSettingsController>().theme.value,
      ThemePreference.dark,
    );
  });
  testWidgets('[teacher-v2.classes.list] opens the saved roster link on Home', (
    tester,
  ) async {
    final h = PrototypeWidgetTestHarness()..bootstrap(authenticated: true);
    await pumpPrototypeApp(tester, h);
    h.router.go('/classes');
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('home-profile')), findsOneWidget);
    expect(find.text('Liste des élèves'), findsNothing);
    expect(h.router.state.uri.path, '/home');
  });
  testWidgets('Home passes a teacher portrait to the shared avatar', (
    tester,
  ) async {
    final harness = PrototypeWidgetTestHarness()
      ..store = _PortraitStore()
      ..store.signIn();
    await pumpPrototypeApp(tester, harness);
    final profile = find.byKey(const ValueKey('home-profile'));
    final avatar = tester.widget<PersonAvatar>(
      find.descendant(of: profile, matching: find.byType(PersonAvatar)),
    );
    expect(avatar.photoUrl, harness.store.teacher.photoUrl);
    expect(avatar.initials, harness.store.teacher.initials);
  });
  for (final formFactor in [
    DesignReviewFormFactor.phone,
    DesignReviewFormFactor.medium,
    DesignReviewFormFactor.tablet,
  ]) {
    testWidgets('Home destinations open a full page on ${formFactor.name}', (
      tester,
    ) async {
      final auth = PrototypeWidgetTestHarness()..bootstrap(authenticated: true);
      await pumpPrototypeApp(tester, auth, formFactor: formFactor);
      auth.router.go('/home');
      await tester.pumpAndSettle();
      expect(find.text('Mes espaces'), findsNothing);
      expect(find.byType(NavigationBar), findsNothing);
      expect(find.byType(NavigationRail), findsNothing);
      expect(find.text('Enseignement'), findsOneWidget);
      expect(find.text('Vie en classe'), findsOneWidget);
      expect(find.text('Liste des élèves'), findsNothing);
      final profile = find.descendant(
        of: find.byType(AppBar),
        matching: find.byKey(const ValueKey('home-profile')),
      );
      expect(tester.getSize(profile).height, greaterThanOrEqualTo(67.2));
      await tester.tap(profile);
      await tester.pumpAndSettle();
      expect(auth.router.state.uri.path, '/account');
      auth.router.pop();
      await tester.pumpAndSettle();
      for (final area in workspaces) {
        final tile = find.text(
          area.label(tester.element(find.byType(HomePage)).tr),
        );
        await tester.ensureVisible(tile);
        await tester.tap(tile);
        await tester.pumpAndSettle();
        expect(auth.router.state.uri.path, area.path);
        expect(find.byType(HomePage), findsNothing);
        auth.router.pop();
        await tester.pumpAndSettle();
        expect(find.text('Enseignement'), findsOneWidget);
      }
    });
  }
}

class _PortraitStore extends MockStore {
  @override
  MockTeacher get teacher => const MockTeacher(
    id: 'photo-teacher',
    firstName: 'Aminata',
    lastName: 'Traoré',
    email: 'teacher@example.test',
    photoUrl: '/core/files/teacher-portrait/content',
  );
}
