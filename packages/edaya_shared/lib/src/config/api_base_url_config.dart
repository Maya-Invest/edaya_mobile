import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../l10n/l10n_lookup.dart';

/// Resolves the API base URL for mobile apps.
///
/// In debug builds, a [SharedPreferences] override takes precedence over the
/// compile-time `--dart-define=API_URL` value so developers can switch servers
/// without rebuilding.
abstract final class ApiBaseUrlConfig {
  ApiBaseUrlConfig._();

  /// Known API endpoints for developer presets and build-time defines.
  static const localUrl = 'http://localhost:9999';
  static const androidEmulatorUrl = 'http://10.0.2.2:9999';
  static const stagingUrl = 'https://api-staging.edaya.softilab.dev';
  static const productionUrl = 'https://api.edaya.softilab.dev';

  static const _prefKey = 'edaya_api_base_url';

  static const compileTimeUrl = String.fromEnvironment(
    'API_URL',
    defaultValue: stagingUrl,
  );

  static String _resolved = compileTimeUrl;
  static bool _hasOverride = false;

  /// The resolved API base URL used by HTTP clients.
  static String get baseUrl => _resolved;

  /// Whether the current URL comes from a persisted dev override.
  static bool get hasOverride => _hasOverride;

  /// Loads any persisted dev override before dependency injection starts.
  static Future<void> load() async {
    if (!kDebugMode) {
      _resolved = compileTimeUrl;
      _hasOverride = false;
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final override = prefs.getString(_prefKey);
    if (override != null && override.isNotEmpty) {
      _resolved = override;
      _hasOverride = true;
      return;
    }

    _resolved = compileTimeUrl;
    _hasOverride = false;
  }

  /// Persists a dev override. Returns `true` when the URL changed.
  static Future<bool> saveOverride(String rawUrl) async {
    assert(kDebugMode, 'API URL overrides are only available in debug builds');

    final normalized = _normalizeUrl(rawUrl);
    if (normalized == _resolved) {
      return false;
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefKey, normalized);
    _resolved = normalized;
    _hasOverride = true;
    return true;
  }

  /// Clears the persisted override and reverts to the compile-time URL.
  static Future<bool> clearOverride() async {
    assert(kDebugMode, 'API URL overrides are only available in debug builds');

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefKey);
    final changed = _resolved != compileTimeUrl || _hasOverride;
    _resolved = compileTimeUrl;
    _hasOverride = false;
    return changed;
  }

  static String _normalizeUrl(String rawUrl) {
    var url = rawUrl.trim();
    if (url.isEmpty) {
      throw FormatException(systemL10n().apiUrlCannotBeEmpty);
    }

    if (!url.contains('://')) {
      url = 'http://$url';
    }

    final uri = Uri.parse(url);
    if (!uri.hasScheme || uri.host.isEmpty) {
      throw FormatException(systemL10n().enterValidApiUrl);
    }

    return uri.replace(path: uri.path.replaceAll(RegExp(r'/+$'), '')).toString();
  }
}
