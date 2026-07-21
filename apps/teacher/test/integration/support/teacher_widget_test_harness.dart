import 'package:edaya_api_client/edaya_api_client.dart';
import 'package:edaya_auth/edaya_auth.dart';
import 'package:edaya_integration_tests/edaya_integration_tests.dart';
import 'package:edaya_shared/edaya_shared.dart';
import 'package:edaya_shared/src/features/settings/app_settings_models.dart';
import 'package:edaya_teacher/app/router.dart';
import 'package:edaya_teacher/di/teacher_module.dart';
import 'package:edaya_teacher/features/auth/session_storage.dart';
import 'package:edaya_teacher/features/context/academic_year_controller.dart';
import 'package:edaya_teacher/features/context/teacher_context_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:levit_flutter/levit_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Wires teacher app controllers to a live [PortalSession] for widget tests.
class TeacherWidgetTestHarness {
  TeacherWidgetTestHarness._({
    required this.portalSession,
    required this.profile,
    required this.context,
    required this.authUserId,
    required this.teacherDisplayName,
    required this.language,
    AuthClient? guestAuthClient,
  }) : _guestAuthClient = guestAuthClient;

  final PortalSession? portalSession;
  final TeacherPortalProfile? profile;
  final TeacherPortalContext? context;
  final String authUserId;
  final String teacherDisplayName;
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
        'Teacher widget harness: pump buildApp() or buildRouterApp() before using scope',
      );
    }
    return resolved;
  }

  static Future<TeacherWidgetTestHarness> create({
    TeacherPortalProfile profile = TeacherPortalProfile.subjectTeacher,
    LanguagePreference language = LanguagePreference.en,
  }) async {
    SharedPreferences.setMockInitialValues({});

    final baseConfig = IntegrationConfig.fromEnvironment();
    final config = baseConfig.withTeacherEmail(profile.email);

    ApiBaseUrlConfig.configure(appDefaultUrl: config.baseUrl);
    await ApiBaseUrlConfig.saveOverride(config.baseUrl);
    await AppSettingsController.preload();

    final portalSession = await PortalSession.signIn(
      config: config,
      actorKind: 'teacher',
      academicYearId: profile.academicYearId,
    );
    final portalContext = await bootstrapTeacherPortal(portalSession, profile);
    final authSession = await portalSession.authClient.getSession();
    final authUserId = authSession.data?.user.id ?? '';

    final teacher = await portalSession.schoolClient.teachers.get(
      portalContext.grants.actorId,
    );
    final firstName = teacher['firstName'] as String? ?? '';
    final lastName = teacher['lastName'] as String? ?? '';
    final fullName = '$firstName $lastName'.trim();

    return TeacherWidgetTestHarness._(
      portalSession: portalSession,
      profile: profile,
      context: portalContext,
      authUserId: authUserId,
      teacherDisplayName: fullName.isEmpty ? profile.email : fullName,
      language: language,
    );
  }

  /// Unauthenticated harness for capturing the login screen.
  static Future<TeacherWidgetTestHarness> createGuest({
    LanguagePreference language = LanguagePreference.fr,
  }) async {
    SharedPreferences.setMockInitialValues({});

    final config = IntegrationConfig.fromEnvironment();
    ApiBaseUrlConfig.configure(appDefaultUrl: config.baseUrl);
    await ApiBaseUrlConfig.saveOverride(config.baseUrl);
    await AppSettingsController.preload();

    return TeacherWidgetTestHarness._(
      portalSession: null,
      profile: null,
      context: null,
      authUserId: '',
      teacherDisplayName: '',
      language: language,
      guestAuthClient: AuthClient(baseUrl: config.baseUrl),
    );
  }

  Widget buildApp(Widget child) {
    return LScope(
      name: 'teacher-widget-integration',
      dependencyFactory: (scope) {
        _scope = scope;
        registerDependencies(scope);
      },
      child: _TeacherTestShell(harness: this, child: child),
    );
  }

  Widget buildRouterApp({String? initialRoute, Object? initialExtra}) {
    return LScope(
      name: 'teacher-widget-integration',
      dependencyFactory: (scope) {
        _scope = scope;
        registerDependencies(scope);
      },
      child: _TeacherTestShell(
        harness: this,
        useRouter: true,
        initialRoute: initialRoute,
        initialExtra: initialExtra,
      ),
    );
  }

  /// Seeds teacher session context from data already loaded in [create].
  Future<void> bootstrapScope() async {
    final scope = _scope;
    if (scope == null) {
      throw StateError(
        'Teacher widget harness: pump buildApp() before bootstrapScope()',
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
    final teacherContext = scope.find<TeacherContextController>();
    final settings = scope.find<AppSettingsController>();

    settings.language(language);

    session.user(AuthUser(id: authUserId, email: profile.email));
    session.grants(context.grants);
    session.isBootstrapping(false);

    await sessionStorage.writeAcademicYearId(profile.academicYearId);
    await sessionStorage.writeClassFilterId(null);

    academicYear.years(context.academicYears);
    academicYear.selectedYearId(profile.academicYearId);

    final assignedClasses = context.assignedClassGroups
        .map(
          (classGroup) => AssignedClass(
            id: classGroup['id'] as String,
            label: classGroup['name'] as String? ?? classGroup['id'] as String,
          ),
        )
        .toList()
      ..sort((a, b) => a.label.compareTo(b.label));

    teacherContext.teacherId(context.grants.actorId);
    teacherContext.teacherName(teacherDisplayName);
    teacherContext.teacherPhotoUrl(null);
    teacherContext.classFilterId(null);
    teacherContext.assignedClasses(assignedClasses);
    teacherContext.taughtClassSubjectIds(context.teachingScope.classSubjectIds);
    teacherContext.assignedClassGroupIds(context.teachingScope.classGroupIds);
    teacherContext.isLoading(false);
    teacherContext.errorMessage('');
  }

  void registerDependencies(LevitScope scope) {
    if (isGuest) {
      registerTeacherDependencies(
        scope,
        authClient: _guestAuthClient,
        pushNotifications: const _NoOpPushNotificationService(),
        includeBootstrap: false,
        eager: false,
      );
      return;
    }

    final portalSession = this.portalSession!;
    registerTeacherDependencies(
      scope,
      cookieJar: portalSession.authClient.cookieJar,
      authClient: portalSession.authClient,
      pushNotifications: const _NoOpPushNotificationService(),
      includeBootstrap: false,
      eager: false,
    );
  }

  static Widget materialApp({
    required Widget home,
    Locale? locale,
  }) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.light,
      locale: locale ?? const Locale('en'),
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

  Locale get appLocale => language.locale ?? const Locale('en');

  Widget designReviewRoot({required Widget child}) {
    final framed = viewportSize == null
        ? child
        : SizedBox(width: viewportSize!.width, height: viewportSize!.height, child: child);
    return RepaintBoundary(
      key: const Key('teacher_design_review_root'),
      child: framed,
    );
  }
}

class _TeacherTestShell extends StatefulWidget {
  const _TeacherTestShell({
    required this.harness,
    this.child,
    this.useRouter = false,
    this.initialRoute,
    this.initialExtra,
  });

  final TeacherWidgetTestHarness harness;
  final Widget? child;
  final bool useRouter;
  final String? initialRoute;
  final Object? initialExtra;

  @override
  State<_TeacherTestShell> createState() => _TeacherTestShellState();
}

class _TeacherTestShellState extends State<_TeacherTestShell> {
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
        final router = widget.harness._scope!.find<AppRouter>();
        final location = widget.initialRoute ??
            (widget.harness.isGuest ? '/login' : '/calendar');
        // Nested routes that rely on `extra` must use push — go() drops it.
        if (widget.initialExtra != null) {
          router.router.push(location, extra: widget.initialExtra);
        } else {
          router.router.go(location);
        }
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
        child: TeacherWidgetTestHarness.materialApp(
          locale: locale,
          home: Scaffold(
            body: Center(child: Text('Bootstrap failed: $_error')),
          ),
        ),
      );
    }
    if (!_ready) {
      return widget.harness.designReviewRoot(
        child: TeacherWidgetTestHarness.materialApp(
          locale: locale,
          home: const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          ),
        ),
      );
    }
    if (widget.useRouter) {
      final appRouter = widget.harness._scope!.find<AppRouter>();
      return widget.harness.designReviewRoot(
        child: MaterialApp.router(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light,
          darkTheme: AppTheme.dark,
          themeMode: ThemeMode.light,
          locale: locale,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          routerConfig: appRouter.config(),
        ),
      );
    }
    return widget.harness.designReviewRoot(
      child: TeacherWidgetTestHarness.materialApp(
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
