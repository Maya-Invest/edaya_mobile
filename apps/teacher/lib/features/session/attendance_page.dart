import 'roll_call.dart';
import 'package:edaya_shared/edaya_shared.dart' hide PersonAvatar;
import 'package:flutter/material.dart';
import 'package:levit_flutter/levit_flutter.dart';

import '../../design/components/components.dart';
import '../../live/runtime.dart';
import '../../mock/mock_store.dart';
import '../calendar/live_calendar_controller.dart';
import '../context/academic_year_controller.dart';
import '../context/teacher_context_controller.dart';
import 'live_session_controller.dart';

LiveSessionController putLiveSessionController(
  LevitScope scope,
  String sessionId,
) {
  return scope.put(
    () => LiveSessionController(
      sessionId: sessionId,
      calendar: scope.find<LiveCalendarController>()..start(),
      academicYear: scope.find<AcademicYearController>(),
      schoolClient: scope.find<SchoolClientFactory>(),
      outboxStore: scope.find<TeacherOutboxStore>(),
      teacherContext: scope.find<TeacherContextController>(),
      schoolId: () => scope.find<AppSessionController>().grants.value?.schoolId,
      outboxContext: () => teacherOutboxContextForSession(
        session: scope.find<AppSessionController>(),
        academicYearId: scope
            .find<AcademicYearController>()
            .selectedYearId
            .value,
      ),
    ),
  );
}

class AttendancePage extends StatelessWidget {
  const AttendancePage({super.key, required this.sessionId});
  final String sessionId;

  @override
  Widget build(BuildContext context) {
    if (!prototypeIsLive(context)) {
      final store = context.levit.find<MockStore>();
      final session = store.sessionById(sessionId)!;
      return ListenableBuilder(
        listenable: store,
        builder: (_, _) => RollCall(
          rows: [
            for (final r in store.getAttendance(sessionId))
              if (store.studentById(r.studentId) case final student?)
                LiveSessionStudent(
                  studentId: r.studentId,
                  fullName: student.fullName,
                  initials: student.initials,
                  photoUrl: student.photoUrl,
                  status: r.status,
                  reason: r.comment,
                ),
          ],
          busy: false,
          pending: false,
          submitted: session.attendanceComplete,
          message: '',
          windowOpen: false,
          schoolTime: (v) => v.toLocal(),
          onSync: () async {},
          onMove: (_, _) async => false,
          onBulk: () async => store.markAllPresent(sessionId),
          onFinish: () async => store.completeAttendance(sessionId),
          onSave: (row, status, comment, reason) async {
            if (session.attendanceComplete) return false;
            store.setAttendanceStatus(
              sessionId,
              row.studentId,
              status,
              comment: comment,
            );
            return true;
          },
        ),
      );
    }
    final c = context.levit.find<LiveSessionController>();
    return LWatch(() {
      if (c.attendanceError.value.isNotEmpty)
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(c.attendanceError.value),
              TextButton(onPressed: c.load, child: Text(context.tr.retry)),
            ],
          ),
        );
      if (!c.supportsAttendanceRecording)
        return EmptyState(
          title: context.tr.attendance,
          message: context.tr.attendanceRecordingLessonOnly,
        );
      return RollCall(
        rows: c.students.value,
        submitted: c.attendanceSubmitted.value,
        busy: c.isBusy.value,
        savingDraft: c.draftWrites.writing.value,
        message: c.saveMessage.value,
        pending: c.draftPending.value,
        conflict: c.draftConflict.value,
        windowOpen: c.arrivalWindowActive,
        onBulk: c.markAllPresent,
        onFinish: c.completeAttendance,
        onSync: c.retryAttendanceDraft,
        schoolTime: c.schoolTime,
        onMove: (row, departure) => departure
            ? c.recordDeparture(row.studentId)
            : c.recordArrival(row.studentId),
        onSave: (row, status, comment, reason) async {
          if (reason != null) {
            await c.requestAttendanceCorrection(
              row.studentId,
              status,
              reason,
              teacherExplanation: comment,
            );
            return c.saveMessage.value ==
                    systemL10n().workflowCorrectionPending ||
                c.saveMessage.value == systemL10n().attendanceSavedLocally;
          }
          return c.setAttendanceStatus(row.studentId, status, reason: comment);
        },
      );
    });
  }
}
