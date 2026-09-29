@Tags(['integration'])
library;

import 'package:edaya_api_client/edaya_api_client.dart';
import 'package:edaya_integration_tests/edaya_integration_tests.dart';
import 'package:edaya_teacher/features/account/account_page.dart';
import 'package:edaya_teacher/features/classes/classes_page.dart';
import 'package:edaya_teacher/features/context/teacher_context_controller.dart';
import 'package:edaya_teacher/features/home/home_page.dart';
import 'package:edaya_teacher/features/login/login_page.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:levit_flutter/levit_flutter.dart';

import 'support/integration_test_lifecycle.dart';
import 'support/live_api_test_binding.dart';
import 'support/teacher_live_widget_test_harness.dart';

Future<void> until(WidgetTester tester, Finder finder) async {
  final deadline = DateTime.now().add(const Duration(seconds: 30));
  while (DateTime.now().isBefore(deadline)) {
    await tester.pump(const Duration(milliseconds: 100));
    if (tester.any(finder)) return;
  }
  fail('Expected loaded teacher widget: $finder');
}

Future<void> main() async {
  LiveApiWidgetTestBinding();
  Levit.enableAutoLinking();
  await initializeDateFormatting('fr_FR');
  final skip = await resolveIntegrationSkipReason();
  if (skip != null) {
    testWidgets('teacher live suite disabled', (_) async {}, skip: true);
    return;
  }
  for (final profile in TeacherPortalProfile.demoCiProfiles) {
    group(profile.kind.name, () {
      late TeacherLiveWidgetTestHarness harness;
      late PortalSession readSession;
      setUpAll(() async {
        final baseline = await TeacherLiveWidgetTestHarness.create(
          profile: profile,
        );
        readSession = baseline.portalSession;
      });
      setUp(() async {
        harness = await TeacherLiveWidgetTestHarness.create(
          profile: profile,
          authenticatedSession: readSession,
        );
      });
      Future<void> mount(WidgetTester tester, String route) async {
        await resetIntegrationTestSurface(tester);
        await configureDesignReviewViewport(
          tester,
          DesignReviewFormFactor.phone,
        );
        addTearDown(() async {
          await resetIntegrationTestSurface(tester);
          await resetIntegrationTestViewport(tester);
        });
        await tester.pumpWidget(harness.buildRouterApp(initialRoute: route));
      }

      testWidgets(
        '[teacher.${profile.kind.name}.bootstrap] loads assigned teaching context',
        (tester) async {
          await mount(tester, '/home');
          await until(tester, find.byType(HomePage));
          final context = harness.scope.find<TeacherContextController>();
          expect(context.teacherId.value, harness.context.grants.actorId);
          expect(context.errorMessage.value, isEmpty);
          expect(context.assignments.value, isNotEmpty);
          expect(
            context.assignments.value.map((a) => a.classGroupId),
            containsAll(profile.expectedClassGroupIds),
          );
          expect(
            context.assignments.value.any((a) => a.isHomeroom),
            profile.kind == TeacherPortalKind.homeroom,
          );
        },
      );

      testWidgets(
        '[teacher.${profile.kind.name}.roster] opens a real assigned class and student',
        (tester) async {
          final rows = await harness.portalSession.schoolClient.enrollments
              .list(
                activeEnrollmentsForClass(
                  profile.primaryClassGroupId,
                  academicYearId: profile.academicYearId,
                ),
              );
          expect(rows, isNotEmpty, reason: 'Required enrolled-student fixture');
          final student = await harness.portalSession.schoolClient.students.get(
            rows.first['studentId'] as String,
          );
          final name = '${student['firstName']} ${student['lastName']}';
          await mount(tester, '/classes/${profile.primaryClassGroupId}');
          await until(tester, find.byType(ClassRosterPage));
          await until(tester, find.byType(ListView));
          await tester.scrollUntilVisible(
            find.text(name),
            200,
            scrollable: find.byType(Scrollable).last,
            maxScrolls: 40,
          );
          expect(find.byType(ClassRosterPage), findsOneWidget);
          await Scrollable.ensureVisible(
            tester.element(find.text(name).first),
            alignment: 0.4,
          );
          await tester.pump();
          await until(tester, find.text(name).hitTestable());
          await tester.tap(find.text(name).hitTestable().first);
          await until(tester, find.byType(StudentProfilePage));
          await until(tester, find.text(name));
          expect(
            harness.scope
                .find<GoRouter>()
                .routeInformationProvider
                .value
                .uri
                .path,
            '/classes/${profile.primaryClassGroupId}/student/${student['id']}',
          );
        },
      );

      testWidgets(
        '[teacher.${profile.kind.name}.account] shows authenticated account and profile',
        (tester) async {
          await mount(tester, '/account');
          await until(tester, find.text(profile.email));
          expect(find.byType(AccountPage), findsOneWidget);
          harness.scope.find<GoRouter>().go('/account/profile');
          await until(tester, find.byType(AccountProfilePage));
          await until(tester, find.text(profile.email));
        },
      );

      testWidgets(
        '[teacher.${profile.kind.name}.logout] logout returns to login and rejects session reuse',
        (tester) async {
          harness = await TeacherLiveWidgetTestHarness.create(profile: profile);
          await mount(tester, '/account');
          await until(tester, find.text('Se déconnecter'));
          await tester.ensureVisible(find.text('Se déconnecter'));
          await tester.tap(find.text('Se déconnecter'));
          await until(tester, find.byType(LoginPage));
          final session = await harness.portalSession.authClient.getSession();
          expect(session.data, isNull);
          harness.scope.find<GoRouter>().go('/classes');
          await tester.pump();
          await until(tester, find.byType(LoginPage));
          expect(find.byType(ClassesPage), findsNothing);
        },
      );
    });
  }
}
