import 'package:edaya_auth/edaya_auth.dart';
import 'package:edaya_shared/edaya_shared.dart' hide LoginPage;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:levit_flutter/levit_flutter.dart';

import '../config/api_config.dart';
import '../features/account/account_page.dart';
import '../features/account/account_profile_page.dart' as proto;
import '../features/account/settings_page.dart' as proto;
import '../features/calendar/attendance_page.dart';
import '../features/calendar/session_detail_page.dart';
import '../features/child_profile/child_profile_page.dart';
import '../features/context/academic_year_controller.dart';
import '../features/context/student_context_controller.dart';
import '../features/family_feedback/family_feedback_page.dart';
import '../features/fees/fee_detail_page.dart';
import '../features/fees/payment_detail_page.dart';
import '../features/inbox/inbox_routes.dart';
import '../features/inbox/message_detail_page.dart';
import '../features/inbox/models/inbox_delivery.dart';
import '../features/invite/invitation_page.dart';
import '../features/login/login_page.dart';
import '../features/scolarite/legacy_result_link.dart';
import '../features/scolarite/progress_page.dart';
import '../features/scolarite/subject_grades_page.dart';
import '../features/scolarite/subject_logbook_page.dart';
import '../features/waiting/waiting_for_students_page.dart';
import '../mock/mock_store.dart';
import 'workspace_shell.dart';
import '../features/context/child_picker.dart';
import '../features/context/archive_workspace.dart';
import '../features/context/child_workspace.dart';
import 'guardian_words.dart';
import '../features/home/home_page.dart';
import '../features/calendar/calendar_page.dart';
import '../features/fees/fees_page.dart';
import '../features/inbox/inbox_page.dart';
import '../features/scolarite/results_page.dart';

GoRouter createRouter({
  required Listenable routerRefresh,
  AppSessionController? session,
  StudentContextController? studentContext,
  AcademicYearController? academicYear,
  PendingInvitationStore? pendingInvitation,
  MockStore? mockStore,
}) {
  Future<void> completePostAuthNavigation([BuildContext? context]) async {
    final liveSession = session;
    final liveStudentContext = studentContext;
    final liveAcademicYear = academicYear;
    if (liveSession == null ||
        liveStudentContext == null ||
        liveAcademicYear == null) {
      if (context != null && context.mounted) {
        context.go(guardianHomeRoute);
      }
      return;
    }
    if (context != null) {
      await prepareGuardianContext(
        auth: context.levit.find<AuthClient>(),
        session: liveSession,
        year: liveAcademicYear,
        student: liveStudentContext,
      );
    } else {
      await liveAcademicYear.loadYears();
      await liveStudentContext.initializeFromSession();
    }
    if (context != null && context.mounted) {
      final next = resolveGuardianPostAuthHome(
        hasSchoolSession: liveSession.hasSchoolSession,
        hasLinkedStudents: liveStudentContext.hasLinkedStudents,
      );
      context.go(next);
    }
  }

  return GoRouter(
    initialLocation: guardianLoginRoute,
    refreshListenable: routerRefresh,
    redirect: (context, state) {
      if (mockStore != null) {
        final loggedIn = mockStore.isAuthenticated;
        final onLogin = state.matchedLocation == guardianLoginRoute;
        if (!loggedIn && !onLogin) return guardianLoginRoute;
        if (loggedIn && onLogin) return guardianHomeRoute;
        return null;
      }

      final liveSession = session;
      final liveStudentContext = studentContext;
      final livePending = pendingInvitation;
      if (liveSession == null ||
          liveStudentContext == null ||
          livePending == null) {
        return guardianLoginRoute;
      }

      final incoming = parseInvitationDeepLink(state.uri);
      if (incoming != null) {
        livePending.remember(incoming.token);
      } else {
        final routeToken = state.pathParameters['token'];
        if (routeToken != null && routeToken.trim().isNotEmpty) {
          livePending.remember(routeToken);
        }
      }

      if (liveSession.isAuthenticated && state.matchedLocation == '/children') {
        return null;
      }
      if (liveSession.isAuthenticated &&
          liveSession.needsProfileSelection &&
          incoming == null &&
          livePending.token == null) {
        return '/children';
      }
      return resolveGuardianAuthRedirect(
        isAuthenticated: liveSession.isAuthenticated,
        matchedLocation: state.matchedLocation,
        pendingInvitationToken: livePending.token,
        hasSchoolSession: liveSession.hasSchoolSession,
        linkedStudentsResolved: liveStudentContext.linkedStudentsResolved.value,
        hasLinkedStudents: liveStudentContext.hasLinkedStudents,
        needsProfileSelection: false,
      );
    },
    routes: [
      guardianRoute(
        path: guardianLoginRoute,
        builder: (context, state) {
          return LoginPage(
            mockStore: mockStore,
            defaultEmail: kDebugMode ? ApiConfig.devGuardianEmail : '',
            onSignInSuccess: () async {
              final pending = pendingInvitation?.token;
              if (pending != null) {
                if (context.mounted) {
                  context.go(invitationRoutePath(pending));
                }
                return;
              }
              await completePostAuthNavigation(context);
            },
          );
        },
      ),
      guardianRoute(path: '/profiles', redirect: (_, _) => '/children'),
      guardianRoute(
        path: '/invite/:token',
        builder: (context, state) => InvitationPage(
          token: state.pathParameters['token'] ?? '',
          onAccepted: () => completePostAuthNavigation(context),
          onContinueToLogin: () async {
            if (context.mounted) context.go(guardianLoginRoute);
          },
        ),
      ),
      guardianRoute(
        path: guardianWaitingRoute,
        builder: (context, state) => WaitingForStudentsPage(
          onCheckAgain: () async {
            await session?.refreshGrants();
            if (context.mounted) {
              await completePostAuthNavigation(context);
            }
          },
        ),
      ),
      ShellRoute(
        builder: (context, state, child) =>
            WorkspaceShell(uri: state.uri, child: child),
        routes: [
          guardianRoute(path: '/home', builder: (_, _) => const HomePage()),
          guardianRoute(
            path: '/children',
            builder: (_, _) => const ChildPicker(),
          ),
          guardianRoute(
            path: '/calendar',
            builder: (context, state) => const CalendarPage(),
            routes: [
              guardianRoute(path: 'events', redirect: (_, _) => '/calendar'),
              guardianRoute(
                path: 'attendance',
                redirect: (_, _) => '/attendance',
              ),
            ],
          ),
          guardianRoute(
            path: '/attendance',
            builder: (_, _) => const AttendanceListPage(),
          ),
          guardianRoute(
            path: '/session/:id',
            builder: (context, state) =>
                SessionDetailPage(sessionId: state.pathParameters['id']!),
          ),
          guardianRoute(
            path: '/scolarite',
            redirect: (_, _) => '/scolarite/notes',
          ),
          guardianRoute(
            path: '/scolarite/notes',
            builder: (context, state) =>
                ResultsPage(period: state.uri.queryParameters['period']),
          ),
          guardianRoute(
            path: '/scolarite/bulletins',
            redirect: (_, _) => '/scolarite/notes',
          ),
          guardianRoute(
            path: '/scolarite/programme',
            redirect: (_, _) => '/scolarite/notes',
          ),
          guardianRoute(
            path: '/scolarite/cahier',
            redirect: (_, _) => '/scolarite/notes',
          ),
          guardianRoute(
            path: '/scolarite/progress',
            builder: (_, _) => const ProgressOverviewPage(),
          ),
          guardianRoute(
            path: '/scolarite/period/:periodId/subject/:subject',
            builder: (context, state) => SubjectGradesPage(
              periodId: state.pathParameters['periodId']!,
              subject: state.pathParameters['subject']!,
              expandedMark: state.uri.queryParameters['mark'],
            ),
          ),
          guardianRoute(
            path: '/scolarite/subject/:subject/cahier',
            builder: (context, state) =>
                SubjectLogbookPage(subject: state.pathParameters['subject']!),
          ),
          guardianRoute(
            path: '/scolarite/subject/:subject',
            redirect: (context, state) {
              final subject = state.pathParameters['subject']!;
              final tab = state.uri.queryParameters['tab'];
              if (tab == 'cahier') {
                return '/scolarite/subject/${Uri.encodeComponent(subject)}/cahier';
              }
              return '/scolarite/progress';
            },
          ),
          guardianRoute(
            path: '/grade/:id',
            builder: (context, state) => LegacyResultLink(
              id: state.pathParameters['id']!,
              report: false,
            ),
          ),
          guardianRoute(
            path: '/report-card/:id',
            builder: (context, state) =>
                LegacyResultLink(id: state.pathParameters['id']!, report: true),
          ),
          guardianRoute(
            path: '/fees',
            builder: (context, state) => const FeesPage(),
            routes: [
              guardianRoute(
                path: 'fee/:id',
                builder: (context, state) =>
                    FeeDetailPage(feeId: state.pathParameters['id']!),
              ),
              guardianRoute(
                path: 'payment/:id',
                builder: (context, state) =>
                    PaymentDetailPage(paymentId: state.pathParameters['id']!),
              ),
            ],
          ),
          guardianRoute(
            path: '/inbox',
            builder: (context, state) => const InboxPage(),
            routes: [
              guardianRoute(
                path: 'conversation/:conversationId',
                builder: (_, state) => ConversationPage(
                  conversationId: state.pathParameters['conversationId']!,
                ),
              ),
              guardianRoute(
                path: 'message/:id',
                builder: (context, state) {
                  final extra = state.extra;
                  return MessageDetailPage(
                    messageId: state.pathParameters['id']!,
                    initialDelivery: extra is InboxDelivery ? extra : null,
                  );
                },
              ),
              guardianRoute(
                path: 'avis',
                builder: (context, state) => const InboxPage(),
                routes: [
                  guardianRoute(
                    path: ':campaignId',
                    builder: (context, state) {
                      final campaignId = state.pathParameters['campaignId']!;
                      final extra = state.extra;
                      String? studentId;
                      if (extra is GuardianFamilyFeedbackCampaign) {
                        studentId = extra.studentId;
                      } else {
                        try {
                          studentId = context.levit
                              .find<StudentContextController>()
                              .activeStudentId;
                        } on Object {
                          studentId = null;
                        }
                      }
                      if (studentId == null || studentId.isEmpty) {
                        return const RouteErrorPage(
                          message: 'Élève introuvable pour cet avis.',
                        );
                      }
                      return GuardianFamilyFeedbackQuestionnairePage(
                        questionnaireArgs:
                            GuardianFamilyFeedbackQuestionnaireArgs(
                              campaignId: campaignId,
                              studentId: studentId,
                            ),
                      );
                    },
                  ),
                ],
              ),
            ],
          ),
          guardianRoute(
            path: '/child',
            builder: (_, _) => const ChildProfilePage(),
          ),
          guardianRoute(
            path: '/account',
            builder: (_, _) => const AccountPage(),
          ),
          guardianRoute(
            path: '/account/profile',
            builder: (_, _) => const proto.AccountProfilePage(),
          ),
          guardianRoute(
            path: '/settings',
            builder: (_, _) => const proto.SettingsPage(),
          ),
        ],
      ),
      guardianRoute(
        path: '/fee/:id',
        redirect: (context, state) => '/fees/fee/${state.pathParameters['id']}',
      ),
      guardianRoute(
        path: '/payment/:id',
        redirect: (context, state) =>
            '/fees/payment/${state.pathParameters['id']}',
      ),
      guardianRoute(
        path: '/message/:id',
        redirect: (context, state) =>
            inboxMessagePath(state.pathParameters['id']!),
      ),
    ],
  );
}

GoRoute guardianRoute({
  required String path,
  GoRouterWidgetBuilder? builder,
  GoRouterRedirect? redirect,
  List<RouteBase> routes = const [],
}) {
  final sheet =
      path == '/children' ||
      path == '/account/profile' ||
      path == '/settings' ||
      path == 'fee/:id' ||
      path == 'payment/:id' ||
      path == 'message/:id' ||
      path == ':campaignId';
  Widget content(BuildContext context, GoRouterState state) {
    Widget child = builder!(context, state);
    final location = state.uri.path;
    if (location.startsWith('/fees') ||
        location == '/attendance' ||
        location.startsWith('/scolarite/notes') ||
        location.startsWith('/scolarite/period/')) {
      child = archived(context, child, state.uri);
    }
    if (location == '/home' ||
        location == '/calendar' ||
        location == '/child' ||
        location == '/attendance' ||
        location.startsWith('/scolarite') ||
        location.startsWith('/fees') ||
        location.startsWith('/inbox') ||
        location.startsWith('/session/') ||
        location.startsWith('/grade/') ||
        location.startsWith('/report-card/')) {
      return ChildWorkspace(child: child);
    }
    return child;
  }

  return GoRoute(
    path: path,
    redirect: redirect,
    routes: routes,
    pageBuilder: builder == null
        ? null
        : (context, state) => sheet
              ? GuardianSheetPage(
                  key: state.pageKey,
                  title: switch (path) {
                    '/children' => words(context, 'Mes enfants', 'My children'),
                    '/account/profile' => words(
                      context,
                      'Mon profil',
                      'My profile',
                    ),
                    '/settings' => words(context, 'Paramètres', 'Settings'),
                    'fee/:id' => words(
                      context,
                      'Détail des frais',
                      'Charge details',
                    ),
                    'payment/:id' => words(
                      context,
                      'Reçu de paiement',
                      'Payment receipt',
                    ),
                    'message/:id' => words(context, 'Message', 'Message'),
                    ':campaignId' => words(
                      context,
                      'Questionnaire',
                      'Questionnaire',
                    ),
                    _ => words(context, 'Détails', 'Details'),
                  },
                  child: content(context, state),
                )
              : MaterialPage<void>(
                  key: state.pageKey,
                  child: content(context, state),
                ),
  );
}
