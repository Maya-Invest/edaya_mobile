import 'package:edaya_auth/edaya_auth.dart';
import 'package:edaya_shared/edaya_shared.dart';
import 'package:go_router/go_router.dart';
import 'package:levit_flutter/levit_flutter.dart';

import '../features/auth/session_storage.dart';
import '../features/calendar/live_calendar_controller.dart';
import '../features/context/academic_year_controller.dart';
import '../features/context/teacher_context_controller.dart';
import '../features/evaluations/family_feedback_controller.dart';
import '../features/evaluations/live_evaluations_controller.dart';
import '../features/home/home_controller.dart';
import '../live/noop_push.dart';
import '../live/prototype_runtime.dart';
import '../mock/mock_store.dart';
import '../app/router.dart';

Future<void> initializeTeacherAuthenticatedContext(LevitScope scope) async {
  await scope.find<AcademicYearController>().loadYears();
  await scope.find<AppSessionController>().refreshGrants();
  await scope.find<TeacherContextController>().initializeFromSession();
}

void registerPrototypeDependencies(
  LevitScope scope, {
  required MockStore store,
  bool live = false,
}) {
  scope.put<PrototypeRuntime>(
    () => PrototypeRuntime(live: live),
    permanent: true,
  );
  scope.put<MockStore>(() => store, permanent: true);
  scope.put<EdayaRouterRefresh>(() => EdayaRouterRefresh(), permanent: true);
  scope.put<MockTeacherContextBridge>(
    () => MockTeacherContextBridge(store: store),
    permanent: true,
  );

  if (live) {
    EdayaRootScope.bind(scope, appName: systemL10n().appTitleTeacher);
    final cookieJar = CookieJar();
    registerEdayaDependencies(scope, cookieJar: cookieJar);
    scope.put<SessionStorage>(() => SessionStorage(), permanent: true);
    scope.put<PushNotificationService>(
      () => NoOpPushNotificationService(),
      permanent: true,
    );
    registerSchoolClientFactory(
      scope,
      getAcademicYearId: () =>
          scope.find<AcademicYearController>().selectedYearId.value,
      getActorKind: () => 'teacher',
      getActorId: () => scope.find<AppSessionController>().actorIdHeader,
      getSchoolId: () => scope.find<AppSessionController>().schoolIdHeader,
    );
    scope.put<AppSessionController>(
      () => AppSessionController(
        authClient: scope.find<AuthClient>(),
        sessionStorage: scope.find<SessionStorage>(),
        pushNotifications: scope.find<PushNotificationService>(),
        routerRefresh: scope.find<EdayaRouterRefresh>(),
        validateGrants: (grants) {
          if (grants.kind != 'teacher') {
            return systemL10n().accountNotLinkedToTeacher;
          }
          return null;
        },
        unauthorizedProfileMessage: () => systemL10n().signedInNoTeacherProfile,
        resolveAcademicYearId: () async {
          final academicYear = scope.find<AcademicYearController>();
          final selected = academicYear.selectedYearId.value;
          if (selected != null && selected.isNotEmpty) {
            return selected;
          }
          return scope.find<SessionStorage>().readAcademicYearId();
        },
        resolveActorKind: () => 'teacher',
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
    scope.put<TeacherContextController>(
      () => TeacherContextController(
        sessionStorage: scope.find<SessionStorage>(),
        session: scope.find<AppSessionController>(),
        academicYear: scope.find<AcademicYearController>(),
        schoolClient: scope.find<SchoolClientFactory>(),
      ),
      permanent: true,
    );
    scope.put<LiveCalendarController>(
      () => LiveCalendarController(
        teacherContext: scope.find<TeacherContextController>(),
        academicYear: scope.find<AcademicYearController>(),
        schoolClient: scope.find<SchoolClientFactory>(),
      ),
      permanent: true,
    );
    scope.put<LiveEvaluationsController>(
      () => LiveEvaluationsController(
        teacherContext: scope.find<TeacherContextController>(),
        academicYear: scope.find<AcademicYearController>(),
        schoolClient: scope.find<SchoolClientFactory>(),
      ),
      permanent: true,
    );
    scope.put<LiveFamilyFeedbackController>(
      () => LiveFamilyFeedbackController(
        session: scope.find<AppSessionController>(),
        schoolClient: scope.find<SchoolClientFactory>(),
      ),
      permanent: true,
    );
    scope.put<LiveHomeController>(
      () => LiveHomeController(
        calendar: scope.find<LiveCalendarController>(),
        evaluations: scope.find<LiveEvaluationsController>(),
        familyFeedback: scope.find<LiveFamilyFeedbackController>(),
      ),
      permanent: true,
    );
    scope.put<AppBootstrapController>(
      () => AppBootstrapController(
        authClient: scope.find<AuthClient>(),
        sessionStorage: scope.find<SessionStorage>(),
        session: scope.find<AppSessionController>(),
        pushNotifications: scope.find<PushNotificationService>(),
        initializeAuthenticatedContext: () =>
            initializeTeacherAuthenticatedContext(scope),
      ),
      permanent: true,
    );
    scope.find<AppBootstrapController>().isReady.stream.listen((ready) {
      if (ready) {
        scope.find<EdayaRouterRefresh>().refresh();
      }
    });
    store.addListener(() => scope.find<EdayaRouterRefresh>().refresh());
  } else {
    store.addListener(() => scope.find<EdayaRouterRefresh>().refresh());
  }

  scope.put<GoRouter>(
    () => createRouter(
      routerRefresh: scope.find<EdayaRouterRefresh>(),
      isAuthenticated: () {
        if (live) {
          return scope.find<AppSessionController>().isAuthenticated;
        }
        return store.isAuthenticated;
      },
      isBootstrapping: () {
        if (!live) {
          return false;
        }
        return !scope.find<AppBootstrapController>().isReady.value;
      },
    ),
    permanent: true,
  );
}

/// Adapts [MockStore] for shell chrome rebuilds in mock tests.
class MockTeacherContextBridge extends LevitController {
  MockTeacherContextBridge({required MockStore store}) : _store = store;

  final MockStore _store;
  final storeTick = LxVar(0);

  MockStore get store => _store;

  @override
  void onInit() {
    super.onInit();
    autoDispose(storeTick);
    _store.addListener(() => storeTick.value++);
  }
}
