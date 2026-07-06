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
    await client
        .get(Uri.parse('${config.baseUrl}/auth/get-session'))
        .timeout(_probeTimeout);
    return null;
  } on SocketException {
    return 'API not reachable at ${config.baseUrl}';
  } on HttpException {
    return 'API not reachable at ${config.baseUrl}';
  } on TimeoutException {
    return 'API not reachable at ${config.baseUrl} (timed out)';
  } finally {
    client.close();
  }
}
