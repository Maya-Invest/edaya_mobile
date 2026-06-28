import 'package:edaya_shared/edaya_shared.dart';

class CalendarSession {
  const CalendarSession({
    required this.id,
    required this.title,
    required this.kind,
    required this.startsAt,
    required this.endsAt,
    this.classSubjectId,
  });

  factory CalendarSession.fromJson(Map<String, dynamic> json) {
    final startsAt = parseApiDateTime(json['startsAt']);
    final endsAt = parseApiDateTime(json['endsAt']);
    if (startsAt == null || endsAt == null) {
      throw FormatException('Session ${json['id']} has invalid dates');
    }

    return CalendarSession(
      id: json['id'] as String,
      title: json['title'] as String,
      kind: json['kind'] as String? ?? 'course',
      startsAt: startsAt.toLocal(),
      endsAt: endsAt.toLocal(),
      classSubjectId: json['classSubjectId'] as String?,
    );
  }

  final String id;
  final String title;
  final String kind;
  final DateTime startsAt;
  final DateTime endsAt;
  final String? classSubjectId;

  /// Projects a recurring timetable slot onto [day] when weekdays match.
  CalendarSession? projectOntoDay(DateTime day) {
    if (startsAt.weekday != day.weekday) {
      return null;
    }

    return CalendarSession(
      id: id,
      title: title,
      kind: kind,
      startsAt: DateTime(
        day.year,
        day.month,
        day.day,
        startsAt.hour,
        startsAt.minute,
        startsAt.second,
        startsAt.millisecond,
        startsAt.microsecond,
      ),
      endsAt: DateTime(
        day.year,
        day.month,
        day.day,
        endsAt.hour,
        endsAt.minute,
        endsAt.second,
        endsAt.millisecond,
        endsAt.microsecond,
      ),
      classSubjectId: classSubjectId,
    );
  }
}
