@Tags(['integration'])
library;

import 'package:edaya_auth/edaya_auth.dart';
import 'package:edaya_guardian/features/home/home_page.dart';
import 'package:edaya_guardian/features/waiting/waiting_for_students_page.dart';
import 'package:edaya_integration_tests/edaya_integration_tests.dart';
import 'package:edaya_shared/edaya_shared.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:levit_flutter/levit_flutter.dart';
import 'support/guardian_widget_test_harness.dart';
import 'support/integration_test_lifecycle.dart';
import 'support/live_api_test_binding.dart';
import 'support/pump_guardian_page.dart';
import 'support/pump_until_found.dart';

Future<void> main() async {
  LiveApiWidgetTestBinding();
  Levit.enableAutoLinking();
  final skip = await resolveIntegrationSkipReason();
  if (skip != null) {
    testWidgets('guardian auth disabled', (_) async {}, skip: true);
    return;
  }
  for (final channel in ['email', 'telegram', 'whatsapp']) {
    testWidgets(
      '[guardian.auth.$channel] signs in through the real branded form and captured transport',
      (tester) async {
        final harness = await GuardianWidgetTestHarness.createGuest();
        addTearDown(() async {
          await resetIntegrationTestSurface(tester);
          await resetIntegrationTestViewport(tester);
        });
        await pumpGuardianLoginShell(tester, harness);
        final destination = channel == 'email'
            ? GuardianPortalProfile.mariamKone.email
            : '+22507${DateTime.now().microsecondsSinceEpoch.toString().substring(8)}';
        if (channel != 'email') {
          await tester.tap(find.byKey(const Key('auth-channel')));
          await tester.pump(const Duration(milliseconds: 300));
          await tester.tap(
            find.text(channel == 'telegram' ? 'Telegram' : 'WhatsApp').last,
          );
          await tester.pump(const Duration(milliseconds: 300));
        }
        await tester.enterText(
          find.byKey(const Key('auth-identifier')),
          destination,
        );
        var since = DateTime.now();
        await tester.ensureVisible(find.byKey(const Key('auth-submit')));
        await tester.tap(find.byKey(const Key('auth-submit')));
        await pumpUntilFound(tester, find.byKey(const Key('auth-code')));
        var code = await capturedOtp(destination, channel, since);
        if (channel == 'email') {
          final invalid = code == '000000' ? '111111' : '000000';
          await tester.enterText(find.byKey(const Key('auth-code')), invalid);
          await tester.tap(find.byKey(const Key('auth-submit')));
          final controller = tester
              .element(find.byKey(const Key('auth-code')))
              .levit
              .find<LoginController>();
          final deadline = DateTime.now().add(const Duration(seconds: 15));
          while (controller.errorMessage.value.isEmpty &&
              DateTime.now().isBefore(deadline)) {
            await tester.pump(const Duration(milliseconds: 100));
          }
          expect(controller.errorMessage.value, isNotEmpty);
          expect(
            harness.scope.find<AppSessionController>().isAuthenticated,
            isFalse,
          );
          since = DateTime.now();
          await tester.ensureVisible(find.byKey(const Key('auth-resend')));
          await tester.tap(find.byKey(const Key('auth-resend')));
          code = await capturedOtp(destination, channel, since);
        }
        await tester.enterText(find.byKey(const Key('auth-code')), code);
        await tester.ensureVisible(find.byKey(const Key('auth-submit')));
        await tester.tap(find.byKey(const Key('auth-submit')));
        await pumpUntilFound(
          tester,
          find.byType(channel == 'email' ? HomePage : WaitingForStudentsPage),
        );
        expect(
          harness.scope.find<AppSessionController>().isAuthenticated,
          isTrue,
        );
        final restored = await harness.scope.find<AuthClient>().getSession();
        expect(
          restored.data,
          isNotNull,
          reason: 'The real identity session must persist after login',
        );
        if (channel != 'email') {
          expect(
            harness.scope.find<AppSessionController>().hasSchoolSession,
            isFalse,
          );
          expect(find.byType(HomePage), findsNothing);
        }
      },
    );
  }
}
