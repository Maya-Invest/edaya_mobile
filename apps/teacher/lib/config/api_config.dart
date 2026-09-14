import 'package:edaya_shared/edaya_shared.dart';

/// API and dev credential configuration for the teacher app.
///
/// The School API defaults to `https://staging.school.api.edayaplus.com`.
/// Override it with `--dart-define=API_URL=...`; Identity is configured
/// independently with `--dart-define=AUTH_URL=...`.
abstract final class ApiConfig {
  static String get baseUrl => ApiBaseUrlConfig.baseUrl;

  static const devTeacherEmail = String.fromEnvironment(
    'DEV_TEACHER_EMAIL',
    defaultValue: 'a.toure@ecole-ci.edaya.dev',
  );

  static const devPassword = String.fromEnvironment(
    'DEV_PASSWORD',
    defaultValue: 'DevPassword1!',
  );
}
