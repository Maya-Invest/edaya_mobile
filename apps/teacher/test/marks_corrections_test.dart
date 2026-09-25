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

class _Context extends Fake implements TeacherContextController {}

class _Client extends Fake implements api.SchoolClient {
  final writes = <Map<String, dynamic>>[];
  bool failFirst = false;
  @override
  Future<Map<String, dynamic>> runQuery(
    String name,
    Map<String, dynamic> payload,
  ) async => {
    'assessment': {
      'id': 'assessment',
      'marksRevision': 2,
      'marksStatus': 'submitted',
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
        'score': 12.75,
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
}
