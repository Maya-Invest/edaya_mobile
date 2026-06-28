import 'package:edaya_shared/edaya_shared.dart';

/// API and dev credential configuration for the teacher app.
///
/// The base URL can be set at build time with
/// `--dart-define=API_URL=http://10.0.2.2:9999` (Android emulator), or changed
/// at runtime from Developer settings (debug builds only).
abstract final class ApiConfig {
  static String get baseUrl => ApiBaseUrlConfig.baseUrl;

  static const devStaffEmail = String.fromEnvironment(
    'DEV_STAFF_EMAIL',
    defaultValue: 'm.dupont@school.edu',
  );

  static const devPassword = String.fromEnvironment(
    'DEV_PASSWORD',
    defaultValue: 'DevPassword1!',
  );
}
