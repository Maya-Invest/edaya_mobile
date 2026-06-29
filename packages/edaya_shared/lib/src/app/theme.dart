import 'package:flutter/material.dart';

import 'edaya_colors.dart';
import 'edaya_typography.dart';

abstract final class AppTheme {
  static const _lightColorScheme = ColorScheme(
    brightness: Brightness.light,
    primary: EdayaColors.primary,
    onPrimary: Colors.white,
    primaryContainer: EdayaColors.primaryContainer,
    onPrimaryContainer: EdayaColors.onBackground,
    secondary: EdayaColors.primaryLight,
    onSecondary: EdayaColors.onBackground,
    secondaryContainer: EdayaColors.secondaryContainer,
    onSecondaryContainer: EdayaColors.onBackground,
    tertiary: EdayaColors.accent,
    onTertiary: EdayaColors.onBackground,
    tertiaryContainer: EdayaColors.accentContainer,
    onTertiaryContainer: EdayaColors.onBackground,
    error: Color(0xFFDC2626),
    onError: Colors.white,
    errorContainer: Color(0xFFFEE2E2),
    onErrorContainer: Color(0xFF7F1D1D),
    surface: Colors.white,
    onSurface: EdayaColors.onBackground,
    onSurfaceVariant: EdayaColors.onSurfaceVariant,
    outline: EdayaColors.outline,
    outlineVariant: EdayaColors.outlineVariant,
    shadow: Colors.black,
    scrim: Colors.black,
    inverseSurface: EdayaColors.onBackground,
    onInverseSurface: EdayaColors.background,
    inversePrimary: EdayaColors.primaryLight,
    surfaceTint: EdayaColors.primary,
  );

  static ThemeData get light => _buildTheme(
    brightness: Brightness.light,
    colorScheme: _lightColorScheme,
    scaffoldBackground: EdayaColors.background,
    cardColor: Colors.white,
    inputFillColor: Colors.white,
    appBarBackground: EdayaColors.background,
    navBarBackground: Colors.white,
  );

  static const _darkColorScheme = ColorScheme(
    brightness: Brightness.dark,
    primary: EdayaColors.primary,
    onPrimary: Colors.white,
    primaryContainer: Color(0xFF1D4ED8),
    onPrimaryContainer: Color(0xFFEFF6FF),
    secondary: EdayaColors.primaryLight,
    onSecondary: EdayaColors.onBackground,
    secondaryContainer: Color(0xFF1E3A8A),
    onSecondaryContainer: Color(0xFFDBEAFE),
    tertiary: EdayaColors.accent,
    onTertiary: EdayaColors.onBackground,
    tertiaryContainer: Color(0xFF92400E),
    onTertiaryContainer: Color(0xFFFEF3C7),
    error: Color(0xFFF87171),
    onError: EdayaColors.onBackground,
    errorContainer: Color(0xFF7F1D1D),
    onErrorContainer: Color(0xFFFEE2E2),
    surface: Color(0xFF1E293B),
    onSurface: Color(0xFFF1F5F9),
    onSurfaceVariant: Color(0xFFCBD5E1),
    outline: Color(0xFF64748B),
    outlineVariant: Color(0xFF475569),
    shadow: Colors.black,
    scrim: Colors.black,
    inverseSurface: Color(0xFFF1F5F9),
    onInverseSurface: EdayaColors.onBackground,
    inversePrimary: EdayaColors.primaryLight,
    surfaceTint: EdayaColors.primary,
    surfaceContainerHighest: Color(0xFF334155),
  );

  static ThemeData get dark => _buildTheme(
    brightness: Brightness.dark,
    colorScheme: _darkColorScheme,
    scaffoldBackground: const Color(0xFF0F172A),
    cardColor: const Color(0xFF1E293B),
    inputFillColor: const Color(0xFF1E293B),
    appBarBackground: const Color(0xFF0F172A),
    navBarBackground: const Color(0xFF1E293B),
  );

  static ThemeData _buildTheme({
    required Brightness brightness,
    required ColorScheme colorScheme,
    required Color scaffoldBackground,
    required Color cardColor,
    required Color inputFillColor,
    required Color appBarBackground,
    required Color navBarBackground,
  }) {
    final base = ThemeData(
      colorScheme: colorScheme,
      scaffoldBackgroundColor: scaffoldBackground,
      useMaterial3: true,
      brightness: brightness,
    );

    return base.copyWith(
      textTheme: EdayaTypography.textTheme(base.textTheme, colorScheme),
      appBarTheme: AppBarTheme(
        backgroundColor: appBarBackground,
        foregroundColor: colorScheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: EdayaTypography.brandWordmark(
          fontSize: 22,
          color: colorScheme.onSurface,
        ),
      ),
      cardTheme: CardThemeData(
        color: cardColor,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: colorScheme.outlineVariant),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: inputFillColor,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colorScheme.outline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colorScheme.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colorScheme.primary, width: 2),
        ),
        labelStyle: TextStyle(color: colorScheme.onSurfaceVariant),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: colorScheme.primary,
          foregroundColor: colorScheme.onPrimary,
          minimumSize: const Size.fromHeight(48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: navBarBackground,
        indicatorColor: colorScheme.primaryContainer,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return TextStyle(
            color: selected ? colorScheme.primary : colorScheme.onSurfaceVariant,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            color: selected ? colorScheme.primary : colorScheme.onSurfaceVariant,
          );
        }),
      ),
      dividerTheme: DividerThemeData(
        color: colorScheme.outlineVariant,
        thickness: 1,
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: colorScheme.primary,
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          foregroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return colorScheme.onPrimary;
            }
            return colorScheme.onSurface;
          }),
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return colorScheme.primary;
            }
            return colorScheme.surfaceContainerHighest;
          }),
        ),
      ),
    );
  }
}
