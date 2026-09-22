import 'dart:async';

import 'package:edaya_api_client/edaya_api_client.dart' as api;
import 'package:edaya_shared/edaya_shared.dart';
import 'package:levit_flutter/levit_flutter.dart';

import '../../live/entity_queries.dart';
import '../../live/runtime.dart';
import '../context/academic_year_controller.dart';
import '../context/teacher_context_controller.dart';
import 'live_evaluations_controller.dart';

enum MarkSyncState { synced, pending, failed }

class LiveMarkRow {
  const LiveMarkRow({
    required this.studentId,
    required this.fullName,
    required this.initials,
    this.photoUrl,
    this.resultId,
    this.score,
    this.marksLocked = false,
    this.syncState = MarkSyncState.synced,
  });

  final String studentId;
  final String fullName;
  final String initials;
  final String? photoUrl;
  final String? resultId;
  final double? score;
  final bool marksLocked;
  final MarkSyncState syncState;

  static const Object _unset = Object();

  LiveMarkRow copyWith({
    Object? resultId = _unset,
    Object? score = _unset,
    bool? marksLocked,
    MarkSyncState? syncState,
  }) {
    return LiveMarkRow(
      studentId: studentId,
      fullName: fullName,
      initials: initials,
      photoUrl: photoUrl,
      resultId: identical(resultId, _unset) ? this.resultId : resultId as String?,
      score: identical(score, _unset) ? this.score : score as double?,
      marksLocked: marksLocked ?? this.marksLocked,
      syncState: syncState ?? this.syncState,
    );
  }
}

class LiveMarksController extends LevitController with LevitReactiveTasksMixin {
  LiveMarksController({
    required this.evaluationId,
    required LiveEvaluationsController evaluations,
    required AcademicYearController academicYear,
    required TeacherContextController teacherContext,
    required SchoolClientFactory schoolClient,
    TeacherOutboxStore? outboxStore,
    TeacherOutboxContext? Function()? outboxContext,
  }) : _evaluations = evaluations,
       _academicYear = academicYear,
       _teacherContext = teacherContext,
       _schoolClient = schoolClient,
       _outboxStore = outboxStore ?? openTeacherOutboxStore(),
       _outboxContext = outboxContext;

  final String evaluationId;
  final LiveEvaluationsController _evaluations;
  final AcademicYearController _academicYear;
  final TeacherContextController _teacherContext;
  final SchoolClientFactory _schoolClient;
  final TeacherOutboxStore _outboxStore;
  final TeacherOutboxContext? Function()? _outboxContext;

  final evaluation = LxVar<LiveEvaluationSummary?>(null);
  final students = LxVar<List<LiveMarkRow>>(const []);
  final ungradedOnly = LxVar(false);
  final errorMessage = LxVar('');
  final saveMessage = LxVar('');

  @override
  void onInit() {
    super.onInit();
    autoDispose(evaluation);
    autoDispose(students);
    autoDispose(ungradedOnly);
    autoDispose(errorMessage);
    autoDispose(saveMessage);
    evaluation(_evaluations.evaluationById(evaluationId));
    unawaited(load());
  }

  List<LiveMarkRow> get visibleStudents {
    final rows = students.value;
    if (!ungradedOnly.value) {
      return rows;
    }
    return rows.where((row) => row.score == null).toList();
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
        final enrollmentRows = await client.enrollments.listAll(
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
            : await client.students.listAll(entitiesByIds(studentIds));
        final results = await client.assessmentResults.listAll(
          resultsForAssessments([summary.id]),
        );
        final lockedStudentIds = await _publishedReportCardStudentIds(
          client,
          classGroupId: summary.classGroupId,
          periodId: summary.periodId,
        );
        if (lockedStudentIds == null) {
          errorMessage(systemL10n().couldNotLoadMarks(''));
          return;
        }
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
            marksLocked: lockedStudentIds.contains(studentId),
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
    if (summary == null) {
      return;
    }
    if (score != null && (score < 0 || score > summary.maxScore)) {
      saveMessage(systemL10n().maxScoreMustBePositive);
      return;
    }
    final row = students.value
        .where((item) => item.studentId == studentId)
        .firstOrNull;
    if (row == null || row.marksLocked) {
      if (row?.marksLocked ?? false) {
        saveMessage(systemL10n().publishedReportCardImmutable);
      }
      return;
    }
    if (!_teacherContext.taughtClassSubjectIds.value.contains(
          summary.classSubjectId,
        ) &&
        _teacherContext.taughtClassSubjectIds.value.isNotEmpty) {
      saveMessage(systemL10n().couldNotSaveMark('403'));
      return;
    }
    saveMessage('');
    _outboxStore.bindContext(_outboxContext?.call());
    final resultId = row.resultId ?? 'ar-${summary.id}-$studentId';
    _patchRow(
      studentId,
      resultId: resultId,
      score: score,
      syncState: MarkSyncState.pending,
    );
    final idempotencyKey = teacherMarkIdempotencyKey(
      assessmentId: summary.id,
      studentId: studentId,
    );
    try {
      await _schoolClient().recordAssessmentResult(
        assessmentResultPayload(
          assessmentId: summary.id,
          studentId: studentId,
          score: score,
          resultId: resultId,
        ),
      );
      await _outboxStore.removeByIdempotencyKey(idempotencyKey);
      _patchRow(
        studentId,
        resultId: resultId,
        score: score,
        syncState: MarkSyncState.synced,
      );
      _evaluations.patchGradedCount(
        summary.id,
        students.value.where((item) => item.score != null).length,
      );
    } on Object catch (error) {
      final retryable = isRetryableTeacherWriteFailure(error);
      await _outboxStore.enqueue(
        buildTeacherOutboxEntry(
          id: resultId,
          kind: TeacherOutboxKind.mark,
          idempotencyKey: idempotencyKey,
          payload: markOutboxPayload(
            assessmentId: summary.id,
            studentId: studentId,
            score: score,
            resultId: resultId,
          ),
          lastError: '$error',
          state: retryable
              ? TeacherOutboxState.pending
              : TeacherOutboxState.rejected,
        ),
      );
      _patchRow(
        studentId,
        resultId: resultId,
        score: score,
        syncState: retryable ? MarkSyncState.pending : MarkSyncState.failed,
      );
      saveMessage(
        retryable
            ? systemL10n().attendanceSavedLocally
            : systemL10n().couldNotSaveMark('$error'),
      );
    }
  }

  Future<void> fillUngraded(double score) async {
    for (final row in students.value) {
      if (row.score != null || row.marksLocked) {
        continue;
      }
      await saveScore(row.studentId, score);
    }
  }

  Future<void> clearUnlocked() async {
    for (final row in students.value) {
      if (row.marksLocked || row.score == null) {
        continue;
      }
      await saveScore(row.studentId, null);
    }
  }

  void _patchRow(
    String studentId, {
    String? resultId,
    double? score,
    MarkSyncState? syncState,
  }) {
    students([
      for (final item in students.value)
        if (item.studentId == studentId)
          item.copyWith(
            resultId: resultId,
            score: score,
            syncState: syncState,
          )
        else
          item,
    ]);
  }

  Future<Set<String>?> _publishedReportCardStudentIds(
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
      errorMessage(systemL10n().couldNotLoadMarks(''));
      return null;
    }
  }
}
