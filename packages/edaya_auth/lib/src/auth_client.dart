import 'dart:convert';
import 'dart:math';

import 'package:edaya_api_client/edaya_api_client.dart' as contract;
import 'package:http/http.dart' as http;

import 'auth_error.dart';
import 'auth_result.dart';
import 'auth_session.dart';
import 'auth_user.dart';
import 'cookie_jar.dart';
import 'http_client_factory.dart';

/// Backend-owned, versioned terms shown before starting authentication.
class AuthTerms {
  const AuthTerms({required this.enforced, required this.document});
  final bool enforced;
  final contract.AuthTermsDocument? document;
  factory AuthTerms.fromJson(Map<String, dynamic> json) {
    final response = contract.AuthTerms.fromJson(json);
    return AuthTerms(
      enforced: response.enforced,
      document: response.document == null
          ? null
          : contract.AuthTermsDocument.fromJson(response.document!),
    );
  }
}

typedef AuthTermsAcceptance = contract.AuthTermsAcceptance;

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
    this.enableTestOtpInDebug = false,
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
  final directoryCache = contract.ConditionalReadCache();

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
    directoryCache.clear();
    _generation++;
    _renewalCredential = null;
    _credentialOrigin = null;
    _accessTokens.clear();
    _cookieJar.clear();
    pendingChallenge = null;
    pendingStep = null;
    primaryStatus = null;
    registration = null;
    emailRetryAt = 0;
    _otpRequests.clear();
    _uncertainOtpRequest = null;
    enrollmentSecret = null;
    recoveryCodes = [];
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
      final response = await _send(
        'POST',
        '/edaya/access-token',
        contract.AuthResource(resource: origin).toJson(),
      );
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
      final data = contract.AuthAccessToken.fromJson(
        Map<String, dynamic>.from(body as Map),
      );
      final token = data.accessToken;
      final expiresAt = DateTime.parse(data.expiresAt);
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

  contract.AuthRegistrationOffer? registration;
  int emailRetryAt = 0;
  int get emailRetrySeconds =>
      ((emailRetryAt - DateTime.now().millisecondsSinceEpoch) / 1000)
          .ceil()
          .clamp(0, 3600);
  String? pendingChallenge;
  String? pendingStep;
  String? enrollmentSecret;
  List<String> recoveryCodes = [];

  OtpStatus? primaryStatus;
  final Map<String, String> _otpRequests = {};
  ({String path, Map<String, dynamic> payload})? _uncertainOtpRequest;
  bool get canRetryOtpRequest => _uncertainOtpRequest != null;

  /// Recovers a lost send response with its original idempotency key.
  Future<AuthResult<void>> retryOtpRequest() async {
    final pending = _uncertainOtpRequest;
    if (pending == null) {
      return const AuthResult.failure(AuthError(message: 'No pending request'));
    }
    return _requestOtp(pending.path, pending.payload);
  }

  /// Advertised availability; delivery choice is owned by Identity.
  Future<bool> phoneAvailable() async {
    final response = await _send('GET', '/edaya/methods');
    final body = _decodeBody(response);
    return response.statusCode < 400 &&
        body is Map &&
        (body['methods'] as List? ?? []).any(
          (method) =>
              method is Map &&
              method['kind'] == 'phone' &&
              method['available'] == true,
        );
  }

  /// Reads the currently published terms (or an explicitly enabled draft preview).
  Future<AuthResult<AuthTerms>> getTerms({String locale = 'fr'}) async {
    try {
      final response = await _send(
        'GET',
        '/edaya/terms?locale=${Uri.encodeQueryComponent(locale)}',
      );
      final body = _decodeBody(response);
      if (response.statusCode >= 400) {
        return AuthResult.failure(_readError(body));
      }
      final terms = AuthTerms.fromJson(Map<String, dynamic>.from(body as Map));
      if (terms.enforced && terms.document == null) {
        return const AuthResult.failure(
          AuthError(message: 'Terms unavailable', code: 'terms_unavailable'),
        );
      }
      return AuthResult.success(terms);
    } catch (_) {
      return const AuthResult.failure(
        AuthError(message: 'Terms unavailable', code: 'terms_unavailable'),
      );
    }
  }

  /// Starts Email or Phone verification. WhatsApp is an initial legacy alias.
  Future<AuthResult<void>> sendOtp({
    required String value,
    String channel = 'email',
    String locale = 'fr',
    AuthTermsAcceptance? termsAcceptance,
    String? invitationToken,
  }) async {
    if (!['email', 'phone', 'whatsapp'].contains(channel)) {
      return const AuthResult.failure(
        AuthError(
          message: 'Unsupported verification channel',
          code: 'unsupported_channel',
        ),
      );
    }
    return _requestOtp(
      '/edaya/otp/start',
      contract.AuthStart(
        kind: channel == 'email' ? 'email' : 'phone',
        value: value,
        locale: locale,
        termsAcceptance: termsAcceptance,
        invitationToken: channel == 'email' ? invitationToken : null,
      ).toJson(),
    );
  }

  /// Requests a replacement challenge; the server retains destination and purpose.
  Future<AuthResult<void>> resendOtp({String action = 'resend'}) async {
    if (pendingChallenge == null) {
      return const AuthResult.failure(
        AuthError(message: 'Verification expired', code: 'challenge_expired'),
      );
    }
    return _requestOtp('/edaya/otp/resend', {
      'challenge': pendingChallenge,
      'action': action,
    });
  }

  /// Observes delivery only. Never sends a code or switches channels.
  Future<AuthResult<OtpStatus>> otpStatus() async {
    final challenge = pendingChallenge;
    if (challenge == null) {
      return const AuthResult.failure(
        AuthError(message: 'Verification expired', code: 'challenge_expired'),
      );
    }
    final response = await _send('POST', '/edaya/otp/status', {
      'challenge': challenge,
    });
    final body = _decodeBody(response);
    if (response.statusCode >= 400) return AuthResult.failure(_readError(body));
    final status = OtpStatus.fromJson(Map<String, dynamic>.from(body as Map));
    if (challenge == pendingChallenge && pendingStep == 'primary_required') {
      primaryStatus = status;
    }
    return AuthResult.success(status);
  }

  Future<AuthResult<void>> _requestOtp(
    String path,
    Map<String, dynamic> payload,
  ) async {
    final key = jsonEncode([path, payload]);
    final requestId = _otpRequests.putIfAbsent(key, _newRequestId);
    final request = path == '/edaya/otp/resend'
        ? contract.AuthResend(
            challenge: payload['challenge'] as String,
            action: payload['action'] as String,
            requestId: requestId,
          ).toJson()
        : {...payload, 'requestId': requestId};
    final response = await _send('POST', path, request);
    final body = _decodeBody(response);
    if (response.statusCode >= 400) {
      final error = _readError(body);
      if (error.code == 'delivery_unavailable') {
        pendingChallenge = pendingStep = null;
        primaryStatus = null;
        if (body is Map &&
            body['nextResendAt'] is num &&
            body['serverNow'] is num) {
          emailRetryAt =
              DateTime.now().millisecondsSinceEpoch +
              (body['nextResendAt'] - body['serverNow'] as num).toInt();
        }
      }
      if (error.code != 'delivery_unavailable' &&
          (response.statusCode >= 500 || error.code == 'NETWORK_ERROR')) {
        _uncertainOtpRequest = (path: path, payload: Map.of(payload));
      } else {
        _otpRequests.remove(key);
        _uncertainOtpRequest = null;
      }
      if (body is Map && body['nextResendAt'] is num && primaryStatus != null) {
        primaryStatus = primaryStatus!.withCooldown(
          (body['nextResendAt'] as num).toInt(),
          (body['serverNow'] as num?)?.toInt(),
        );
      }
      return AuthResult.failure(error);
    }
    _otpRequests.remove(key);
    _uncertainOtpRequest = null;
    emailRetryAt = 0;
    primaryStatus = OtpStatus.fromJson(Map<String, dynamic>.from(body as Map));
    pendingChallenge = primaryStatus!.challenge;
    pendingStep = 'primary_required';
    return const AuthResult.success(null);
  }

  Future<AuthResult<bool>> authenticatorEnabled() async {
    final response = await _send('POST', '/edaya/security', {});
    final body = _decodeBody(response);
    if (response.statusCode >= 400) return AuthResult.failure(_readError(body));
    return AuthResult.success((body as Map)['totpEnabled'] == true);
  }

  Future<AuthResult<List<Map<String, dynamic>>>> identifiers() async {
    final response = await _send('POST', '/edaya/session', {});
    final body = _decodeBody(response);
    if (response.statusCode >= 400) return AuthResult.failure(_readError(body));
    final account = (body as Map)['account'] as Map;
    return AuthResult.success(
      (account['identifiers'] as List)
          .map((i) => Map<String, dynamic>.from(i as Map))
          .toList(),
    );
  }

  Future<AuthResult<void>> linkIdentifier({
    required String value,
    required String channel,
    bool recoveryEligible = false,
    String locale = 'fr',
  }) async {
    if (!['email', 'phone', 'whatsapp'].contains(channel)) {
      return const AuthResult.failure(
        AuthError(
          message: 'Unsupported verification channel',
          code: 'unsupported_channel',
        ),
      );
    }
    return _requestOtp(
      '/edaya/identifiers/start',
      contract.AuthStart(
        kind: channel == 'email' ? 'email' : 'phone',
        value: value,
        recoveryEligible: recoveryEligible,
        locale: locale,
      ).toJson(),
    );
  }

  Future<AuthResult<void>> verifyIdentifier(String code) async {
    final response = await _send('POST', '/edaya/otp/verify', {
      'challenge': pendingChallenge,
      'code': code,
    });
    final result = await _readVoidResult(response);
    if (result.isSuccess) {
      pendingChallenge = null;
      pendingStep = null;
      primaryStatus = null;
    }
    return result;
  }

  Future<AuthResult<void>> unlinkIdentifier(String id) async {
    final response = await _send('POST', '/edaya/identifiers/unlink', {
      'identifierId': id,
    });
    final result = await _readVoidResult(response);
    if (result.isSuccess) clearCredentials();
    return result;
  }

  Future<AuthResult<void>> sendEmailOtp({
    required String email,
    String type = 'sign-in',
  }) => sendOtp(value: email);

  Future<AuthResult<AuthUser>> signInWithEmailOtp({
    required String email,
    required String otp,
  }) => verifyOtp(otp);

  Future<AuthResult<AuthUser>> completeRegistration(
    contract.AuthRegistrationOffer offer,
    AuthTermsAcceptance? acceptance,
  ) => _postAuthUser(
    '/edaya/registration/complete',
    contract.AuthRegistrationInput(
      challenge: offer.challenge,
      proof: offer.proof,
      termsAcceptance: acceptance,
    ).toJson(),
  );

  Future<AuthResult<AuthUser>> teacherCode(
    String code,
    AuthTermsAcceptance? acceptance,
  ) => _postAuthUser(
    '/edaya/teacher-code',
    contract.AuthTeacherCodeLogin(
      code: code.trim(),
      termsAcceptance: acceptance,
    ).toJson(),
  );

  Future<AuthResult<AuthUser>> verifyOtp(String code) => _postAuthUser(
    '/edaya/otp/verify',
    {'challenge': pendingChallenge, 'code': code},
  );
  Future<AuthResult<AuthUser>> verifyTotp(String code) => _postAuthUser(
    '/edaya/totp/verify',
    {'challenge': pendingChallenge, 'code': code},
  );
  Future<AuthResult<AuthUser>> recover(String code) => _postAuthUser(
    '/edaya/recovery',
    {'challenge': pendingChallenge, 'code': code},
  );
  Future<AuthResult<AuthUser>> confirmTotp(String code) => _postAuthUser(
    '/edaya/totp/confirm',
    {'challenge': pendingChallenge, 'code': code},
  );
  Future<AuthResult<void>> beginTotpEnrollment() async {
    final response = await _send('POST', '/edaya/totp/enroll', {
      if (pendingStep == 'enrollment_required') 'challenge': pendingChallenge,
    });
    final body = _decodeBody(response);
    if (response.statusCode >= 400) return AuthResult.failure(_readError(body));
    final data = body as Map;
    pendingChallenge = data['challenge'] as String;
    pendingStep = 'enrollment_required';
    enrollmentSecret = data['secret'] as String;
    return const AuthResult.success(null);
  }

  final bool enableTestOtpInDebug;
  static const _debugBuild =
      !bool.fromEnvironment('dart.vm.product') &&
      !bool.fromEnvironment('dart.vm.profile');
  static const testOtpAccess =
      _debugBuild && bool.fromEnvironment('TEST_OTP_ACCESS');

  /// An explicit build flag takes precedence over the app's debug default.
  bool get testOtpEnabled =>
      _debugBuild &&
      (const bool.hasEnvironment('TEST_OTP_ACCESS')
          ? testOtpAccess
          : enableTestOtpInDebug);

  Future<bool>? _testingDiscovery;
  String? _testingOrigin;
  Future<bool> testingOtpAvailable() {
    if (!testOtpEnabled) return Future.value(false);
    if (_testingOrigin != baseUrl) {
      _testingOrigin = baseUrl;
      _testingDiscovery = null;
    }
    final origin = baseUrl;
    return _testingDiscovery ??= _discoverTestingOtp().catchError((
      Object error,
    ) {
      if (_testingOrigin == origin) _testingDiscovery = null;
      throw error;
    });
  }

  Future<bool> _discoverTestingOtp() async {
    final response = await _send('GET', '/edaya/testing/capabilities');
    final body = _decodeBody(response);
    if (response.statusCode == 429 || response.statusCode >= 500) {
      throw _readError(body);
    }
    return response.statusCode == 200 &&
        body is Map &&
        body['otpAccess'] == true;
  }

  Future<({String challenge, String otp, String channel, int expiresAt})?>
  revealTestOtp(String challenge) async {
    if (!testOtpEnabled) return null;
    final response = await _send('POST', '/edaya/testing/otp', {
      'challenge': challenge,
    });
    final body = _decodeBody(response);
    if (response.statusCode != 200 ||
        body is! Map ||
        body['challenge'] != challenge) {
      return null;
    }
    return (
      challenge: body['challenge'] as String,
      otp: body['otp'] as String,
      channel: body['channel'] as String,
      expiresAt: (body['expiresAt'] as num).toInt(),
    );
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

      if (body is Map && body['state'] == 'registration_required') {
        registration = contract.AuthRegistrationOffer.fromJson(
          Map<String, dynamic>.from(body),
        );
        primaryStatus = null;
        pendingChallenge = null;
        return const AuthResult.failure(
          AuthError(
            message: 'Explicit registration required',
            code: 'registration_required',
          ),
        );
      }
      if (body is Map &&
          (body['state'] == 'totp_required' ||
              body['state'] == 'enrollment_required')) {
        primaryStatus = null;
        pendingStep = body['state'] as String;
        pendingChallenge = body['challenge'] as String;
        return AuthResult.failure(
          AuthError(
            message: 'Additional verification required',
            code: pendingStep,
          ),
        );
      }
      final userJson = _readUserJson(body);
      if (userJson == null) {
        return const AuthResult.failure(
          AuthError(message: 'Authentication response did not include a user'),
        );
      }

      clearCredentials();
      if (!edayaHttpUsesBrowserCredentials) {
        final data = Map<String, dynamic>.from(body as Map);
        final credential = data['token'];
        if (credential is String && credential.isNotEmpty) {
          restoreRenewalCredential(credential);
        } else {
          return const AuthResult.failure(
            AuthError(message: 'Login did not return a renewal credential'),
          );
        }
      }
      pendingChallenge = null;
      pendingStep = null;
      enrollmentSecret = null;
      recoveryCodes = body is Map && body['recoveryCodes'] is List
          ? List<String>.from(body['recoveryCodes'] as List)
          : [];
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
      if (message is String || body['code'] is String) {
        return AuthError(
          message: normalizeAuthErrorMessage(
            message is String ? message : body['code'] as String,
          ),
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
    final routes = contract.authRoutes.values.where(
      (route) => route.path == '$basePath$path' && route.method == method,
    );
    final uri = routes.isEmpty
        ? _resolveUri(path)
        : Uri.parse(baseUrl).resolve(routes.first.path);
    final headers = <String, String>{
      'Accept': 'application/json',
      if (!edayaHttpUsesBrowserCredentials) 'x-edaya-client': 'native',
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

    try {
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
    } on http.ClientException catch (error) {
      final failure = _networkError(error);
      return http.Response(
        jsonEncode({'code': failure.code, 'message': failure.message}),
        503,
      );
    }
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

/// Transient delivery and cooldown state; never a completed authentication proof.
class OtpStatus {
  OtpStatus({
    required this.challenge,
    required this.channel,
    required this.delivery,
    required this.lifecycle,
    required this.expiresAt,
    required this.nextResendAt,
    required this.canResend,
    required this.canSms,
    required this.clockOffset,
  });
  final String challenge, channel, delivery, lifecycle;
  final int expiresAt, nextResendAt, clockOffset;
  final bool canResend, canSms;
  factory OtpStatus.fromJson(Map<String, dynamic> json) {
    final now = DateTime.now().millisecondsSinceEpoch;
    final actions = json['actions'] as Map?;
    return OtpStatus(
      challenge: json['challenge'] as String,
      channel: json['channel'] as String? ?? 'email',
      delivery: json['delivery'] as String? ?? 'accepted',
      lifecycle: json['lifecycle'] as String? ?? 'pending',
      expiresAt: (json['expiresAt'] as num?)?.toInt() ?? now + 300000,
      nextResendAt: (json['nextResendAt'] as num?)?.toInt() ?? now + 60000,
      canResend: actions?['resend'] != false,
      canSms: actions?['sms'] == true,
      clockOffset: ((json['serverNow'] as num?)?.toInt() ?? now) - now,
    );
  }
  int get secondsRemaining => max(
    0,
    ((nextResendAt - DateTime.now().millisecondsSinceEpoch - clockOffset) /
            1000)
        .ceil(),
  );
  OtpStatus withCooldown(int next, int? serverNow) => OtpStatus(
    challenge: challenge,
    channel: channel,
    delivery: delivery,
    lifecycle: lifecycle,
    expiresAt: expiresAt,
    nextResendAt: next,
    canResend: canResend,
    canSms: canSms,
    clockOffset: serverNow == null
        ? clockOffset
        : serverNow - DateTime.now().millisecondsSinceEpoch,
  );
}

String _newRequestId() {
  final random = Random.secure();
  final bytes = List<int>.generate(16, (_) => random.nextInt(256));
  bytes[6] = (bytes[6] & 15) | 64;
  bytes[8] = (bytes[8] & 63) | 128;
  final hex = bytes
      .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
      .join();
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
}
