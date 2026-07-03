import 'package:edaya_shared/edaya_shared.dart';

class AttendanceRecord {
  const AttendanceRecord({
    required this.id,
    required this.occurrenceId,
    required this.occurrenceKind,
    required this.date,
    required this.status,
    required this.justificationStatus,
    this.reason,
  });

  factory AttendanceRecord.fromJson(Map<String, dynamic> json) {
    final date = parseApiDateTime(json['date']);
    if (date == null) {
      throw FormatException('Attendance ${json['id']} has invalid date');
    }

    final lessonSessionId = json['lessonSessionId'] as String?;
    final activitySessionId = json['activitySessionId'] as String?;
    final assessmentId = json['assessmentId'] as String?;
    final legacySessionId = json['sessionId'] as String?;

    final occurrenceId =
        lessonSessionId ??
        activitySessionId ??
        assessmentId ??
        legacySessionId ??
        '';
    final occurrenceKind = activitySessionId != null
        ? 'activity'
        : assessmentId != null
        ? 'assessment'
        : 'lesson';

    return AttendanceRecord(
      id: json['id'] as String,
      occurrenceId: occurrenceId,
      occurrenceKind: occurrenceKind,
      date: date.toLocal(),
      status: json['status'] as String? ?? 'absent',
      justificationStatus: json['justificationStatus'] as String? ?? 'none',
      reason: json['reason'] as String?,
    );
  }

  final String id;
  final String occurrenceId;
  final String occurrenceKind;
  final DateTime date;
  final String status;
  final String justificationStatus;
  final String? reason;

  @Deprecated('Use occurrenceId')
  String get sessionId => occurrenceId;
}
