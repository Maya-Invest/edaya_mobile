import 'package:levit_flutter/levit_flutter.dart';
import 'dart:async';
import 'package:edaya_api_client/edaya_api_client.dart' as api;
import 'package:edaya_shared/edaya_shared.dart';
import 'package:edaya_teacher/features/context/academic_year_controller.dart';
import 'package:edaya_teacher/features/context/teacher_context_controller.dart';
import 'package:edaya_teacher/features/evaluations/live_evaluations_controller.dart';
import 'package:edaya_teacher/features/evaluations/live_marks_controller.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Evaluations extends Fake implements LiveEvaluationsController {
  @override
  void patchGradedCount(String id, int count) {}
  @override
  LiveEvaluationSummary? evaluationById(String id) => LiveEvaluationSummary(
    id: id,
    title: 'Math',
    classGroupId: 'class',
    classSubjectId: 'subject',
    periodId: 'period',
    classLabel: 'Class',
    subjectLabel: 'Math',
    gradedCount: 1,
    totalStudents: 1,
  );
}

class _Year extends Fake implements AcademicYearController {}

class _Context extends Fake implements TeacherContextController {
  @override
  final taughtClassSubjectIds = LxVar<Set<String>>({});
}

class _Client extends Fake implements api.SchoolClient {
  final writes = <Map<String, dynamic>>[];
  bool failFirst = false;
  bool mentionFirst = false;
  bool numericAfterMention = false;
  bool draft = false;
  @override
  Future<Map<String, dynamic>> runQuery(
    String name,
    Map<String, dynamic> payload,
  ) async => {
    'assessment': {
      'id': 'assessment',
      'marksRevision': 2,
      'marksStatus': draft ? 'draft' : 'submitted',
    },
    if (mentionFirst)
      'gradingPolicy': {
        'revision': 2,
        'mode': numericAfterMention ? 'numeric-first' : 'mention-first',
        'status': 'completed',
        'aggregateLabel': 'GPA',
        'scale': {
          'id': 'points',
          'maxScore': 4,
          'decimalPlaces': 2,
          'ranges': [
            {
              'id': 'b',
              'letter': 'B',
              'interpretation': 'Good',
              'minScore': 0,
              'maxScore': 4,
              'gpaValue': 3,
            },
          ],
        },
      },
    'allowedActions': {'submit': false, 'requestCorrection': true},
    'publishedResultIds': <String>[],
    'corrections': <Map<String, dynamic>>[],
    'students': [
      {'id': 'student', 'firstName': 'Ada', 'lastName': 'L'},
    ],
    'results': [
      {
        'id': 'mark',
        'studentId': 'student',
        'score': mentionFirst ? null : 12.75,
        if (mentionFirst) 'mentionId': 'b',
        if (mentionFirst) 'originalEntry': {'kind': 'mention', 'code': 'B'},
        'designation': 'scored',
        'revision': 1,
      },
    ],
  };
  @override
  Future<Map<String, dynamic>> runCommand(
    String name,
    Map<String, dynamic> payload,
  ) async {
    writes.add({...payload, 'command': name});
    if (failFirst && writes.length == 1) {
      throw TimeoutException('Response lost');
    }
    return {'id': 'correction', 'version': 0, 'status': 'pending'};
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  LiveMarksController controller(_Client client, TeacherOutboxStore store) {
    final scope = Levit.createScope('marks-test');
    addTearDown(scope.dispose);
    return scope.run(
      () => Levit.put(
        () => LiveMarksController(
          evaluationId: 'assessment',
          evaluations: _Evaluations(),
          academicYear: _Year(),
          teacherContext: _Context(),
          schoolClient: () => client,
          outboxStore: store,
        ),
      ),
    );
  }

  test(
    'delayed draft writes remain conflicts and never replace official submitted values',
    () async {
      final store = InMemoryTeacherOutboxStore();
      await store.enqueue(
        buildTeacherOutboxEntry(
          id: 'old-edit',
          kind: TeacherOutboxKind.mark,
          idempotencyKey: 'old-edit',
          payload: {
            'assessmentId': 'assessment',
            'studentId': 'student',
            'id': 'mark',
            'expectedRevision': 1,
            'score': 19,
          },
        ),
      );
      final client = _Client();
      final marks = controller(client, store);
      await marks.load();
      expect(marks.students.value.single.score, 12.75);
      expect(
        (await store.listPending()).single.state,
        TeacherOutboxState.conflict,
      );
      await marks.saveScore('student', 19);
      expect(client.writes, isEmpty);
    },
  );

  test(
    'explicit online retries keep their request identity across controller recreation',
    () async {
      final client = _Client()..failFirst = true;
      final store = InMemoryTeacherOutboxStore();
      final changes = [
        {
          'resultId': 'mark',
          'proposed': {'score': 14.25, 'designation': 'scored', 'notes': null},
        },
      ];
      final first = controller(client, store);
      await first.load();
      expect(
        await first.requestCorrection(changes, 'Original paper checked'),
        isFalse,
      );
      expect(await store.listPending(), isEmpty);
      final retry = controller(client, store);
      await retry.load();
      expect(
        await retry.requestCorrection(changes, 'Original paper checked'),
        isTrue,
      );
      expect(client.writes, hasLength(2));
      expect(client.writes[0]['requestId'], client.writes[1]['requestId']);
      expect(retry.students.value.single.score, 12.75);
    },
  );
  test(
    'revision submits the displayed request version and homework status in one command',
    () async {
      final client = _Client();
      final marks = controller(client, InMemoryTeacherOutboxStore());
      await marks.load();
      expect(
        await marks.requestCorrection(
          [
            {
              'resultId': 'mark',
              'proposed': {
                'score': 14,
                'designation': 'scored',
                'notes': 'Checked',
                'status': 'met',
              },
            },
          ],
          'Checked submission',
          correction: {'id': 'correction', 'version': 3},
        ),
        isTrue,
      );
      expect(
        client.writes.single['command'],
        'revise-assessment-marks-correction',
      );
      expect(client.writes.single['expectedVersion'], 3);
      expect(client.writes.single['assessmentId'], 'assessment');
      expect(client.writes.single['expectedRevision'], 2);
      expect(
        ((client.writes.single['changes'] as List).single as Map)['proposed'],
        containsPair('status', 'met'),
      );
      expect(marks.students.value.single.score, 12.75);
    },
  );
  test(
    'fill ungraded retains original mentions after a switch to numeric entry',
    () async {
      final client = _Client()
        ..mentionFirst = true
        ..numericAfterMention = true
        ..draft = true;
      final marks = controller(client, InMemoryTeacherOutboxStore());
      await marks.load();
      expect(marks.mentionFirst, isFalse);
      expect(marks.students.value.single.score, isNull);
      expect(marks.students.value.single.mentionCode, 'B');
      await marks.fillUngraded(20);
      expect(client.writes, isEmpty);
      expect(marks.students.value.single.mentionId, 'b');
    },
  );

  test(
    'mention entry and corrections preserve identifiers and the displayed policy revision',
    () async {
      final client = _Client()
        ..mentionFirst = true
        ..draft = true;
      final marks = controller(client, InMemoryTeacherOutboxStore());
      await marks.load();
      expect(marks.mentionFirst, isTrue);
      expect(marks.mentionLabel('b'), 'B');
      expect(marks.students.value.single.mentionCode, 'B');
      marks.ungradedOnly(true);
      expect(marks.visibleStudents, isEmpty);
      await marks.saveScore('student', null, mentionId: 'b');
      expect(client.writes.last['score'], isNull);
      expect(client.writes.last['mentionId'], 'b');
      expect(client.writes.last['expectedGradingRevision'], 2);
      client.draft = false;
      await marks.load();
      expect(
        await marks.requestCorrection([
          {
            'resultId': 'mark',
            'proposed': {
              'score': null,
              'mentionId': 'b',
              'designation': 'scored',
              'notes': 'Checked',
            },
          },
        ], 'Reviewed'),
        isTrue,
      );
      expect(client.writes.last['expectedGradingRevision'], 2);
      expect(
        (client.writes.last['changes'] as List).single['proposed']['score'],
        isNull,
      );
    },
  );
}
