class TransportRequestOptions {
  const TransportRequestOptions({this.body, this.headers = const {}});

  final Object? body;
  final Map<String, String> headers;
}

abstract class Transport {
  Future<T> request<T>(
    String method,
    String path, {
    TransportRequestOptions? options,
  });
}
