import 'package:edaya_shared/edaya_shared.dart';
import 'package:flutter/material.dart';

import '../models/session_detail_models.dart';

class AttendanceRowTile extends StatelessWidget {
  const AttendanceRowTile({
    super.key,
    required this.row,
    required this.onStatusTap,
  });

  final SessionStudentRow row;
  final VoidCallback onStatusTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final statusColor = switch (row.status) {
      SessionAttendanceStatus.present => colorScheme.primary,
      SessionAttendanceStatus.absent => colorScheme.error,
      SessionAttendanceStatus.late => colorScheme.tertiary,
      null => colorScheme.onSurfaceVariant,
    };

    return Card(
      child: ListTile(
        leading: PersonAvatar(
          name: row.studentName,
          initials: row.studentInitials,
          photoUrl: row.photoUrl,
        ),
        title: Text(row.studentName),
        subtitle: Text(
          row.status?.label(context.tr) ?? context.tr.notRecorded,
        ),
        trailing: FilledButton.tonal(
          style: FilledButton.styleFrom(
            minimumSize: const Size(88, 44),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            textStyle: Theme.of(context).textTheme.labelLarge,
          ),
          onPressed: onStatusTap,
          child: Text(
            row.status == null ? context.tr.record : context.tr.edit,
          ),
        ),
        textColor: statusColor,
      ),
    );
  }
}
