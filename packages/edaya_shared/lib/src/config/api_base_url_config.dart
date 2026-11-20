import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, kReleaseMode, TargetPlatform;
import 'package:shared_preferences/shared_preferences.dart';

import '../l10n/l10n_lookup.dart';

/// Resolves the unified API origin for all mobile requests.
///
/// Store builds always use their compiled API origin. Developer builds may
/// override it with a saved preference. Authentication uses the same origin.
abstract final class ApiBaseUrlConfig {
  ApiBaseUrlConfig._();

  /// Known endpoints for developer presets and build-time defines.
  static const localUrl = 'http://localhost:9999';
  static const androidEmulatorUrl = 'http://10.0.2.2:9999';
  static const stagingUrl = 'https://staging.api.edayaplus.com';
  static const productionUrl = 'https://api.edayaplus.com';

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

  static const _dartDefineUrl = String.fromEnvironment(
    'API_URL',
    defaultValue: '',
  );
  static String? _appDefaultUrl;

  /// Sets app defaults when the corresponding dart-define is not provided.
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

  /// The resolved School API base URL used by School HTTP clients.
  static String get baseUrl => _resolved;

  static String get apiBaseUrl => _resolved;

  /// The Identity base URL used by [AuthClient].
  static String get authBaseUrl => baseUrl;

  /// Whether the current URL comes from a persisted dev override.
  static bool get hasOverride => _hasOverride;

  /// Loads any persisted override before dependency injection starts.
  static Future<void> load() async {
    if (kReleaseMode) {
      _resolved = _coerceUrlForPlatform(defaultUrl);
      _hasOverride = false;
      return;
    }
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
    if (kReleaseMode) return false;
    final normalized = _coerceUrlForPlatform(_normalizeUrl(rawUrl));
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
    _resolved = _coerceUrlForPlatform(defaultUrl);
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

    return uri
        .replace(path: uri.path.replaceAll(RegExp(r'/+$'), ''))
        .toString();
  }

  /// Known retired presets require fresh login; custom developer URLs survive.
  static String migratePreset(String url) =>
      const {
        'https://staging.school.api.edayaplus.com': stagingUrl,
        'https://staging.identity.api.edayaplus.com': stagingUrl,
        'https://school.api.edayaplus.com': productionUrl,
        'https://identity.api.edayaplus.com': productionUrl,
        'http://localhost:9900': localUrl,
        'http://127.0.0.1:9900': 'http://127.0.0.1:9999',
        'http://10.0.2.2:9900': androidEmulatorUrl,
      }[url] ??
      url;

  static const _loopbackHosts = {'localhost', '127.0.0.1', '::1'};

  /// Rewrites server-issued loopback URLs onto the client School API host.
  ///
  /// Local API mints upload URLs with `API_ORIGIN` (`http://localhost:9999`).
  /// Android emulators and physical devices reach that origin through
  /// `10.0.2.2` or a LAN address instead.
  static String rewriteLocalDevUrl(String url, {String? apiBaseUrl}) {
    final uri = Uri.tryParse(url);
    if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
      return url;
    }
    if (!_loopbackHosts.contains(uri.host)) {
      return url;
    }

    final base = Uri.tryParse(apiBaseUrl ?? baseUrl);
    if (base == null ||
        base.host.isEmpty ||
        _loopbackHosts.contains(base.host)) {
      return url;
    }

    return uri.replace(scheme: base.scheme, host: base.host).toString();
  }

  /// Maps Android loopback (`10.0.2.2`) to localhost on iOS/desktop simulators.
  static String _coerceUrlForPlatform(String url) {
    url = migratePreset(url);
    if (kIsWeb || defaultTargetPlatform == TargetPlatform.android) {
      return url;
    }
    if (url == androidEmulatorUrl) {
      return localUrl;
    }
    return url;
  }
}
