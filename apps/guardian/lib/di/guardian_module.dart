import 'package:edaya_auth/edaya_auth.dart';
import 'package:levit_flutter/levit_flutter.dart';

import '../access/school_client.dart';
import '../access/root_scope.dart';
import '../app/router.dart';
import '../app/router_refresh.dart';
import '../features/auth/app_bootstrap_controller.dart';
import '../features/auth/app_session_controller.dart';
import '../features/auth/session_storage.dart';
import '../features/context/academic_year_controller.dart';
import '../features/context/student_context_controller.dart';
import '../services/push_notification_service.dart';
import 'edaya_module.dart';

void registerGuardianDependencies(LevitScope scope) {
  GuardianRootScope.bind(scope);
  final cookieJar = CookieJar();
  scope.put<CookieJar>(() => cookieJar, permanent: true);
  scope.put<SessionStorage>(() => SessionStorage(), permanent: true);
  scope.put<GuardianRouterRefresh>(
    () => GuardianRouterRefresh(),
    permanent: true,
  );
  registerEdayaDependencies(scope, cookieJar: cookieJar);
  scope.put<PushNotificationService>(
    () => PushNotificationService(
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
      routerRefresh: scope.find<GuardianRouterRefresh>(),
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
      routerRefresh: scope.find<GuardianRouterRefresh>(),
    ),
    permanent: true,
  );
  scope.put<AppBootstrapController>(
    () => AppBootstrapController(
      cookieJar: scope.find<CookieJar>(),
      sessionStorage: scope.find<SessionStorage>(),
      session: scope.find<AppSessionController>(),
      pushNotifications: scope.find<PushNotificationService>(),
      academicYear: scope.find<AcademicYearController>(),
      studentContext: scope.find<StudentContextController>(),
    ),
    permanent: true,
  );
}
