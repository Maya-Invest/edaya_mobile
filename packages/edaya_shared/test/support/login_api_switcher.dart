import 'dart:async';
import 'dart:convert';

import 'package:edaya_auth/edaya_auth.dart';
import 'package:edaya_shared/edaya_shared.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:levit_flutter/levit_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _UnusedPushService extends Fake implements PushNotificationService {}

/// Exercises each branded live login with recorded requests to two API origins.
void testLoginApiSwitcher({
  required String app,
  required Widget login,
  required void Function(LevitScope) registerRuntime,
}) {
  testWidgets(
    '[$app.auth.api-switcher] login follows the build flag and active API',
    (tester) async {
      const previous = 'https://previous.example';
      const selected = 'https://selected.example';
      SharedPreferences.setMockInitialValues({'edaya_api_base_url': previous});
      FlutterSecureStorage.setMockInitialValues({});
      ApiBaseUrlConfig.configure(appDefaultUrl: ApiBaseUrlConfig.stagingUrl);
      await ApiBaseUrlConfig.load();
      Levit.enableAutoLinking();

      final requests = <Uri>[];
      final firstSend = Completer<void>();
      final auth = AuthClient(
        baseUrl: ApiBaseUrlConfig.baseUrl,
        baseUrlProvider: () => ApiBaseUrlConfig.authBaseUrl,
        client: MockClient((request) async {
          final url = request.url;
          requests.add(url);
          final Object body = switch (url.path) {
            '/auth/edaya/terms' => {
              'enforced': true,
              'document': {
                'version': 'v1',
                'locale': 'en',
                'documentHash': 'fixture-hash',
                'status': 'published',
                'title': 'School terms',
                'sections': [],
              },
            },
            '/auth/edaya/methods' => {'methods': []},
            '/auth/edaya/otp/start' => {'challenge': url.host},
            '/core/authorization/effective-grants' => {
              'kind': 'guardian',
              'actorId': 'actor',
              'schoolId': 'school',
              'assuranceLevel': 'standard',
              'grants': [],
            },
            _ => throw StateError('Unexpected request $url'),
          };
          if (url.path.endsWith('/otp/start') && url.origin == previous) {
            await firstSend.future;
          }
          return http.Response(jsonEncode(body), 200);
        }),
      );
      final invitation = PendingInvitationStore();
      if (app == 'guardian-v2') await invitation.save('previous-invitation');
      await tester.pumpWidget(
        LScope(
          dependencyFactory: (scope) {
            registerRuntime(scope);
            scope.put<AuthClient>(() => auth);
            scope.put<PendingInvitationStore>(() => invitation);
            scope.put<AppSettingsController>(() => AppSettingsController());
            scope.put<AppSessionController>(
              () => AppSessionController(
                authClient: auth,
                sessionStorage: AuthSessionStorage(),
                pushNotifications: _UnusedPushService(),
                routerRefresh: EdayaRouterRefresh(),
                validateGrants: (_) => null,
                unauthorizedProfileMessage: () => '',
              ),
            );
          },
          child: MaterialApp(
            locale: const Locale('en'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: login,
          ),
        ),
      );
      await tester.pumpAndSettle();
      final submit = find.byKey(const Key('auth-submit'));
      final accept = find.byKey(const Key('auth-terms-accept'));
      final picker = find.byType(DevApiUrlSettings);
      Future<void> tap(Finder finder) async {
        await tester.ensureVisible(finder);
        await tester.tap(finder);
        await tester.pump();
      }

      const fallback = String.fromEnvironment(
        'API_URL',
        defaultValue: ApiBaseUrlConfig.stagingUrl,
      );
      await tester.enterText(
        find.byKey(const Key('auth-identifier')),
        'person@example.com',
      );
      await tap(accept);
      if (const bool.fromEnvironment('PRODUCTION')) {
        expect(picker, findsNothing);
        expect(ApiBaseUrlConfig.hasOverride, isFalse);
        expect(await ApiBaseUrlConfig.saveOverride(selected), isFalse);
        expect(await ApiBaseUrlConfig.clearOverride(), isFalse);
        await tap(submit);
        await tester.pumpAndSettle();
        expect(auth.pendingChallenge, Uri.parse(fallback).host);
        await createEdayaSchoolClient(auth).effectiveGrants();
        expect(requests.map((url) => url.origin).toSet(), {fallback});
      } else {
        expect(auth.baseUrl, previous);
        await tap(find.text('Developer settings'));
        await tester.pumpAndSettle();
        await tap(submit);
        expect(tester.widget<DevApiUrlSettings>(picker).enabled, isFalse);
        firstSend.complete();
        await tester.pumpAndSettle();
        expect(auth.pendingChallenge, Uri.parse(previous).host);

        final urlField = find.descendant(
          of: picker,
          matching: find.byType(TextFormField),
        );
        await tester.enterText(urlField, selected);
        await tap(find.text('Save'));
        await tester.pumpAndSettle();
        expect(auth.pendingChallenge, isNull);
        expect(invitation.token, isNull);
        expect(find.byKey(const Key('auth-identifier')), findsOneWidget);
        expect(requests, contains(Uri.parse('$selected/auth/edaya/methods')));
        expect(
          requests.any(
            (url) => url.origin == selected && url.path.endsWith('/terms'),
          ),
          isTrue,
        );
        await ApiBaseUrlConfig.load();
        expect(auth.baseUrl, selected);
        expect(tester.widget<FilledButton>(submit).onPressed, isNull);
        await tap(accept);
        await tap(submit);
        await tester.pumpAndSettle();
        expect(auth.pendingChallenge, Uri.parse(selected).host);
        await createEdayaSchoolClient(auth).effectiveGrants();
        expect(requests.last.origin, selected);

        await tap(find.text('Reset default'));
        await tester.pumpAndSettle();
        await ApiBaseUrlConfig.load();
        expect(ApiBaseUrlConfig.hasOverride, isFalse);
        expect(auth.baseUrl, fallback);
        expect(
          tester.widget<TextFormField>(urlField).controller!.text,
          fallback,
        );
      }
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
