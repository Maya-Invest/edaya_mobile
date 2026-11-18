import 'dart:io' show Platform;
import 'package:flutter/services.dart';
import 'package:edaya_guardian_v2/features/fees/payment_detail_page.dart';
import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'package:edaya_guardian_v2/main.dart' as app;
import 'package:edaya_shared/edaya_shared.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('guardian screens follow the selected language', (tester) async {
    final store = await DemoStore.start(DemoRole.guardian);
    await store.close();
    // Add a refund to this test's isolated demo, alongside the normal receipt.
    final db = await openDatabase(
      '${await getDatabasesPath()}/edaya-demo-${store.id}.db',
    );
    try {
      final seed =
          jsonDecode((await db.query('school')).single['body'] as String)
              as Map;
      final payments = seed['payments'] as List;
      payments.add({
        ...Map<String, dynamic>.from(payments.first as Map),
        'id': 'test-refund',
        'kind': 'disbursement',
        'amount': 1000,
      });
      await db.update('school', {'body': jsonEncode(seed)}, where: 'id = 1');
    } finally {
      await db.close();
    }
    await app.main();
    Future<void> waitFor(bool Function() ready, String description) async {
      for (var i = 0; i < 120; i++) {
        await tester.pump(const Duration(milliseconds: 100));
        if (ready()) return;
      }
      fail(
        '$description. Visible text: ${tester.widgetList<Text>(find.byType(Text)).map((text) => text.data).whereType<String>().join(" | ")}',
      );
    }

    await waitFor(
      () => find.byType(DemoFrame).evaluate().isNotEmpty,
      'Open demo',
    );
    final settings = EdayaRootScope.find<AppSettingsController>();
    final router = EdayaRootScope.find<GoRouter>();
    final channel = PushNotificationConfigs.guardian;
    final notifications = FcmPushNotificationService(
      config: channel,
      schoolClientFactory: EdayaRootScope.find<SchoolClientFactory>(),
    );
    if (Platform.isAndroid) await notifications.initialize();
    for (final language in [LanguagePreference.en, LanguagePreference.fr]) {
      await settings.setLanguage(language);
      await tester.pumpAndSettle();
      final tr = lookupAppLocalizations(Locale(language.name));
      final screens = {
        '/calendar': tr.viewAllAttendance,
        '/attendance': tr.attendanceStatusPresent,
        '/fees': tr.summary,
        '/fees/payment/demo-amina-receipt': tr.downloadReceipt,
        '/fees/payment/test-refund': tr.paymentKindDisbursement,
        '/scolarite/progress': tr.indicativeAverageAcrossTheSubjectsTracked,
        '/child': tr.photo,
        '/inbox/avis/demo-amina-survey': tr.familyFeedbackCannotAssess,
        '/account': tr.settingsTitle,
        '/settings': tr.openAllSettings,
      };
      for (final screen in screens.entries) {
        router.go(screen.key);
        await tester.pumpAndSettle();
        await waitFor(
          () => find.text(screen.value).evaluate().isNotEmpty,
          '${language.name} ${screen.key} should show "${screen.value}"',
        );
        expect(
          tester.element(find.text(screen.value).first).tr.localeName,
          language.name,
        );
        if (screen.key.endsWith('/test-refund')) {
          final detail = find.byType(PaymentDetailPage);
          expect(
            find.descendant(
              of: detail,
              matching: find.text(tr.paymentKindDisbursement),
            ),
            findsWidgets,
          );
          expect(
            find.descendant(
              of: detail,
              matching: find.text(tr.downloadReceipt),
            ),
            findsWidgets,
          );
          expect(find.text(tr.paymentReceipt), findsNothing);
        }
        if (screen.key.endsWith('/demo-amina-survey')) {
          expect(
            find.text(
              language == LanguagePreference.fr
                  ? 'Les consignes des devoirs sont claires.'
                  : 'The homework instructions are clear.',
            ),
            findsOneWidget,
          );
          expect(
            find.text(
              language == LanguagePreference.fr
                  ? 'Évitez de nommer d’autres élèves.'
                  : 'Please avoid naming other students.',
            ),
            findsOneWidget,
          );
        }
        expect(tester.takeException(), isNull, reason: screen.key);
      }
      if (Platform.isAndroid) {
        const plugin = MethodChannel(
          'dexterous.com/flutter/local_notifications',
        );
        final channels = await plugin.invokeListMethod<dynamic>(
          'getNotificationChannels',
        );
        final stored = channels!.whereType<Map>().singleWhere(
          (row) => row['id'] == channel.androidChannelId,
        );
        expect(stored['description'], channel.androidChannelDescription);
      }
    }
    await notifications.dispose();
    final active =
        EdayaRootScope.find<SchoolClientFactory>()() as DemoSchoolClient;
    await tester.pumpWidget(const SizedBox.shrink());
    await active.store.erase();
  });
}
