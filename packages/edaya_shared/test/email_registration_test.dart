import 'dart:convert';

import 'package:edaya_auth/edaya_auth.dart';
import 'package:edaya_shared/src/features/auth/login_controller.dart';
import 'package:edaya_shared/src/features/auth/passwordless_login_form.dart';
import 'package:edaya_shared/src/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'terms_acceptance_test.dart' show FixtureSession;

void main() {
  for (final locale in ['en', 'fr']) {
    for (final eligible in [true, false]) {
      testWidgets(
        'verified email registration in $locale, eligible=$eligible',
        (tester) async {
          tester.view.physicalSize = const Size(390, 844);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          var completions = 0;
          final auth = AuthClient(
            baseUrl: 'http://localhost:9999',
            client: MockClient((request) async {
              final path = request.url.path;
              final Object body;
              if (path.endsWith('/terms')) {
                body = {'enforced': false, 'document': null};
              } else if (path.endsWith('/methods')) {
                body = {'methods': []};
              } else if (path.endsWith('/otp/verify')) {
                body = {
                  'state': 'registration_required',
                  'challenge': 'fixture',
                  'proof': 'transient-fixture',
                  'expiresAt': DateTime.now().millisecondsSinceEpoch + 300000,
                  'eligible': eligible,
                };
              } else if (path.endsWith('/registration/complete')) {
                completions++;
                expect(jsonDecode(request.body), {
                  'challenge': 'fixture',
                  'proof': 'transient-fixture',
                });
                body = {'state': 'totp_required', 'challenge': 'factor'};
              } else {
                return http.Response('{}', 404);
              }
              return http.Response(jsonEncode(body), 200);
            }),
          );
          final controller = LoginController(
            authClient: auth,
            session: FixtureSession(),
            defaultEmail: 'fixture@example.test',
            onSignInSuccess: () async {},
          );
          controller.onInit();
          await controller.loadTerms(locale: locale);
          auth.pendingChallenge = 'fixture';
          controller.otp('123456');
          await controller.verifyOtp();
          await tester.pumpWidget(
            MaterialApp(
              locale: Locale(locale),
              theme: ThemeData(
                brightness: eligible ? Brightness.light : Brightness.dark,
              ),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: const TextScaler.linear(2)),
                child: child!,
              ),
              home: Scaffold(
                body: SingleChildScrollView(
                  child: PasswordlessLoginForm(controller: controller),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(controller.mode.value, LoginMode.register);
          expect(completions, 0);
          expect(find.byKey(const Key('auth-code')), findsNothing);
          final submit = find.byKey(const Key('auth-submit'));
          final other = find.text(
            locale == 'en'
                ? 'Use another email'
                : 'Utiliser une autre adresse e-mail',
          );
          expect(other, findsOneWidget);
          final action = eligible ? submit : other;
          if (!eligible) expect(submit, findsNothing);
          await tester.ensureVisible(action);
          await tester.tap(action);
          await tester.pumpAndSettle();
          expect(completions, eligible ? 1 : 0);
          expect(
            controller.mode.value,
            eligible ? LoginMode.verifyTotp : LoginMode.enterEmail,
          );
          expect(auth.registration, isNull);
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox.shrink());
          controller.onClose();
        },
      );
    }
  }
}
