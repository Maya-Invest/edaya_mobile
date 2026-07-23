part of 'mock_store.dart';

class MockSchool {
  const MockSchool({
    required this.id,
    required this.name,
    required this.years,
  });

  final String id;
  final String name;
  final List<String> years;
}

class MockTeacher {
  const MockTeacher({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.email,
    this.photoUrl,
  });

  final String id;
  final String firstName;
  final String lastName;
  final String email;
  final String? photoUrl;

  String get fullName => '$firstName $lastName';
  String get initials => '${firstName[0]}${lastName[0]}';
}

class MockClassAssignment {
  const MockClassAssignment({
    required this.id,
    required this.classId,
    required this.classLabel,
    required this.subject,
    required this.isHomeroom,
    required this.studentCount,
  });

  final String id;
  final String classId;
  final String classLabel;
  final String subject;
  final bool isHomeroom;
  final int studentCount;

  String get subjectLabel => isHomeroom ? '$subject · Titulaire' : subject;
}

class MockStudent {
  const MockStudent({
    required this.id,
    required this.classId,
    required this.firstName,
    required this.lastName,
    this.photoUrl,
  });

  final String id;
  final String classId;
  final String firstName;
  final String lastName;
  final String? photoUrl;

  String get fullName => '$firstName $lastName';
  String get initials => '${firstName[0]}${lastName[0]}';
}

class MockSession {
  MockSession({
    required this.id,
    required this.classId,
    required this.classLabel,
    required this.subject,
    required this.date,
    required this.startHour,
    required this.endHour,
    this.room = '',
    this.attendanceComplete = false,
    this.logbookComplete = false,
  });

  final String id;
  final String classId;
  final String classLabel;
  final String subject;
  final DateTime date;
  final int startHour;
  final int endHour;
  final String room;
  bool attendanceComplete;
  bool logbookComplete;
}

enum AttendanceStatus { present, absent, late, excused }

extension AttendanceStatusLabel on AttendanceStatus {
  String get labelFr => switch (this) {
        AttendanceStatus.present => 'Présent',
        AttendanceStatus.absent => 'Absent',
        AttendanceStatus.late => 'Retard',
        AttendanceStatus.excused => 'Excusé',
      };
}

class MockAttendanceRecord {
  MockAttendanceRecord({
    required this.studentId,
    required this.status,
  });

  final String studentId;
  AttendanceStatus status;
}

class MockLogbook {
  MockLogbook({
    required this.sessionId,
    this.content = '',
    this.objectives = '',
    this.homework = '',
    this.progressPercent = 0,
  });

  final String sessionId;
  String content;
  String objectives;
  String homework;
  int progressPercent;
}

class MockEvaluation {
  MockEvaluation({
    required this.id,
    required this.classId,
    required this.classLabel,
    required this.subject,
    required this.title,
    required this.period,
    required this.maxScore,
    required this.coefficient,
    required this.dueDate,
    required this.gradedCount,
    required this.totalCount,
  });

  final String id;
  final String classId;
  final String classLabel;
  final String subject;
  final String title;
  final String period;
  final double maxScore;
  final double coefficient;
  final DateTime dueDate;
  int gradedCount;
  final int totalCount;

  bool get needsMarks => gradedCount < totalCount;
}

class MockMark {
  MockMark({
    required this.evaluationId,
    required this.studentId,
    this.score,
  });

  final String evaluationId;
  final String studentId;
  double? score;
}

class MockReportCardClass {
  const MockReportCardClass({
    required this.id,
    required this.classId,
    required this.classLabel,
    required this.period,
    required this.periodId,
    required this.pendingComments,
    required this.totalStudents,
  });

  final String id;
  final String classId;
  final String classLabel;
  final String period;
  final String periodId;
  final int pendingComments;
  final int totalStudents;
}

class MockReportCardStudent {
  MockReportCardStudent({
    required this.id,
    required this.classId,
    required this.periodId,
    required this.studentId,
    required this.studentName,
    required this.average,
    required this.rank,
    required this.hasHomeroomComment,
    required this.hasSubjectComment,
    this.homeroomComment = '',
    this.subjectComment = '',
  });

  final String id;
  final String classId;
  final String periodId;
  final String studentId;
  final String studentName;
  final double average;
  final int rank;
  bool hasHomeroomComment;
  bool hasSubjectComment;
  String homeroomComment;
  String subjectComment;
}

class MockMessage {
  MockMessage({
    required this.id,
    required this.title,
    required this.body,
    required this.sentAt,
    required this.read,
    required this.type,
  });

  final String id;
  final String title;
  final String body;
  final DateTime sentAt;
  bool read;
  final String type;
}

class MockTask {
  const MockTask({
    required this.id,
    required this.kind,
    required this.title,
    required this.subtitle,
    required this.route,
  });

  final String id;
  final String kind;
  final String title;
  final String subtitle;
  final String route;
}
