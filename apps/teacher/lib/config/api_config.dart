import 'package:edaya_shared/edaya_shared.dart';

/// API and dev credential configuration for the teacher app.
///
/// The base URL defaults to local dev (`http://localhost:9999`). Override at build
/// time with `--dart-define=API_URL=...`, or change at runtime from Developer settings.
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
