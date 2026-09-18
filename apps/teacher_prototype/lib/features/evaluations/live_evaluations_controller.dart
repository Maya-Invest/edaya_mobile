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

  bool get needsMarks => totalStudents > 0 && gradedCount < totalStudents;
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
  final errorMessage = LxVar('');

  @override
  void onInit() {
    super.onInit();
    autoDispose(evaluations);
    autoDispose(errorMessage);
    for (final subscription in [
      _teacherContext.assignedClasses.stream,
      _teacherContext.activeAssignmentId.stream,
      _teacherContext.taughtClassSubjectIds.stream,
      _academicYear.selectedYearId.stream,
    ]) {
      autoDispose(subscription.listen((_) => unawaited(loadEvaluations())));
    }
    unawaited(loadEvaluations());
  }

  List<LiveEvaluationSummary> get needingMarks =>
      evaluations.value.where((item) => item.needsMarks).toList();

  LiveEvaluationSummary? evaluationById(String id) {
    for (final item in evaluations.value) {
      if (item.id == id) {
        return item;
      }
    }
    return null;
  }

  Future<void> loadEvaluations() async {
    final yearId = _academicYear.selectedYearId.value;
    final taughtSubjectIds = _teacherContext.taughtClassSubjectIds.value;
    final classGroupIds = _teacherContext.visibleClassGroupIds;
    if (yearId == null || taughtSubjectIds.isEmpty || classGroupIds.isEmpty) {
      evaluations(const []);
      return;
    }

    errorMessage('');
    await runTask(() async {
      try {
        final client = _schoolClient();
        final periods = sortAcademicPeriods(
          await client.academicPeriods.list(academicPeriodsForYear(yearId)),
        );
        final periodId = currentAcademicPeriodId(periods);
        if (periodId == null) {
          evaluations(const []);
          return;
        }

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
}
