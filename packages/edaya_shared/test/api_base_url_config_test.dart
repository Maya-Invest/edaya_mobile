import 'package:edaya_shared/edaya_shared.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'auth and school follow the selected origin and migrate retired presets',
    () async {
      SharedPreferences.setMockInitialValues({
        'edaya_api_base_url': 'https://staging.school.api.edayaplus.com',
      });
      ApiBaseUrlConfig.configure(appDefaultUrl: ApiBaseUrlConfig.stagingUrl);
      await ApiBaseUrlConfig.load();
      expect(ApiBaseUrlConfig.baseUrl, 'https://staging.api.edayaplus.com');
      expect(ApiBaseUrlConfig.authBaseUrl, ApiBaseUrlConfig.baseUrl);
      await ApiBaseUrlConfig.saveOverride('https://developer.example:8443');
      expect(ApiBaseUrlConfig.authBaseUrl, 'https://developer.example:8443');
      expect(
        ApiBaseUrlConfig.migratePreset('http://10.0.2.2:9900'),
        'http://10.0.2.2:9999',
      );
      expect(
        ApiBaseUrlConfig.migratePreset('http://192.168.1.23:9900'),
        'http://192.168.1.23:9900',
      );
      await ApiBaseUrlConfig.clearOverride();
      expect(ApiBaseUrlConfig.authBaseUrl, ApiBaseUrlConfig.stagingUrl);
    },
  );

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
