import 'package:edaya_auth/edaya_auth.dart';
import 'package:edaya_shared/edaya_shared.dart';
import 'package:levit_flutter/levit_flutter.dart';

import '../app/router.dart';
import '../features/auth/session_storage.dart';
import '../features/context/academic_year_controller.dart';
import '../features/context/student_context_controller.dart';
import '../services/push_notification_service.dart';

void registerGuardianDependencies(LevitScope scope) {
  EdayaRootScope.bind(scope, appName: 'Guardian');
  final cookieJar = CookieJar();
  scope.put<CookieJar>(() => cookieJar, permanent: true);
  scope.put<SessionStorage>(() => SessionStorage(), permanent: true);
  scope.put<EdayaRouterRefresh>(
    () => EdayaRouterRefresh(),
    permanent: true,
  );
  registerEdayaDependencies(scope, cookieJar: cookieJar);
  scope.put<PushNotificationService>(
    () => GuardianPushNotificationService(
      schoolClientFactory: () =>
          createEdayaSchoolClient(scope.find<AuthClient>()),
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
      unauthorizedProfileMessage: () =>
          'Signed in, but no linked guardian/staff profile. Run: bun run seed:auth:link',
    ),
    permanent: true,
  );
  scope.put<AcademicYearController>(
    () => AcademicYearController(
      sessionStorage: scope.find<SessionStorage>(),
      session: scope.find<AppSessionController>(),
    ),
    permanent: true,
  );
  scope.put<StudentContextController>(
    () => StudentContextController(
      sessionStorage: scope.find<SessionStorage>(),
      session: scope.find<AppSessionController>(),
      academicYear: scope.find<AcademicYearController>(),
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
  scope.put<EdayaAppRouter>(
    () => scope.find<AppRouter>(),
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
}
