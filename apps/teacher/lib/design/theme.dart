import 'package:edaya_shared/edaya_shared.dart';
import 'package:flutter/material.dart';

import 'spacing.dart';

/// Accueil chrome on top of EDAYA 1.0 [AppTheme]: canvas app bar, borderless cards.
abstract final class PrototypeTheme {
  static ThemeData get light => _withAccueilChrome(
    AppTheme.light,
    canvas: EdayaTokens.lightBackground,
    card: EdayaTokens.lightCard,
  );

  static ThemeData get dark => _withAccueilChrome(
    AppTheme.dark,
    canvas: EdayaTokens.darkBackground,
    card: EdayaTokens.darkCard,
  );

  static ThemeData _withAccueilChrome(
    ThemeData base, {
    required Color canvas,
    required Color card,
  }) {
    return base.copyWith(
      scaffoldBackgroundColor: canvas,
      appBarTheme: base.appBarTheme.copyWith(
        backgroundColor: canvas,
        centerTitle: true,
      ),
      cardTheme: CardThemeData(
        color: card,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(PrototypeRadii.md),
        ),
      ),
    );
  }
}
