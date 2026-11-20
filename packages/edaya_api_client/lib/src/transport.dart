class TransportRequestOptions {
  const TransportRequestOptions({
    this.body,
    this.headers = const {},
    this.abortTrigger,
  });

  final Object? body;
  final Future<void>? abortTrigger;
  final Map<String, String> headers;
}

abstract class Transport {
  Future<T> request<T>(
    String method,
    String path, {
    TransportRequestOptions? options,
  });
}
