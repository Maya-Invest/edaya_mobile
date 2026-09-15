import 'package:edaya_auth/edaya_auth.dart';
import 'package:edaya_shared/edaya_shared.dart';
import 'package:edaya_teacher/features/auth/session_storage.dart';
import 'package:edaya_teacher/features/context/academic_year_controller.dart';
import 'package:edaya_teacher/features/context/teacher_context_controller.dart';
import 'package:edaya_teacher/features/calendar/calendar_controller.dart';
import 'package:edaya_teacher/features/calendar/calendar_page.dart';
import 'package:edaya_teacher/features/calendar/models/teacher_session.dart';
import 'package:edaya_teacher/features/session/widgets/attendance_row_tile.dart';
import 'package:edaya_teacher/features/session/models/session_detail_models.dart';
import 'package:edaya_teacher/features/evaluations/widgets/mark_row_tile.dart';
import 'package:edaya_teacher/features/evaluations/models/evaluation_models.dart';
import 'package:edaya_teacher/features/app_shell/app_shell_page.dart';
import 'package:edaya_teacher/features/app_shell/app_shell_controller.dart';
import 'package:edaya_teacher/app/router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:levit_flutter/levit_flutter.dart';
import '../../../scripts/design-review/support.dart';

class _Session implements AppSessionController {
  @override
  dynamic noSuchMethod(Invocation i) =>
      throw StateError('No session calls in visual fixtures: $i');
}

class _Storage implements SessionStorage {
  @override
  dynamic noSuchMethod(Invocation i) =>
      throw StateError('No storage calls in visual fixtures: $i');
}

class _Auth implements AuthClient {
  @override
  dynamic noSuchMethod(Invocation i) =>
      throw StateError('No auth calls in visual fixtures: $i');
}

class _Router implements AppRouter {
  @override
  dynamic noSuchMethod(Invocation i) =>
      throw StateError('No navigation in visual fixtures: $i');
}

Never _noApi() => throw StateError('No API calls in visual fixtures');

class _Teacher extends TeacherContextController {
  _Teacher(AcademicYearController year)
    : super(
        sessionStorage: _Storage(),
        session: _Session(),
        academicYear: year,
        schoolClient: _noApi,
      ) {
    teacherId('fixture');
    assignedClasses([const AssignedClass(id: 'fixture', label: '6e A')]);
    classFilterId('fixture');
  }
  // Visual fixtures intentionally bypass network subscriptions; live journeys test lifecycle.
  @override
  // ignore: must_call_super
  void onInit() {} // Fixture values replace data loading, never production behavior.
}

class _Calendar extends CalendarController {
  @override
  DataStatus get dataStatus => DataStatus.ready;
  _Calendar(TeacherContextController teacher, AcademicYearController year)
    : super(teacherContext: teacher, academicYear: year, schoolClient: _noApi) {
    weekStart(DateTime(2026, 9, 14));
    selectedDay(DateTime(2026, 9, 14));
    sessions([
      for (final (i, title) in [
        'Mathématiques',
        'Géométrie — droites et angles',
        'Accompagnement personnalisé',
      ].indexed)
        TeacherSession.fromOccurrence(
          TimetableOccurrence(
            id: 'fixture-$i',
            title: title,
            subjectLabel: 'Mathématiques',
            kind: 'lesson',
            startsAt: DateTime(2026, 9, 14, 8 + i),
            endsAt: DateTime(2026, 9, 14, 9 + i),
            classGroupId: 'fixture',
            classSubjectId: 'fixture',
          ),
          classLabel: '6e A',
        ),
    ]);
  }
  // Visual fixtures intentionally bypass network subscriptions; live journeys test lifecycle.
  @override
  // ignore: must_call_super
  void onInit() {}
}

void main() {
  setUpAll(loadReviewFonts);
  setUp(Levit.reset);
  for (final config in reviewCases) {
    for (final screen in ['calendar', 'attendance-marks-components', 'login']) {
      if (config.keyboardInset > 0 && screen != 'login') continue;
      testWidgets('Teacher $screen ${config.name}', (tester) async {
        final year = AcademicYearController(
          sessionStorage: _Storage(),
          session: _Session(),
          schoolClient: _noApi,
        );
        final teacher = _Teacher(year), calendar = _Calendar(teacher, year);
        final router = GoRouter(
          initialLocation: '/calendar',
          routes: [
            GoRoute(
              path: '/calendar',
              builder: (context, state) {
                if (screen == 'login')
                  return LoginPage(
                    appTitle: 'EDAYA Teacher',
                    subtitle: context.tr.loginSubtitleStaffDev,
                    defaultEmail: '',
                    onSignInSuccess: () async {},
                  ).buildView(context, context.levit.find<LoginController>());
                if (screen == 'attendance-marks-components')
                  return Scaffold(
                    appBar: AppBar(title: const Text('6e A · Mathématiques')),
                    body: ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        Text(
                          context.tr.attendance,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        for (final (i, status) in [
                          SessionAttendanceStatus.present,
                          SessionAttendanceStatus.late,
                          SessionAttendanceStatus.absent,
                        ].indexed)
                          AttendanceRowTile(
                            row: SessionStudentRow(
                              studentId: 'fixture-$i',
                              studentName: [
                                'Aminata Mariam Koné-Diabaté',
                                'Issa Traoré',
                                'Fatou Bamba',
                              ][i],
                              studentInitials: 'AB',
                              status: status,
                            ),
                            onStatusTap: () {},
                          ),
                        const SizedBox(height: 24),
                        Text(
                          context.tr.navEvaluations,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        MarkRowTile(
                          row: const StudentMarkRow(
                            studentId: 'fixture',
                            studentName: 'Aminata Mariam Koné-Diabaté',
                            score: 16.5,
                          ),
                          onEditScore: () {},
                        ),
                        MarkRowTile(
                          row: const StudentMarkRow(
                            studentId: 'fixture-locked',
                            studentName: 'Issa Traoré',
                            score: 14,
                            marksLocked: true,
                          ),
                          onEditScore: () {},
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          initialValue: '16.5',
                          decoration: const InputDecoration(
                            labelText: 'Note / Score',
                          ),
                        ),
                      ],
                    ),
                  );
                return AppShellPage(
                  child: const CalendarPage().buildView(context, calendar),
                ).buildView(context, AppShellController(appRouter: _Router()));
              },
            ),
          ],
        );
        addTearDown(router.dispose);
        await captureReview(
          tester,
          '$screen-${config.name}',
          reviewScope(
            dependencies: (scope) {
              scope.put(
                () => LoginController(
                  authClient: _Auth(),
                  session: _Session(),
                  defaultEmail: '',
                  onSignInSuccess: () async {},
                ),
              );
              scope.put<AcademicYearController>(() => year);
              scope.put<TeacherContextController>(() => teacher);
              scope.put<CalendarController>(() => calendar);
            },
            child: MaterialApp.router(
              debugShowCheckedModeBanner: false,
              routerConfig: router,
              theme: AppTheme.light,
              darkTheme: AppTheme.dark,
              themeMode: config.dark ? ThemeMode.dark : ThemeMode.light,
              locale: Locale(config.locale),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: TextScaler.linear(config.scale)),
                child: child!,
              ),
            ),
          ),
          config.size,
          keyboardInset: config.keyboardInset,
        );
      });
    }
  }
  testWidgets('Locked marks keep the edit action disabled', (tester) async {
    var edits = 0;
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: MarkRowTile(
            row: const StudentMarkRow(
              studentId: 'fixture',
              studentName: 'Aminata',
              marksLocked: true,
            ),
            onEditScore: () => edits++,
          ),
        ),
      ),
    );
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNull,
    );
    expect(edits, 0);
  });
}
