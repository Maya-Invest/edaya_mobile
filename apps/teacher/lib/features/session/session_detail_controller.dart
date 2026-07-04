import 'dart:async';

import 'package:edaya_api_client/edaya_api_client.dart' as api;
import 'package:levit_flutter/levit_flutter.dart';

import 'package:edaya_shared/edaya_shared.dart';
import 'package:edaya_shared/src/l10n/l10n_lookup.dart';
import '../../common/utils/entity_filters.dart';
import '../calendar/models/teacher_session.dart';
import 'models/session_detail_models.dart';

class SessionDetailController extends LevitController
    with LevitReactiveTasksMixin {
  SessionDetailController({
    required this.session,
    required SchoolClientFactory schoolClient,
  }) : _schoolClient = schoolClient;

  final TeacherSession session;
  final SchoolClientFactory _schoolClient;

  final segment = LxVar(SessionDetailSegment.attendance);
  final students = LxVar<List<SessionStudentRow>>(const []);
  final logbook = LxVar<SessionLogbook?>(null);
  final subjectMatters = LxVar<List<SessionSubjectMatterOption>>(const []);
  final errorMessage = LxVar('');
  final saveMessage = LxVar('');

  @override
  void onInit() {
    super.onInit();
    autoDispose(segment);
    autoDispose(students);
    autoDispose(logbook);
    autoDispose(subjectMatters);
    autoDispose(errorMessage);
    autoDispose(saveMessage);
    unawaited(loadDetail());
  }

  int get recordedAttendanceCount =>
      students.value.where((row) => row.status != null).length;

  bool get supportsLogbook => session.kind == 'lesson';

  Future<void> loadDetail() async {
    errorMessage('');
    await runTask(() async {
      try {
        final client = _schoolClient();
        final enrollmentRows = await client.enrollments.list(
          activeEnrollmentsForClass(session.classGroupId),
        );
        final studentIds = enrollmentRows
            .map((row) => row['studentId'] as String?)
            .whereType<String>()
            .toList();
        final studentRows = studentIds.isEmpty
            ? <Map<String, dynamic>>[]
            : await client.students.list(entitiesByIds(studentIds));

        final attendanceRows = await listAttendanceForOccurrence(
          client.attendance,
          kind: session.kind,
          occurrenceId: session.id,
        );
        final attendanceByStudent = {
          for (final row in attendanceRows)
            row['studentId'] as String: row,
        };

        final roster = studentRows
            .map((row) {
              final studentId = row['id'] as String;
              final firstName = row['firstName'] as String? ?? '';
              final lastName = row['lastName'] as String? ?? '';
              final fullName = '$firstName $lastName'.trim();
              final attendance = attendanceByStudent[studentId];
              return SessionStudentRow(
                studentId: studentId,
                studentName: fullName.isEmpty ? studentId : fullName,
                studentInitials: _initials(fullName.isEmpty ? studentId : fullName),
                photoUrl: row['photoUrl'] as String?,
                attendanceId: attendance?['id'] as String?,
                status: SessionAttendanceStatus.fromApi(
                  attendance?['status'] as String?,
                ),
              );
            })
            .toList()
          ..sort((a, b) => a.studentName.compareTo(b.studentName));
        students(roster);

        if (!supportsLogbook || session.classSubjectId == null) {
          if (session.kind == 'activity') {
            try {
              final activitySession = await client.activitySessions.get(
                session.id,
              );
              final notes = activitySession['notes'] as String?;
              if (notes != null && notes.isNotEmpty) {
                logbook(
                  SessionLogbook(
                    id: session.id,
                    chapter: session.title,
                    content: notes,
                    objectives: const [],
                    progress: 0,
                  ),
                );
              } else {
                logbook(null);
              }
            } on Object {
              logbook(null);
            }
          } else {
            subjectMatters(const []);
            logbook(null);
          }
          return;
        }

        final matterLinks = await client.classSubjectMatters.list({
          'classSubjectId': session.classSubjectId,
        });
        final matterIds = matterLinks
            .map((row) => row['subjectMatterId'] as String?)
            .whereType<String>()
            .toList();
        final matters = matterIds.isEmpty
            ? <Map<String, dynamic>>[]
            : await client.subjectMatters.list(entitiesByIds(matterIds));
        final progressRows = await client.classSubjectProgress.list(
          progressForLessonSessions([session.id]),
        );
        final progressByMatterId = {
          for (final row in progressRows)
            row['classSubjectMatterId'] as String: row,
        };
        final matterNameById = {
          for (final matter in matters)
            matter['id'] as String:
                matter['name'] as String? ?? systemL10n().chapterFallback,
        };
        subjectMatters(
          matterLinks
              .map(
                (link) {
                  final linkId = link['id'] as String;
                  final progress = progressByMatterId[linkId];
                  return SessionSubjectMatterOption(
                    id: linkId,
                    name:
                        matterNameById[link['subjectMatterId'] as String] ??
                        systemL10n().chapterFallback,
                    completedPercentage:
                        (progress?['completedPercentage'] as num?)?.toInt() ??
                        (link['completedPercentage'] as num?)?.toInt() ??
                        0,
                  );
                },
              )
              .toList(),
        );

        final lessonSession = await client.lessonSessions.get(session.id);
        final sessionNote = lessonSession['sessionNote'] as String?;
        final primaryProgress = progressRows.isEmpty ? null : progressRows.first;
        if (sessionNote == null && primaryProgress == null) {
          logbook(null);
          return;
        }

        final matterLink = primaryProgress == null
            ? null
            : _firstMatterLink(
                matterLinks,
                primaryProgress['classSubjectMatterId'] as String?,
              );
        logbook(
          SessionLogbook(
            id: primaryProgress?['id'] as String? ?? session.id,
            chapter: matterLink?['id'] as String? ?? session.title,
            content: sessionNote ?? primaryProgress?['notes'] as String? ?? '',
            objectives: primaryProgress?['notes'] != null
                ? [primaryProgress!['notes'] as String]
                : const [],
            progress:
                (primaryProgress?['completedPercentage'] as num?)?.toInt() ?? 0,
          ),
        );
      } on api.ApiError catch (error) {
        errorMessage(systemL10n().couldNotLoadSession('$error'));
      } on Object catch (error) {
        errorMessage(systemL10n().couldNotLoadSession('$error'));
      }
    });
  }

  Future<bool> recordAttendance(
    SessionStudentRow row,
    SessionAttendanceStatus status,
  ) async {
    saveMessage('');
    try {
      final client = _schoolClient();
      final attendanceId = row.attendanceId ?? '${row.studentId}-${session.id}';
      await client.recordAttendance(
        attendanceRecordPayload(
          kind: session.kind,
          occurrenceId: session.id,
          studentId: row.studentId,
          attendanceId: attendanceId,
          status: status.apiValue,
          createdAt: DateTime.now().toUtc().toIso8601String(),
        ),
      );
      students(
        students.value
            .map(
              (entry) => entry.studentId == row.studentId
                  ? entry.copyWith(
                      attendanceId: attendanceId,
                      status: status,
                    )
                  : entry,
            )
            .toList(),
      );
      return true;
    } on Object catch (error) {
      saveMessage(systemL10n().couldNotSaveAttendance('$error'));
      return false;
    }
  }

  Future<bool> saveLogbook({
    required String classSubjectMatterId,
    required String chapter,
    required String content,
    required List<String> objectives,
    required int progress,
    String? homework,
  }) async {
    if (!supportsLogbook || session.classSubjectId == null) {
      return false;
    }

    saveMessage('');
    try {
      final client = _schoolClient();
      final progressId =
          logbook.value?.id ??
          'csp-${session.id}-${DateTime.now().millisecondsSinceEpoch}';

      final lessonSession = await client.lessonSessions.get(session.id);
      await client.lessonSessions.save({
        ...lessonSession,
        'displayLabel':
            lessonSession['displayLabel'] as String? ?? session.title,
        'sessionNote': content.trim().isEmpty ? null : content.trim(),
      });
      await client.recordLessonSessionProgress({
        'id': progressId,
        'classSubjectMatterId': classSubjectMatterId,
        'lessonSessionId': session.id,
        'completedPercentage': progress,
        'notes': objectives.join('\n').trim().isEmpty
            ? null
            : objectives.join('\n').trim(),
        'recordedAt': DateTime.now().toUtc().toIso8601String(),
      });

      logbook(
        SessionLogbook(
          id: progressId,
          chapter: chapter.trim(),
          content: content.trim(),
          objectives: objectives,
          homework: homework?.trim().isEmpty ?? true ? null : homework?.trim(),
          progress: progress,
        ),
      );
      return true;
    } on Object catch (error) {
      saveMessage(systemL10n().couldNotSaveLogbook('$error'));
      return false;
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
}

enum SessionDetailSegment { attendance, logbook }

Map<String, dynamic>? _firstMatterLink(
  List<Map<String, dynamic>> matterLinks,
  String? matterId,
) {
  if (matterId == null) {
    return null;
  }
  for (final link in matterLinks) {
    if (link['id'] == matterId) {
      return link;
    }
  }
  return null;
}
