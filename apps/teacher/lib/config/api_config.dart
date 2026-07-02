import 'package:edaya_shared/edaya_shared.dart';

/// API and dev credential configuration for the teacher app.
///
/// The base URL defaults to staging; override at build time with
/// `--dart-define=API_URL=http://10.0.2.2:9999` (Android emulator → local), or change
/// at runtime from Developer settings.
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
