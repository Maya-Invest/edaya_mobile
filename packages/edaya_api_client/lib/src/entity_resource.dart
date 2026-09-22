import 'entity_envelope.dart';
import 'paths.dart';
import 'transport.dart';

typedef EntityQuery = Map<String, dynamic>;

class EntityResource {
  EntityResource(
    this._transport,
    this.publicName, {
    Map<String, bool> publicOperations = const {},
  }) : _operations = Map.unmodifiable(publicOperations);

  final Map<String, bool> _operations;

  final Transport _transport;
  final String publicName;

  /// Pages with `$limit`/`$offset` until a short page. Throws if the result
  /// would be silently truncated past [maxRows].
  Future<List<Map<String, dynamic>>> listAll([
    EntityQuery? query,
    int pageSize = 100,
    int maxRows = 5000,
  ]) async {
    final rows = <Map<String, dynamic>>[];
    var offset = 0;
    while (true) {
      final page = await list({
        ...?query,
        r'$limit': pageSize,
        r'$offset': offset,
      });
      rows.addAll(page);
      if (page.length < pageSize) {
        return rows;
      }
      offset += page.length;
      if (offset >= maxRows) {
        throw StateError(
          'Entity list for $publicName exceeded $maxRows rows',
        );
      }
    }
  }

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
    _requireOperations(['create', 'update']);
    final result = await _transport.request<Object?>(
      'POST',
      _path('save'),
      options: TransportRequestOptions(body: entity),
    );
    return unwrapEntityMap(result);
  }

  Future<Map<String, dynamic>> delete({required String id}) {
    _requireOperations(['delete']);
    return _transport.request<Map<String, dynamic>>(
      'POST',
      _path('delete'),
      options: TransportRequestOptions(body: {'id': id}),
    );
  }

  Future<Map<String, dynamic>> batchSave({
    required List<Map<String, dynamic>> entities,
  }) {
    _requireOperations(['batchCreate', 'batchUpdate']);
    return _transport.request<Map<String, dynamic>>(
      'POST',
      _path('batch-save'),
      options: TransportRequestOptions(body: {'entities': entities}),
    );
  }

  Future<Map<String, dynamic>> batchDelete({required List<String> ids}) {
    _requireOperations(['batchDelete']);
    return _transport.request<Map<String, dynamic>>(
      'POST',
      _path('batch-delete'),
      options: TransportRequestOptions(body: {'ids': ids}),
    );
  }

  void _requireOperations(List<String> operations) {
    if (operations.any((operation) => _operations[operation] != true)) {
      throw StateError(
        'Generic mutation is unavailable for $publicName; use a domain command',
      );
    }
  }

  String _path(String action) {
    return schoolApiPath(['entities', publicName, action]);
  }
}
