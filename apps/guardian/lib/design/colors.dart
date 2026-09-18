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
  (Color bg, Color fg) resolve(ColorScheme scheme) => switch (this) {
    SemanticTone.neutral => (
      EdayaTokens.lightMuted,
      PrototypeColors.onSurfaceVariant,
    ),
    SemanticTone.info => (
      PrototypeColors.primaryContainer,
      PrototypeColors.primary,
    ),
    SemanticTone.success => (
      PrototypeColors.primaryContainer,
      PrototypeColors.onBackground,
    ),
    SemanticTone.warning => (
      PrototypeColors.accentContainer,
      EdayaTokens.lightHighlight,
    ),
    SemanticTone.error => (
      PrototypeColors.errorContainer,
      PrototypeColors.onErrorContainer,
    ),
  };
}
