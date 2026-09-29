import 'package:edaya_api_client/edaya_api_client.dart';
import 'package:edaya_auth/edaya_auth.dart';
import 'package:edaya_integration_tests/edaya_integration_tests.dart';
import 'package:edaya_shared/edaya_shared.dart';
import 'package:edaya_shared/src/features/settings/app_settings_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:go_router/go_router.dart';
import 'package:levit_flutter/levit_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:edaya_teacher/design/theme.dart';
import 'package:edaya_teacher/di/prototype_module.dart';
import 'package:edaya_teacher/features/auth/session_storage.dart';
import 'package:edaya_teacher/features/context/academic_year_controller.dart';
import 'package:edaya_teacher/features/context/teacher_context_controller.dart';
import 'package:edaya_teacher/live/noop_push.dart';
import 'package:edaya_teacher/mock/mock_store.dart';

/// Wires Accueil teacher controllers to a live [PortalSession] for widget tests.
class TeacherLiveWidgetTestHarness {
  TeacherLiveWidgetTestHarness._({
    required this.portalSession,
    required this.profile,
    required this.context,
    required this.authUserId,
    required this.teacherDisplayName,
    required this.language,
  });

  final PortalSession portalSession;
  final TeacherPortalProfile profile;
  final TeacherPortalContext context;
  final String authUserId;
  final String teacherDisplayName;
  final LanguagePreference language;

  Size? viewportSize;
  LevitScope? _scope;

  LevitScope get scope {
    final resolved = _scope;
    if (resolved == null) {
      throw StateError(
        'Teacher live harness: pump buildRouterApp() before using scope',
      );
    }
    return resolved;
  }

  static Future<TeacherLiveWidgetTestHarness> create({
    TeacherPortalProfile profile = TeacherPortalProfile.subjectTeacher,
    LanguagePreference language = LanguagePreference.fr,
    PortalSession? authenticatedSession,
  }) async {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});

    final baseConfig = IntegrationConfig.fromEnvironment();
    final config = baseConfig.withTeacherEmail(profile.email);

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

    return TeacherLiveWidgetTestHarness._(
      portalSession: portalSession,
      profile: profile,
      context: portalContext,
      authUserId: authUserId,
      teacherDisplayName: fullName.isEmpty ? profile.email : fullName,
      language: language,
    );
  }

  Widget buildRouterApp({String? initialRoute}) {
    return LScope(
      name: 'teacher-live-integration-${identityHashCode(this)}',
      dependencyFactory: (scope) {
        _scope = scope;
        registerPrototypeDependencies(
          scope,
          store: MockStore(),
          live: true,
          cookieJar: portalSession.authClient.cookieJar,
          authClient: portalSession.authClient,
          pushNotifications: NoOpPushNotificationService(),
          includeBootstrap: false,
        );
      },
      child: _LiveTestShell(harness: this, initialRoute: initialRoute),
    );
  }

  Future<void> bootstrapScope() async {
    final scope = _scope;
    if (scope == null) {
      throw StateError(
        'Teacher live harness: pump buildRouterApp() before bootstrapScope()',
      );
    }

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

    academicYear.years(context.academicYears);
    academicYear.selectedYearId(profile.academicYearId);

    await teacherContext.initializeFromSession();
    final primary = teacherContext.assignments.value
        .where(
          (assignment) =>
              assignment.classGroupId == profile.primaryClassGroupId &&
              assignment.classSubjectId ==
                  profile.expectedClassSubjectIds.first,
        )
        .firstOrNull;
    if (primary != null) await teacherContext.selectAssignment(primary.id);
    if (teacherContext.errorMessage.value.isNotEmpty ||
        teacherContext.assignments.value.isEmpty) {
      throw StateError(
        'Teacher fixture bootstrap failed: '
        '${teacherContext.errorMessage.value}; no usable assignments',
      );
    }
  }

  Locale get appLocale => language.locale ?? const Locale('fr');

  Widget designReviewRoot({required Widget child}) {
    final framed = viewportSize == null
        ? child
        : SizedBox(
            width: viewportSize!.width,
            height: viewportSize!.height,
            child: child,
          );
    return RepaintBoundary(key: const Key('teacher_live_root'), child: framed);
  }
}

class _LiveTestShell extends StatefulWidget {
  const _LiveTestShell({required this.harness, this.initialRoute});

  final TeacherLiveWidgetTestHarness harness;
  final String? initialRoute;

  @override
  State<_LiveTestShell> createState() => _LiveTestShellState();
}

class _LiveTestShellState extends State<_LiveTestShell> {
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
      final router = widget.harness._scope!.find<GoRouter>();
      router.go(widget.initialRoute ?? '/home');
      widget.harness._scope!.find<EdayaRouterRefresh>().refresh();
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
        child: MaterialApp(
          locale: locale,
          home: Scaffold(
            body: Center(child: Text('Bootstrap failed: $_error')),
          ),
        ),
      );
    }
    if (!_ready) {
      return widget.harness.designReviewRoot(
        child: MaterialApp(
          locale: locale,
          home: const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          ),
        ),
      );
    }
    final router = widget.harness._scope!.find<GoRouter>();
    return widget.harness.designReviewRoot(
      child: MaterialApp.router(
        debugShowCheckedModeBanner: false,
        theme: PrototypeTheme.light,
        darkTheme: PrototypeTheme.dark,
        themeMode: ThemeMode.light,
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
}
