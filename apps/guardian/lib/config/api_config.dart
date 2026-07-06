import 'package:edaya_shared/edaya_shared.dart';

/// API and dev credential configuration for the guardian app.
///
/// The base URL defaults to `localhost` on iOS simulators and `10.0.2.2` on
/// Android emulators. Override at build time with `--dart-define=API_URL=...`,
/// or change at runtime from Developer settings.
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
