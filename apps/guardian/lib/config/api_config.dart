import 'package:edaya_shared/edaya_shared.dart';

/// API and dev credential configuration for the next guardian app.
///
/// Base URL: SharedPreferences override → `--dart-define=API_URL` → app default.
/// Authentication uses the selected API URL.
abstract final class ApiConfig {
  static String get baseUrl => ApiBaseUrlConfig.baseUrl;

  static const devGuardianEmail = String.fromEnvironment(
    'DEV_GUARDIAN_EMAIL',
    defaultValue: 'm.kone@mail.ci',
  );
}
