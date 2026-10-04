import 'package:edaya_api_client/edaya_api_client.dart';

import '../api/evaluation_data.dart';
import 'teacher_outbox_models.dart';

/// Replays a single outbox entry against the live API.
Future<void> syncTeacherOutboxEntry(
  SchoolClient client,
  TeacherOutboxEntry entry,
) async {
  final command = entry.payload['command'];
  final body = entry.payload['body'];
  const workflowCommands = {
    'save-teacher-attendance-draft',
    'record-teacher-attendance-arrival',
    'save-teacher-logbook',
    'request-teacher-correction',
    'revise-teacher-correction',
    'withdraw-teacher-correction',
    'edit-teacher-incident',
    'append-incident-follow-up',
  };
  if (command is String && workflowCommands.contains(command) && body is Map) {
    await client.runCommand(command, Map<String, dynamic>.from(body));
    return;
  }
  switch (entry.kind) {
    case TeacherOutboxKind.correction:
      throw StateError('A correction must carry a supported named command');
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
        await _recordOrUpdateLessonProgress(client, opPayload);
      case 'update':
        await client.classSubjectProgress.save(opPayload);
    }
  }
}

Future<void> _recordOrUpdateLessonProgress(
  SchoolClient client,
  Map<String, dynamic> payload,
) async {
  try {
    await client.recordLessonSessionProgress(payload);
  } on Object catch (error) {
    if (!'$error'.contains('DUPLICATE_PROGRESS')) {
      rethrow;
    }
    final rows = await client.classSubjectProgress.list({
      'lessonSessionId': payload['lessonSessionId'],
      'classSubjectMatterId': payload['classSubjectMatterId'],
    });
    if (rows.isEmpty) {
      rethrow;
    }
    final existing = rows.first;
    final existingPercentage = existing['completedPercentage'];
    if (existingPercentage == payload['completedPercentage']) {
      return;
    }
    await client.classSubjectProgress.save({
      ...existing,
      'completedPercentage': payload['completedPercentage'],
      if (payload['notes'] != null) 'notes': payload['notes'],
      'recordedAt': payload['recordedAt'],
    });
  }
}

Future<void> _syncCommentEntry(
  SchoolClient client,
  Map<String, dynamic> payload,
) async {
  final homeroom = payload['homeroom'];
  if (homeroom is Map) {
    await client.runCommand(
      'write-homeroom-report-comment',
      homeroom.cast<String, dynamic>(),
    );
  }
  final sections = payload['sections'];
  if (sections is Map) {
    await client.runCommand(
      'write-report-card-section-comments',
      sections.cast<String, dynamic>(),
    );
  }

  final command = payload['command'] as String?;
  if (command == 'write-homeroom-report-comment') {
    final body = payload['body'];
    if (body is Map<String, dynamic>) {
      await client.runCommand('write-homeroom-report-comment', body);
    }
    return;
  }
  if (command == 'write-report-card-section-comments') {
    final body = payload['body'];
    if (body is Map<String, dynamic>) {
      await client.runCommand(
        'write-report-card-section-comments',
        body.cast<String, dynamic>(),
      );
    }
    return;
  }

  if (payload['resultPayload'] != null) {
    throw StateError(
      'Generic report-card result saves are not a supported offline command',
    );
  }
}

TeacherOutboxEntry buildTeacherOutboxEntry({
  required String id,
  required TeacherOutboxKind kind,
  required String idempotencyKey,
  required Map<String, dynamic> payload,
  String? lastError,
  TeacherOutboxState state = TeacherOutboxState.pending,
}) {
  final now = DateTime.now();
  return TeacherOutboxEntry(
    id: id,
    kind: kind,
    idempotencyKey: idempotencyKey,
    payload: payload,
    state: state,
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
  return {'notePayload': notePayload, 'progressOps': progressOps};
}

Map<String, dynamic> markOutboxPayload({
  required String assessmentId,
  required String studentId,
  required double? score,
  String? resultId,
  required String requestId,
  required int expectedRevision,
}) {
  return assessmentResultPayload(
    assessmentId: assessmentId,
    studentId: studentId,
    score: score,
    resultId: resultId,
    requestId: requestId,
    expectedRevision: expectedRevision,
  );
}

/// Commands belonging to one logical report-comment edit, in replay order.
List<Map<String, dynamic>> reportCommentCommandBodies(
  TeacherOutboxEntry entry,
) {
  if (entry.kind != TeacherOutboxKind.comment) return const [];
  return [
    for (final key in const ['homeroom', 'sections', 'body'])
      if (entry.payload[key] is Map)
        Map<String, dynamic>.from(entry.payload[key] as Map),
  ];
}

int reportCommentNextVersion(
  int serverVersion,
  String resultId,
  Iterable<TeacherOutboxEntry> entries,
) {
  var version = serverVersion;
  for (final entry in entries) {
    for (final body in reportCommentCommandBodies(entry)) {
      if (body['id'] != resultId) continue;
      final expected = body['expectedVersion'];
      if (expected is num && expected.toInt() >= version) {
        version = expected.toInt() + 1;
      }
    }
  }
  return version;
}
