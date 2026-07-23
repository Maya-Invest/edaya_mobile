import 'package:flutter/material.dart';

import 'colors.dart';

abstract final class PrototypeTypography {
  /// Single UI family for now (Galak Round deferred until a commercial license).
  static const uiFamily = 'Nunito';

  static TextTheme textTheme(TextTheme base, ColorScheme scheme) {
    return base.copyWith(
      displaySmall: _nunito(32, scheme.onSurface, weight: FontWeight.w600),
      headlineMedium: _nunito(24, scheme.onSurface, weight: FontWeight.w600),
      headlineSmall: _nunito(20, scheme.onSurface, weight: FontWeight.w600),
      titleLarge: _nunito(18, scheme.onSurface, weight: FontWeight.w600),
      titleMedium: _nunito(16, scheme.onSurface, weight: FontWeight.w600),
      titleSmall: _nunito(14, scheme.onSurface, weight: FontWeight.w600),
      bodyLarge: _nunito(16, scheme.onSurface),
      bodyMedium: _nunito(14, scheme.onSurface),
      bodySmall: _nunito(12, scheme.onSurfaceVariant),
      labelLarge: _nunito(14, scheme.onSurface, weight: FontWeight.w600),
      labelMedium: _nunito(12, scheme.onSurfaceVariant, weight: FontWeight.w600),
      labelSmall: _nunito(11, scheme.onSurfaceVariant, weight: FontWeight.w500),
    );
  }

  /// Brand wordmark. [size] must stay in **28–40** sp.
  static TextStyle brandWordmark({double size = 40, Color? color}) {
    assert(size >= 28 && size <= 40, 'brandWordmark size must be 28–40');
    return TextStyle(
      fontFamily: uiFamily,
      fontWeight: FontWeight.w700,
      fontSize: size,
      color: color ?? PrototypeColors.onBackground,
      height: 1.05,
      letterSpacing: -0.5,
    );
  }

  static TextStyle _nunito(
    double size,
    Color color, {
    FontWeight weight = FontWeight.w400,
  }) {
    return TextStyle(
      fontFamily: uiFamily,
      fontWeight: weight,
      fontSize: size,
      height: 1.4,
      color: color,
    );
  }
}
