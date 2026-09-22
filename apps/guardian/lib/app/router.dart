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
import '../features/scolarite/grade_detail_page.dart';
import '../features/scolarite/progress_page.dart';
import '../features/scolarite/report_card_page.dart';
import '../features/scolarite/subject_grades_page.dart';
import '../features/scolarite/subject_logbook_page.dart';
import '../features/waiting/waiting_for_students_page.dart';
import '../mock/mock_store.dart';
import 'shell_page.dart';

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
    await liveAcademicYear.loadYears();
    await liveStudentContext.initializeFromSession();
    if (context != null && context.mounted) {
      final next = resolveGuardianPostAuthHome(
        hasSchoolSession: liveSession.hasSchoolSession,
        hasLinkedStudents: liveStudentContext.hasLinkedStudents,
      );
      context.go(next);
    }
  }

  Widget hubPlaceholder() => const SizedBox.shrink();

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

      return resolveGuardianAuthRedirect(
        isAuthenticated: liveSession.isAuthenticated,
        matchedLocation: state.matchedLocation,
        pendingInvitationToken: livePending.token,
        hasSchoolSession: liveSession.hasSchoolSession,
        linkedStudentsResolved: liveStudentContext.linkedStudentsResolved.value,
        hasLinkedStudents: liveStudentContext.hasLinkedStudents,
        needsProfileSelection: liveSession.needsProfileSelection,
      );
    },
    routes: [
      GoRoute(
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
      GoRoute(
        path: '/profiles',
        builder: (context, state) => ProfilePickerPage(
          onSelected: () => completePostAuthNavigation(context),
        ),
      ),
      GoRoute(
        path: '/invite/:token',
        builder: (context, state) => InvitationPage(
          token: state.pathParameters['token'] ?? '',
          onAccepted: () => completePostAuthNavigation(context),
          onContinueToLogin: () async {
            if (context.mounted) context.go(guardianLoginRoute);
          },
        ),
      ),
      GoRoute(
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
        builder: (context, state, child) => PrototypeShell(child: child),
        routes: [
          GoRoute(path: '/home', builder: (_, _) => hubPlaceholder()),
          GoRoute(
            path: '/calendar',
            builder: (_, _) => hubPlaceholder(),
            routes: [
              GoRoute(path: 'events', redirect: (_, _) => '/calendar'),
              GoRoute(path: 'attendance', redirect: (_, _) => '/attendance'),
            ],
          ),
          GoRoute(
            path: '/attendance',
            builder: (_, _) => const AttendanceListPage(),
          ),
          GoRoute(
            path: '/session/:id',
            builder: (context, state) =>
                SessionDetailPage(sessionId: state.pathParameters['id']!),
          ),
          GoRoute(path: '/scolarite', redirect: (_, _) => '/scolarite/notes'),
          GoRoute(
            path: '/scolarite/notes',
            builder: (_, _) => hubPlaceholder(),
          ),
          GoRoute(
            path: '/scolarite/bulletins',
            redirect: (_, _) => '/scolarite/notes',
          ),
          GoRoute(
            path: '/scolarite/programme',
            redirect: (_, _) => '/scolarite/notes',
          ),
          GoRoute(
            path: '/scolarite/cahier',
            redirect: (_, _) => '/scolarite/notes',
          ),
          GoRoute(
            path: '/scolarite/progress',
            builder: (_, _) => const ProgressOverviewPage(),
          ),
          GoRoute(
            path: '/scolarite/period/:periodId/subject/:subject',
            builder: (context, state) => SubjectGradesPage(
              periodId: state.pathParameters['periodId']!,
              subject: Uri.decodeComponent(state.pathParameters['subject']!),
            ),
          ),
          GoRoute(
            path: '/scolarite/subject/:subject/cahier',
            builder: (context, state) => SubjectLogbookPage(
              subject: Uri.decodeComponent(state.pathParameters['subject']!),
            ),
          ),
          GoRoute(
            path: '/scolarite/subject/:subject',
            redirect: (context, state) {
              final subject = state.pathParameters['subject']!;
              final tab = state.uri.queryParameters['tab'];
              if (tab == 'cahier') {
                return '/scolarite/subject/$subject/cahier';
              }
              return '/scolarite/progress';
            },
          ),
          GoRoute(
            path: '/grade/:id',
            builder: (context, state) =>
                GradeDetailPage(gradeId: state.pathParameters['id']!),
          ),
          GoRoute(
            path: '/report-card/:id',
            builder: (context, state) =>
                ReportCardDetailPage(reportCardId: state.pathParameters['id']!),
          ),
          GoRoute(
            path: '/fees',
            builder: (_, _) => hubPlaceholder(),
            routes: [
              GoRoute(
                path: 'fee/:id',
                builder: (context, state) =>
                    FeeDetailPage(feeId: state.pathParameters['id']!),
              ),
              GoRoute(
                path: 'payment/:id',
                builder: (context, state) =>
                    PaymentDetailPage(paymentId: state.pathParameters['id']!),
              ),
            ],
          ),
          GoRoute(
            path: '/inbox',
            builder: (_, _) => hubPlaceholder(),
            routes: [
              GoRoute(
                path: 'message/:id',
                builder: (context, state) {
                  final extra = state.extra;
                  return MessageDetailPage(
                    messageId: state.pathParameters['id']!,
                    initialDelivery: extra is InboxDelivery ? extra : null,
                  );
                },
              ),
              GoRoute(
                path: 'avis',
                builder: (_, _) => hubPlaceholder(),
                routes: [
                  GoRoute(
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
          GoRoute(path: '/child', builder: (_, _) => const ChildProfilePage()),
          GoRoute(path: '/account', builder: (_, _) => const AccountPage()),
          GoRoute(
            path: '/account/profile',
            builder: (_, _) => const proto.AccountProfilePage(),
          ),
          GoRoute(
            path: '/settings',
            builder: (_, _) => const proto.SettingsPage(),
          ),
        ],
      ),
      GoRoute(
        path: '/fee/:id',
        redirect: (context, state) => '/fees/fee/${state.pathParameters['id']}',
      ),
      GoRoute(
        path: '/payment/:id',
        redirect: (context, state) =>
            '/fees/payment/${state.pathParameters['id']}',
      ),
      GoRoute(
        path: '/message/:id',
        redirect: (context, state) =>
            inboxMessagePath(state.pathParameters['id']!),
      ),
    ],
  );
}
