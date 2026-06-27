import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:levit_flutter/levit_flutter.dart';

import '../access/root_scope.dart';
import '../common/models/modal_bottom_sheet_page.dart';
import '../common/widgets/route_error_page.dart';
import '../features/account/account_sheet.dart';
import '../features/app_shell/app_shell_page.dart';
import '../features/auth/app_session_controller.dart';
import '../features/auth/login_page.dart';
import '../features/calendar/calendar_page.dart';
import '../features/calendar/models/teacher_session.dart';
import '../features/context/class_filter_sheet.dart';
import '../features/evaluations/evaluation_create_sheet.dart';
import '../features/evaluations/evaluations_page.dart';
import '../features/evaluations/marks_entry_sheet.dart';
import '../features/evaluations/models/evaluation_models.dart';
import '../features/session/attendance_flow_page.dart';
import '../features/session/session_details_sheet.dart';
import 'router_refresh.dart';

final rootNavigatorKey = GlobalKey<NavigatorState>();
final shellNavigatorKey = GlobalKey<NavigatorState>();

class AppRouter extends LevitController {
  AppRouter({
    required AppSessionController session,
    required TeacherRouterRefresh routerRefresh,
  }) : _session = session,
       _routerRefresh = routerRefresh {
    router = GoRouter(
      navigatorKey: rootNavigatorKey,
      initialLocation: '/login',
      refreshListenable: _routerRefresh,
      redirect: (context, state) {
        final isAuthenticated = _session.isAuthenticated;
        final isAuthRoute = state.matchedLocation == '/login';

        if (!isAuthenticated && !isAuthRoute) {
          return '/login';
        }
        if (isAuthenticated && isAuthRoute) {
          return '/calendar';
        }
        return null;
      },
      routes: [
        GoRoute(
          path: '/login',
          builder: (context, state) => const LoginPage(),
        ),
        GoRoute(
          parentNavigatorKey: rootNavigatorKey,
          path: '/account',
          pageBuilder: (context, state) {
            return const ModalBottomSheetPage<void>(
              isScrollControlled: true,
              useSafeArea: true,
              child: AccountSheet(),
            );
          },
        ),
        GoRoute(
          parentNavigatorKey: rootNavigatorKey,
          path: '/class-filter',
          pageBuilder: (context, state) {
            return const ModalBottomSheetPage<void>(
              isScrollControlled: true,
              useSafeArea: true,
              child: ClassFilterSheet(),
            );
          },
        ),
        ShellRoute(
          navigatorKey: shellNavigatorKey,
          builder: (context, state, child) => AppShellPage(child: child),
          routes: [
            GoRoute(
              path: '/calendar',
              builder: (context, state) => const CalendarPage(),
              routes: [
                GoRoute(
                  parentNavigatorKey: rootNavigatorKey,
                  path: 'session-details',
                  pageBuilder: (context, state) {
                    final extra = state.extra;
                    if (extra is! TeacherSession) {
                      return const MaterialPage<void>(
                        child: RouteErrorPage(
                          message: 'Missing session details route data.',
                        ),
                      );
                    }

                    return ModalBottomSheetPage<void>(
                      isScrollControlled: true,
                      useSafeArea: true,
                      child: SessionDetailsSheet(session: extra),
                    );
                  },
                ),
                GoRoute(
                  parentNavigatorKey: rootNavigatorKey,
                  path: 'attendance-flow',
                  builder: (context, state) {
                    final extra = state.extra;
                    if (extra is! TeacherSession) {
                      return const RouteErrorPage(
                        message: 'Missing attendance flow route data.',
                      );
                    }

                    return AttendanceFlowPage(session: extra);
                  },
                ),
              ],
            ),
            GoRoute(
              path: '/evaluations',
              builder: (context, state) => const EvaluationsPage(),
              routes: [
                GoRoute(
                  parentNavigatorKey: rootNavigatorKey,
                  path: 'create',
                  pageBuilder: (context, state) {
                    return const ModalBottomSheetPage<void>(
                      isScrollControlled: true,
                      useSafeArea: true,
                      child: EvaluationCreateSheet(),
                    );
                  },
                ),
                GoRoute(
                  parentNavigatorKey: rootNavigatorKey,
                  path: 'marks',
                  pageBuilder: (context, state) {
                    final extra = state.extra;
                    if (extra is! EvaluationSummary) {
                      return const MaterialPage<void>(
                        child: RouteErrorPage(
                          message: 'Missing marks entry route data.',
                        ),
                      );
                    }

                    return ModalBottomSheetPage<void>(
                      isScrollControlled: true,
                      useSafeArea: true,
                      child: MarksEntrySheet(evaluation: extra),
                    );
                  },
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  final AppSessionController _session;
  final TeacherRouterRefresh _routerRefresh;

  static AppRouter get find => TeacherRootScope.find<AppRouter>();

  late final GoRouter router;

  RouterConfig<Object> config() => router;
}
