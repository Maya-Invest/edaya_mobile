import 'package:edaya_auth/edaya_auth.dart';
import 'package:edaya_shared/edaya_shared.dart';
import 'package:edaya_guardian/features/auth/session_storage.dart';
import 'package:edaya_guardian/features/context/academic_year_controller.dart';
import 'package:edaya_guardian/features/context/student_context_controller.dart';
import 'package:edaya_guardian/features/calendar/calendar_controller.dart';
import 'package:edaya_guardian/features/calendar/calendar_page.dart';
import 'package:edaya_guardian/features/calendar/models/calendar_session.dart';
import 'package:edaya_guardian/features/fees/fees_controller.dart';
import 'package:edaya_guardian/features/fees/fees_page.dart';
import 'package:edaya_guardian/features/fees/models/payment_record.dart';
import 'package:edaya_guardian/features/fees/models/student_charge_line.dart';
import 'package:edaya_guardian/features/my_students/linked_student.dart';
import 'package:edaya_guardian/features/app_shell/app_shell_page.dart';
import 'package:edaya_guardian/features/app_shell/app_shell_controller.dart';
import 'package:edaya_guardian/app/router.dart';
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

class _Student extends StudentContextController {
  _Student(AcademicYearController year)
    : super(
        sessionStorage: _Storage(),
        session: _Session(),
        academicYear: year,
        schoolClient: _noApi,
      ) {
    activeStudent(
      const LinkedStudent(
        id: 'fixture',
        firstName: 'Aminata Mariam',
        lastName: 'Koné-Diabaté',
        status: 'active',
      ),
    );
    classLabel('6e A · Collège EDAYA');
    isEnrolled(true);
  }
  // Visual fixtures intentionally bypass network subscriptions; live journeys test lifecycle.
  @override
  // ignore: must_call_super
  void onInit() {} // Fixture values replace data loading, never production behavior.
}

class _Calendar extends CalendarController {
  @override
  DataStatus get dataStatus => DataStatus.ready;
  _Calendar(StudentContextController student, AcademicYearController year)
    : super(studentContext: student, academicYear: year, schoolClient: _noApi) {
    weekStart(DateTime(2026, 9, 14));
    selectedDay(DateTime(2026, 9, 14));
    sessions([
      for (final (i, title) in [
        'Mathématiques',
        'Français — lecture et expression',
        'Sciences de la vie et de la Terre',
      ].indexed)
        CalendarSession(
          id: 'fixture-$i',
          title: title,
          subjectLabel: title,
          kind: 'lesson',
          startsAt: DateTime(2026, 9, 14, 8 + i),
          endsAt: DateTime(2026, 9, 14, 9 + i),
        ),
    ]);
  }
  // Visual fixtures intentionally bypass network subscriptions; live journeys test lifecycle.
  @override
  // ignore: must_call_super
  void onInit() {}
}

class _Fees extends FeesController {
  @override
  DataStatus get dataStatus => DataStatus.ready;
  _Fees(StudentContextController student, AcademicYearController year)
    : super(studentContext: student, academicYear: year, schoolClient: _noApi) {
    summary(
      const FeesSummary(
        available: 20000,
        outstanding: 800000,
        overdue: 400000,
        currency: 'XOF',
      ),
    );
    charges([
      StudentChargeLine(
        id: 'fixture',
        label: 'Scolarité annuelle',
        expectedAmount: 1250000,
        allocatedAmount: 450000,
        adjustmentAmount: 0,
        waiverAmount: 0,
        currency: 'XOF',
        status: ChargeStatus.partial,
        dueDate: DateTime(2026, 9, 1),
        installments: [
          ChargeInstallment(
            id: 'fixture-inst-1',
            label: 'Trimestre 1',
            expectedAmount: 625000,
            dueDate: DateTime(2026, 9, 1),
          ),
          ChargeInstallment(
            id: 'fixture-inst-2',
            label: 'Trimestre 2',
            expectedAmount: 625000,
            dueDate: DateTime(2027, 1, 15),
          ),
        ],
        settlementCount: 1,
      ),
    ]);
    payments([
      PaymentRecord(
        id: 'fixture',
        feeLabel: 'Scolarité annuelle',
        amount: 450000,
        currency: 'XOF',
        paymentDate: DateTime(2026, 9, 1),
        method: 'cash',
        status: 'recorded',
        kind: 'receipt',
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
    for (final screen in ['calendar', 'fees', 'login']) {
      if (config.keyboardInset > 0 && screen != 'login') continue;
      testWidgets('Guardian $screen ${config.name}', (tester) async {
        final year = AcademicYearController(
          sessionStorage: _Storage(),
          session: _Session(),
          schoolClient: _noApi,
        );
        year.years([
          {'id': 'fixture', 'name': '2026 – 2027'},
        ]);
        year.selectedYearId('fixture');
        final student = _Student(year),
            calendar = _Calendar(_Student(year), year),
            fees = _Fees(student, year);
        final router = GoRouter(
          initialLocation: '/$screen',
          routes: [
            GoRoute(
              path: '/$screen',
              builder: (context, state) {
                if (screen == 'login')
                  return LoginPage(
                    appTitle: 'EDAYA Guardian',
                    subtitle: context.tr.loginSubtitleGuardianDev,
                    defaultEmail: '',
                    onSignInSuccess: () async {},
                  ).buildView(context, context.levit.find<LoginController>());
                final body = screen == 'calendar'
                    ? const CalendarPage().buildView(context, calendar)
                    : const FeesPage().buildView(context, fees);
                return AppShellPage(
                  child: body,
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
              scope.put<StudentContextController>(() => student);
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
}
