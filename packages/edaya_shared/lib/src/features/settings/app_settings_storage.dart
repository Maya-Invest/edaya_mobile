import 'dart:async';

import 'package:shared_preferences/shared_preferences.dart';

import 'app_settings_models.dart';

abstract final class AppSettingsStorage {
  AppSettingsStorage._();

  static const _themeKey = 'edaya_settings_theme';
  static const _languageKey = 'edaya_settings_language';
  static const _timezoneKey = 'edaya_settings_timezone';
  static const _dateFormatKey = 'edaya_settings_date_format';
  static const _timeFormatKey = 'edaya_settings_time_format';

  static final _languageChanges = StreamController<void>.broadcast();
  static Stream<void> get languageChanges => _languageChanges.stream;

  static String _activePrefix = '';
  static AppSettingsSnapshot _cached = AppSettingsSnapshot.defaults;

  static AppSettingsSnapshot get cached => _cached;

  static Future<AppSettingsSnapshot> load({String prefix = ''}) async {
    _activePrefix = prefix;
    final prefs = await SharedPreferences.getInstance();
    String? read(String key) =>
        prefs.getString('$prefix$key') ?? prefs.getString(key);
    _cached = AppSettingsSnapshot(
      theme: _readEnum(
        read(_themeKey),
        ThemePreference.values,
        ThemePreference.system,
      ),
      language: _readEnum(
        read(_languageKey),
        LanguagePreference.values,
        LanguagePreference.system,
      ),
      timezone: AppTimezoneX.fromStorage(read(_timezoneKey)),
      dateFormat: _readEnum(
        read(_dateFormatKey),
        DateFormatPreference.values,
        DateFormatPreference.system,
      ),
      timeFormat: _readEnum(
        read(_timeFormatKey),
        TimeFormatPreference.values,
        TimeFormatPreference.system,
      ),
    );
    return _cached;
  }

  static Future<AppSettingsSnapshot> save(
    AppSettingsSnapshot snapshot, {
    String prefix = '',
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('$prefix$_themeKey', snapshot.theme.name);
    await prefs.setString('$prefix$_languageKey', snapshot.language.name);
    await prefs.setString('$prefix$_timezoneKey', snapshot.timezone.name);
    await prefs.setString('$prefix$_dateFormatKey', snapshot.dateFormat.name);
    await prefs.setString('$prefix$_timeFormatKey', snapshot.timeFormat.name);
    if (_activePrefix == prefix) {
      final changed = _cached.language != snapshot.language;
      _cached = snapshot;
      if (changed) _languageChanges.add(null);
    }
    return snapshot;
  }

  static T _readEnum<T extends Enum>(String? raw, List<T> values, T fallback) {
    if (raw == null) {
      return fallback;
    }
    return values.firstWhere(
      (value) => value.name == raw,
      orElse: () => fallback,
    );
  }
}
