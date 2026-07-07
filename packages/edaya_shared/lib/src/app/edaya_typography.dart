import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'edaya_colors.dart';

/// Typography tokens for the Edaya design system.
///
/// UI copy uses Nunito (rounded sans). Display headings use a heavier Nunito
/// weight until Galak Round Demo is bundled under `assets/fonts/`.
abstract final class EdayaTypography {
  static const brandFontFamily = 'GalakRound';

  static TextTheme textTheme(TextTheme base, ColorScheme colorScheme) {
    final theme = GoogleFonts.nunitoTextTheme(base).apply(
      bodyColor: colorScheme.onSurface,
      displayColor: colorScheme.onSurface,
    );

    return theme.copyWith(
      displayLarge: _displayStyle(theme.displayLarge, colorScheme.onSurface),
      displayMedium: _displayStyle(theme.displayMedium, colorScheme.onSurface),
      displaySmall: _displayStyle(theme.displaySmall, colorScheme.onSurface),
      headlineLarge: _displayStyle(theme.headlineLarge, colorScheme.onSurface),
      titleMedium: theme.titleMedium?.copyWith(color: colorScheme.onSurface),
      titleSmall: theme.titleSmall?.copyWith(color: colorScheme.onSurface),
      bodySmall: theme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
      labelSmall: theme.labelSmall?.copyWith(
        color: colorScheme.onSurfaceVariant,
      ),
    );
  }

  static TextStyle brandWordmark({
    double fontSize = 40,
    Color color = EdayaColors.onBackground,
  }) {
    return GoogleFonts.nunito(
      fontWeight: FontWeight.w800,
      fontSize: fontSize,
      color: color,
      height: 1.1,
    );
  }

  static TextStyle _displayStyle(TextStyle? base, Color color) {
    return GoogleFonts.nunito(
      fontWeight: FontWeight.w800,
      fontSize: base?.fontSize,
      height: base?.height,
      letterSpacing: base?.letterSpacing,
      color: color,
    );
  }
}
