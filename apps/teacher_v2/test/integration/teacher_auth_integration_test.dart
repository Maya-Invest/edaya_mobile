@Tags(['integration'])
library;

import 'package:edaya_auth/edaya_auth.dart';
import 'package:edaya_shared/edaya_shared.dart';
import 'package:edaya_integration_tests/edaya_integration_tests.dart';
import 'package:edaya_teacher_v2/di/prototype_module.dart';
import 'package:edaya_teacher_v2/features/context/academic_year_controller.dart';
import 'package:edaya_teacher_v2/app/workspace_navigation.dart';
import 'package:edaya_teacher_v2/design/theme.dart';
import 'package:edaya_teacher_v2/features/home/home_page.dart';
import 'package:edaya_teacher_v2/features/login/login_page.dart' as teacher;
import 'package:edaya_teacher_v2/live/noop_push.dart';
import 'package:edaya_teacher_v2/mock/mock_store.dart';
import 'package:flutter/material.dart';
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

Future<void> expectAutofilledCode(
  WidgetTester tester,
  String expected, {
  String field = 'auth-code',
}) async {
  final finder = find.byKey(Key(field));
  final input = tester.widget<TextFormField>(finder).controller!;
  final deadline = DateTime.now().add(const Duration(seconds: 15));
  while (input.text != expected && DateTime.now().isBefore(deadline)) {
    await tester.pump(const Duration(milliseconds: 100));
  }
  expect(input.text == expected, isTrue);
  final notice = AppLocalizations.of(
    tester.element(finder),
  )!.testCodeAutofilled;
  await until(tester, find.text(notice));
  expect(find.byKey(const Key('auth-test-reveal')), findsNothing);
  expect(find.byKey(const Key('auth-test-copy')), findsNothing);
  expect(find.byKey(const Key('auth-test-code')), findsNothing);
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
    return LScope(
      name: 'teacher-auth-${DateTime.now().microsecondsSinceEpoch}',
      dependencyFactory: (current) {
        scope = current;
        registerPrototypeDependencies(
          current,
          store: MockStore(),
          live: true,
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
    await expectAutofilledCode(tester, code);
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
      '[teacher-v2.auth.$channel] verifies a linked phone and preserves teaching access',
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
        await expectAutofilledCode(
          tester,
          linkingCode,
          field: 'auth-link-code',
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
            expect(controller.otpText.text.isEmpty, isTrue);
            expect(controller.delivery.testCode.value.isEmpty, isTrue);
            expect(controller.delivery.status.value!.channel, 'sms');
            expect(controller.delivery.status.value!.canSms, isFalse);
          }
        } finally {
          await setIntegrationClockOffset(Duration.zero);
        }
        await expectAutofilledCode(tester, code);
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
    '[teacher-v2.auth.email] signs in using UI OTP and bootstraps actual teaching permissions',
    (tester) async {
      await mount(tester);
      await signIn(tester);
      expect(scope.find<AppSessionController>().grants.value?.kind, 'teacher');
    },
  );
  testWidgets(
    '[teacher-v2.auth.restore-stale] restores a session and requires reauthentication after revocation',
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
    '[teacher-v2.profiles.select] selects an assignment automatically and exposes one hierarchical picker',
    (tester) async {
      await mount(tester);
      await signIn(tester);
      final session = scope.find<AppSessionController>();
      expect(session.availableProfiles.value, isNotEmpty);
      expect(session.needsProfileSelection, isFalse);
      expect(session.grants.value?.kind, 'teacher');
      scope.find<GoRouter>().go('/profiles');
      await until(tester, find.byType(HomePage));
      expect(find.byType(ProfilePickerPage), findsNothing);
      final year = scope.find<AcademicYearController>();
      expect(
        year.years.value.singleWhere(
          (row) => row['id'] == year.selectedYearId.value,
        )['status'],
        'published',
      );
      scope.find<GoRouter>().push('/home/context');
      await until(tester, find.byType(ClassContextPicker));
      expect(find.byType(DropdownButtonFormField<String>), findsNothing);
      await until(tester, find.textContaining(year.selectedYearLabel!));
      expect(find.text('Toutes les classes'), findsNothing);
    },
  );
}
