import 'package:edaya_auth/edaya_auth.dart';
import 'package:edaya_guardian/di/prototype_module.dart';
import 'package:edaya_guardian/design/theme.dart';
import 'package:edaya_guardian/features/auth/session_storage.dart';
import 'package:edaya_guardian/features/context/academic_year_controller.dart';
import 'package:edaya_guardian/features/context/student_context_controller.dart';
import 'package:edaya_guardian/features/my_students/linked_student.dart';
import 'package:edaya_integration_tests/edaya_integration_tests.dart';
import 'package:edaya_shared/edaya_shared.dart';
import 'package:edaya_shared/src/features/settings/app_settings_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:go_router/go_router.dart';
import 'package:levit_flutter/levit_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Wires the guardian app to a live [PortalSession] for widget tests.
class GuardianWidgetTestHarness {
  GuardianWidgetTestHarness._({
    required this.portalSession,
    required this.profile,
    required this.context,
    required this.language,
    AuthClient? guestAuthClient,
  }) : _guestAuthClient = guestAuthClient;

  final PortalSession? portalSession;
  final GuardianPortalProfile? profile;
  final GuardianPortalContext? context;
  final LanguagePreference language;
  final AuthClient? _guestAuthClient;

  bool get isGuest => _guestAuthClient != null;

  /// When set, design-review captures use this exact logical frame size.
  Size? viewportSize;

  LevitScope? _scope;

  /// Levit scope after [buildApp] or [buildRouterApp] has been pumped.
  LevitScope get scope {
    final resolved = _scope;
    if (resolved == null) {
      throw StateError(
        'Guardian widget harness: pump buildApp() or buildRouterApp() before using scope',
      );
    }
    return resolved;
  }

  GoRouter get router => scope.find<GoRouter>();

  static Future<GuardianWidgetTestHarness> create({
    GuardianPortalProfile profile = GuardianPortalProfile.mariamKone,
    LanguagePreference language = LanguagePreference.fr,
    PortalSession? authenticatedSession,
  }) async {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});

    final baseConfig = IntegrationConfig.fromEnvironment();
    final config = baseConfig.withGuardianEmail(profile.email);

    ApiBaseUrlConfig.configure(
      appDefaultUrl: config.baseUrl,
      appDefaultAuthUrl: config.authUrl,
    );
    await ApiBaseUrlConfig.saveOverride(config.baseUrl);
    await AppSettingsController.preload();

    final portalSession =
        authenticatedSession ??
        await PortalSession.signIn(
          config: config,
          actorKind: 'guardian',
          academicYearId: profile.academicYearId,
        );
    final portalContext = await bootstrapGuardianPortal(portalSession, profile);

    return GuardianWidgetTestHarness._(
      portalSession: portalSession,
      profile: profile,
      context: portalContext,
      language: language,
    );
  }

  /// Unauthenticated harness for capturing the login screen.
  static Future<GuardianWidgetTestHarness> createGuest({
    LanguagePreference language = LanguagePreference.fr,
  }) async {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});

    final config = IntegrationConfig.fromEnvironment();
    ApiBaseUrlConfig.configure(
      appDefaultUrl: config.baseUrl,
      appDefaultAuthUrl: config.authUrl,
    );
    await ApiBaseUrlConfig.saveOverride(config.baseUrl);
    await AppSettingsController.preload();

    return GuardianWidgetTestHarness._(
      portalSession: null,
      profile: null,
      context: null,
      language: language,
      guestAuthClient: AuthClient(baseUrl: config.authUrl),
    );
  }

  /// Builds the widget tree for a guardian page under test (no shell router).
  Widget buildApp(Widget child) {
    return LScope(
      name: 'guardian-widget-integration-${identityHashCode(this)}',
      dependencyFactory: (scope) {
        _scope = scope;
        registerDependencies(scope);
      },
      child: _GuardianTestShell(harness: this, child: child),
    );
  }

  /// Builds the authenticated shell with [GoRouter] (post-bootstrap).
  Widget buildRouterApp({String? initialRoute}) {
    return LScope(
      name: 'guardian-widget-integration-${identityHashCode(this)}',
      dependencyFactory: (scope) {
        _scope = scope;
        registerDependencies(scope);
      },
      child: _GuardianTestShell(
        harness: this,
        useRouter: true,
        initialRoute: initialRoute,
      ),
    );
  }

  /// Seeds guardian session context from data already loaded in [create].
  Future<void> bootstrapScope() async {
    final scope = _scope;
    if (scope == null) {
      throw StateError(
        'Guardian widget harness: pump buildApp() before bootstrapScope()',
      );
    }

    if (isGuest) {
      scope.find<AppSettingsController>().language(language);
      scope.find<AppSessionController>().isBootstrapping(false);
      return;
    }

    final profile = this.profile!;
    final context = this.context!;

    final session = scope.find<AppSessionController>();
    final sessionStorage = scope.find<SessionStorage>();
    final academicYear = scope.find<AcademicYearController>();
    final studentContext = scope.find<StudentContextController>();
    final settings = scope.find<AppSettingsController>();

    settings.language(language);

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
        context.primaryClassGroup['name'] as String? ??
        profile.primaryClassGroupId;
    final level = context.primaryClassGroup['level'] as String?;
    studentContext.classLabel(
      level == null ? className : '$className · $level',
    );
    studentContext.isEnrolled(true);
    studentContext.isLoading(false);
  }

  void registerDependencies(LevitScope scope) {
    registerPrototypeDependencies(
      scope,
      live: true,
      authClient: _guestAuthClient ?? portalSession!.authClient,
      pushNotifications: const _NoOpPushNotificationService(),
      includeBootstrap: false,
    );
  }

  Locale get appLocale => language.locale ?? const Locale('fr');

  static Widget materialApp({required Widget home, Locale? locale}) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: PrototypeTheme.light,
      locale: locale ?? const Locale('fr'),
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

  Widget designReviewRoot({required Widget child}) {
    final framed = viewportSize == null
        ? child
        : SizedBox(
            width: viewportSize!.width,
            height: viewportSize!.height,
            child: child,
          );
    return RepaintBoundary(
      key: const Key('guardian_design_review_root'),
      child: framed,
    );
  }
}

class _GuardianTestShell extends StatefulWidget {
  const _GuardianTestShell({
    required this.harness,
    this.child,
    this.useRouter = false,
    this.initialRoute,
  });

  final GuardianWidgetTestHarness harness;
  final Widget? child;
  final bool useRouter;
  final String? initialRoute;

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
      if (widget.useRouter) {
        final router = widget.harness._scope!.find<GoRouter>();
        final location =
            widget.initialRoute ??
            (widget.harness.isGuest ? '/login' : '/home');
        router.go(location);
      }
      widget.harness._scope!.find<EdayaRouterRefresh>().notifyListeners();
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
    final locale = widget.harness.appLocale;
    if (_error != null) {
      return widget.harness.designReviewRoot(
        child: GuardianWidgetTestHarness.materialApp(
          locale: locale,
          home: Scaffold(
            body: Center(child: Text('Bootstrap failed: $_error')),
          ),
        ),
      );
    }
    if (!_ready) {
      return widget.harness.designReviewRoot(
        child: GuardianWidgetTestHarness.materialApp(
          locale: locale,
          home: const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          ),
        ),
      );
    }
    if (widget.useRouter) {
      final router = widget.harness._scope!.find<GoRouter>();
      return widget.harness.designReviewRoot(
        child: MaterialApp.router(
          debugShowCheckedModeBanner: false,
          theme: PrototypeTheme.light,
          locale: locale,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          routerConfig: router,
        ),
      );
    }
    return widget.harness.designReviewRoot(
      child: GuardianWidgetTestHarness.materialApp(
        locale: locale,
        home: widget.child!,
      ),
    );
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
