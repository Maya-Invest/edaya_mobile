import 'dart:convert';

import 'package:http/http.dart' as http;

import 'api_error.dart';
import 'entity_envelope.dart';
import 'transport.dart';

class HttpTransport implements Transport {
  HttpTransport({
    required this.baseUrl,
    this.client,
    this.getAcademicYearId,
    this.getActorKind,
    this.getActorId,
    this.getSchoolId,
    this.getAccessToken,
    this.invalidateAccessToken,
  });

  final String baseUrl;
  final http.Client? client;
  final String? Function()? getAcademicYearId;
  final String? Function()? getActorKind;
  final String? Function()? getActorId;
  final String? Function()? getSchoolId;
  final Future<String> Function()? getAccessToken;
  final void Function(String)? invalidateAccessToken;

  http.Client get _client => client ?? http.Client();

  @override
  Future<T> request<T>(
    String method,
    String path, {
    TransportRequestOptions? options,
  }) async {
    final uri = _resolveUri(path);
    final headers = <String, String>{
      'Accept': 'application/json',
      ...?options?.headers,
    };

    if (options?.body != null) {
      headers['Content-Type'] = 'application/json';
    }

    final yearId = getAcademicYearId?.call();
    if (yearId != null && yearId.isNotEmpty) {
      headers['X-Academic-Year-Id'] = yearId;
    }

    final actorKind = getActorKind?.call();
    if (actorKind != null && actorKind.isNotEmpty) {
      headers['X-Actor-Kind'] = actorKind;
    }

    final actorId = getActorId?.call();
    if (actorId != null && actorId.isNotEmpty) {
      headers['X-Actor-Id'] = actorId;
    }

    final schoolId = getSchoolId?.call();
    if (schoolId != null && schoolId.isNotEmpty) {
      headers['X-School-Id'] = schoolId;
    }

    final token = await getAccessToken?.call();
    headers.remove('Cookie');
    if (token != null) headers['Authorization'] = 'Bearer $token';

    var response = await _client.send(
      http.Request(method, uri)
        ..headers.addAll(headers)
        ..body = options?.body == null ? '' : jsonEncode(options!.body),
    );

    if (response.statusCode == 401 && token != null) {
      invalidateAccessToken?.call(token);
      if (method == 'GET' || method == 'HEAD') {
        await response.stream.drain<void>();
        headers['Authorization'] = 'Bearer ${await getAccessToken!()}';
        response = await _client.send(
          http.Request(method, uri)..headers.addAll(headers),
        );
      }
    }
    return _parseResponse<T>(path, response);
  }

  Uri _resolveUri(String path) {
    final normalized = path.startsWith('/') ? path : '/$path';
    final base = Uri.parse(baseUrl.endsWith('/') ? baseUrl : '$baseUrl/');
    return base.resolve(normalized.substring(1));
  }

  Future<T> _parseResponse<T>(
    String path,
    http.StreamedResponse response,
  ) async {
    final bodyBytes = await response.stream.toBytes();
    final bodyText = utf8.decode(bodyBytes);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      Object? body;
      try {
        body = jsonDecode(bodyText);
      } catch (_) {
        body = bodyText;
      }
      throw ApiError(response.statusCode, body);
    }

    if (response.statusCode == 204 || bodyText.isEmpty) {
      return null as T;
    }

    final json = jsonDecode(bodyText);
    return parseApiResponse<T>(path, response.statusCode, json);
  }
}

String resolveApiUrl(String baseUrl, String path) {
  final normalized = path.startsWith('/') ? path : '/$path';
  if (baseUrl.isEmpty) {
    return normalized;
  }
  return '${baseUrl.endsWith('/') ? baseUrl.substring(0, baseUrl.length - 1) : baseUrl}$normalized';
}
