import 'package:flutter/material.dart';

import 'colors.dart';

abstract final class PrototypeSpacing {
  static const xxs = 4.0;
  static const xs = 8.0;
  static const sm = 12.0;
  static const md = 16.0;
  static const lg = 20.0;
  static const xl = 24.0;
  static const xxl = 32.0;
}

abstract final class PrototypeRadii {
  static const sm = 12.0;
  static const md = 16.0;
  static const lg = 20.0;
  static const pill = 999.0;
}

abstract final class PrototypeElevation {
  static const cardShadow = [
    BoxShadow(
      color: Color(0x141E293B),
      blurRadius: 12,
      offset: Offset(0, 4),
    ),
  ];

  /// Borderless card surface — white fill + soft shadow, no stroke.
  static BoxDecoration cardDecoration({
    Color background = PrototypeColors.surface,
    double radius = PrototypeRadii.md,
    List<BoxShadow>? shadow,
  }) {
    return BoxDecoration(
      color: background,
      borderRadius: BorderRadius.circular(radius),
      boxShadow: shadow ?? cardShadow,
    );
  }
}
