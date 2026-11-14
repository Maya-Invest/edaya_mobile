import '../features/context/teacher_context_controller.dart';
import '../features/evaluations/live_evaluations_controller.dart';
import 'package:levit_flutter/levit_flutter.dart';
import '../di/prototype_module.dart';
import '../features/classes/daily_attendance_page.dart';
import '../features/classes/teacher_discipline_page.dart';
import 'package:edaya_shared/edaya_shared.dart'
    hide AccountProfilePage, LoginPage, SettingsPage;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'workspace_navigation.dart';
import '../features/classes/new_record_form.dart';
import '../features/classes/workspace_classes.dart';
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

GoRouter createRouter({
  required Listenable routerRefresh,
  required bool Function() isAuthenticated,
  bool Function()? isBootstrapping,
}) {
  GoRouter.optionURLReflectsImperativeAPIs = true;
  return GoRouter(
    initialLocation: '/login',
    refreshListenable: routerRefresh,
    redirect: (context, state) {
      if (isBootstrapping?.call() ?? false) {
        return null;
      }
      final loggedIn = isAuthenticated();
      final onLogin = state.matchedLocation == '/login';
      if (!loggedIn && !onLogin) {
        return Uri(
          path: '/login',
          queryParameters: {'next': state.uri.toString()},
        ).toString();
      }
      if (loggedIn && onLogin) {
        return _localTarget(state);
      }
      return null;
    },
    routes: [
      GoRoute(path: '/login', builder: (context, state) => const LoginPage()),
      GoRoute(path: '/profiles', redirect: (_, state) => _localTarget(state)),
      ShellRoute(
        builder: (context, state, child) =>
            WorkspaceShell(uri: state.uri, child: child),
        routes: [
          workspaceRoute(
            path: '/home',
            builder: (_, _) => const HomePage(),
            routes: [
              record(
                'student/:classId/:studentId',
                'Élève',
                (s) => StudentProfilePage(
                  classId: s.pathParameters['classId']!,
                  studentId: s.pathParameters['studentId']!,
                ),
              ),
              GoRoute(
                path: 'avis/:feedbackId',
                redirect: (_, s) =>
                    '/evaluations/avis/${s.pathParameters['feedbackId']}',
              ),
            ],
          ),
          workspaceRoute(
            path: '/calendar',
            builder: (_, _) => const CalendarPage(),
            routes: [
              record(
                'lesson/:id',
                'Séance',
                (s) => SessionDetailPage(sessionId: s.pathParameters['id']!),
                wide: true,
              ),
              record(
                'lesson/:id/attendance',
                'Appel de séance',
                (s) => AttendancePage(sessionId: s.pathParameters['id']!),
                wide: true,
              ),
              record(
                'lesson/:id/logbook',
                'Cahier de texte',
                (s) => LogbookPage(sessionId: s.pathParameters['id']!),
                titleBuilder: (context) => context.tr.logbook,
                wide: true,
              ),
            ],
          ),
          workspaceRoute(
            path: '/session/:id',
            builder: (_, s) =>
                SessionDetailPage(sessionId: s.pathParameters['id']!),
            routes: [
              record(
                'attendance',
                'Appel de séance',
                (s) => AttendancePage(sessionId: s.pathParameters['id']!),
                wide: true,
              ),
              record(
                'logbook',
                'Cahier de texte',
                (s) => LogbookPage(sessionId: s.pathParameters['id']!),
                titleBuilder: (context) => context.tr.logbook,
                wide: true,
              ),
            ],
          ),
          workspaceRoute(
            path: '/progress',
            builder: (_, _) => const ProgressPage(),
            routes: [
              record(
                'cahier/:id',
                'Cahier de texte',
                (s) => LogbookPage(sessionId: s.pathParameters['id']!),
                titleBuilder: (context) => context.tr.logbook,
                wide: true,
              ),
            ],
          ),
          for (final path in [
            '/class-roll',
            '/classes',
            '/classes/:classId',
            '/class-roll/editor',
            '/classes/:classId/editor',
          ])
            GoRoute(path: path, redirect: (_, _) => '/home'),
          for (final path in [
            '/class-roll/context',
            '/classes/:classId/context',
          ])
            GoRoute(path: path, redirect: (_, _) => '/home/context'),
          for (final path in [
            '/class-roll/:classId/:studentId',
            '/classes/:classId/student/:studentId',
          ])
            GoRoute(
              path: path,
              redirect: (_, s) => Uri(
                pathSegments: [
                  '',
                  'home',
                  'student',
                  s.pathParameters['classId']!,
                  s.pathParameters['studentId']!,
                ],
              ).toString(),
            ),
          workspaceRoute(
            path: '/classes/:classId/attendance',
            builder: (_, s) =>
                DailyAttendancePage(classId: s.pathParameters['classId']!),
          ),
          workspaceRoute(
            path: '/classes/:classId/discipline',
            builder: (_, s) =>
                TeacherDisciplinePage(classId: s.pathParameters['classId']!),
          ),
          workspaceRoute(
            path: '/incidents',
            builder: (_, _) => const IncidentsPage(),
            routes: [
              record(
                'new',
                'Signaler un incident',
                (_) => const NewRecordForm(message: false),
                wide: true,
              ),
              record(
                ':classId/:incidentId',
                'Incident',
                (s) => TeacherDisciplinePage(
                  classId: s.pathParameters['classId']!,
                  incidentId: s.pathParameters['incidentId']!,
                  mode: s.uri.queryParameters['mode'],
                ),
                wide: true,
              ),
            ],
          ),
          workspaceRoute(
            path: '/evaluations',
            builder: (_, state) => EvaluationsPage(
              assessmentId: state.uri.queryParameters['assessment'],
            ),
            routes: [
              record(
                'create',
                'Créer une évaluation',
                (s) => const EvaluationCreatePage(),
              ),
              GoRoute(
                path: ':evaluationId/marks',
                redirect: (_, state) => Uri(
                  path: '/evaluations',
                  queryParameters: {
                    'assessment': state.pathParameters['evaluationId']!,
                  },
                ).toString(),
              ),
              record(
                'subject-comment/:classId/:periodId/:studentId',
                'Appréciation',
                (s) => ReportCardCommentPage(
                  classId: s.pathParameters['classId']!,
                  periodId: s.pathParameters['periodId']!,
                  rosterId: s.pathParameters['studentId']!,
                  subjectId: s.uri.queryParameters['subject'],
                ),
              ),
            ],
          ),
          workspaceRoute(
            path: '/evaluations/avis',
            builder: (_, _) => const FamilyFeedbackListPage(),
            routes: [
              record(
                ':feedbackId',
                'Avis des familles',
                (s) => FamilyFeedbackDetailPage(
                  feedbackId: s.pathParameters['feedbackId']!,
                ),
                wide: true,
              ),
            ],
          ),
          workspaceRoute(
            path: '/report-cards',
            builder: (_, _) => const BulletinsPage(),
            routes: [
              GoRoute(
                path: ':classId/:periodId',
                redirect: (context, s) async {
                  final scope = LScope.of(context)!;
                  await initializeTeacherAuthenticatedContext(scope);
                  final teacher = scope.find<TeacherContextController>();
                  final options = teacher.assignments.value.where(
                    (a) => a.classGroupId == s.pathParameters['classId'],
                  );
                  final own =
                      options
                          .where(
                            (a) => a.id == teacher.activeAssignmentId.value,
                          )
                          .firstOrNull ??
                      options.firstOrNull;
                  if (own == null) return '/report-cards?notice=access';
                  await teacher.selectAssignment(own.id);
                  scope.find<LiveEvaluationsController>().selectPeriod(
                    s.pathParameters['periodId']!,
                  );
                  return own.isHomeroom ? '/report-cards' : '/evaluations';
                },
              ),
              GoRoute(
                path: ':classId/:periodId/:rosterId',
                onExit: workspaceCanExit,
                redirect: (context, s) async {
                  final teacher = context.levit
                      .find<TeacherContextController>();
                  final options = teacher.assignments.value
                      .where(
                        (a) => a.classGroupId == s.pathParameters['classId'],
                      )
                      .toList();
                  if (options.any((a) => a.isHomeroom)) return null;
                  final own =
                      options
                          .where(
                            (a) => a.id == teacher.activeAssignmentId.value,
                          )
                          .firstOrNull ??
                      options.firstOrNull;
                  if (own?.classSubjectId == null) {
                    return '/report-cards?notice=access';
                  }
                  final evaluations = context.levit
                      .find<LiveEvaluationsController>();
                  await teacher.selectAssignment(own!.id);
                  evaluations.selectPeriod(s.pathParameters['periodId']!);
                  return '/evaluations/subject-comment/${s.pathParameters['classId']}/${s.pathParameters['periodId']}/${s.pathParameters['rosterId']}?subject=${own.classSubjectId}';
                },
                pageBuilder: (_, s) => RecordSheetPage(
                  key: s.pageKey,
                  title: 'Bulletin',
                  wide: true,
                  child: ReportCardCommentPage(
                    classId: s.pathParameters['classId']!,
                    periodId: s.pathParameters['periodId']!,
                    rosterId: s.pathParameters['rosterId']!,
                  ),
                ),
              ),
            ],
          ),
          GoRoute(
            path: '/evaluations/report-cards/:classId/:periodId',
            redirect: (_, s) =>
                '/report-cards/${s.pathParameters['classId']}/${s.pathParameters['periodId']}',
          ),
          GoRoute(
            path: '/evaluations/report-cards/:classId/:periodId/:rosterId',
            redirect: (_, s) =>
                '/report-cards/${s.pathParameters['classId']}/${s.pathParameters['periodId']}/${s.pathParameters['rosterId']}',
          ),
          workspaceRoute(
            path: '/inbox',
            builder: (_, _) => const InboxPage(),
            routes: [
              record(
                'new',
                'Nouvelle conversation',
                (_) => const NewRecordForm(message: true),
                wide: true,
              ),
              record(
                'conversation/:conversationId',
                'Conversation',
                (s) => ConversationPage(
                  conversationId: s.pathParameters['conversationId']!,
                ),
              ),
              record(
                'message/:id',
                'Message',
                (s) => MessageDetailPage(messageId: s.pathParameters['id']!),
              ),
            ],
          ),
          workspaceRoute(
            path: '/account',
            builder: (_, _) => const AccountPage(),
            routes: [
              record(
                'profile',
                'Mon compte',
                (s) => const AccountProfilePage(),
              ),
              record('settings', 'Préférences', (s) => const SettingsPage()),
            ],
          ),
          GoRoute(path: '/settings', redirect: (_, _) => '/account/settings'),
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

GoRoute record(
  String path,
  String title,
  Widget Function(GoRouterState) build, {
  bool wide = false,
  String Function(BuildContext)? titleBuilder,
}) => GoRoute(
  path: path,
  onExit: workspaceCanExit,
  pageBuilder: (context, s) => RecordSheetPage(
    key: s.pageKey,
    title: titleBuilder?.call(context) ?? title,
    wide: wide,
    child: build(s),
  ),
);

String _localTarget(GoRouterState state) {
  final uri = Uri.tryParse(state.uri.queryParameters['next'] ?? '/home');
  return uri != null &&
          !uri.hasAuthority &&
          !uri.hasScheme &&
          uri.path.startsWith('/') &&
          !['/login', '/profiles'].contains(uri.path)
      ? uri.toString()
      : '/home';
}
