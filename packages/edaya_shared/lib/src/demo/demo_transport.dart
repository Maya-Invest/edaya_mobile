import 'package:edaya_api_client/edaya_api_client.dart';
import 'demo_store.dart';
import 'package:http/http.dart' as http;

String schoolStoragePrefix(SchoolClient client) =>
    client is DemoSchoolClient ? client.store.prefix : '';

http.Client schoolMediaClient(SchoolClient client) =>
    client is DemoSchoolClient ? DemoMediaClient(client.store) : http.Client();

class DemoSchoolClient extends SchoolClient {
  DemoSchoolClient(super.transport, this.store);
  final DemoStore store;
}

class DemoTransport implements Transport {
  DemoTransport(this.store, this.year);
  final DemoStore store;
  final String? Function()? year;
  @override
  Future<T> request<T>(
    String method,
    String path, {
    TransportRequestOptions? options,
  }) async {
    final body = Map<String, dynamic>.from(options?.body as Map? ?? {});
    return await store.request(method, path, body, year?.call()) as T;
  }
}
