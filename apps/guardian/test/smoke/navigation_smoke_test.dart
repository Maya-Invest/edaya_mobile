import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:edaya_guardian_v2/app/workspace_shell.dart';
import 'package:edaya_guardian_v2/features/home/home_page.dart';
import 'package:edaya_guardian_v2/features/scolarite/subject_grades_page.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:levit_flutter/levit_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:edaya_shared/edaya_shared.dart';
import '../integration/support/integration_test_lifecycle.dart';
import '../integration/support/prototype_widget_test_harness.dart';
import '../integration/support/pump_prototype_page.dart';
import '../integration/support/design_review_capture.dart';
import '../integration/support/design_review_environment.dart';

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    ApiBaseUrlConfig.configure(appDefaultUrl: 'http://localhost:19998');
    await ApiBaseUrlConfig.load();
    await AppSettingsController.preload();
    Levit.enableAutoLinking();
    await initializeDateFormatting('fr_FR');
    await initializeDateFormatting('en');
    await loadDesignReviewFonts();
  });
  for (final locale in ['fr', 'en']) {
    for (final dark in [false, true]) {
      for (final size in [
        DesignReviewFormFactor.phone,
        DesignReviewFormFactor.tablet,
      ]) {
        for (final scale in [1.0, 2.0]) {
          testWidgets(
            'workspace $locale ${dark ? 'dark' : 'light'} ${size.name} $scale',
            (tester) async {
              final h = PrototypeWidgetTestHarness()
                ..bootstrap(authenticated: true);
              h.locale = Locale(locale);
              h.mode = dark ? ThemeMode.dark : ThemeMode.light;
              h.textScale = scale;
              addTearDown(() async {
                await resetIntegrationTestSurface(tester);
                await resetIntegrationTestViewport(tester);
              });
              await pumpPrototypeRoute(
                tester,
                h,
                location: '/home',
                formFactor: size,
              );
              await tester.pumpAndSettle();
              expect(find.byType(HomePage), findsOneWidget);
              expect(find.byType(ChildContextCard), findsOneWidget);
              expect(find.byType(NavigationBar), findsNothing);
              expect(find.byType(NavigationRail), findsNothing);
              expect(tester.takeException(), isNull);
              if (scale == 1 &&
                  locale == 'fr' &&
                  size == DesignReviewFormFactor.phone) {
                await captureDesignReviewShot(
                  tester,
                  File('/tmp/guardian-v2-home-${dark ? 'dark' : 'light'}.png'),
                  logicalSize: designReviewLogicalSize(size),
                );
              }
              h.router.push('/scolarite/notes');
              await tester.pumpAndSettle();
              expect(find.text('Enseignements'), findsOneWidget);
              expect(find.text('Anglais').hitTestable(), findsNothing);
              await tester.tap(find.text('Enseignements'));
              await tester.pumpAndSettle();
              final subject = find.text('Anglais');
              await tester.ensureVisible(subject);
              await tester.tap(subject);
              await tester.pumpAndSettle();
              expect(find.byType(SubjectGradesPage), findsOneWidget);
              expect(tester.takeException(), isNull);
              final marks = find.byType(ExpansionTile);
              if (marks.evaluate().isNotEmpty) {
                await tester.ensureVisible(marks.first);
                await tester.tap(marks.first);
                await tester.pumpAndSettle();
                expect(tester.takeException(), isNull);
              }
            },
          );
        }
      }
    }
  }
  testWidgets('all menu destinations and child picker stay reachable', (
    tester,
  ) async {
    final h = PrototypeWidgetTestHarness()..bootstrap(authenticated: true);
    addTearDown(() async {
      await resetIntegrationTestSurface(tester);
      await resetIntegrationTestViewport(tester);
    });
    await pumpPrototypeRoute(tester, h, location: '/home');
    for (final d in destinations) {
      h.router.go(d.path);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: d.path);
      expect(find.byType(BackButton), findsOneWidget);
    }
    h.router.go('/home');
    await tester.pumpAndSettle();
    await tester.tap(find.byType(ChildContextCard));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Fermer'), findsOneWidget);
    final second = h.store.students[1];
    await tester.tap(find.text(second.fullName));
    await tester.pumpAndSettle();
    expect(h.store.activeStudentId, second.id);
    expect(find.byTooltip('Fermer'), findsNothing);
  });
}
