import 'package:edaya_auth/edaya_auth.dart';
import 'package:edaya_guardian/app/router.dart';
import 'package:edaya_guardian/features/auth/session_storage.dart';
import 'package:edaya_guardian/features/context/academic_year_controller.dart';
import 'package:edaya_guardian/features/context/student_context_controller.dart';
import 'package:edaya_guardian/features/my_students/linked_student.dart';
import 'package:edaya_integration_tests/edaya_integration_tests.dart';
import 'package:edaya_shared/edaya_shared.dart';
import 'package:edaya_shared/src/features/settings/app_settings_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:levit_flutter/levit_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Wires guardian app controllers to a live [PortalSession] for widget tests.
class GuardianWidgetTestHarness {
  GuardianWidgetTestHarness._({
    required this.portalSession,
    required this.profile,
    required this.context,
  });

  final PortalSession portalSession;
  final GuardianPortalProfile profile;
  final GuardianPortalContext context;

  LevitScope? _scope;

  static Future<GuardianWidgetTestHarness> create({
    GuardianPortalProfile profile = GuardianPortalProfile.mariamKone,
  }) async {
    SharedPreferences.setMockInitialValues({});

    final baseConfig = IntegrationConfig.fromEnvironment();
    final config = baseConfig.withGuardianEmail(profile.email);

    ApiBaseUrlConfig.configure(appDefaultUrl: config.baseUrl);
    await ApiBaseUrlConfig.saveOverride(config.baseUrl);
    await AppSettingsController.preload();

    final portalSession = await PortalSession.signIn(
      config: config,
      actorKind: 'guardian',
      academicYearId: profile.academicYearId,
    );
    final portalContext = await bootstrapGuardianPortal(portalSession, profile);

    return GuardianWidgetTestHarness._(
      portalSession: portalSession,
      profile: profile,
      context: portalContext,
    );
  }

  /// Builds the widget tree for a guardian page under test.
  Widget buildApp(Widget child) {
    return LScope(
      name: 'guardian-widget-integration',
      dependencyFactory: (scope) {
        _scope = scope;
        registerDependencies(scope);
      },
      child: _GuardianTestShell(harness: this, child: child),
    );
  }

  /// Builds the authenticated shell with [AppRouter] (post-bootstrap).
  Widget buildRouterApp() {
    return LScope(
      name: 'guardian-widget-integration',
      dependencyFactory: (scope) {
        _scope = scope;
        registerDependencies(scope);
      },
      child: _GuardianTestShell(harness: this, useRouter: true),
    );
  }

  /// Seeds guardian session context from data already loaded in [create].
  Future<void> bootstrapScope() async {
    final scope = _scope;
    if (scope == null) {
      throw StateError('Guardian widget harness: pump buildApp() before bootstrapScope()');
    }

    final session = scope.find<AppSessionController>();
    final sessionStorage = scope.find<SessionStorage>();
    final academicYear = scope.find<AcademicYearController>();
    final studentContext = scope.find<StudentContextController>();
    final settings = scope.find<AppSettingsController>();

    settings.language(LanguagePreference.en);

    session.user(AuthUser(id: context.authUserId, email: profile.email));
    session.grants(context.grants);
    session.isBootstrapping(false);

    await sessionStorage.writeAcademicYearId(profile.academicYearId);
    await sessionStorage.writeActiveStudentId(profile.primaryStudentId);

    academicYear.years(context.academicYears);
    academicYear.selectedYearId(profile.academicYearId);

    final studentRow = context.linkedStudents.firstWhere(
      (row) => row['id'] == profile.primaryStudentId,
    );
    studentContext.activeStudent(LinkedStudent.fromJson(studentRow));
    studentContext.classGroupId(profile.primaryClassGroupId);

    final className =
        context.primaryClassGroup['name'] as String? ?? profile.primaryClassGroupId;
    final level = context.primaryClassGroup['level'] as String?;
    studentContext.classLabel(
      level == null ? className : '$className · $level',
    );
    studentContext.isEnrolled(true);
    studentContext.isLoading(false);
  }

  void registerDependencies(LevitScope scope) {
    EdayaRootScope.bind(scope, appName: 'Guardian integration test');

    scope.put<SessionStorage>(() => SessionStorage(), permanent: true);
    scope.put<CookieJar>(() => portalSession.authClient.cookieJar, permanent: true);
    scope.put<AuthClient>(() => portalSession.authClient, permanent: true);
    scope.put<PushNotificationService>(
      () => const _NoOpPushNotificationService(),
      permanent: true,
    );
    scope.put<EdayaRouterRefresh>(() => EdayaRouterRefresh(), permanent: true);
    scope.put<AppSettingsController>(
      () => AppSettingsController(),
      permanent: true,
    );

    registerSchoolClientFactory(
      scope,
      getAcademicYearId: () =>
          scope.find<AcademicYearController>().selectedYearId.value,
      getActorKind: () => 'guardian',
    );

    scope.put<AppSessionController>(
      () => AppSessionController(
        authClient: scope.find<AuthClient>(),
        sessionStorage: scope.find<SessionStorage>(),
        pushNotifications: scope.find<PushNotificationService>(),
        routerRefresh: scope.find<EdayaRouterRefresh>(),
        validateGrants: (_) => null,
        unauthorizedProfileMessage: () => systemL10n().signedInNoGuardianProfile,
        resolveActorKind: () => 'guardian',
      ),
      permanent: true,
    );
    scope.put<AcademicYearController>(
      () => AcademicYearController(
        sessionStorage: scope.find<SessionStorage>(),
        session: scope.find<AppSessionController>(),
        schoolClient: scope.find<SchoolClientFactory>(),
      ),
      permanent: true,
    );
    scope.put<StudentContextController>(
      () => StudentContextController(
        sessionStorage: scope.find<SessionStorage>(),
        session: scope.find<AppSessionController>(),
        academicYear: scope.find<AcademicYearController>(),
        schoolClient: scope.find<SchoolClientFactory>(),
      ),
      permanent: true,
    );
    scope.put<AppRouter>(
      () => AppRouter(
        session: scope.find<AppSessionController>(),
        routerRefresh: scope.find<EdayaRouterRefresh>(),
      ),
      permanent: true,
    );
  }

  static Widget materialApp({required Widget home}) {
    return MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: home,
    );
  }
}

class _GuardianTestShell extends StatefulWidget {
  const _GuardianTestShell({
    required this.harness,
    this.child,
    this.useRouter = false,
  });

  final GuardianWidgetTestHarness harness;
  final Widget? child;
  final bool useRouter;

  @override
  State<_GuardianTestShell> createState() => _GuardianTestShellState();
}

class _GuardianTestShellState extends State<_GuardianTestShell> {
  var _ready = false;
  Object? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrap());
  }

  Future<void> _bootstrap() async {
    try {
      await widget.harness.bootstrapScope();
      if (!mounted) {
        return;
      }
      setState(() => _ready = true);
    } on Object catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _error = error);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return GuardianWidgetTestHarness.materialApp(
        home: Scaffold(body: Center(child: Text('Bootstrap failed: $_error'))),
      );
    }
    if (!_ready) {
      return GuardianWidgetTestHarness.materialApp(
        home: const Scaffold(body: Center(child: CircularProgressIndicator())),
      );
    }
    if (widget.useRouter) {
      final appRouter = widget.harness._scope!.find<AppRouter>();
      return MaterialApp.router(
        locale: const Locale('en'),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        routerConfig: appRouter.config(),
      );
    }
    return GuardianWidgetTestHarness.materialApp(home: widget.child!);
  }
}

class _NoOpPushNotificationService implements PushNotificationService {
  const _NoOpPushNotificationService();

  @override
  Future<void> initialize() async {}

  @override
  Future<void> registerForAuthenticatedUser() async {}

  @override
  Future<void> unregister() async {}

  @override
  Future<void> consumePendingNavigation() async {}
}
