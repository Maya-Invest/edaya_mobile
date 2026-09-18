import 'package:edaya_auth/edaya_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Only the signed renewal credential is persisted, in the OS secure store.
class AuthSessionStorage {
  AuthSessionStorage({FlutterSecureStorage? secureStorage})
    : _secure =
          secureStorage ??
          const FlutterSecureStorage(
            iOptions: IOSOptions(
              accessibility: KeychainAccessibility.first_unlock_this_device,
            ),
          );
  final FlutterSecureStorage _secure;
  static const cookiesKey = 'edaya_auth_cookies';
  static const loggedOutKey = 'edaya_auth_logged_out';
  static const renewalKey = 'edaya_auth_renewal_v1';
  static const originKey = 'edaya_auth_renewal_origin_v1';

  Future<bool> isLoggedOut() async =>
      (await SharedPreferences.getInstance()).getBool(loggedOutKey) ?? false;
  Future<void> markLoggedOut() async =>
      (await SharedPreferences.getInstance()).setBool(loggedOutKey, true);
  Future<void> markLoggedIn() async =>
      (await SharedPreferences.getInstance()).remove(loggedOutKey);

  Future<void> persist(AuthClient client) async {
    if (kIsWeb) return;
    await (await SharedPreferences.getInstance()).remove(cookiesKey);
    final credential = client.renewalCredential;
    if (credential == null) {
      await clearCookies();
      return;
    }
    await _secure.write(
      key: originKey,
      value: Uri.parse(client.baseUrl).origin,
    );
    await _secure.write(key: renewalKey, value: credential);
  }

  Future<void> restoreInto(AuthClient client) async {
    if (kIsWeb) return;
    final prefs = await SharedPreferences.getInstance();
    client.clearCredentials();
    if (prefs.containsKey(cookiesKey)) {
      // The cutover requires fresh login proof; never convert old cookie files.
      await clearCookies();
      return;
    }
    if (await _secure.read(key: originKey) !=
        Uri.parse(client.baseUrl).origin) {
      await clearCookies();
      return;
    }
    final credential = await _secure.read(key: renewalKey);
    if (credential != null) client.restoreRenewalCredential(credential);
  }

  Future<void> clearCookies() async {
    if (kIsWeb) return;
    await (await SharedPreferences.getInstance()).remove(cookiesKey);
    await _secure.delete(key: renewalKey);
    await _secure.delete(key: originKey);
  }
}
