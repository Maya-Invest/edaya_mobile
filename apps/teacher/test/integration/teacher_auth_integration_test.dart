@Tags(['integration'])
library;

import 'package:edaya_auth/edaya_auth.dart';
import 'package:edaya_shared/edaya_shared.dart';
import 'package:edaya_shared/src/features/auth/account_security_page.dart';
import 'package:edaya_integration_tests/edaya_integration_tests.dart';
import 'package:edaya_teacher/di/prototype_module.dart';
import 'package:edaya_teacher/design/theme.dart';
import 'package:edaya_teacher/features/home/home_page.dart';
import 'package:edaya_teacher/features/login/login_page.dart' as teacher;
import 'package:edaya_teacher/live/noop_push.dart';
import 'package:edaya_teacher/mock/mock_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:levit_flutter/levit_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'support/integration_test_lifecycle.dart';
import 'support/live_api_test_binding.dart';
import '../../../../packages/edaya_shared/test/support/enter_focused_text.dart';
import '../../../../packages/edaya_shared/test/support/submit_auth.dart';

Future<void> until(WidgetTester tester, Finder finder) async {
  final deadline = DateTime.now().add(const Duration(seconds: 30));
  while (DateTime.now().isBefore(deadline)) {
    await tester.pump(const Duration(milliseconds: 100));
    if (tester.any(finder)) return;
  }
  fail('Expected authentication outcome: $finder');
}

Future<void> revealAndCopy(
  WidgetTester tester,
  String expected, {
  String field = 'auth-code',
}) async {
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
  final input = tester.widget<TextFormField>(find.byKey(Key(field)));
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
    testWidgets('teacher auth disabled', (_) async {}, skip: true);
    return;
  }
  final config = IntegrationConfig.fromEnvironment();
  late LevitScope scope;
  Widget app() {
    final auth = AuthClient(baseUrl: config.authUrl);
    return LScope(
      name: 'teacher-auth-${DateTime.now().microsecondsSinceEpoch}',
      dependencyFactory: (current) {
        scope = current;
        registerPrototypeDependencies(
          current,
          store: MockStore(),
          live: true,
          authClient: auth,
          cookieJar: auth.cookieJar,
          pushNotifications: NoOpPushNotificationService(),
        );
      },
      child: Builder(
        builder: (context) => MaterialApp.router(
          theme: PrototypeTheme.light,
          locale: const Locale('fr'),
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          routerConfig: context.levit.find<GoRouter>(),
        ),
      ),
    );
  }

  Future<void> signIn(WidgetTester tester) async {
    await until(tester, find.byKey(const Key('auth-identifier')));
    await tester.enterText(
      find.byKey(const Key('auth-identifier')),
      TeacherPortalProfile.subjectTeacher.email,
    );
    final since = DateTime.now();
    await submitAuth(tester);
    await until(tester, find.byKey(const Key('auth-code')));
    final code = await capturedOtp(
      TeacherPortalProfile.subjectTeacher.email,
      'email',
      since,
    );
    await revealAndCopy(tester, code);
    await enterFocusedText(tester, find.byKey(const Key('auth-code')), code);
    await submitAuth(tester);
    await until(tester, find.byType(HomePage));
    expect(scope.find<AppSessionController>().hasSchoolSession, isTrue);
  }

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    ApiBaseUrlConfig.configure(appDefaultUrl: config.baseUrl);
    await ApiBaseUrlConfig.saveOverride(config.baseUrl);
    await AppSettingsController.preload();
  });
  Future<void> mount(WidgetTester tester) async {
    await configureDesignReviewViewport(tester, DesignReviewFormFactor.phone);
    addTearDown(() async {
      await resetIntegrationTestSurface(tester);
      await resetIntegrationTestViewport(tester);
    });
    await tester.pumpWidget(app());
  }

  for (final channel in ['whatsapp', 'sms-switch']) {
    testWidgets(
      '[teacher.auth.$channel] verifies a linked phone and preserves teaching access',
      (tester) async {
        await mount(tester);
        await signIn(tester);
        final auth = scope.find<AuthClient>();
        final phone =
            '+22507${DateTime.now().microsecondsSinceEpoch.toString().substring(8)}';
        var since = DateTime.now();
        scope.find<GoRouter>().go('/account/profile');
        await until(tester, find.text('Sécurité du compte'));
        await tester.ensureVisible(find.text('Sécurité du compte'));
        await tester.tap(find.text('Sécurité du compte'));
        await until(tester, find.byType(AccountSecurityPage));
        final security = tester
            .element(
              find
                  .descendant(
                    of: find.byType(AccountSecurityPage),
                    matching: find.byType(ListView),
                  )
                  .first,
            )
            .levit
            .find<AccountSecurityController>();
        final ready = DateTime.now().add(const Duration(seconds: 15));
        while ((security.identifiers.value.isEmpty ||
                !security.delivery.phoneAvailable.value) &&
            DateTime.now().isBefore(ready)) {
          await tester.pump(const Duration(milliseconds: 100));
        }
        expect(security.identifiers.value, isNotEmpty);
        expect(security.delivery.phoneAvailable.value, isTrue);
        await tester.scrollUntilVisible(
          find.byKey(const Key('auth-link-channel')),
          200,
          scrollable: find
              .descendant(
                of: find.byType(AccountSecurityPage),
                matching: find.byType(Scrollable),
              )
              .first,
        );
        await tester.ensureVisible(find.byKey(const Key('auth-link-channel')));
        await until(
          tester,
          find.byKey(const Key('auth-link-channel')).hitTestable(),
        );
        await tester.tap(find.byKey(const Key('auth-link-channel')));
        await tester.pump(const Duration(milliseconds: 300));
        await until(tester, find.text('Téléphone').hitTestable());
        await tester.tap(find.text('Téléphone').hitTestable().last);
        await tester.pump(const Duration(milliseconds: 300));
        await tester.scrollUntilVisible(
          find.byKey(const Key('auth-link-contact')),
          100,
          scrollable: find
              .descendant(
                of: find.byType(AccountSecurityPage),
                matching: find.byType(Scrollable),
              )
              .first,
        );
        await until(
          tester,
          find.byKey(const Key('auth-link-contact')).hitTestable(),
        );
        await tester.enterText(
          find.byKey(const Key('auth-link-contact')),
          phone,
        );
        await tester.ensureVisible(find.byKey(const Key('auth-link-submit')));
        await tester.tap(find.byKey(const Key('auth-link-submit')));
        await until(tester, find.byKey(const Key('auth-link-code')));
        final linkingCode = await capturedOtp(phone, 'whatsapp', since);
        await revealAndCopy(tester, linkingCode, field: 'auth-link-code');
        await tester.enterText(
          find.byKey(const Key('auth-link-code')),
          linkingCode,
        );
        await tester.ensureVisible(find.byKey(const Key('auth-link-submit')));
        await tester.tap(find.byKey(const Key('auth-link-submit')));
        await until(tester, find.text(phone));
        expect(security.delivery.testCode.value.isEmpty, isTrue);
        Navigator.of(tester.element(find.byType(AccountSecurityPage))).pop();
        scope.find<GoRouter>().go('/home');
        await until(tester, find.byType(HomePage));
        await scope.find<AppSessionController>().signOut();
        await until(tester, find.byKey(const Key('auth-identifier')));
        final controller = tester
            .element(find.byKey(const Key('auth-identifier')))
            .levit
            .find<LoginController>();
        final availableDeadline = DateTime.now().add(
          const Duration(seconds: 15),
        );
        while (!controller.delivery.phoneAvailable.value &&
            DateTime.now().isBefore(availableDeadline)) {
          await tester.pump(const Duration(milliseconds: 100));
        }
        expect(controller.delivery.phoneAvailable.value, isTrue);
        expect(find.byKey(const Key('auth-channel')), findsNothing);
        await tester.enterText(find.byKey(const Key('auth-identifier')), phone);
        late String code;
        try {
          // Linking and login share the same recipient cooldown.
          await setIntegrationClockOffset(const Duration(seconds: 61));
          since = DateTime.now();
          await tester.ensureVisible(find.byKey(const Key('auth-submit')));
          await submitAuth(tester);
          await until(tester, find.byKey(const Key('auth-code')));
          code = await capturedOtp(phone, 'whatsapp', since);
          expect(controller.delivery.remaining.value, greaterThan(110));
          if (channel == 'sms-switch') {
            expect(controller.delivery.canSms, isFalse);
            await enterFocusedText(
              tester,
              find.byKey(const Key('auth-code')),
              code,
            );
            await setIntegrationClockOffset(const Duration(seconds: 182));
            final deadline = DateTime.now().add(const Duration(seconds: 15));
            while (!controller.delivery.canSms &&
                DateTime.now().isBefore(deadline)) {
              await tester.pump(const Duration(milliseconds: 100));
            }
            expect(controller.delivery.canSms, isTrue);
            since = DateTime.now();
            await tester.ensureVisible(find.byKey(const Key('auth-sms')));
            await tester.tap(find.byKey(const Key('auth-sms')));
            code = await capturedOtp(phone, 'sms', since);
            while (controller.isBusy.value) {
              await tester.pump(const Duration(milliseconds: 100));
            }
            expect(controller.otpText.text, isEmpty);
            expect(controller.delivery.testCode.value.isEmpty, isTrue);
            expect(controller.delivery.status.value!.channel, 'sms');
            expect(controller.delivery.status.value!.canSms, isFalse);
          }
        } finally {
          await setIntegrationClockOffset(Duration.zero);
        }
        await tester.enterText(find.byKey(const Key('auth-code')), '');
        await revealAndCopy(tester, code);
        await enterFocusedText(
          tester,
          find.byKey(const Key('auth-code')),
          code,
        );
        await tester.ensureVisible(find.byKey(const Key('auth-submit')));
        await submitAuth(tester);
        await until(tester, find.byType(HomePage));
        expect(
          scope.find<AppSessionController>().grants.value?.kind,
          'teacher',
        );
        expect((await auth.getSession()).data?.user.id, isNotEmpty);
        final linked = (await auth.identifiers()).data!;
        expect(
          linked.any((identifier) => identifier['value'] == phone),
          isTrue,
        );
        final identifier = linked.singleWhere((row) => row['value'] == phone);
        final removed = await auth.unlinkIdentifier(identifier['id'] as String);
        expect(removed.isSuccess, isTrue);
      },
    );
  }

  testWidgets(
    '[teacher.auth.email] signs in using UI OTP and bootstraps actual teaching permissions',
    (tester) async {
      await mount(tester);
      await signIn(tester);
      expect(scope.find<AppSessionController>().grants.value?.kind, 'teacher');
    },
  );
  testWidgets(
    '[teacher.auth.restore-stale] restores a session and requires reauthentication after revocation',
    (tester) async {
      await mount(tester);
      await signIn(tester);
      final credential = scope.find<AuthClient>().renewalCredential!;
      await resetIntegrationTestSurface(tester);
      await tester.pumpWidget(app());
      await until(tester, find.byType(HomePage));
      final revoked = AuthClient(baseUrl: config.authUrl)
        ..restoreRenewalCredential(credential);
      final result = await revoked.signOut();
      expect(result.isSuccess, isTrue);
      await resetIntegrationTestSurface(tester);
      await tester.pumpWidget(app());
      await until(tester, find.byType(teacher.LoginPage));
      await until(tester, find.byKey(const Key('auth-identifier')));
      expect(scope.find<AppSessionController>().hasSchoolSession, isFalse);
      await signIn(tester);
    },
  );
  testWidgets(
    '[teacher.profiles.select] selects an authorized profile and returns to home',
    (tester) async {
      await mount(tester);
      await signIn(tester);
      final session = scope.find<AppSessionController>();
      expect(session.availableProfiles.value, isNotEmpty);
      final profile = session.availableProfiles.value.first;
      scope.find<GoRouter>().go('/profiles');
      await until(tester, find.byType(ProfilePickerPage));
      final choice = find
          .descendant(
            of: find.byType(ProfilePickerPage),
            matching: find.text(profile.label),
          )
          .first;
      await until(tester, choice);
      await tester.tap(choice);
      await until(tester, find.byType(HomePage));
      final deadline = DateTime.now().add(const Duration(seconds: 20));
      while (session.grants.value?.actorId != profile.actorId &&
          DateTime.now().isBefore(deadline)) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(session.grants.value?.actorId, profile.actorId);
      expect(session.grants.value?.schoolId, profile.schoolId);
    },
  );
}
