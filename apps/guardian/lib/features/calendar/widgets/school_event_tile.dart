import 'package:flutter/material.dart';

import '../models/school_event.dart';

class SchoolEventTile extends StatelessWidget {
  const SchoolEventTile({super.key, required this.event});

  final SchoolEvent event;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      child: ListTile(
        leading: Icon(
          event.isNonSchoolDay
              ? Icons.event_busy_outlined
              : Icons.event_outlined,
          color: event.isNonSchoolDay ? colorScheme.error : colorScheme.primary,
        ),
        title: Text(event.title),
        subtitle: Text(
          [
            event.kind,
            if (event.description != null && event.description!.isNotEmpty)
              event.description!,
          ].join(' · '),
        ),
      ),
    );
  }
}
