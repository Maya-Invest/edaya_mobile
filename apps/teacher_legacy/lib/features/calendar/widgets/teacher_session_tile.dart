import 'package:flutter/material.dart';

import 'package:edaya_shared/edaya_shared.dart';
import '../calendar_today_logic.dart';
import '../models/teacher_session.dart';

class TeacherSessionTile extends StatelessWidget {
  const TeacherSessionTile({
    super.key,
    required this.session,
    required this.onTap,
    this.completion,
  });

  final TeacherSession session;
  final VoidCallback onTap;
  final SessionAttendanceCompletion? completion;

  @override
  Widget build(BuildContext context) {
    Widget? statusBadge;
    if (session.kind == 'lesson' && completion != null) {
      statusBadge = StatusBadge(
        label: completion!.isComplete
            ? context.tr.sessionAttendanceComplete
            : context.tr.sessionAttendanceIncomplete,
        icon: completion!.isComplete
            ? Icons.check_circle_outline
            : Icons.pending_outlined,
        tone: completion!.isComplete
            ? StatusBadgeTone.success
            : StatusBadgeTone.warning,
      );
    }

    return SessionCard(
      title: session.title,
      subtitle:
          '${session.classLabel} · ${session.subjectLabel}\n'
          '${timetableSessionKindLabel(context.tr, session.kind)} · '
          '${context.tr.timeRange(context.formatTimeOfDay(session.startsAt), context.formatTimeOfDay(session.endsAt))}',
      onTap: onTap,
      statusBadge: statusBadge,
    );
  }
}
