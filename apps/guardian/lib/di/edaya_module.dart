import 'package:edaya_api_client/edaya_api_client.dart' as api;
import 'package:edaya_auth/edaya_auth.dart';
import 'package:levit_flutter/levit_flutter.dart';

import '../config/api_config.dart';

/// Registers shared Edaya clients in the Levit scope.
void registerEdayaDependencies(
  LevitScope scope, {
  required CookieJar cookieJar,
}) {
  scope.put<CookieJar>(() => cookieJar, permanent: true);
  scope.put<AuthClient>(
    () => AuthClient(
      baseUrl: ApiConfig.baseUrl,
      client: createEdayaHttpClient(),
      cookieJar: cookieJar,
    ),
    permanent: true,
  );
}

api.SchoolClient createEdayaSchoolClient(AuthClient authClient) {
  return api.createSchoolClient(
    api.HttpTransport(
      baseUrl: ApiConfig.baseUrl,
      client: authClient.httpClient,
      cookieHeader: edayaHttpUsesBrowserCredentials
          ? null
          : () => authClient.cookieHeader,
    ),
  );
}
