import 'dart:math' as math;
import 'package:flutter/material.dart';

enum EdayaLogoVariant { vertical, horizontal, symbol }

/// Supplied outlined EDAYA artwork with reserved clear space.
class EdayaBrandLogo extends StatelessWidget {
  const EdayaBrandLogo({
    super.key,
    this.variant = EdayaLogoVariant.horizontal,
    this.width,
    this.white,
    this.decorative = false,
  });
  final EdayaLogoVariant variant;
  final double? width;
  final bool? white;
  final bool decorative;

  @override
  Widget build(BuildContext context) {
    final minWidth = switch (variant) {
      EdayaLogoVariant.vertical => 88.0,
      EdayaLogoVariant.horizontal => 128.0,
      EdayaLogoVariant.symbol => 32.0,
    };
    final size = math.max(width ?? minWidth, minWidth);
    final name = variant == EdayaLogoVariant.symbol ? 'symbole' : variant.name;
    final reversed = white ?? Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: EdgeInsets.all(
        size * (variant == EdayaLogoVariant.horizontal ? .1 : .2),
      ),
      child: Image.asset(
        'assets/brand/edaya-$name-${reversed ? 'blanc' : 'couleur'}.png',
        package: 'edaya_shared',
        width: size,
        fit: BoxFit.contain,
        semanticLabel: decorative ? null : 'EDAYA',
        excludeFromSemantics: decorative,
      ),
    );
  }
}
