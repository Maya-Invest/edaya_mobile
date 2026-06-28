import 'dart:convert';

import 'package:edaya_auth/edaya_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persists auth cookies and logged-out state on native platforms.
class AuthSessionStorage {
  static const cookiesKey = 'edaya_auth_cookies';
  static const loggedOutKey = 'edaya_auth_logged_out';

  Future<bool> isLoggedOut() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(loggedOutKey) ?? false;
  }

  Future<void> markLoggedOut() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(loggedOutKey, true);
  }

  Future<void> markLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(loggedOutKey);
  }

  Future<void> persist(CookieJar jar) async {
    if (kIsWeb) {
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    if (jar.snapshot().isEmpty) {
      await prefs.remove(cookiesKey);
      return;
    }

    await prefs.setString(cookiesKey, jsonEncode(jar.snapshot()));
  }

  Future<void> restoreInto(CookieJar jar) async {
    if (kIsWeb) {
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(cookiesKey);
    if (raw == null) {
      return;
    }

    final decoded = jsonDecode(raw);
    if (decoded is! Map) {
      return;
    }

    jar.restore(Map<String, String>.from(decoded));
  }

  Future<void> clearCookies() async {
    if (kIsWeb) {
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(cookiesKey);
  }
}
