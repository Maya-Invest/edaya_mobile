import 'package:flutter/material.dart';

import '../l10n/l10n_extension.dart';
import '../ui/status_badge.dart';
import '../ui/sync_indicator.dart';
import 'teacher_outbox_models.dart';

class TeacherOutboxSyncSummaryCard extends StatelessWidget {
  const TeacherOutboxSyncSummaryCard({
    super.key,
    required this.summary,
    required this.isSyncing,
    this.onSyncNow,
  });

  final TeacherOutboxSummary summary;
  final bool isSyncing;
  final VoidCallback? onSyncNow;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              context.tr.accountSyncSectionTitle,
              style: theme.textTheme.titleSmall,
            ),
            const SizedBox(height: 12),
            if (summary.hasPending) ...[
              SyncIndicator(
                status: isSyncing
                    ? EdayaSyncStatus.syncing
                    : EdayaSyncStatus.pending,
              ),
              const SizedBox(height: 8),
              Text(context.tr.accountPendingSyncSummary(summary.pendingCount)),
              if (summary.oldestPendingAt != null) ...[
                const SizedBox(height: 4),
                Text(
                  context.tr.accountPendingSyncOldest(
                    formatTeacherOutboxPendingAge(
                      oldestPendingAt: summary.oldestPendingAt!,
                      now: DateTime.now(),
                      justNow: () => context.tr.accountPendingSyncJustNow,
                      minutesAgo: context.tr.accountPendingSyncMinutes,
                      hoursAgo: context.tr.accountPendingSyncHours,
                      daysAgo: context.tr.accountPendingSyncDays,
                    ),
                  ),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
              if (onSyncNow != null) ...[
                const SizedBox(height: 12),
                FilledButton.tonal(
                  onPressed: isSyncing ? null : onSyncNow,
                  child: isSyncing
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(context.tr.accountSyncNow),
                ),
              ],
            ] else
              Row(
                children: [
                  const SyncIndicator(
                    status: EdayaSyncStatus.synced,
                    compact: true,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      context.tr.accountPendingSyncNone,
                      style: theme.textTheme.bodyMedium,
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
