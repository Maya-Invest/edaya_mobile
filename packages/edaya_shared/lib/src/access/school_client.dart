import 'package:edaya_api_client/edaya_api_client.dart' as api;
import 'package:edaya_auth/edaya_auth.dart';
import 'package:levit_flutter/levit_flutter.dart';

import '../config/api_base_url_config.dart';

typedef SchoolClientFactory = api.SchoolClient Function();

api.SchoolClient createEdayaSchoolClient(
  AuthClient authClient, {
  String? Function()? getAcademicYearId,
  String? Function()? getActorKind,
  String? Function()? getActorId,
  String? Function()? getSchoolId,
}) {
  return api.createSchoolClient(
    api.HttpTransport(
      baseUrl: ApiBaseUrlConfig.apiBaseUrl,
      client: authClient.businessHttpClient,
      getAccessToken: authClient.getAccessToken,
      invalidateAccessToken: authClient.invalidateAccessToken,
      getAcademicYearId: getAcademicYearId,
      getActorKind: getActorKind,
      getActorId: getActorId,
      getSchoolId: getSchoolId,
    ),
  );
}

/// Registers a [SchoolClientFactory] that resolves the academic-year header at
/// call time.
void registerSchoolClientFactory(
  LevitScope scope, {
  required String? Function() getAcademicYearId,
  String? Function()? getActorKind,
  String? Function()? getActorId,
  String? Function()? getSchoolId,
}) {
  scope.put<SchoolClientFactory>(
    () =>
        () => createEdayaSchoolClient(
          scope.find<AuthClient>(),
          getAcademicYearId: getAcademicYearId,
          getActorKind: getActorKind,
          getActorId: getActorId,
          getSchoolId: getSchoolId,
        ),
    permanent: true,
  );
}
