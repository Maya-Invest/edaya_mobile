import 'package:edaya_shared/edaya_shared.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// API and dev credential configuration for the teacher app.
///
/// Authentication and school data use the same selected API.
abstract final class ApiConfig {
  static Future<String> resolveDefaultUrl() async {
    if (kDebugMode && !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
      const runtime = MethodChannel('edaya_teacher_v2/runtime');
      if (await runtime.invokeMethod<bool>('isSimulator') == true) {
        return ApiBaseUrlConfig.localUrl;
      }
    }
    return ApiBaseUrlConfig.stagingUrl;
  }

  static String get baseUrl => ApiBaseUrlConfig.baseUrl;

  static String get devTeacherEmail => kDebugMode
      ? const String.fromEnvironment(
          'DEV_TEACHER_EMAIL',
          defaultValue: 'a.toure@ecole-ci.edaya.dev',
        )
      : '';
}
