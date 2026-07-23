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
import '../features/context/academic_year_controller.dart';
import '../features/context/student_context_controller.dart';
import '../features/fees/fee_detail_page.dart';
import '../features/fees/fees_page.dart';
import '../features/fees/payment_detail_page.dart';
import '../features/home/home_page.dart';
import '../features/inbox/inbox_page.dart';
import '../features/inbox/message_detail_page.dart';
import '../features/login/login_page.dart';
import '../features/scolarite/grade_detail_page.dart';
import '../features/scolarite/progress_page.dart';
import '../features/scolarite/report_card_page.dart';
import '../features/scolarite/results_page.dart';
import '../features/scolarite/subject_grades_page.dart';
import '../features/scolarite/subject_logbook_page.dart';
import '../mock/mock_store.dart';
import 'shell_page.dart';

GoRouter createRouter({
  required AppSessionController session,
  required Listenable routerRefresh,
  MockStore? mockStore,
}) {
  return GoRouter(
    initialLocation: '/login',
    refreshListenable: routerRefresh,
    redirect: (context, state) {
      final loggedIn = mockStore != null
          ? mockStore.isAuthenticated
          : session.isAuthenticated;
      final onLogin = state.matchedLocation == '/login';
      if (!loggedIn && !onLogin) return '/login';
      if (loggedIn && onLogin) return '/home';
      return null;
    },
    routes: [
      GoRoute(
        path: '/login',
        builder: (context, state) {
          return LoginPage(
            mockStore: mockStore,
            defaultEmail: ApiConfig.devGuardianEmail,
            defaultPassword: ApiConfig.devPassword,
            onSignInSuccess: () async {
              final years =
                  context.levit.find<AcademicYearController>();
              final students =
                  context.levit.find<StudentContextController>();
              await years.loadYears();
              await students.initializeFromSession();
              if (context.mounted) context.go('/home');
            },
          );
        },
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
