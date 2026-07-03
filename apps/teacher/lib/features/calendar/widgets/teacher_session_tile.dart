import 'package:flutter/material.dart';

import 'package:edaya_shared/edaya_shared.dart';
import '../models/teacher_session.dart';

class TeacherSessionTile extends StatelessWidget {
  const TeacherSessionTile({
    super.key,
    required this.session,
    required this.onTap,
  });

  final TeacherSession session;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        onTap: onTap,
        title: Text(session.title),
        subtitle: Text(
          '${session.classLabel} · ${session.subjectLabel}\n'
          '${timetableSessionKindLabel(context.tr, session.kind)} · '
          '${context.tr.timeRange(context.formatTimeOfDay(session.startsAt), context.formatTimeOfDay(session.endsAt))}',
        ),
        isThreeLine: true,
        trailing: const Icon(Icons.chevron_right),
      ),
    );
  }
}
