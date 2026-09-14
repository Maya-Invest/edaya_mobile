import 'package:edaya_shared/edaya_shared.dart';
import 'package:flutter/material.dart';

import '../models/evaluation_models.dart';

class MarkRowTile extends StatelessWidget {
  const MarkRowTile({super.key, required this.row, required this.onEditScore});

  final StudentMarkRow row;
  final VoidCallback onEditScore;

  @override
  Widget build(BuildContext context) {
    final scoreLabel = row.marksLocked
        ? context.tr.marksLockedReportCardPublished
        : row.score == null
        ? context.tr.notRecorded
        : context.tr.currentScore(row.score.toString());

    return Card(
      child: ListTile(
        leading: PersonAvatar(
          name: row.studentName,
          initials: row.studentInitials ?? '?',
          photoUrl: row.photoUrl,
        ),
        title: Text(row.studentName),
        subtitle: Text(
          scoreLabel,
          style: row.marksLocked
              ? TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)
              : null,
        ),
        trailing: FilledButton.tonal(
          style: FilledButton.styleFrom(
            minimumSize: const Size(88, 44),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            textStyle: Theme.of(context).textTheme.labelLarge,
          ),
          onPressed: row.marksLocked ? null : onEditScore,
          child: Text(row.score == null ? context.tr.record : context.tr.edit),
        ),
      ),
    );
  }
}
