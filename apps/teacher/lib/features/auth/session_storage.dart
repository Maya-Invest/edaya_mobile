import 'dart:convert';

import 'package:edaya_auth/edaya_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SessionStorage {
  static const _cookiesKey = 'edaya_auth_cookies';
  static const _loggedOutKey = 'edaya_auth_logged_out';
  static const _academicYearIdKey = 'teacher_academic_year_id';
  static const _classFilterIdKey = 'teacher_class_filter_id';

  Future<bool> isLoggedOut() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_loggedOutKey) ?? false;
  }

  Future<void> markLoggedOut() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_loggedOutKey, true);
  }

  Future<void> markLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_loggedOutKey);
  }

  Future<void> persist(CookieJar jar) async {
    if (kIsWeb) {
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    if (jar.snapshot().isEmpty) {
      await prefs.remove(_cookiesKey);
      return;
    }

    await prefs.setString(_cookiesKey, jsonEncode(jar.snapshot()));
  }

  Future<void> restoreInto(CookieJar jar) async {
    if (kIsWeb) {
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_cookiesKey);
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
    await prefs.remove(_cookiesKey);
  }

  Future<String?> readAcademicYearId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_academicYearIdKey);
  }

  Future<void> writeAcademicYearId(String? yearId) async {
    final prefs = await SharedPreferences.getInstance();
    if (yearId == null || yearId.isEmpty) {
      await prefs.remove(_academicYearIdKey);
      return;
    }
    await prefs.setString(_academicYearIdKey, yearId);
  }

  Future<String?> readClassFilterId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_classFilterIdKey);
  }

  Future<void> writeClassFilterId(String? classGroupId) async {
    final prefs = await SharedPreferences.getInstance();
    if (classGroupId == null || classGroupId.isEmpty) {
      await prefs.remove(_classFilterIdKey);
      return;
    }
    await prefs.setString(_classFilterIdKey, classGroupId);
  }
}
