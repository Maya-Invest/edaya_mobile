import 'package:flutter/foundation.dart';

/// Controls whether developer settings are shown in the UI.
abstract final class DeveloperSettingsConfig {
  DeveloperSettingsConfig._();

  /// Production builds always use the compiled API URL.
  static const production = bool.fromEnvironment(
    'PRODUCTION',
    defaultValue: !kDebugMode,
  );

  /// Account-screen developer settings are available in local debug builds.
  static const enabled = kDebugMode && !production;
}
