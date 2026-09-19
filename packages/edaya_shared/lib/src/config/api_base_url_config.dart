import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;
import 'package:shared_preferences/shared_preferences.dart';

import '../l10n/l10n_lookup.dart';

/// Resolves the Identity and School API base URLs for mobile apps.
///
/// A [SharedPreferences] override takes precedence over the compile-time School
/// `--dart-define=API_URL` value so that endpoint can be switched without
/// rebuilding. Identity uses the independent `--dart-define=AUTH_URL` value.
abstract final class ApiBaseUrlConfig {
  ApiBaseUrlConfig._();

  /// Known endpoints for developer presets and build-time defines.
  static const localUrl = 'http://localhost:9999';
  static const localAuthUrl = 'http://localhost:9900';
  static const androidEmulatorUrl = 'http://10.0.2.2:9999';
  static const androidEmulatorAuthUrl = 'http://10.0.2.2:9900';
  static const stagingUrl = 'https://staging.school.api.edayaplus.com';
  static const stagingAuthUrl = 'https://staging.identity.api.edayaplus.com';
  static const productionUrl = 'https://school.api.edayaplus.com';
  static const productionAuthUrl = 'https://identity.api.edayaplus.com';

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

  /// Default Identity origin matching [defaultForCurrentPlatform].
  static String get defaultAuthForCurrentPlatform {
    if (kIsWeb) {
      return localAuthUrl;
    }
    if (defaultTargetPlatform == TargetPlatform.android) {
      return androidEmulatorAuthUrl;
    }
    return localAuthUrl;
  }

  static const _prefKey = 'edaya_api_base_url';

  static const _dartDefineUrl = String.fromEnvironment(
    'API_URL',
    defaultValue: '',
  );
  static const _dartDefineAuthUrl = String.fromEnvironment(
    'AUTH_URL',
    defaultValue: '',
  );

  static String? _appDefaultUrl;
  static String? _appDefaultAuthUrl;

  /// Sets app defaults when the corresponding dart-define is not provided.
  ///
  /// Call before [load] from each app's `main`.
  static void configure({
    required String appDefaultUrl,
    String? appDefaultAuthUrl,
  }) {
    _appDefaultUrl = appDefaultUrl;
    _appDefaultAuthUrl = appDefaultAuthUrl;
  }

  /// Build-time URL from `--dart-define=API_URL`, else the configured app default.
  static String get defaultUrl {
    if (_dartDefineUrl.isNotEmpty) {
      return _dartDefineUrl;
    }
    return _appDefaultUrl ?? stagingUrl;
  }

  /// Build-time Identity URL, else the configured app Identity default.
  static String get defaultAuthUrl {
    if (_dartDefineAuthUrl.isNotEmpty) {
      return _dartDefineAuthUrl;
    }
    return _appDefaultAuthUrl ?? stagingAuthUrl;
  }

  /// Backwards-compatible alias for [defaultUrl].
  static String get compileTimeUrl => defaultUrl;

  static String _resolved = stagingUrl;
  static bool _hasOverride = false;

  /// The resolved School API base URL used by School HTTP clients.
  static String get baseUrl => _resolved;

  static String get apiBaseUrl => _resolved;

  /// The Identity base URL used by [AuthClient].
  static String get authBaseUrl => _coerceAuthUrlForPlatform(defaultAuthUrl);

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
    if (kIsWeb || defaultTargetPlatform == TargetPlatform.android) {
      return url;
    }
    if (url == androidEmulatorUrl) {
      return localUrl;
    }
    return url;
  }

  static String _coerceAuthUrlForPlatform(String url) {
    if (kIsWeb || defaultTargetPlatform == TargetPlatform.android) {
      return url;
    }
    if (url == androidEmulatorAuthUrl) {
      return localAuthUrl;
    }
    return url;
  }
}
