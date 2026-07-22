import 'package:flutter/material.dart';

import 'colors.dart';
import 'spacing.dart';
import 'typography.dart';

abstract final class PrototypeTheme {
  static ThemeData get light {
    const scheme = ColorScheme(
      brightness: Brightness.light,
      primary: PrototypeColors.primary,
      onPrimary: Colors.white,
      primaryContainer: PrototypeColors.primaryContainer,
      onPrimaryContainer: PrototypeColors.onBackground,
      secondary: PrototypeColors.primaryLight,
      onSecondary: PrototypeColors.onBackground,
      tertiary: PrototypeColors.accent,
      onTertiary: PrototypeColors.onBackground,
      error: PrototypeColors.error,
      onError: Colors.white,
      errorContainer: PrototypeColors.errorContainer,
      onErrorContainer: PrototypeColors.onErrorContainer,
      surface: PrototypeColors.surface,
      onSurface: PrototypeColors.onBackground,
      onSurfaceVariant: PrototypeColors.onSurfaceVariant,
      outline: PrototypeColors.onSurfaceVariant,
      outlineVariant: PrototypeColors.outlineVariant,
    );

    final base = ThemeData(
      colorScheme: scheme,
      scaffoldBackgroundColor: PrototypeColors.background,
      useMaterial3: true,
    );

    return base.copyWith(
      textTheme: PrototypeTypography.textTheme(base.textTheme, scheme),
      appBarTheme: AppBarTheme(
        backgroundColor: PrototypeColors.background,
        foregroundColor: scheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleTextStyle: PrototypeTypography.textTheme(base.textTheme, scheme)
            .titleMedium,
      ),
      cardTheme: CardThemeData(
        color: PrototypeColors.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(PrototypeRadii.md),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: PrototypeColors.surface,
        indicatorColor: PrototypeColors.primaryContainer,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return TextStyle(
            fontFamily: PrototypeTypography.uiFamily,
            fontSize: 11,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
            color: selected ? scheme.primary : scheme.onSurfaceVariant,
          );
        }),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(PrototypeRadii.sm),
          ),
          textStyle: const TextStyle(
            fontFamily: PrototypeTypography.uiFamily,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: PrototypeColors.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(PrototypeRadii.sm),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(PrototypeRadii.sm),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(PrototypeRadii.sm),
          borderSide: BorderSide(color: scheme.primary, width: 2),
        ),
      ),
      dividerTheme: DividerThemeData(color: scheme.outlineVariant),
    );
  }
}
