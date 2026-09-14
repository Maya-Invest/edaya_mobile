import 'package:edaya_shared/edaya_shared.dart';

/// API and dev credential configuration for the guardian app.
///
/// The School API defaults to `https://staging.school.api.edayaplus.com`.
/// Override it with `--dart-define=API_URL=...`; Identity is configured
/// independently with `--dart-define=AUTH_URL=...`.
///
/// Flutter web runs in the browser and calls the API directly, so the API must
/// allow your dev origin via CORS (localhost origins are allowed in development).
abstract final class ApiConfig {
  static String get baseUrl => ApiBaseUrlConfig.baseUrl;

  static const devGuardianEmail = String.fromEnvironment(
    'DEV_GUARDIAN_EMAIL',
    defaultValue: 'm.kone@mail.ci',
  );

  static const devPassword = String.fromEnvironment(
    'DEV_PASSWORD',
    defaultValue: 'DevPassword1!',
  );
}
