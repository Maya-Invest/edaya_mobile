import '../navigation/record_access_transport.dart';
import 'package:edaya_auth/edaya_auth.dart';
import 'package:edaya_shared/edaya_shared.dart';
import 'package:go_router/go_router.dart';
import 'package:levit_flutter/levit_flutter.dart';

import '../features/auth/session_storage.dart';
import '../features/calendar/live_calendar_controller.dart';
import '../features/context/academic_year_controller.dart';
import '../features/context/teacher_context_controller.dart';
import '../features/context/teacher_workspace_catalog.dart';
import '../features/evaluations/family_feedback_controller.dart';
import '../features/evaluations/live_evaluations_controller.dart';
import '../features/inbox/live_inbox_controller.dart';
import '../features/report_cards/live_report_cards_controller.dart';
import '../features/home/home_controller.dart';
import '../features/offline/teacher_outbox_controller.dart';
import '../live/prototype_runtime.dart';
import '../mock/mock_store.dart';
import '../navigation/notification_navigation.dart';
import '../app/router.dart';

Future<void> initializeTeacherAuthenticatedContext(
  LevitScope scope, {
  bool findEligibleSchool = true,
}) async {
  // Resolve dependencies before awaiting: the initiating route can be disposed.
  final session = scope.find<AppSessionController>();
  if (!session.hasSchoolSession) return;
  final year = scope.find<AcademicYearController>();
  final teacher = scope.find<TeacherContextController>();
  final outbox = scope.find<TeacherOutboxController>();
  final inbox = scope.find<LiveInboxController>();
  await year.loadYears();
  if (session.isClosed) return;
  await session.refreshGrants();
  if (session.isClosed) return;
  await teacher.initializeFromSession();
  if (session.isClosed) return;
  if (findEligibleSchool &&
      teacher.assignments.value.isEmpty &&
      session.availableProfiles.value.length > 1) {
    final catalog = await loadTeacherSchoolChoices(
      scope.find<AuthClient>(),
      session.availableProfiles.value,
    );
    if (session.isClosed) return;
    final eligible = catalog
        .where(
          (school) =>
              school.options.isNotEmpty &&
              school.profile.schoolId != session.schoolIdHeader,
        )
        .firstOrNull;
    if (eligible != null) {
      year.clearSelection();
      final failure = await session.selectProfile(eligible.profile);
      if (failure == null) {
        await initializeTeacherAuthenticatedContext(
          scope,
          findEligibleSchool: false,
        );
        return;
      }
    }
  }
  await outbox.refreshSummary();
  if (session.isClosed) return;
  await inbox.loadInbox();
}

void registerPrototypeDependencies(
  LevitScope scope, {
  required MockStore store,
  bool live = false,
  CookieJar? cookieJar,
  AuthClient? authClient,
  PushNotificationService? pushNotifications,
  bool includeBootstrap = true,
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
    final resolvedCookieJar = cookieJar ?? CookieJar();
    if (authClient != null) {
      scope.put<CookieJar>(() => resolvedCookieJar, permanent: true);
      scope.put<AuthClient>(() => authClient, permanent: true);
      scope.put<AppSettingsController>(
        () => AppSettingsController(),
        permanent: true,
      );
    } else {
      registerEdayaDependencies(
        scope,
        cookieJar: resolvedCookieJar,
        enableTestOtpInDebug: true,
      );
    }
    scope.put<SessionStorage>(() => SessionStorage(), permanent: true);
    registerSchoolClientFactory(
      scope,
      getAcademicYearId: () =>
          scope.find<AcademicYearController>().selectedYearId.value,
      getActorKind: () => 'teacher',
      decorateTransport: (transport) => RecordAccessTransport(
        transport,
        location: () =>
            scope.find<GoRouter>().routeInformationProvider.value.uri,
        onUnavailable: (owner) =>
            scope.find<GoRouter>().go('$owner?notice=access'),
      ),
      getActorId: () => scope.find<AppSessionController>().actorIdHeader,
      getSchoolId: () => scope.find<AppSessionController>().schoolIdHeader,
    );
    scope.put<PushNotificationService>(
      () =>
          pushNotifications ??
          FcmPushNotificationService(
            schoolClientFactory: scope.find<SchoolClientFactory>(),
            config: PushNotificationConfigs.teacher,
            onNotificationOpened: handleTeacherNotificationOpened,
          ),
      permanent: true,
    );
    scope.put<AppSessionController>(
      () => AppSessionController(
        selectFirstProfile: true,
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
          if (!scope.find<AppSessionController>().hasSchoolSession) return null;
          final academicYear = scope.find<AcademicYearController>();
          final selected = academicYear.selectedYearId.value;
          if (selected != null && selected.isNotEmpty) {
            return selected;
          }
          return null;
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
    scope.put<LiveReportCardsController>(
      () => LiveReportCardsController(
        teacherContext: scope.find<TeacherContextController>(),
        academicYear: scope.find<AcademicYearController>(),
        evaluations: scope.find<LiveEvaluationsController>(),
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
    scope.put<LiveInboxController>(
      () => LiveInboxController(
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
        reportCards: scope.find<LiveReportCardsController>(),
        inbox: scope.find<LiveInboxController>(),
      ),
      permanent: true,
    );
    scope.put<TeacherOutboxStore>(
      () => openTeacherOutboxStore(),
      permanent: true,
    );
    scope.put<TeacherOutboxController>(
      () => TeacherOutboxController(
        outboxStore: scope.find<TeacherOutboxStore>(),
        schoolClient: scope.find<SchoolClientFactory>(),
        context: () => teacherOutboxContextForSession(
          session: scope.find<AppSessionController>(),
          academicYearId: scope
              .find<AcademicYearController>()
              .selectedYearId
              .value,
        ),
      ),
      permanent: true,
    );
    if (includeBootstrap) {
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
    }
    store.addListener(() => scope.find<EdayaRouterRefresh>().refresh());
  } else {
    scope.put<AppSettingsController>(
      () => AppSettingsController(),
      permanent: true,
    );
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
        if (!live || !includeBootstrap) {
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
