import 'package:edaya_shared/edaya_shared.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:levit_flutter/levit_flutter.dart';

import '../access/app_runtime.dart';
import '../config/api_config.dart';
import '../features/academic/academic_page.dart';
import '../features/academic/grade_details_dialog.dart';
import '../features/academic/models/grade_entry.dart';
import '../features/academic/models/report_card_summary.dart';
import '../features/academic/report_card_details_dialog.dart';
import '../features/account/account_sheet.dart';
import '../features/app_shell/app_shell_page.dart';
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

final rootNavigatorKey = GlobalKey<NavigatorState>();
final shellNavigatorKey = GlobalKey<NavigatorState>();

class AppRouter extends LevitController implements EdayaAppRouter {
  AppRouter({
    required AppSessionController session,
    required EdayaRouterRefresh routerRefresh,
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
          builder: (context, state) => LoginPage(
            appTitle: context.tr.appTitleGuardian,
            subtitle: context.tr.loginSubtitleGuardianDev,
            defaultEmail: ApiConfig.devGuardianEmail,
            defaultPassword: ApiConfig.devPassword,
            onSignInSuccess: () async {
              await AppRuntime.academicYear.loadYears();
              await AppRuntime.studentContext.initializeFromSession();
              find.router.go('/calendar');
            },
          ),
        ),
        GoRoute(
          parentNavigatorKey: rootNavigatorKey,
          path: '/settings',
          builder: (context, state) => const SettingsPage(),
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
                      return MaterialPage<void>(
                        child: RouteErrorPage(
                          message: context.tr.missingSessionDetailsRouteData,
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
                      return MaterialPage<void>(
                        child: RouteErrorPage(
                          message: context.tr.missingGradeDetailsRouteData,
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
                      return MaterialPage<void>(
                        child: RouteErrorPage(
                          message: context.tr.missingReportCardRouteData,
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
                      return MaterialPage<void>(
                        child: RouteErrorPage(
                          message: context.tr.missingPaymentDetailsRouteData,
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
                      return MaterialPage<void>(
                        child: RouteErrorPage(
                          message: context.tr.missingMessageDetailsRouteData,
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
  final EdayaRouterRefresh _routerRefresh;

  static AppRouter get find => EdayaRootScope.find<AppRouter>();

  late final GoRouter router;

  @override
  RouterConfig<Object> config() => router;
}
