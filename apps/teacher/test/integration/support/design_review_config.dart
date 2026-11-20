import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;

/// Locale slug for design-review screenshots.
///
/// Set `EDAYA_DESIGN_REVIEW_LOCALE` to `fr` (default). This keeps the output
/// folder layout aligned with Guardian.
String designReviewLocaleSlug() {
  final raw =
      (kIsWeb ? null : Platform.environment['EDAYA_DESIGN_REVIEW_LOCALE']) ??
      const String.fromEnvironment(
        'EDAYA_DESIGN_REVIEW_LOCALE',
        defaultValue: 'fr',
      );

  return switch (raw.toLowerCase()) {
    'en' => 'en',
    'fr' => 'fr',
    _ => 'fr',
  };
}

String designReviewLocaleLabel(String localeSlug) {
  return switch (localeSlug) {
    'en' => 'EN',
    'fr' => 'FR',
    _ => localeSlug.toUpperCase(),
  };
}

/// Explicit palette for reproducible accessibility review captures.
String designReviewTheme() {
  final value =
      (kIsWeb ? null : Platform.environment['EDAYA_DESIGN_REVIEW_THEME']) ??
      const String.fromEnvironment(
        'EDAYA_DESIGN_REVIEW_THEME',
        defaultValue: 'light',
      );
  if (!['light', 'dark'].contains(value)) {
    throw ArgumentError('EDAYA_DESIGN_REVIEW_THEME must be light or dark');
  }
  return value;
}

double designReviewTextScale() {
  final value =
      (kIsWeb
          ? null
          : Platform.environment['EDAYA_DESIGN_REVIEW_TEXT_SCALE']) ??
      const String.fromEnvironment(
        'EDAYA_DESIGN_REVIEW_TEXT_SCALE',
        defaultValue: '1',
      );
  if (!['1', '2'].contains(value)) {
    throw ArgumentError('EDAYA_DESIGN_REVIEW_TEXT_SCALE must be 1 or 2');
  }
  return double.parse(value);
}

String designReviewOutputPath() {
  final theme = designReviewTheme();
  final scale = designReviewTextScale();
  return 'design-review${theme == 'dark' ? '/dark' : ''}${scale == 2 ? '/large-text' : ''}';
}
