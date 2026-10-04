import 'dart:async';

import 'package:edaya_api_client/edaya_api_client.dart';
import 'package:edaya_shared/edaya_shared.dart';
import 'package:levit_flutter/levit_flutter.dart';

import '../../live/entity_queries.dart';
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
  });

  final String classGroupId;
  final String classLabel;
  final String periodId;
  final String periodLabel;
  final int generatedCount;
  final int commentFilledCount;

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
    this.rank,
    this.hasComment = false,
  });

  final String studentId;
  final String studentName;
  final String studentInitials;
  final String? photoUrl;
  final String? reportCardId;
  final String? status;
  final double? overallAverage;
  final int? rank;
  final bool hasComment;

  bool get hasReportCard => reportCardId != null;
}

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

  Future<void> loadClassSummaries() async {
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
          final results = await client.results.list({
            'classGroupId': assigned.id,
            'periodId': periodId,
          });
          final generated = results.where(reportCardIsGenerated);
          final withComments = generated.where(reportCardHasComment);
          summaries.add(
            ReportCardClassSummary(
              classGroupId: assigned.id,
              classLabel: assigned.label,
              periodId: periodId,
              periodLabel: periodLabel,
              generatedCount: generated.length,
              commentFilledCount: withComments.length,
            ),
          );
        }
        classSummaries(summaries);
      } on Object catch (error) {
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
    required SchoolClientFactory schoolClient,
  }) : _academicYear = academicYear,
       _schoolClient = schoolClient;

  final String classGroupId;
  final String periodId;
  final AcademicYearController _academicYear;
  final SchoolClientFactory _schoolClient;

  final students = LxVar<List<ReportCardStudentRow>>(const []);
  final errorMessage = LxVar('');

  @override
  void onInit() {
    super.onInit();
    autoDispose(students);
    autoDispose(errorMessage);
    unawaited(load());
  }

  Future<void> load() async {
    errorMessage('');
    await runTask(() async {
      try {
        final client = _schoolClient();
        final enrollmentRows = await client.enrollments.list(
          activeEnrollmentsForClass(
            classGroupId,
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
        final resultRows = await client.results.list({
          'classGroupId': classGroupId,
          'periodId': periodId,
        });
        final resultByStudent = <String, Map<String, dynamic>>{};
        for (final row in resultRows) {
          final studentId = row['studentId'] as String?;
          if (studentId == null || !reportCardIsGenerated(row)) {
            continue;
          }
          resultByStudent[studentId] = row;
        }
        final roster = studentRows.map((row) {
          final studentId = row['id'] as String;
          final firstName = row['firstName'] as String? ?? '';
          final lastName = row['lastName'] as String? ?? '';
          final fullName = '$firstName $lastName'.trim();
          final displayName = fullName.isEmpty ? studentId : fullName;
          final result = resultByStudent[studentId];
          return ReportCardStudentRow(
            studentId: studentId,
            studentName: displayName,
            studentInitials: personInitials(displayName),
            photoUrl: row['photoUrl'] as String?,
            reportCardId: result?['id'] as String?,
            status: result?['status'] as String?,
            overallAverage: (result?['overallAverage'] as num?)?.toDouble(),
            rank: (result?['rank'] as num?)?.toInt(),
            hasComment: result == null ? false : reportCardHasComment(result),
          );
        }).toList()..sort((a, b) => a.studentName.compareTo(b.studentName));
        students(roster);
      } on Object catch (error) {
        errorMessage(systemL10n().couldNotLoadReportCardRoster('$error'));
        students(const []);
      }
    });
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
  }) : _teacherContext = teacherContext,
       _session = session,
       _schoolClient = schoolClient,
       _outboxStore = outboxStore ?? openTeacherOutboxStore();

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

  Future<void> load() async {
    errorMessage('');
    await runTask(() async {
      try {
        final client = _schoolClient();
        final results = await client.results.list({
          'classGroupId': classGroupId,
          'periodId': periodId,
          'studentId': studentId,
        });
        final result = results.where(reportCardIsGenerated).firstOrNull;
        if (result == null) {
          errorMessage(systemL10n().reportCardNotFound);
          fields(const []);
          return;
        }
        _resultRow = result;
        studentName(result['studentName'] as String? ?? studentId);
        correctionRequired(result['status'] == 'published');
        isReadOnly(false);
        final homeroomClassGroupIds = _teacherContext.assignments.value
            .where((assignment) => assignment.isHomeroom)
            .map((assignment) => assignment.classGroupId)
            .toSet();
        final editableFields = extractWritableReportCardCommentFields(
          result: result,
          classGroupId: classGroupId,
          homeroomClassGroupIds: homeroomClassGroupIds,
          taughtClassSubjectIds: _teacherContext.taughtClassSubjectIds.value,
        );
        fields(editableFields);
        if (correctionRequired.value) {
          _eligibility = await client.runQuery('get-teacher-workflow-state', {
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
          });
        }
        await _restoreDraft(editableFields, result['id'] as String);
      } on Object catch (error) {
        errorMessage(systemL10n().couldNotLoadReportCardComments('$error'));
        fields(const []);
      }
    });
  }

  Future<void> persistDraft(Map<String, String> commentsBySectionId) async {
    final resultId = _resultRow?['id'] as String?;
    if (resultId == null) {
      return;
    }
    await ReportCardCommentDraftStorage.save(
      resultId: resultId,
      studentId: studentId,
      draft: ReportCardCommentDraft(
        commentsBySectionId: commentsBySectionId,
        updatedAt: DateTime.now(),
      ),
    );
  }

  Future<void> _restoreDraft(
    List<ReportCardCommentField> editableFields,
    String resultId,
  ) async {
    final draft = await ReportCardCommentDraftStorage.load(
      resultId: resultId,
      studentId: studentId,
    );
    if (draft == null) {
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
      } on Object catch (error) {
        saveMessage(systemL10n().couldNotSaveMark('$error'));
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
          resultId: resultId,
          studentId: studentId,
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
            : 'Conflit de version : rechargez le bulletin et réconciliez votre commentaire.',
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
