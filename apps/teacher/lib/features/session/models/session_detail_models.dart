enum SessionAttendanceStatus {
  present,
  absent,
  late;

  static SessionAttendanceStatus? fromApi(String? value) {
    return switch (value) {
      'present' => SessionAttendanceStatus.present,
      'absent' => SessionAttendanceStatus.absent,
      'late' => SessionAttendanceStatus.late,
      _ => null,
    };
  }

  String get apiValue => name;

  String get label => switch (this) {
    SessionAttendanceStatus.present => 'Present',
    SessionAttendanceStatus.absent => 'Absent',
    SessionAttendanceStatus.late => 'Late',
  };
}

class SessionStudentRow {
  const SessionStudentRow({
    required this.studentId,
    required this.studentName,
    required this.studentInitials,
    this.attendanceId,
    this.status,
  });

  final String studentId;
  final String studentName;
  final String studentInitials;
  final String? attendanceId;
  final SessionAttendanceStatus? status;

  SessionStudentRow copyWith({
    String? attendanceId,
    SessionAttendanceStatus? status,
  }) {
    return SessionStudentRow(
      studentId: studentId,
      studentName: studentName,
      studentInitials: studentInitials,
      attendanceId: attendanceId ?? this.attendanceId,
      status: status ?? this.status,
    );
  }
}

class SessionLogbook {
  const SessionLogbook({
    required this.id,
    required this.chapter,
    required this.content,
    required this.objectives,
    required this.progress,
    this.homework,
  });

  factory SessionLogbook.fromJson(Map<String, dynamic> json) {
    return SessionLogbook(
      id: json['id'] as String,
      chapter: json['chapter'] as String? ?? '',
      content: json['content'] as String? ?? '',
      objectives: (json['objectives'] as List<dynamic>? ?? const [])
          .map((entry) => entry as String)
          .toList(),
      homework: json['homework'] as String?,
      progress: (json['progress'] as num?)?.toInt() ?? 0,
    );
  }

  final String id;
  final String chapter;
  final String content;
  final List<String> objectives;
  final String? homework;
  final int progress;
}

class SessionSubjectMatterOption {
  const SessionSubjectMatterOption({
    required this.id,
    required this.name,
    required this.completedPercentage,
  });

  final String id;
  final String name;
  final int completedPercentage;
}
