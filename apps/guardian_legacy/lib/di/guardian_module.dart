import 'package:edaya_auth/edaya_auth.dart';
import 'package:edaya_shared/edaya_shared.dart';
import 'package:levit_flutter/levit_flutter.dart';

import '../app/router.dart';
import '../features/auth/session_storage.dart';
import '../features/context/academic_year_controller.dart';
import '../features/context/student_context_controller.dart';
import '../navigation/notification_navigation.dart';

void registerGuardianDependencies(LevitScope scope) {
  EdayaRootScope.bind(scope, appName: systemL10n().appTitleGuardian);
  final cookieJar = CookieJar();
  scope.put<SessionStorage>(() => SessionStorage(), permanent: true);
  scope.put<EdayaRouterRefresh>(() => EdayaRouterRefresh(), permanent: true);
  registerEdayaDependencies(scope, cookieJar: cookieJar);
  scope.put<PendingInvitationStore>(
    () => PendingInvitationStore(),
    permanent: true,
  );
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
      allowUnlinkedIdentity: () => true,
      onSignOut: () => scope.find<PendingInvitationStore>().clear(),
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
  scope.put<AppRouter>(
    () => AppRouter(
      session: scope.find<AppSessionController>(),
      academicYear: scope.find<AcademicYearController>(),
      studentContext: scope.find<StudentContextController>(),
      routerRefresh: scope.find<EdayaRouterRefresh>(),
      pendingInvitation: scope.find<PendingInvitationStore>(),
    ),
    permanent: true,
  );
  scope.put<EdayaAppRouter>(() => scope.find<AppRouter>(), permanent: true);
  scope.put<AppBootstrapController>(
    () => AppBootstrapController(
      authClient: scope.find<AuthClient>(),
      sessionStorage: scope.find<SessionStorage>(),
      session: scope.find<AppSessionController>(),
      pushNotifications: scope.find<PushNotificationService>(),
      beforeRestore: () => scope.find<PendingInvitationStore>().hydrate(),
      initializeAuthenticatedContext: () =>
          scope.find<AppRouter>().hydrateSessionContext(),
    ),
    permanent: true,
  );
}
