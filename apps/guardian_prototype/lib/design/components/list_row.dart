import 'package:flutter/material.dart';

import '../colors.dart';
import '../spacing.dart';
import 'status_chip.dart';
import 'surface_card.dart';

class ListRow extends StatelessWidget {
  const ListRow({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.trailing,
    this.badge,
    this.badgeTone,
    this.onTap,
    this.unread = false,
    this.tint,
  });

  final String title;
  final String? subtitle;
  final Widget? leading;
  final Widget? trailing;
  final String? badge;
  final SemanticTone? badgeTone;
  final VoidCallback? onTap;
  final bool unread;
  final Color? tint;

  @override
  Widget build(BuildContext context) {
    return SurfaceCard(
      onTap: onTap,
      tint: tint ??
          (unread ? PrototypeColors.primaryContainer.withValues(alpha: 0.35) : null),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (leading != null) ...[leading!, const SizedBox(width: PrototypeSpacing.sm)],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleSmall),
                if (subtitle != null) ...[
                  const SizedBox(height: 4),
                  Text(subtitle!, style: Theme.of(context).textTheme.bodySmall),
                ],
              ],
            ),
          ),
          if (badge != null || trailing != null) ...[
            const SizedBox(width: PrototypeSpacing.sm),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (badge != null)
                  StatusChip(
                    label: badge!,
                    tone: badgeTone ?? (unread ? SemanticTone.info : SemanticTone.neutral),
                  ),
                if (trailing != null) ...[
                  if (badge != null) const SizedBox(height: PrototypeSpacing.xs),
                  trailing!,
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }
}
