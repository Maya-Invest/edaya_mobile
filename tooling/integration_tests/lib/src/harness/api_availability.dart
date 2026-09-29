import 'dart:async';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../config/integration_config.dart';

const Duration _probeTimeout = Duration(seconds: 5);

/// Returns a skip reason when integration tests should not run.
Future<String?> resolveIntegrationSkipReason() async {
  if (!IntegrationConfig.isEnabled) {
    return 'Set EDAYA_INTEGRATION_TESTS=1 to run live API integration tests';
  }

  final config = IntegrationConfig.fromEnvironment();
  final client = http.Client();

  try {
    final response = await client
        .get(Uri.parse('${config.authUrl}/auth/edaya/methods'))
        .timeout(_probeTimeout);
    if (response.statusCode != 200) {
      throw StateError(
        'Identity fixture readiness failed: HTTP ${response.statusCode}',
      );
    }
    return null;
  } on SocketException {
    throw StateError('Identity fixture not reachable at ${config.authUrl}');
  } on HttpException {
    throw StateError('Identity fixture not reachable at ${config.authUrl}');
  } on TimeoutException {
    throw StateError(
      'Identity fixture not reachable at ${config.authUrl} (timed out)',
    );
  } finally {
    client.close();
  }
}
