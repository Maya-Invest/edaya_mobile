import 'package:edaya_teacher_v2/main.dart' as app;
import 'package:edaya_teacher_v2/features/context/teacher_context_controller.dart';
import 'package:edaya_shared/edaya_shared.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:integration_test/integration_test.dart';

Future<void> waitFor(WidgetTester tester, bool Function() ready) async {
  for (var attempt = 0; attempt < 150; attempt++) {
    await tester.pump(const Duration(milliseconds: 100));
    if (ready()) return;
  }
  fail('Timed out waiting for the demo workspace');
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('public offline teacher workspace opens, saves and exits', (
    tester,
  ) async {
    await (await DemoStore.resume(DemoRole.teacher))?.erase();
    await app.main();
    final button = find.byType(DemoButton);
    await waitFor(tester, () => button.evaluate().isNotEmpty);
    await tester.ensureVisible(button);
    await tester.tap(button);
    final banner = find.textContaining(RegExp(r'^(Demo|Démo) · '));
    await waitFor(tester, () => banner.evaluate().isNotEmpty);
    expect(
      EdayaRootScope.find<AppSessionController>().user.value?.name,
      'Aminata Traoré',
    );
    final workspace = EdayaRootScope.find<TeacherContextController>();
    await waitFor(
      tester,
      () =>
          workspace.taughtClassSubjectIds.value.contains('demo-math-a') &&
          workspace.assignedClassGroupIds.value.contains('demo-class-b'),
    );
    final client = EdayaRootScope.find<SchoolClientFactory>()();
    expect(client, isA<DemoSchoolClient>());
    final profile = await client.runCommand('update-teacher-self-profile', {
      'phone': '+2250102030405',
    });
    expect(profile['phone'], '+2250102030405');
    final firstId = (client as DemoSchoolClient).store.id;
    await tester.pumpWidget(const SizedBox.shrink());
    await client.store.close();
    await app.main();
    await waitFor(tester, () => banner.evaluate().isNotEmpty);
    final resumed =
        EdayaRootScope.find<SchoolClientFactory>()() as DemoSchoolClient;
    expect(resumed.store.id, firstId);
    expect(
      (await resumed.getEntityByPublicName(
        'teachers',
        'demo-teacher',
      ))['phone'],
      '+2250102030405',
    );
    final router = EdayaRootScope.find<GoRouter>();
    for (final route in [
      "/calendar",
      "/session/demo-math-a-lesson-1",
      "/classes/demo-class-b/attendance",
      "/classes/demo-class-b/discipline",
      "/evaluations",
      "/evaluations/avis",
      "/inbox",
      "/inbox/conversation/demo-thread",
      "/account",
    ]) {
      router.go(route);
      await tester.pumpAndSettle();
      expect(router.routeInformationProvider.value.uri.path, route);
      expect(tester.takeException(), isNull, reason: route);
      if (route == '/inbox/conversation/demo-thread') {
        final reply = find.byType(TextField).last;
        await waitFor(
          tester,
          () => find.byType(TextField).evaluate().isNotEmpty,
        );
        await tester.enterText(reply, 'Merci pour le suivi.');
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: 'Typing a reply');
        FocusManager.instance.primaryFocus?.unfocus();
        await tester.pumpAndSettle();
        final send = find.widgetWithText(
          FilledButton,
          tester.element(reply).tr.messagingSend,
        );
        await tester.ensureVisible(send);
        await tester.tap(send);
        await waitFor(
          tester,
          () => tester.widget<TextField>(reply).controller!.text.isEmpty,
        );
        expect(tester.takeException(), isNull, reason: 'Composing a reply');
        final detail = await resumed.runQuery('get-conversation', {
          'conversationId': 'demo-thread',
        });
        expect(
          (detail['messages'] as List).last['body'],
          'Merci pour le suivi.',
        );
      }
    }
    await tester.ensureVisible(button);
    await tester.tap(button);
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(FilledButton),
      ),
    );
    await waitFor(
      tester,
      () =>
          button.evaluate().isNotEmpty &&
          EdayaRootScope.find<AppSessionController>().user.value == null,
    );
    expect(await DemoStore.resume(DemoRole.teacher), isNull);
  });
}
