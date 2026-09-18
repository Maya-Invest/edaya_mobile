import 'package:edaya_auth/edaya_auth.dart';
import 'package:levit_flutter/levit_flutter.dart';

import '../config/api_base_url_config.dart';
import '../features/settings/app_settings_controller.dart';

/// Registers shared Edaya clients in the Levit scope.
void registerEdayaDependencies(
  LevitScope scope, {
  required CookieJar cookieJar,
}) {
  scope.put<AppSettingsController>(
    () => AppSettingsController(),
    permanent: true,
  );
  scope.put<CookieJar>(() => cookieJar, permanent: true);
  scope.put<AuthClient>(
    () => AuthClient(
      baseUrl: ApiBaseUrlConfig.authBaseUrl,
      baseUrlProvider: () => ApiBaseUrlConfig.authBaseUrl,
      client: createEdayaHttpClient(),
      cookieJar: cookieJar,
    ),
    permanent: true,
  );
}
