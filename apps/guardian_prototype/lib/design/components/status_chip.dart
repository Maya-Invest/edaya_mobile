import 'package:flutter/material.dart';

import '../colors.dart';
import '../spacing.dart';

class StatusChip extends StatelessWidget {
  const StatusChip({super.key, required this.label, this.tone = SemanticTone.neutral});

  final String label;
  final SemanticTone tone;

  @override
  Widget build(BuildContext context) {
    final colors = tone.resolve(Theme.of(context).colorScheme);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: colors.$1,
        borderRadius: BorderRadius.circular(PrototypeRadii.pill),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: colors.$2,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
