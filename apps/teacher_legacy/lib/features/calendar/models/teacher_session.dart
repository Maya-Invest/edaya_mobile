import 'package:edaya_shared/edaya_shared.dart';

class TeacherSession {
  const TeacherSession({
    required this.id,
    required this.title,
    required this.kind,
    required this.startsAt,
    required this.endsAt,
    required this.classGroupId,
    required this.classLabel,
    required this.subjectLabel,
    this.classSubjectId,
    this.status,
    this.teacherName,
  });

  factory TeacherSession.fromOccurrence(
    TimetableOccurrence occurrence, {
    required String classLabel,
  }) {
    return TeacherSession(
      id: occurrence.id,
      title: occurrence.title,
      kind: occurrence.kind,
      startsAt: occurrence.startsAt,
      endsAt: occurrence.endsAt,
      classGroupId: occurrence.classGroupId,
      classLabel: classLabel,
      subjectLabel: occurrence.subjectLabel,
      classSubjectId: occurrence.classSubjectId,
      status: occurrence.status,
      teacherName: occurrence.teacherName,
    );
  }

  final String id;
  final String title;
  final String kind;
  final DateTime startsAt;
  final DateTime endsAt;
  final String classGroupId;
  final String classLabel;
  final String subjectLabel;
  final String? classSubjectId;
  final String? status;
  final String? teacherName;

  bool occursOn(DateTime day) => isSameCalendarDay(startsAt, day);
}
