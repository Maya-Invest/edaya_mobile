import 'package:edaya_shared/edaya_shared.dart';

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
    this.originalMention,
    this.calculation,
    this.designation,
    this.notes,
  });

  factory GradeEntry.fromMaps({
    required Map<String, dynamic> result,
    required Map<String, dynamic> assessment,
    required String subjectName,
    required String periodName,
  }) {
    final date = parseApiDateTime(
      assessment['startsAt'] ??
          assessment['dueAt'] ??
          assessment['date'] ??
          assessment['metAt'],
    );

    final rawScore = result['score'];
    final score = rawScore is num
        ? rawScore.toDouble()
        : double.tryParse(rawScore?.toString() ?? '');

    return GradeEntry(
      id: result['id'] as String,
      assessmentId: assessment['id'] as String,
      title: assessment['title'] as String,
      subjectName: subjectName,
      periodId: assessment['periodId'] as String,
      periodName: periodName,
      date: date,
      score: score,
      originalMention: (result['originalEntry'] as Map?)?['code'] as String?,
      calculation: result['calculation'] is Map
          ? Map<String, dynamic>.from(result['calculation'] as Map)
          : null,
      designation: result['designation'] as String?,
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
  final String? originalMention;
  final Map<String, dynamic>? calculation;
  final String? designation;
  final double maxScore;
  final double coefficient;
  final String? notes;

  bool get hasScore =>
      (score != null || calculation != null) &&
      designation != 'absent' &&
      designation != 'exempt';
  String get scoreLabel {
    if (originalMention != null) {
      final value = calculation?['reportedValue'];
      return '$originalMention${value == null ? '' : ' · ${formatGradeNumber(value as num)} / ${formatGradeNumber(calculation!['maximum'] as num)}'}';
    }
    final value = score;
    if (value != null) {
      return '${formatGradeNumber(value, precision: calculation == null ? 2 : null)} / ${formatGradeNumber(maxScore, precision: 2)}';
    }
    return switch (designation) {
      'absent' => systemL10n().marksAbsent,
      'exempt' => systemL10n().marksExempt,
      _ => '—',
    };
  }
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

double? averageGrades(
  Iterable<GradeEntry> entries,
  GradingPolicyView? policy,
) => gradingAverage([
  for (final entry in entries.where((row) => row.hasScore))
    (
      score: entry.score,
      maximum: entry.maxScore,
      coefficient: entry.coefficient,
      calculation: entry.calculation,
    ),
], policy: policy);
