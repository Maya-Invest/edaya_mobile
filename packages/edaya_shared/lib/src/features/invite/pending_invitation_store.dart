import 'dart:async';

import 'package:shared_preferences/shared_preferences.dart';

class PendingInvitationStore {
  static const tokenKey = 'edaya_pending_invitation_token';
  static const expiresKey = 'edaya_pending_invitation_expires_at';
  static const ttl = Duration(days: 7);

  String? _token;
  DateTime? _expiresAt;

  String? get token {
    final current = _token;
    if (current == null || current.isEmpty) {
      return null;
    }
    final expiresAt = _expiresAt;
    if (expiresAt != null && DateTime.now().isAfter(expiresAt)) {
      _token = null;
      _expiresAt = null;
      return null;
    }
    return current;
  }

  bool get hasToken => token != null;

  Future<void> hydrate() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(tokenKey);
    final expiresMillis = prefs.getInt(expiresKey);
    if (stored == null || stored.isEmpty || expiresMillis == null) {
      _token = null;
      _expiresAt = null;
      return;
    }
    final expiresAt = DateTime.fromMillisecondsSinceEpoch(expiresMillis);
    if (DateTime.now().isAfter(expiresAt)) {
      await clear();
      return;
    }
    _token = stored;
    _expiresAt = expiresAt;
  }

  void remember(String token) {
    final trimmed = token.trim();
    if (trimmed.isEmpty) {
      return;
    }
    _token = trimmed;
    _expiresAt = DateTime.now().add(ttl);
    unawaited(_persist());
  }

  Future<void> save(String token) async {
    remember(token);
    await _persist();
  }

  Future<void> clear() async {
    _token = null;
    _expiresAt = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(tokenKey);
    await prefs.remove(expiresKey);
  }

  Future<void> _persist() async {
    final current = _token;
    final expiresAt = _expiresAt;
    final prefs = await SharedPreferences.getInstance();
    if (current == null || expiresAt == null) {
      await prefs.remove(tokenKey);
      await prefs.remove(expiresKey);
      return;
    }
    await prefs.setString(tokenKey, current);
    await prefs.setInt(expiresKey, expiresAt.millisecondsSinceEpoch);
  }
}
