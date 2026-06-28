import 'package:edaya_ui/edaya_ui.dart';
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
        subtitle: Text(row.status?.label ?? 'Not recorded'),
        trailing: TextButton(
          onPressed: onStatusTap,
          child: Text(row.status == null ? 'Record' : 'Edit'),
        ),
        textColor: statusColor,
      ),
    );
  }
}
