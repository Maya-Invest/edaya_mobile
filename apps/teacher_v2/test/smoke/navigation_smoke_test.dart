import 'package:edaya_teacher_v2/app/workspace_navigation.dart';
import 'package:edaya_shared/edaya_shared.dart' show PersonAvatar;
import 'package:edaya_teacher_v2/mock/mock_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:edaya_teacher_v2/features/home/home_page.dart';
import '../integration/support/integration_test_lifecycle.dart';
import '../integration/support/prototype_widget_test_harness.dart';
import '../integration/support/pump_prototype_page.dart';

void main() {
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
        final tile = find.text(area.label);
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
