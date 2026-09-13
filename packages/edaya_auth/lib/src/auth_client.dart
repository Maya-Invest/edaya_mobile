import 'dart:convert';

import 'package:http/http.dart' as http;

import 'auth_error.dart';
import 'auth_result.dart';
import 'auth_session.dart';
import 'auth_user.dart';
import 'cookie_jar.dart';
import 'http_client_factory.dart';

typedef AuthBaseUrlProvider = String Function();

class _ResourceTokenState {
  String? token;
  DateTime? expiresAt;
  Future<String>? pending;
}

Uri canonicalApiOrigin(Uri resource) {
  if ((resource.scheme != 'http' && resource.scheme != 'https') ||
      resource.host.isEmpty ||
      resource.host.contains('*') ||
      resource.hasQuery ||
      resource.hasFragment ||
      resource.userInfo.isNotEmpty ||
      (resource.path.isNotEmpty && resource.path != '/')) {
    throw const AuthError(message: 'Invalid API origin');
  }
  return Uri.parse(resource.origin);
}

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

  late final http.Client businessHttpClient = edayaHttpUsesBrowserCredentials
      ? createEdayaHttpClient(withCredentials: false)
      : _client;

  String? get cookieHeader => null;

  String? _renewalCredential;
  String? _credentialOrigin;
  final Map<String, _ResourceTokenState> _accessTokens = {};
  int _generation = 0;

  String? get renewalCredential => _renewalCredential;

  void restoreRenewalCredential(String credential) {
    clearCredentials();
    _renewalCredential = credential;
    _credentialOrigin = Uri.parse(baseUrl).origin;
  }

  void clearCredentials() {
    _generation++;
    _renewalCredential = null;
    _credentialOrigin = null;
    _accessTokens.clear();
    _cookieJar.clear();
  }

  void invalidateAccessToken({required Uri resource, required String token}) {
    final origin = canonicalApiOrigin(resource).origin;
    final state = _accessTokens[origin];
    if (state?.token == token) {
      state?.token = null;
      state?.expiresAt = null;
    }
  }

  Future<String> getAccessToken({required Uri resource}) async {
    _checkOrigin();
    final origin = canonicalApiOrigin(resource).origin;
    final state = _accessTokens.putIfAbsent(origin, _ResourceTokenState.new);
    if (state.token != null &&
        state.expiresAt!.isAfter(
          DateTime.now().add(const Duration(seconds: 30)),
        )) {
      return state.token!;
    }
    return state.pending ??= _issueAccessToken(_generation, origin, state);
  }

  Future<String> _issueAccessToken(
    int generation,
    String origin,
    _ResourceTokenState state,
  ) async {
    try {
      final response = await _send('POST', '/edaya/access-token', {
        'resource': origin,
      });
      final body = _decodeBody(response);
      if (response.statusCode >= 400) {
        if (response.statusCode == 401 && generation == _generation) {
          clearCredentials();
        }
        throw _readError(body);
      }
      if (generation != _generation) {
        throw const AuthError(message: 'Authentication changed during renewal');
      }
      final data = Map<String, dynamic>.from(body as Map);
      final token = data['accessToken'] as String;
      final expiresAt = DateTime.parse(data['expiresAt'] as String);
      final segments = token.split('.');
      if (segments.length != 3 ||
          segments.any((segment) => segment.isEmpty) ||
          !expiresAt.isAfter(DateTime.now())) {
        throw const AuthError(message: 'Invalid API token response');
      }
      state.token = token;
      state.expiresAt = expiresAt;
      return token;
    } finally {
      if (generation == _generation) state.pending = null;
    }
  }

  void _checkOrigin() {
    if (_credentialOrigin != null &&
        _credentialOrigin != Uri.parse(baseUrl).origin) {
      clearCredentials();
    }
  }

  Future<AuthResult<AuthSessionSnapshot?>> getSession() async {
    try {
      final response = await _send('POST', '/edaya/session', const {});
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
    return _postAuthUser(
      edayaHttpUsesBrowserCredentials
          ? '/sign-in/email'
          : '/edaya/native/sign-in/email',
      {'email': email, 'password': password},
    );
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
    return _postAuthUser(
      edayaHttpUsesBrowserCredentials
          ? '/sign-in/email-otp'
          : '/edaya/native/sign-in/email-otp',
      {'email': email, 'otp': otp},
    );
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
    try {
      final response = await _send('POST', '/edaya/sign-out', const {});
      return await _readVoidResult(response);
    } finally {
      clearCredentials();
    }
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

      clearCredentials();
      if (!edayaHttpUsesBrowserCredentials && path.contains('/sign-in/')) {
        final credential = (body as Map)['renewalCredential'];
        if (credential is! String || !credential.contains('.')) {
          return const AuthResult.failure(
            AuthError(message: 'Login did not return a renewal credential'),
          );
        }
        restoreRenewalCredential(credential);
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
      message: normalizeAuthErrorMessage(
        body?.toString() ?? 'Authentication failed',
      ),
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
    _checkOrigin();
    final uri = _resolveUri(path);
    final headers = <String, String>{
      'Accept': 'application/json',
      'Origin': _origin,
      if (method != 'GET' && method != 'HEAD')
        'Content-Type': 'application/json',
    };

    if (!edayaHttpUsesBrowserCredentials &&
        path.startsWith('/edaya/') &&
        !path.startsWith('/edaya/native/') &&
        _renewalCredential != null) {
      headers['Authorization'] = 'Bearer $_renewalCredential';
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
