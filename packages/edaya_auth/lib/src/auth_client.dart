import 'dart:convert';

import 'package:http/http.dart' as http;

import 'auth_error.dart';
import 'auth_result.dart';
import 'auth_session.dart';
import 'auth_user.dart';
import 'cookie_jar.dart';

typedef AuthBaseUrlProvider = String Function();

class AuthClient {
  AuthClient({
    required String baseUrl,
    this.basePath = '/auth',
    String? origin,
    AuthBaseUrlProvider? baseUrlProvider,
    http.Client? client,
    CookieJar? cookieJar,
  }) : _baseUrl = baseUrl,
       _baseUrlProvider = baseUrlProvider,
       _client = client ?? http.Client(),
       _cookieJar = cookieJar ?? CookieJar(),
       _originOverride = origin;

  final String _baseUrl;
  final AuthBaseUrlProvider? _baseUrlProvider;
  final String basePath;
  final String? _originOverride;
  final http.Client _client;
  final CookieJar _cookieJar;

  String get baseUrl => _baseUrlProvider?.call() ?? _baseUrl;

  String get _origin => _originOverride ?? Uri.parse(baseUrl).origin;

  CookieJar get cookieJar => _cookieJar;

  http.Client get httpClient => _client;

  String? get cookieHeader => _cookieJar.headerValue();

  Future<AuthResult<AuthSessionSnapshot?>> getSession() async {
    try {
      final response = await _send('GET', '/get-session');
      if (response.statusCode == 401 || response.statusCode == 404) {
        return const AuthResult.success(null);
      }

      final body = _decodeBody(response);
      if (response.statusCode >= 400) {
        return AuthResult.failure(_readError(body));
      }

      if (body == null) {
        return const AuthResult.success(null);
      }

      if (body is Map && body['session'] == null) {
        return const AuthResult.success(null);
      }

      return AuthResult.success(
        AuthSessionSnapshot.fromJson(Map<String, dynamic>.from(body as Map)),
      );
    } on http.ClientException catch (error) {
      return AuthResult.failure(_networkError(error));
    }
  }

  Future<AuthResult<AuthUser>> signInWithEmail({
    required String email,
    required String password,
  }) {
    return _postAuthUser('/sign-in/email', {
      'email': email,
      'password': password,
    });
  }

  Future<AuthResult<void>> sendEmailOtp({
    required String email,
    String type = 'sign-in',
  }) async {
    final response = await _send('POST', '/email-otp/send-verification-otp', {
      'email': email,
      'type': type,
    });
    return _readVoidResult(response);
  }

  Future<AuthResult<AuthUser>> signInWithEmailOtp({
    required String email,
    required String otp,
  }) {
    return _postAuthUser('/sign-in/email-otp', {'email': email, 'otp': otp});
  }

  Future<AuthResult<AuthUser>> signUpWithEmail({
    required String email,
    required String password,
    required String name,
  }) {
    return _postAuthUser('/sign-up/email', {
      'email': email,
      'password': password,
      'name': name,
    });
  }

  Future<AuthResult<void>> signOut() async {
    final response = await _send('POST', '/sign-out', const {});
    if (response.statusCode >= 400) {
      final body = _decodeBody(response);
      return AuthResult.failure(_readError(body));
    }

    _cookieJar.clear();
    return const AuthResult.success(null);
  }

  Future<AuthResult<AuthUser>> _postAuthUser(
    String path,
    Map<String, dynamic> payload,
  ) async {
    try {
      final response = await _send('POST', path, payload);
      final body = _decodeBody(response);

      if (response.statusCode >= 400) {
        return AuthResult.failure(_readError(body));
      }

      final userJson = _readUserJson(body);
      if (userJson == null) {
        return const AuthResult.failure(
          AuthError(message: 'Authentication response did not include a user'),
        );
      }

      return AuthResult.success(AuthUser.fromJson(userJson));
    } on http.ClientException catch (error) {
      return AuthResult.failure(_networkError(error));
    }
  }

  Future<AuthResult<void>> _readVoidResult(http.Response response) async {
    final body = _decodeBody(response);
    if (response.statusCode >= 400) {
      return AuthResult.failure(_readError(body));
    }

    if (body is Map && body['error'] != null) {
      return AuthResult.failure(
        AuthError.fromJson(Map<String, dynamic>.from(body['error'] as Map)),
      );
    }

    return const AuthResult.success(null);
  }

  Map<String, dynamic>? _readUserJson(Object? body) {
    if (body is! Map) {
      return null;
    }

    final user = body['user'];
    if (user is Map) {
      return Map<String, dynamic>.from(user);
    }

    final data = body['data'];
    if (data is Map) {
      final nestedUser = data['user'];
      if (nestedUser is Map) {
        return Map<String, dynamic>.from(nestedUser);
      }
    }

    return null;
  }

  AuthError _readError(Object? body) {
    if (body is Map) {
      final error = body['error'];
      if (error is Map) {
        return AuthError.fromJson(Map<String, dynamic>.from(error));
      }

      final message = body['message'];
      if (message is String) {
        return AuthError(
          message: normalizeAuthErrorMessage(message),
          code: body['code'] as String?,
        );
      }
    }

    return AuthError(
      message: normalizeAuthErrorMessage(body?.toString() ?? 'Authentication failed'),
    );
  }

  AuthError _networkError(http.ClientException error) {
    return AuthError(
      message: 'Cannot reach API at $baseUrl. Is the server running?',
      code: 'NETWORK_ERROR',
    );
  }

  Object? _decodeBody(http.Response response) {
    if (response.body.isEmpty) {
      return null;
    }

    try {
      return jsonDecode(response.body);
    } catch (_) {
      return response.body;
    }
  }

  Future<http.Response> _send(
    String method,
    String path, [
    Map<String, dynamic>? payload,
  ]) async {
    final uri = _resolveUri(path);
    final headers = <String, String>{
      'Accept': 'application/json',
      'Origin': _origin,
      if (method != 'GET' && method != 'HEAD')
        'Content-Type': 'application/json',
    };

    final cookies = _cookieJar.headerValue();
    if (cookies != null) {
      headers['Cookie'] = cookies;
    }

    final response = await _client.send(
      http.Request(method, uri)
        ..headers.addAll(headers)
        ..body = payload == null
            ? (method == 'GET' || method == 'HEAD' ? '' : '{}')
            : jsonEncode(payload),
    );

    final bodyBytes = await response.stream.toBytes();
    final responseBody = utf8.decode(bodyBytes);
    _cookieJar.updateFromHeader(response.headers['set-cookie']);

    return http.Response(
      responseBody,
      response.statusCode,
      headers: response.headers,
      request: response.request,
    );
  }

  Uri _resolveUri(String path) {
    final normalizedPath = path.startsWith('/') ? path : '/$path';
    final normalizedBasePath = basePath.endsWith('/')
        ? basePath.substring(0, basePath.length - 1)
        : basePath;
    final base = Uri.parse(baseUrl.endsWith('/') ? baseUrl : '$baseUrl/');
    return base.resolve('${normalizedBasePath.substring(1)}$normalizedPath');
  }
}
