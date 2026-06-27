import '../../../common/utils/date_time_parse.dart';

class GradeEntry {
  const GradeEntry({
    required this.id,
    required this.assessmentId,
    required this.title,
    required this.subjectName,
    required this.periodId,
    required this.periodName,
    required this.maxScore,
    required this.coefficient,
    this.date,
    this.score,
    this.notes,
  });

  factory GradeEntry.fromMaps({
    required Map<String, dynamic> result,
    required Map<String, dynamic> assessment,
    required String subjectName,
    required String periodName,
  }) {
    final date = parseApiDateTime(
      assessment['date'] ?? assessment['dueAt'] ?? assessment['metAt'],
    );

    final rawScore = result['score'];
    final score = rawScore is num ? rawScore.toDouble() : null;

    return GradeEntry(
      id: result['id'] as String,
      assessmentId: assessment['id'] as String,
      title: assessment['title'] as String,
      subjectName: subjectName,
      periodId: assessment['periodId'] as String,
      periodName: periodName,
      date: date,
      score: score,
      maxScore: (assessment['maxScore'] as num?)?.toDouble() ?? 20,
      coefficient: (assessment['coefficient'] as num?)?.toDouble() ?? 1,
      notes: result['notes'] as String?,
    );
  }

  final String id;
  final String assessmentId;
  final String title;
  final String subjectName;
  final String periodId;
  final String periodName;
  final DateTime? date;
  final double? score;
  final double maxScore;
  final double coefficient;
  final String? notes;

  bool get hasScore => score != null;
}

class SubjectGradeGroup {
  const SubjectGradeGroup({
    required this.subjectName,
    required this.entries,
    this.average,
  });

  final String subjectName;
  final List<GradeEntry> entries;
  final double? average;
}
