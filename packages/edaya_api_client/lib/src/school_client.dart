import 'effective_grants.dart';
import 'entity_resource.dart';
import 'generated/client_bindings.dart';
import 'paths.dart';
import 'transport.dart';

class SchoolClient {
  SchoolClient(this._transport)
    : _entities = {
        for (final entry in ClientBindings.entities.entries)
          entry.key: EntityResource(
            _transport,
            entry.value.publicName,
            publicOperations: entry.value.publicOperations,
          ),
      };

  final Transport _transport;
  final Map<String, EntityResource> _entities;

  Map<String, EntityResource> get entities => _entities;

  Future<Map<String, dynamic>> runCommand(
    String publicName,
    Map<String, dynamic> payload,
  ) {
    return _transport.request<Map<String, dynamic>>(
      'POST',
      schoolApiPath(['commands', publicName]),
      options: TransportRequestOptions(body: payload),
    );
  }

  Future<Map<String, dynamic>> runQuery(
    String publicName,
    Map<String, dynamic> payload,
  ) {
    return _transport.request<Map<String, dynamic>>(
      'POST',
      schoolApiPath(['queries', publicName]),
      options: TransportRequestOptions(body: payload),
    );
  }

  Future<List<Map<String, dynamic>>> authorizationProfiles() async {
    final response = await _transport.request<Map<String, dynamic>>(
      'GET',
      schoolApiPath(['authorization', 'profiles']),
    );
    final rows = response['profiles'];
    if (rows is! List) {
      return const [];
    }
    return [
      for (final row in rows)
        if (row is Map) Map<String, dynamic>.from(row),
    ];
  }

  Future<EffectiveGrantsResponse> effectiveGrants() async {
    final response = await _transport.request<Map<String, dynamic>>(
      'GET',
      schoolApiPath(['authorization', 'effective-grants']),
    );
    return EffectiveGrantsResponse.fromJson(response);
  }

  /// Lists an entity collection by public API name, including legacy routes
  /// that are no longer present in generated bindings.
  Future<List<Map<String, dynamic>>> listEntityByPublicName(
    String publicName, [
    EntityQuery? query,
  ]) {
    return EntityResource(_transport, publicName).list(query);
  }

  Future<Map<String, dynamic>> getEntityByPublicName(
    String publicName,
    String id,
  ) {
    return EntityResource(_transport, publicName).get(id);
  }

  Future<T> requestRoute<T>(
    String method,
    String path, {
    Object? body,
  }) {
    return _transport.request<T>(
      method,
      path.startsWith('/') ? path : '/$path',
      options: body == null ? null : TransportRequestOptions(body: body),
    );
  }
  Future<Map<String, dynamic>> getDownloadUrl({
    required String attachmentId,
  }) {
    return _transport.request<Map<String, dynamic>>(
      'GET',
      schoolApiPath(['files', attachmentId, 'download-url']),
    );
  }
}

SchoolClient createSchoolClient(Transport transport) => SchoolClient(transport);
