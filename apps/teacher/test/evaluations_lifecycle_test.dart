import 'dart:async';

import 'package:edaya_api_client/edaya_api_client.dart' as api;
import 'package:edaya_teacher_v2/features/context/academic_year_controller.dart';
import 'package:edaya_teacher_v2/features/context/teacher_context_controller.dart';
import 'package:edaya_teacher_v2/features/evaluations/live_evaluations_controller.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:levit_flutter/levit_flutter.dart';

class _AcademicYear implements AcademicYearController {
  @override
  final selectedYearId = LxVar<String?>('year');

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _TeacherContext implements TeacherContextController {
  @override
  final assignedClasses = LxVar<List<AssignedClass>>(const [
    AssignedClass(id: 'class', label: 'Class'),
  ]);
  @override
  final activeAssignmentId = LxVar<String?>('assignment');
  @override
  final taughtClassSubjectIds = LxVar<Set<String>>({'class-subject'});
  @override
  List<String> get visibleClassGroupIds => ['class'];
  @override
  TeacherWorkspaceSelection get selection => const TeacherWorkspaceSelection(
    schoolId: 'school',
    academicYearId: 'year',
    classGroupId: 'class',
    classSubjectId: 'class-subject',
  );
  @override
  TeacherAssignmentOption get activeAssignment => const TeacherAssignmentOption(
    id: 'assignment',
    classGroupId: 'class',
    classLabel: 'Class',
    subjectLabel: 'Maths',
    isHomeroom: false,
    classSubjectId: 'class-subject',
  );

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Transport implements api.Transport {
  _Transport(this.deferredEntity);

  final String deferredEntity;
  final requested = Completer<void>();
  final response = Completer<List<Map<String, dynamic>>>();
  final requests = <String>[];

  static const rows = <String, List<Map<String, dynamic>>>{
    'academic-periods': [
      {'id': 'period'},
    ],
    'class-subjects': [
      {'id': 'class-subject', 'classGroupId': 'class', 'subjectId': 'subject'},
    ],
    'subjects': [
      {'id': 'subject', 'name': 'Maths'},
    ],
    'assessments': [],
  };

  @override
  Future<T> request<T>(
    String method,
    String path, {
    api.TransportRequestOptions? options,
  }) async {
    final entity = path.split('/')[3];
    requests.add(entity);
    if (entity == deferredEntity && !requested.isCompleted) {
      requested.complete();
      return await response.future as T;
    }
    return rows[entity]! as T;
  }
}

class _Controller extends LiveEvaluationsController {
  _Controller({
    required super.teacherContext,
    required super.academicYear,
    required super.schoolClient,
  });

  late Future<void> initialReload;

  @override
  Future<void> reload() => initialReload = super.reload();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  for (final entity in ['academic-periods', 'class-subjects', 'assessments']) {
    for (final fails in [false, true]) {
      test(
        'closing during $entity ignores a late ${fails ? 'failure' : 'response'}',
        () async {
          final year = _AcademicYear();
          final teacher = _TeacherContext();
          final transport = _Transport(entity);
          final controller = _Controller(
            teacherContext: teacher,
            academicYear: year,
            schoolClient: () => api.createSchoolClient(transport),
          );
          controller.selectedPeriodId('period');
          final observed = [
            controller.periods,
            controller.classSubjects,
            controller.evaluations,
            controller.errorMessage,
          ];
          for (final reactive in observed) {
            final subscription = reactive.stream.listen((_) {});
            addTearDown(subscription.cancel);
          }
          controller.onInit();
          addTearDown(controller.onClose);
          addTearDown(year.selectedYearId.close);
          addTearDown(teacher.assignedClasses.close);
          addTearDown(teacher.activeAssignmentId.close);
          addTearDown(teacher.taughtClassSubjectIds.close);

          final completion = expectLater(controller.initialReload, completes);
          await transport.requested.future.timeout(const Duration(seconds: 2));
          final requestCount = transport.requests.length;
          final beforeClose = [for (final reactive in observed) reactive.value];
          controller.onClose();
          if (fails) {
            transport.response.completeError(StateError('Late API failure'));
          } else {
            transport.response.complete(_Transport.rows[entity]!);
          }
          await completion;
          // Task cancellation can finish the caller before the HTTP continuation.
          await Future<void>.delayed(Duration.zero);
          expect(controller.isClosed, isTrue);
          expect(transport.requests, hasLength(requestCount));
          for (var i = 0; i < observed.length; i++) {
            expect(observed[i].value, same(beforeClose[i]));
          }
        },
      );
    }
  }
}
