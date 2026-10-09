@Tags(['integration'])
library;

import 'package:edaya_auth/edaya_auth.dart';
import 'package:edaya_guardian/features/home/home_page.dart';
import 'package:edaya_guardian/features/waiting/waiting_for_students_page.dart';
import 'package:edaya_integration_tests/edaya_integration_tests.dart';
import 'package:edaya_shared/edaya_shared.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:levit_flutter/levit_flutter.dart';
import 'support/guardian_widget_test_harness.dart';
import 'support/integration_test_lifecycle.dart';
import 'support/live_api_test_binding.dart';
import '../../../../packages/edaya_shared/test/support/enter_focused_text.dart';
import 'support/pump_guardian_page.dart';
import 'support/pump_until_found.dart';

Future<void> revealAndCopy(WidgetTester tester, String expected) async {
  final reveal = find.byKey(const Key('auth-test-reveal'));
  final deadline = DateTime.now().add(const Duration(seconds: 15));
  while (!tester.any(reveal) && DateTime.now().isBefore(deadline)) {
    await tester.pump(const Duration(milliseconds: 100));
  }
  expect(tester.any(reveal), isTrue);
  await tester.ensureVisible(reveal);
  await tester.tap(reveal);
  final displayed = find.byKey(const Key('auth-test-code'));
  while (!tester.any(displayed) && DateTime.now().isBefore(deadline)) {
    await tester.pump(const Duration(milliseconds: 100));
  }
  expect(tester.any(displayed), isTrue);
  expect(tester.widget<Text>(displayed).data == expected, isTrue);
  final input = tester.widget<TextFormField>(
    find.byKey(const Key('auth-code')),
  );
  expect(input.controller!.text.isEmpty, isTrue);
  String? copied;
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
    SystemChannels.platform,
    (call) async {
      if (call.method == 'Clipboard.setData') {
        copied = (call.arguments as Map)['text'] as String;
      }
      return null;
    },
  );
  try {
    await tester.tap(find.byKey(const Key('auth-test-copy')));
    await tester.pump();
    expect(copied == expected, isTrue);
  } finally {
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      null,
    );
  }
}

Future<void> main() async {
  LiveApiWidgetTestBinding();
  Levit.enableAutoLinking();
  final skip = await resolveIntegrationSkipReason();
  if (skip != null) {
    testWidgets('guardian auth disabled', (_) async {}, skip: true);
    return;
  }
  for (final channel in ['email', 'whatsapp', 'sms-switch']) {
    testWidgets(
      '[guardian.auth.$channel] signs in through the real branded form and captured transport',
      (tester) async {
        final harness = await GuardianWidgetTestHarness.createGuest();
        addTearDown(() async {
          await resetIntegrationTestSurface(tester);
          await resetIntegrationTestViewport(tester);
        });
        await pumpGuardianLoginShell(tester, harness);
        expect(find.byKey(const Key('auth-channel')), findsNothing);
        await tester.enterText(
          find.byKey(const Key('auth-identifier')),
          '0712345678',
        );
        await tester.tap(find.byKey(const Key('auth-submit')));
        await tester.pump();
        expect(find.byKey(const Key('auth-code')), findsNothing);
        final invalidController = tester
            .element(find.byKey(const Key('auth-identifier')))
            .levit
            .find<LoginController>();
        expect(invalidController.errorMessage.value, isNotEmpty);
        expect(find.text(invalidController.errorMessage.value), findsOneWidget);
        final destination = channel == 'email'
            ? GuardianPortalProfile.mariamKone.email
            : '+22507${DateTime.now().microsecondsSinceEpoch.toString().substring(8)}';
        if (channel != 'email') {
          final controller = tester
              .element(find.byKey(const Key('auth-identifier')))
              .levit
              .find<LoginController>();
          final deadline = DateTime.now().add(const Duration(seconds: 15));
          while (!controller.delivery.phoneAvailable.value &&
              DateTime.now().isBefore(deadline)) {
            await tester.pump(const Duration(milliseconds: 100));
          }
          expect(controller.delivery.phoneAvailable.value, isTrue);
          expect(find.byKey(const Key('auth-channel')), findsNothing);
        }
        await tester.enterText(
          find.byKey(const Key('auth-identifier')),
          channel == 'email'
              ? ' ${destination.toUpperCase()} '
              : '${destination.substring(0, 4)} (${destination.substring(4, 6)}) ${destination.substring(6)}',
        );
        var since = DateTime.now();
        await tester.ensureVisible(find.byKey(const Key('auth-submit')));
        await tester.tap(find.byKey(const Key('auth-submit')));
        await pumpUntilFound(tester, find.byKey(const Key('auth-code')));
        var code = await capturedOtp(
          destination,
          channel == 'email' ? 'email' : 'whatsapp',
          since,
        );
        await revealAndCopy(tester, code);
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
          try {
            await setIntegrationClockOffset(const Duration(seconds: 61));
            final deadline = DateTime.now().add(const Duration(seconds: 15));
            while (!controller.delivery.canResend &&
                DateTime.now().isBefore(deadline)) {
              await tester.pump(const Duration(milliseconds: 100));
            }
            expect(controller.delivery.canResend, isTrue);
            await tester.ensureVisible(find.byKey(const Key('auth-resend')));
            await tester.tap(find.byKey(const Key('auth-resend')));
            code = await capturedOtp(destination, channel, since);
          } finally {
            await setIntegrationClockOffset(Duration.zero);
          }
        }
        if (channel == 'sms-switch') {
          final controller = tester
              .element(find.byKey(const Key('auth-code')))
              .levit
              .find<LoginController>();
          expect(controller.delivery.canSms, isFalse);
          final oldChallenge = harness.scope
              .find<AuthClient>()
              .pendingChallenge;
          await enterFocusedText(
            tester,
            find.byKey(const Key('auth-code')),
            code,
          );
          try {
            await setIntegrationClockOffset(const Duration(seconds: 61));
            final deadline = DateTime.now().add(const Duration(seconds: 15));
            while (!controller.delivery.canSms &&
                DateTime.now().isBefore(deadline)) {
              await tester.pump(const Duration(milliseconds: 100));
            }
            expect(controller.delivery.canSms, isTrue);
            since = DateTime.now();
            await tester.ensureVisible(find.byKey(const Key('auth-sms')));
            await tester.tap(find.byKey(const Key('auth-sms')));
            code = await capturedOtp(destination, 'sms', since);
            while (controller.isBusy.value) {
              await tester.pump(const Duration(milliseconds: 100));
            }
            expect(
              harness.scope.find<AuthClient>().pendingChallenge,
              isNot(oldChallenge),
            );
            expect(controller.otpText.text, isEmpty);
            expect(controller.delivery.testCode.value.isEmpty, isTrue);
            expect(controller.delivery.status.value!.channel, 'sms');
            expect(controller.delivery.status.value!.canSms, isFalse);
          } finally {
            await setIntegrationClockOffset(Duration.zero);
          }
        }
        await tester.enterText(find.byKey(const Key('auth-code')), '');
        await revealAndCopy(tester, code);
        await enterFocusedText(
          tester,
          find.byKey(const Key('auth-code')),
          code,
        );
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
