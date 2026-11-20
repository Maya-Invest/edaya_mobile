import 'package:edaya_api_client/edaya_api_client.dart';

import '../common/utils/entity_query.dart';

Future<List<Map<String, dynamic>>> listAttendanceForOccurrence(
  EntityResource attendance, {
  required String kind,
  required String occurrenceId,
}) async {
  return attendance.list(
    attendanceForOccurrence(kind: kind, occurrenceId: occurrenceId),
  );
}

Map<String, dynamic> attendanceRecordPayload({
  required String kind,
  required String occurrenceId,
  required String studentId,
  required String attendanceId,
  required String status,
  required String createdAt,
  String? reason,
  String? notes,
}) {
  return {
    'id': attendanceId,
    'studentId': studentId,
    'status': status,
    'createdAt': createdAt,
    ...attendanceAnchorPayload(kind: kind, occurrenceId: occurrenceId),
    if (reason != null && reason.isNotEmpty) 'reason': reason,
    if (notes != null && notes.isNotEmpty) 'notes': notes,
  };
}

Map<String, dynamic> attendanceAnchorPayload({
  required String kind,
  required String occurrenceId,
}) {
  return switch (kind) {
    'activity' => {'activitySessionId': occurrenceId},
    'assessment' => {'assessmentId': occurrenceId},
    _ => {'lessonSessionId': occurrenceId},
  };
}
