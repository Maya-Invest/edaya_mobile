import 'package:edaya_shared/edaya_shared.dart';
import 'package:flutter/foundation.dart';

/// API and dev credential configuration for the teacher app.
///
/// The base URL defaults to local dev (`http://localhost:9999`). Override at build
/// time with `--dart-define=API_URL=...`, or change at runtime from Developer
/// settings (debug builds only).
abstract final class ApiConfig {
  static String get baseUrl => ApiBaseUrlConfig.baseUrl;

  static String get devTeacherEmail => kDebugMode
      ? const String.fromEnvironment(
          'DEV_TEACHER_EMAIL',
          defaultValue: 'a.toure@ecole-ci.edaya.dev',
        )
      : '';

  static String get devPassword => kDebugMode
      ? const String.fromEnvironment(
          'DEV_PASSWORD',
          defaultValue: 'DevPassword1!',
        )
      : '';
}
