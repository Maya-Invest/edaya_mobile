import 'package:edaya_shared/edaya_shared.dart' hide LoginPage;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:levit_flutter/levit_flutter.dart';

import '../config/api_config.dart';
import '../design/list_detail_host.dart';
import '../design/shell_chrome.dart';
import '../features/account/account_page.dart';
import '../features/account/account_profile_page.dart' as proto;
import '../features/account/settings_page.dart' as proto;
import '../features/calendar/attendance_page.dart';
import '../features/calendar/calendar_page.dart';
import '../features/calendar/session_detail_page.dart';
import '../features/child_profile/child_profile_page.dart';
import '../features/context/academic_year_controller.dart';
import '../features/context/student_context_controller.dart';
import '../features/family_feedback/family_feedback_page.dart';
import '../features/fees/fee_detail_page.dart';
import '../features/fees/fees_page.dart';
import '../features/fees/payment_detail_page.dart';
import '../features/home/home_page.dart';
import '../features/inbox/inbox_page.dart';
import '../features/inbox/message_detail_page.dart';
import '../features/invite/invitation_page.dart';
import '../features/login/login_page.dart';
import '../features/scolarite/grade_detail_page.dart';
import '../features/scolarite/progress_page.dart';
import '../features/scolarite/report_card_page.dart';
import '../features/scolarite/results_page.dart';
import '../features/scolarite/subject_grades_page.dart';
import '../features/scolarite/subject_logbook_page.dart';
import '../features/waiting/waiting_for_students_page.dart';
import '../mock/mock_store.dart';
import 'shell_page.dart';

GoRouter createRouter({
  required AppSessionController session,
  required StudentContextController studentContext,
  required AcademicYearController academicYear,
  required PendingInvitationStore pendingInvitation,
  required Listenable routerRefresh,
  MockStore? mockStore,
}) {
  Future<void> completePostAuthNavigation([BuildContext? context]) async {
    await academicYear.loadYears();
    await studentContext.initializeFromSession();
    if (context != null && context.mounted) {
      final next = resolveGuardianPostAuthHome(
        hasSchoolSession: session.hasSchoolSession,
        hasLinkedStudents: studentContext.hasLinkedStudents,
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

      final incoming = parseInvitationDeepLink(state.uri);
      if (incoming != null) {
        pendingInvitation.remember(incoming.token);
      } else {
        final routeToken = state.pathParameters['token'];
        if (routeToken != null && routeToken.trim().isNotEmpty) {
          pendingInvitation.remember(routeToken);
        }
      }

      return resolveGuardianAuthRedirect(
        isAuthenticated: session.isAuthenticated,
        matchedLocation: state.matchedLocation,
        pendingInvitationToken: pendingInvitation.token,
        hasSchoolSession: session.hasSchoolSession,
        linkedStudentsResolved: studentContext.linkedStudentsResolved.value,
        hasLinkedStudents: studentContext.hasLinkedStudents,
      );
    },
    routes: [
      GoRoute(
        path: guardianLoginRoute,
        builder: (context, state) {
          return LoginPage(
            mockStore: mockStore,
            defaultEmail: ApiConfig.devGuardianEmail,
            onSignInSuccess: () async {
              final pending = pendingInvitation.token;
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
            await session.refreshGrants();
            if (context.mounted) {
              await completePostAuthNavigation(context);
            }
          },
        ),
      ),
      ShellRoute(
        builder: (context, state, child) => PrototypeShell(child: child),
        routes: [
          GoRoute(
            path: '/home',
            builder: (_, _) => const ShellChromeBody(child: HomePage()),
          ),
          ShellRoute(
            builder: (context, state, child) => ListDetailHost(
              listPath: '/calendar',
              master: const CalendarPage(),
              detailChild: child,
            ),
            routes: [
              GoRoute(
                path: '/calendar',
                builder: (_, _) => const SizedBox.shrink(),
                routes: [
                  GoRoute(
                    path: 'events',
                    redirect: (_, _) => '/calendar',
                  ),
                  GoRoute(
                    path: 'attendance',
                    redirect: (_, _) => '/attendance',
                  ),
                ],
              ),
              GoRoute(
                path: '/attendance',
                builder: (_, _) => const AttendanceListPage(),
              ),
              GoRoute(
                path: '/session/:id',
                builder: (context, state) => SessionDetailPage(
                  sessionId: state.pathParameters['id']!,
                ),
              ),
            ],
          ),
          ShellRoute(
            builder: (context, state, child) => ListDetailHost(
              listPath: '/scolarite/notes',
              master: const ResultsPage(),
              detailChild: child,
              isListPath: (path) => path == '/scolarite/notes',
            ),
            routes: [
              GoRoute(
                path: '/scolarite',
                redirect: (_, _) => '/scolarite/notes',
              ),
              GoRoute(
                path: '/scolarite/notes',
                builder: (_, _) => const SizedBox.shrink(),
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
                  subject: Uri.decodeComponent(
                    state.pathParameters['subject']!,
                  ),
                ),
              ),
              GoRoute(
                path: '/scolarite/subject/:subject/cahier',
                builder: (context, state) => SubjectLogbookPage(
                  subject: Uri.decodeComponent(
                    state.pathParameters['subject']!,
                  ),
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
                builder: (context, state) => GradeDetailPage(
                  gradeId: state.pathParameters['id']!,
                ),
              ),
              GoRoute(
                path: '/report-card/:id',
                builder: (context, state) => ReportCardDetailPage(
                  reportCardId: state.pathParameters['id']!,
                ),
              ),
            ],
          ),
          ShellRoute(
            builder: (context, state, child) => ListDetailHost(
              listPath: '/fees',
              master: const FeesPage(),
              detailChild: child,
            ),
            routes: [
              GoRoute(
                path: '/fees',
                builder: (_, _) => const SizedBox.shrink(),
                routes: [
                  GoRoute(
                    path: 'fee/:id',
                    builder: (context, state) => FeeDetailPage(
                      feeId: state.pathParameters['id']!,
                    ),
                  ),
                  GoRoute(
                    path: 'payment/:id',
                    builder: (context, state) => PaymentDetailPage(
                      paymentId: state.pathParameters['id']!,
                    ),
                  ),
                ],
              ),
            ],
          ),
          ShellRoute(
            builder: (context, state, child) => ListDetailHost(
              listPath: '/inbox',
              master: const InboxPage(),
              detailChild: child,
              isListPath: (path) => path == '/inbox' || path == '/inbox/avis',
            ),
            routes: [
              GoRoute(
                path: '/inbox',
                builder: (_, _) => const SizedBox.shrink(),
                routes: [
                  GoRoute(
                    path: 'message/:id',
                    builder: (context, state) => MessageDetailPage(
                      messageId: state.pathParameters['id']!,
                    ),
                  ),
                  GoRoute(
                    path: 'avis',
                    builder: (_, _) => const SizedBox.shrink(),
                    routes: [
                      GoRoute(
                        path: ':campaignId',
                        builder: (context, state) {
                          final campaignId =
                              state.pathParameters['campaignId']!;
                          final extra = state.extra;
                          final studentId = extra is GuardianFamilyFeedbackCampaign
                              ? extra.studentId
                              : context.levit
                                    .find<StudentContextController>()
                                    .activeStudentId;
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
            ],
          ),
          GoRoute(
            path: '/child',
            builder: (_, _) =>
                const ShellChromeBody(child: ChildProfilePage()),
          ),
          ShellRoute(
            builder: (context, state, child) => ListDetailHost(
              listPath: '/account',
              master: const AccountPage(),
              detailChild: child,
              isListPath: (path) => path == '/account',
            ),
            routes: [
              GoRoute(
                path: '/account',
                builder: (_, _) => const SizedBox.shrink(),
              ),
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
        ],
      ),
      GoRoute(
        path: '/fee/:id',
        redirect: (context, state) =>
            '/fees/fee/${state.pathParameters['id']}',
      ),
      GoRoute(
        path: '/payment/:id',
        redirect: (context, state) =>
            '/fees/payment/${state.pathParameters['id']}',
      ),
      GoRoute(
        path: '/message/:id',
        redirect: (context, state) =>
            '/inbox/message/${state.pathParameters['id']}',
      ),
    ],
  );
}
