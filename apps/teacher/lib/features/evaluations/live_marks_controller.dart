import 'dart:async';

import 'package:edaya_api_client/edaya_api_client.dart' as api;
import 'package:edaya_shared/edaya_shared.dart';
import 'package:levit_flutter/levit_flutter.dart';

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
    this.designation,
    this.marksLocked = false,
    this.syncState = MarkSyncState.synced,
  });

  final String studentId;
  final String fullName;
  final String initials;
  final String? photoUrl;
  final String? resultId;
  final double? score;
  final String? designation;
  final bool marksLocked;
  final MarkSyncState syncState;

  static const Object _unset = Object();

  LiveMarkRow copyWith({
    Object? resultId = _unset,
    Object? score = _unset,
    Object? designation = _unset,
    bool? marksLocked,
    MarkSyncState? syncState,
  }) {
    return LiveMarkRow(
      studentId: studentId,
      fullName: fullName,
      initials: initials,
      photoUrl: photoUrl,
      resultId: identical(resultId, _unset)
          ? this.resultId
          : resultId as String?,
      score: identical(score, _unset) ? this.score : score as double?,
      designation: identical(designation, _unset)
          ? this.designation
          : designation as String?,
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
       _teacherContext = teacherContext,
       _schoolClient = schoolClient,
       _outboxStore = outboxStore ?? openTeacherOutboxStore(),
       _outboxContext = outboxContext;

  final String evaluationId;
  final LiveEvaluationsController _evaluations;
  final TeacherContextController _teacherContext;
  final SchoolClientFactory _schoolClient;
  final TeacherOutboxStore _outboxStore;
  final TeacherOutboxContext? Function()? _outboxContext;

  final evaluation = LxVar<LiveEvaluationSummary?>(null);
  final students = LxVar<List<LiveMarkRow>>(const []);
  final ungradedOnly = LxVar(false);
  final errorMessage = LxVar('');
  final saveMessage = LxVar('');
  final marksStatus = LxVar('draft');
  final returnReason = LxVar('');
  final canSubmit = LxVar(false);
  int _revision = 0;
  bool _saving = false;

  @override
  void onInit() {
    super.onInit();
    autoDispose(evaluation);
    autoDispose(students);
    autoDispose(ungradedOnly);
    autoDispose(errorMessage);
    autoDispose(saveMessage);
    autoDispose(marksStatus);
    autoDispose(returnReason);
    autoDispose(canSubmit);
    evaluation(_evaluations.evaluationById(evaluationId));
    unawaited(load());
  }

  List<LiveMarkRow> get visibleStudents {
    final rows = students.value;
    if (!ungradedOnly.value) {
      return rows;
    }
    return rows
        .where(
          (row) =>
              row.score == null &&
              row.designation != 'absent' &&
              row.designation != 'exempt',
        )
        .toList();
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
        final review = await client.getAssessmentMarksReview({
          'assessmentId': evaluationId,
        });
        final sheet = (review['assessment'] as Map).cast<String, dynamic>();
        _revision = (sheet['marksRevision'] as num).toInt();
        marksStatus(sheet['marksStatus'] as String);
        canSubmit((review['allowedActions'] as Map)['submit'] == true);
        final history =
            ((sheet['marksReview'] as Map?)?['history'] as List?) ?? [];
        returnReason(
          history
                      .whereType<Map>()
                      .where((event) => event['action'] == 'return')
                      .lastOrNull?['reason']
                  as String? ??
              '',
        );
        _outboxStore.bindContext(_outboxContext?.call());
        final pending = await _outboxStore.listPending();
        for (final entry in pending.where(
          (row) =>
              row.kind == TeacherOutboxKind.mark &&
              row.payload['assessmentId'] == evaluationId,
        )) {
          final next =
              ((entry.payload['expectedRevision'] as num?)?.toInt() ??
                  _revision) +
              1;
          if (next > _revision) _revision = next;
        }
        final studentRows = (review['students'] as List).cast<Map>();
        final results = (review['results'] as List).cast<Map>();
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
            designation: result?['designation'] as String?,
            marksLocked: marksStatus.value != 'draft',
          );
        }).toList()..sort((a, b) => a.fullName.compareTo(b.fullName));
        students(roster);
        for (final entry in pending.where(
          (row) =>
              row.kind == TeacherOutboxKind.mark &&
              row.payload['assessmentId'] == evaluationId,
        )) {
          _patchRow(
            entry.payload['studentId'] as String,
            resultId: entry.payload['id'] as String?,
            score: (entry.payload['score'] as num?)?.toDouble(),
            designation: entry.payload['designation'] as String?,
            syncState: teacherOutboxEntryIsReplayable(entry)
                ? MarkSyncState.pending
                : MarkSyncState.failed,
          );
        }
      } on api.ApiError catch (error) {
        errorMessage(systemL10n().couldNotLoadMarks('$error'));
      } on Object catch (error) {
        errorMessage(systemL10n().couldNotLoadMarks('$error'));
      }
    });
  }

  Future<void> saveScore(
    String studentId,
    double? score, {
    String? designation,
  }) async {
    if (_saving || marksStatus.value != 'draft') return;
    final summary = evaluation.value;
    if (summary == null) {
      return;
    }
    if (score != null &&
        (!score.isFinite || score < 0 || score > summary.maxScore)) {
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
      designation: designation ?? (score != null ? 'scored' : null),
      syncState: MarkSyncState.pending,
    );
    final requestId = newSchoolRequestId();
    final idempotencyKey = requestId;
    final payload = assessmentResultPayload(
      assessmentId: summary.id,
      studentId: studentId,
      score: score,
      designation: designation,
      resultId: resultId,
      requestId: requestId,
      expectedRevision: _revision,
    );
    _saving = true;
    try {
      if ((await _outboxStore.listPending()).any(
        (entry) =>
            entry.kind == TeacherOutboxKind.mark &&
            entry.payload['assessmentId'] == evaluationId,
      )) {
        throw Exception('offline pending marks');
      }
      await _schoolClient().recordAssessmentResult(payload);
      _revision++;
      await _outboxStore.removeByIdempotencyKey(idempotencyKey);
      _patchRow(
        studentId,
        resultId: resultId,
        score: score,
        designation: designation ?? (score != null ? 'scored' : null),
        syncState: MarkSyncState.synced,
      );
      _evaluations.patchGradedCount(
        summary.id,
        students.value.where((item) => item.score != null).length,
      );
    } on Object catch (error) {
      final retryable = isRetryableTeacherWriteFailure(error);
      if (retryable) _revision++;
      await _outboxStore.enqueue(
        buildTeacherOutboxEntry(
          id: requestId,
          kind: TeacherOutboxKind.mark,
          idempotencyKey: idempotencyKey,
          payload: payload,
          lastError: '$error',
          state: retryable
              ? TeacherOutboxState.pending
              : TeacherOutboxState.conflict,
        ),
      );
      _patchRow(
        studentId,
        resultId: resultId,
        score: score,
        designation: designation ?? (score != null ? 'scored' : null),
        syncState: retryable ? MarkSyncState.pending : MarkSyncState.failed,
      );
      saveMessage(
        retryable
            ? systemL10n().attendanceSavedLocally
            : systemL10n().couldNotSaveMark('$error'),
      );
    } finally {
      _saving = false;
    }
  }

  Future<void> fillUngraded(double score) async {
    for (final row in students.value) {
      if (row.score != null ||
          row.designation == 'absent' ||
          row.designation == 'exempt' ||
          row.marksLocked) {
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
    String? designation,
    MarkSyncState? syncState,
  }) {
    students([
      for (final item in students.value)
        if (item.studentId == studentId)
          item.copyWith(
            resultId: resultId,
            score: score,
            designation: designation,
            syncState: syncState,
          )
        else
          item,
    ]);
  }

  Future<void> saveScoreText(String studentId, String value) async {
    final normalized = value.trim().replaceAll(',', '.');
    final score = double.tryParse(normalized);
    if (normalized.isNotEmpty && (score == null || !score.isFinite)) {
      saveMessage(
        systemL10n().couldNotSaveMark(systemL10n().marksInvalidNumber),
      );
      return;
    }
    await saveScore(studentId, score);
  }

  Future<void> submitMarks() async {
    if (_saving || marksStatus.value != 'draft') return;
    _saving = true;
    try {
      _outboxStore.bindContext(_outboxContext?.call());
      final entries = await _outboxStore.listPending();
      final client = _schoolClient();
      for (final entry in entries.where(
        (entry) =>
            entry.kind == TeacherOutboxKind.mark &&
            entry.payload['assessmentId'] == evaluationId,
      )) {
        if (!teacherOutboxEntryIsReplayable(entry)) {
          throw StateError(systemL10n().marksResolveConflicts);
        }
        try {
          await syncTeacherOutboxEntry(client, entry);
          await _outboxStore.remove(entry.id);
        } on Object catch (error) {
          await _outboxStore.upsert(
            entry.copyWith(
              state: isRetryableTeacherWriteFailure(error)
                  ? TeacherOutboxState.failed
                  : TeacherOutboxState.conflict,
              lastError: '$error',
            ),
          );
          rethrow;
        }
      }
      await load();
      await client.submitAssessmentMarks({
        'requestId': newSchoolRequestId(),
        'assessmentId': evaluationId,
        'expectedRevision': _revision,
      });
      await load();
      saveMessage(systemL10n().marksSubmitted);
    } on Object catch (error) {
      saveMessage('Soumission impossible : $error');
    } finally {
      _saving = false;
    }
  }
}
