import 'package:flutter/material.dart';

import 'edaya_tokens.g.dart';
import 'edaya_typography.dart';

abstract final class AppTheme {
  static const _lightColorScheme = ColorScheme(
    brightness: Brightness.light,
    primary: EdayaTokens.lightPrimary,
    onPrimary: EdayaTokens.lightPrimaryForeground,
    primaryContainer: EdayaTokens.lightPrimaryContainer,
    onPrimaryContainer: EdayaTokens.lightForeground,
    secondary: EdayaTokens.lightSky,
    onSecondary: EdayaTokens.lightPrimaryForeground,
    secondaryContainer: EdayaTokens.lightSkySoft,
    onSecondaryContainer: EdayaTokens.lightForeground,
    tertiary: EdayaTokens.lightHighlight,
    onTertiary: EdayaTokens.lightHighlightForeground,
    tertiaryContainer: EdayaTokens.lightHighlightSoft,
    onTertiaryContainer: EdayaTokens.lightHighlight,
    error: EdayaTokens.lightDestructive,
    onError: EdayaTokens.lightDestructiveForeground,
    errorContainer: EdayaTokens.lightDestructiveSoft,
    onErrorContainer: EdayaTokens.lightDestructive,
    surface: EdayaTokens.lightCard,
    onSurface: EdayaTokens.lightForeground,
    onSurfaceVariant: EdayaTokens.lightMutedForeground,
    outline: EdayaTokens.lightInput,
    outlineVariant: EdayaTokens.lightBorder,
    surfaceTint: EdayaTokens.lightPrimary,
    surfaceContainerHighest: EdayaTokens.lightSecondary,
    shadow: Colors.black,
    scrim: Colors.black,
  );

  static ThemeData get light => _buildTheme(
    brightness: Brightness.light,
    colorScheme: _lightColorScheme,
    scaffoldBackground: EdayaTokens.lightBackground,
    cardColor: EdayaTokens.lightCard,
    inputFillColor: EdayaTokens.lightCard,
    appBarBackground: EdayaTokens.lightCard,
    navBarBackground: EdayaTokens.lightCard,
  );

  static const _darkColorScheme = ColorScheme(
    brightness: Brightness.dark,
    primary: EdayaTokens.darkPrimary,
    onPrimary: EdayaTokens.darkPrimaryForeground,
    primaryContainer: EdayaTokens.darkPrimaryContainer,
    onPrimaryContainer: EdayaTokens.darkForeground,
    secondary: EdayaTokens.darkSky,
    onSecondary: EdayaTokens.darkPrimaryForeground,
    secondaryContainer: EdayaTokens.darkSkySoft,
    onSecondaryContainer: EdayaTokens.darkForeground,
    tertiary: EdayaTokens.darkHighlight,
    onTertiary: EdayaTokens.darkHighlightForeground,
    tertiaryContainer: EdayaTokens.darkHighlightSoft,
    onTertiaryContainer: EdayaTokens.darkHighlight,
    error: EdayaTokens.darkDestructive,
    onError: EdayaTokens.darkDestructiveForeground,
    errorContainer: EdayaTokens.darkDestructiveSoft,
    onErrorContainer: EdayaTokens.darkDestructive,
    surface: EdayaTokens.darkCard,
    onSurface: EdayaTokens.darkForeground,
    onSurfaceVariant: EdayaTokens.darkMutedForeground,
    outline: EdayaTokens.darkInput,
    outlineVariant: EdayaTokens.darkBorder,
    surfaceTint: EdayaTokens.darkPrimary,
    surfaceContainerHighest: EdayaTokens.darkSecondary,
    shadow: Colors.black,
    scrim: Colors.black,
  );

  static ThemeData get dark => _buildTheme(
    brightness: Brightness.dark,
    colorScheme: _darkColorScheme,
    scaffoldBackground: EdayaTokens.darkBackground,
    cardColor: EdayaTokens.darkCard,
    inputFillColor: EdayaTokens.darkCard,
    appBarBackground: EdayaTokens.darkCard,
    navBarBackground: EdayaTokens.darkCard,
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
      pageTransitionsTheme: const _EdayaPageTransitionsTheme(),
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
        titleTextStyle: EdayaTypography.heading(
          fontSize: EdayaTokens.typeMobilePage,
          color: colorScheme.onSurface,
        ),
      ),
      cardTheme: CardThemeData(
        color: cardColor,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(EdayaTokens.radiusSurface),
          side: BorderSide(color: colorScheme.outlineVariant),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: inputFillColor,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(EdayaTokens.radiusControl),
          borderSide: BorderSide(color: colorScheme.outline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(EdayaTokens.radiusControl),
          borderSide: BorderSide(color: colorScheme.outline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(EdayaTokens.radiusControl),
          borderSide: BorderSide(color: colorScheme.primary, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        errorMaxLines: 4,
        labelStyle: TextStyle(color: colorScheme.onSurfaceVariant),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: colorScheme.primary,
          foregroundColor: colorScheme.onPrimary,
          minimumSize: const Size(48, 48),
          textStyle: EdayaTypography.textTheme(
            base.textTheme,
            colorScheme,
          ).labelLarge,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(EdayaTokens.radiusControl),
          ),
        ),
      ),
      listTileTheme: ListTileThemeData(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        titleTextStyle: EdayaTypography.textTheme(
          base.textTheme,
          colorScheme,
        ).titleMedium,
        subtitleTextStyle: EdayaTypography.textTheme(
          base.textTheme,
          colorScheme,
        ).bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant),
        iconColor: colorScheme.onSurfaceVariant,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: cardColor,
        surfaceTintColor: Colors.transparent,
        constraints: const BoxConstraints(maxWidth: 840),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(EdayaTokens.radiusOverlay),
          ),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: cardColor,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(EdayaTokens.radiusOverlay),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(48, 48),
          side: BorderSide(color: colorScheme.outline),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(EdayaTokens.radiusControl),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(minimumSize: const Size(44, 44)),
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
          return EdayaTypography.textTheme(
            base.textTheme,
            colorScheme,
          ).labelSmall?.copyWith(
            color: selected
                ? colorScheme.primary
                : colorScheme.onSurfaceVariant,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            color: selected
                ? colorScheme.primary
                : colorScheme.onSurfaceVariant,
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

class _EdayaPageTransitionsTheme extends PageTransitionsTheme {
  const _EdayaPageTransitionsTheme();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) => super.buildTransitions<T>(
    route,
    context,
    animation,
    secondaryAnimation,
    // Workspace pages share a scaffold, so their canvas must move with them.
    route.opaque
        ? Material(
            color: Theme.of(context).scaffoldBackgroundColor,
            child: child,
          )
        : child,
  );
}
