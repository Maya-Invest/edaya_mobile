import 'package:http/browser_client.dart';
import 'package:http/http.dart' as http;

bool get edayaHttpUsesBrowserCredentials => true;

http.Client createEdayaHttpClient({bool withCredentials = true}) {
  final client = BrowserClient();
  client.withCredentials = withCredentials;
  return client;
}
