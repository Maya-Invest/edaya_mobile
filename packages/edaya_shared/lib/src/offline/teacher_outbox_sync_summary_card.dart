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
    this.conflicts = const [],
    this.onDiscardConflict,
  });

  final TeacherOutboxSummary summary;
  final bool isSyncing;
  final VoidCallback? onSyncNow;
  final List<TeacherOutboxEntry> conflicts;
  final Future<void> Function(String id)? onDiscardConflict;

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
            if (conflicts.isNotEmpty) ...[
              Text(
                context.tr.outboxConflictTitle,
                style: theme.textTheme.titleSmall,
              ),
              Text(context.tr.mutationConflict),
              for (final entry in conflicts)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    '${entry.kind.name} · ${entry.payload['studentId'] ?? entry.payload['id'] ?? ''}',
                  ),
                  subtitle: Text(
                    entry.kind == TeacherOutboxKind.mark
                        ? '${entry.payload['designation'] ?? '—'} · ${entry.payload['score'] ?? '—'}'
                        : _commentPreview(entry.payload),
                  ),
                  trailing: onDiscardConflict == null
                      ? null
                      : IconButton(
                          icon: const Icon(Icons.delete_outline),
                          tooltip: context.tr.outboxDiscardEdit,
                          onPressed: isSyncing
                              ? null
                              : () async {
                                  final discard = await showDialog<bool>(
                                    context: context,
                                    builder: (dialogContext) => AlertDialog(
                                      title: Text(context.tr.outboxDiscardEdit),
                                      content: Text(
                                        context.tr.outboxDiscardConfirm,
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed: () => Navigator.pop(
                                            dialogContext,
                                            false,
                                          ),
                                          child: Text(context.tr.cancel),
                                        ),
                                        TextButton(
                                          onPressed: () => Navigator.pop(
                                            dialogContext,
                                            true,
                                          ),
                                          child: Text(
                                            context.tr.outboxDiscardEdit,
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                  if (discard == true) {
                                    await onDiscardConflict!(entry.id);
                                  }
                                },
                        ),
                ),
            ],
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

String _commentPreview(Map<String, dynamic> payload) {
  final texts = <String>[];
  final homeroom = payload['homeroom'];
  if (homeroom is Map && homeroom['teacherComment'] is String) {
    texts.add(homeroom['teacherComment'] as String);
  }
  final sections = payload['sections'];
  if (sections is Map && sections['sections'] is List) {
    for (final section in sections['sections'] as List) {
      if (section is Map && section['comment'] is String) {
        texts.add(section['comment'] as String);
      }
    }
  }
  final body = payload['body'];
  if (body is Map && body['teacherComment'] is String) {
    texts.add(body['teacherComment'] as String);
  }
  return texts.join('\n');
}
