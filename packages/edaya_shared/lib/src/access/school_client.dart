import 'package:edaya_api_client/edaya_api_client.dart' as api;
import 'package:edaya_auth/edaya_auth.dart';
import 'package:levit_flutter/levit_flutter.dart';

import '../config/api_base_url_config.dart';

typedef SchoolClientFactory = api.SchoolClient Function();

/// Native apps mint school JWTs from the stored renewal credential.
/// Flutter web has no renewal credential; Identity issues the JWT from the
/// browser cookie session instead.
bool canIssueSchoolAccessToken(AuthClient authClient) =>
    edayaHttpUsesBrowserCredentials || authClient.renewalCredential != null;

api.SchoolClient createEdayaSchoolClient(
  AuthClient authClient, {
  String? Function()? getAcademicYearId,
  String? Function()? getActorKind,
  String? Function()? getActorId,
  String? Function()? getSchoolId,
  api.Transport Function(api.Transport)? decorateTransport,
}) {
  final transport = api.HttpTransport(
    baseUrl: ApiBaseUrlConfig.apiBaseUrl,
    client: authClient.businessHttpClient,
    getAccessToken: ({required Uri resource}) async {
      if (!canIssueSchoolAccessToken(authClient)) {
        return null;
      }
      return authClient.getAccessToken(resource: resource);
    },
    invalidateAccessToken: authClient.invalidateAccessToken,
    getAcademicYearId: getAcademicYearId,
    getActorKind: getActorKind,
    getActorId: getActorId,
    getSchoolId: getSchoolId,
  );
  return api.createSchoolClient(
    decorateTransport?.call(transport) ?? transport,
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
  api.Transport Function(api.Transport)? decorateTransport,
}) {
  scope.put<SchoolClientFactory>(
    () =>
        () => createEdayaSchoolClient(
          scope.find<AuthClient>(),
          getAcademicYearId: getAcademicYearId,
          getActorKind: getActorKind,
          getActorId: getActorId,
          getSchoolId: getSchoolId,
          decorateTransport: decorateTransport,
        ),
    permanent: true,
  );
}
