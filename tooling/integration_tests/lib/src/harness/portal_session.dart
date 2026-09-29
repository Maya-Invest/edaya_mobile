import 'dart:convert';
import 'dart:io';
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
    final fixtureSessions = Platform.environment['SEED_AUTH_SESSIONS_FILE'];
    if (fixtureSessions != null) {
      final credentials =
          jsonDecode(await File(fixtureSessions).readAsString()) as Map;
      final credential = credentials[config.email] as String?;
      if (credential == null) {
        throw StateError('Missing fixture Account session');
      }
      authClient.restoreRenewalCredential(credential);
      final session = await authClient.getSession();
      if (!session.isSuccess || session.data == null) {
        throw StateError('Fixture Account session is not valid');
      }
    } else {
      final send = await authClient.sendEmailOtp(email: config.email);
      if (!send.isSuccess) {
        throw StateError(
          'OTP send failed for ${config.email}: ${send.error?.message ?? 'unknown error'}',
        );
      }

      final mailbox = Platform.environment['EDAYA_TEST_OTP_FILE'];
      String code;
      if (mailbox != null) {
        final messages = (await File(mailbox).readAsLines())
            .where((line) => line.isNotEmpty)
            .map((line) => jsonDecode(line) as Map<String, dynamic>);
        final delivered = messages.where(
          (message) =>
              message['channel'] == 'email' &&
              message['destination'] == config.email.trim().toLowerCase(),
        );
        if (delivered.isEmpty) {
          throw StateError('Required OTP transport delivery missing');
        }
        code = delivered.last['code'] as String;
      } else {
        final peeked = await authClient.peekDevLastOtp(email: config.email);
        if (!peeked.isSuccess || peeked.data == null) {
          throw StateError('Local OTP fixture delivery unavailable');
        }
        code = peeked.data!;
      }

      final signIn = await authClient.signInWithEmailOtp(
        email: config.email,
        otp: code,
      );

      if (!signIn.isSuccess || signIn.data == null) {
        throw StateError(
          'Sign-in failed for ${config.email}: ${signIn.error?.message ?? 'unknown error'}',
        );
      }
    }

    final yearId = academicYearId ?? config.academicYearId;
    String? resolvedActorId;
    String? resolvedSchoolId;
    final schoolClient = createSchoolClient(
      HttpTransport(
        baseUrl: config.baseUrl,
        client: authClient.businessHttpClient,
        getAccessToken: authClient.getAccessToken,
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
