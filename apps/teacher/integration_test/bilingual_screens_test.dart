import 'dart:io' show Platform;
import 'package:flutter/services.dart';
import 'package:edaya_teacher_v2/main.dart' as app;
import 'package:edaya_shared/edaya_shared.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('teacher screens follow the selected language', (tester) async {
    final store = await DemoStore.start(DemoRole.teacher);
    await store.close();
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
    final channel = PushNotificationConfigs.teacher;
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
        '/home': tr.teachingProgressTab,
        '/evaluations/create': tr.createAssessment,
        '/evaluations/avis': tr.teacherTaskFamilyFeedback,
        '/evaluations/avis/demo-feedback': tr.feedbackClarity,
        '/session/demo-math-a-lesson-1': tr.rollAttendance,
        '/incidents/new': tr.searchForAStudent,
        '/account/settings': tr.settingsTitle,
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
        if (screen.key == '/evaluations/create') {
          Finder field(String label) => find.byWidgetPredicate(
            (widget) =>
                widget is TextField && widget.decoration?.labelText == label,
          );
          final title = field(tr.titleLabel);
          final maximum = field(tr.maximumScore);
          await tester.ensureVisible(title);
          await tester.enterText(title, 'QA ${language.name}');
          await tester.ensureVisible(maximum);
          await tester.enterText(
            maximum,
            language == LanguagePreference.fr ? '12,5' : '12.5',
          );
          FocusManager.instance.primaryFocus?.unfocus();
          await tester.pumpAndSettle();
          final create = find.widgetWithText(FilledButton, tr.create);
          if (create.evaluate().isEmpty) {
            final list = find.descendant(
              of: find.byType(BottomSheet),
              matching: find.byType(ListView),
            );
            await waitFor(
              () => list.evaluate().isNotEmpty,
              'Open assessment form at ${router.routeInformationProvider.value.uri}',
            );
            for (
              var attempt = 0;
              attempt < 8 && create.evaluate().isEmpty;
              attempt++
            ) {
              await tester.drag(list.last, const Offset(0, -180));
              await tester.pumpAndSettle();
            }
          }
          await waitFor(
            () => create.evaluate().isNotEmpty,
            'Find Create on ${router.routeInformationProvider.value.uri}',
          );
          await tester.ensureVisible(create);
          await tester.tap(create);
          await waitFor(
            () =>
                router
                    .routeInformationProvider
                    .value
                    .uri
                    .queryParameters['assessment'] !=
                null,
            'Save ${language.name} decimal maximum',
          );
          final id = router
              .routeInformationProvider
              .value
              .uri
              .queryParameters['assessment']!;
          final client = EdayaRootScope.find<SchoolClientFactory>()();
          final saved = await client.getEntityByPublicName('assessments', id);
          expect(saved['maxScore'], 12.5);
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
