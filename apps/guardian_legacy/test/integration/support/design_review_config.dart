import 'dart:async';
import 'dart:io';

import 'package:edaya_integration_tests/edaya_integration_tests.dart';
import 'package:edaya_shared/src/features/settings/app_settings_models.dart';

/// Locale for design-review screenshots.
///
/// Set `EDAYA_DESIGN_REVIEW_LOCALE` to `fr` or `en` (default: `fr`).
LanguagePreference designReviewLanguage() {
  final raw =
      Platform.environment['EDAYA_DESIGN_REVIEW_LOCALE'] ??
      const String.fromEnvironment('EDAYA_DESIGN_REVIEW_LOCALE', defaultValue: 'fr');

  return switch (raw.toLowerCase()) {
    'en' => LanguagePreference.en,
    'fr' => LanguagePreference.fr,
    _ => LanguagePreference.fr,
  };
}

String designReviewLocaleLabel(LanguagePreference language) {
  return switch (language) {
    LanguagePreference.en => 'EN',
    LanguagePreference.fr => 'FR',
    LanguagePreference.system => 'System',
  };
}

const Duration _apiProbeTimeout = Duration(seconds: 5);

/// Returns a failure reason when the design-review API probe cannot reach the backend.
Future<String?> resolveDesignReviewApiSkipReason() async {
  final config = IntegrationConfig.fromEnvironment();
  final client = HttpClient();

  try {
    final request = await client
        .getUrl(Uri.parse('${config.baseUrl}/auth/get-session'))
        .timeout(_apiProbeTimeout);
    final response = await request.close().timeout(_apiProbeTimeout);
    await response.drain();
    if (response.statusCode >= 500) {
      return 'API not reachable at ${config.baseUrl} (HTTP ${response.statusCode})';
    }
    return null;
  } on SocketException {
    return 'API not reachable at ${config.baseUrl}';
  } on TimeoutException {
    return 'API not reachable at ${config.baseUrl} (timed out)';
  } finally {
    client.close(force: true);
  }
}
