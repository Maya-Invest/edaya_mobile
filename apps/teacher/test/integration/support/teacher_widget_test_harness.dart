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
  });

  final PortalSession portalSession;
  final TeacherPortalProfile profile;
  final TeacherPortalContext context;
  final String authUserId;
  final String teacherDisplayName;

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
  }) async {
    SharedPreferences.setMockInitialValues({});

    final baseConfig = IntegrationConfig.fromEnvironment();
    final config = baseConfig.withTeacherEmail(profile.email);

    ApiBaseUrlConfig.configure(
      appDefaultUrl: config.baseUrl,
      appDefaultAuthUrl: config.authUrl,
    );
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

  Widget buildRouterApp({String? initialRoute}) {
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

    final session = scope.find<AppSessionController>();
    final sessionStorage = scope.find<SessionStorage>();
    final academicYear = scope.find<AcademicYearController>();
    final teacherContext = scope.find<TeacherContextController>();
    final settings = scope.find<AppSettingsController>();

    settings.language(LanguagePreference.en);

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
    registerTeacherDependencies(
      scope,
      cookieJar: portalSession.authClient.cookieJar,
      authClient: portalSession.authClient,
      pushNotifications: const _NoOpPushNotificationService(),
      includeBootstrap: false,
      eager: false,
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

class _TeacherTestShell extends StatefulWidget {
  const _TeacherTestShell({
    required this.harness,
    this.child,
    this.useRouter = false,
    this.initialRoute,
  });

  final TeacherWidgetTestHarness harness;
  final Widget? child;
  final bool useRouter;
  final String? initialRoute;

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
        router.router.go(widget.initialRoute ?? '/calendar');
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
    if (_error != null) {
      return TeacherWidgetTestHarness.materialApp(
        home: Scaffold(body: Center(child: Text('Bootstrap failed: $_error'))),
      );
    }
    if (!_ready) {
      return TeacherWidgetTestHarness.materialApp(
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
    return TeacherWidgetTestHarness.materialApp(home: widget.child!);
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
