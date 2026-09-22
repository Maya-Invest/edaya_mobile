import 'dart:async';

import 'package:edaya_api_client/edaya_api_client.dart' as api;
import 'package:edaya_shared/edaya_shared.dart';
import 'package:levit_flutter/levit_flutter.dart';

import '../../live/entity_queries.dart';
import '../context/academic_year_controller.dart';
import '../context/teacher_context_controller.dart';

class LiveEvaluationSummary {
  const LiveEvaluationSummary({
    required this.id,
    required this.title,
    required this.classGroupId,
    required this.classSubjectId,
    required this.periodId,
    required this.classLabel,
    required this.subjectLabel,
    required this.gradedCount,
    required this.totalStudents,
    this.maxScore = 20,
    this.kind = 'quiz',
    this.date,
  });

  final String id;
  final String title;
  final String classGroupId;
  final String classSubjectId;
  final String periodId;
  final String classLabel;
  final String subjectLabel;
  final int gradedCount;
  final int totalStudents;
  final double maxScore;
  final String kind;
  final String? date;

  bool get needsMarks => totalStudents > 0 && gradedCount < totalStudents;

  LiveEvaluationSummary copyWith({int? gradedCount}) {
    return LiveEvaluationSummary(
      id: id,
      title: title,
      classGroupId: classGroupId,
      classSubjectId: classSubjectId,
      periodId: periodId,
      classLabel: classLabel,
      subjectLabel: subjectLabel,
      gradedCount: gradedCount ?? this.gradedCount,
      totalStudents: totalStudents,
      maxScore: maxScore,
      kind: kind,
      date: date,
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

class LiveEvaluationsController extends LevitController
    with LevitReactiveTasksMixin {
  LiveEvaluationsController({
    required TeacherContextController teacherContext,
    required AcademicYearController academicYear,
    required SchoolClientFactory schoolClient,
  }) : _teacherContext = teacherContext,
       _academicYear = academicYear,
       _schoolClient = schoolClient;

  final TeacherContextController _teacherContext;
  final AcademicYearController _academicYear;
  final SchoolClientFactory _schoolClient;

  final evaluations = LxVar<List<LiveEvaluationSummary>>(const []);
  final periods = LxVar<List<Map<String, dynamic>>>(const []);
  final selectedPeriodId = LxVar<String?>(null);
  final classSubjects = LxVar<List<ClassSubjectOption>>(const []);
  final errorMessage = LxVar('');

  @override
  void onInit() {
    super.onInit();
    autoDispose(evaluations);
    autoDispose(periods);
    autoDispose(selectedPeriodId);
    autoDispose(classSubjects);
    autoDispose(errorMessage);
    for (final subscription in [
      _teacherContext.assignedClasses.stream,
      _teacherContext.activeAssignmentId.stream,
      _teacherContext.taughtClassSubjectIds.stream,
      _academicYear.selectedYearId.stream,
    ]) {
      autoDispose(subscription.listen((_) => unawaited(reload())));
    }
    unawaited(reload());
  }

  List<LiveEvaluationSummary> get needingMarks =>
      evaluations.value.where((item) => item.needsMarks).toList();

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

  LiveEvaluationSummary? evaluationById(String id) {
    for (final item in evaluations.value) {
      if (item.id == id) {
        return item;
      }
    }
    return null;
  }

  void selectPeriod(String periodId) {
    selectedPeriodId(periodId);
    unawaited(loadEvaluations());
  }

  Future<void> reload() async {
    await loadPeriods();
    await loadClassSubjects();
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
      final rows = sortAcademicPeriods(
        await _schoolClient().academicPeriods.list(
          academicPeriodsForYear(yearId),
        ),
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

  Future<void> loadClassSubjects() async {
    final taughtIds = _teacherContext.taughtClassSubjectIds.value;
    if (taughtIds.isEmpty) {
      classSubjects(const []);
      return;
    }
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
    } on Object {
      classSubjects(const []);
    }
  }

  Future<void> loadEvaluations() async {
    final yearId = _academicYear.selectedYearId.value;
    final taughtSubjectIds = _teacherContext.taughtClassSubjectIds.value;
    final classGroupIds = _teacherContext.visibleClassGroupIds;
    final periodId = selectedPeriodId.value;
    if (yearId == null ||
        taughtSubjectIds.isEmpty ||
        classGroupIds.isEmpty ||
        periodId == null) {
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
        final summaries = <LiveEvaluationSummary>[];
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
          var totalStudents = enrollmentCountByClass[classGroupId];
          if (totalStudents == null) {
            final enrollmentRows = await client.enrollments.list(
              activeEnrollmentsForClass(classGroupId, academicYearId: yearId),
            );
            totalStudents = enrollmentRows.length;
            enrollmentCountByClass[classGroupId] = totalStudents;
          }
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
          final subjectId = classSubjectRow['subjectId'] as String?;
          final subjectLabel = subjectId == null
              ? systemL10n().subjectFallback
              : subjectNameById[subjectId] ?? systemL10n().subjectFallback;
          for (final assessment in assessmentRows) {
            final assessmentId = assessment['id'] as String;
            summaries.add(
              LiveEvaluationSummary(
                id: assessmentId,
                title: assessment['title'] as String? ?? assessmentId,
                classGroupId: classGroupId,
                classSubjectId: classSubjectId,
                periodId: periodId,
                classLabel: classLabelById[classGroupId] ?? classGroupId,
                subjectLabel: subjectLabel,
                gradedCount: gradedByAssessment[assessmentId] ?? 0,
                totalStudents: totalStudents,
                maxScore: (assessment['maxScore'] as num?)?.toDouble() ?? 20,
                kind: assessment['kind'] as String? ?? 'quiz',
                date: assessment['startsAt'] as String? ??
                    assessment['dueAt'] as String?,
              ),
            );
          }
        }
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

  void patchGradedCount(String evaluationId, int gradedCount) {
    evaluations([
      for (final item in evaluations.value)
        if (item.id == evaluationId)
          item.copyWith(gradedCount: gradedCount)
        else
          item,
    ]);
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
    try {
      await _schoolClient().createAssessment(
        createAssessmentPayload(
          id: 'asm-${DateTime.now().millisecondsSinceEpoch}',
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
      selectPeriod(periodId);
      await loadEvaluations();
      return null;
    } on Object catch (error) {
      return systemL10n().couldNotCreateEvaluation('$error');
    }
  }

  Future<String?> duplicateEvaluation(LiveEvaluationSummary evaluation) async {
    try {
      final source = await _schoolClient().assessments.get(evaluation.id);
      await _schoolClient().createAssessment(
        createAssessmentPayload(
          id: 'asm-${DateTime.now().millisecondsSinceEpoch}',
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

  Future<String?> completeEvaluation(LiveEvaluationSummary evaluation) async {
    try {
      await _schoolClient().completeAssessment({
        'assessmentId': evaluation.id,
      });
      await loadEvaluations();
      return null;
    } on Object catch (error) {
      return systemL10n().couldNotCreateEvaluation('$error');
    }
  }
}
