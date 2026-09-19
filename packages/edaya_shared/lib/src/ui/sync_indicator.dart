import 'package:flutter/material.dart';

import '../l10n/l10n_extension.dart';
import 'status_badge.dart';

class SyncIndicator extends StatelessWidget {
  const SyncIndicator({
    super.key,
    required this.status,
    this.compact = false,
  });

  final EdayaSyncStatus status;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final label = _label(context);
    final tone = switch (status) {
      EdayaSyncStatus.saved ||
      EdayaSyncStatus.synced => StatusBadgeTone.success,
      EdayaSyncStatus.savedLocally ||
      EdayaSyncStatus.pending => StatusBadgeTone.warning,
      EdayaSyncStatus.syncing => StatusBadgeTone.neutral,
      EdayaSyncStatus.failed => StatusBadgeTone.error,
    };
    final icon = switch (status) {
      EdayaSyncStatus.saved || EdayaSyncStatus.synced => Icons.cloud_done_outlined,
      EdayaSyncStatus.savedLocally => Icons.save_outlined,
      EdayaSyncStatus.pending => Icons.schedule_outlined,
      EdayaSyncStatus.syncing => Icons.cloud_upload_outlined,
      EdayaSyncStatus.failed => Icons.error_outline,
    };

    if (compact) {
      return Semantics(
        label: label,
        child: Icon(icon, size: 18),
      );
    }

    return StatusBadge(label: label, icon: icon, tone: tone);
  }

  String _label(BuildContext context) {
    return switch (status) {
      EdayaSyncStatus.saved => context.tr.syncStatusSaved,
      EdayaSyncStatus.savedLocally => context.tr.syncStatusSavedLocally,
      EdayaSyncStatus.pending => context.tr.syncStatusPending,
      EdayaSyncStatus.syncing => context.tr.syncStatusSyncing,
      EdayaSyncStatus.synced => context.tr.syncStatusSynced,
      EdayaSyncStatus.failed => context.tr.syncStatusFailed,
    };
  }
}
