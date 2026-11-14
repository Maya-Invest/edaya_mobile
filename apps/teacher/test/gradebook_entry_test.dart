import 'dart:async';
import 'package:go_router/go_router.dart';
import 'package:edaya_teacher_v2/app/workspace_navigation.dart';
import 'package:levit_flutter/levit_flutter.dart';
import 'package:edaya_api_client/edaya_api_client.dart' as api;
import 'package:edaya_shared/edaya_shared.dart';
import 'package:edaya_teacher_v2/features/context/academic_year_controller.dart';
import 'package:edaya_teacher_v2/features/context/teacher_context_controller.dart';
import 'package:edaya_teacher_v2/features/evaluations/live_evaluations_controller.dart';
import 'package:edaya_teacher_v2/features/evaluations/live_marks_controller.dart';
import 'package:edaya_teacher_v2/features/evaluations/gradebook_marks_view.dart';
import 'package:edaya_teacher_v2/design/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Evaluations extends Fake implements LiveEvaluationsController {
  @override
  LiveEvaluationSummary? evaluationById(String id) =>
      const LiveEvaluationSummary(
        id: 'a',
        title: 'Math',
        classGroupId: 'c',
        classSubjectId: 's',
        periodId: 'p',
        classLabel: 'Class',
        subjectLabel: 'Math',
        gradedCount: 0,
        totalStudents: 2,
      );
}

class _Year extends Fake implements AcademicYearController {}

class _Teacher extends Fake implements TeacherContextController {}

class _Client extends Fake implements api.SchoolClient {
  final writes = <Map<String, dynamic>>[];
  final results = <Map<String, dynamic>>[];
  final proposals = <Map<String, dynamic>>[];
  int revision = 0;
  bool offline = false, reject = false, submitted = false;
  @override
  Future<Map<String, dynamic>> runQuery(
    String name,
    Map<String, dynamic> input,
  ) async => {
    'assessment': {
      'id': 'a',
      'marksStatus': submitted ? 'submitted' : 'draft',
      'marksRevision': revision,
    },
    'allowedActions': {'submit': true, 'requestCorrection': true},
    'publishedResultIds': [],
    'corrections': proposals,
    'students': [
      for (final id in ['one', 'two'])
        {'id': id, 'firstName': id, 'lastName': 'Pupil'},
    ],
    'results': results,
  };
  @override
  Future<List<Map<String, dynamic>>> runListCommand(
    String name,
    Map<String, dynamic> input,
  ) async {
    await runCommand(name, input);
    return results;
  }

  @override
  Future<Map<String, dynamic>> runCommand(
    String name,
    Map<String, dynamic> input,
  ) async {
    writes.add({'command': name, ...input});
    if (offline) throw TimeoutException('Offline');
    if (reject) throw StateError('Permission denied');
    if (name == 'record-assessment-results') {
      if (input['expectedRevision'] != revision)
        throw api.ApiError(409, 'MARKS_REVISION_CONFLICT');
      for (final raw in input['results'] as List) {
        final row = Map<String, dynamic>.from(raw as Map);
        results.removeWhere((r) => r['studentId'] == row['studentId']);
        results.add(row);
        revision++;
      }
    } else if (name == 'submit-assessment-marks') {
      expect(input['expectedRevision'], revision);
      submitted = true;
    }
    return {'id': 'saved'};
  }
}

Future<LiveMarksController> _make(
  _Client client,
  TeacherOutboxStore store,
) async {
  final evaluations = _Evaluations();
  final scope = Levit.createScope('gradebook-test');
  addTearDown(scope.dispose);
  final c = scope.run(
    () => Levit.put(
      () => LiveMarksController(
        evaluationId: 'a',
        evaluations: evaluations,
        academicYear: _Year(),
        teacherContext: _Teacher(),
        schoolClient: () => client,
        outboxStore: store,
      ),
    ),
  );
  c.evaluation(evaluations.evaluationById('a'));
  await c.load();
  return c;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test(
    'local entries make no writes; Save batches incomplete drafts and clears previously saved marks',
    () async {
      final client = _Client();
      final c = await _make(client, InMemoryTeacherOutboxStore());
      c.editMark('one', const MarkDraft(text: '12,5'));
      expect(client.writes, isEmpty);
      expect(c.students.value.first.score, isNull);
      expect(await c.saveDraft(), isTrue);
      expect(client.writes.single['results'], hasLength(1));
      expect(client.results.single['score'], 12.5);
      c.editMark('one', const MarkDraft());
      expect(await c.saveDraft(), isTrue);
      expect(client.results.single.containsKey('score'), isFalse);
      expect(c.completedCount, 0);
    },
  );
  test(
    'invalid batch sends nothing and submission saves the whole valid draft first',
    () async {
      final client = _Client();
      final c = await _make(client, InMemoryTeacherOutboxStore());
      c.editMark('one', const MarkDraft(text: '21'));
      c.editMark('two', const MarkDraft(designation: 'exempt'));
      expect(await c.saveDraft(), isFalse);
      expect(client.writes, isEmpty);
      c.editMark('one', const MarkDraft(text: '0'));
      await c.saveAndSubmit();
      expect(client.writes.map((w) => w['command']), [
        'record-assessment-results',
        'submit-assessment-marks',
      ]);
      expect(c.marksStatus.value, 'submitted');
    },
  );
  test(
    'offline batch is visible and retry reuses its identity before submission',
    () async {
      final client = _Client()..offline = true;
      final store = InMemoryTeacherOutboxStore();
      final c = await _make(client, store);
      c.editMark('one', const MarkDraft(text: '15'));
      c.editMark('two', const MarkDraft(designation: 'absent'));
      expect(await c.saveDraft(), isTrue);
      expect(c.hasUnsaved, isFalse);
      expect(c.students.value.first.score, 15);
      expect(c.students.value.first.syncState, MarkSyncState.pending);
      final id = client.writes.single['requestId'];
      client.offline = false;
      await c.saveAndSubmit();
      expect(client.writes[1]['requestId'], id);
      expect(await store.listPending(), isEmpty);
      expect(c.marksStatus.value, 'submitted');
    },
  );
  test(
    'rejected saves preserve local input for explicit review and retry',
    () async {
      final client = _Client()..reject = true;
      final c = await _make(client, InMemoryTeacherOutboxStore());
      c.editMark('one', const MarkDraft(text: '14'));
      expect(await c.saveDraft(), isFalse);
      expect(c.hasUnsaved, isTrue);
      expect(c.draftFor(c.students.value.first).text, '14');
      client.reject = false;
      await c.reviewSaveFailure();
      expect(await c.saveDraft(), isTrue);
      expect(client.results.single['score'], 14);
    },
  );
  test(
    'editing or withdrawing one grouped proposal preserves other pupils and shared reason',
    () async {
      final client = _Client()..submitted = true;
      client.results.addAll([
        for (final id in ['one', 'two'])
          {
            'id': 'r-$id',
            'studentId': id,
            'score': 12,
            'designation': 'scored',
          },
      ]);
      client.proposals.add({
        'id': 'group',
        'status': 'pending',
        'version': 3,
        'reason': 'Shared reason',
        'allowedActions': {'withdraw': true},
        'changes': [
          for (final id in ['one', 'two'])
            {
              'resultId': 'r-$id',
              'proposed': {'score': 14, 'designation': 'scored', 'notes': null},
            },
        ],
      });
      final c = await _make(client, InMemoryTeacherOutboxStore());
      expect(c.canEditCorrection(c.students.value.first), isTrue);
      await c.correctPupil(c.students.value.first, {
        'score': 16,
        'designation': 'scored',
        'notes': null,
      }, 'Different reason');
      expect(client.writes.last['reason'], 'Shared reason');
      expect(
        (client.writes.last['changes'] as List).first['proposed']['score'],
        14,
      );
      await c.withdrawPupil(c.students.value.first);
      expect(
        (client.writes.last['changes'] as List).single['resultId'],
        'r-two',
      );
    },
  );
  test(
    'mention drafts preserve IDs and reject numeric values for a mention policy',
    () async {
      final client = _Client();
      final c = await _make(client, InMemoryTeacherOutboxStore());
      c.gradingPolicy(
        GradingPolicyView({
          'revision': 2,
          'mode': 'mention-first',
          'status': 'completed',
          'scale': {
            'id': 'scale',
            'maxScore': 4,
            'decimalPlaces': 2,
            'ranges': [
              {
                'id': 'good',
                'letter': 'B',
                'interpretation': 'Good',
                'minScore': 0,
                'maxScore': 4,
                'gpaValue': 3,
              },
            ],
          },
        }),
      );
      c.editMark('one', const MarkDraft(text: '12'));
      expect(await c.saveDraft(), isFalse);
      c.editMark(
        'one',
        const MarkDraft(mentionId: 'good', designation: 'scored'),
      );
      expect(await c.saveDraft(), isTrue);
      expect(client.writes.single['expectedGradingRevision'], 2);
      expect(
        (client.writes.single['results'] as List).single['mentionId'],
        'good',
      );
    },
  );
  test(
    'stale revision retains inputs until the teacher reviews server state',
    () async {
      final client = _Client();
      final c = await _make(client, InMemoryTeacherOutboxStore());
      c.editMark('one', const MarkDraft(text: '14'));
      client.revision = 3;
      expect(await c.saveDraft(), isFalse);
      expect(c.hasUnsaved, isTrue);
      await c.reviewSaveFailure();
      expect(await c.saveDraft(), isTrue);
      expect(client.writes.last['expectedRevision'], 3);
    },
  );
  testWidgets('Next moves to the next pupil input without a write', (
    tester,
  ) async {
    final client = _Client();
    final c = await _make(client, InMemoryTeacherOutboxStore());
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: GradebookMarksView(controller: c)),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('score-one')), '12');
    await tester.testTextInput.receiveAction(TextInputAction.next);
    await tester.pump();
    expect(
      tester
          .widget<TextField>(find.byKey(const ValueKey('score-two')))
          .focusNode!
          .hasFocus,
      isTrue,
    );
    expect(client.writes, isEmpty);
  });
  testWidgets(
    'Back protects local edits; a rejected Save stays on the assessment',
    (tester) async {
      final client = _Client();
      final c = await _make(client, InMemoryTeacherOutboxStore());
      final router = GoRouter(
        initialLocation: '/evaluations?assessment=first',
        onEnter: workspaceCanEnter,
        routes: [
          GoRoute(
            path: '/evaluations',
            onExit: workspaceCanExit,
            builder: (_, _) =>
                Scaffold(body: GradebookMarksView(controller: c)),
          ),
          GoRoute(
            path: '/other',
            builder: (_, _) => const Scaffold(body: Text('Other page')),
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        MaterialApp.router(
          routerConfig: router,
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const ValueKey('score-one')), '14');
      // Browser Back can change only the assessment query on the same route.
      unawaited(
        router.routeInformationProvider.didPushRouteInformation(
          RouteInformation(uri: Uri.parse('/evaluations?assessment=second')),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Continue editing'), findsOneWidget);
      await tester.tap(find.text('Continue editing'));
      await tester.pumpAndSettle();
      expect(
        router
            .routerDelegate
            .currentConfiguration
            .uri
            .queryParameters['assessment'],
        'first',
      );
      expect(c.draftFor(c.students.value.first).text, '14');
      expect(client.writes, isEmpty);
      router.go('/other');
      await tester.pumpAndSettle();
      expect(find.text('Continue editing'), findsOneWidget);
      await tester.tap(find.text('Continue editing'));
      await tester.pumpAndSettle();
      expect(c.hasUnsaved, isTrue);
      client.reject = true;
      router.go('/other');
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text('Save'),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Other page'), findsNothing);
      expect(c.hasUnsaved, isTrue);
      router.go('/other');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Discard changes'));
      await tester.pumpAndSettle();
      expect(find.text('Other page'), findsOneWidget);
    },
  );
  for (final width in [320.0, 390.0, 768.0, 1024.0]) {
    for (final language in ['fr', 'en']) {
      testWidgets('inline entry stable at $width in $language', (tester) async {
        final client = _Client();
        final c = await _make(client, InMemoryTeacherOutboxStore());
        c.students([
          ...c.students.value,
          for (var i = 2; i < 26; i++)
            LiveMarkRow(
              studentId: 'pupil-$i',
              fullName: 'Pupil $i',
              initials: 'P',
            ),
        ]);
        final height = width == 768
            ? 1024.0
            : width == 1024
            ? 768.0
            : 844.0;
        await tester.binding.setSurfaceSize(Size(width, height));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        addTearDown(tester.view.resetViewInsets);
        await tester.pumpWidget(
          MaterialApp(
            locale: Locale(language),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            theme: language == 'en'
                ? PrototypeTheme.dark
                : PrototypeTheme.light,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(width == 320 ? 2 : 1)),
              child: child!,
            ),
            home: Scaffold(body: GradebookMarksView(controller: c)),
          ),
        );
        await tester.pumpAndSettle();
        final first = find.byKey(const ValueKey('score-one'));
        await tester.enterText(first, '12,5');
        await tester.pump();
        expect(client.writes, isEmpty);
        tester.view.viewInsets = FakeViewPadding(
          bottom: 280 * tester.view.devicePixelRatio,
        );
        await tester.pumpAndSettle();
        final last = find.byKey(const ValueKey('score-pupil-25'));
        await tester.ensureVisible(last);
        await tester.pumpAndSettle();
        expect(
          tester.getBottomLeft(last).dy,
          lessThanOrEqualTo(tester.getTopLeft(find.textContaining('/26 ·')).dy),
        );
        tester.view.resetViewInsets();
        await tester.binding.setSurfaceSize(
          Size(width == 320 ? 768 : 320, 1024),
        );
        await tester.pumpAndSettle();
        expect(tester.widget<TextField>(first).controller!.text, '12,5');
        expect(tester.takeException(), isNull);
      });
    }
  }
}
