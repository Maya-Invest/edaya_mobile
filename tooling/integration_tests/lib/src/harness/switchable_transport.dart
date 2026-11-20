import 'dart:io';
import 'package:http/http.dart' as http;

/// Fault injection at the HTTP boundary. Reads and identity requests stay real.
class SwitchableTransport extends http.BaseClient {
  final http.Client _inner = http.Client();
  bool offline = false;
  int blockedWrites = 0;
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    if (offline && request.url.path.contains('/commands/')) {
      blockedWrites++;
      throw const SocketException('Integration transport is offline');
    }
    return _inner.send(request);
  }

  @override
  void close() => _inner.close();
}
