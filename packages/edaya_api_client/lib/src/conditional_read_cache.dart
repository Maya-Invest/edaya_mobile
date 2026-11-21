import 'dart:typed_data';
import 'package:http/http.dart' as http;

/// Memory-only pages are reusable only after the server approves the validator.
class ConditionalReadCache {
  final _pages = <Uri, ({String etag, Uint8List bytes})>{};
  String? _scope;
  int _generation = 0;
  int _size = 0;

  void clear() {
    _generation++;
    _scope = null;
    _pages.clear();
    _size = 0;
  }

  Future<http.StreamedResponse> read(
    Uri uri,
    String scope,
    Future<http.StreamedResponse> Function(String?) send,
  ) async {
    if (_scope != scope) {
      clear();
      _scope = scope;
    }
    final generation = _generation;
    void current() {
      if (generation != _generation)
        throw StateError('Directory scope changed');
    }

    final retained = _pages[uri];
    var response = await send(retained?.etag);
    if (response.statusCode == 304) {
      await response.stream.drain<void>();
      current();
      if (retained != null && identical(_pages[uri]?.bytes, retained.bytes)) {
        _pages.remove(uri);
        _pages[uri] = retained;
        return http.StreamedResponse(Stream.value(retained.bytes), 200);
      }
      response = await send(null);
    }
    if (response.statusCode != 200) {
      if (generation == _generation &&
          (response.statusCode == 401 || response.statusCode == 403))
        clear();
      return response;
    }
    final bytes = await response.stream.toBytes();
    current();
    final old = _pages.remove(uri);
    if (old != null) _size -= old.bytes.length;
    final etag = response.headers['etag'];
    const budget = 1024 * 1024;
    if (etag != null &&
        bytes.length <= budget &&
        !(response.headers['cache-control'] ?? '').contains('no-store')) {
      while (_pages.length >= 32 || _size + bytes.length > budget) {
        _size -= _pages.remove(_pages.keys.first)!.bytes.length;
      }
      _pages[uri] = (etag: etag, bytes: bytes);
      _size += bytes.length;
    }
    return http.StreamedResponse(
      Stream.value(bytes),
      200,
      headers: response.headers,
    );
  }
}
