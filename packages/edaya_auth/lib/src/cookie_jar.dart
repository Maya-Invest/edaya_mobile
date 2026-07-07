class CookieJar {
  final Map<String, String> _cookies = {};

  void updateFromHeader(String? header) {
    if (header == null || header.isEmpty) {
      return;
    }

    final cookiePart = header.split(';').first.trim();
    final separator = cookiePart.indexOf('=');
    if (separator <= 0) {
      return;
    }

    final name = cookiePart.substring(0, separator).trim();
    final value = cookiePart.substring(separator + 1).trim();
    if (value.isNotEmpty) {
      _cookies[name] = value;
    }
  }

  void updateFromHeaders(Iterable<String> headers) {
    for (final header in headers) {
      updateFromHeader(header);
    }
  }

  String? headerValue() {
    if (_cookies.isEmpty) {
      return null;
    }

    return _cookies.entries
        .map((entry) => '${entry.key}=${entry.value}')
        .join('; ');
  }

  Map<String, String> snapshot() => Map.unmodifiable(_cookies);

  void restore(Map<String, String> cookies) {
    _cookies
      ..clear()
      ..addAll(cookies);
  }

  void clear() => _cookies.clear();
}
