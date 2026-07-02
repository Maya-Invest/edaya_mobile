/// Controls whether developer settings are shown in the UI.
abstract final class DeveloperSettingsConfig {
  DeveloperSettingsConfig._();

  /// Intentionally enabled in release/production builds so API endpoints can
  /// be switched at runtime without rebuilding the app.
  static const enabled = true;
}
