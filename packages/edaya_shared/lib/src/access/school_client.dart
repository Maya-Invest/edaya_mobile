import 'package:edaya_api_client/edaya_api_client.dart' as api;
import 'package:edaya_auth/edaya_auth.dart';
import 'package:levit_flutter/levit_flutter.dart';

import '../config/api_base_url_config.dart';

typedef SchoolClientFactory = api.SchoolClient Function();

api.SchoolClient createEdayaSchoolClient(
  AuthClient authClient, {
  String? Function()? getAcademicYearId,
  String? Function()? getActorKind,
}) {
  return api.createSchoolClient(
    api.HttpTransport(
      baseUrl: ApiBaseUrlConfig.baseUrl,
      client: authClient.httpClient,
      cookieHeader: edayaHttpUsesBrowserCredentials
          ? null
          : () => authClient.cookieHeader,
      getAcademicYearId: getAcademicYearId,
      getActorKind: getActorKind,
    ),
  );
}

/// Registers a [SchoolClientFactory] that resolves the academic-year header at
/// call time.
void registerSchoolClientFactory(
  LevitScope scope, {
  required String? Function() getAcademicYearId,
  String? Function()? getActorKind,
}) {
  scope.put<SchoolClientFactory>(
    () =>
        () => createEdayaSchoolClient(
          scope.find<AuthClient>(),
          getAcademicYearId: getAcademicYearId,
          getActorKind: getActorKind,
        ),
    permanent: true,
  );
}
