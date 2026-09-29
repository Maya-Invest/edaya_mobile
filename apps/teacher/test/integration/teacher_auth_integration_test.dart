@Tags(['integration'])
library;

import 'package:edaya_auth/edaya_auth.dart';
import 'package:edaya_shared/edaya_shared.dart';
import 'package:edaya_integration_tests/edaya_integration_tests.dart';
import 'package:edaya_teacher/di/prototype_module.dart';
import 'package:edaya_teacher/design/theme.dart';
import 'package:edaya_teacher/features/home/home_page.dart';
import 'package:edaya_teacher/features/login/login_page.dart' as teacher;
import 'package:edaya_teacher/live/noop_push.dart';
import 'package:edaya_teacher/mock/mock_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:levit_flutter/levit_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'support/integration_test_lifecycle.dart';
import 'support/live_api_test_binding.dart';

Future<void> until(WidgetTester tester, Finder finder) async {
  final deadline = DateTime.now().add(const Duration(seconds: 30));
  while (DateTime.now().isBefore(deadline)) {
    await tester.pump(const Duration(milliseconds: 100));
    if (tester.any(finder)) return;
  }
  fail('Expected authentication outcome: $finder');
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
    await tester.tap(find.byKey(const Key('auth-submit')));
    await until(tester, find.byKey(const Key('auth-code')));
    final code = await capturedOtp(
      TeacherPortalProfile.subjectTeacher.email,
      'email',
      since,
    );
    await tester.enterText(find.byKey(const Key('auth-code')), code);
    await tester.tap(find.byKey(const Key('auth-submit')));
    await until(tester, find.byType(HomePage));
    expect(scope.find<AppSessionController>().hasSchoolSession, isTrue);
  }

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    ApiBaseUrlConfig.configure(
      appDefaultUrl: config.baseUrl,
      appDefaultAuthUrl: config.authUrl,
    );
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
      await until(tester, find.text(profile.label));
      await tester.tap(find.text(profile.label));
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
