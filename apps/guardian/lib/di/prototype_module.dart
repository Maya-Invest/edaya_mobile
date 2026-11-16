import 'package:edaya_auth/edaya_auth.dart';
import 'package:edaya_shared/edaya_shared.dart';
import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:levit_flutter/levit_flutter.dart';

import '../app/router.dart';
import '../features/auth/session_storage.dart';
import '../features/context/academic_year_controller.dart';
import '../features/context/child_picker.dart';
import '../features/context/student_context_controller.dart';
import '../features/push/noop_push_notification_service.dart';
import '../live/prototype_runtime.dart';
import '../mock/mock_store.dart';
import '../navigation/notification_navigation.dart';

Future<void> initializeGuardianAuthenticatedContext(LevitScope scope) async {
  await prepareGuardianContext(
    auth: scope.find<AuthClient>(),
    session: scope.find<AppSessionController>(),
    year: scope.find<AcademicYearController>(),
    student: scope.find<StudentContextController>(),
  );
}

/// Registers production API dependencies when [live] is true. Widget and
/// design-review harnesses pass a [store] and keep [live] false so feature
/// screens read mock fixtures instead of SchoolClient.
void registerPrototypeDependencies(
  LevitScope scope, {
  MockStore? store,
  bool? live,
  AuthClient? authClient,
  PushNotificationService? pushNotifications,
  bool includeBootstrap = true,
  DemoStore? demo,
}) {
  authClient ??= demo?.auth;
  final isLive = live ?? store == null;
  scope.put<PrototypeRuntime>(
    () => PrototypeRuntime(live: isLive),
    permanent: true,
  );
  scope.put<EdayaRouterRefresh>(() => EdayaRouterRefresh(), permanent: true);

  final mockStore = store;
  if (mockStore != null) {
    scope.put<MockStore>(() => mockStore, permanent: true);
    scope.put<MockGuardianContextBridge>(
      () => MockGuardianContextBridge(store: mockStore),
      permanent: true,
    );
  }

  if (isLive) {
    EdayaRootScope.bind(scope, appName: systemL10n().appTitleGuardian);
    final cookieJar = authClient?.cookieJar ?? CookieJar();
    scope.put<SessionStorage>(
      () => SessionStorage(
        prefix: demo?.prefix ?? '',
        contextKey: () =>
            '${scope.find<AppSessionController>().user.value?.id}/${scope.find<AppSessionController>().schoolIdHeader}',
      ),
      permanent: true,
    );
    scope.put<PendingInvitationStore>(
      () => PendingInvitationStore(),
      permanent: true,
    );
    if (authClient != null) {
      scope.put<CookieJar>(() => cookieJar, permanent: true);
      scope.put<AuthClient>(() => authClient!, permanent: true);
      scope.put<AppSettingsController>(
        () => AppSettingsController(prefix: demo?.prefix ?? ''),
        permanent: true,
      );
    } else {
      registerEdayaDependencies(scope, cookieJar: cookieJar);
    }
    registerSchoolClientFactory(
      scope,
      getAcademicYearId: () =>
          scope.find<AcademicYearController>().selectedYearId.value,
      getActorKind: () => 'guardian',
      getActorId: () => scope.find<AppSessionController>().actorIdHeader,
      getSchoolId: () => scope.find<AppSessionController>().schoolIdHeader,
    );
    scope.put<PushNotificationService>(
      () =>
          pushNotifications ??
          (demo != null
              ? NoOpPushNotificationService()
              : FcmPushNotificationService(
                  schoolClientFactory: scope.find<SchoolClientFactory>(),
                  config: PushNotificationConfigs.guardian,
                  onNotificationOpened: handleGuardianNotificationOpened,
                )),
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
            systemL10n().signedInNoGuardianProfile,
        resolveActorKind: () => 'guardian',
        allowUnlinkedIdentity: () => true,
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
    if (includeBootstrap) {
      scope.put<AppBootstrapController>(
        () => AppBootstrapController(
          skipAnonymousNativeRestore: authClient == null,
          authClient: scope.find<AuthClient>(),
          sessionStorage: scope.find<SessionStorage>(),
          session: scope.find<AppSessionController>(),
          pushNotifications: scope.find<PushNotificationService>(),
          beforeRestore: demo == null
              ? () => scope.find<PendingInvitationStore>().hydrate()
              : null,
          initializeAuthenticatedContext: () =>
              initializeGuardianAuthenticatedContext(scope),
        ),
        permanent: true,
      );
    }
  } else {
    scope.put<AppSettingsController>(
      () => AppSettingsController(prefix: demo?.prefix ?? ''),
      permanent: true,
    );
    scope.put<PendingInvitationStore>(
      () => PendingInvitationStore(),
      permanent: true,
    );
    scope.put<PushNotificationService>(
      () => NoOpPushNotificationService(),
      permanent: true,
    );
  }

  if (mockStore != null) {
    mockStore.addListener(() => scope.find<EdayaRouterRefresh>().refresh());
  }

  scope.put<GoRouter>(
    () => createRouter(
      demo: demo != null,
      session: isLive ? scope.find<AppSessionController>() : null,
      studentContext: isLive ? scope.find<StudentContextController>() : null,
      academicYear: isLive ? scope.find<AcademicYearController>() : null,
      pendingInvitation: scope.find<PendingInvitationStore>(),
      routerRefresh: scope.find<EdayaRouterRefresh>(),
      mockStore: isLive ? null : mockStore,
    ),
    permanent: true,
  );
  scope.put<EdayaAppRouter>(
    () => PrototypeAppRouter(scope.find<GoRouter>()),
    permanent: true,
  );
}

/// Adapts [MockStore] for shell chrome rebuilds in mock tests.
class MockGuardianContextBridge extends LevitController {
  MockGuardianContextBridge({required MockStore store}) : _store = store;

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

class PrototypeAppRouter implements EdayaAppRouter {
  PrototypeAppRouter(this._router);

  final GoRouter _router;

  @override
  RouterConfig<Object> config() => _router;
}
