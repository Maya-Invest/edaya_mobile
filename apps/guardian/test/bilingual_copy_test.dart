import 'package:edaya_guardian_v2/app/prototype_app_root.dart';
import 'package:edaya_guardian_v2/mock/mock_store.dart';
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
        '/home': tr.teacherTodaySessions,
        '/session/s1': tr.timetableSessionKindLesson,
        '/scolarite/notes': tr.academicSubjects,
        '/scolarite/subject/Anglais/cahier': tr.entries,
        '/fees/fee/f1': tr.feeStatusOverdue,
        '/fees/payment/p1': tr.paymentMethodBankTransfer,
        '/inbox/avis': tr.familyFeedbackEmpty,
        '/account/profile': tr.name,

        '/calendar': tr.workspaceHistory,
        '/session/missing': tr.sessionNotFound,
        '/fees': tr.summary,
        '/fees/payment/missing': tr.paymentNotFound,
        '/inbox/message/missing': tr.messageNotFound,
        '/scolarite/progress': tr.teachingProgressTab,
        '/account': tr.settingsTitle,
        '/settings': tr.openAllSettings,
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
