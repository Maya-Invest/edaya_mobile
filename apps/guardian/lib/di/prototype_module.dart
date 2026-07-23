import 'package:edaya_auth/edaya_auth.dart';
import 'package:edaya_shared/edaya_shared.dart';
import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:levit_flutter/levit_flutter.dart';

import '../app/router.dart';
import '../features/auth/session_storage.dart';
import '../features/context/academic_year_controller.dart';
import '../features/context/student_context_controller.dart';
import '../mock/mock_store.dart';
import '../navigation/notification_navigation.dart';

/// Registers API dependencies. Optional [store] enables mock auth redirects for
/// widget / design-review harnesses (feature screens still use SchoolClient).
void registerPrototypeDependencies(LevitScope scope, {MockStore? store}) {
  EdayaRootScope.bind(scope, appName: systemL10n().appTitleGuardian);
  final cookieJar = CookieJar();

  if (store != null) {
    scope.put<MockStore>(() => store, permanent: true);
  }

  scope.put<SessionStorage>(() => SessionStorage(), permanent: true);
  scope.put<EdayaRouterRefresh>(() => EdayaRouterRefresh(), permanent: true);
  registerEdayaDependencies(scope, cookieJar: cookieJar);
  registerSchoolClientFactory(
    scope,
    getAcademicYearId: () =>
        scope.find<AcademicYearController>().selectedYearId.value,
    getActorKind: () => 'guardian',
    getActorId: () => scope.find<AppSessionController>().actorIdHeader,
    getSchoolId: () => scope.find<AppSessionController>().schoolIdHeader,
  );
  scope.put<PushNotificationService>(
    () => FcmPushNotificationService(
      schoolClientFactory: scope.find<SchoolClientFactory>(),
      config: PushNotificationConfigs.guardian,
      onNotificationOpened: handleGuardianNotificationOpened,
    ),
    permanent: true,
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
  scope.put<GoRouter>(
    () => createRouter(
      session: scope.find<AppSessionController>(),
      routerRefresh: scope.find<EdayaRouterRefresh>(),
      mockStore: store,
    ),
    permanent: true,
  );
  scope.put<EdayaAppRouter>(
    () => PrototypeAppRouter(scope.find<GoRouter>()),
    permanent: true,
  );
  scope.put<AppBootstrapController>(
    () => AppBootstrapController(
      cookieJar: scope.find<CookieJar>(),
      sessionStorage: scope.find<SessionStorage>(),
      session: scope.find<AppSessionController>(),
      pushNotifications: scope.find<PushNotificationService>(),
      initializeAuthenticatedContext: () async {
        await scope.find<AcademicYearController>().loadYears();
        await scope.find<StudentContextController>().initializeFromSession();
      },
    ),
    permanent: true,
  );

  if (store != null) {
    store.addListener(() => scope.find<EdayaRouterRefresh>().refresh());
  }
}

class PrototypeAppRouter implements EdayaAppRouter {
  PrototypeAppRouter(this._router);

  final GoRouter _router;

  @override
  RouterConfig<Object> config() => _router;
}
