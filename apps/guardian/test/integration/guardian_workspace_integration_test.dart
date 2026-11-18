@Tags(['integration'])
library;

import 'package:edaya_guardian_v2/app/workspace_shell.dart';
import 'package:edaya_guardian_v2/design/components/list_row.dart';
import 'package:edaya_guardian_v2/design/components/summary_metric.dart';
import 'package:edaya_api_client/edaya_api_client.dart';
import 'package:edaya_guardian_v2/features/calendar/session_detail_page.dart';
import 'package:edaya_guardian_v2/features/home/home_page.dart';
import 'package:edaya_guardian_v2/features/fees/payment_detail_page.dart';
import 'package:edaya_guardian_v2/features/home/dashboard_controller.dart';
import 'package:edaya_guardian_v2/features/context/academic_year_controller.dart';
import 'package:edaya_guardian_v2/features/context/student_context_controller.dart';
import 'package:edaya_guardian_v2/features/scolarite/results_page.dart';
import 'package:edaya_guardian_v2/features/scolarite/subject_grades_page.dart';
import 'package:edaya_guardian_v2/features/context/child_picker.dart';
import 'package:edaya_integration_tests/edaya_integration_tests.dart';
import 'package:edaya_shared/edaya_shared.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:levit_flutter/levit_flutter.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'support/guardian_widget_test_harness.dart';
import 'support/live_api_test_binding.dart';
import 'support/pump_guardian_page.dart';
import 'support/pump_until_found.dart';
import 'support/design_review_environment.dart';

Future<void> main() async {
  LiveApiWidgetTestBinding();
  Levit.enableAutoLinking();
  tz.initializeTimeZones();
  final skip = await resolveIntegrationSkipReason();
  if (skip != null) {
    testWidgets('guardian v2 integrations disabled', (_) async {}, skip: true);
    return;
  }
  setUpAll(() async {
    await initializeDateFormatting('fr_FR');
    await loadDesignReviewFonts();
  });

  testWidgets(
    '[guardian-v2.workspace.home] home has child context and two menu groups',
    (tester) async {
      final h = await GuardianWidgetTestHarness.create();
      await pumpGuardianShellUntil<HomePage>(tester, h, initialRoute: '/home');
      final dashboard = tester
          .element(
            find.byWidgetPredicate(
              (w) => w.runtimeType.toString() == '_Dashboard',
            ),
          )
          .levit
          .find<DashboardController>();
      final deadline = DateTime.now().add(const Duration(seconds: 30));
      while (dashboard.sessions.value == null &&
          dashboard.errors.value.isEmpty &&
          DateTime.now().isBefore(deadline)) {
        await tester.pump(const Duration(milliseconds: 200));
      }
      expect(
        dashboard.sessions.value,
        isNotNull,
        reason: 'Home must finish its initial timetable read',
      );
      await tester.pump(const Duration(milliseconds: 200));
      expect(
        find.byType(LinearProgressIndicator),
        findsNothing,
        reason: 'Loaded sessions must replace the visible loading indicator',
      );
      await pumpUntilFound(tester, find.text('Bulletin disponible'));
      expect(find.byType(ChildContextCard), findsOneWidget);
      expect(find.byType(NavigationBar), findsNothing);
      await pumpUntilFound(tester, find.text('Scolarité'));
      await tester.scrollUntilVisible(
        find.text('Vie scolaire'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Vie scolaire'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    '[guardian-v2.workspace.menu] all menu destinations resolve with real data',
    (tester) async {
      final h = await GuardianWidgetTestHarness.create();
      final profile = h.profile!;
      final owner = await PortalSession.signIn(
        config: IntegrationConfig.fromEnvironment().withSchoolOwnerEmail(),
        actorKind: 'staff',
        academicYearId: profile.academicYearId,
      );
      final feedback = await createFeedbackFixture(
        owner,
        teacherId: 'ci-t1',
        classGroupId: profile.primaryClassGroupId,
        academicYearId: profile.academicYearId,
      );
      final campaignId = feedback['id'] as String;
      addTearDown(() => disposeFeedbackFixture(owner, campaignId));
      await pumpGuardianShellUntil<HomePage>(tester, h, initialRoute: '/home');
      for (final d in destinations) {
        final menuLabel = find
            .descendant(of: find.byType(HomePage), matching: find.text(d.fr))
            .first;
        await tester.ensureVisible(menuLabel);
        await pumpUntilFound(tester, menuLabel.hitTestable());
        await tester.tap(menuLabel.hitTestable());
        await tester.pump(const Duration(seconds: 1));
        await pumpUntilFound(tester, find.byType(BackButton));
        final loadedContent = switch (d.path) {
          '/calendar' => find.text('Toutes les présences'),
          '/scolarite/progress' => find.text('Cahier de texte'),
          '/scolarite/notes' => find.text('Bulletin publié'),
          '/attendance' => find.text('Appel du jour'),
          '/fees' => find.text('Attendu'),
          '/inbox' => find.text('Nouveau message'),
          '/inbox/avis' => await campaignRow(tester, h, campaignId),
          '/child' => find.text('Documents'),
          _ => throw StateError('Missing content check for ${d.path}'),
        };
        await pumpUntilFound(tester, loadedContent);
        expect(find.byType(RouteErrorPage), findsNothing, reason: d.path);
        expect(tester.takeException(), isNull, reason: d.path);
        if (d.path == '/calendar') {
          final date =
              IntegrationConfig.fromEnvironment().calendarReferenceDate;
          final timetable = await h.portalSession!.schoolClient
              .getStudentTimetable({
                'studentId': h.profile!.primaryStudentId,
                'startDate': date,
                'endDate': date,
              });
          final event = (timetable['events'] as List).first as Map;
          h.router.push(
            '/session/${Uri.encodeComponent(event['id'] as String)}',
          );
          final detailPage = find.byType(SessionDetailPage);
          await pumpUntilFound(
            tester,
            find.descendant(
              of: detailPage,
              matching: find.text(
                event['subjectLabel'] as String? ?? event['title'] as String,
              ),
            ),
          );
          expect(
            find.descendant(of: detailPage, matching: find.text('Horaire')),
            findsOneWidget,
          );
          h.router.pop();
          await tester.pump(const Duration(milliseconds: 400));
        }
        if (d.path == '/fees') {
          final client = h.portalSession!.schoolClient;
          final query = {
            'studentId': h.profile!.primaryStudentId,
            'academicYearId': h.profile!.academicYearId,
          };
          final charges = await client.studentCharges.listAll(query);
          final charge = charges.firstWhere((r) => r['label'] == 'Scolarité A');
          h.router.push('/fees/fee/${charge['id']}');
          await pumpUntilFound(tester, find.text('Scolarité A'));
          expect(find.byTooltip('Fermer'), findsOneWidget);
          h.router.pop();
          await tester.pump(const Duration(milliseconds: 400));
          final summary = await client.getStudentFinanceSummary(query);
          final history = await client.getPaymentSettlementHistory({
            'accountId': summary['accountId'],
          });
          final receipt = (history['payments'] as List).cast<Map>().firstWhere(
            (r) => r['kind'] == 'receipt',
          );
          final allocatedChargeIds = (history['allocations'] as List)
              .cast<Map>()
              .where(
                (a) =>
                    a['causedByPaymentId'] == receipt['id'] &&
                    a['kind'] != 'reverse',
              )
              .map((a) => a['chargeId'])
              .toSet();
          final expectedFees = charges
              .where((c) => allocatedChargeIds.contains(c['id']))
              .map((c) => c['label'] as String)
              .toSet();
          expect(expectedFees, isNotEmpty);
          h.router.push('/fees/payment/${receipt['id']}');
          final feeMetric = find.byWidgetPredicate(
            (widget) => widget is SummaryMetric && widget.label == 'Frais',
          );
          await pumpUntilFound(tester, feeMetric);
          expect(
            tester.widget<SummaryMetric>(feeMetric).value.split(', '),
            unorderedEquals(expectedFees),
          );
          expect(
            find.descendant(
              of: find.byType(PaymentDetailPage),
              matching: find.text(
                lookupAppLocalizations(h.appLocale).paymentKindReceipt,
              ),
            ),
            findsOneWidget,
          );
          h.router.pop();
          await tester.pump(const Duration(milliseconds: 400));
        }
        h.router.go('/home');
        await pumpUntilFound(tester, find.byType(HomePage));
      }
    },
  );
  testWidgets(
    '[guardian-v2.workspace.children] picker selects an authorized sibling',
    (tester) async {
      final h = await GuardianWidgetTestHarness.create();
      await pumpGuardianShellUntil<HomePage>(tester, h, initialRoute: '/home');
      await h.scope.find<AppSessionController>().refreshGrants();
      h.router.push('/children');
      await pumpUntilFound(tester, find.byType(ChildPicker));
      final sibling = h.context!.linkedStudents.firstWhere(
        (r) => r['id'] != h.profile!.primaryStudentId,
      );
      final name = '${sibling['firstName']} ${sibling['lastName']}';
      await pumpUntilFound(tester, find.text(name));
      await tester.tap(find.text(name));
      await pumpUntilFound(tester, find.byType(HomePage));
      await tester.pump(const Duration(milliseconds: 400));
      expect(
        h.scope.find<StudentContextController>().activeStudentId,
        sibling['id'],
      );
      expect(find.byTooltip('Fermer'), findsNothing);
    },
  );
  testWidgets(
    '[guardian-v2.results.drilldown] published modules open subject marks',
    (tester) async {
      final h = await GuardianWidgetTestHarness.create();
      final client = h.portalSession!.schoolClient;
      final reports = await client.results.listAll({
        'studentId': h.profile!.primaryStudentId,
        'status': 'published',
      });
      expect(reports, isNotEmpty);
      final period = reports.first['periodId'] as String;
      final data = await client.runQuery('get-guardian-period-results', {
        'studentId': h.profile!.primaryStudentId,
        'periodId': period,
      });
      expect(data['state'], 'published');
      await pumpGuardianShellUntil<ResultsPage>(
        tester,
        h,
        initialRoute: '/scolarite/notes?period=$period',
      );
      await pumpUntilFound(tester, find.text('Bulletin publié'));
      final sections = (data['sections'] as List).cast<Map>();
      expect(sections, isNotEmpty);
      final module = sections.first;
      final subject = module['sectionKind'] == 'module'
          ? (module['subResults'] as List).first as Map
          : module;
      if (module['sectionKind'] == 'module') {
        await tester.ensureVisible(find.text(module['name'] as String).first);
        await tester.tap(find.text(module['name'] as String).first);
        await tester.pump(const Duration(milliseconds: 400));
      }
      await tester.ensureVisible(find.text(subject['name'] as String).first);
      await tester.tap(find.text(subject['name'] as String).first);
      await pumpUntilFound(tester, find.byType(SubjectGradesPage));
      await pumpUntilFound(tester, find.text('Toutes les notes'));
      final marks = (data['marks'] as List)
          .cast<Map>()
          .where(
            (m) =>
                m['subjectId'] == subject['subjectId'] ||
                m['classSubjectId'] == subject['classSubjectId'],
          )
          .toList();
      if (marks.isNotEmpty) {
        final title = find.text(marks.first['title'] as String).first;
        await tester.scrollUntilVisible(
          title,
          250,
          scrollable: find.byType(Scrollable).last,
        );
        await tester.tap(title);
        await tester.pump(const Duration(milliseconds: 400));
      }
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    '[guardian-v2.results.archive] results archive leaves home year unchanged',
    (tester) async {
      final h = await GuardianWidgetTestHarness.create();
      await pumpGuardianShellUntil<HomePage>(tester, h, initialRoute: '/home');
      final year = h.scope.find<AcademicYearController>().selectedYearId.value;
      final alternate = h.context!.academicYears
          .where((r) => r['id'] != year)
          .firstOrNull;
      h.router.push('/scolarite/notes?year=${alternate?['id'] ?? year}');
      await tester.pump(const Duration(seconds: 1));
      expect(h.scope.find<AcademicYearController>().selectedYearId.value, year);
      h.router.go('/home');
      await tester.pump(const Duration(milliseconds: 400));
      expect(h.scope.find<AcademicYearController>().selectedYearId.value, year);
      expect(tester.takeException(), isNull);
    },
  );
}

Future<Finder> campaignRow(
  WidgetTester tester,
  GuardianWidgetTestHarness harness,
  String campaignId,
) async {
  final campaigns = await listGuardianFamilyFeedbackCampaigns(
    harness.portalSession!.schoolClient,
  );
  final studentId = harness.scope
      .find<StudentContextController>()
      .activeStudentId;
  final campaign = campaigns.singleWhere(
    (row) => row.studentId == studentId && row.campaignId == campaignId,
  );
  expect(campaign.slotState, 'open');
  final labels = tester.element(find.byType(BackButton)).tr;
  final title = campaign.context?.subjectName.isNotEmpty == true
      ? '${campaign.context!.subjectName} · ${campaign.context!.teacherName}'
      : labels.familyFeedbackTitle;
  return find.byWidgetPredicate(
    (widget) =>
        widget is ListRow &&
        widget.title == title &&
        widget.subtitle == labels.familyFeedbackSlotOpen,
  );
}
