class EvaluationSummary {
  const EvaluationSummary({
    required this.id,
    required this.title,
    required this.classGroupId,
    required this.classSubjectId,
    required this.classLabel,
    required this.subjectLabel,
    required this.date,
    required this.maxScore,
    required this.gradedCount,
    required this.totalStudents,
  });

  final String id;
  final String title;
  final String classGroupId;
  final String classSubjectId;
  final String classLabel;
  final String subjectLabel;
  final String date;
  final double maxScore;
  final int gradedCount;
  final int totalStudents;

  double get progress =>
      totalStudents == 0 ? 0 : gradedCount / totalStudents;
}

class StudentMarkRow {
  const StudentMarkRow({
    required this.studentId,
    required this.studentName,
    this.resultId,
    this.score,
  });

  final String studentId;
  final String studentName;
  final String? resultId;
  final double? score;

  StudentMarkRow copyWith({String? resultId, double? score}) {
    return StudentMarkRow(
      studentId: studentId,
      studentName: studentName,
      resultId: resultId ?? this.resultId,
      score: score ?? this.score,
    );
  }
}
