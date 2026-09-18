import 'package:edaya_shared/edaya_shared.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'rewriteLocalDevUrl maps loopback uploads onto the Android emulator host',
    () {
      expect(
        ApiBaseUrlConfig.rewriteLocalDevUrl(
          'http://localhost:9999/core/files/memory/portrait.jpg',
          apiBaseUrl: 'http://10.0.2.2:9999',
        ),
        'http://10.0.2.2:9999/core/files/memory/portrait.jpg',
      );
      expect(
        ApiBaseUrlConfig.rewriteLocalDevUrl(
          'http://127.0.0.1:9200/upload?token=abc',
          apiBaseUrl: 'http://10.0.2.2:9999',
        ),
        'http://10.0.2.2:9200/upload?token=abc',
      );
    },
  );

  test(
    'rewriteLocalDevUrl leaves non-loopback and same-host URLs unchanged',
    () {
      expect(
        ApiBaseUrlConfig.rewriteLocalDevUrl(
          'https://files.example/portrait.jpg',
          apiBaseUrl: 'http://10.0.2.2:9999',
        ),
        'https://files.example/portrait.jpg',
      );
      expect(
        ApiBaseUrlConfig.rewriteLocalDevUrl(
          'http://localhost:9999/core/files/memory/portrait.jpg',
          apiBaseUrl: 'http://localhost:9999',
        ),
        'http://localhost:9999/core/files/memory/portrait.jpg',
      );
    },
  );
}
