import 'effective_grants.dart';
import 'entity_resource.dart';
import 'generated/client_bindings.dart';
import 'paths.dart';
import 'transport.dart';

class SchoolClient {
  SchoolClient(this._transport)
    : _entities = {
        for (final entry in ClientBindings.entities.entries)
          entry.key: EntityResource(_transport, entry.value.publicName),
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

  Future<EffectiveGrantsResponse> effectiveGrants() async {
    final response = await _transport.request<Map<String, dynamic>>(
      'GET',
      schoolApiPath(['authorization', 'effective-grants']),
    );
    return EffectiveGrantsResponse.fromJson(response);
  }
}

SchoolClient createSchoolClient(Transport transport) => SchoolClient(transport);
