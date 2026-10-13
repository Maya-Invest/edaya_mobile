import 'dart:math';

String newSchoolRequestId() => List.generate(
  24,
  (_) => Random.secure().nextInt(256).toRadixString(16).padLeft(2, '0'),
).join();

Map<String, dynamic> assessmentResultPayload({
  required String assessmentId,
  required String studentId,
  required double? score,
  String? resultId,
  required String requestId,
  required int expectedRevision,
  String? designation,
  String? mentionId,
  int? expectedGradingRevision,
  DateTime? createdAt,
}) {
  final resolvedId = resultId ?? 'ar-$assessmentId-$studentId';
  return {
    'id': resolvedId,
    'studentId': studentId,
    'assessmentId': assessmentId,
    'score': score,
    if (mentionId != null || expectedGradingRevision != null)
      'mentionId': mentionId,
    'expectedGradingRevision': ?expectedGradingRevision,
    if (designation != null || score != null || mentionId != null)
      'designation': designation ?? 'scored',
    'requestId': requestId,
    'expectedRevision': expectedRevision,
    'createdAt': (createdAt ?? DateTime.now().toUtc()).toIso8601String(),
  };
}

Map<String, dynamic> buildInClassAssessmentTiming(DateTime date) {
  final startsAt = DateTime.utc(date.year, date.month, date.day, 9);
  final endsAt = startsAt.add(const Duration(hours: 1));
  return {
    'startsAt': startsAt.toIso8601String(),
    'endsAt': endsAt.toIso8601String(),
  };
}

Map<String, dynamic> createAssessmentPayload({
  required String id,
  required String classGroupId,
  required String classSubjectId,
  required String periodId,
  required String title,
  required double maxScore,
  required DateTime assessmentDate,
  String kind = 'quiz',
  double coefficient = 1,
  DateTime? createdAt,
  DateTime? homeworkDueDate,
}) {
  final now = createdAt ?? DateTime.now().toUtc();
  final payload = <String, dynamic>{
    'id': id,
    'classGroupId': classGroupId,
    'classSubjectId': classSubjectId,
    'periodId': periodId,
    'title': title.trim(),
    'kind': kind,
    'maxScore': maxScore,
    'coefficient': coefficient,
    'attachments': const <Map<String, dynamic>>[],
    'createdAt': now.toIso8601String(),
  };

  if (kind == 'homework') {
    final due = homeworkDueDate ?? assessmentDate;
    payload['dueAt'] = due.toIso8601String().substring(0, 10);
  } else {
    payload.addAll(buildInClassAssessmentTiming(assessmentDate));
  }

  return payload;
}
