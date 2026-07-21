import 'package:edaya_api_client/edaya_api_client.dart';

import '../api/evaluation_data.dart';
import 'teacher_outbox_models.dart';

/// Replays a single outbox entry against the live API.
Future<void> syncTeacherOutboxEntry(
  SchoolClient client,
  TeacherOutboxEntry entry,
) async {
  switch (entry.kind) {
    case TeacherOutboxKind.attendance:
      await client.recordAttendance(entry.payload);
    case TeacherOutboxKind.logbook:
      await _syncLogbookEntry(client, entry.payload);
    case TeacherOutboxKind.mark:
      await client.recordAssessmentResult(entry.payload);
    case TeacherOutboxKind.comment:
      await _syncCommentEntry(client, entry.payload);
  }
}

Future<void> _syncLogbookEntry(
  SchoolClient client,
  Map<String, dynamic> payload,
) async {
  final notePayload = payload['notePayload'];
  if (notePayload is Map<String, dynamic>) {
    await client.lessonSessions.save(notePayload);
  }

  final progressOps = payload['progressOps'];
  if (progressOps is! List) {
    return;
  }

  for (final rawOp in progressOps) {
    if (rawOp is! Map) {
      continue;
    }
    final op = rawOp.cast<String, dynamic>();
    final action = op['action'] as String?;
    final opPayload = op['payload'];
    if (opPayload is! Map<String, dynamic>) {
      continue;
    }

    switch (action) {
      case 'create':
        await client.recordLessonSessionProgress(opPayload);
      case 'update':
        await client.classSubjectProgress.save(opPayload);
    }
  }
}

Future<void> _syncCommentEntry(
  SchoolClient client,
  Map<String, dynamic> payload,
) async {
  final command = payload['command'] as String?;
  if (command == 'write-homeroom-report-comment') {
    final body = payload['body'];
    if (body is Map<String, dynamic>) {
      await client.runCommand('write-homeroom-report-comment', body);
    }
    return;
  }

  final resultPayload = payload['resultPayload'];
  if (resultPayload is Map<String, dynamic>) {
    await client.results.save(resultPayload);
  }
}

String teacherMarkIdempotencyKey({
  required String assessmentId,
  required String studentId,
}) {
  return 'mark:$assessmentId:$studentId';
}

String teacherCommentIdempotencyKey({
  required String resultId,
  required String sectionId,
}) {
  return 'comment:$resultId:$sectionId';
}

TeacherOutboxEntry buildTeacherOutboxEntry({
  required String id,
  required TeacherOutboxKind kind,
  required String idempotencyKey,
  required Map<String, dynamic> payload,
  String? lastError,
}) {
  final now = DateTime.now();
  return TeacherOutboxEntry(
    id: id,
    kind: kind,
    idempotencyKey: idempotencyKey,
    payload: payload,
    state: TeacherOutboxState.pending,
    attemptCount: lastError == null ? 0 : 1,
    lastError: lastError,
    createdAt: now,
    updatedAt: now,
  );
}

Map<String, dynamic> logbookOutboxPayload({
  required Map<String, dynamic> notePayload,
  required List<Map<String, dynamic>> progressOps,
}) {
  return {
    'notePayload': notePayload,
    'progressOps': progressOps,
  };
}

Map<String, dynamic> markOutboxPayload({
  required String assessmentId,
  required String studentId,
  required double score,
  String? resultId,
}) {
  return assessmentResultPayload(
    assessmentId: assessmentId,
    studentId: studentId,
    score: score,
    resultId: resultId,
  );
}
