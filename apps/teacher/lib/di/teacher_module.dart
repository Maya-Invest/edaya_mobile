import 'package:edaya_auth/edaya_auth.dart';
import 'package:edaya_shared/edaya_shared.dart';
import 'package:levit_flutter/levit_flutter.dart';

import '../app/router.dart';
import '../features/auth/session_storage.dart';
import '../features/context/academic_year_controller.dart';
import '../features/context/staff_context_controller.dart';
import '../navigation/notification_navigation.dart';

void registerTeacherDependencies(LevitScope scope) {
  EdayaRootScope.bind(scope, appName: systemL10n().appTitleTeacher);
  final cookieJar = CookieJar();
  scope.put<CookieJar>(() => cookieJar, permanent: true);
  scope.put<SessionStorage>(() => SessionStorage(), permanent: true);
  scope.put<EdayaRouterRefresh>(
    () => EdayaRouterRefresh(),
    permanent: true,
  );
  registerEdayaDependencies(scope, cookieJar: cookieJar);
  registerSchoolClientFactory(
    scope,
    getAcademicYearId: () =>
        scope.find<AcademicYearController>().selectedYearId.value,
  );
  scope.put<PushNotificationService>(
    () => FcmPushNotificationService(
      schoolClientFactory: scope.find<SchoolClientFactory>(),
      config: PushNotificationConfigs.teacher,
      onNotificationOpened: handleTeacherNotificationOpened,
    ),
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
          return systemL10n().accountNotLinkedToStaff;
        }
        return null;
      },
      unauthorizedProfileMessage: () => systemL10n().signedInNoStaffProfile,
      resolveAcademicYearId: () async {
        final academicYear = scope.find<AcademicYearController>();
        final selected = academicYear.selectedYearId.value;
        if (selected != null && selected.isNotEmpty) {
          return selected;
        }
        return scope.find<SessionStorage>().readAcademicYearId();
      },
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
  scope.put<StaffContextController>(
    () => StaffContextController(
      sessionStorage: scope.find<SessionStorage>(),
      session: scope.find<AppSessionController>(),
      academicYear: scope.find<AcademicYearController>(),
      schoolClient: scope.find<SchoolClientFactory>(),
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
        await scope.find<AppSessionController>().refreshGrants();
        await scope.find<StaffContextController>().initializeFromSession();
      },
    ),
    permanent: true,
  );
}
