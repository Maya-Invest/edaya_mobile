import 'package:flutter/material.dart';

import '../spacing.dart';
import 'person_avatar.dart';
import 'surface_card.dart';

/// Square parent photo card (initials only) matching the child card height.
class ParentAccountCard extends StatelessWidget {
  const ParentAccountCard({super.key, required this.initials, this.onTap});

  final String initials;
  final VoidCallback? onTap;

  static const double side = 80;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Mon compte',
      child: SizedBox.square(
        dimension: side,
        child: SurfaceCard(
          tint: Theme.of(context).colorScheme.primaryContainer,
          padding: const EdgeInsets.all(PrototypeSpacing.xs),
          onTap: onTap,
          child: Center(child: PersonAvatar(initials: initials, radius: 22)),
        ),
      ),
    );
  }
}
