import 'dart:async';
import 'package:edaya_api_client/edaya_api_client.dart' as api;
import 'package:edaya_shared/edaya_shared.dart';
import 'package:edaya_teacher/features/context/academic_year_controller.dart';
import 'package:edaya_teacher/features/context/teacher_context_controller.dart';
import 'package:edaya_teacher/features/evaluations/live_evaluations_controller.dart';
import 'package:edaya_teacher/features/evaluations/live_marks_controller.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:levit_flutter/levit_flutter.dart';

class _Year implements AcademicYearController {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Teacher implements TeacherContextController {
  @override
  final taughtClassSubjectIds = LxVar<Set<String>>({'subject'});
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Transport implements api.Transport {
  final started = Completer<void>();
  final response = Completer<Map<String, dynamic>>();
  int writes = 0;
  @override
  Future<T> request<T>(
    String method,
    String path, {
    api.TransportRequestOptions? options,
  }) async {
    writes++;
    started.complete();
    return await response.future as T;
  }
}

class _Store extends InMemoryTeacherOutboxStore {
  final started = Completer<void>();
  final pending = Completer<List<TeacherOutboxEntry>>();
  final bool defer;
  _Store(this.defer);
  @override
  Future<List<TeacherOutboxEntry>> listPending() async {
    if (defer) {
      started.complete();
      return pending.future;
    }
    return super.listPending();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  for (final deferStore in [true, false]) {
    for (final failure in [false, true]) {
      test(
        'closing mark batch during ${deferStore ? 'outbox read' : 'API write'} ignores late ${failure ? 'failure' : 'response'}',
        () async {
          final transport = _Transport();
          final teacher = _Teacher();
          final year = _Year();
          final evaluations = LiveEvaluationsController(
            teacherContext: teacher,
            academicYear: year,
            schoolClient: () => api.createSchoolClient(transport),
          );
          final store = _Store(deferStore);
          var contexts = 0;
          final marks = LiveMarksController(
            evaluationId: 'evaluation',
            evaluations: evaluations,
            academicYear: year,
            teacherContext: teacher,
            schoolClient: () => api.createSchoolClient(transport),
            outboxStore: store,
            outboxContext: () {
              contexts++;
              return null;
            },
          );
          marks.evaluation(
            const LiveEvaluationSummary(
              id: 'evaluation',
              title: 'Quiz',
              classGroupId: 'class',
              classSubjectId: 'subject',
              periodId: 'period',
              classLabel: 'Class',
              subjectLabel: 'Maths',
              gradedCount: 0,
              totalStudents: 2,
            ),
          );
          marks.students(const [
            LiveMarkRow(studentId: 'first', fullName: 'First', initials: 'F'),
            LiveMarkRow(studentId: 'second', fullName: 'Second', initials: 'S'),
          ]);
          final completion = expectLater(marks.fillUngraded(20), completes);
          await (deferStore ? store.started.future : transport.started.future);
          marks.onClose();
          if (deferStore) {
            if (failure) {
              store.pending.completeError(StateError('late outbox error'));
            } else {
              store.pending.complete([]);
            }
          } else {
            if (failure) {
              transport.response.completeError(StateError('late API error'));
            } else {
              transport.response.complete({});
            }
          }
          await completion;
          expect(
            contexts,
            1,
            reason: 'Disposed scope must never be consulted for another row',
          );
          expect(transport.writes, deferStore ? 0 : 1);
          teacher.taughtClassSubjectIds.close();
        },
      );
    }
  }
}
