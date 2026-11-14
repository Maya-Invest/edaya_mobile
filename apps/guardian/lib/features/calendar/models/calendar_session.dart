import 'package:edaya_shared/edaya_shared.dart';

class CalendarSession {
  const CalendarSession({
    required this.id,
    required this.title,
    required this.kind,
    required this.startsAt,
    required this.endsAt,
    this.classSubjectId,
    this.subjectLabel,
    this.status,
  });

  factory CalendarSession.fromOccurrence(TimetableOccurrence occurrence) {
    return CalendarSession(
      id: occurrence.id,
      title: occurrence.title,
      kind: occurrence.kind,
      startsAt: occurrence.startsAt,
      endsAt: occurrence.endsAt,
      classSubjectId: occurrence.classSubjectId,
      subjectLabel: occurrence.subjectLabel,
      status: occurrence.status,
    );
  }

  final String id;
  final String title;
  final String kind;
  final DateTime startsAt;
  final DateTime endsAt;
  final String? classSubjectId;
  final String? subjectLabel;
  final String? status;

  bool occursOn(DateTime day) => isSameCalendarDay(startsAt, day);
}
