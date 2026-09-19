import 'package:edaya_api_client/edaya_api_client.dart';

import 'package:edaya_shared/edaya_shared.dart';
import '../common/utils/entity_filters.dart';
import '../features/calendar/models/teacher_session.dart';
import '../features/evaluations/models/evaluation_models.dart';
import '../features/report_cards/models/report_card_roster_models.dart';
import '../features/report_cards/report_card_logic.dart';

Future<TeacherSession?> resolveTeacherSession(
  SchoolClient client, {
  required String sessionId,
  required Map<String, String> classLabelById,
  required Map<String, String> subjectLabelByClassSubjectId,
}) async {
  try {
    final lesson = await client.lessonSessions.get(sessionId);
    return _sessionFromLesson(
      lesson,
      classLabelById: classLabelById,
      subjectLabelByClassSubjectId: subjectLabelByClassSubjectId,
    );
  } on Object {
    // Fall through to activity sessions.
  }

  try {
    final activity = await client.activitySessions.get(sessionId);
    return _sessionFromActivity(
      activity,
      classLabelById: classLabelById,
    );
  } on Object {
    return null;
  }
}

TeacherSession? _sessionFromLesson(
  Map<String, dynamic> lesson, {
  required Map<String, String> classLabelById,
  required Map<String, String> subjectLabelByClassSubjectId,
}) {
  final id = lesson['id'] as String?;
  final classGroupId = lesson['classGroupId'] as String?;
  final startsAt = parseApiDateTime(lesson['startsAt']);
  final endsAt = parseApiDateTime(lesson['endsAt']);
  if (id == null || classGroupId == null || startsAt == null || endsAt == null) {
    return null;
  }

  final classSubjectId = lesson['classSubjectId'] as String?;
  return TeacherSession(
    id: id,
    title: lesson['displayLabel'] as String? ?? id,
    kind: 'lesson',
    startsAt: startsAt,
    endsAt: endsAt,
    classGroupId: classGroupId,
    classLabel: classLabelById[classGroupId] ?? classGroupId,
    subjectLabel: classSubjectId == null
        ? systemL10n().subjectFallback
        : subjectLabelByClassSubjectId[classSubjectId] ??
              systemL10n().subjectFallback,
    classSubjectId: classSubjectId,
    status: lesson['status'] as String?,
  );
}

TeacherSession? _sessionFromActivity(
  Map<String, dynamic> activity, {
  required Map<String, String> classLabelById,
}) {
  final id = activity['id'] as String?;
  final classGroupId = activity['classGroupId'] as String?;
  final startsAt = parseApiDateTime(activity['startsAt']);
  final endsAt = parseApiDateTime(activity['endsAt']);
  if (id == null || classGroupId == null || startsAt == null || endsAt == null) {
    return null;
  }

  return TeacherSession(
    id: id,
    title: activity['displayLabel'] as String? ?? id,
    kind: 'activity',
    startsAt: startsAt,
    endsAt: endsAt,
    classGroupId: classGroupId,
    classLabel: classLabelById[classGroupId] ?? classGroupId,
    subjectLabel: activity['activityName'] as String? ?? systemL10n().subjectFallback,
  );
}

Future<EvaluationSummary?> resolveEvaluationSummary(
  SchoolClient client, {
  required String assessmentId,
  required String? academicYearId,
  required Map<String, String> classLabelById,
}) async {
  try {
    final assessment = await client.assessments.get(assessmentId);
    final classSubjectId = assessment['classSubjectId'] as String?;
    final classGroupId = assessment['classGroupId'] as String?;
    final periodId = assessment['periodId'] as String?;
    if (classSubjectId == null || classGroupId == null || periodId == null) {
      return null;
    }

    final classSubject = await client.classSubjects.get(classSubjectId);
    final subjectId = classSubject['subjectId'] as String?;
    final subjectLabel = subjectId == null
        ? systemL10n().subjectFallback
        : (await client.subjects.get(subjectId))['name'] as String? ??
              systemL10n().subjectFallback;

    final results = await client.assessmentResults.list(
      resultsForAssessment(assessmentId),
    );
    final graded = results.where((row) => row['score'] != null).length;
    final enrollments = await client.enrollments.list(
      activeEnrollmentsForClass(classGroupId, academicYearId: academicYearId),
    );

    return EvaluationSummary(
      id: assessmentId,
      title: assessment['title'] as String? ?? assessmentId,
      classGroupId: classGroupId,
      classSubjectId: classSubjectId,
      periodId: periodId,
      classLabel: classLabelById[classGroupId] ?? classGroupId,
      subjectLabel: subjectLabel,
      date:
          (assessment['dueAt'] as String?)?.substring(0, 10) ??
          (assessment['startsAt'] as String?)?.substring(0, 10) ??
          '',
      maxScore: (assessment['maxScore'] as num?)?.toDouble() ?? 20,
      gradedCount: graded,
      totalStudents: enrollments.length,
    );
  } on Object {
    return null;
  }
}

Future<ReportCardRosterArgs> resolveReportCardRosterArgs(
  SchoolClient client, {
  required String classGroupId,
  required String periodId,
}) async {
  var classLabel = classGroupId;
  var periodLabel = periodId;

  try {
    final classGroup = await client.classGroups.get(classGroupId);
    classLabel = classGroup['name'] as String? ?? classGroupId;
  } on Object {
    // Keep fallback label.
  }

  try {
    final period = await client.academicPeriods.get(periodId);
    periodLabel = period['name'] as String? ?? periodId;
  } on Object {
    // Keep fallback label.
  }

  return ReportCardRosterArgs(
    classGroupId: classGroupId,
    classLabel: classLabel,
    periodId: periodId,
    periodLabel: periodLabel,
  );
}

Future<({ReportCardRosterArgs rosterArgs, ReportCardStudentRow student})?>
resolveReportCardCommentTarget(
  SchoolClient client, {
  required String resultId,
  required String studentId,
}) async {
  try {
    final result = await client.results.get(resultId);
    if (!reportCardIsGenerated(result)) {
      return null;
    }

    final classGroupId = result['classGroupId'] as String?;
    final periodId = result['periodId'] as String?;
    if (classGroupId == null || periodId == null) {
      return null;
    }

    final rosterArgs = await resolveReportCardRosterArgs(
      client,
      classGroupId: classGroupId,
      periodId: periodId,
    );

    final student = await client.students.get(studentId);
    final firstName = student['firstName'] as String? ?? '';
    final lastName = student['lastName'] as String? ?? '';
    final fullName = '$firstName $lastName'.trim();
    final displayName = fullName.isEmpty ? studentId : fullName;

    return (
      rosterArgs: rosterArgs,
      student: ReportCardStudentRow(
        studentId: studentId,
        studentName: displayName,
        studentInitials: _initials(displayName),
        photoUrl: student['photoUrl'] as String?,
        reportCardId: resultId,
        status: result['status'] as String?,
        overallAverage: (result['overallAverage'] as num?)?.toDouble(),
        rank: (result['rank'] as num?)?.toInt(),
        classSize: (result['classSize'] as num?)?.toInt(),
        hasComment: reportCardHasComment(result),
      ),
    );
  } on Object {
    return null;
  }
}

String _initials(String name) {
  final parts = name.trim().split(RegExp(r'\s+'));
  if (parts.isEmpty) {
    return '?';
  }
  if (parts.length == 1) {
    return parts.first.substring(0, 1).toUpperCase();
  }
  return '${parts.first.substring(0, 1)}${parts.last.substring(0, 1)}'
      .toUpperCase();
}
