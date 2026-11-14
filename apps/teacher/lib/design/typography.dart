import 'package:edaya_shared/edaya_shared.dart';
import 'package:flutter/material.dart';

abstract final class PrototypeTypography {
  static const uiFamily = EdayaTokens.bodyFont;
  static const headingFamily = EdayaTokens.headingFont;

  static TextTheme textTheme(TextTheme base, ColorScheme scheme) {
    return EdayaTypography.textTheme(base, scheme);
  }
}
