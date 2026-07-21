import 'dart:async';

import 'package:edaya_auth/edaya_auth.dart';
import 'package:edaya_shared/edaya_shared.dart';
import 'package:levit_flutter/levit_flutter.dart';

import '../app/router.dart';
import '../features/auth/session_storage.dart';
import '../features/context/academic_year_controller.dart';
import '../features/context/teacher_context_controller.dart';
import '../features/evaluations/evaluations_controller.dart';
import '../features/report_cards/report_cards_controller.dart';
import '../features/teaching/teaching_controller.dart';
import '../features/offline/teacher_outbox_controller.dart';
import '../navigation/notification_navigation.dart';

/// Loads academic year, year-scoped grants, and teacher context after auth.
Future<void> initializeTeacherAuthenticatedContext() async {
  await EdayaRootScope.find<AcademicYearController>().loadYears();
  await EdayaRootScope.find<AppSessionController>().refreshGrants();
  await EdayaRootScope.find<TeacherContextController>().initializeFromSession();
  await EdayaRootScope.find<TeacherOutboxController>().refreshSummary();
}

void registerTeacherDependencies(
  LevitScope scope, {
  CookieJar? cookieJar,
  AuthClient? authClient,
  PushNotificationService? pushNotifications,
  bool includeBootstrap = true,
  bool eager = true,
}) {
  void bind<S>(S Function() factory, {bool permanent = false}) {
    if (eager) {
      scope.put<S>(factory, permanent: permanent);
    } else {
      scope.lazyPut<S>(factory, permanent: permanent);
    }
  }

  EdayaRootScope.bind(scope, appName: systemL10n().appTitleTeacher);
  final resolvedCookieJar = cookieJar ?? CookieJar();
  bind<SessionStorage>(() => SessionStorage(), permanent: true);
  bind<EdayaRouterRefresh>(() => EdayaRouterRefresh(), permanent: true);
  if (authClient != null) {
    bind<CookieJar>(() => resolvedCookieJar, permanent: true);
    bind<AuthClient>(() => authClient, permanent: true);
    bind<AppSettingsController>(() => AppSettingsController(), permanent: true);
  } else {
    registerEdayaDependencies(scope, cookieJar: resolvedCookieJar);
  }
  registerSchoolClientFactory(
    scope,
    getAcademicYearId: () =>
        scope.find<AcademicYearController>().selectedYearId.value,
    getActorKind: () => 'teacher',
    getActorId: () => scope.find<AppSessionController>().actorIdHeader,
    getSchoolId: () => scope.find<AppSessionController>().schoolIdHeader,
  );
  bind<PushNotificationService>(
    () =>
        pushNotifications ??
        FcmPushNotificationService(
          schoolClientFactory: scope.find<SchoolClientFactory>(),
          config: PushNotificationConfigs.teacher,
          onNotificationOpened: handleTeacherNotificationOpened,
        ),
    permanent: true,
  );
  bind<AppSessionController>(
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
  bind<AcademicYearController>(
    () => AcademicYearController(
      sessionStorage: scope.find<SessionStorage>(),
      session: scope.find<AppSessionController>(),
      schoolClient: scope.find<SchoolClientFactory>(),
    ),
    permanent: true,
  );
  bind<TeacherContextController>(
    () => TeacherContextController(
      sessionStorage: scope.find<SessionStorage>(),
      session: scope.find<AppSessionController>(),
      academicYear: scope.find<AcademicYearController>(),
      schoolClient: scope.find<SchoolClientFactory>(),
    ),
    permanent: true,
  );
  bind<EvaluationsController>(
    () => EvaluationsController(
      teacherContext: scope.find<TeacherContextController>(),
      academicYear: scope.find<AcademicYearController>(),
      schoolClient: scope.find<SchoolClientFactory>(),
    ),
    permanent: true,
  );
  bind<TeachingController>(
    () => TeachingController(
      teacherContext: scope.find<TeacherContextController>(),
      academicYear: scope.find<AcademicYearController>(),
      schoolClient: scope.find<SchoolClientFactory>(),
    ),
    permanent: true,
  );
  bind<TeacherOutboxStore>(
    () => openTeacherOutboxStore(),
    permanent: true,
  );
  bind<TeacherOutboxController>(
    () => TeacherOutboxController(
      outboxStore: scope.find<TeacherOutboxStore>(),
      schoolClient: scope.find<SchoolClientFactory>(),
    ),
    permanent: true,
  );
  bind<ReportCardsController>(
    () => ReportCardsController(
      teacherContext: scope.find<TeacherContextController>(),
      academicYear: scope.find<AcademicYearController>(),
      evaluations: scope.find<EvaluationsController>(),
      schoolClient: scope.find<SchoolClientFactory>(),
    ),
    permanent: true,
  );
  bind<AppRouter>(
    () => AppRouter(
      session: scope.find<AppSessionController>(),
      routerRefresh: scope.find<EdayaRouterRefresh>(),
    ),
    permanent: true,
  );
  bind<EdayaAppRouter>(() => scope.find<AppRouter>(), permanent: true);
  if (includeBootstrap) {
    bind<AppBootstrapController>(
      () => AppBootstrapController(
        cookieJar: scope.find<CookieJar>(),
        sessionStorage: scope.find<SessionStorage>(),
        session: scope.find<AppSessionController>(),
        pushNotifications: scope.find<PushNotificationService>(),
        initializeAuthenticatedContext: initializeTeacherAuthenticatedContext,
      ),
      permanent: true,
    );
  }
}
