import 'package:edaya_auth/edaya_auth.dart';
import 'package:levit_flutter/levit_flutter.dart';

import '../access/root_scope.dart';
import '../app/router.dart';
import '../app/router_refresh.dart';
import '../features/auth/app_bootstrap_controller.dart';
import '../features/auth/app_session_controller.dart';
import '../features/auth/session_storage.dart';
import '../features/calendar/calendar_controller.dart';
import '../features/context/academic_year_controller.dart';
import '../features/context/staff_context_controller.dart';
import '../features/evaluations/evaluations_controller.dart';
import '../services/push_notification_service.dart';
import 'edaya_module.dart';

void registerTeacherDependencies(LevitScope scope) {
  TeacherRootScope.bind(scope);
  final cookieJar = CookieJar();
  scope.put<CookieJar>(() => cookieJar, permanent: true);
  scope.put<SessionStorage>(() => SessionStorage(), permanent: true);
  scope.put<TeacherRouterRefresh>(
    () => TeacherRouterRefresh(),
    permanent: true,
  );
  registerEdayaDependencies(scope, cookieJar: cookieJar);
  scope.put<PushNotificationService>(
    () => PushNotificationService(),
    permanent: true,
  );
  scope.put<AppSessionController>(
    () => AppSessionController(
      authClient: scope.find<AuthClient>(),
      sessionStorage: scope.find<SessionStorage>(),
      pushNotifications: scope.find<PushNotificationService>(),
      routerRefresh: scope.find<TeacherRouterRefresh>(),
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
  scope.put<StaffContextController>(
    () => StaffContextController(
      sessionStorage: scope.find<SessionStorage>(),
      session: scope.find<AppSessionController>(),
      academicYear: scope.find<AcademicYearController>(),
    ),
    permanent: true,
  );
  scope.put<CalendarController>(
    () => CalendarController(
      staffContext: scope.find<StaffContextController>(),
      academicYear: scope.find<AcademicYearController>(),
    ),
    permanent: true,
  );
  scope.put<EvaluationsController>(
    () => EvaluationsController(
      staffContext: scope.find<StaffContextController>(),
      academicYear: scope.find<AcademicYearController>(),
    ),
    permanent: true,
  );
  scope.put<AppRouter>(
    () => AppRouter(
      session: scope.find<AppSessionController>(),
      routerRefresh: scope.find<TeacherRouterRefresh>(),
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
      staffContext: scope.find<StaffContextController>(),
    ),
    permanent: true,
  );
}
