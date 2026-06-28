import 'package:edaya_auth/edaya_auth.dart';
import 'package:edaya_shared/edaya_shared.dart';
import 'package:levit_flutter/levit_flutter.dart';

import '../app/router.dart';
import '../features/auth/session_storage.dart';
import '../features/calendar/calendar_controller.dart';
import '../features/context/academic_year_controller.dart';
import '../features/context/staff_context_controller.dart';
import '../features/evaluations/evaluations_controller.dart';
import '../services/push_notification_service.dart';

void registerTeacherDependencies(LevitScope scope) {
  EdayaRootScope.bind(scope, appName: 'Teacher');
  final cookieJar = CookieJar();
  scope.put<CookieJar>(() => cookieJar, permanent: true);
  scope.put<SessionStorage>(() => SessionStorage(), permanent: true);
  scope.put<EdayaRouterRefresh>(
    () => EdayaRouterRefresh(),
    permanent: true,
  );
  registerEdayaDependencies(scope, cookieJar: cookieJar);
  scope.put<PushNotificationService>(
    () => TeacherPushNotificationService(),
    permanent: true,
  );
  scope.put<AppSessionController>(
    () => AppSessionController(
      authClient: scope.find<AuthClient>(),
      sessionStorage: scope.find<SessionStorage>(),
      pushNotifications: scope.find<PushNotificationService>(),
      routerRefresh: scope.find<EdayaRouterRefresh>(),
      validateGrants: (grants) {
        if (grants.kind != 'staff') {
          return 'This account is not linked to a staff profile.';
        }
        return null;
      },
      unauthorizedProfileMessage: () =>
          'Signed in, but no linked staff profile. Run: bun run seed:auth:link',
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
        await scope.find<StaffContextController>().initializeFromSession();
      },
    ),
    permanent: true,
  );
}
