import 'package:edaya_shared/edaya_shared.dart';
import 'package:flutter/foundation.dart';

abstract final class ApiConfig {
  static String get baseUrl => ApiBaseUrlConfig.baseUrl;

  static String get devTeacherEmail => kDebugMode
      ? const String.fromEnvironment(
          'DEV_TEACHER_EMAIL',
          defaultValue: 'a.toure@ecole-ci.edaya.dev',
        )
      : '';
}
