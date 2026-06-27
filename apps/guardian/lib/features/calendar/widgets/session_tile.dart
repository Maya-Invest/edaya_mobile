import 'package:flutter/material.dart';

import '../../../common/utils/date_time_parse.dart';
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
        title: Text(session.title),
        subtitle: Text(
          '${formatTimeOfDay(session.startsAt)} – ${formatTimeOfDay(session.endsAt)}',
        ),
        trailing: const Icon(Icons.chevron_right),
      ),
    );
  }
}
