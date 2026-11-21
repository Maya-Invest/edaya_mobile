import 'dart:async';

import 'package:edaya_api_client/edaya_api_client.dart' as api;
import 'package:edaya_shared/edaya_shared.dart';
import 'package:levit_flutter/levit_flutter.dart';

import '../context/student_context_controller.dart';
import '../context/academic_year_controller.dart';
import 'models/attendance_record.dart';
import 'models/calendar_session.dart';
import 'models/logbook_entry.dart';

/// Resolves a timetable occurrence by path id and loads attendance + logbook.
class SessionDetailController extends LevitController
    with LevitReactiveTasksMixin {
  SessionDetailController({
    required this.sessionId,
    this.kindHint,
    required this.academicYear,
    required StudentContextController studentContext,
    required SchoolClientFactory schoolClient,
  }) : _studentContext = studentContext,
       _schoolClient = schoolClient;

  int _loadGeneration = 0;
  final AcademicYearController academicYear;
  GuardianPupilSelection? _selection;
  Completer<void>? _abort;

  @override
  void onClose() {
    _loadGeneration++;
    _abort?.complete();
    super.onClose();
  }

  final String sessionId;
  final String? kindHint;
  final StudentContextController _studentContext;
  final SchoolClientFactory _schoolClient;

  final session = LxVar<CalendarSession?>(null);
  final attendance = LxVar<AttendanceRecord?>(null);
  final logbook = LxVar<LogbookEntry?>(null);
  final assessmentTitle = LxVar<String?>(null);
  final assessmentDescription = LxVar<String?>(null);
  final assessmentInstructions = LxVar<String?>(null);
  final assessmentMark = LxVar<Map<String, dynamic>?>(null);
  final assessmentMaxScore = LxVar<double?>(null);
  final assessmentCoefficient = LxVar<double?>(null);
  final activityNotes = LxVar<String?>(null);
  final errorMessage = LxVar('');

  @override
  void onInit() {
    super.onInit();
    autoDispose(session);
    autoDispose(attendance);
    autoDispose(logbook);
    autoDispose(assessmentTitle);
    autoDispose(assessmentDescription);
    autoDispose(assessmentInstructions);
    autoDispose(assessmentMark);
    autoDispose(assessmentMaxScore);
    autoDispose(assessmentCoefficient);
    autoDispose(activityNotes);
    autoDispose(errorMessage);
    for (final stream in [
      _studentContext.activeStudent.stream,
      _studentContext.isLoading.stream,
      academicYear.selectedYearId.stream,
    ]) {
      autoDispose(stream.listen((_) => unawaited(_onSelection())));
    }
    unawaited(_onSelection());
  }

  Future<void> _onSelection() async {
    if (_selection != _studentContext.verifiedSelection) await loadDetails();
  }

  Future<void> loadDetails() async {
    if (isClosed) return;
    final selection = _studentContext.verifiedSelection;
    _selection = selection;
    _abort?.complete();
    _abort = null;
    final generation = ++_loadGeneration;
    bool isCurrent() =>
        !isClosed &&
        generation == _loadGeneration &&
        selection == _studentContext.verifiedSelection;
    session(null);
    attendance(null);
    logbook(null);
    assessmentTitle(null);
    assessmentDescription(null);
    assessmentInstructions(null);
    assessmentMark(null);
    assessmentMaxScore(null);
    assessmentCoefficient(null);
    activityNotes(null);
    errorMessage('');
    if (selection == null) return;
    final abort = _abort = Completer<void>();
    await runTask(() async {
      try {
        final data = await _schoolClient().getGuardianOccurrenceDetail({
          'studentId': selection.studentId,
          'academicYearId': selection.academicYearId,
          'occurrenceId': sessionId,
          if (const {'lesson', 'assessment', 'activity'}.contains(kindHint))
            'kind': kindHint,
        }, abortTrigger: abort.future);
        if (!isCurrent()) return;
        final row = data['occurrence'] as Map<String, dynamic>?;
        if (row == null) {
          errorMessage(systemL10n().sessionNotFound);
          return;
        }
        if (row['id'] != sessionId) {
          throw const FormatException('Unexpected calendar occurrence');
        }
        final resolved = CalendarSession(
          id: sessionId,
          kind: row['kind'] as String,
          title: row['title'] as String,
          startsAt: parseApiDateTime(row['startsAt'])!,
          endsAt: parseApiDateTime(row['endsAt'])!,
          classSubjectId: row['classSubjectId'] as String?,
          subjectLabel: row['subjectLabel'] as String?,
          status: row['status'] as String?,
        );
        final record = row['attendance'] as Map<String, dynamic>?;
        final note = row['logbook'] as Map<String, dynamic>?;
        final assessment = row['assessment'] as Map<String, dynamic>?;
        if (record != null) attendance(AttendanceRecord.fromJson(record));
        if (note != null) {
          logbook(
            LogbookEntry(
              id: sessionId,
              chapter: resolved.title,
              date: resolved.startsAt,
              content: note['content'] as String,
              chapters: [
                for (final chapter
                    in (note['chapters'] as List).cast<Map<String, dynamic>>())
                  (
                    name:
                        chapter['name'] as String? ??
                        systemL10n().chapterFallback,
                    completed: chapter['completed'] as bool?,
                    notes: chapter['notes'] as String?,
                  ),
              ],
            ),
          );
        }
        if (assessment != null) {
          assessmentTitle(resolved.title);
          assessmentDescription(assessment['description'] as String? ?? '');
          assessmentInstructions('');
          assessmentMaxScore((assessment['maxScore'] as num).toDouble());
          assessmentCoefficient((assessment['coefficient'] as num).toDouble());
          assessmentMark(assessment['mark'] as Map<String, dynamic>?);
        }
        activityNotes(row['activityNotes'] as String?);
        session(resolved);
      } on Object catch (error) {
        if (!isCurrent()) return;
        errorMessage(systemL10n().couldNotLoadSessionDetails(error.toString()));
      } finally {
        if (identical(_abort, abort)) _abort = null;
      }
    }, id: 'load-session-details:$generation');
  }
}

class AttendanceListController extends LevitController
    with LevitReactiveTasksMixin {
  AttendanceListController({
    required StudentContextController studentContext,
    required SchoolClientFactory schoolClient,
  }) : _studentContext = studentContext,
       _schoolClient = schoolClient;

  final StudentContextController _studentContext;
  final SchoolClientFactory _schoolClient;

  final records = LxVar<List<AttendanceRecord>>(const []);
  final sessionTitles = LxVar<Map<String, String>>(const {});
  final errorMessage = LxVar('');

  @override
  void onInit() {
    super.onInit();
    autoDispose(records);
    autoDispose(sessionTitles);
    autoDispose(errorMessage);
    unawaited(loadAttendance());
  }

  Future<void> loadAttendance() async {
    final studentId = _studentContext.activeStudentId;
    if (studentId == null) {
      return;
    }

    await runTask(() async {
      try {
        final client = _schoolClient();
        final rows = await client.attendance.listAll(studentScope(studentId));
        final parsed = rows.map(AttendanceRecord.fromJson).toList()
          ..sort((a, b) => b.date.compareTo(a.date));
        records(parsed);

        final sessionIds = parsed.map((record) => record.occurrenceId).toSet();
        final titles = <String, String>{};
        for (final occurrenceId in sessionIds) {
          final record = parsed.firstWhere(
            (entry) => entry.occurrenceId == occurrenceId,
          );
          try {
            titles[occurrenceId] = await _resolveOccurrenceTitle(
              client,
              occurrenceId: occurrenceId,
              kind: record.occurrenceKind,
            );
          } on Object {
            titles[occurrenceId] = occurrenceId;
          }
        }
        sessionTitles(titles);
      } on Object catch (error) {
        errorMessage(systemL10n().couldNotLoadAttendance(error.toString()));
        records(const []);
      }
    }, id: 'load-attendance-list');
  }
}

/// alias used by attendance_page.dart.
typedef AttendanceController = AttendanceListController;

Future<String> _resolveOccurrenceTitle(
  api.SchoolClient client, {
  required String occurrenceId,
  required String kind,
}) async {
  switch (kind) {
    case 'daily':
      return systemL10n().dailyAttendance;
    case 'activity':
      try {
        final session = await client.activitySessions.get(occurrenceId);
        return session['displayLabel'] as String? ??
            session['title'] as String? ??
            occurrenceId;
      } on api.ApiError catch (error) {
        if (error.status != 404) rethrow;
      }
      return occurrenceId;
    case 'assessment':
      final assessment = await client.assessments.get(occurrenceId);
      return assessment['title'] as String? ?? occurrenceId;
    default:
      try {
        final session = await client.lessonSessions.get(occurrenceId);
        return session['displayLabel'] as String? ??
            session['title'] as String? ??
            occurrenceId;
      } on api.ApiError catch (error) {
        if (error.status != 404) rethrow;
      }
      return occurrenceId;
  }
}
