import 'dart:io';

/// Locale slug for design-review screenshots.
///
/// Set `EDAYA_DESIGN_REVIEW_LOCALE` to `fr` (default). The prototype UI is
/// French-only today; this keeps the output folder layout aligned with live apps.
String designReviewLocaleSlug() {
  final raw =
      Platform.environment['EDAYA_DESIGN_REVIEW_LOCALE'] ??
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
