import 'package:edaya_shared/edaya_shared.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:levit_flutter/levit_flutter.dart';

import '../di/teacher_module.dart';
import '../features/context/teacher_context_controller.dart';
import '../config/api_config.dart';
import '../features/account/account_sheet.dart';
import '../features/app_shell/app_shell_page.dart';
import '../features/calendar/calendar_page.dart';
import '../features/calendar/models/teacher_session.dart';
import '../features/context/class_filter_sheet.dart';
import '../features/evaluations/evaluation_create_sheet.dart';
import '../features/evaluations/evaluations_page.dart';
import '../features/evaluations/marks_entry_sheet.dart';
import '../features/evaluations/models/evaluation_models.dart';
import '../features/report_cards/models/report_card_roster_models.dart';
import '../features/report_cards/report_card_comment_sheet.dart';
import '../features/report_cards/report_card_roster_sheet.dart';
import '../features/report_cards/report_cards_page.dart';
import '../features/teaching/teaching_page.dart';
import '../features/session/attendance_flow_page.dart';
import '../features/session/session_details_sheet.dart';
import '../features/session/session_route_args.dart';
import '../navigation/teacher_route_loaders.dart';

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
            appTitle: context.tr.appTitleTeacher,
            subtitle: context.tr.loginSubtitleStaffDev,
            defaultEmail: ApiConfig.devTeacherEmail,
            defaultPassword: ApiConfig.devPassword,
            onSignInSuccess: () async {
              await initializeTeacherAuthenticatedContext();
              AppRouter.find.router.go('/calendar');
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
            onProfileSaved: (_) =>
                context.levit.find<TeacherContextController>().reloadContext(),
          ),
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
                  path: 'sessions/:sessionId',
                  pageBuilder: (context, state) {
                    final sessionId = state.pathParameters['sessionId'];
                    if (sessionId == null || sessionId.isEmpty) {
                      return MaterialPage<void>(
                        child: RouteErrorPage(
                          message: context.tr.missingSessionDetailsRouteData,
                        ),
                      );
                    }

                    return ModalBottomSheetPage<void>(
                      isScrollControlled: true,
                      useSafeArea: true,
                      child: TeacherSessionRouteLoader(sessionId: sessionId),
                    );
                  },
                ),
                GoRoute(
                  parentNavigatorKey: rootNavigatorKey,
                  path: 'session-details',
                  pageBuilder: (context, state) {
                    final extra = state.extra;
                    if (extra is! TeacherSession) {
                      return MaterialPage<void>(
                        child: RouteErrorPage(
                          message: context.tr.missingSessionDetailsRouteData,
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
                    if (extra is AttendanceFlowArgs) {
                      return AttendanceFlowPage(
                        session: extra.session,
                        controller: extra.controller,
                      );
                    }
                    if (extra is TeacherSession) {
                      return AttendanceFlowPage(session: extra);
                    }

                    return RouteErrorPage(
                      message: context.tr.missingAttendanceFlowRouteData,
                    );
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
                  path: 'assessments/:assessmentId/marks',
                  pageBuilder: (context, state) {
                    final assessmentId = state.pathParameters['assessmentId'];
                    if (assessmentId == null || assessmentId.isEmpty) {
                      return MaterialPage<void>(
                        child: RouteErrorPage(
                          message: context.tr.missingMarksEntryRouteData,
                        ),
                      );
                    }

                    return ModalBottomSheetPage<void>(
                      isScrollControlled: true,
                      useSafeArea: true,
                      child: TeacherAssessmentMarksRouteLoader(
                        assessmentId: assessmentId,
                      ),
                    );
                  },
                ),
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
                      return MaterialPage<void>(
                        child: RouteErrorPage(
                          message: context.tr.missingMarksEntryRouteData,
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
            GoRoute(
              path: '/teaching',
              builder: (context, state) => const TeachingPage(),
            ),
            GoRoute(
              path: '/report-cards',
              builder: (context, state) => const ReportCardsPage(),
              routes: [
                GoRoute(
                  parentNavigatorKey: rootNavigatorKey,
                  path: 'classes/:classGroupId/periods/:periodId/roster',
                  pageBuilder: (context, state) {
                    final classGroupId = state.pathParameters['classGroupId'];
                    final periodId = state.pathParameters['periodId'];
                    if (classGroupId == null ||
                        classGroupId.isEmpty ||
                        periodId == null ||
                        periodId.isEmpty) {
                      return MaterialPage<void>(
                        child: RouteErrorPage(
                          message: context.tr.missingReportCardRosterRouteData,
                        ),
                      );
                    }

                    return ModalBottomSheetPage<void>(
                      isScrollControlled: true,
                      useSafeArea: true,
                      child: TeacherReportCardRosterRouteLoader(
                        classGroupId: classGroupId,
                        periodId: periodId,
                      ),
                    );
                  },
                ),
                GoRoute(
                  parentNavigatorKey: rootNavigatorKey,
                  path: 'results/:resultId/students/:studentId/comment',
                  pageBuilder: (context, state) {
                    final resultId = state.pathParameters['resultId'];
                    final studentId = state.pathParameters['studentId'];
                    if (resultId == null ||
                        resultId.isEmpty ||
                        studentId == null ||
                        studentId.isEmpty) {
                      return MaterialPage<void>(
                        child: RouteErrorPage(
                          message: context.tr.reportCardNotFound,
                        ),
                      );
                    }

                    return ModalBottomSheetPage<void>(
                      isScrollControlled: true,
                      useSafeArea: true,
                      child: TeacherReportCardCommentRouteLoader(
                        resultId: resultId,
                        studentId: studentId,
                      ),
                    );
                  },
                ),
                GoRoute(
                  parentNavigatorKey: rootNavigatorKey,
                  path: 'roster',
                  pageBuilder: (context, state) {
                    final extra = state.extra;
                    if (extra is! ReportCardRosterArgs) {
                      return MaterialPage<void>(
                        child: RouteErrorPage(
                          message: context.tr.missingReportCardRosterRouteData,
                        ),
                      );
                    }

                    return ModalBottomSheetPage<void>(
                      isScrollControlled: true,
                      useSafeArea: true,
                      child: ReportCardRosterSheet(rosterArgs: extra),
                    );
                  },
                  routes: [
                    GoRoute(
                      parentNavigatorKey: rootNavigatorKey,
                      path: 'comment',
                      pageBuilder: (context, state) {
                        final extra = state.extra;
                        if (extra is! ReportCardCommentRouteArgs) {
                          return MaterialPage<void>(
                            child: RouteErrorPage(
                              message:
                                  context.tr.missingReportCardRosterRouteData,
                            ),
                          );
                        }

                        return ModalBottomSheetPage<void>(
                          isScrollControlled: true,
                          useSafeArea: true,
                          child: ReportCardCommentSheet(
                            rosterArgs: extra.rosterArgs,
                            student: extra.student,
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
