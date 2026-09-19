import 'dart:async';

import 'package:edaya_api_client/edaya_api_client.dart' as api;
import 'package:levit_flutter/levit_flutter.dart';

import 'package:edaya_shared/edaya_shared.dart';
import '../../common/utils/academic_period.dart';
import '../../common/utils/entity_filters.dart';
import '../context/academic_year_controller.dart';
import '../context/teacher_context_controller.dart';
import 'evaluations_marks_logic.dart';
import 'models/evaluation_models.dart';

class EvaluationsController extends LevitController
    with LevitReactiveTasksMixin {
  EvaluationsController({
    required TeacherContextController teacherContext,
    required AcademicYearController academicYear,
    required SchoolClientFactory schoolClient,
    TeacherOutboxStore? outboxStore,
  }) : _teacherContext = teacherContext,
       _academicYear = academicYear,
       _schoolClient = schoolClient,
       _outboxStore = outboxStore ?? openTeacherOutboxStore();

  final TeacherContextController _teacherContext;
  final AcademicYearController _academicYear;
  final SchoolClientFactory _schoolClient;
  final TeacherOutboxStore _outboxStore;

  final evaluations = LxVar<List<EvaluationSummary>>(const []);
  final periods = LxVar<List<Map<String, dynamic>>>(const []);
  final selectedPeriodId = LxVar<String?>(null);
  final errorMessage = LxVar('');
  final marksStudents = LxVar<List<StudentMarkRow>>(const []);
  final marksErrorMessage = LxVar('');
  final marksSaveMessage = LxVar('');
  final marksEvaluationId = LxVar<String?>(null);

  int _marksLoadGeneration = 0;

  @override
  void onInit() {
    super.onInit();
    autoDispose(evaluations);
    autoDispose(periods);
    autoDispose(selectedPeriodId);
    autoDispose(errorMessage);
    autoDispose(marksStudents);
    autoDispose(marksErrorMessage);
    autoDispose(marksSaveMessage);
    autoDispose(marksEvaluationId);

    for (final subscription in [
      _teacherContext.assignedClasses.stream,
      _teacherContext.classFilterId.stream,
      _academicYear.selectedYearId.stream,
    ]) {
      autoDispose(
        subscription.listen((_) {
          unawaited(reloadPeriodsAndEvaluations());
        }),
      );
    }

    unawaited(reloadPeriodsAndEvaluations());
  }

  String? get selectedPeriodLabel {
    final periodId = selectedPeriodId.value;
    if (periodId == null) {
      return null;
    }
    for (final period in periods.value) {
      if (period['id'] == periodId) {
        return academicPeriodLabel(period);
      }
    }
    return periodId;
  }

  Future<void> reloadPeriodsAndEvaluations() async {
    await loadPeriods();
    await loadEvaluations();
  }

  Future<void> loadPeriods() async {
    final yearId = _academicYear.selectedYearId.value;
    if (yearId == null) {
      periods(const []);
      selectedPeriodId(null);
      return;
    }

    try {
      final client = _schoolClient();
      final rows = sortAcademicPeriods(
        await client.academicPeriods.list(academicPeriodsForYear(yearId)),
      );
      periods(rows);

      final currentId = selectedPeriodId.value;
      if (currentId == null || !rows.any((row) => row['id'] == currentId)) {
        selectedPeriodId(currentAcademicPeriodId(rows));
      }
    } on Object {
      periods(const []);
      selectedPeriodId(null);
    }
  }

  void selectPeriod(String periodId) {
    selectedPeriodId(periodId);
    unawaited(loadEvaluations());
  }

  DataStatus get dataStatus {
    if (isBusy.value && evaluations.value.isEmpty) {
      return DataStatus.loading;
    }
    if (errorMessage.value.isNotEmpty && evaluations.value.isEmpty) {
      return DataStatus.error;
    }
    if (_teacherContext.assignedClasses.value.isEmpty) {
      return DataStatus.empty;
    }
    return DataStatus.ready;
  }

  String get emptyMessage {
    if (selectedPeriodId.value == null) {
      return systemL10n().selectPeriodToViewEvaluations;
    }
    return systemL10n().noEvaluationsForPeriod;
  }

  Future<void> loadEvaluations() async {
    final classGroupIds = _teacherContext.visibleClassGroupIds;
    final periodId = selectedPeriodId.value;
    final taughtSubjectIds = _teacherContext.taughtClassSubjectIds.value;
    if (classGroupIds.isEmpty || periodId == null || taughtSubjectIds.isEmpty) {
      evaluations(const []);
      return;
    }

    errorMessage('');
    await runTask(() async {
      try {
        final client = _schoolClient();
        final classLabelById = {
          for (final assigned in _teacherContext.assignedClasses.value)
            assigned.id: assigned.label,
        };

        final classSubjectRows = await client.classSubjects.list(
          entitiesByIds(taughtSubjectIds.toList()),
        );
        final subjectIds = classSubjectRows
            .map((row) => row['subjectId'] as String?)
            .whereType<String>()
            .toSet()
            .toList();
        final subjectRows = subjectIds.isEmpty
            ? <Map<String, dynamic>>[]
            : await client.subjects.list(entitiesByIds(subjectIds));
        final subjectNameById = {
          for (final subject in subjectRows)
            subject['id'] as String:
                subject['name'] as String? ?? systemL10n().subjectFallback,
        };

        final enrollmentCountByClass = <String, int>{};
        final summaries = <EvaluationSummary>[];
        for (final classSubjectRow in classSubjectRows) {
          final classSubjectId = classSubjectRow['id'] as String;
          final classGroupId = classSubjectRow['classGroupId'] as String;
          if (!classGroupIds.contains(classGroupId)) {
            continue;
          }

          final assessmentRows = await client.assessments.list(
            assessmentsForClassSubjectPeriod(classSubjectId, periodId),
          );
          if (assessmentRows.isEmpty) {
            continue;
          }

          final totalStudents = await _activeEnrollmentCount(
            client,
            classGroupId: classGroupId,
            academicYearId: _academicYear.selectedYearId.value,
            cache: enrollmentCountByClass,
          );

          final subjectId = classSubjectRow['subjectId'] as String?;
          final subjectLabel = subjectId == null
              ? systemL10n().subjectFallback
              : subjectNameById[subjectId] ?? systemL10n().subjectFallback;

          final assessmentIds = assessmentRows
              .map((row) => row['id'] as String)
              .toList();
          final allResults = await client.assessmentResults.list(
            resultsForAssessments(assessmentIds),
          );
          final gradedByAssessment = <String, int>{};
          for (final result in allResults) {
            if (result['score'] == null) {
              continue;
            }
            final assessmentId = result['assessmentId'] as String?;
            if (assessmentId == null) {
              continue;
            }
            gradedByAssessment[assessmentId] =
                (gradedByAssessment[assessmentId] ?? 0) + 1;
          }

          for (final assessment in assessmentRows) {
            final assessmentId = assessment['id'] as String;
            summaries.add(
              EvaluationSummary(
                id: assessmentId,
                title: assessment['title'] as String? ?? assessmentId,
                classGroupId: classGroupId,
                classSubjectId: classSubjectId,
                periodId: assessment['periodId'] as String? ?? periodId,
                classLabel: classLabelById[classGroupId] ?? classGroupId,
                subjectLabel: subjectLabel,
                date:
                    (assessment['dueAt'] as String?)?.substring(0, 10) ??
                    (assessment['startsAt'] as String?)?.substring(0, 10) ??
                    '',
                maxScore: (assessment['maxScore'] as num?)?.toDouble() ?? 20,
                gradedCount: gradedByAssessment[assessmentId] ?? 0,
                totalStudents: totalStudents,
              ),
            );
          }
        }

        summaries.sort((a, b) => b.date.compareTo(a.date));
        evaluations(summaries);
      } on api.ApiError catch (error) {
        errorMessage(systemL10n().couldNotLoadEvaluations('$error'));
        evaluations(const []);
      } on Object catch (error) {
        errorMessage(systemL10n().couldNotLoadEvaluations('$error'));
        evaluations(const []);
      }
    });
  }

  Future<void> loadMarks(EvaluationSummary evaluation) async {
    final generation = ++_marksLoadGeneration;
    marksEvaluationId(evaluation.id);
    marksSaveMessage('');
    marksErrorMessage('');
    await runTask(() async {
      final result = await fetchMarksRoster(evaluation);
      if (!shouldApplyMarksLoad(generation, _marksLoadGeneration)) {
        return;
      }
      marksStudents(result.students);
      marksErrorMessage(result.errorMessage);
    }, id: 'load-marks');
  }

  Future<({List<StudentMarkRow> students, String errorMessage})>
  fetchMarksRoster(EvaluationSummary evaluation) async {
    try {
      final client = _schoolClient();
      final enrollmentRows = await client.enrollments.list(
        activeEnrollmentsForClass(
          evaluation.classGroupId,
          academicYearId: _academicYear.selectedYearId.value,
        ),
      );
      final studentIds = enrollmentRows
          .map((row) => row['studentId'] as String?)
          .whereType<String>()
          .toList();
      final studentRows = studentIds.isEmpty
          ? <Map<String, dynamic>>[]
          : await client.students.list(entitiesByIds(studentIds));
      final results = await client.assessmentResults.list(
        resultsForAssessment(evaluation.id),
      );
      final lockedStudentIds = await _publishedReportCardStudentIds(
        client,
        classGroupId: evaluation.classGroupId,
        periodId: evaluation.periodId,
      );
      final scoreByStudent = <String, Map<String, dynamic>>{};
      for (final row in results) {
        final studentId = row['studentId'] as String?;
        if (studentId != null) {
          scoreByStudent[studentId] = row;
        }
      }

      final roster = studentRows.map((row) {
        final studentId = row['id'] as String;
        final firstName = row['firstName'] as String? ?? '';
        final lastName = row['lastName'] as String? ?? '';
        final fullName = '$firstName $lastName'.trim();
        final displayName = fullName.isEmpty ? studentId : fullName;
        final result = scoreByStudent[studentId];
        return StudentMarkRow(
          studentId: studentId,
          studentName: displayName,
          studentInitials: _initials(displayName),
          photoUrl: row['photoUrl'] as String?,
          resultId: result?['id'] as String?,
          score: (result?['score'] as num?)?.toDouble(),
          marksLocked: lockedStudentIds.contains(studentId),
        );
      }).toList()..sort((a, b) => a.studentName.compareTo(b.studentName));
      return (students: roster, errorMessage: '');
    } on api.ApiError catch (error) {
      return (
        students: const <StudentMarkRow>[],
        errorMessage: systemL10n().couldNotLoadMarks('$error'),
      );
    } on Object catch (error) {
      return (
        students: const <StudentMarkRow>[],
        errorMessage: systemL10n().couldNotLoadMarks('$error'),
      );
    }
  }

  Future<bool> saveMark(
    EvaluationSummary evaluation,
    StudentMarkRow row,
    double score,
  ) async {
    if (row.marksLocked) {
      marksSaveMessage(systemL10n().publishedReportCardImmutable);
      return false;
    }

    final taughtSubjectIds = _teacherContext.taughtClassSubjectIds.value;
    if (!canInputGradeForSubject(
      classSubjectId: evaluation.classSubjectId,
      taughtSubjectIds: taughtSubjectIds,
    )) {
      marksSaveMessage(systemL10n().couldNotSaveMark('403'));
      return false;
    }

    marksSaveMessage('');
    final resultId = row.resultId ?? 'ar-${evaluation.id}-${row.studentId}';
    final previousScore = row.score;
    final previousResultId = row.resultId;

    marksStudents(
      applyStudentMark(
        marksStudents.value,
        studentId: row.studentId,
        resultId: resultId,
        score: score,
        syncState: MarkSyncState.pending,
      ),
    );

    try {
      final client = _schoolClient();
      await client.recordAssessmentResult(
        assessmentResultPayload(
          assessmentId: evaluation.id,
          studentId: row.studentId,
          score: score,
          resultId: resultId,
        ),
      );

      marksStudents(
        applyStudentMark(
          marksStudents.value,
          studentId: row.studentId,
          resultId: resultId,
          score: score,
          syncState: MarkSyncState.synced,
        ),
      );
      _patchEvaluationSummary(evaluation.id, marksStudents.value);
      return true;
    } on api.ApiError catch (error) {
      return _enqueueMarkFailure(
        evaluation: evaluation,
        row: row,
        score: score,
        resultId: resultId,
        previousScore: previousScore,
        previousResultId: previousResultId,
        error: _formatApiError(error),
      );
    } on Object catch (error) {
      return _enqueueMarkFailure(
        evaluation: evaluation,
        row: row,
        score: score,
        resultId: resultId,
        previousScore: previousScore,
        previousResultId: previousResultId,
        error: '$error',
      );
    }
  }

  Future<bool> saveAllMarks(
    EvaluationSummary evaluation,
    Map<String, double> scoresByStudentId,
  ) async {
    var saved = true;
    for (final entry in scoresByStudentId.entries) {
      final row = marksStudents.value.firstWhere(
        (candidate) => candidate.studentId == entry.key,
        orElse: () => throw StateError('Missing student ${entry.key}'),
      );
      final ok = await saveMark(evaluation, row, entry.value);
      saved = saved && ok;
    }
    return saved;
  }

  Future<String?> duplicateEvaluation(EvaluationSummary evaluation) async {
    try {
      final client = _schoolClient();
      final source = await client.assessments.get(evaluation.id);
      final newId = 'asm-${DateTime.now().millisecondsSinceEpoch}';
      await client.createAssessment(
        createAssessmentPayload(
          id: newId,
          classGroupId: evaluation.classGroupId,
          classSubjectId: evaluation.classSubjectId,
          periodId: evaluation.periodId,
          title: '${evaluation.title} (copy)',
          maxScore: evaluation.maxScore,
          kind: source['kind'] as String? ?? 'quiz',
          assessmentDate: DateTime.now(),
          coefficient: (source['coefficient'] as num?)?.toDouble() ?? 1,
        ),
      );
      await loadEvaluations();
      return null;
    } on Object catch (error) {
      return systemL10n().couldNotCreateEvaluation('$error');
    }
  }

  Future<String?> completeEvaluation(EvaluationSummary evaluation) async {
    try {
      final client = _schoolClient();
      await client.completeAssessment({'id': evaluation.id});
      await loadEvaluations();
      return null;
    } on Object catch (error) {
      return systemL10n().couldNotCreateEvaluation('$error');
    }
  }

  Future<bool> _enqueueMarkFailure({
    required EvaluationSummary evaluation,
    required StudentMarkRow row,
    required double score,
    required String resultId,
    required double? previousScore,
    required String? previousResultId,
    required String error,
  }) async {
    await _outboxStore.enqueue(
      buildTeacherOutboxEntry(
        id: resultId,
        kind: TeacherOutboxKind.mark,
        idempotencyKey: teacherMarkIdempotencyKey(
          assessmentId: evaluation.id,
          studentId: row.studentId,
        ),
        payload: markOutboxPayload(
          assessmentId: evaluation.id,
          studentId: row.studentId,
          score: score,
          resultId: resultId,
        ),
        lastError: error,
      ),
    );
    marksStudents(
      applyStudentMark(
        marksStudents.value,
        studentId: row.studentId,
        resultId: resultId,
        score: score,
        syncState: MarkSyncState.pending,
      ),
    );
    marksSaveMessage(systemL10n().attendanceSavedLocally);
    _patchEvaluationSummary(evaluation.id, marksStudents.value);
    return true;
  }

  void _patchEvaluationSummary(
    String evaluationId,
    List<StudentMarkRow> students,
  ) {
    evaluations(
      patchEvaluationGradedCount(
        summaries: evaluations.value,
        evaluationId: evaluationId,
        students: students,
      ),
    );
  }
}

class ClassSubjectOption {
  const ClassSubjectOption({
    required this.id,
    required this.classGroupId,
    required this.label,
  });

  final String id;
  final String classGroupId;
  final String label;
}

class EvaluationCreateController extends LevitController
    with LevitReactiveTasksMixin {
  EvaluationCreateController({
    required TeacherContextController teacherContext,
    required AcademicYearController academicYear,
    required EvaluationsController evaluations,
    required SchoolClientFactory schoolClient,
  }) : _teacherContext = teacherContext,
       _academicYear = academicYear,
       _evaluations = evaluations,
       _schoolClient = schoolClient;

  final TeacherContextController _teacherContext;
  final AcademicYearController _academicYear;
  final EvaluationsController _evaluations;
  final SchoolClientFactory _schoolClient;

  final classSubjects = LxVar<List<ClassSubjectOption>>(const []);
  final periods = LxVar<List<Map<String, dynamic>>>(const []);
  final errorMessage = LxVar('');

  @override
  void onInit() {
    super.onInit();
    autoDispose(classSubjects);
    autoDispose(periods);
    autoDispose(errorMessage);
    unawaited(loadClassSubjects());
    unawaited(loadPeriods());
  }

  List<AssignedClass> get assignedClasses =>
      _teacherContext.assignedClasses.value;

  Future<void> loadClassSubjects() async {
    final taughtIds = _teacherContext.taughtClassSubjectIds.value;
    if (taughtIds.isEmpty) {
      classSubjects(const []);
      return;
    }

    await runTask(() async {
      try {
        final client = _schoolClient();
        final classLabelById = {
          for (final assigned in _teacherContext.assignedClasses.value)
            assigned.id: assigned.label,
        };
        final rows = await client.classSubjects.list(
          entitiesByIds(taughtIds.toList()),
        );
        final subjectIds = rows
            .map((row) => row['subjectId'] as String?)
            .whereType<String>()
            .toSet()
            .toList();
        final subjectRows = subjectIds.isEmpty
            ? <Map<String, dynamic>>[]
            : await client.subjects.list(entitiesByIds(subjectIds));
        final subjectNameById = {
          for (final subject in subjectRows)
            subject['id'] as String:
                subject['name'] as String? ?? systemL10n().subjectFallback,
        };

        final options = rows.map((row) {
          final classGroupId = row['classGroupId'] as String;
          final subjectId = row['subjectId'] as String?;
          final subjectName = subjectId == null
              ? systemL10n().subjectFallback
              : subjectNameById[subjectId] ?? systemL10n().subjectFallback;
          final classLabel = classLabelById[classGroupId] ?? classGroupId;
          return ClassSubjectOption(
            id: row['id'] as String,
            classGroupId: classGroupId,
            label: '$classLabel · $subjectName',
          );
        }).toList()..sort((a, b) => a.label.compareTo(b.label));
        classSubjects(options);
      } on Object catch (error) {
        errorMessage(systemL10n().couldNotLoadSubjects('$error'));
        classSubjects(const []);
      }
    });
  }

  Future<void> loadPeriods() async {
    final yearId = _academicYear.selectedYearId.value;
    if (yearId == null) {
      periods(const []);
      return;
    }

    try {
      final client = _schoolClient();
      final rows = sortAcademicPeriods(
        await client.academicPeriods.list(academicPeriodsForYear(yearId)),
      );
      periods(rows);
    } on Object catch (error) {
      errorMessage(systemL10n().couldNotLoadPeriods('$error'));
      periods(const []);
    }
  }

  String? defaultPeriodId() {
    return currentAcademicPeriodId(periods.value);
  }

  Future<String?> createEvaluation({
    required String classGroupId,
    required String classSubjectId,
    required String periodId,
    required String title,
    required double maxScore,
    required DateTime assessmentDate,
    DateTime? homeworkDueDate,
    String kind = 'quiz',
  }) async {
    final trimmedTitle = title.trim();
    if (trimmedTitle.isEmpty) {
      return systemL10n().titleRequired;
    }
    if (maxScore <= 0) {
      return systemL10n().maxScoreMustBePositive;
    }
    if (periodId.isEmpty) {
      return systemL10n().periodRequired;
    }

    errorMessage('');
    try {
      final client = _schoolClient();
      final id = 'asm-${DateTime.now().millisecondsSinceEpoch}';
      await client.createAssessment(
        createAssessmentPayload(
          id: id,
          classGroupId: classGroupId,
          classSubjectId: classSubjectId,
          periodId: periodId,
          title: trimmedTitle,
          maxScore: maxScore,
          kind: kind,
          assessmentDate: assessmentDate,
          homeworkDueDate: homeworkDueDate,
        ),
      );
      await _evaluations.loadEvaluations();
      _evaluations.selectPeriod(periodId);
      return null;
    } on api.ApiError catch (error) {
      return systemL10n().couldNotCreateEvaluation('$error');
    } on Object catch (error) {
      return systemL10n().couldNotCreateEvaluation('$error');
    }
  }
}

String _initials(String name) {
  final parts = name.trim().split(RegExp(r'\s+'));
  if (parts.isEmpty) {
    return '?';
  }
  if (parts.length == 1) {
    return parts.first.substring(0, 1).toUpperCase();
  }
  return '${parts.first.substring(0, 1)}${parts.last.substring(0, 1)}'
      .toUpperCase();
}

String _formatApiError(api.ApiError error) {
  final body = error.body;
  if (body is Map) {
    final code = body['code'];
    if (code == 'PUBLISHED_REPORT_CARD_IMMUTABLE') {
      return systemL10n().publishedReportCardImmutable;
    }
    final message = body['message'] ?? body['error'];
    if (message is String && message.isNotEmpty) {
      return message;
    }
    if (code is String && code.isNotEmpty) {
      return code;
    }
  }
  return error.message;
}

Future<int> _activeEnrollmentCount(
  api.SchoolClient client, {
  required String classGroupId,
  required String? academicYearId,
  required Map<String, int> cache,
}) async {
  final cached = cache[classGroupId];
  if (cached != null) {
    return cached;
  }
  final enrollments = await client.enrollments.list(
    activeEnrollmentsForClass(classGroupId, academicYearId: academicYearId),
  );
  cache[classGroupId] = enrollments.length;
  return enrollments.length;
}

Future<Set<String>> _publishedReportCardStudentIds(
  api.SchoolClient client, {
  required String classGroupId,
  required String periodId,
}) async {
  try {
    final rows = await client.results.list(
      publishedReportCardsForClassPeriod(classGroupId, periodId),
    );
    return rows
        .map((row) => row['studentId'] as String?)
        .whereType<String>()
        .toSet();
  } on Object {
    return const {};
  }
}
