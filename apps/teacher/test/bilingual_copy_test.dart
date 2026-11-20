import 'package:edaya_teacher_v2/app/prototype_app_root.dart';
import 'package:edaya_teacher_v2/mock/mock_store.dart';
import 'package:edaya_shared/edaya_shared.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:levit_flutter/levit_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('workspace screens update when the saved language changes', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await AppSettingsController.preload();
    await initializeDateFormatting();
    tester.platformDispatcher.localeTestValue = const Locale('es');
    addTearDown(tester.platformDispatcher.clearLocaleTestValue);
    await tester.pumpWidget(
      PrototypeAppRoot(store: MockStore(), authenticated: true),
    );
    await tester.pumpAndSettle();
    final context = tester.element(find.byType(Scaffold).first);
    expect(context.tr.localeName, 'en');
    final router = GoRouter.of(context);
    final settings = context.levit.find<AppSettingsController>();
    for (final language in [LanguagePreference.en, LanguagePreference.fr]) {
      await settings.setLanguage(language);
      await tester.pumpAndSettle();
      final tr = lookupAppLocalizations(Locale(language.name));
      final screens = {
        '/evaluations': tr.navEvaluations,
        '/progress': tr.chooseAClass,
        '/incidents': tr.reportAnIncident,
        '/inbox': tr.workspaceNotifications,
        '/inbox?tab=notifications': tr.inboxStatusRead,
        '/inbox/message/missing': tr.messageNotFound,
        '/account/profile': tr.lastNameLabel,

        '/home': tr.teachingProgressTab,
        '/evaluations/avis': tr.teacherTaskFamilyFeedback,
        '/account': tr.settingsTitle,
        '/report-cards': tr.navReportCards,
      };
      for (final screen in screens.entries) {
        router.go(screen.key);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: screen.key);
        expect(
          find.text(screen.value),
          findsWidgets,
          reason:
              '${screen.key} should show "${screen.value}" in ${language.name}',
        );
      }
    }
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
