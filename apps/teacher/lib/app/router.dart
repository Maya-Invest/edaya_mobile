import '../features/classes/daily_attendance_page.dart';
import '../features/classes/teacher_discipline_page.dart';
import 'package:edaya_shared/edaya_shared.dart'
    hide AccountProfilePage, LoginPage, SettingsPage;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../design/list_detail_host.dart';
import '../design/shell_chrome.dart';
import '../features/account/account_page.dart';
import '../features/calendar/calendar_page.dart';
import '../features/classes/classes_page.dart';
import '../features/evaluations/evaluations_page.dart';
import '../features/evaluations/family_feedback_page.dart';
import '../features/home/home_page.dart';
import '../features/inbox/inbox_page.dart';
import '../features/login/login_page.dart';
import '../features/session/attendance_page.dart';
import '../features/session/logbook_page.dart';
import '../features/session/session_detail_page.dart';
import 'shell_page.dart';

GoRouter createRouter({
  required Listenable routerRefresh,
  required bool Function() isAuthenticated,
  bool Function()? isBootstrapping,
  bool Function()? needsProfileSelection,
}) {
  return GoRouter(
    initialLocation: '/login',
    refreshListenable: routerRefresh,
    redirect: (context, state) {
      if (isBootstrapping?.call() ?? false) {
        return null;
      }
      final loggedIn = isAuthenticated();
      final onLogin = state.matchedLocation == '/login';
      final choosingProfile = needsProfileSelection?.call() ?? false;
      if (!loggedIn && !onLogin) return '/login';
      if (loggedIn && choosingProfile && state.matchedLocation != '/profiles') {
        return '/profiles';
      }
      if (loggedIn && onLogin) return '/home';
      return null;
    },
    routes: [
      GoRoute(path: '/login', builder: (context, state) => const LoginPage()),
      GoRoute(
        path: '/profiles',
        builder: (context, state) =>
            ProfilePickerPage(onSelected: () => context.go('/home')),
      ),
      ShellRoute(
        builder: (context, state, child) => PrototypeShell(child: child),
        routes: [
          GoRoute(
            path: '/home',
            builder: (_, _) => const ShellChromeBody(child: HomePage()),
            routes: [
              GoRoute(
                path: 'avis/:feedbackId',
                builder: (context, state) => ShellChromeBody(
                  child: FamilyFeedbackDetailPage(
                    feedbackId: state.pathParameters['feedbackId']!,
                    fromHome: true,
                  ),
                ),
              ),
            ],
          ),
          ShellRoute(
            builder: (context, state, child) => ListDetailHost(
              listPath: '/calendar',
              master: const CalendarPage(),
              detailChild: child,
              isListPath: (path) => path == '/calendar',
            ),
            routes: [
              GoRoute(
                path: '/calendar',
                builder: (_, _) => const SizedBox.shrink(),
              ),
              GoRoute(
                path: '/session/:id',
                builder: (context, state) =>
                    SessionDetailPage(sessionId: state.pathParameters['id']!),
                routes: [
                  GoRoute(
                    path: 'attendance',
                    builder: (context, state) =>
                        AttendancePage(sessionId: state.pathParameters['id']!),
                  ),
                  GoRoute(
                    path: 'logbook',
                    builder: (context, state) =>
                        LogbookPage(sessionId: state.pathParameters['id']!),
                  ),
                ],
              ),
            ],
          ),
          ShellRoute(
            builder: (context, state, child) => ListDetailHost(
              listPath: '/classes',
              master: const ClassesPage(),
              detailChild: child,
              isListPath: (path) => path == '/classes',
            ),
            routes: [
              GoRoute(
                path: '/classes',
                builder: (_, _) => const SizedBox.shrink(),
              ),
              GoRoute(
                path: '/classes/:classId',
                builder: (context, state) =>
                    ClassRosterPage(classId: state.pathParameters['classId']!),
                routes: [
                  GoRoute(
                    path: 'discipline',
                    builder: (context, state) => TeacherDisciplinePage(
                      classId: state.pathParameters['classId']!,
                    ),
                  ),
                  GoRoute(
                    path: 'attendance',
                    builder: (context, state) => DailyAttendancePage(
                      classId: state.pathParameters['classId']!,
                    ),
                  ),
                  GoRoute(
                    path: 'student/:studentId',
                    builder: (context, state) => StudentProfilePage(
                      classId: state.pathParameters['classId']!,
                      studentId: state.pathParameters['studentId']!,
                    ),
                  ),
                ],
              ),
            ],
          ),
          ShellRoute(
            builder: (context, state, child) => ListDetailHost(
              listPath: '/evaluations',
              master: const EvaluationsPage(),
              detailChild: child,
              isListPath: (path) => path == '/evaluations',
            ),
            routes: [
              GoRoute(
                path: '/evaluations',
                builder: (_, _) => const SizedBox.shrink(),
              ),
              GoRoute(
                path: '/evaluations/avis',
                builder: (_, _) => const FamilyFeedbackListPage(),
                routes: [
                  GoRoute(
                    path: ':feedbackId',
                    builder: (context, state) => FamilyFeedbackDetailPage(
                      feedbackId: state.pathParameters['feedbackId']!,
                    ),
                  ),
                ],
              ),
              GoRoute(
                path: '/evaluations/report-cards/:classId/:periodId',
                builder: (context, state) => ReportCardRosterPage(
                  classId: state.pathParameters['classId']!,
                  periodId: state.pathParameters['periodId']!,
                ),
                routes: [
                  GoRoute(
                    path: ':rosterId',
                    builder: (context, state) => ReportCardCommentPage(
                      classId: state.pathParameters['classId']!,
                      periodId: state.pathParameters['periodId']!,
                      rosterId: state.pathParameters['rosterId']!,
                    ),
                  ),
                ],
              ),
              GoRoute(
                path: '/evaluations/create',
                builder: (_, _) => const EvaluationCreatePage(),
              ),
              GoRoute(
                path: '/evaluations/:evaluationId/marks',
                builder: (context, state) => MarksEntryPage(
                  evaluationId: state.pathParameters['evaluationId']!,
                ),
              ),
            ],
          ),
          ShellRoute(
            builder: (context, state, child) => ListDetailHost(
              listPath: '/inbox',
              master: const InboxPage(),
              detailChild: child,
            ),
            routes: [
              GoRoute(
                path: '/inbox',
                builder: (_, _) => const SizedBox.shrink(),
                routes: [
                  GoRoute(
                    path: 'conversation/:conversationId',
                    builder: (_, state) => ConversationPage(
                      conversationId: state.pathParameters['conversationId']!,
                    ),
                  ),
                  GoRoute(
                    path: 'message/:id',
                    builder: (context, state) => MessageDetailPage(
                      messageId: Uri.decodeComponent(
                        state.pathParameters['id']!,
                      ),
                    ),
                  ),
                ],
              ),
            ],
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
                builder: (_, _) => const AccountProfilePage(),
              ),
              GoRoute(
                path: '/settings',
                builder: (_, _) => const SettingsPage(),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: '/message/:id',
        redirect: (context, state) =>
            '/inbox/message/${state.pathParameters['id']}',
      ),
    ],
  );
}
