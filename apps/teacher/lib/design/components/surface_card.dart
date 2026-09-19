import 'package:flutter/material.dart';

import '../colors.dart';
import '../spacing.dart';

class SurfaceCard extends StatelessWidget {
  const SurfaceCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(PrototypeSpacing.md),
    this.onTap,
    this.tint,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final Color? tint;

  @override
  Widget build(BuildContext context) {
    final content = Padding(padding: padding, child: child);
    final background = tint ?? PrototypeColors.surface;
    final radius = BorderRadius.circular(PrototypeRadii.md);
    final shadowOnly = BoxDecoration(
      borderRadius: radius,
      boxShadow: PrototypeElevation.cardShadow,
    );

    Widget card = Material(
      color: background,
      shape: RoundedRectangleBorder(borderRadius: radius),
      clipBehavior: Clip.antiAlias,
      child: content,
    );

    card = DecoratedBox(decoration: shadowOnly, child: card);

    if (onTap == null) {
      return card;
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(onTap: onTap, borderRadius: radius, child: card),
    );
  }
}
