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
  Map<String, dynamic>? _resultRow;

  @override
  void onInit() {
    super.onInit();
    autoDispose(studentName);
    autoDispose(fields);
    autoDispose(errorMessage);
    autoDispose(saveMessage);
    autoDispose(isReadOnly);
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
        if (!reportCardCommentsEditable(result)) {
          isReadOnly(true);
        }
        final grants = _session.grants.value;
        final homeroomClassGroupIds =
            grants?.teacherScope?.homeroomClassGroupIds.toSet() ??
            _teacherContext.assignedClassGroupIds.value;
        final editableFields = extractWritableReportCardCommentFields(
          result: result,
          classGroupId: classGroupId,
          homeroomClassGroupIds: homeroomClassGroupIds,
          taughtClassSubjectIds: _teacherContext.taughtClassSubjectIds.value,
        );
        fields(editableFields);
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

  Future<bool> save(Map<String, String> commentsBySectionId) async {
    final result = _resultRow;
    if (result == null || isReadOnly.value) {
      return false;
    }
    saveMessage('');
    try {
      final client = _schoolClient();
      final homeroomOnly =
          commentsBySectionId.keys.length == 1 &&
          commentsBySectionId.containsKey('__homeroom__');
      if (homeroomOnly) {
        await client.runCommand('write-homeroom-report-comment', {
          'id': result['id'],
          'teacherComment': commentsBySectionId['__homeroom__'] ?? '',
        });
      } else {
        await client.results.save(
          applyReportCardCommentUpdates(
            result,
            commentsBySectionId: commentsBySectionId,
          ),
        );
      }
      final resultId = result['id'] as String?;
      if (resultId != null) {
        await ReportCardCommentDraftStorage.clear(
          resultId: resultId,
          studentId: studentId,
        );
      }
      return true;
    } on Object catch (error) {
      final homeroomOnly =
          commentsBySectionId.keys.length == 1 &&
          commentsBySectionId.containsKey('__homeroom__');
      final resultId = result['id'] as String? ?? '';
      final sectionId = homeroomOnly
          ? '__homeroom__'
          : commentsBySectionId.keys.first;
      final payload = homeroomOnly
          ? {
              'command': 'write-homeroom-report-comment',
              'body': {
                'id': result['id'],
                'teacherComment': commentsBySectionId['__homeroom__'] ?? '',
              },
            }
          : {
              'resultPayload': applyReportCardCommentUpdates(
                result,
                commentsBySectionId: commentsBySectionId,
              ),
            };
      await _outboxStore.enqueue(
        buildTeacherOutboxEntry(
          id: 'comment-$resultId-$sectionId',
          kind: TeacherOutboxKind.comment,
          idempotencyKey: teacherCommentIdempotencyKey(
            resultId: resultId,
            sectionId: sectionId,
          ),
          payload: payload,
          lastError: '$error',
        ),
      );
      saveMessage(systemL10n().attendanceSavedLocally);
      return true;
    }
  }
}
