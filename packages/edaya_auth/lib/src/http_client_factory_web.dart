import 'package:http/browser_client.dart';
import 'package:http/http.dart' as http;

bool get edayaHttpUsesBrowserCredentials => true;

http.Client createEdayaHttpClient() {
  final client = BrowserClient();
  client.withCredentials = true;
  return client;
}
