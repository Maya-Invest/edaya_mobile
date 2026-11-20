import 'package:flutter/foundation.dart';

/// Controls whether developer settings are shown in the UI.
abstract final class DeveloperSettingsConfig {
  DeveloperSettingsConfig._();

  /// Runtime API switching and dev diagnostics are limited to debug builds.
  static bool get enabled => kDebugMode;
}
