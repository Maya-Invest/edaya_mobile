/// Default API base URL for local development.
///
/// Override at runtime with:
/// `flutter run --dart-define=API_URL=http://10.0.2.2:9999` (Android emulator)
///
/// Flutter web runs in the browser and calls the API directly, so the API must
/// allow your dev origin via CORS (localhost origins are allowed in development).
abstract final class ApiConfig {
  static const baseUrl = String.fromEnvironment(
    'API_URL',
    defaultValue: 'http://localhost:9999',
  );

  static const devGuardianEmail = String.fromEnvironment(
    'DEV_GUARDIAN_EMAIL',
    defaultValue: 'c.laurent@mail.com',
  );

  static const devPassword = String.fromEnvironment(
    'DEV_PASSWORD',
    defaultValue: 'DevPassword1!',
  );
}
