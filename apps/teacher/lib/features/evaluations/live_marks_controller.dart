import 'dart:async';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

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
    this.official = const {},
    this.resultId,
    this.score,
    this.mentionId,
    this.mentionCode,
    this.designation,
    this.marksLocked = false,
    this.published = false,
    this.notes,
    this.deadlineStatus,
    this.syncState = MarkSyncState.synced,
  });

  final Map<String, dynamic> official;
  final String studentId;
  final String fullName;
  final String initials;
  final String? photoUrl;
  final String? resultId;
  final double? score;
  final String? mentionId;
  final String? mentionCode;
  final String? designation;
  final bool marksLocked;
  final bool published;
  final String? notes;
  final String? deadlineStatus;
  final MarkSyncState syncState;

  static const Object _unset = Object();

  LiveMarkRow copyWith({
    Object? resultId = _unset,
    Object? score = _unset,
    Object? mentionId = _unset,
    Object? designation = _unset,
    bool? marksLocked,
    MarkSyncState? syncState,
  }) {
    return LiveMarkRow(
      studentId: studentId,
      official: official,
      fullName: fullName,
      initials: initials,
      photoUrl: photoUrl,
      resultId: identical(resultId, _unset)
          ? this.resultId
          : resultId as String?,
      mentionId: identical(mentionId, _unset)
          ? this.mentionId
          : mentionId as String?,
      mentionCode: mentionCode,
      score: identical(score, _unset) ? this.score : score as double?,
      designation: identical(designation, _unset)
          ? this.designation
          : designation as String?,
      marksLocked: marksLocked ?? this.marksLocked,
      published: published,
      notes: notes,
      deadlineStatus: deadlineStatus,
      syncState: syncState ?? this.syncState,
    );
  }
}

/// Local entry text is deliberately separate from confirmed/queued results.
class MarkDraft {
  const MarkDraft({this.text = '', this.designation, this.mentionId});
  factory MarkDraft.fromRow(LiveMarkRow row) => MarkDraft(
    text: row.score == null ? '' : formatGradeNumber(row.score),
    designation: row.designation,
    mentionId: row.mentionId,
  );
  final String text;
  final String? designation, mentionId;
  double? get score => double.tryParse(text.trim().replaceAll(',', '.'));
  bool get exceptional => designation == 'absent' || designation == 'exempt';
  Map<String, dynamic> get values => {
    'score': exceptional ? null : score,
    'mentionId': exceptional ? null : mentionId,
    'designation': exceptional
        ? designation
        : (score != null || mentionId != null ? 'scored' : null),
  };
  bool matches(LiveMarkRow row) =>
      (text.trim().isEmpty || score != null) &&
      values['score'] == row.score &&
      values['mentionId'] == row.mentionId &&
      values['designation'] == row.designation;
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
  String mentionLabel(String id) =>
      (mentions.where((range) => range['id'] == id).firstOrNull?['letter']
          as String?) ??
      students.value
          .where((row) => row.mentionId == id)
          .firstOrNull
          ?.mentionCode ??
      id;

  final gradingPolicy = LxVar<GradingPolicyView?>(null);
  bool get mentionFirst => gradingPolicy.value?.mentionFirst ?? false;
  List<Map<String, dynamic>> get mentions =>
      gradingPolicy.value?.intervals ?? const [];
  final marksStatus = LxVar('draft');
  final canRequestCorrection = LxVar(false);
  final corrections = LxVar<List<Map<String, dynamic>>>(const []);
  final canSubmit = LxVar(false);
  int _revision = 0;
  final writing = LxVar(false);
  final submitting = LxVar(false);
  final edits = LxVar<Map<String, MarkDraft>>({});
  final entryErrors = LxVar<Map<String, String>>({});
  final pendingScoreInputs = LxVar<Map<String, String>>({});
  Future<void> _draftWrites = Future<void>.value();
  bool get _saving => writing.value;
  set _saving(bool value) {
    if (!isClosed) writing(value);
  }

  @override
  void onInit() {
    super.onInit();
    autoDispose(evaluation);
    autoDispose(students);
    autoDispose(ungradedOnly);
    autoDispose(errorMessage);
    autoDispose(saveMessage);
    autoDispose(marksStatus);
    autoDispose(gradingPolicy);
    autoDispose(canRequestCorrection);
    autoDispose(writing);
    autoDispose(submitting);
    autoDispose(pendingScoreInputs);
    autoDispose(edits);
    autoDispose(entryErrors);
    autoDispose(corrections);
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
              row.mentionId == null &&
              row.designation != 'absent' &&
              row.designation != 'exempt',
        )
        .toList();
  }

  Future<void> load() async {
    errorMessage('');
    await runTask(() async {
      try {
        final client = _schoolClient();
        // A marks deep link must resolve independently of the class/period
        // currently selected in the evaluations list. The review query enforces
        // access to this assessment before any roster is displayed.
        final review = await client.getAssessmentMarksReview({
          'assessmentId': evaluationId,
        });
        if (isClosed) return;
        final sheet = (review['assessment'] as Map).cast<String, dynamic>();
        var summary = _evaluations.evaluationById(evaluationId);
        if (summary == null) {
          final classId = sheet['classGroupId'] as String;
          final classSubjectId = sheet['classSubjectId'] as String;
          final classGroup = await client.classGroups.get(classId);
          final classSubject = await client.classSubjects.get(classSubjectId);
          final subject = await client.subjects.get(
            classSubject['subjectId'] as String,
          );
          summary = LiveEvaluationSummary(
            id: evaluationId,
            title: sheet['title'] as String,
            classGroupId: classId,
            classSubjectId: classSubjectId,
            periodId: sheet['periodId'] as String,
            classLabel: classGroup['name'] as String? ?? classId,
            subjectLabel: subject['name'] as String? ?? classSubjectId,
            gradedCount: (review['results'] as List).length,
            totalStudents: (review['students'] as List).length,
            maxScore: (sheet['maxScore'] as num).toDouble(),
            coefficient: sheet['coefficient'] as num?,
            kind: sheet['kind'] as String? ?? 'quiz',
            date: (sheet['startsAt'] ?? sheet['dueAt']) as String?,
          );
        }
        if (isClosed) return;
        gradingPolicy(
          review['gradingPolicy'] is Map
              ? GradingPolicyView(
                  Map<String, dynamic>.from(review['gradingPolicy'] as Map),
                )
              : null,
        );
        evaluation(summary);
        _revision = (sheet['marksRevision'] as num).toInt();
        marksStatus(sheet['marksStatus'] as String);
        canSubmit((review['allowedActions'] as Map)['submit'] == true);
        canRequestCorrection(
          (review['allowedActions'] as Map)['requestCorrection'] == true,
        );
        corrections(
          (review['corrections'] as List? ?? [])
              .map((row) => (row as Map).cast<String, dynamic>())
              .toList(),
        );
        final published = (review['publishedResultIds'] as List? ?? [])
            .cast<String>()
            .toSet();
        _outboxStore.bindContext(_outboxContext?.call());
        final pending = await _outboxStore.listPending();
        if (isClosed) return;
        for (final entry in pending.where(
          (row) =>
              row.kind == TeacherOutboxKind.mark &&
              row.payload['assessmentId'] == evaluationId,
        )) {
          final next =
              ((entry.payload['expectedRevision'] as num?)?.toInt() ??
                  _revision) +
              ((entry.payload['results'] as List?)?.length ?? 1);
          if (marksStatus.value == 'draft' && next > _revision) {
            _revision = next;
          }
        }
        final studentRows = (review['students'] as List).cast<Map>();
        final captured =
            ((sheet['marksReview'] as Map?)?['rosterStudentIds'] as List?)
                ?.toSet();
        final loaded = studentRows.map((s) => s['id']).toSet();
        final rawResults = (review['results'] as List)
            .map((r) => Map<String, dynamic>.from(r as Map))
            .toList();
        final results = withOfficialRanks(
          rawResults,
          complete:
              marksStatus.value == 'submitted' &&
              captured != null &&
              captured.isNotEmpty &&
              loaded.containsAll(captured) &&
              rawResults
                  .map((r) => r['studentId'])
                  .toSet()
                  .containsAll(captured) &&
              rawResults.every((r) => captured.contains(r['studentId'])),
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
            official: {
              if (result != null) ...result.cast<String, dynamic>(),
              'maxScore': sheet['maxScore'],
            },
            fullName: displayName,
            initials: personInitials(displayName),
            photoUrl: row['photoUrl'] as String?,
            resultId: result?['id'] as String?,
            score: (result?['score'] as num?)?.toDouble(),
            mentionId: result?['mentionId'] as String?,
            mentionCode: (result?['originalEntry'] as Map?)?['code'] as String?,
            designation: result?['designation'] as String?,
            marksLocked: marksStatus.value != 'draft',
            published: published.contains(result?['id']),
            notes: result?['notes'] as String?,
            deadlineStatus: result?['status'] as String?,
          );
        }).toList()..sort((a, b) => a.fullName.compareTo(b.fullName));
        students(roster);
        for (final entry in pending.where(
          (row) =>
              row.kind == TeacherOutboxKind.mark &&
              row.payload['assessmentId'] == evaluationId,
        )) {
          if (marksStatus.value != 'draft') {
            await _outboxStore.upsert(
              entry.copyWith(
                state: TeacherOutboxState.conflict,
                lastError: systemL10n().marksResolveConflicts,
              ),
            );
            saveMessage(systemL10n().marksResolveConflicts);
            continue;
          }
          for (final payload in _entryRows(entry)) {
            _patchRow(
              payload['studentId'] as String,
              resultId: payload['id'] as String?,
              score: (payload['score'] as num?)?.toDouble(),
              mentionId: payload['mentionId'] as String?,
              designation: payload['designation'] as String?,
              syncState: teacherOutboxEntryIsReplayable(entry)
                  ? MarkSyncState.pending
                  : MarkSyncState.failed,
            );
          }
        }
      } on api.ApiError catch (error) {
        errorMessage(systemL10n().couldNotLoadMarks('$error'));
      } on Object catch (error) {
        errorMessage(systemL10n().couldNotLoadMarks('$error'));
      }
    });
  }

  Iterable<Map<String, dynamic>> _entryRows(TeacherOutboxEntry entry) =>
      entry.payload['results'] is List
      ? (entry.payload['results'] as List).map(
          (r) => Map<String, dynamic>.from(r as Map),
        )
      : [entry.payload];

  MarkDraft draftFor(LiveMarkRow row) =>
      edits.value[row.studentId] ?? MarkDraft.fromRow(row);
  void editMark(String studentId, MarkDraft draft) {
    if (isClosed ||
        writing.value ||
        submitting.value ||
        marksStatus.value != 'draft') {
      return;
    }
    final row = students.value
        .where((r) => r.studentId == studentId)
        .firstOrNull;
    if (row == null || row.marksLocked || row.published) return;
    final next = {...edits.value};
    if (draft.matches(row)) {
      next.remove(studentId);
    } else {
      next[studentId] = draft;
    }
    edits(next);
    final errors = {...entryErrors.value}..remove(studentId);
    if (draft.text.trim().isNotEmpty && !validDraft(draft)) {
      errors[studentId] = systemL10n().gradebookInvalid;
    }
    entryErrors(errors);
  }

  bool validDraft(MarkDraft draft) =>
      draft.exceptional ||
      (mentionFirst
          ? draft.text.trim().isEmpty &&
                (draft.mentionId == null ||
                    mentions.any((m) => m['id'] == draft.mentionId))
          : draft.text.trim().isEmpty ||
                (draft.score != null &&
                    draft.score!.isFinite &&
                    draft.score! >= 0 &&
                    draft.score! <= (evaluation.value?.maxScore ?? 20)));
  bool completeDraft(MarkDraft draft) =>
      validDraft(draft) &&
      (draft.exceptional ||
          (mentionFirst ? draft.mentionId != null : draft.score != null));
  int get completedCount =>
      students.value.where((r) => completeDraft(draftFor(r))).length;
  bool get hasUnsaved => edits.value.isNotEmpty;
  void discardEdits() {
    edits({});
    entryErrors({});
  }

  /// Save only an explicit user-confirmed snapshot; retries retain batch identity.
  Future<bool> saveDraft() async {
    if (isClosed ||
        _saving ||
        submitting.value ||
        marksStatus.value != 'draft') {
      return false;
    }
    final snapshot = {...edits.value};
    final errors = <String, String>{};
    for (final row in students.value) {
      if (snapshot.containsKey(row.studentId) &&
          (!validDraft(snapshot[row.studentId]!) ||
              row.marksLocked ||
              row.published)) {
        errors[row.studentId] = systemL10n().gradebookInvalid;
      }
    }
    entryErrors(errors);
    if (errors.isNotEmpty) return false;
    _saving = true;
    saveMessage('');
    _outboxStore.bindContext(_outboxContext?.call());
    final client = _schoolClient();
    try {
      // Replay prior batches first. Never predict a revision after a failed save.
      final queued = (await _outboxStore.listPending())
          .where(
            (e) =>
                e.kind == TeacherOutboxKind.mark &&
                e.payload['assessmentId'] == evaluationId,
          )
          .toList();
      for (final entry in queued.where(
        (e) =>
            e.kind == TeacherOutboxKind.mark &&
            e.payload['assessmentId'] == evaluationId,
      )) {
        if (!teacherOutboxEntryIsReplayable(entry)) {
          throw StateError(systemL10n().marksResolveConflicts);
        }
        await syncTeacherOutboxEntry(client, entry);
        await _outboxStore.remove(entry.id);
      }
      if (isClosed) return false;
      if (snapshot.isEmpty) {
        await load();
        return errorMessage.value.isEmpty;
      }
      // Refresh revisions after queued writes, retaining all local inputs.
      if (queued.isNotEmpty) await load();
      if (isClosed ||
          errorMessage.value.isNotEmpty ||
          marksStatus.value != 'draft') {
        return false;
      }
      if (snapshot.keys.any(
        (id) => !students.value.any(
          (r) => r.studentId == id && !r.marksLocked && !r.published,
        ),
      )) {
        throw StateError(systemL10n().gradebookLocked);
      }
      final payload = <String, dynamic>{
        'requestId': newSchoolRequestId(),
        'assessmentId': evaluationId,
        'expectedRevision': _revision,
        'expectedGradingRevision': gradingPolicy.value?.revision ?? 0,
        'results': [
          for (final row in students.value)
            if (snapshot.containsKey(row.studentId))
              {
                'id': row.resultId ?? 'ar-$evaluationId-${row.studentId}',
                'studentId': row.studentId,
                for (final value in snapshot[row.studentId]!.values.entries)
                  if (value.value != null) value.key: value.value,
              },
        ],
      };
      final requestId = payload['requestId'] as String;
      // Persist before sending, so an uncertain response can be replayed once.
      final entry = buildTeacherOutboxEntry(
        id: requestId,
        kind: TeacherOutboxKind.mark,
        idempotencyKey: requestId,
        payload: payload,
      );
      await _outboxStore.enqueue(entry);
      try {
        await client.runListCommand('record-assessment-results', payload);
        await _outboxStore.remove(entry.id);
      } on Object catch (error) {
        final retryable = isRetryableTeacherWriteFailure(error);
        await _outboxStore.upsert(
          entry.copyWith(
            state: retryable
                ? TeacherOutboxState.pending
                : TeacherOutboxState.conflict,
            lastError: '$error',
          ),
        );
        if (isClosed) return false;
        if (retryable) {
          for (final value in _entryRows(entry)) {
            _patchRow(
              value['studentId'] as String,
              resultId: value['id'] as String,
              score: (value['score'] as num?)?.toDouble(),
              mentionId: value['mentionId'] as String?,
              designation: value['designation'] as String?,
              syncState: MarkSyncState.pending,
            );
          }
          discardEdits();
          saveMessage(systemL10n().gradebookQueued);
          return true;
        }
        rethrow;
      }
      if (isClosed) return false;
      discardEdits();
      await load();
      saveMessage(systemL10n().gradebookSaved);
      return errorMessage.value.isEmpty;
    } on Object catch (error) {
      if (!isClosed) saveMessage(systemL10n().couldNotSaveMark('$error'));
      return false;
    } finally {
      _saving = false;
    }
  }

  /// User explicitly reviews current server values before retrying a rejected batch.
  Future<void> reviewSaveFailure() async {
    if (_saving || submitting.value) return;
    _outboxStore.bindContext(_outboxContext?.call());
    final pending = await _outboxStore.listPending();
    for (final entry in pending.where(
      (e) =>
          e.kind == TeacherOutboxKind.mark &&
          e.payload['assessmentId'] == evaluationId &&
          !teacherOutboxEntryIsReplayable(e),
    )) {
      final local = {...edits.value};
      for (final value in _entryRows(entry)) {
        local.putIfAbsent(
          value['studentId'] as String,
          () => MarkDraft(
            text: value['score'] == null
                ? ''
                : formatGradeNumber(value['score'] as num),
            mentionId: value['mentionId'] as String?,
            designation: value['designation'] as String?,
          ),
        );
      }
      edits(local);
      await _outboxStore.remove(entry.id);
    }
    await load();
    if (!isClosed && errorMessage.value.isEmpty) saveMessage('');
  }

  Future<void> saveAndSubmit() async {
    if (writing.value || submitting.value) return;
    final errors = <String, String>{
      for (final row in students.value)
        if (!completeDraft(draftFor(row)))
          row.studentId: systemL10n().gradebookMissing,
    };
    entryErrors(errors);
    if (errors.isNotEmpty || students.value.isEmpty) return;
    if (await saveDraft()) await submitMarks();
  }

  Map<String, dynamic>? pendingFor(LiveMarkRow row) => corrections.value
      .where(
        (c) =>
            c['status'] == 'pending' &&
            (c['changes'] as List).any(
              (v) => (v as Map)['resultId'] == row.resultId,
            ),
      )
      .firstOrNull;
  bool canEditCorrection(LiveMarkRow row) {
    final pending = pendingFor(row);
    return !row.published &&
        row.resultId != null &&
        (pending == null
            ? canRequestCorrection.value
            : (pending['allowedActions'] as Map?)?['withdraw'] == true);
  }

  Future<bool> correctPupil(
    LiveMarkRow row,
    Map<String, dynamic> proposed,
    String reason,
  ) {
    final pending = pendingFor(row);
    final changes = <Map<String, dynamic>>[
      if (pending != null)
        for (final raw in pending['changes'] as List)
          if ((raw as Map)['resultId'] != row.resultId)
            {'resultId': raw['resultId'], 'proposed': raw['proposed']},
      {'resultId': row.resultId, 'proposed': proposed},
    ];
    final grouped = pending != null && (pending['changes'] as List).length > 1;
    return requestCorrection(
      changes,
      grouped ? pending['reason'] as String : reason,
      correction: pending,
    );
  }

  Future<bool> withdrawPupil(LiveMarkRow row) async {
    final pending = pendingFor(row);
    if (pending == null ||
        (pending['allowedActions'] as Map?)?['withdraw'] != true) {
      return false;
    }
    final remaining = <Map<String, dynamic>>[
      for (final raw in pending['changes'] as List)
        if ((raw as Map)['resultId'] != row.resultId)
          {'resultId': raw['resultId'], 'proposed': raw['proposed']},
    ];
    if (remaining.isNotEmpty) {
      return requestCorrection(
        remaining,
        pending['reason'] as String,
        correction: pending,
      );
    }
    await withdrawCorrection(pending);
    return !isClosed && pendingFor(row) == null;
  }

  Future<void> saveScore(
    String studentId,
    double? score, {
    String? designation,
    String? mentionId,
  }) {
    if (isClosed || submitting.value) return Future<void>.value();
    final write = _draftWrites.then(
      (_) => _saveScore(
        studentId,
        score,
        designation: designation,
        mentionId: mentionId,
      ),
    );
    _draftWrites = write.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    return write;
  }

  Future<void> _saveScore(
    String studentId,
    double? score, {
    String? designation,
    String? mentionId,
  }) async {
    if (isClosed || _saving || marksStatus.value != 'draft') return;
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
    if (mentionFirst &&
        (score != null ||
            (mentionId != null &&
                !mentions.any((range) => range['id'] == mentionId)))) {
      saveMessage(systemL10n().marksInvalidNumber);
      return;
    }
    saveMessage('');
    _outboxStore.bindContext(_outboxContext?.call());
    final resultId = row.resultId ?? 'ar-${summary.id}-$studentId';
    _patchRow(
      studentId,
      resultId: resultId,
      score: score,
      mentionId: mentionId,
      designation:
          designation ?? (score != null || mentionId != null ? 'scored' : null),
      syncState: MarkSyncState.pending,
    );
    final requestId = newSchoolRequestId();
    final idempotencyKey = requestId;
    final payload = assessmentResultPayload(
      assessmentId: summary.id,
      studentId: studentId,
      score: score,
      mentionId: mentionId,
      designation: designation,
      resultId: resultId,
      requestId: requestId,
      expectedRevision: _revision,
      expectedGradingRevision: gradingPolicy.value?.revision ?? 0,
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
      if (isClosed) return;
      await _schoolClient().recordAssessmentResult(payload);
      if (isClosed) return;
      _revision++;
      await _outboxStore.removeByIdempotencyKey(idempotencyKey);
      if (isClosed) return;
      _patchRow(
        studentId,
        resultId: resultId,
        score: score,
        mentionId: mentionId,
        designation:
            designation ??
            (score != null || mentionId != null ? 'scored' : null),
        syncState: MarkSyncState.synced,
      );
      _evaluations.patchGradedCount(
        summary.id,
        students.value
            .where(
              (item) =>
                  item.score != null ||
                  item.mentionId != null ||
                  item.designation == 'absent' ||
                  item.designation == 'exempt',
            )
            .length,
      );
    } on Object catch (error) {
      if (isClosed) return;
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
      if (isClosed) return;
      _patchRow(
        studentId,
        resultId: resultId,
        score: score,
        mentionId: mentionId,
        designation:
            designation ??
            (score != null || mentionId != null ? 'scored' : null),
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
    if (isClosed) return;
    for (final row in students.value) {
      if (isClosed) return;
      if (row.score != null ||
          row.mentionId != null ||
          row.designation == 'absent' ||
          row.designation == 'exempt' ||
          row.marksLocked) {
        continue;
      }
      await saveScore(row.studentId, score);
    }
  }

  Future<void> clearUnlocked() async {
    if (isClosed) return;
    for (final row in students.value) {
      if (isClosed) return;
      if (row.marksLocked || (row.score == null && row.mentionId == null)) {
        continue;
      }
      await saveScore(row.studentId, null);
    }
  }

  void trackScoreInput(String studentId, String value) {
    final normalized = value.trim().replaceAll(',', '.');
    final score = double.tryParse(normalized);
    final saved = students.value
        .where((row) => row.studentId == studentId)
        .firstOrNull;
    final inputs = {...pendingScoreInputs.value};
    if (saved != null &&
        (normalized.isEmpty || score != null) &&
        score == saved.score) {
      inputs.remove(studentId);
    } else {
      inputs[studentId] = value;
    }
    pendingScoreInputs(inputs);
  }

  void _patchRow(
    String studentId, {
    String? resultId,
    double? score,
    String? designation,
    String? mentionId,
    MarkSyncState? syncState,
  }) {
    final entered = pendingScoreInputs.value[studentId];
    if (entered != null) {
      final normalized = entered.trim().replaceAll(',', '.');
      if ((normalized.isEmpty || double.tryParse(normalized) != null) &&
          double.tryParse(normalized) == score) {
        pendingScoreInputs({...pendingScoreInputs.value}..remove(studentId));
      }
    }
    students([
      for (final item in students.value)
        if (item.studentId == studentId)
          item.copyWith(
            resultId: resultId,
            score: score,
            mentionId: mentionId,
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

  Future<Map<String, dynamic>> _onlineCommand(
    String command,
    Map<String, dynamic> payload,
    Future<Map<String, dynamic>> Function(Map<String, dynamic>) send,
  ) async {
    final context = _outboxContext?.call()?.toJson();
    final key =
        '${schoolStoragePrefix(_schoolClient())}marks-online:${base64Url.encode(utf8.encode(jsonEncode([context, evaluationId, command, payload])))}';
    final prefs = await SharedPreferences.getInstance();
    final requestId = prefs.getString(key) ?? newSchoolRequestId();
    await prefs.setString(key, requestId);
    try {
      final result = await send({...payload, 'requestId': requestId});
      await prefs.remove(key);
      return result;
    } on Object catch (error) {
      if (!isRetryableTeacherWriteFailure(error)) await prefs.remove(key);
      rethrow;
    }
  }

  Future<bool> requestCorrection(
    List<Map<String, dynamic>> changes,
    String reason, {
    Map<String, dynamic>? correction,
  }) async {
    if (_saving ||
        (correction == null && !canRequestCorrection.value) ||
        reason.trim().isEmpty ||
        changes.isEmpty) {
      return false;
    }
    for (final change in changes) {
      final proposed = change['proposed'] as Map;
      final score = proposed['score'] as num?;
      if (proposed['designation'] == 'scored' &&
          (mentionFirst
              ? !mentions.any((range) => range['id'] == proposed['mentionId'])
              : (score == null ||
                    !score.isFinite ||
                    score < 0 ||
                    score > (evaluation.value?.maxScore ?? 0)))) {
        saveMessage(systemL10n().marksInvalidNumber);
        return false;
      }
    }
    _saving = true;
    try {
      if (correction == null) {
        await _onlineCommand('request', {
          'assessmentId': evaluationId,
          'expectedRevision': _revision,
          'expectedGradingRevision': gradingPolicy.value?.revision ?? 0,
          'reason': reason.trim(),
          'changes': changes,
        }, _schoolClient().requestAssessmentMarksCorrection);
      } else {
        await _onlineCommand(
          'revise',
          {
            'correctionId': correction['id'],
            'assessmentId': evaluationId,
            'expectedRevision': _revision,
            'expectedGradingRevision': gradingPolicy.value?.revision ?? 0,
            'expectedVersion': correction['version'],
            'reason': reason.trim(),
            'changes': changes,
          },
          (body) => _schoolClient().runCommand(
            'revise-assessment-marks-correction',
            body,
          ),
        );
      }
      await load();
      saveMessage(systemL10n().marksCorrectionRequested);
      return true;
    } on Object catch (error) {
      if (error is api.ApiError &&
          (error.status == 409 || error.status == 412)) {
        await load();
      }
      saveMessage(systemL10n().couldNotSaveMark('$error'));
      return false;
    } finally {
      _saving = false;
    }
  }

  Future<void> withdrawCorrection(Map<String, dynamic> correction) async {
    if (_saving ||
        (correction['allowedActions'] as Map?)?['withdraw'] != true) {
      return;
    }
    _saving = true;
    try {
      await _onlineCommand('withdraw', {
        'correctionId': correction['id'],
        'expectedVersion': correction['version'],
      }, _schoolClient().withdrawAssessmentMarksCorrection);
      await load();
    } on Object catch (error) {
      saveMessage(systemL10n().couldNotSaveMark('$error'));
    } finally {
      _saving = false;
    }
  }

  Future<void> submitMarks() async {
    if (isClosed ||
        submitting.value ||
        pendingScoreInputs.value.isNotEmpty ||
        marksStatus.value != 'draft') {
      return;
    }
    submitting(true);
    try {
      await _draftWrites;
      if (isClosed) return;
      if (_saving) return;
      _saving = true;
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
      await _onlineCommand('submit', {
        'assessmentId': evaluationId,
        'expectedRevision': _revision,
      }, client.submitAssessmentMarks);
      await load();
      saveMessage(systemL10n().marksSubmitted);
    } on Object catch (error) {
      saveMessage(systemL10n().couldNotSubmit(error));
    } finally {
      _saving = false;
      if (!isClosed) submitting(false);
    }
  }
}
