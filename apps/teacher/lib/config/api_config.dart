import 'package:edaya_shared/edaya_shared.dart';
import 'package:flutter/foundation.dart';

/// API and dev credential configuration for the teacher app.
///
/// The School API defaults to staging unless `--dart-define=API_URL=...` or a
/// SharedPreferences override is set. Authentication uses the selected API URL.
abstract final class ApiConfig {
  static String get baseUrl => ApiBaseUrlConfig.baseUrl;

  static String get devTeacherEmail => kDebugMode
      ? const String.fromEnvironment(
          'DEV_TEACHER_EMAIL',
          defaultValue: 'a.toure@ecole-ci.edaya.dev',
        )
      : '';
}
