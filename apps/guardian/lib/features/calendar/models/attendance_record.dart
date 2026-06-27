import '../../../common/utils/date_time_parse.dart';

class AttendanceRecord {
  const AttendanceRecord({
    required this.id,
    required this.sessionId,
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

    return AttendanceRecord(
      id: json['id'] as String,
      sessionId: json['sessionId'] as String,
      date: date.toLocal(),
      status: json['status'] as String? ?? 'absent',
      justificationStatus:
          json['justificationStatus'] as String? ?? 'none',
      reason: json['reason'] as String?,
    );
  }

  final String id;
  final String sessionId;
  final DateTime date;
  final String status;
  final String justificationStatus;
  final String? reason;
}
