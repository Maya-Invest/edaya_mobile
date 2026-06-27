import 'package:flutter/material.dart';

import '../../../common/utils/date_time_parse.dart';
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
          '${formatTimeOfDay(session.startsAt)} – ${formatTimeOfDay(session.endsAt)}',
        ),
        isThreeLine: true,
        trailing: const Icon(Icons.chevron_right),
      ),
    );
  }
}
