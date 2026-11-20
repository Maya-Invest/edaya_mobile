import 'package:http/http.dart' as http;

bool get edayaHttpUsesBrowserCredentials => false;

http.Client createEdayaHttpClient({bool withCredentials = true}) =>
    http.Client();
