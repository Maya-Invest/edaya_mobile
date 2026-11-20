import 'package:edaya_api_client/edaya_api_client.dart';

import '../api/evaluation_data.dart';
import 'teacher_outbox_models.dart';

/// A pre-upgrade request may already have committed even if its response was lost.
bool isLegacyLogbookWrite(TeacherOutboxEntry entry) {
  final body = entry.payload['body'];
  final proposal = body is Map ? body['proposal'] : null;
  return proposal is Map &&
          proposal['workflow'] == 'logbook' &&
          proposal['formatVersion'] != 2 ||
      entry.kind == TeacherOutboxKind.logbook && body == null;
}

Future<bool> legacyLogbookWasDelivered(
  SchoolClient client,
  TeacherOutboxEntry entry,
) async {
  final body = entry.payload['body'];
  if (body is! Map || body['proposal'] is! Map) return false;
  final command = const {
    'save-teacher-logbook': 'saveTeacherLogbook',
    'request-teacher-correction': 'requestTeacherCorrection',
    'revise-teacher-correction': 'reviseTeacherCorrection',
  }[entry.payload['command']];
  if (command == null) return false;
  final target = (body['proposal'] as Map)['targetId'];
  try {
    final state = await client.runQuery('get-teacher-workflow-state', {
      'proposal': {
        'workflow': 'logbook',
        'formatVersion': 2,
        'targetId': target,
        'sessionNote': null,
        'progress': [],
      },
      'legacyReceipt': {'command': command, 'body': body},
    });
    return state['delivered'] == true;
  } on ApiError catch (error) {
    if (error.body.toString().contains('COMMAND_REPLAY_CONFLICT')) return false;
    rethrow;
  }
}

/// Split writes have no command receipt. Reconcile exact row identity, original
/// percentage and notes. A missing or changed row stays available for review.
Future<Map<String, dynamic>> remainingLegacyLogbookPayload(
  SchoolClient client,
  TeacherOutboxEntry entry,
) async {
  if (entry.payload['body'] is Map) return entry.payload;
  final note = entry.payload['notePayload'] as Map?;
  final ops = (entry.payload['progressOps'] as List? ?? [])
      .whereType<Map>()
      .toList();
  final lesson =
      note?['id'] ?? (ops.firstOrNull?['payload'] as Map?)?['lessonSessionId'];
  if (lesson is! String) return entry.payload;
  final official = await client.lessonSessions.get(lesson);
  final rows = await client.classSubjectProgress.listAll({
    'lessonSessionId': lesson,
  });
  final remaining = <Map>[];
  for (final op in ops) {
    final p = op['payload'] as Map?;
    final matches =
        p != null &&
        p['id'] is String &&
        p['lessonSessionId'] == lesson &&
        rows.any(
          (row) =>
              row['id'] == p['id'] &&
              row['classSubjectMatterId'] == p['classSubjectMatterId'] &&
              row['legacyPercentage'] != null &&
              row['legacyPercentage'] == p['completedPercentage'] &&
              row['completed'] ==
                  (p['completedPercentage'] == 0
                      ? null
                      : p['completedPercentage'] == 100) &&
              row['notes'] == p['notes'],
        );
    if (!matches) remaining.add(op);
  }
  return {
    if (note != null && official['sessionNote'] != note['sessionNote'])
      'notePayload': note,
    if (remaining.isNotEmpty) 'progressOps': remaining,
  };
}

/// Replays a single outbox entry against the live API.
Future<void> syncTeacherOutboxEntry(
  SchoolClient client,
  TeacherOutboxEntry entry,
) async {
  if (isLegacyLogbookWrite(entry)) {
    if (await legacyLogbookWasDelivered(client, entry) ||
        (entry.payload['body'] == null &&
            (await remainingLegacyLogbookPayload(client, entry)).isEmpty))
      return;
    throw StateError('Open this lesson to review the recovered logbook draft.');
  }
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
      throw StateError('A logbook must carry a versioned command');
    case TeacherOutboxKind.mark:
      if (entry.payload['results'] is List) {
        await client.runListCommand('record-assessment-results', entry.payload);
      } else {
        await client.recordAssessmentResult(entry.payload);
      }
    case TeacherOutboxKind.comment:
      await _syncCommentEntry(client, entry.payload);
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

/// Rows covered by one legacy single-mark or current batch outbox entry.
Iterable<Map<String, dynamic>> teacherMarkOutboxRows(
  TeacherOutboxEntry entry,
) => entry.payload['results'] is List
    ? (entry.payload['results'] as List).map(
        (row) => Map<String, dynamic>.from(row as Map),
      )
    : [entry.payload];
