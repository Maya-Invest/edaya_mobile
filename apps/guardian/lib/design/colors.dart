import 'package:flutter/material.dart';

abstract final class PrototypeColors {
  static const primary = Color(0xFF2563EB);
  static const primaryLight = Color(0xFF60A5FA);
  static const accent = Color(0xFFFBBF24);
  static const background = Color(0xFFF0F7FF);
  static const onBackground = Color(0xFF1E293B);

  static const primaryContainer = Color(0xFFDBEAFE);
  static const successContainer = Color(0xFFDCFCE7);
  static const accentContainer = Color(0xFFFEF3C7);
  static const errorContainer = Color(0xFFFEE2E2);
  static const onErrorContainer = Color(0xFF7F1D1D);
  static const onSurfaceVariant = Color(0xFF64748B);
  static const outlineVariant = Color(0xFFCBD5E1);
  static const surface = Colors.white;
  static const error = Color(0xFFDC2626);
}

enum SemanticTone { neutral, info, success, warning, error }

extension SemanticToneColors on SemanticTone {
  (Color bg, Color fg) resolve(ColorScheme scheme) => switch (this) {
    SemanticTone.neutral => (
      const Color(0xFFF1F5F9),
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
      const Color(0xFF92400E),
    ),
    SemanticTone.error => (
      PrototypeColors.errorContainer,
      PrototypeColors.onErrorContainer,
    ),
  };
}
