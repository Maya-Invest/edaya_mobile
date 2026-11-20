import 'dart:async';

import 'package:edaya_api_client/edaya_api_client.dart';
import 'package:edaya_shared/edaya_shared.dart';
import 'package:levit_flutter/levit_flutter.dart';

import '../../live/runtime.dart';
import '../context/academic_year_controller.dart';
import '../context/teacher_context_controller.dart';
import '../evaluations/live_evaluations_controller.dart';
import 'report_card_comment_draft_storage.dart';
import 'report_card_comment_logic.dart';
import 'report_card_logic.dart';

class ReportCardClassSummary {
  const ReportCardClassSummary({
    required this.classGroupId,
    required this.classLabel,
    required this.periodId,
    required this.periodLabel,
    required this.generatedCount,
    required this.commentFilledCount,
    this.remainingFields = 0,
  });

  final String classGroupId;
  final String classLabel;
  final String periodId;
  final String periodLabel;
  final int generatedCount;
  final int commentFilledCount;
  final int remainingFields;

  int get pendingComments =>
      (generatedCount - commentFilledCount).clamp(0, generatedCount);
}

class ReportCardStudentRow {
  const ReportCardStudentRow({
    required this.studentId,
    required this.studentName,
    required this.studentInitials,
    this.photoUrl,
    this.reportCardId,
    this.status,
    this.overallAverage,
    this.grading,
    this.aggregateLabel,
    this.rank,
    this.classSize,
    this.hasComment = false,
  });

  final String studentId;
  final String studentName;
  final String studentInitials;
  final String? photoUrl;
  final String? reportCardId;
  final String? status;
  final double? overallAverage;
  final Map<String, dynamic>? grading;
  final String? aggregateLabel;
  String get averageLabel => formatCalculatedGrade(overallAverage, grading);
  final int? rank, classSize;
  final bool hasComment;

  bool get hasReportCard => reportCardId != null;
}

List<ReportCardCommentField> _responsibilities(
  TeacherContextController context,
  Map<String, dynamic> row,
  String classId,
) => extractWritableReportCardCommentFields(
  result: row,
  classGroupId: classId,
  homeroomClassGroupIds: context.assignments.value
      .where((a) => a.isHomeroom)
      .map((a) => a.classGroupId)
      .toSet(),
  taughtClassSubjectIds: context.taughtClassSubjectIds.value,
);

class LiveReportCardsController extends LevitController
    with LevitReactiveTasksMixin {
  LiveReportCardsController({
    required TeacherContextController teacherContext,
    required AcademicYearController academicYear,
    required LiveEvaluationsController evaluations,
    required SchoolClientFactory schoolClient,
  }) : _teacherContext = teacherContext,
       _academicYear = academicYear,
       _evaluations = evaluations,
       _schoolClient = schoolClient;

  final TeacherContextController _teacherContext;
  final AcademicYearController _academicYear;
  final LiveEvaluationsController _evaluations;
  final SchoolClientFactory _schoolClient;

  final classSummaries = LxVar<List<ReportCardClassSummary>>(const []);
  final errorMessage = LxVar('');

  @override
  void onInit() {
    super.onInit();
    autoDispose(classSummaries);
    autoDispose(errorMessage);
    for (final subscription in [
      _teacherContext.assignedClasses.stream,
      _evaluations.selectedPeriodId.stream,
      _academicYear.selectedYearId.stream,
    ]) {
      autoDispose(subscription.listen((_) => unawaited(loadClassSummaries())));
    }
    unawaited(loadClassSummaries());
  }

  List<ReportCardClassSummary> get pendingCommentClasses =>
      classSummaries.value.where((item) => item.pendingComments > 0).toList();

  int _summaryGeneration = 0;
  Future<void> loadClassSummaries() async {
    final generation = ++_summaryGeneration;
    bool stale() => isClosed || generation != _summaryGeneration;
    final periodId = _evaluations.selectedPeriodId.value;
    final periodLabel = _evaluations.selectedPeriodLabel ?? periodId ?? '';
    final classes = _teacherContext.assignedClasses.value;
    if (periodId == null || classes.isEmpty) {
      classSummaries(const []);
      return;
    }
    errorMessage('');
    await runTask(() async {
      try {
        final client = _schoolClient();
        final summaries = <ReportCardClassSummary>[];
        for (final assigned in classes) {
          final response = await client.getClassReportRoster({
            'classGroupId': assigned.id,
            'periodId': periodId,
            'view': 'summary',
          });
          if (stale()) return;
          final totals = response['totals'] as Map;
          summaries.add(
            ReportCardClassSummary(
              classGroupId: assigned.id,
              classLabel: assigned.label,
              periodId: periodId,
              periodLabel: periodLabel,
              generatedCount: totals['generatedCount'] as int,
              commentFilledCount: totals['commentFilledCount'] as int,
              remainingFields: totals['remainingFields'] as int,
            ),
          );
        }
        if (!stale()) classSummaries(summaries);
      } on Object catch (error) {
        if (stale()) return;
        errorMessage(systemL10n().couldNotLoadReportCards('$error'));
        classSummaries(const []);
      }
    });
  }
}

class LiveReportCardRosterController extends LevitController
    with LevitReactiveTasksMixin {
  LiveReportCardRosterController({
    required this.classGroupId,
    required this.periodId,
    required AcademicYearController academicYear,
    required this.teacherContext,
    required SchoolClientFactory schoolClient,
  }) : _academicYear = academicYear,
       _schoolClient = schoolClient;

  final String classGroupId;
  final String periodId;
  final TeacherContextController teacherContext;
  final AcademicYearController _academicYear;
  final SchoolClientFactory _schoolClient;

  final students = LxVar<List<ReportCardStudentRow>>(const []);
  final errorMessage = LxVar('');

  final nextCursor = LxVar<String?>(null);
  final loading = LxVar(false);
  Completer<void>? _abort;

  @override
  void onInit() {
    super.onInit();
    autoDispose(students);
    autoDispose(errorMessage);
    autoDispose(loading);
    autoDispose(nextCursor);
    for (final stream in [
      _academicYear.selectedYearId.stream,
      teacherContext.assignments.stream,
    ]) {
      autoDispose(
        stream.listen((_) {
          students(const []);
          nextCursor(null);
          unawaited(load());
        }),
      );
    }
    unawaited(load());
  }

  @override
  void onClose() {
    _abort?.complete();
    _abort = null;
    super.onClose();
  }

  Future<void> load({bool more = false}) async {
    if (isClosed || (more && (loading.value || nextCursor.value == null)))
      return;
    _abort?.complete();
    final abort = _abort = Completer<void>();
    bool current() => identical(_abort, abort) && !isClosed;
    loading(true);
    errorMessage('');
    try {
      final client = _schoolClient();
      final previousCount = students.value.length;
      final rows = <String, ReportCardStudentRow>{
        if (more)
          for (final row in students.value) row.studentId: row,
      };
      var cursor = more ? nextCursor.value : null;
      do {
        final response = await client.getClassReportRoster({
          'classGroupId': classGroupId,
          'periodId': periodId,
          'cursor': ?cursor,
        }, abortTrigger: abort.future);
        if (!current()) return;
        for (final pupil in (response['items'] as List).cast<Map>()) {
          final id = pupil['studentId'] as String;
          final name = pupil['studentName'] as String;
          final report = pupil['report'] as Map?;
          rows[id] = ReportCardStudentRow(
            studentId: id,
            studentName: name,
            studentInitials: personInitials(name),
            photoUrl: pupil['photoUrl'] as String?,
            reportCardId: report?['id'] as String?,
            status: report?['status'] as String?,
            overallAverage: (report?['overallAverage'] as num?)?.toDouble(),
            grading: (report?['grading'] as Map?)?.cast<String, dynamic>(),
            aggregateLabel: report?['aggregateLabel'] as String?,
            classSize: report?['classSize'] as int?,
            rank: report?['rank'] as int?,
            hasComment: report?['hasComment'] == true,
          );
        }
        cursor = response['nextCursor'] as String?;
      } while (!more && cursor != null && rows.length < previousCount);
      students(rows.values.toList());
      nextCursor(cursor);
    } on Object catch (error) {
      if (!current()) return;
      if (error is ApiError && [400, 401, 403, 404].contains(error.status)) {
        students(const []);
        nextCursor(null);
      }
      errorMessage(systemL10n().couldNotLoadReportCardRoster('$error'));
    } finally {
      if (current()) {
        _abort = null;
        loading(false);
      }
    }
  }
}

class LiveReportCardCommentController extends LevitController
    with LevitReactiveTasksMixin {
  LiveReportCardCommentController({
    required this.classGroupId,
    required this.periodId,
    required this.studentId,
    required TeacherContextController teacherContext,
    required AppSessionController session,
    required SchoolClientFactory schoolClient,
    TeacherOutboxStore? outboxStore,
    this.subjectId,
    this.homeroomOnly = false,
  }) : _teacherContext = teacherContext,
       _session = session,
       _schoolClient = schoolClient,
       _outboxStore = outboxStore ?? openTeacherOutboxStore();

  final String? subjectId;
  final bool homeroomOnly;
  Map<String, dynamic>? get report => _resultRow;
  final String classGroupId;
  final String periodId;
  final String studentId;
  final TeacherContextController _teacherContext;
  final AppSessionController _session;
  final SchoolClientFactory _schoolClient;
  final TeacherOutboxStore _outboxStore;

  final studentName = LxVar('');
  final fields = LxVar<List<ReportCardCommentField>>(const []);
  final errorMessage = LxVar('');
  final saveMessage = LxVar('');
  final isReadOnly = LxVar(false);
  final correctionRequired = LxVar(false);
  Map<String, dynamic>? _resultRow;
  Map<String, dynamic>? _eligibility;

  @override
  void onInit() {
    super.onInit();
    autoDispose(studentName);
    autoDispose(fields);
    autoDispose(errorMessage);
    autoDispose(saveMessage);
    autoDispose(isReadOnly);
    autoDispose(correctionRequired);
    unawaited(load());
  }

  int _readGeneration = 0;

  Future<void> load() async {
    if (isClosed) return;
    final generation = ++_readGeneration;
    bool current() => !isClosed && generation == _readGeneration;
    errorMessage('');
    await runTask(() async {
      try {
        final client = _schoolClient();
        final results = await client.results.list({
          'classGroupId': classGroupId,
          'periodId': periodId,
          'studentId': studentId,
        });
        if (!current()) return;
        final result = results.where(reportCardIsGenerated).firstOrNull;
        if (result == null) {
          errorMessage(systemL10n().reportCardNotFound);
          fields(const []);
          return;
        }
        final homeroomClassGroupIds = _teacherContext.assignments.value
            .where((assignment) => assignment.isHomeroom)
            .map((assignment) => assignment.classGroupId)
            .toSet();
        final editableFields =
            extractWritableReportCardCommentFields(
                  result: result,
                  classGroupId: classGroupId,
                  homeroomClassGroupIds: homeroomClassGroupIds,
                  taughtClassSubjectIds: homeroomOnly
                      ? {}
                      : subjectId == null
                      ? _teacherContext.taughtClassSubjectIds.value
                      : {subjectId!},
                )
                .where(
                  (f) => homeroomOnly
                      ? f.isHomeroom
                      : subjectId == null || f.classSubjectId == subjectId,
                )
                .toList();
        final published = result['status'] == 'published';
        final (pupil, eligibility) = await (
          client.students.get(studentId),
          published
              ? client.runQuery('get-teacher-workflow-state', {
                  'proposal': {
                    'workflow': 'report_comments',
                    'targetId': result['id'],
                    'sections': [
                      for (final field in editableFields)
                        if (!field.isHomeroom)
                          {
                            'sectionId': field.sectionId,
                            'comment': field.initialComment,
                          },
                    ],
                    if (editableFields.any((f) => f.isHomeroom))
                      'teacherComment': result['teacherComment'],
                  },
                })
              : Future<Map<String, dynamic>?>.value(null),
        ).wait;
        if (!current()) return;
        _resultRow = result;
        _eligibility = eligibility;
        studentName(
          '${pupil['firstName'] ?? ''} ${pupil['lastName'] ?? ''}'.trim(),
        );
        correctionRequired(published);
        isReadOnly(false);
        final official = publishedFields;
        final proposals = activeProposals;
        final initial = [
          for (final field in editableFields)
            ReportCardCommentField(
              sectionId: field.sectionId,
              label: field.label,
              kind: field.kind,
              classSubjectId: field.classSubjectId,
              initialComment:
                  proposals[field.sectionId]?.text ??
                  official[field.sectionId] ??
                  field.initialComment,
            ),
        ];
        isReadOnly(
          proposals.values.any(
            (p) => p.status.startsWith(systemL10n().approved),
          ),
        );
        fields(initial);
        if (!isReadOnly.value) {
          await _restoreDraft(initial, result['id'] as String, current);
        }
      } on Object catch (error) {
        if (!current()) return;
        _resultRow = null;
        _eligibility = null;
        errorMessage(systemL10n().couldNotLoadReportCardComments('$error'));
        fields(const []);
      }
    });
  }

  String get _draftOwner =>
      '${_session.grants.value?.schoolId}/${_session.grants.value?.actorId}/$studentId/${homeroomOnly ? 'homeroom' : subjectId ?? 'all'}';
  Map<String, String> get publishedFields {
    final fields = {
      for (final f in _responsibilities(
        _teacherContext,
        _resultRow ?? {},
        classGroupId,
      ))
        f.sectionId: f.initialComment,
    };
    final official = _eligibility?['official'];
    if (official is Map) {
      if (fields.containsKey('__homeroom__') &&
          official.containsKey('teacherComment')) {
        fields['__homeroom__'] = official['teacherComment'] as String? ?? '';
      }
      for (final section
          in (official['sections'] as List? ?? []).whereType<Map>()) {
        final id = section['sectionId'] as String;
        if (fields.containsKey(id)) {
          fields[id] = section['comment'] as String? ?? '';
        }
      }
    }
    return fields;
  }

  Map<String, ({String text, String status})> get activeProposals {
    final result = <String, ({String text, String status})>{};
    for (final row
        in (_eligibility?['corrections'] as List? ?? const [])
            .whereType<Map>()) {
      if (row['status'] != 'pending' &&
          row['status'] != 'approved_pending_publication') {
        continue;
      }
      final proposal = row['proposal'] as Map?;
      if (proposal == null) continue;
      final status = row['status'] == 'pending'
          ? systemL10n().gradebookPending
          : systemL10n().approvedAwaitingPublication;
      final before = row['before'] as Map?;
      final beforeSections = {
        for (final section
            in (before?['sections'] as List? ?? []).whereType<Map>())
          section['sectionId']: section['comment'],
      };
      if (proposal.containsKey('teacherComment') &&
          proposal['teacherComment'] != before?['teacherComment']) {
        result['__homeroom__'] = (
          text: proposal['teacherComment'] as String? ?? '',
          status: status,
        );
      }
      for (final field
          in (proposal['sections'] as List? ?? []).whereType<Map>()) {
        final id = field['sectionId'] as String;
        if (field['comment'] != beforeSections[id]) {
          result[id] = (
            text: field['comment'] as String? ?? '',
            status: status,
          );
        }
      }
    }
    return result;
  }

  Future<void> persistDraft(Map<String, String> commentsBySectionId) async {
    final resultId = _resultRow?['id'] as String?;
    if (resultId == null) {
      return;
    }
    await ReportCardCommentDraftStorage.save(
      prefix: schoolStoragePrefix(_schoolClient()),
      resultId: resultId,
      studentId: _draftOwner,
      draft: ReportCardCommentDraft(
        commentsBySectionId: commentsBySectionId,
        baseVersion: (_resultRow?['version'] as num?)?.toInt() ?? 0,
        updatedAt: DateTime.now(),
      ),
    );
  }

  Future<void> _restoreDraft(
    List<ReportCardCommentField> editableFields,
    String resultId,
    bool Function() current,
  ) async {
    final draft = await ReportCardCommentDraftStorage.load(
      prefix: schoolStoragePrefix(_schoolClient()),
      resultId: resultId,
      studentId: _draftOwner,
    );
    if (!current() ||
        draft == null ||
        draft.baseVersion != (_resultRow?['version'] as num?)?.toInt()) {
      return;
    }
    fields(
      editableFields
          .map(
            (field) => ReportCardCommentField(
              sectionId: field.sectionId,
              label: field.label,
              kind: field.kind,
              classSubjectId: field.classSubjectId,
              initialComment:
                  draft.commentsBySectionId[field.sectionId] ??
                  field.initialComment,
            ),
          )
          .toList(),
    );
  }

  Future<bool> save(
    Map<String, String> commentsBySectionId, {
    String? correctionReason,
  }) async {
    final result = _resultRow;
    if (result == null || isReadOnly.value) {
      return false;
    }
    saveMessage('');
    _outboxStore.bindContext(teacherOutboxContextForSession(session: _session));
    final resultId = result['id'] as String? ?? '';
    if (correctionRequired.value) {
      if (correctionReason?.trim().isEmpty ?? true) return false;
      final proposal = <String, dynamic>{
        'workflow': 'report_comments',
        'targetId': resultId,
        'sections': [
          for (final entry in commentsBySectionId.entries)
            if (entry.key != '__homeroom__')
              {
                'sectionId': entry.key,
                'comment': entry.value.trim().isEmpty
                    ? null
                    : entry.value.trim(),
              },
        ],
        if (commentsBySectionId.containsKey('__homeroom__'))
          'teacherComment': commentsBySectionId['__homeroom__'],
      };
      try {
        final eligibility = _eligibility;
        if (eligibility == null) {
          throw StateError(systemL10n().reportCardNotFound);
        }
        final pending =
            (eligibility['corrections'] as List)
                    .where((row) => (row as Map)['status'] == 'pending')
                    .firstOrNull
                as Map?;
        final command = pending == null
            ? 'request-teacher-correction'
            : 'revise-teacher-correction';
        final body = <String, dynamic>{
          'requestId': newSchoolRequestId(),
          'expectedVersion': pending?['version'] ?? eligibility['version'],
          'proposal': proposal,
          'reason': correctionReason,
          if (pending != null) 'correctionId': pending['id'],
        };
        try {
          final request = await _schoolClient().runCommand(command, body);
          _eligibility = {
            ...eligibility,
            'corrections': [request],
          };
        } on Object catch (error) {
          if (!isRetryableTeacherWriteFailure(error)) rethrow;
          await _outboxStore.enqueue(
            buildTeacherOutboxEntry(
              id: body['requestId'] as String,
              kind: TeacherOutboxKind.correction,
              idempotencyKey: body['requestId'] as String,
              payload: {'command': command, 'body': body},
              lastError: '$error',
            ),
          );
          saveMessage(systemL10n().attendanceSavedLocally);
          return true;
        }
        saveMessage(systemL10n().workflowCorrectionPending);
        return true;
      } on Object {
        saveMessage(systemL10n().commentCorrectionFailed);
        return false;
      }
    }

    final requestId = newSchoolRequestId();
    final queued = (await _outboxStore.listPending())
        .where(
          (entry) => reportCommentCommandBodies(
            entry,
          ).any((body) => body['id'] == resultId),
        )
        .toList();
    if (queued.any((entry) => !teacherOutboxEntryIsReplayable(entry))) {
      saveMessage(systemL10n().mutationConflict);
      return false;
    }
    final version = reportCommentNextVersion(
      (result['version'] as num).toInt(),
      resultId,
      queued,
    );
    final homeroomComment = commentsBySectionId['__homeroom__'];
    final sectionComments = <Map<String, dynamic>>[
      for (final entry in commentsBySectionId.entries)
        if (entry.key != '__homeroom__')
          {
            'sectionId': entry.key,
            'comment': entry.value.trim().isEmpty ? null : entry.value.trim(),
          },
    ];
    final payload = <String, dynamic>{
      if (homeroomComment != null)
        'homeroom': {
          'id': resultId,
          'teacherComment': homeroomComment,
          'requestId': '$requestId:homeroom',
          'expectedVersion': version,
        },
      if (sectionComments.isNotEmpty)
        'sections': {
          'id': resultId,
          'sections': sectionComments,
          'requestId': '$requestId:sections',
          'expectedVersion': version + (homeroomComment == null ? 0 : 1),
        },
    };
    try {
      final client = _schoolClient();
      if (queued.isNotEmpty) throw Exception('offline pending report comments');
      await _sendReportComments(client, payload);
      await _outboxStore.removeByIdempotencyKey(requestId);
      if (resultId.isNotEmpty) {
        await ReportCardCommentDraftStorage.clear(
          prefix: schoolStoragePrefix(_schoolClient()),
          resultId: resultId,
          studentId: _draftOwner,
        );
      }
      _resultRow = {
        ...result,
        'version':
            version +
            (homeroomComment == null ? 0 : 1) +
            (sectionComments.isEmpty ? 0 : 1),
      };
      return true;
    } on Object catch (error) {
      final retryable = isRetryableTeacherWriteFailure(error);
      await _outboxStore.enqueue(
        buildTeacherOutboxEntry(
          id: requestId,
          kind: TeacherOutboxKind.comment,
          idempotencyKey: requestId,
          payload: payload,
          lastError: '$error',
          state: retryable
              ? TeacherOutboxState.pending
              : TeacherOutboxState.conflict,
        ),
      );
      saveMessage(
        retryable
            ? systemL10n().attendanceSavedLocally
            : systemL10n().theReportCardHasChangedReloadItAnd,
      );
      return retryable;
    }
  }
}

Future<void> _sendReportComments(
  SchoolClient client,
  Map<String, dynamic> payload,
) async {
  final homeroom = payload['homeroom'];
  if (homeroom is Map<String, dynamic>) {
    await client.runCommand('write-homeroom-report-comment', homeroom);
  }
  final sections = payload['sections'];
  if (sections is Map<String, dynamic>) {
    await client.runCommand('write-report-card-section-comments', sections);
  }
}
