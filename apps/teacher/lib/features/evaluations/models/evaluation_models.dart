class EvaluationSummary {
  const EvaluationSummary({
    required this.id,
    required this.title,
    required this.classGroupId,
    required this.classSubjectId,
    required this.periodId,
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
  final String periodId;
  final String classLabel;
  final String subjectLabel;
  final String date;
  final double maxScore;
  final int gradedCount;
  final int totalStudents;

  double get progress => totalStudents == 0 ? 0 : gradedCount / totalStudents;
}

class StudentMarkRow {
  const StudentMarkRow({
    required this.studentId,
    required this.studentName,
    this.studentInitials,
    this.photoUrl,
    this.resultId,
    this.score,
    this.marksLocked = false,
  });

  final String studentId;
  final String studentName;
  final String? studentInitials;
  final String? photoUrl;
  final String? resultId;
  final double? score;
  final bool marksLocked;

  static const Object _unset = Object();

  StudentMarkRow copyWith({
    Object? resultId = _unset,
    Object? score = _unset,
    bool? marksLocked,
  }) {
    return StudentMarkRow(
      studentId: studentId,
      studentName: studentName,
      studentInitials: studentInitials,
      photoUrl: photoUrl,
      resultId: identical(resultId, _unset)
          ? this.resultId
          : resultId as String?,
      score: identical(score, _unset) ? this.score : score as double?,
      marksLocked: marksLocked ?? this.marksLocked,
    );
  }
}
