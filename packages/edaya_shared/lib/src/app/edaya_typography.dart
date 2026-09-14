import 'package:flutter/material.dart';

import 'edaya_tokens.g.dart';

/// Locally bundled, offline typography. Logos are assets, never UI text.
abstract final class EdayaTypography {
  static const _package = 'edaya_shared';

  static TextStyle heading({required double fontSize, required Color color}) =>
      TextStyle(
        fontFamily: EdayaTokens.headingFont,
        package: _package,
        fontSize: fontSize,
        fontWeight: FontWeight.w600,
        height: 1.3,
        letterSpacing: -0.3,
        color: color,
      );

  static TextTheme textTheme(TextTheme base, ColorScheme colors) {
    final theme = base.apply(
      fontFamily: EdayaTokens.bodyFont,
      package: _package,
      bodyColor: colors.onSurface,
      displayColor: colors.onSurface,
    );
    return theme.copyWith(
      displayLarge: heading(fontSize: 36, color: colors.onSurface),
      displayMedium: heading(fontSize: 32, color: colors.onSurface),
      displaySmall: heading(fontSize: 28, color: colors.onSurface),
      headlineLarge: heading(fontSize: 28, color: colors.onSurface),
      headlineMedium: heading(
        fontSize: EdayaTokens.typeMobilePage,
        color: colors.onSurface,
      ),
      headlineSmall: heading(
        fontSize: EdayaTokens.typeMobilePage,
        color: colors.onSurface,
      ),
      titleLarge: heading(
        fontSize: EdayaTokens.typeSection,
        color: colors.onSurface,
      ),
      titleMedium: theme.titleMedium?.copyWith(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        height: 1.4,
      ),
      titleSmall: theme.titleSmall?.copyWith(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        height: 1.4,
      ),
      bodyLarge: theme.bodyLarge?.copyWith(fontSize: 16, height: 1.5),
      bodyMedium: theme.bodyMedium?.copyWith(fontSize: 14, height: 1.5),
      bodySmall: theme.bodySmall?.copyWith(
        fontSize: 12,
        height: 1.5,
        color: colors.onSurfaceVariant,
      ),
      labelLarge: theme.labelLarge?.copyWith(
        fontSize: 14,
        fontWeight: FontWeight.w600,
      ),
      labelMedium: theme.labelMedium?.copyWith(
        fontSize: 12,
        fontWeight: FontWeight.w500,
      ),
      labelSmall: theme.labelSmall?.copyWith(
        fontSize: 12,
        color: colors.onSurfaceVariant,
      ),
    );
  }
}
