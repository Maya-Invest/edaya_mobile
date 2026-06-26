import 'entity_envelope.dart';
import 'paths.dart';
import 'transport.dart';

typedef EntityQuery = Map<String, dynamic>;

class EntityResource {
  EntityResource(this._transport, this.publicName);

  final Transport _transport;
  final String publicName;

  Future<List<Map<String, dynamic>>> list([EntityQuery? query]) async {
    final result = await _transport.request<Object?>(
      'POST',
      _path('list'),
      options: TransportRequestOptions(body: query ?? const {}),
    );
    return unwrapEntityList(result);
  }

  Future<Map<String, dynamic>> one(EntityQuery query) async {
    final result = await _transport.request<Object?>(
      'POST',
      _path('one'),
      options: TransportRequestOptions(body: query),
    );
    return unwrapEntityMap(result);
  }

  Future<Map<String, dynamic>> count([EntityQuery? query]) {
    return _transport.request<Map<String, dynamic>>(
      'POST',
      _path('count'),
      options: TransportRequestOptions(body: query ?? const {}),
    );
  }

  Future<Map<String, dynamic>> get(String id) async {
    final result = await _transport.request<Object?>(
      'GET',
      schoolApiPath(['entities', publicName, id]),
    );
    return unwrapEntityMap(result);
  }

  Future<Map<String, dynamic>> save(Map<String, dynamic> entity) async {
    final result = await _transport.request<Object?>(
      'POST',
      _path('save'),
      options: TransportRequestOptions(body: entity),
    );
    return unwrapEntityMap(result);
  }

  Future<Map<String, dynamic>> delete({required String id}) {
    return _transport.request<Map<String, dynamic>>(
      'POST',
      _path('delete'),
      options: TransportRequestOptions(body: {'id': id}),
    );
  }

  Future<Map<String, dynamic>> batchSave({
    required List<Map<String, dynamic>> entities,
  }) {
    return _transport.request<Map<String, dynamic>>(
      'POST',
      _path('batch-save'),
      options: TransportRequestOptions(body: {'entities': entities}),
    );
  }

  Future<Map<String, dynamic>> batchDelete({required List<String> ids}) {
    return _transport.request<Map<String, dynamic>>(
      'POST',
      _path('batch-delete'),
      options: TransportRequestOptions(body: {'ids': ids}),
    );
  }

  String _path(String action) {
    return schoolApiPath(['entities', publicName, action]);
  }
}
