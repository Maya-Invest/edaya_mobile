import 'package:edaya_shared/edaya_shared.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:levit_flutter/levit_flutter.dart';

import '../features/context/academic_year_controller.dart';
import '../features/context/student_context_controller.dart';
import '../config/api_config.dart';
import '../features/academic/academic_page.dart';
import '../features/evaluations/evaluations_page.dart';
import '../features/academic/grade_details_dialog.dart';
import '../features/academic/models/grade_entry.dart';
import '../features/academic/models/report_card_summary.dart';
import '../features/academic/report_card_details_dialog.dart';
import '../features/account/account_sheet.dart';
import '../features/app_shell/app_shell_page.dart';
import '../features/child_profile/child_profile_page.dart';
import '../features/calendar/attendance_list_page.dart';
import '../features/calendar/calendar_page.dart';
import '../features/calendar/models/calendar_session.dart';
import '../features/calendar/session_details_dialog.dart';
import '../features/context/academic_year_picker_sheet.dart';
import '../features/documents/documents_page.dart';
import '../features/fees/charge_details_dialog.dart';
import '../features/fees/fees_page.dart';
import '../features/fees/models/payment_record.dart';
import '../features/fees/models/student_charge_line.dart';
import '../features/fees/payment_details_dialog.dart';
import '../features/inbox/inbox_page.dart';
import '../features/inbox/models/inbox_delivery.dart';
import '../features/inbox/message_details_dialog.dart';
import '../features/invite/invitation_page.dart';
import '../features/my_students/my_students_sheet.dart';

import '../features/waiting/waiting_for_students_page.dart';

final rootNavigatorKey = GlobalKey<NavigatorState>();
final shellNavigatorKey = GlobalKey<NavigatorState>();

class AppRouter extends LevitController implements EdayaAppRouter {
  AppRouter({
    required AppSessionController session,
    required AcademicYearController academicYear,
    required StudentContextController studentContext,
    required EdayaRouterRefresh routerRefresh,
    required PendingInvitationStore pendingInvitation,
  }) : _session = session,
       _academicYear = academicYear,
       _studentContext = studentContext,
       _routerRefresh = routerRefresh,
       _pendingInvitation = pendingInvitation {
    router = GoRouter(
      navigatorKey: rootNavigatorKey,
      initialLocation: guardianLoginRoute,
      refreshListenable: _routerRefresh,
      redirect: (context, state) {
        final incoming = parseInvitationDeepLink(state.uri);
        if (incoming != null) {
          _pendingInvitation.remember(incoming.token);
        } else {
          final routeToken = state.pathParameters['token'];
          if (routeToken != null && routeToken.trim().isNotEmpty) {
            _pendingInvitation.remember(routeToken);
          }
        }
        return resolveGuardianAuthRedirect(
          isAuthenticated: _session.isAuthenticated,
          matchedLocation: state.matchedLocation,
          pendingInvitationToken: _pendingInvitation.token,
          hasSchoolSession: _session.hasSchoolSession,
          linkedStudentsResolved: _studentContext.linkedStudentsResolved.value,
          hasLinkedStudents: _studentContext.hasLinkedStudents,
        );
      },
      routes: [
        GoRoute(
          path: guardianLoginRoute,
          builder: (context, state) => LoginPage(
            appTitle: context.tr.appTitleGuardian,
            subtitle: context.tr.loginSubtitleGuardianDev,
            defaultEmail: ApiConfig.devGuardianEmail,
            onSignInSuccess: () async {
              final pending = _pendingInvitation.token;
              if (pending != null) {
                AppRouter.find.router.go(invitationRoutePath(pending));
                return;
              }
              await completePostAuthNavigation();
            },
          ),
        ),
        GoRoute(
          path: '/invite/:token',
          builder: (context, state) => InvitationPage(
            token: state.pathParameters['token'] ?? '',
            onAccepted: completePostAuthNavigation,
            onContinueToLogin: () async {
              AppRouter.find.router.go(guardianLoginRoute);
            },
          ),
        ),
        GoRoute(
          parentNavigatorKey: rootNavigatorKey,
          path: guardianWaitingRoute,
          builder: (context, state) => WaitingForStudentsPage(
            onCheckAgain: () async {
              await _session.refreshGrants();
              await completePostAuthNavigation();
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
          path: '/account/profile',
          builder: (context, state) => AccountProfilePage(
            session: context.levit.find<AppSessionController>(),
            schoolClient: context.levit.find<SchoolClientFactory>(),
          ),
        ),
        GoRoute(
          parentNavigatorKey: rootNavigatorKey,
          path: '/child-profile',
          builder: (context, state) => const ChildProfilePage(),
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
            ),
            GoRoute(
              path: '/documents',
              builder: (context, state) => const DocumentsPage(),
            ),
            GoRoute(
              path: '/evaluations',
              builder: (context, state) => const EvaluationsPage(),
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
                  path: 'charge-details',
                  pageBuilder: (context, state) {
                    final extra = state.extra;
                    if (extra is! StudentChargeLine) {
                      return MaterialPage<void>(
                        child: RouteErrorPage(
                          message: context.tr.missingChargeDetailsRouteData,
                        ),
                      );
                    }

                    return ModalBottomSheetPage<void>(
                      isScrollControlled: true,
                      useSafeArea: true,
                      child: ChargeDetailsDialog(charge: extra),
                    );
                  },
                ),
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
  final AcademicYearController _academicYear;
  final StudentContextController _studentContext;
  final EdayaRouterRefresh _routerRefresh;
  final PendingInvitationStore _pendingInvitation;

  static AppRouter get find => EdayaRootScope.find<AppRouter>();

  late final GoRouter router;

  Future<void> hydrateSessionContext() async {
    if (_session.hasSchoolSession) {
      await _academicYear.loadYears();
      await _studentContext.initializeFromSession();
      return;
    }
    _studentContext.markNoLinkedStudents();
  }

  Future<void> completePostAuthNavigation() async {
    await hydrateSessionContext();
    router.go(
      resolveGuardianPostAuthHome(
        hasSchoolSession: _session.hasSchoolSession,
        hasLinkedStudents: _studentContext.hasLinkedStudents,
      ),
    );
  }

  @override
  RouterConfig<Object> config() => router;
}
