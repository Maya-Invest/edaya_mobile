@Tags(['integration'])
library;

import 'package:edaya_api_client/edaya_api_client.dart';
import 'package:edaya_guardian/features/invite/invitation_page.dart';
import 'package:edaya_guardian/features/waiting/waiting_for_students_page.dart';
import 'package:edaya_auth/edaya_auth.dart';
import 'package:edaya_shared/src/features/auth/account_security_page.dart';
import 'package:edaya_shared/edaya_shared.dart';
import 'package:edaya_integration_tests/edaya_integration_tests.dart';
import 'package:edaya_guardian/di/prototype_module.dart';
import 'package:edaya_guardian/design/theme.dart';
import 'package:edaya_guardian/features/home/home_page.dart';
import 'package:edaya_guardian/features/login/login_page.dart' as guardian;
import 'package:edaya_guardian/features/push/noop_push_notification_service.dart';
import 'package:edaya_guardian/mock/mock_store.dart';
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
    if (finder.evaluate().length == 1) return;
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
      name: 'guardian-auth-${DateTime.now().microsecondsSinceEpoch}',
      dependencyFactory: (current) {
        scope = current;
        registerPrototypeDependencies(
          current,
          store: MockStore(),
          live: true,
          authClient: auth,
          pushNotifications: NoOpPushNotificationService(),
        );
      },
      child: Builder(
        builder: (context) {
          final bootstrap = context.levit.find<AppBootstrapController>();
          return LWatch(() {
            final ready = bootstrap.isReady.value;
            return MaterialApp.router(
              builder: (_, child) =>
                  ready ? child! : const EdayaStartupScreen(),
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
            );
          });
        },
      ),
    );
  }

  Future<void> signIn(
    WidgetTester tester, {
    String? email,
    Type destination = HomePage,
  }) async {
    await until(tester, find.byKey(const Key('auth-identifier')));
    email ??= GuardianPortalProfile.mariamKone.email;
    await tester.enterText(find.byKey(const Key('auth-identifier')), email);
    final since = DateTime.now();
    await tester.tap(find.byKey(const Key('auth-submit')));
    await until(tester, find.byKey(const Key('auth-code')));
    final code = await capturedOtp(email, 'email', since);
    await tester.enterText(find.byKey(const Key('auth-code')), code);
    await tester.tap(find.byKey(const Key('auth-submit')));
    await until(tester, find.byType(destination));
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
    '[guardian.auth.restore-stale] restores a session and requires reauthentication after revocation',
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
      await until(tester, find.byType(guardian.LoginPage));
      await until(tester, find.byKey(const Key('auth-identifier')));
      expect(scope.find<AppSessionController>().hasSchoolSession, isFalse);
      await signIn(tester);
    },
  );
  testWidgets(
    '[guardian.profiles.select] selects an authorized profile and returns to home',
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

  testWidgets(
    '[guardian.invitation.accept] verifies OTP before linking a new invited account',
    (tester) async {
      final owner = await PortalSession.signIn(
        config: config.withSchoolOwnerEmail(),
        actorKind: 'staff',
        academicYearId: config.academicYearId,
      );
      final school = await owner.schoolClient.effectiveGrants();
      final id = fixtureId('invited-guardian');
      final email = '$id@integration.edaya.test';
      await owner.schoolClient.registerGuardian({
        'id': id,
        'schoolId': school.schoolId,
        'firstName': 'Invited',
        'lastName': 'Guardian',
        'email': email,
        'sendAccountInvitation': false,
      });
      final invitation = await owner.schoolClient.sendAccountInvitation({
        'kind': 'guardian',
        'targetId': id,
        'inviteBaseUrl': 'http://127.0.0.1:24173/invite',
      });
      final token = invitation['token'] as String;
      await mount(tester);
      await until(tester, find.byKey(const Key('auth-identifier')));
      scope.find<GoRouter>().go('/invite/$token');
      await until(tester, find.text('Continuer'));
      expect(scope.find<AppSessionController>().isAuthenticated, isFalse);
      expect((await owner.schoolClient.guardians.get(id))['subjectId'], isNull);
      await tester.tap(find.text('Continuer'));
      await signIn(tester, email: email, destination: InvitationPage);
      await until(tester, find.text("Accepter l'invitation"));
      await tester.tap(find.text("Accepter l'invitation"));
      await until(tester, find.byType(WaitingForStudentsPage));
      final linked = await owner.schoolClient.guardians.get(id);
      expect(
        linked['subjectId'],
        scope.find<AppSessionController>().user.value!.id,
      );
      expect(scope.find<PendingInvitationStore>().token, isNull);
    },
  );

  testWidgets(
    '[guardian.auth.totp-recovery] enrolls an authenticator, signs in with TOTP, and consumes recovery codes once',
    (tester) async {
      final owner = await PortalSession.signIn(
        config: config.withSchoolOwnerEmail(),
        actorKind: 'staff',
        academicYearId: config.academicYearId,
      );
      final school = await owner.schoolClient.effectiveGrants();
      final id = fixtureId('security-guardian');
      final email = '$id@integration.edaya.test';
      await owner.schoolClient.registerGuardian({
        'id': id,
        'schoolId': school.schoolId,
        'firstName': 'Security',
        'lastName': 'Guardian',
        'email': email,
        'sendAccountInvitation': false,
      });
      await owner.schoolClient.linkGuardianToStudent({
        'id': fixtureId('link'),
        'guardianId': id,
        'studentId': GuardianPortalProfile.mariamKone.primaryStudentId,
        'relationship': 'parent',
      });
      final invitation = await owner.schoolClient.sendAccountInvitation({
        'kind': 'guardian',
        'targetId': id,
        'inviteBaseUrl': 'http://127.0.0.1:24173/invite',
      });
      await mount(tester);
      await until(tester, find.byKey(const Key('auth-identifier')));
      scope.find<GoRouter>().go('/invite/${invitation['token']}');
      await until(tester, find.text('Continuer'));
      await tester.tap(find.text('Continuer'));
      await signIn(tester, email: email, destination: InvitationPage);
      await until(tester, find.text("Accepter l'invitation"));
      await tester.tap(find.text("Accepter l'invitation"));
      await until(tester, find.byType(HomePage));
      scope.find<GoRouter>().go('/account/profile');
      await until(tester, find.text('Sécurité du compte'));
      await tester.ensureVisible(find.text('Sécurité du compte'));
      await tester.tap(find.text('Sécurité du compte'));
      await until(tester, find.text('Configurer l’application'));
      await tester.ensureVisible(find.text('Configurer l’application'));
      await tester.tap(find.text('Configurer l’application'));
      final secretField = find.byKey(const Key('auth-enrollment-secret'));
      await until(tester, secretField);
      final deadline = DateTime.now().add(const Duration(seconds: 15));
      while ((tester.widget<SelectableText>(secretField).data ?? '').isEmpty &&
          DateTime.now().isBefore(deadline)) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      final secret = tester.widget<SelectableText>(secretField).data!;
      if (secret.isEmpty) fail('Authenticator setup secret was not received');
      final enrollmentCode = authenticatorCode(secret);
      await tester.enterText(
        find.byKey(const Key('auth-code')),
        enrollmentCode,
      );
      await tester.tap(find.byKey(const Key('auth-submit')));
      await until(tester, find.byKey(const Key('auth-recovery-codes')));
      final codes = tester
          .widget<SelectableText>(find.byKey(const Key('auth-recovery-codes')))
          .data!
          .split('\n');
      expect(codes.length, greaterThan(1));
      await tester.ensureVisible(find.byKey(const Key('auth-submit')));
      await tester.tap(find.byKey(const Key('auth-submit')));
      await until(tester, find.byType(AccountSecurityPage));
      Navigator.of(tester.element(find.byType(AccountSecurityPage))).pop();

      Future<void> logout() async {
        scope.find<GoRouter>().go('/account');
        await until(tester, find.text('Se déconnecter'));
        await tester.ensureVisible(find.text('Se déconnecter'));
        await tester.tap(find.text('Se déconnecter'));
        await until(tester, find.byKey(const Key('auth-identifier')));
      }

      Future<void> primaryProof() async {
        await signIn(tester, email: email, destination: guardian.LoginPage);
        await until(tester, find.byKey(const Key('auth-use-recovery')));
        expect(scope.find<AppSessionController>().isAuthenticated, isFalse);
      }

      await logout();
      await primaryProof();
      // Enrollment consumed this counter. Wait for a fresh real authenticator step.
      final nextStep = DateTime.now().add(const Duration(seconds: 31));
      while (authenticatorCode(secret) == enrollmentCode &&
          DateTime.now().isBefore(nextStep)) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      await tester.enterText(
        find.byKey(const Key('auth-code')),
        authenticatorCode(secret),
      );
      await tester.tap(find.byKey(const Key('auth-submit')));
      await until(tester, find.byType(HomePage));
      await logout();
      await primaryProof();
      await tester.tap(find.byKey(const Key('auth-use-recovery')));
      await tester.pump();
      await tester.enterText(find.byKey(const Key('auth-code')), codes.first);
      await tester.tap(find.byKey(const Key('auth-submit')));
      await until(tester, secretField);
      final replacementBy = DateTime.now().add(const Duration(seconds: 15));
      while ((tester.widget<SelectableText>(secretField).data ?? '').isEmpty &&
          DateTime.now().isBefore(replacementBy)) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      final replacementSecret = tester
          .widget<SelectableText>(secretField)
          .data!;
      if (replacementSecret.isEmpty) {
        fail('Recovery must require replacement authenticator enrollment');
      }
      await tester.enterText(
        find.byKey(const Key('auth-code')),
        authenticatorCode(replacementSecret),
      );
      await tester.tap(find.byKey(const Key('auth-submit')));
      await until(tester, find.byKey(const Key('auth-recovery-codes')));
      await tester.ensureVisible(find.byKey(const Key('auth-submit')));
      await tester.tap(find.byKey(const Key('auth-submit')));
      await until(tester, find.byType(HomePage));
      await logout();
      await primaryProof();
      await tester.tap(find.byKey(const Key('auth-use-recovery')));
      await tester.pump();
      await tester.enterText(find.byKey(const Key('auth-code')), codes.first);
      await tester.tap(find.byKey(const Key('auth-submit')));
      final controller = tester
          .element(find.byKey(const Key('auth-code')))
          .levit
          .find<LoginController>();
      final rejectedBy = DateTime.now().add(const Duration(seconds: 15));
      while (controller.errorMessage.value.isEmpty &&
          DateTime.now().isBefore(rejectedBy)) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(controller.errorMessage.value, isNotEmpty);
      expect(scope.find<AppSessionController>().isAuthenticated, isFalse);
    },
  );
}
