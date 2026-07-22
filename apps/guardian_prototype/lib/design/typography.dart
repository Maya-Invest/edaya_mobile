import 'package:flutter/material.dart';

import 'colors.dart';

abstract final class PrototypeTypography {
  static const brandFamily = 'GalakRound';
  static const uiFamily = 'Nunito';

  static TextTheme textTheme(TextTheme base, ColorScheme scheme) {
    return base.copyWith(
      displaySmall: _galak(base.displaySmall, scheme.onSurface),
      headlineMedium: _galak(base.headlineMedium, scheme.onSurface),
      headlineSmall: _galak(base.headlineSmall, scheme.onSurface),
      titleLarge: _nunito(base.titleLarge, scheme.onSurface, w600: true),
      titleMedium: _nunito(base.titleMedium, scheme.onSurface, w600: true),
      titleSmall: _nunito(base.titleSmall, scheme.onSurface, w600: true),
      bodyLarge: _nunito(base.bodyLarge, scheme.onSurface),
      bodyMedium: _nunito(base.bodyMedium, scheme.onSurface),
      bodySmall: _nunito(base.bodySmall, scheme.onSurfaceVariant),
      labelLarge: _nunito(base.labelLarge, scheme.onSurface, w600: true),
      labelMedium: _nunito(base.labelMedium, scheme.onSurfaceVariant, w600: true),
      labelSmall: _nunito(base.labelSmall, scheme.onSurfaceVariant),
    );
  }

  static TextStyle brandWordmark({double size = 40, Color? color}) {
    return TextStyle(
      fontFamily: brandFamily,
      fontSize: size,
      color: color ?? PrototypeColors.onBackground,
      height: 1.05,
      letterSpacing: -0.5,
    );
  }

  static TextStyle _galak(TextStyle? base, Color color) {
    return TextStyle(
      fontFamily: brandFamily,
      fontSize: base?.fontSize,
      height: base?.height ?? 1.15,
      color: color,
    );
  }

  static TextStyle _nunito(
    TextStyle? base,
    Color color, {
    bool w600 = false,
  }) {
    return TextStyle(
      fontFamily: uiFamily,
      fontWeight: w600 ? FontWeight.w600 : FontWeight.w400,
      fontSize: base?.fontSize,
      height: base?.height ?? 1.4,
      color: color,
    );
  }
}
