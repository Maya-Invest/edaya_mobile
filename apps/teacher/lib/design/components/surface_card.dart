import 'package:flutter/material.dart';

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
    final background = tint ?? Theme.of(context).colorScheme.surface;
    final radius = BorderRadius.circular(PrototypeRadii.md);
    final shadowOnly = BoxDecoration(
      borderRadius: radius,
      boxShadow: PrototypeElevation.cardShadow,
    );

    return Semantics(
      container: true,
      explicitChildNodes: onTap == null,
      onTap: onTap,
      button: onTap == null ? null : true,
      child: DecoratedBox(
        decoration: shadowOnly,
        child: Material(
          color: background,
          shape: RoundedRectangleBorder(borderRadius: radius),
          clipBehavior: Clip.antiAlias,
          child: onTap == null
              ? content
              : InkWell(
                  onTap: onTap,
                  excludeFromSemantics: true,
                  child: content,
                ),
        ),
      ),
    );
  }
}
