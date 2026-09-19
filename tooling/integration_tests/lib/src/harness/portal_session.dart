import 'package:edaya_api_client/edaya_api_client.dart';
import 'package:edaya_auth/edaya_auth.dart';

import '../config/integration_config.dart';

/// Authenticated portal session for live API integration tests.
class PortalSession {
  PortalSession({
    required this.config,
    required this.authClient,
    required this.schoolClient,
    required this.actorKind,
  });

  final IntegrationConfig config;
  final AuthClient authClient;
  final SchoolClient schoolClient;
  final String actorKind;

  static Future<PortalSession> signIn({
    required IntegrationConfig config,
    required String actorKind,
    String? academicYearId,
  }) async {
    final authClient = AuthClient(baseUrl: config.authUrl);
    final send = await authClient.sendEmailOtp(email: config.email);
    if (!send.isSuccess) {
      throw StateError(
        'OTP send failed for ${config.email}: ${send.error?.message ?? 'unknown error'}',
      );
    }
    final peek = await authClient.peekDevLastOtp(email: config.email);
    final otp = peek.data?.trim() ?? '';
    if (!peek.isSuccess || otp.isEmpty) {
      throw StateError(
        'Could not read local OTP for ${config.email}: ${peek.error?.message ?? 'empty'}',
      );
    }
    final signIn = await authClient.signInWithEmailOtp(
      email: config.email,
      otp: otp,
    );

    if (!signIn.isSuccess || signIn.data == null) {
      throw StateError(
        'Sign-in failed for ${config.email}: ${signIn.error?.message ?? 'unknown error'}',
      );
    }

    final yearId = academicYearId ?? config.academicYearId;
    String? resolvedActorId;
    String? resolvedSchoolId;
    final schoolClient = createSchoolClient(
      HttpTransport(
        baseUrl: config.baseUrl,
        client: authClient.businessHttpClient,
        getAccessToken: ({required Uri resource}) {
          return authClient.getAccessToken(resource: resource);
        },
        invalidateAccessToken: authClient.invalidateAccessToken,
        getAcademicYearId: () => yearId,
        getActorKind: () => actorKind,
        getActorId: () => resolvedActorId,
        getSchoolId: () => resolvedSchoolId,
      ),
    );

    final grants = await schoolClient.effectiveGrants();
    resolvedActorId = grants.actorId;
    resolvedSchoolId = grants.schoolId;

    return PortalSession(
      config: config,
      authClient: authClient,
      schoolClient: schoolClient,
      actorKind: actorKind,
    );
  }
}
