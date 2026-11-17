import 'dart:async';
import 'package:edaya_api_client/edaya_api_client.dart' show ApiError;
import 'package:edaya_auth/edaya_auth.dart' show AuthClient;
import '../../di/prototype_module.dart';
import '../context/academic_year_controller.dart';
import 'package:edaya_shared/edaya_shared.dart';
import 'package:levit_flutter/levit_flutter.dart';
import '../context/teacher_context_controller.dart';
import 'live_evaluations_controller.dart';

class TeacherGradebookController extends LevitController {
  TeacherGradebookController(
    this.teacher,
    this.evaluations,
    this.client,
    this.dependencies, {
    this.initialAssessmentId,
  });
  final String? initialAssessmentId;
  final TeacherContextController teacher;
  final LiveEvaluationsController evaluations;
  final SchoolClientFactory client;
  final LevitScope dependencies;
  final assessmentError = LxVar('');
  final students = LxVar<List<Map<String, dynamic>>>([]);
  final loading = LxVar(false);
  final error = LxVar('');
  int generation = 0;
  @override
  void onInit() {
    super.onInit();
    autoDispose(students);
    autoDispose(loading);
    autoDispose(error);
    autoDispose(assessmentError);
    for (final stream in [
      teacher.activeAssignmentId.stream,
      evaluations.selectedPeriodId.stream,
    ]) {
      autoDispose(stream.listen((_) => unawaited(load())));
    }
    if (initialAssessmentId == null) {
      evaluations.selectedEvaluationId(null);
      unawaited(load());
    } else if (evaluations.selectedEvaluationId.value != initialAssessmentId ||
        evaluations.evaluationById(initialAssessmentId!) == null) {
      unawaited(openAssessment(initialAssessmentId!));
    }
  }

  Future<void> openAssessment(String id) async {
    loading(true);
    try {
      final session = dependencies.find<AppSessionController>();
      final year = dependencies.find<AcademicYearController>();
      final auth = dependencies.find<AuthClient>();
      if (teacher.activeAssignment == null) {
        await initializeTeacherAuthenticatedContext(dependencies);
      }
      if (isClosed) return;
      final profiles = session.availableProfiles.value
          .where((p) => p.kind == 'teacher')
          .toList();
      // The active school wins if two schools happen to use the same record ID.
      final active = profiles
          .where(
            (p) =>
                p.schoolId == session.schoolIdHeader &&
                p.actorId == session.actorIdHeader,
          )
          .firstOrNull;
      final candidates = [?active, ...profiles.where((p) => p != active)];
      Map? assessment;
      for (final profile in candidates) {
        if (isClosed) return;
        final here = profile == active;
        final reader = here
            ? client()
            : createEdayaSchoolClient(
                auth,
                getSchoolId: () => profile.schoolId,
                getActorId: () => profile.actorId,
                getActorKind: () => 'teacher',
              );
        try {
          final data = await reader.runQuery('get-assessment-marks-review', {
            'assessmentId': id,
          });
          if (isClosed) return;
          final target = data['assessment'] as Map;
          if (!here) {
            year.clearSelection();
            final failure = await session.selectProfile(profile);
            if (failure != null) throw StateError(failure);
            await initializeTeacherAuthenticatedContext(
              dependencies,
              findEligibleSchool: false,
            );
          }
          if (isClosed) return;
          if (!teacher.assignments.value.any(
            (a) => a.classSubjectId == target['classSubjectId'],
          )) {
            continue;
          }
          assessment = target;
          break;
        } on ApiError catch (e) {
          if (e.status != 403 && e.status != 404) rethrow;
        }
      }
      if (assessment == null) throw StateError('Unavailable assessment');
      await teacher.selectAssignment(assessment['classSubjectId'] as String);
      if (isClosed) return;
      evaluations.selectPeriod(assessment['periodId'] as String);
      await evaluations.loadEvaluations();
      if (isClosed) return;
      evaluations.selectedEvaluationId(id);
    } on Object {
      if (!isClosed) {
        assessmentError(
          systemL10n().thisAssessmentIsUnavailableOrYourAccessHas,
        );
      }
    } finally {
      if (!isClosed) loading(false);
    }
  }

  Future<void> load() async {
    final request = ++generation;
    final subject = teacher.activeAssignment?.classSubjectId;
    final period = evaluations.selectedPeriodId.value;
    students([]);
    error('');
    loading(true);
    try {
      if (subject == null || period == null) return;
      final data = await client().runQuery(
        'get-teacher-subject-period-summary',
        {'classSubjectId': subject, 'periodId': period},
      );
      if (isClosed || request != generation) return;
      students(
        (data['students'] as List)
            .map((r) => (r as Map).cast<String, dynamic>())
            .toList(),
      );
    } on Object {
      if (!isClosed && request == generation) {
        error(systemL10n().couldNotLoadResultsTryAgain);
      }
    } finally {
      if (!isClosed && request == generation) loading(false);
    }
  }
}
