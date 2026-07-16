import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb, TargetPlatform;
import 'package:shared_preferences/shared_preferences.dart';

import '../l10n/l10n_lookup.dart';

/// Resolves the API base URL for mobile apps.
///
/// A [SharedPreferences] override takes precedence over the compile-time
/// `--dart-define=API_URL` value so the API endpoint can be switched without
/// rebuilding. Overrides work in all build modes, including release.
abstract final class ApiBaseUrlConfig {
  ApiBaseUrlConfig._();

  /// Known API endpoints for developer presets and build-time defines.
  static const localUrl = 'http://localhost:9999';
  static const androidEmulatorUrl = 'http://10.0.2.2:9999';
  static const stagingUrl = 'https://staging.api.edaya.app';
  static const productionUrl = 'https://api.edaya.app';

  /// Default API origin for the current runtime (iOS/macOS → localhost, Android → 10.0.2.2).
  static String get defaultForCurrentPlatform {
    if (kIsWeb) {
      return localUrl;
    }
    if (defaultTargetPlatform == TargetPlatform.android) {
      return androidEmulatorUrl;
    }
    return localUrl;
  }

  static const _prefKey = 'edaya_api_base_url';

  static const _dartDefineUrl = String.fromEnvironment('API_URL', defaultValue: '');

  static String? _appDefaultUrl;

  /// Sets the app-specific default when `--dart-define=API_URL` is not provided.
  ///
  /// Call before [load] from each app's `main`.
  static void configure({required String appDefaultUrl}) {
    _appDefaultUrl = appDefaultUrl;
  }

  /// Build-time URL from `--dart-define=API_URL`, else the configured app default.
  static String get defaultUrl {
    if (_dartDefineUrl.isNotEmpty) {
      return _dartDefineUrl;
    }
    return _appDefaultUrl ?? stagingUrl;
  }

  /// Backwards-compatible alias for [defaultUrl].
  static String get compileTimeUrl => defaultUrl;

  static String _resolved = stagingUrl;
  static bool _hasOverride = false;

  /// The resolved API base URL used by HTTP clients.
  static String get baseUrl => _resolved;

  /// Whether the current URL comes from a persisted dev override.
  static bool get hasOverride => _hasOverride;

  /// Loads any persisted override before dependency injection starts.
  static Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final override = prefs.getString(_prefKey);
    if (override != null && override.isNotEmpty) {
      final coerced = _coerceUrlForPlatform(override);
      _resolved = coerced;
      _hasOverride = true;
      if (coerced != override) {
        await prefs.setString(_prefKey, coerced);
      }
      return;
    }

    _resolved = _coerceUrlForPlatform(defaultUrl);
    _hasOverride = false;
  }

  /// Persists an override. Returns `true` when the URL changed.
  static Future<bool> saveOverride(String rawUrl) async {
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
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefKey);
    final changed = _resolved != defaultUrl || _hasOverride;
    _resolved = defaultUrl;
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

  /// Maps Android loopback (`10.0.2.2`) to localhost on iOS/desktop simulators.
  static String _coerceUrlForPlatform(String url) {
    if (kIsWeb || defaultTargetPlatform == TargetPlatform.android) {
      return url;
    }
    if (url == androidEmulatorUrl) {
      return localUrl;
    }
    return url;
  }
}
