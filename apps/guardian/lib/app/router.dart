import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:levit_flutter/levit_flutter.dart';

import '../access/root_scope.dart';
import '../common/models/modal_bottom_sheet_page.dart';
import '../common/widgets/route_error_page.dart';
import '../features/academic/academic_page.dart';
import '../features/academic/grade_details_dialog.dart';
import '../features/academic/models/grade_entry.dart';
import '../features/academic/models/report_card_summary.dart';
import '../features/academic/report_card_details_dialog.dart';
import '../features/account/account_sheet.dart';
import '../features/app_shell/app_shell_page.dart';
import '../features/auth/app_session_controller.dart';
import '../features/auth/login_page.dart';
import '../features/calendar/attendance_list_page.dart';
import '../features/calendar/calendar_page.dart';
import '../features/calendar/models/calendar_session.dart';
import '../features/calendar/session_details_dialog.dart';
import '../features/context/academic_year_picker_sheet.dart';
import '../features/fees/fees_page.dart';
import '../features/fees/models/payment_record.dart';
import '../features/fees/payment_details_dialog.dart';
import '../features/inbox/inbox_page.dart';
import '../features/inbox/models/inbox_delivery.dart';
import '../features/inbox/message_details_dialog.dart';
import '../features/my_students/my_students_sheet.dart';
import 'router_refresh.dart';

final rootNavigatorKey = GlobalKey<NavigatorState>();
final shellNavigatorKey = GlobalKey<NavigatorState>();

class AppRouter extends LevitController {
  AppRouter({
    required AppSessionController session,
    required GuardianRouterRefresh routerRefresh,
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
          path: '/my-students',
          pageBuilder: (context, state) {
            return const ModalBottomSheetPage<void>(
              isScrollControlled: true,
              useSafeArea: true,
              child: MyStudentsSheet(),
            );
          },
        ),
        GoRoute(
          parentNavigatorKey: rootNavigatorKey,
          path: '/academic-year-picker',
          pageBuilder: (context, state) {
            return const ModalBottomSheetPage<void>(
              isScrollControlled: true,
              useSafeArea: true,
              child: AcademicYearPickerSheet(),
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
                  path: 'attendance',
                  builder: (context, state) => const AttendanceListPage(),
                ),
                GoRoute(
                  parentNavigatorKey: rootNavigatorKey,
                  path: 'session-details',
                  pageBuilder: (context, state) {
                    final extra = state.extra;
                    if (extra is! CalendarSession) {
                      return const MaterialPage<void>(
                        child: RouteErrorPage(
                          message: 'Missing session details route data.',
                        ),
                      );
                    }

                    return ModalBottomSheetPage<void>(
                      isScrollControlled: true,
                      useSafeArea: true,
                      child: SessionDetailsDialog(session: extra),
                    );
                  },
                ),
              ],
            ),
            GoRoute(
              path: '/academic',
              builder: (context, state) => const AcademicPage(),
              routes: [
                GoRoute(
                  parentNavigatorKey: rootNavigatorKey,
                  path: 'grade-details',
                  pageBuilder: (context, state) {
                    final extra = state.extra;
                    if (extra is! GradeEntry) {
                      return const MaterialPage<void>(
                        child: RouteErrorPage(
                          message: 'Missing grade details route data.',
                        ),
                      );
                    }

                    return ModalBottomSheetPage<void>(
                      isScrollControlled: true,
                      useSafeArea: true,
                      child: GradeDetailsDialog(entry: extra),
                    );
                  },
                ),
                GoRoute(
                  parentNavigatorKey: rootNavigatorKey,
                  path: 'report-card-details',
                  pageBuilder: (context, state) {
                    final extra = state.extra;
                    if (extra is! ReportCardSummary) {
                      return const MaterialPage<void>(
                        child: RouteErrorPage(
                          message: 'Missing report card route data.',
                        ),
                      );
                    }

                    return ModalBottomSheetPage<void>(
                      isScrollControlled: true,
                      useSafeArea: true,
                      child: ReportCardDetailsDialog(reportCard: extra),
                    );
                  },
                ),
              ],
            ),
            GoRoute(
              path: '/fees',
              builder: (context, state) => const FeesPage(),
              routes: [
                GoRoute(
                  parentNavigatorKey: rootNavigatorKey,
                  path: 'payment-details',
                  pageBuilder: (context, state) {
                    final extra = state.extra;
                    if (extra is! PaymentRecord) {
                      return const MaterialPage<void>(
                        child: RouteErrorPage(
                          message: 'Missing payment details route data.',
                        ),
                      );
                    }

                    return ModalBottomSheetPage<void>(
                      isScrollControlled: true,
                      useSafeArea: true,
                      child: PaymentDetailsDialog(payment: extra),
                    );
                  },
                ),
              ],
            ),
            GoRoute(
              path: '/inbox',
              builder: (context, state) => const InboxPage(),
              routes: [
                GoRoute(
                  parentNavigatorKey: rootNavigatorKey,
                  path: 'message',
                  pageBuilder: (context, state) {
                    final extra = state.extra;
                    if (extra is! InboxDelivery) {
                      return const MaterialPage<void>(
                        child: RouteErrorPage(
                          message: 'Missing message details route data.',
                        ),
                      );
                    }

                    return ModalBottomSheetPage<void>(
                      isScrollControlled: true,
                      useSafeArea: true,
                      child: MessageDetailsDialog(initialDelivery: extra),
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
  final GuardianRouterRefresh _routerRefresh;

  static AppRouter get find => GuardianRootScope.find<AppRouter>();

  late final GoRouter router;

  RouterConfig<Object> config() => router;
}
