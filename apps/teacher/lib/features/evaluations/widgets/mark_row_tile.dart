import 'package:edaya_shared/edaya_shared.dart';
import 'package:flutter/material.dart';

import '../models/evaluation_models.dart';

class MarkRowTile extends StatelessWidget {
  const MarkRowTile({
    super.key,
    required this.row,
    required this.maxScore,
    required this.controller,
    required this.onSubmitted,
    this.focusNode,
  });

  final StudentMarkRow row;
  final double maxScore;
  final TextEditingController controller;
  final ValueChanged<double> onSubmitted;
  final FocusNode? focusNode;

  @override
  Widget build(BuildContext context) {
    final lockedLabel = context.tr.marksLockedReportCardPublished;

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
        child: Row(
          children: [
            PersonAvatar(
              name: row.studentName,
              initials: row.studentInitials ?? '?',
              photoUrl: row.photoUrl,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(row.studentName),
                  if (row.marksLocked)
                    Text(
                      lockedLabel,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                        fontSize: 12,
                      ),
                    ),
                ],
              ),
            ),
            if (row.syncState != MarkSyncState.synced) ...[
              SyncIndicator(
                status: row.syncState == MarkSyncState.pending
                    ? EdayaSyncStatus.pending
                    : EdayaSyncStatus.failed,
                compact: true,
              ),
              const SizedBox(width: 8),
            ],
            SizedBox(
              width: 88,
              child: TextField(
                controller: controller,
                focusNode: focusNode,
                enabled: !row.marksLocked,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                textInputAction: TextInputAction.next,
                decoration: InputDecoration(
                  isDense: true,
                  hintText: context.tr.notRecorded,
                  border: const OutlineInputBorder(),
                ),
                onSubmitted: (value) {
                  final parsed = double.tryParse(value.trim());
                  if (parsed == null) {
                    return;
                  }
                  if (parsed < 0 || parsed > maxScore) {
                    return;
                  }
                  onSubmitted(parsed);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
