import 'package:flutter/material.dart';

import '../colors.dart';
import '../spacing.dart';

class StatusChip extends StatelessWidget {
  const StatusChip({
    super.key,
    required this.label,
    this.tone = SemanticTone.neutral,
    this.icon,
  });

  final String label;
  final SemanticTone tone;

  /// Overrides the default tone icon. Status is always icon + label + color.
  final IconData? icon;

  static IconData iconForTone(SemanticTone tone) {
    return switch (tone) {
      SemanticTone.neutral => Icons.circle_outlined,
      SemanticTone.info => Icons.info_outline,
      SemanticTone.success => Icons.check_circle_outline,
      SemanticTone.warning => Icons.schedule,
      SemanticTone.error => Icons.error_outline,
    };
  }

  @override
  Widget build(BuildContext context) {
    final colors = tone.resolve(Theme.of(context).colorScheme);
    final resolvedIcon = icon ?? iconForTone(tone);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: colors.$1,
        borderRadius: BorderRadius.circular(PrototypeRadii.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(resolvedIcon, size: 12, color: colors.$2),
          const SizedBox(width: 4),
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: colors.$2,
                  fontWeight: FontWeight.w600,
                ),
          ),
        ],
      ),
    );
  }
}
