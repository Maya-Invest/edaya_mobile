import 'package:edaya_shared/src/features/settings/app_settings_models.dart'
    show ThemePreference;
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
  testWidgets('[guardian-v2.settings.persist] saves the theme from settings', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await AppSettingsController.preload();
    final h = PrototypeWidgetTestHarness()..bootstrap(authenticated: true);
    await pumpPrototypeRoute(tester, h, location: '/settings');
    await tester.tap(find.text('Ouvrir les paramètres complets'));
    await tester.pumpAndSettle();
    final dark = find.byWidgetPredicate(
      (widget) =>
          widget is RadioListTile<ThemePreference> &&
          widget.value == ThemePreference.dark,
    );
    await tester.tap(dark);
    await tester.pumpAndSettle();
    expect((await AppSettingsStorage.load()).theme, ThemePreference.dark);
    Navigator.of(tester.element(dark)).pop();
    await tester.pumpAndSettle();
    expect(dark, findsNothing);
    await tester.tap(find.text('Ouvrir les paramètres complets'));
    await tester.pumpAndSettle();
    expect(dark, findsOneWidget);
    expect(
      h.scope.find<AppSettingsController>().theme.value,
      ThemePreference.dark,
    );
  });
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
              expect(
                find.text(
                  lookupAppLocalizations(Locale(locale)).academicSubjects,
                ),
                findsOneWidget,
              );
              expect(find.text('Anglais').hitTestable(), findsNothing);
              await tester.tap(
                find.text(
                  lookupAppLocalizations(Locale(locale)).academicSubjects,
                ),
              );
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
  testWidgets('fee amounts and status fit a narrow phone at double text size', (
    tester,
  ) async {
    final h = PrototypeWidgetTestHarness()
      ..bootstrap(authenticated: true)
      ..textScale = 2;
    await configureDesignReviewViewport(tester, DesignReviewFormFactor.phone);
    const size = Size(320, 844);
    tester.view.physicalSize = size;
    await tester.binding.setSurfaceSize(size);
    h.viewportSize = size;
    await tester.pumpWidget(h.designReviewRoot(child: h.buildApp()));
    h.router.go('/fees');
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await resetIntegrationTestSurface(tester);
    await resetIntegrationTestViewport(tester);
  });
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
      final label = find
          .descendant(of: find.byType(HomePage), matching: find.text(d.fr))
          .first;
      await tester.ensureVisible(label);
      await tester.tap(label);
      await tester.pumpAndSettle();
      expect(h.router.state.uri.path, d.path, reason: d.fr);
      expect(tester.takeException(), isNull, reason: d.path);
      expect(find.byType(BackButton), findsOneWidget);
      h.router.go('/home');
      await tester.pumpAndSettle();
    }
    await tester.scrollUntilVisible(
      find.byType(ChildContextCard),
      -350,
      scrollable: find.byType(Scrollable).first,
    );
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
