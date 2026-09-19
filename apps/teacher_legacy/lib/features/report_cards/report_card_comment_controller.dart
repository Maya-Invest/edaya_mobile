import 'dart:async';

import 'package:edaya_api_client/edaya_api_client.dart' as api;
import 'package:levit_flutter/levit_flutter.dart';

import 'package:edaya_shared/edaya_shared.dart';
import '../context/teacher_context_controller.dart';
import 'models/report_card_roster_models.dart';
import 'report_card_comment_draft_storage.dart';
import 'report_card_comment_logic.dart';

class ReportCardCommentController extends LevitController
    with LevitReactiveTasksMixin {
  ReportCardCommentController({
    required this.args,
    required this.student,
    required TeacherContextController teacherContext,
    required AppSessionController session,
    required SchoolClientFactory schoolClient,
    TeacherOutboxStore? outboxStore,
  }) : _teacherContext = teacherContext,
       _session = session,
       _schoolClient = schoolClient,
       _outboxStore = outboxStore ?? openTeacherOutboxStore();

  final ReportCardRosterArgs args;
  final ReportCardStudentRow student;
  final TeacherContextController _teacherContext;
  final AppSessionController _session;
  final SchoolClientFactory _schoolClient;
  final TeacherOutboxStore _outboxStore;

  final fields = LxVar<List<ReportCardCommentField>>(const []);
  final errorMessage = LxVar('');
  final saveMessage = LxVar('');
  final isReadOnly = LxVar(false);

  Map<String, dynamic>? _resultRow;

  @override
  void onInit() {
    super.onInit();
    autoDispose(fields);
    autoDispose(errorMessage);
    autoDispose(saveMessage);
    autoDispose(isReadOnly);
    unawaited(load());
  }

  DataStatus get dataStatus {
    if (isBusy.value && fields.value.isEmpty && errorMessage.value.isEmpty) {
      return DataStatus.loading;
    }
    if (errorMessage.value.isNotEmpty && fields.value.isEmpty) {
      return DataStatus.error;
    }
    if (fields.value.isEmpty) {
      return DataStatus.empty;
    }
    return DataStatus.ready;
  }

  String get emptyMessage => systemL10n().reportCardCommentNoEditableFields;

  Future<void> load() async {
    errorMessage('');
    saveMessage('');
    await runTask(() async {
      final reportCardId = student.reportCardId;
      if (reportCardId == null) {
        errorMessage(systemL10n().reportCardNotFound);
        fields(const []);
        return;
      }

      try {
        final client = _schoolClient();
        final result = await client.results.get(reportCardId);
        _resultRow = result;

        if (!reportCardCommentsEditable(result)) {
          isReadOnly(true);
        }

        final grants = _session.grants.value;
        final homeroomClassGroupIds = grants?.teacherScope?.homeroomClassGroupIds
                .toSet() ??
            const {};
        final taughtClassSubjectIds = _teacherContext.taughtClassSubjectIds.value;

        final editableFields = extractWritableReportCardCommentFields(
          result: result,
          classGroupId: args.classGroupId,
          homeroomClassGroupIds: homeroomClassGroupIds,
          taughtClassSubjectIds: taughtClassSubjectIds,
        );

        if (editableFields.isEmpty && !isReadOnly.value) {
          errorMessage(systemL10n().reportCardCommentNoEditableFields);
        }

        fields(editableFields);
        await _restoreDraft(editableFields);
      } on Object catch (error) {
        errorMessage(systemL10n().couldNotLoadReportCardComments('$error'));
        fields(const []);
      }
    });
  }

  Future<void> persistDraft(Map<String, String> commentsBySectionId) async {
    final reportCardId = student.reportCardId;
    if (reportCardId == null) {
      return;
    }
    await ReportCardCommentDraftStorage.save(
      resultId: reportCardId,
      studentId: student.studentId,
      draft: ReportCardCommentDraft(
        commentsBySectionId: commentsBySectionId,
        updatedAt: DateTime.now(),
      ),
    );
  }

  Future<void> _restoreDraft(List<ReportCardCommentField> editableFields) async {
    final reportCardId = student.reportCardId;
    if (reportCardId == null) {
      return;
    }
    final draft = await ReportCardCommentDraftStorage.load(
      resultId: reportCardId,
      studentId: student.studentId,
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
    errorMessage('');

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
        final updated = applyReportCardCommentUpdates(
          result,
          commentsBySectionId: commentsBySectionId,
        );
        await client.results.save(updated);
      }

      final reportCardId = student.reportCardId;
      if (reportCardId != null) {
        await ReportCardCommentDraftStorage.clear(
          resultId: reportCardId,
          studentId: student.studentId,
        );
      }
      return true;
    } on api.ApiError catch (error) {
      return _enqueueCommentFailure(
        result: result,
        commentsBySectionId: commentsBySectionId,
        error: _formatApiError(error),
      );
    } on Object catch (error) {
      return _enqueueCommentFailure(
        result: result,
        commentsBySectionId: commentsBySectionId,
        error: '$error',
      );
    }
  }

  Future<bool> _enqueueCommentFailure({
    required Map<String, dynamic> result,
    required Map<String, String> commentsBySectionId,
    required String error,
  }) async {
    final homeroomOnly =
        commentsBySectionId.keys.length == 1 &&
        commentsBySectionId.containsKey('__homeroom__');
    final resultId = result['id'] as String? ?? student.reportCardId ?? '';
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
        lastError: error,
      ),
    );
    saveMessage(systemL10n().attendanceSavedLocally);
    return true;
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
    }
    return error.message;
  }
}
