import 'package:edaya_api_client/edaya_api_client.dart' as api;
import 'package:edaya_auth/edaya_auth.dart';

import '../config/api_base_url_config.dart';

api.SchoolClient createEdayaSchoolClient(
  AuthClient authClient, {
  String? Function()? getAcademicYearId,
}) {
  return api.createSchoolClient(
    api.HttpTransport(
      baseUrl: ApiBaseUrlConfig.baseUrl,
      client: authClient.httpClient,
      cookieHeader: edayaHttpUsesBrowserCredentials
          ? null
          : () => authClient.cookieHeader,
      getAcademicYearId: getAcademicYearId,
    ),
  );
}
