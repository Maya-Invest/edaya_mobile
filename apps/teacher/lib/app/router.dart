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
import '../features/session/session_detail_page.dart';

GoRouter createRouter({
  bool demo = false,
  required Listenable routerRefresh,
  required bool Function() isAuthenticated,
  bool Function()? isBootstrapping,
}) {
  GoRouter.optionURLReflectsImperativeAPIs = true;
  return GoRouter(
    overridePlatformDefaultLocation: demo,
    initialLocation: '/login',
    onEnter: workspaceCanEnter,
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
                (context) => context.tr.student,
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
              for (final tail in ['', '/attendance', '/logbook'])
                GoRoute(
                  path: 'lesson/:id$tail',
                  redirect: (_, s) =>
                      _sessionLocation(s, logbook: tail == '/logbook'),
                ),
            ],
          ),
          workspaceRoute(
            path: '/session/:id',
            builder: (_, s) => SessionDetailPage(
              key: ValueKey(s.pathParameters['id']),
              sessionId: s.pathParameters['id']!,
              logbook: s.uri.queryParameters['tab'] == 'logbook',
            ),
            routes: [
              for (final entry in ['attendance', 'logbook'])
                GoRoute(
                  path: entry,
                  redirect: (_, s) =>
                      _sessionLocation(s, logbook: entry == 'logbook'),
                ),
            ],
          ),
          workspaceRoute(
            path: '/progress',
            builder: (_, _) => const ProgressPage(),
            routes: [
              GoRoute(
                path: 'cahier/:id',
                redirect: (_, s) => _sessionLocation(s, logbook: true),
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
            builder: (_, s) => DailyAttendancePage(
              key: ValueKey(s.pathParameters['classId']),
              classId: s.pathParameters['classId']!,
              initialDate: DateTime.tryParse(
                s.uri.queryParameters['date'] ?? '',
              ),
            ),
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
                (context) => context.tr.reportAnIncident,
                (_) => const NewRecordForm(message: false),
                wide: true,
              ),
              record(
                ':classId/:incidentId',
                (context) => context.tr.incident,
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
                (context) => context.tr.createAssessment,
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
                (context) => context.tr.reportComment,
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
                (context) => context.tr.teacherTaskFamilyFeedback,
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
                pageBuilder: (context, s) => RecordSheetPage(
                  key: s.pageKey,
                  title: context.tr.reportCard,
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
                (context) => context.tr.newConversation,
                (_) => const NewRecordForm(message: true),
                wide: true,
              ),
              record(
                'conversation/:conversationId',
                (context) => context.tr.conversation,
                (s) => ConversationPage(
                  conversationId: s.pathParameters['conversationId']!,
                ),
              ),
              record(
                'message/:id',
                (context) => context.tr.messageDefaultTitle,
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
                (context) => context.tr.myAccount,
                (s) => const AccountProfilePage(),
              ),
              record(
                'settings',
                (context) => context.tr.preferences,
                (s) => const SettingsPage(),
              ),
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
  String Function(BuildContext) title,
  Widget Function(GoRouterState) build, {
  bool wide = false,
}) => GoRoute(
  path: path,
  onExit: workspaceCanExit,
  pageBuilder: (context, s) => RecordSheetPage(
    key: s.pageKey,
    title: title(context),
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

String _sessionLocation(GoRouterState s, {required bool logbook}) => Uri(
  pathSegments: ['', 'session', s.pathParameters['id']!],
  queryParameters: logbook ? {'tab': 'logbook'} : null,
).toString();
