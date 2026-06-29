import 'package:shared_preferences/shared_preferences.dart';

import 'app_settings_models.dart';

abstract final class AppSettingsStorage {
  AppSettingsStorage._();

  static const _themeKey = 'edaya_settings_theme';
  static const _languageKey = 'edaya_settings_language';
  static const _timezoneKey = 'edaya_settings_timezone';
  static const _dateFormatKey = 'edaya_settings_date_format';
  static const _timeFormatKey = 'edaya_settings_time_format';

  static AppSettingsSnapshot _cached = AppSettingsSnapshot.defaults;

  static AppSettingsSnapshot get cached => _cached;

  static Future<AppSettingsSnapshot> load() async {
    final prefs = await SharedPreferences.getInstance();
    _cached = AppSettingsSnapshot(
      theme: _readEnum(
        prefs.getString(_themeKey),
        ThemePreference.values,
        ThemePreference.system,
      ),
      language: _readEnum(
        prefs.getString(_languageKey),
        LanguagePreference.values,
        LanguagePreference.system,
      ),
      timezone: AppTimezoneX.fromStorage(prefs.getString(_timezoneKey)),
      dateFormat: _readEnum(
        prefs.getString(_dateFormatKey),
        DateFormatPreference.values,
        DateFormatPreference.system,
      ),
      timeFormat: _readEnum(
        prefs.getString(_timeFormatKey),
        TimeFormatPreference.values,
        TimeFormatPreference.system,
      ),
    );
    return _cached;
  }

  static Future<AppSettingsSnapshot> save(AppSettingsSnapshot snapshot) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_themeKey, snapshot.theme.name);
    await prefs.setString(_languageKey, snapshot.language.name);
    await prefs.setString(_timezoneKey, snapshot.timezone.name);
    await prefs.setString(_dateFormatKey, snapshot.dateFormat.name);
    await prefs.setString(_timeFormatKey, snapshot.timeFormat.name);
    _cached = snapshot;
    return _cached;
  }

  static T _readEnum<T extends Enum>(
    String? raw,
    List<T> values,
    T fallback,
  ) {
    if (raw == null) {
      return fallback;
    }
    return values.firstWhere((value) => value.name == raw, orElse: () => fallback);
  }
}
