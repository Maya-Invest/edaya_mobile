import 'dart:async';

import 'package:edaya_api_client/edaya_api_client.dart' as api;
import 'package:edaya_shared/edaya_shared.dart';
import 'package:levit_flutter/levit_flutter.dart';

import '../../live/entity_queries.dart';
import '../../live/runtime.dart';
import '../context/academic_year_controller.dart';
import 'live_evaluations_controller.dart';

class LiveMarkRow {
  const LiveMarkRow({
    required this.studentId,
    required this.fullName,
    required this.initials,
    this.photoUrl,
    this.resultId,
    this.score,
  });

  final String studentId;
  final String fullName;
  final String initials;
  final String? photoUrl;
  final String? resultId;
  final double? score;

  LiveMarkRow copyWith({String? resultId, double? score}) {
    return LiveMarkRow(
      studentId: studentId,
      fullName: fullName,
      initials: initials,
      photoUrl: photoUrl,
      resultId: resultId ?? this.resultId,
      score: score ?? this.score,
    );
  }
}

class LiveMarksController extends LevitController with LevitReactiveTasksMixin {
  LiveMarksController({
    required this.evaluationId,
    required LiveEvaluationsController evaluations,
    required AcademicYearController academicYear,
    required SchoolClientFactory schoolClient,
  }) : _evaluations = evaluations,
       _academicYear = academicYear,
       _schoolClient = schoolClient;

  final String evaluationId;
  final LiveEvaluationsController _evaluations;
  final AcademicYearController _academicYear;
  final SchoolClientFactory _schoolClient;

  final evaluation = LxVar<LiveEvaluationSummary?>(null);
  final students = LxVar<List<LiveMarkRow>>(const []);
  final errorMessage = LxVar('');
  final saveMessage = LxVar('');

  @override
  void onInit() {
    super.onInit();
    autoDispose(evaluation);
    autoDispose(students);
    autoDispose(errorMessage);
    autoDispose(saveMessage);
    evaluation(_evaluations.evaluationById(evaluationId));
    unawaited(load());
  }

  Future<void> load() async {
    errorMessage('');
    await runTask(() async {
      var summary = _evaluations.evaluationById(evaluationId);
      if (summary == null) {
        await _evaluations.loadEvaluations();
        summary = _evaluations.evaluationById(evaluationId);
      }
      evaluation(summary);
      if (summary == null) {
        students(const []);
        return;
      }
      try {
        final client = _schoolClient();
        final enrollmentRows = await client.enrollments.list(
          activeEnrollmentsForClass(
            summary.classGroupId,
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
          resultsForAssessments([summary.id]),
        );
        final scoreByStudent = {
          for (final row in results)
            if (row['studentId'] is String) row['studentId'] as String: row,
        };
        final roster = studentRows.map((row) {
          final studentId = row['id'] as String;
          final firstName = row['firstName'] as String? ?? '';
          final lastName = row['lastName'] as String? ?? '';
          final fullName = '$firstName $lastName'.trim();
          final displayName = fullName.isEmpty ? studentId : fullName;
          final result = scoreByStudent[studentId];
          return LiveMarkRow(
            studentId: studentId,
            fullName: displayName,
            initials: personInitials(displayName),
            photoUrl: row['photoUrl'] as String?,
            resultId: result?['id'] as String?,
            score: (result?['score'] as num?)?.toDouble(),
          );
        }).toList()..sort((a, b) => a.fullName.compareTo(b.fullName));
        students(roster);
      } on api.ApiError catch (error) {
        errorMessage(systemL10n().couldNotLoadMarks('$error'));
      } on Object catch (error) {
        errorMessage(systemL10n().couldNotLoadMarks('$error'));
      }
    });
  }

  Future<void> saveScore(String studentId, double? score) async {
    final summary = evaluation.value;
    if (summary == null || score == null) {
      return;
    }
    final row = students.value
        .where((item) => item.studentId == studentId)
        .firstOrNull;
    if (row == null) {
      return;
    }
    saveMessage('');
    final resultId = row.resultId ?? 'ar-${summary.id}-$studentId';
    try {
      await _schoolClient().recordAssessmentResult(
        assessmentResultPayload(
          assessmentId: summary.id,
          studentId: studentId,
          score: score,
          resultId: resultId,
        ),
      );
      students([
        for (final item in students.value)
          if (item.studentId == studentId)
            item.copyWith(resultId: resultId, score: score)
          else
            item,
      ]);
      unawaited(_evaluations.loadEvaluations());
    } on Object catch (error) {
      saveMessage('$error');
    }
  }
}
