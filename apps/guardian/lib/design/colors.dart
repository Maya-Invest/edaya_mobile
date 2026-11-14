import 'package:edaya_shared/edaya_shared.dart';
import 'package:flutter/material.dart';

abstract final class PrototypeColors {
  static const primary = EdayaColors.primary;
  static const primaryLight = EdayaColors.primaryLight;
  static const accent = EdayaColors.accent;
  static const background = EdayaColors.background;
  static const onBackground = EdayaColors.onBackground;

  static const primaryContainer = EdayaColors.primaryContainer;
  static const successContainer = EdayaTokens.lightSuccessSoft;
  static const accentContainer = EdayaColors.accentContainer;
  static const errorContainer = EdayaTokens.lightDestructiveSoft;
  static const onErrorContainer = EdayaTokens.lightDestructive;
  static const onSurfaceVariant = EdayaColors.onSurfaceVariant;
  static const outlineVariant = EdayaColors.outlineVariant;
  static const surface = EdayaTokens.lightCard;
  static const error = EdayaTokens.lightDestructive;
}

enum SemanticTone { neutral, info, success, warning, error }

extension SemanticToneColors on SemanticTone {
  (Color bg, Color fg) resolve(ColorScheme scheme) {
    final dark = scheme.brightness == Brightness.dark;
    return switch (this) {
      SemanticTone.neutral => (
        dark ? EdayaTokens.darkMuted : EdayaTokens.lightMuted,
        dark
            ? EdayaTokens.darkMutedForeground
            : PrototypeColors.onSurfaceVariant,
      ),
      SemanticTone.info => (
        scheme.secondaryContainer,
        scheme.onSecondaryContainer,
      ),
      SemanticTone.success => (
        dark ? EdayaTokens.darkSuccessSoft : PrototypeColors.primaryContainer,
        dark ? EdayaTokens.darkSuccess : PrototypeColors.onBackground,
      ),
      SemanticTone.warning => (
        dark ? EdayaTokens.darkHighlightSoft : PrototypeColors.accentContainer,
        dark ? EdayaTokens.darkHighlight : EdayaTokens.lightHighlight,
      ),
      SemanticTone.error => (
        dark ? EdayaTokens.darkDestructiveSoft : PrototypeColors.errorContainer,
        dark ? EdayaTokens.darkDestructive : PrototypeColors.onErrorContainer,
      ),
    };
  }
}
