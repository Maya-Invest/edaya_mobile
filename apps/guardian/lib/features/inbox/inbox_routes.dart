/// Inbox message locations. Delivery ids contain `:` and `%xx` sequences, so
/// they must be path-encoded or GoRouter / HTTP GET will treat `%3A` as `:`.
String inboxMessagePath(String deliveryId) =>
    '/inbox/message/${Uri.encodeComponent(deliveryId)}';
