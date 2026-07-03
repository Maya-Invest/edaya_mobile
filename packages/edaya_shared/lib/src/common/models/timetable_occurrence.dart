import '../utils/date_time_parse.dart';

/// A materialized timetable occurrence (lesson, activity, or assessment).
class TimetableOccurrence {
  const TimetableOccurrence({
    required this.id,
    required this.kind,
    required this.title,
    required this.subjectLabel,
    required this.startsAt,
    required this.endsAt,
    required this.classGroupId,
    this.classSubjectId,
    this.status,
    this.room,
    this.teacherName,
  });

  final String id;
  final String kind;
  final String title;
  final String subjectLabel;
  final DateTime startsAt;
  final DateTime endsAt;
  final String classGroupId;
  final String? classSubjectId;
  final String? status;
  final String? room;
  final String? teacherName;

  bool occursOn(DateTime day) => isSameCalendarDay(startsAt, day);

  String get attendanceAnchorField => switch (kind) {
    'activity' => 'activitySessionId',
    'assessment' => 'assessmentId',
    _ => 'lessonSessionId',
  };

  Map<String, dynamic> get attendanceAnchorPayload => {
    attendanceAnchorField: id,
  };
}
