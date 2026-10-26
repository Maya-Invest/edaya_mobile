import 'dart:convert';
import 'package:edaya_auth/edaya_auth.dart';
import 'package:edaya_shared/src/features/auth/app_session_controller.dart';
import 'package:edaya_shared/src/features/auth/login_controller.dart';
import 'package:edaya_shared/src/features/auth/passwordless_login_form.dart';
import 'package:edaya_shared/src/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

class FixtureSession implements AppSessionController {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Map<String, dynamic> document(String version, String locale) => {
  'enforced': true,
  'document': {
    'version': version,
    'locale': locale,
    'documentHash': '$version-$locale-hash',
    'status': 'published',
    'title': 'Fixture terms',
    'sections': [
      {
        'heading': 'School use',
        'paragraphs': [
          'Read this text before accepting.',
          for (var i = 0; i < 12; i++)
            'Section $i: Keep account information accurate and use the school service responsibly.',
        ],
      },
    ],
  },
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  for (final role in ['guardian', 'teacher']) {
    for (final locale in ['en', 'fr']) {
      testWidgets(
        '$role $locale terms dialog accepts explicitly and gates OTP at 200% text',
        (tester) async {
          tester.view.physicalSize = const Size(390, 844);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final writes = <Map<String, dynamic>>[];
          final auth = AuthClient(
            baseUrl: 'http://localhost:9999',
            client: MockClient((request) async {
              if (request.url.path.endsWith('/terms')) {
                return http.Response(
                  jsonEncode(
                    document('v1', request.url.queryParameters['locale']!),
                  ),
                  200,
                );
              }
              if (request.url.path.endsWith('/methods')) {
                return http.Response('{"methods":[]}', 200);
              }
              writes.add(jsonDecode(request.body) as Map<String, dynamic>);
              return http.Response('{"code":"fixture"}', 400);
            }),
          );
          final controller = LoginController(
            authClient: auth,
            session: FixtureSession(),
            defaultEmail: 'person@example.com',
            onSignInSuccess: () async {},
          );
          controller.onInit();
          await controller.loadTerms(locale: locale);
          await tester.pumpWidget(
            MaterialApp(
              locale: Locale(locale),
              theme: ThemeData(brightness: Brightness.dark),
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
                  child: PasswordlessLoginForm(
                    controller: controller,
                    subtitle: role,
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(controller.termsAccepted.value, isFalse);
          expect(
            tester
                .widget<FilledButton>(find.byKey(const Key('auth-submit')))
                .onPressed,
            isNull,
          );
          await controller.sendCode();
          expect(writes, isEmpty);
          expect(find.text('Read this text before accepting.'), findsNothing);
          await tester.ensureVisible(find.byKey(const Key('auth-terms-read')));
          await tester.tap(find.byKey(const Key('auth-terms-read')));
          await tester.pumpAndSettle();
          expect(find.text('Read this text before accepting.'), findsOneWidget);
          expect(controller.termsAccepted.value, isFalse);
          await tester.tap(find.byKey(const Key('auth-terms-close')));
          await tester.pumpAndSettle();
          expect(find.byKey(const Key('auth-terms-dialog')), findsNothing);
          expect(controller.termsAccepted.value, isFalse);
          await tester.tap(find.byKey(const Key('auth-terms-read')));
          await tester.pumpAndSettle();
          final confirm = find.byKey(const Key('auth-terms-confirm'));
          expect(tester.getRect(confirm).bottom, lessThanOrEqualTo(844));
          await tester.tap(confirm);
          await tester.pumpAndSettle();
          expect(find.byKey(const Key('auth-terms-dialog')), findsNothing);
          expect(controller.termsAccepted.value, isTrue);
          expect(
            tester
                .widget<CheckboxListTile>(
                  find.byKey(const Key('auth-terms-accept')),
                )
                .value,
            isTrue,
          );
          expect(writes, isEmpty);
          await tester.tap(find.byKey(const Key('auth-terms-read')));
          await tester.pumpAndSettle();
          await tester.binding.handlePopRoute();
          await tester.pumpAndSettle();
          expect(controller.termsAccepted.value, isTrue);
          await controller.sendCode();
          expect(writes.single['termsAcceptance'], {
            'version': 'v1',
            'locale': locale,
            'accepted': true,
          });
          controller.setEmail('another@example.com');
          await tester.pump();
          expect(controller.termsAccepted.value, isFalse);
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox.shrink());
          controller.onClose();
        },
      );
    }
  }
  testWidgets(
    'loading failure retries, changed terms reload unchecked, and restarting clears acceptance',
    (tester) async {
      var unavailable = true;
      var version = 'v1';
      var rejectVersion = false;
      var writes = 0;
      final auth = AuthClient(
        baseUrl: 'http://localhost:9999',
        client: MockClient((request) async {
          if (request.url.path.endsWith('/methods')) {
            return http.Response('{"methods":[]}', 200);
          }
          if (request.url.path.endsWith('/terms')) {
            return unavailable
                ? http.Response('{}', 503)
                : http.Response(
                    jsonEncode(
                      document(version, request.url.queryParameters['locale']!),
                    ),
                    200,
                  );
          }
          writes++;
          if (rejectVersion) {
            version = 'v2';
            return http.Response('{"code":"terms_version_changed"}', 409);
          }
          return http.Response('{"code":"fixture"}', 400);
        }),
      );
      final controller = LoginController(
        authClient: auth,
        session: FixtureSession(),
        defaultEmail: 'person@example.com',
        onSignInSuccess: () async {},
      );
      controller.onInit();
      await controller.loadTerms(locale: 'en');
      expect(controller.termsLoadError.value, isTrue);
      await controller.sendCode();
      expect(writes, 0);
      unavailable = false;
      await controller.loadTerms(locale: 'en');
      controller.setTermsAccepted(true);
      expect(controller.termsReady, isTrue);
      rejectVersion = true;
      await controller.sendCode();
      expect(controller.terms.value?.document?.version, 'v2');
      expect(controller.termsAccepted.value, isFalse);
      controller.setTermsAccepted(true);
      controller.showEmailEntry();
      expect(controller.termsAccepted.value, isFalse);
      controller.setTermsAccepted(true);
      controller.email('direct-edit@example.com');
      expect(controller.termsReady, isFalse);
      controller.onClose();
    },
  );
  testWidgets(
    'an uncertain send can restart with another contact and fresh acceptance',
    (tester) async {
      final writes = <Map<String, dynamic>>[];
      final auth = AuthClient(
        baseUrl: 'http://localhost:9999',
        client: MockClient((request) async {
          if (request.url.path.endsWith('/terms')) {
            return http.Response(
              jsonEncode(
                document('v1', request.url.queryParameters['locale']!),
              ),
              200,
            );
          }
          if (request.url.path.endsWith('/methods')) {
            return http.Response('{"methods":[]}', 200);
          }
          writes.add(jsonDecode(request.body) as Map<String, dynamic>);
          return http.Response(
            '{"code":"unavailable","message":"unavailable"}',
            503,
          );
        }),
      );
      final controller = LoginController(
        authClient: auth,
        session: FixtureSession(),
        defaultEmail: 'first@example.com',
        onSignInSuccess: () async {},
      );
      controller.onInit();
      await controller.loadTerms(locale: 'en');
      controller.setTermsAccepted(true);
      await controller.sendCode();
      expect(controller.delivery.retryable.value, isTrue);
      controller.showEmailEntry();
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: SingleChildScrollView(
              child: PasswordlessLoginForm(controller: controller),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('auth-identifier')),
        'second@example.com',
      );
      await tester.ensureVisible(find.byKey(const Key('auth-terms-accept')));
      await tester.tap(find.byKey(const Key('auth-terms-accept')));
      await tester.pump();
      expect(controller.termsReady, isTrue);
      await controller.sendCode();
      expect(writes.last['value'], 'second@example.com');
      expect(writes.last['termsAcceptance'], {
        'version': 'v1',
        'locale': 'en',
        'accepted': true,
      });
      await tester.pumpWidget(const SizedBox.shrink());
      controller.onClose();
    },
  );
}
