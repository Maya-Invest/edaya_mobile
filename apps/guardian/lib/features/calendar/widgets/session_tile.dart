import 'package:flutter/material.dart';

import 'package:edaya_shared/edaya_shared.dart';
import '../models/calendar_session.dart';

class SessionTile extends StatelessWidget {
  const SessionTile({
    super.key,
    required this.session,
    required this.onTap,
  });

  final CalendarSession session;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        onTap: onTap,
        title: Text(session.subjectLabel ?? session.title),
        subtitle: Text(
          [
            timetableSessionKindLabel(context.tr, session.kind),
            context.tr.timeRange(
              context.formatTimeOfDay(session.startsAt),
              context.formatTimeOfDay(session.endsAt),
            ),
          ].join(' · '),
        ),
        trailing: const Icon(Icons.chevron_right),
      ),
    );
  }
}
