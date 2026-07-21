import 'package:flutter/material.dart';

enum EdayaSyncStatus {
  saved,
  savedLocally,
  pending,
  syncing,
  synced,
  failed,
}

class StatusBadge extends StatelessWidget {
  const StatusBadge({
    super.key,
    required this.label,
    this.icon,
    this.tone = StatusBadgeTone.neutral,
  });

  final String label;
  final IconData? icon;
  final StatusBadgeTone tone;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = switch (tone) {
      StatusBadgeTone.success => (
        background: theme.colorScheme.primaryContainer,
        foreground: theme.colorScheme.onPrimaryContainer,
      ),
      StatusBadgeTone.warning => (
        background: theme.colorScheme.tertiaryContainer,
        foreground: theme.colorScheme.onTertiaryContainer,
      ),
      StatusBadgeTone.error => (
        background: theme.colorScheme.errorContainer,
        foreground: theme.colorScheme.onErrorContainer,
      ),
      StatusBadgeTone.neutral => (
        background: theme.colorScheme.surfaceContainerHighest,
        foreground: theme.colorScheme.onSurfaceVariant,
      ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: colors.background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: colors.foreground),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: theme.textTheme.labelMedium?.copyWith(
              color: colors.foreground,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

enum StatusBadgeTone { neutral, success, warning, error }
