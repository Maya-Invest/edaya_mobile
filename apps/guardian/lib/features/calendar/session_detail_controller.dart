import 'dart:async';

import 'package:edaya_api_client/edaya_api_client.dart' as api;
import 'package:edaya_api_client/edaya_api_client.dart' show SchoolClient;
import 'package:edaya_shared/edaya_shared.dart';
import 'package:levit_flutter/levit_flutter.dart';

import '../context/student_context_controller.dart';
import 'models/attendance_record.dart';
import 'models/calendar_session.dart';
import 'models/logbook_entry.dart';

/// Resolves a timetable occurrence by path id and loads attendance + logbook.
class SessionDetailController extends LevitController
    with LevitReactiveTasksMixin {
  SessionDetailController({
    required this.sessionId,
    required StudentContextController studentContext,
    required SchoolClientFactory schoolClient,
  }) : _studentContext = studentContext,
       _schoolClient = schoolClient;

  final String sessionId;
  final StudentContextController _studentContext;
  final SchoolClientFactory _schoolClient;

  final session = LxVar<CalendarSession?>(null);
  final attendance = LxVar<AttendanceRecord?>(null);
  final logbook = LxVar<LogbookEntry?>(null);
  final assessmentTitle = LxVar<String?>(null);
  final assessmentDescription = LxVar<String?>(null);
  final assessmentInstructions = LxVar<String?>(null);
  final assessmentMention = LxVar<String?>(null);
  final assessmentScore = LxVar<double?>(null);
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
    autoDispose(assessmentScore);
    autoDispose(assessmentMention);
    autoDispose(assessmentMaxScore);
    autoDispose(assessmentCoefficient);
    autoDispose(activityNotes);
    autoDispose(errorMessage);
    unawaited(loadDetails());
  }

  Future<void> loadDetails() async {
    await runTask(() async {
      try {
        final client = _schoolClient();
        final resolved = await _resolveSession(client);
        session(resolved);
        if (resolved == null) {
          errorMessage('Séance introuvable');
          return;
        }

        final studentId = _studentContext.activeStudentId;
        final classGroupId = _studentContext.classGroupId.value;
        if (studentId != null && classGroupId != null) {
          final attendanceRows = await client.attendance.list({
            ...attendanceForOccurrence(
              kind: resolved.kind,
              occurrenceId: resolved.id,
            ),
            'studentId': studentId,
          });
          attendance(
            attendanceRows.isEmpty
                ? null
                : AttendanceRecord.fromJson(attendanceRows.first),
          );
        }

        logbook(await _loadLogbook(client, resolved));

        if (resolved.kind == 'assessment') {
          await _loadAssessmentExtras(client, resolved);
        } else if (resolved.kind == 'activity') {
          await _loadActivityExtras(client, resolved);
        }
      } on Object catch (error) {
        errorMessage(systemL10n().couldNotLoadSessionDetails(error.toString()));
      }
    }, id: 'load-session-details');
  }

  Future<CalendarSession?> _resolveSession(SchoolClient client) async {
    try {
      final lesson = await client.lessonSessions.get(sessionId);
      return CalendarSession(
        id: lesson['id'] as String,
        title:
            lesson['displayLabel'] as String? ??
            lesson['title'] as String? ??
            'Cours',
        kind: 'lesson',
        startsAt: parseApiDateTime(lesson['startsAt']) ?? DateTime.now(),
        endsAt: parseApiDateTime(lesson['endsAt']) ?? DateTime.now(),
        classSubjectId: lesson['classSubjectId'] as String?,
        subjectLabel: lesson['displayLabel'] as String?,
        status: lesson['status'] as String?,
      );
    } on api.ApiError catch (error) {
      if (error.status != 404 && error.status != 403) rethrow;
    }

    try {
      final activity = await client.activitySessions.get(sessionId);
      return CalendarSession(
        id: activity['id'] as String,
        title:
            activity['displayLabel'] as String? ??
            activity['title'] as String? ??
            'Activité',
        kind: 'activity',
        startsAt: parseApiDateTime(activity['startsAt']) ?? DateTime.now(),
        endsAt: parseApiDateTime(activity['endsAt']) ?? DateTime.now(),
        status: activity['status'] as String?,
      );
    } on api.ApiError catch (error) {
      if (error.status != 404 && error.status != 403) rethrow;
    }

    try {
      final assessment = await client.assessments.get(sessionId);
      final startsAt =
          parseApiDateTime(
            assessment['startsAt'] ??
                assessment['dueAt'] ??
                assessment['date'] ??
                assessment['metAt'],
          ) ??
          DateTime.now();
      return CalendarSession(
        id: assessment['id'] as String,
        title: assessment['title'] as String? ?? 'Évaluation',
        kind: 'assessment',
        startsAt: startsAt,
        endsAt: startsAt.add(const Duration(hours: 1)),
        classSubjectId: assessment['classSubjectId'] as String?,
        status: assessment['status'] as String?,
      );
    } on api.ApiError catch (error) {
      if (error.status != 404 && error.status != 403) rethrow;
    }

    return null;
  }

  Future<void> _loadAssessmentExtras(
    SchoolClient client,
    CalendarSession resolved,
  ) async {
    try {
      final assessment = await client.assessments.get(resolved.id);
      assessmentTitle(assessment['title'] as String?);
      assessmentDescription(assessment['description'] as String? ?? '');
      assessmentInstructions(assessment['instructions'] as String? ?? '');
      assessmentMaxScore((assessment['maxScore'] as num?)?.toDouble());
      assessmentCoefficient((assessment['coefficient'] as num?)?.toDouble());

      final studentId = _studentContext.activeStudentId;
      if (studentId == null) return;
      final results = await client.assessmentResults.list({
        'studentId': studentId,
        'assessmentId': resolved.id,
      });
      if (results.isNotEmpty) {
        final entry = results.first['originalEntry'] as Map?;
        assessmentMention(
          entry?['kind'] == 'mention'
              ? '${entry!['code']} — ${entry['label']}'
              : null,
        );
        final rawScore = results.first['score'];
        assessmentScore(
          rawScore is num
              ? rawScore.toDouble()
              : double.tryParse(rawScore?.toString() ?? ''),
        );
      }
    } on Object {
      // Optional enrichment — leave fields null.
    }
  }

  Future<void> _loadActivityExtras(
    SchoolClient client,
    CalendarSession resolved,
  ) async {
    try {
      final activity = await client.activitySessions.get(resolved.id);
      activityNotes(activity['notes'] as String?);
    } on Object {
      // Optional.
    }
  }

  Future<LogbookEntry?> _loadLogbook(
    SchoolClient client,
    CalendarSession resolved,
  ) async {
    if (resolved.kind != 'lesson' || resolved.classSubjectId == null) {
      if (resolved.kind == 'activity') {
        final notes = activityNotes.value;
        if (notes == null || notes.isEmpty) return null;
        return LogbookEntry(
          id: resolved.id,
          chapter: resolved.title,
          content: notes,
          objectives: const [],
          progress: 0,
          date: resolved.startsAt,
        );
      }
      return null;
    }

    final progressRows = await client.classSubjectProgress.list(
      progressForLessonSessions([resolved.id]),
    );

    Map<String, dynamic>? lessonSession;
    try {
      lessonSession = await client.lessonSessions.get(resolved.id);
    } on api.ApiError catch (error) {
      if (error.status != 404 && error.status != 403) rethrow;
    }

    final sessionNote = lessonSession?['sessionNote'] as String?;
    final primaryProgress = progressRows.isEmpty ? null : progressRows.first;
    if (sessionNote == null && primaryProgress == null) {
      return null;
    }

    String chapter = resolved.title;
    if (primaryProgress != null) {
      try {
        final matterLinks = await client.classSubjectMatters.list({
          'classSubjectId': resolved.classSubjectId,
        });
        final matterLink = matterLinks.cast<Map<String, dynamic>>().where(
          (link) => link['id'] == primaryProgress['classSubjectMatterId'],
        );
        final subjectMatterId = matterLink.isEmpty
            ? null
            : matterLink.first['subjectMatterId'] as String?;
        if (subjectMatterId != null) {
          final subjectMatter = await client.subjectMatters.get(
            subjectMatterId,
          );
          chapter = subjectMatter['name'] as String? ?? chapter;
        }
      } on Object {
        chapter = resolved.title;
      }
    }

    return LogbookEntry(
      id: primaryProgress?['id'] as String? ?? resolved.id,
      chapter: chapter,
      content: decodeStructuredSessionNote(sessionNote).guardianText.isNotEmpty
          ? decodeStructuredSessionNote(sessionNote).guardianText
          : primaryProgress?['notes'] as String? ?? '',
      objectives: primaryProgress?['notes'] != null
          ? [primaryProgress!['notes'] as String]
          : const [],
      progress: (primaryProgress?['completedPercentage'] as num?)?.toInt() ?? 0,
      date: resolved.startsAt,
    );
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
        final rows = await client.attendance.list(studentScope(studentId));
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

/// Prototype alias used by attendance_page.dart.
typedef AttendanceController = AttendanceListController;

Future<String> _resolveOccurrenceTitle(
  SchoolClient client, {
  required String occurrenceId,
  required String kind,
}) async {
  switch (kind) {
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
