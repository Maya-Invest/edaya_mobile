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
  });

  factory TeacherSession.fromJson(
    Map<String, dynamic> json, {
    required String classGroupId,
    required String classLabel,
    required String subjectLabel,
  }) {
    final startsAt = parseApiDateTime(json['startsAt']);
    final endsAt = parseApiDateTime(json['endsAt']);
    if (startsAt == null || endsAt == null) {
      throw FormatException('Session ${json['id']} has invalid dates');
    }

    return TeacherSession(
      id: json['id'] as String,
      title: json['title'] as String,
      kind: json['kind'] as String? ?? 'course',
      startsAt: startsAt.toLocal(),
      endsAt: endsAt.toLocal(),
      classGroupId: classGroupId,
      classLabel: classLabel,
      subjectLabel: subjectLabel,
      classSubjectId: json['classSubjectId'] as String?,
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

  TeacherSession? projectOntoDay(DateTime day) {
    if (startsAt.weekday != day.weekday) {
      return null;
    }

    return TeacherSession(
      id: id,
      title: title,
      kind: kind,
      startsAt: DateTime(
        day.year,
        day.month,
        day.day,
        startsAt.hour,
        startsAt.minute,
      ),
      endsAt: DateTime(
        day.year,
        day.month,
        day.day,
        endsAt.hour,
        endsAt.minute,
      ),
      classGroupId: classGroupId,
      classLabel: classLabel,
      subjectLabel: subjectLabel,
      classSubjectId: classSubjectId,
    );
  }
}
