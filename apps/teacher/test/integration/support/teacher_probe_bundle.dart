import 'package:edaya_api_client/edaya_api_client.dart';
import 'package:edaya_integration_tests/edaya_integration_tests.dart';
import 'package:edaya_teacher/common/utils/academic_period.dart';
import 'package:edaya_teacher/features/calendar/models/teacher_session.dart';
import 'package:edaya_teacher/features/evaluations/models/evaluation_models.dart';
import 'package:edaya_teacher/features/report_cards/models/report_card_roster_models.dart';
import 'package:edaya_teacher/features/report_cards/report_card_logic.dart';
import 'package:edaya_teacher/navigation/teacher_entity_resolvers.dart';

import 'teacher_widget_test_harness.dart';

class TeacherReportCardCommentProbe {
  const TeacherReportCardCommentProbe({
    required this.resultId,
    required this.studentId,
    required this.studentName,
  });

  final String resultId;
  final String studentId;
  final String studentName;
}

class TeacherReportCardClassProbe {
  const TeacherReportCardClassProbe({
    required this.classGroupId,
    required this.classLabel,
    required this.generatedCount,
    required this.rosterStudentNames,
  });

  final String classGroupId;
  final String classLabel;
  final int generatedCount;
  final List<String> rosterStudentNames;
}

class TeacherCalendarSessionProbe {
  const TeacherCalendarSessionProbe({
    required this.sessionTitle,
    required this.sessionDay,
    required this.lessonSessionId,
    required this.classGroupId,
    required this.studentCount,
  });

  final String sessionTitle;
  final DateTime sessionDay;
  final String lessonSessionId;
  final String classGroupId;
  final int studentCount;
}

class TeacherTeachingProbe {
  const TeacherTeachingProbe({
    required this.classSubjectId,
    required this.matterNames,
  });

  final String classSubjectId;
  final List<String> matterNames;
}

class TeacherClassFilterProbe {
  const TeacherClassFilterProbe({
    required this.alternateClassGroupId,
    required this.alternateClassLabel,
  });

  final String alternateClassGroupId;
  final String alternateClassLabel;
}

/// API probes loaded once for teacher widget integration tests.
class TeacherProbeBundle {
  const TeacherProbeBundle({
    required this.timetableEvents,
    required this.evaluations,
    required this.reportCardClasses,
    required this.classSubjectIds,
    required this.sessionProbe,
    required this.teachingProbe,
    required this.classFilterProbe,
    required this.firstAssessmentTitle,
    required this.marksStudentCount,
    required this.periodId,
    required this.firstAssessmentId,
    required this.resolvedSession,
    required this.evaluationSummary,
    required this.reportCardRosterArgs,
    required this.reportCardCommentProbe,
    required this.reportCardCommentRouteArgs,
  });

  final List<dynamic> timetableEvents;
  final TeacherEvaluationsProbe? evaluations;
  final List<TeacherReportCardClassProbe> reportCardClasses;
  final List<String> classSubjectIds;
  final TeacherCalendarSessionProbe? sessionProbe;
  final TeacherTeachingProbe? teachingProbe;
  final TeacherClassFilterProbe? classFilterProbe;
  final String? firstAssessmentTitle;
  final int marksStudentCount;
  final String? periodId;
  final String? firstAssessmentId;
  final TeacherSession? resolvedSession;
  final EvaluationSummary? evaluationSummary;
  final ReportCardRosterArgs? reportCardRosterArgs;
  final TeacherReportCardCommentProbe? reportCardCommentProbe;
  final ReportCardCommentRouteArgs? reportCardCommentRouteArgs;

  TeacherReportCardClassProbe? get firstClassWithGeneratedReportCards {
    for (final row in reportCardClasses) {
      if (row.generatedCount > 0) {
        return row;
      }
    }
    return null;
  }

  static Future<TeacherProbeBundle> load(
    TeacherWidgetTestHarness harness,
  ) async {
    if (harness.isGuest) {
      throw StateError('TeacherProbeBundle.load requires an authenticated harness');
    }

    final client = harness.portalSession!.schoolClient;
    final profile = harness.profile!;
    final context = harness.context!;
    final classGroupIds = context.assignedClassGroups
        .map((row) => row['id'] as String)
        .toList();

    final timetables = await loadCalendarTimetables(client, classGroupIds);
    final timetableEvents =
        timetables[profile.primaryClassGroupId] ?? const <dynamic>[];

    TeacherEvaluationsProbe? evaluations;
    final sortedPeriods = sortAcademicPeriods(context.academicPeriods);
    final periodId = currentAcademicPeriodId(sortedPeriods);
    final classSubjectIds = context.teachingScope.classSubjectIds.toList();
    if (periodId != null && classSubjectIds.isNotEmpty) {
      evaluations = await loadTeacherEvaluations(
        client,
        classGroupId: profile.primaryClassGroupId,
        periodId: periodId,
        academicYearId: profile.academicYearId,
        classSubjectIds: classSubjectIds,
      );
    }

    final reportCardClasses = <TeacherReportCardClassProbe>[];
    if (periodId != null) {
      for (final classGroup in context.assignedClassGroups) {
        final classGroupId = classGroup['id'] as String;
        final classLabel = classGroup['name'] as String? ?? classGroupId;
        final results = await client.results.list({
          'classGroupId': classGroupId,
          'periodId': periodId,
        });
        final generated = results.where(reportCardIsGenerated).toList();
        final rosterStudentNames = await _loadRosterStudentNames(
          client,
          classGroupId: classGroupId,
          academicYearId: profile.academicYearId,
        );

        reportCardClasses.add(
          TeacherReportCardClassProbe(
            classGroupId: classGroupId,
            classLabel: classLabel,
            generatedCount: generated.length,
            rosterStudentNames: rosterStudentNames,
          ),
        );
      }
    }

    final sessionProbe = await _loadSessionProbe(
      client,
      profile: profile,
      context: context,
      timetableByClass: timetables,
    );

    final teachingProbe = await _loadTeachingProbe(
      client,
      classSubjectIds: classSubjectIds,
    );

    final classFilterProbe = _loadClassFilterProbe(
      profile: profile,
      assignedClassGroups: context.assignedClassGroups,
    );

    final firstAssessmentTitle = evaluations?.assessments.isNotEmpty == true
        ? evaluations!.assessments.first['title'] as String?
        : null;
    final firstAssessmentId = evaluations?.assessments.isNotEmpty == true
        ? evaluations!.assessments.first['id'] as String?
        : null;
    final marksStudentCount = evaluations?.enrollments.length ?? 0;

    final classLabelById = {
      for (final classGroup in context.assignedClassGroups)
        classGroup['id'] as String:
            classGroup['name'] as String? ?? classGroup['id'] as String,
    };

    TeacherSession? resolvedSession;
    if (sessionProbe != null) {
      final subjectLabelByClassSubjectId = await _subjectLabelsByClassSubject(
        client,
        classSubjectIds.toSet(),
      );
      resolvedSession = await resolveTeacherSession(
        client,
        sessionId: sessionProbe.lessonSessionId,
        classLabelById: classLabelById,
        subjectLabelByClassSubjectId: subjectLabelByClassSubjectId,
      );
    }

    EvaluationSummary? evaluationSummary;
    if (firstAssessmentId != null) {
      evaluationSummary = await resolveEvaluationSummary(
        client,
        assessmentId: firstAssessmentId,
        academicYearId: profile.academicYearId,
        classLabelById: classLabelById,
      );
    }

    ReportCardRosterArgs? reportCardRosterArgs;
    TeacherReportCardClassProbe? reportClass;
    for (final row in reportCardClasses) {
      if (row.generatedCount > 0) {
        reportClass = row;
        break;
      }
    }
    if (periodId != null && reportClass != null) {
      reportCardRosterArgs = await resolveReportCardRosterArgs(
        client,
        classGroupId: reportClass.classGroupId,
        periodId: periodId,
      );
    }

    final reportCardCommentProbe = await _loadReportCardCommentProbe(
      client,
      classGroupIds: classGroupIds,
      periodId: periodId,
    );

    ReportCardCommentRouteArgs? reportCardCommentRouteArgs;
    if (reportCardCommentProbe != null) {
      final target = await resolveReportCardCommentTarget(
        client,
        resultId: reportCardCommentProbe.resultId,
        studentId: reportCardCommentProbe.studentId,
      );
      if (target != null) {
        reportCardCommentRouteArgs = ReportCardCommentRouteArgs(
          rosterArgs: target.rosterArgs,
          student: target.student,
        );
      }
    }

    return TeacherProbeBundle(
      timetableEvents: timetableEvents,
      evaluations: evaluations,
      reportCardClasses: reportCardClasses,
      classSubjectIds: classSubjectIds,
      sessionProbe: sessionProbe,
      teachingProbe: teachingProbe,
      classFilterProbe: classFilterProbe,
      firstAssessmentTitle: firstAssessmentTitle,
      marksStudentCount: marksStudentCount,
      periodId: periodId,
      firstAssessmentId: firstAssessmentId,
      resolvedSession: resolvedSession,
      evaluationSummary: evaluationSummary,
      reportCardRosterArgs: reportCardRosterArgs,
      reportCardCommentProbe: reportCardCommentProbe,
      reportCardCommentRouteArgs: reportCardCommentRouteArgs,
    );
  }

  static Future<Map<String, String>> _subjectLabelsByClassSubject(
    SchoolClient client,
    Set<String> classSubjectIds,
  ) async {
    if (classSubjectIds.isEmpty) {
      return const {};
    }

    final rows = await client.classSubjects.list(
      entitiesByIds(classSubjectIds.toList()),
    );
    final subjectIds = rows
        .map((row) => row['subjectId'] as String?)
        .whereType<String>()
        .toList();
    final subjects = subjectIds.isEmpty
        ? <Map<String, dynamic>>[]
        : await client.subjects.list(entitiesByIds(subjectIds));
    final subjectNameById = {
      for (final subject in subjects)
        subject['id'] as String: subject['name'] as String? ?? '',
    };

    return {
      for (final row in rows)
        row['id'] as String:
            subjectNameById[row['subjectId'] as String? ?? ''] ?? 'Subject',
    };
  }

  static Future<TeacherReportCardCommentProbe?> _loadReportCardCommentProbe(
    SchoolClient client, {
    required List<String> classGroupIds,
    required String? periodId,
  }) async {
    if (periodId == null) {
      return null;
    }

    for (final classGroupId in classGroupIds) {
      final results = await client.results.list({
        'classGroupId': classGroupId,
        'periodId': periodId,
      });
      for (final result in results) {
        if (!reportCardIsGenerated(result)) {
          continue;
        }
        final resultId = result['id'] as String?;
        final studentId = result['studentId'] as String?;
        if (resultId == null || studentId == null) {
          continue;
        }

        final student = await client.students.get(studentId);
        final firstName = student['firstName'] as String? ?? '';
        final lastName = student['lastName'] as String? ?? '';
        final fullName = '$firstName $lastName'.trim();

        return TeacherReportCardCommentProbe(
          resultId: resultId,
          studentId: studentId,
          studentName: fullName.isEmpty ? studentId : fullName,
        );
      }
    }

    return null;
  }

  static Future<List<String>> _loadRosterStudentNames(
    SchoolClient client, {
    required String classGroupId,
    required String academicYearId,
  }) async {
    final enrollments = await client.enrollments.list(
      activeEnrollmentsForClass(classGroupId, academicYearId: academicYearId),
    );
    final studentIds = enrollments
        .map((row) => row['studentId'] as String?)
        .whereType<String>()
        .toList();
    if (studentIds.isEmpty) {
      return const [];
    }

    final students = await client.students.list(entitiesByIds(studentIds));
    return students
        .map((row) {
          final firstName = row['firstName'] as String? ?? '';
          final lastName = row['lastName'] as String? ?? '';
          return '$firstName $lastName'.trim();
        })
        .where((name) => name.isNotEmpty)
        .toList();
  }

  static Future<TeacherCalendarSessionProbe?> _loadSessionProbe(
    SchoolClient client, {
    required TeacherPortalProfile profile,
    required TeacherPortalContext context,
    required Map<String, List<dynamic>> timetableByClass,
  }) async {
    final classGroupIds = context.assignedClassGroups
        .map((row) => row['id'] as String)
        .toSet();

    for (final classGroupId in classGroupIds) {
      final events = timetableByClass[classGroupId] ?? const [];
      final preferredSubjectId = profile.expectedClassSubjectIds.isEmpty
          ? null
          : profile.expectedClassSubjectIds.first;
      final lessonSessionId = await resolveLessonSessionIdForClass(
        client,
        classGroupId: classGroupId,
        timetableEvents: events,
        classSubjectId: profile.kind == TeacherPortalKind.subject
            ? preferredSubjectId
            : null,
      );
      if (lessonSessionId == null) {
        continue;
      }

      final detail = await loadTeacherSessionDetail(
        client,
        lessonSessionId: lessonSessionId,
        classGroupId: classGroupId,
        academicYearId: profile.academicYearId,
      );

      Map<String, dynamic>? matchedEvent;
      for (final event in events) {
        if (event is! Map<String, dynamic>) {
          continue;
        }
        final eventSessionId =
            event['lessonSessionId'] as String? ?? event['id'] as String?;
        if (eventSessionId == lessonSessionId) {
          matchedEvent = event;
          break;
        }
      }

      final startsAtRaw =
          matchedEvent?['startsAt'] as String? ??
          detail.lessonSession['startsAt'] as String?;
      final startsAt = startsAtRaw == null
          ? DateTime.now()
          : DateTime.parse(startsAtRaw).toLocal();
      final title =
          matchedEvent?['title'] as String? ??
          detail.lessonSession['title'] as String? ??
          'Lesson';

      return TeacherCalendarSessionProbe(
        sessionTitle: title,
        sessionDay: DateTime(startsAt.year, startsAt.month, startsAt.day),
        lessonSessionId: lessonSessionId,
        classGroupId: classGroupId,
        studentCount: detail.students.length,
      );
    }

    return null;
  }

  static Future<TeacherTeachingProbe?> _loadTeachingProbe(
    SchoolClient client, {
    required List<String> classSubjectIds,
  }) async {
    if (classSubjectIds.isEmpty) {
      return null;
    }

    final matterNames = <String>{};
    for (final classSubjectId in classSubjectIds) {
      final matters = await client.classSubjectMatters.list({
        'classSubjectId': classSubjectId,
      });
      final matterIds = matters
          .map((row) => row['subjectMatterId'] as String?)
          .whereType<String>()
          .toList();
      if (matterIds.isEmpty) {
        continue;
      }

      final subjectMatters = await client.subjectMatters.list(
        entitiesByIds(matterIds),
      );
      matterNames.addAll(
        subjectMatters
            .map(
              (row) => row['name'] as String? ?? row['title'] as String? ?? '',
            )
            .where((name) => name.isNotEmpty),
      );
    }

    if (matterNames.isEmpty) {
      return TeacherTeachingProbe(
        classSubjectId: classSubjectIds.first,
        matterNames: const [],
      );
    }

    return TeacherTeachingProbe(
      classSubjectId: classSubjectIds.first,
      matterNames: matterNames.toList(),
    );
  }

  static TeacherClassFilterProbe? _loadClassFilterProbe({
    required TeacherPortalProfile profile,
    required List<Map<String, dynamic>> assignedClassGroups,
  }) {
    if (assignedClassGroups.length < 2) {
      return null;
    }

    final alternate = assignedClassGroups.firstWhere(
      (row) => row['id'] != profile.primaryClassGroupId,
      orElse: () => assignedClassGroups.last,
    );
    final alternateId = alternate['id'] as String;
    if (alternateId == profile.primaryClassGroupId) {
      return null;
    }

    return TeacherClassFilterProbe(
      alternateClassGroupId: alternateId,
      alternateClassLabel: alternate['name'] as String? ?? alternateId,
    );
  }
}
