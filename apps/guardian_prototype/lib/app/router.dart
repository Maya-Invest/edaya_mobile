import 'package:go_router/go_router.dart';

import '../features/account_pages.dart';
import '../features/calendar_pages.dart';
import '../features/fees_inbox_pages.dart';
import '../features/home_page.dart';
import '../features/login_page.dart';
import '../features/scolarite_pages.dart';
import '../mock/mock_store.dart';
import 'shell_page.dart';

GoRouter createRouter(MockStore store) {
  return GoRouter(
    initialLocation: '/login',
    refreshListenable: store,
    redirect: (context, state) {
      final loggedIn = store.isAuthenticated;
      final onLogin = state.matchedLocation == '/login';
      if (!loggedIn && !onLogin) return '/login';
      if (loggedIn && onLogin) return '/home';
      return null;
    },
    routes: [
      GoRoute(
        path: '/login',
        builder: (context, state) => LoginPage(store: store),
      ),
      ShellRoute(
        builder: (context, state, child) => PrototypeShell(store: store, child: child),
        routes: [
          GoRoute(path: '/home', builder: (_, _) => HomePage(store: store)),
          GoRoute(
            path: '/calendar',
            builder: (_, _) => CalendarPage(store: store),
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
            path: '/scolarite',
            redirect: (_, _) => '/scolarite/notes',
          ),
          GoRoute(
            path: '/scolarite/notes',
            builder: (_, _) => ResultsPage(store: store),
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
          GoRoute(path: '/fees', builder: (_, _) => FeesPage(store: store)),
          GoRoute(path: '/inbox', builder: (_, _) => InboxPage(store: store)),
        ],
      ),
      GoRoute(
        path: '/scolarite/progress',
        builder: (_, _) => ProgressOverviewPage(store: store),
      ),
      GoRoute(
        path: '/scolarite/period/:periodId/subject/:subject',
        builder: (context, state) => SubjectGradesPage(
          store: store,
          periodId: state.pathParameters['periodId']!,
          subject: MockStore.subjectFromRouteParam(
            state.pathParameters['subject']!,
          ),
        ),
      ),
      GoRoute(
        path: '/scolarite/subject/:subject/cahier',
        builder: (context, state) => SubjectLogbookPage(
          store: store,
          subject: MockStore.subjectFromRouteParam(
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
        path: '/attendance',
        builder: (_, _) => AttendanceListPage(store: store),
      ),
      GoRoute(
        path: '/session/:id',
        builder: (context, state) => SessionDetailPage(
          store: store,
          sessionId: state.pathParameters['id']!,
        ),
      ),
      GoRoute(
        path: '/grade/:id',
        builder: (context, state) => GradeDetailPage(
          store: store,
          gradeId: state.pathParameters['id']!,
        ),
      ),
      GoRoute(
        path: '/report-card/:id',
        builder: (context, state) => ReportCardDetailPage(
          store: store,
          reportCardId: state.pathParameters['id']!,
        ),
      ),
      GoRoute(
        path: '/fee/:id',
        builder: (context, state) => FeeDetailPage(
          store: store,
          feeId: state.pathParameters['id']!,
        ),
      ),
      GoRoute(
        path: '/payment/:id',
        builder: (context, state) => PaymentDetailPage(
          store: store,
          paymentId: state.pathParameters['id']!,
        ),
      ),
      GoRoute(
        path: '/message/:id',
        builder: (context, state) => MessageDetailPage(
          store: store,
          messageId: state.pathParameters['id']!,
        ),
      ),
      GoRoute(path: '/settings', builder: (_, _) => const SettingsPage()),
      GoRoute(path: '/account', builder: (_, _) => AccountPage(store: store)),
      GoRoute(path: '/account/profile', builder: (_, _) => const AccountProfilePage()),
    ],
  );
}
