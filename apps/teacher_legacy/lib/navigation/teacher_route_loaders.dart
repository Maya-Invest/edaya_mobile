import 'package:edaya_api_client/edaya_api_client.dart';
import 'package:edaya_shared/edaya_shared.dart';
import 'package:flutter/material.dart';
import 'package:levit_flutter/levit_flutter.dart';

import '../features/calendar/models/teacher_session.dart';
import '../features/context/academic_year_controller.dart';
import '../features/context/teacher_context_controller.dart';
import '../features/evaluations/marks_entry_sheet.dart';
import '../features/evaluations/models/evaluation_models.dart';
import '../features/report_cards/models/report_card_roster_models.dart';
import '../features/report_cards/report_card_comment_sheet.dart';
import '../features/report_cards/report_card_roster_sheet.dart';
import '../features/session/session_details_sheet.dart';
import 'teacher_entity_resolvers.dart';

class TeacherSessionRouteLoader extends StatefulWidget {
  const TeacherSessionRouteLoader({super.key, required this.sessionId});

  final String sessionId;

  @override
  State<TeacherSessionRouteLoader> createState() =>
      _TeacherSessionRouteLoaderState();
}

class _TeacherSessionRouteLoaderState extends State<TeacherSessionRouteLoader> {
  TeacherSession? _session;
  String? _error;
  var _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    final teacherContext = context.levit.find<TeacherContextController>();
    final schoolClient = context.levit.find<SchoolClientFactory>();
    final classLabelById = {
      for (final assigned in teacherContext.assignedClasses.value)
        assigned.id: assigned.label,
    };
    final subjectLabelByClassSubjectId = await _subjectLabelsByClassSubject(
      schoolClient(),
      teacherContext.taughtClassSubjectIds.value,
    );

    final session = await resolveTeacherSession(
      schoolClient(),
      sessionId: widget.sessionId,
      classLabelById: classLabelById,
      subjectLabelByClassSubjectId: subjectLabelByClassSubjectId,
    );

    if (!mounted) {
      return;
    }

    setState(() {
      _loading = false;
      _session = session;
      _error = session == null ? context.tr.missingSessionDetailsRouteData : null;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    if (_error != null || _session == null) {
      return Scaffold(
        body: RouteErrorPage(
          message: _error ?? context.tr.missingSessionDetailsRouteData,
        ),
      );
    }

    return SessionDetailsSheet(session: _session!);
  }
}

class TeacherAssessmentMarksRouteLoader extends StatefulWidget {
  const TeacherAssessmentMarksRouteLoader({
    super.key,
    required this.assessmentId,
  });

  final String assessmentId;

  @override
  State<TeacherAssessmentMarksRouteLoader> createState() =>
      _TeacherAssessmentMarksRouteLoaderState();
}

class _TeacherAssessmentMarksRouteLoaderState
    extends State<TeacherAssessmentMarksRouteLoader> {
  EvaluationSummary? _evaluation;
  String? _error;
  var _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    final teacherContext = context.levit.find<TeacherContextController>();
    final academicYear = context.levit.find<AcademicYearController>();
    final schoolClient = context.levit.find<SchoolClientFactory>();
    final classLabelById = {
      for (final assigned in teacherContext.assignedClasses.value)
        assigned.id: assigned.label,
    };

    final evaluation = await resolveEvaluationSummary(
      schoolClient(),
      assessmentId: widget.assessmentId,
      academicYearId: academicYear.selectedYearId.value,
      classLabelById: classLabelById,
    );

    if (!mounted) {
      return;
    }

    setState(() {
      _loading = false;
      _evaluation = evaluation;
      _error = evaluation == null ? context.tr.missingMarksEntryRouteData : null;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    if (_error != null || _evaluation == null) {
      return Scaffold(
        body: RouteErrorPage(
          message: _error ?? context.tr.missingMarksEntryRouteData,
        ),
      );
    }

    return MarksEntrySheet(evaluation: _evaluation!);
  }
}

class TeacherReportCardRosterRouteLoader extends StatefulWidget {
  const TeacherReportCardRosterRouteLoader({
    super.key,
    required this.classGroupId,
    required this.periodId,
  });

  final String classGroupId;
  final String periodId;

  @override
  State<TeacherReportCardRosterRouteLoader> createState() =>
      _TeacherReportCardRosterRouteLoaderState();
}

class _TeacherReportCardRosterRouteLoaderState
    extends State<TeacherReportCardRosterRouteLoader> {
  ReportCardRosterArgs? _args;
  var _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
    });

    final schoolClient = context.levit.find<SchoolClientFactory>();
    final args = await resolveReportCardRosterArgs(
      schoolClient(),
      classGroupId: widget.classGroupId,
      periodId: widget.periodId,
    );

    if (!mounted) {
      return;
    }

    setState(() {
      _loading = false;
      _args = args;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    if (_args == null) {
      return Scaffold(
        body: RouteErrorPage(
          message: context.tr.missingReportCardRosterRouteData,
        ),
      );
    }

    return ReportCardRosterSheet(rosterArgs: _args!);
  }
}

class TeacherReportCardCommentRouteLoader extends StatefulWidget {
  const TeacherReportCardCommentRouteLoader({
    super.key,
    required this.resultId,
    required this.studentId,
  });

  final String resultId;
  final String studentId;

  @override
  State<TeacherReportCardCommentRouteLoader> createState() =>
      _TeacherReportCardCommentRouteLoaderState();
}

class _TeacherReportCardCommentRouteLoaderState
    extends State<TeacherReportCardCommentRouteLoader> {
  ReportCardRosterArgs? _rosterArgs;
  ReportCardStudentRow? _student;
  String? _error;
  var _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    final schoolClient = context.levit.find<SchoolClientFactory>();
    final target = await resolveReportCardCommentTarget(
      schoolClient(),
      resultId: widget.resultId,
      studentId: widget.studentId,
    );

    if (!mounted) {
      return;
    }

    setState(() {
      _loading = false;
      if (target == null) {
        _error = context.tr.reportCardNotFound;
      } else {
        _rosterArgs = target.rosterArgs;
        _student = target.student;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    if (_error != null || _rosterArgs == null || _student == null) {
      return Scaffold(
        body: RouteErrorPage(
          message: _error ?? context.tr.reportCardNotFound,
        ),
      );
    }

    return ReportCardCommentSheet(
      rosterArgs: _rosterArgs!,
      student: _student!,
    );
  }
}

Future<Map<String, String>> _subjectLabelsByClassSubject(
  SchoolClient client,
  Set<String> classSubjectIds,
) async {
  if (classSubjectIds.isEmpty) {
    return const {};
  }

  final rows = await client.classSubjects.list(entitiesByIds(classSubjectIds.toList()));
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
          subjectNameById[row['subjectId'] as String? ?? ''] ??
          systemL10n().subjectFallback,
  };
}
