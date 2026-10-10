import 'package:flutter/material.dart';

import '../spacing.dart';
import 'surface_card.dart';

/// Visual tone for home attention CTAs (same layout, different surface).
enum AttentionTone {
  /// Urgent — error / red surface (e.g. overdue fees).
  important,

  /// Standard highlight — primary / blue surface (e.g. bulletin).
  normal,

  /// Inbox / new mail — white surface with tinted icon well.
  message,
}

/// Compact tappable attention row used on Accueil.
///
/// All tones share one layout (icon · title/subtitle · chevron). Surface color
/// comes from [tone] only — no oversized “hero” CTA variant.
class AttentionCard extends StatelessWidget {
  const AttentionCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.tone,
    this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final AttentionTone tone;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = _AttentionToneColors.resolve(
      tone,
      Theme.of(context).colorScheme,
    );
    final textTheme = Theme.of(context).textTheme;

    return SurfaceCard(
      onTap: onTap,
      tint: colors.surface,
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: colors.iconWell,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 20, color: colors.icon),
          ),
          const SizedBox(width: PrototypeSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: textTheme.titleSmall?.copyWith(color: colors.title),
                ),
                Text(subtitle, style: textTheme.bodySmall),
              ],
            ),
          ),
          Icon(
            Icons.chevron_right,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ],
      ),
    );
  }
}

class _AttentionToneColors {
  const _AttentionToneColors({
    required this.surface,
    required this.iconWell,
    required this.icon,
    required this.title,
  });

  final Color surface;
  final Color iconWell;
  final Color icon;
  final Color? title;

  static _AttentionToneColors resolve(AttentionTone tone, ColorScheme scheme) {
    return switch (tone) {
      AttentionTone.important => _AttentionToneColors(
        surface: scheme.errorContainer.withValues(alpha: 0.55),
        iconWell: scheme.surface,
        icon: scheme.error,
        title: scheme.error,
      ),
      AttentionTone.normal => _AttentionToneColors(
        surface: scheme.primaryContainer,
        iconWell: scheme.surface,
        icon: scheme.primary,
        title: null,
      ),
      AttentionTone.message => _AttentionToneColors(
        surface: scheme.surface,
        iconWell: scheme.primaryContainer,
        icon: scheme.primary,
        title: null,
      ),
    };
  }
}
