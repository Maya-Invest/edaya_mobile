import 'dart:async';

import 'package:edaya_api_client/edaya_api_client.dart' as api;
import 'package:levit_flutter/levit_flutter.dart';

import '../../access/app_runtime.dart';
import 'package:edaya_shared/edaya_shared.dart';
import '../../common/utils/entity_filters.dart';
import '../calendar/models/teacher_session.dart';
import 'models/session_detail_models.dart';

class SessionDetailController extends LevitController
    with LevitReactiveTasksMixin {
  SessionDetailController({required this.session});

  final TeacherSession session;

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

  Future<void> loadDetail() async {
    errorMessage('');
    await runTask(() async {
      try {
        final client = AppRuntime.schoolClient();
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

        final attendanceRows = await client.attendance.list(
          attendanceForSession(session.id),
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

        if (session.classSubjectId != null) {
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
          final matterNameById = {
            for (final matter in matters)
              matter['id'] as String: matter['name'] as String? ?? 'Chapter',
          };
          subjectMatters(
            matterLinks
                .map(
                  (link) => SessionSubjectMatterOption(
                    id: link['id'] as String,
                    name:
                        matterNameById[link['subjectMatterId'] as String] ??
                        'Chapter',
                    completedPercentage:
                        (link['completedPercentage'] as num?)?.toInt() ?? 0,
                  ),
                )
                .toList(),
          );

          final logbookRows = await client.classLogbookEntries.list(
            logbookForClassSubject(
              session.classGroupId,
              session.classSubjectId!,
            ),
          );
          final sessionDate = DateTime(
            session.startsAt.year,
            session.startsAt.month,
            session.startsAt.day,
          );
          SessionLogbook? matched;
          for (final row in logbookRows) {
            final date = parseApiDateTime(row['date']);
            if (date != null && isSameCalendarDay(date, sessionDate)) {
              matched = SessionLogbook.fromJson(row);
              break;
            }
          }
          logbook(matched);
        } else {
          subjectMatters(const []);
          logbook(null);
        }
      } on api.ApiError catch (error) {
        errorMessage('Could not load session: $error');
      } on Object catch (error) {
        errorMessage('Could not load session: $error');
      }
    });
  }

  Future<bool> recordAttendance(
    SessionStudentRow row,
    SessionAttendanceStatus status,
  ) async {
    saveMessage('');
    try {
      final client = AppRuntime.schoolClient();
      final attendanceId = row.attendanceId ?? '${row.studentId}-${session.id}';
      await client.recordAttendance({
        'id': attendanceId,
        'studentId': row.studentId,
        'sessionId': session.id,
        'status': status.apiValue,
        'createdAt': DateTime.now().toUtc().toIso8601String(),
      });
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
      saveMessage('Could not save attendance: $error');
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
    if (session.classSubjectId == null) {
      return false;
    }

    saveMessage('');
    try {
      final client = AppRuntime.schoolClient();
      final grants = AppRuntime.session.grants.value;
      final schoolId = grants?.schoolId;
      if (schoolId == null) {
        return false;
      }

      final entryId =
          logbook.value?.id ??
          'log-${session.id}-${DateTime.now().millisecondsSinceEpoch}';
      final sessionDate = DateTime(
        session.startsAt.year,
        session.startsAt.month,
        session.startsAt.day,
      );

      final saved = await client.classLogbookEntries.save({
        'id': entryId,
        'schoolId': schoolId,
        'classGroupId': session.classGroupId,
        'classSubjectId': session.classSubjectId,
        'date': sessionDate.toIso8601String().substring(0, 10),
        'chapter': chapter,
        'content': content,
        'objectives': objectives,
        if (homework != null && homework.isNotEmpty) 'homework': homework,
        'progress': progress,
      });
      logbook(SessionLogbook.fromJson(saved));
      return true;
    } on Object catch (error) {
      saveMessage('Could not save logbook: $error');
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
