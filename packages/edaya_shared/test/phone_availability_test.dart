import 'dart:convert';
import 'package:edaya_auth/edaya_auth.dart';
import 'package:edaya_shared/src/features/auth/account_security_page.dart';
import 'package:edaya_shared/src/features/auth/app_session_controller.dart';
import 'package:edaya_shared/src/features/auth/login_controller.dart';
import 'package:edaya_shared/src/features/auth/passwordless_login_form.dart';
import 'package:edaya_shared/src/l10n/app_localizations.dart';
import 'package:edaya_shared/src/l10n/l10n_lookup.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

class FixtureSession implements AppSessionController {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  for (final role in ['guardian', 'teacher']) {
    for (final failure in [false, true]) {
      testWidgets(
        '$role email-only form rejects pasted phone after ${failure ? 'failed' : 'disabled'} discovery and supports re-enablement',
        (tester) async {
          var available = false;
          var requests = 0;
          var unavailable = failure;
          final auth = AuthClient(
            baseUrl: 'http://localhost:9999',
            client: MockClient((request) async {
              if (request.url.path.endsWith('/terms'))
                return http.Response('{"enforced":false,"document":null}', 200);
              if (request.url.path.endsWith('/methods')) {
                if (unavailable) throw StateError('unreachable');
                return http.Response(
                  jsonEncode({
                    'methods': [
                      {'kind': 'phone', 'available': available},
                    ],
                  }),
                  200,
                );
              }
              requests++;
              return http.Response('{"code":"fixture"}', 400);
            }),
          );
          final controller = LoginController(
            authClient: auth,
            session: FixtureSession(),
            defaultEmail: '',
            onSignInSuccess: () async {},
          );
          controller.onInit();
          await controller.delivery.loadMethods();
          await tester.pumpWidget(
            MaterialApp(
              locale: const Locale('en'),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: Scaffold(
                body: SingleChildScrollView(
                  child: PasswordlessLoginForm(
                    controller: controller,
                    subtitle: role,
                  ),
                ),
              ),
            ),
          );
          expect(find.text('Email'), findsOneWidget);
          await tester.enterText(
            find.byKey(const Key('auth-identifier')),
            '+2250712345678',
          );
          await tester.pump();
          expect(find.textContaining('Include +225'), findsNothing);
          await controller.sendCode();
          expect(controller.errorMessage.value, systemL10n().phoneUnavailable);
          expect(requests, 0);
          controller.email('person@example.com');
          await controller.sendCode();
          expect(requests, 1);
          unavailable = false;
          available = true;
          await controller.delivery.loadMethods();
          controller.email('+2250712345678');
          await tester.pump();
          expect(find.text('Email or phone number'), findsOneWidget);
          await controller.sendCode();
          expect(requests, 2);
          await tester.pumpWidget(const SizedBox.shrink());
          controller.onClose();
        },
      );
    }
  }
  test(
    'email-only account linking rejects phone locally and accepts email',
    () async {
      var writes = 0;
      final auth = AuthClient(
        baseUrl: 'http://localhost:9999',
        client: MockClient((request) async {
          writes++;
          return http.Response('{"code":"fixture"}', 400);
        }),
      );
      final controller = AccountSecurityController(auth, FixtureSession());
      controller.onInit();
      await controller.load();
      writes = 0;
      controller.value('+2250712345678');
      await controller.link();
      expect(controller.error.value, systemL10n().phoneUnavailable);
      expect(writes, 0);
      controller.value('person@example.com');
      await controller.link();
      expect(writes, 1);
      controller.delivery.phoneAvailable(true);
      controller.channel('phone');
      controller.value('+2250712345678');
      await controller.link();
      expect(writes, 2);
      controller.onClose();
    },
  );
}
