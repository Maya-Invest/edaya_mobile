import 'package:edaya_shared/edaya_shared.dart';

/// API and dev credential configuration for the guardian app.
///
/// The base URL defaults to staging; override at build time with
/// `--dart-define=API_URL=http://10.0.2.2:9999` (Android emulator → local), or change
/// at runtime from Developer settings.
///
/// Flutter web runs in the browser and calls the API directly, so the API must
/// allow your dev origin via CORS (localhost origins are allowed in development).
abstract final class ApiConfig {
  static String get baseUrl => ApiBaseUrlConfig.baseUrl;

  static const devGuardianEmail = String.fromEnvironment(
    'DEV_GUARDIAN_EMAIL',
    defaultValue: 'c.laurent@mail.com',
  );

  static const devPassword = String.fromEnvironment(
    'DEV_PASSWORD',
    defaultValue: 'DevPassword1!',
  );
}
