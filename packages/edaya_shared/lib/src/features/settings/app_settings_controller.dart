import 'package:flutter/material.dart';
import 'package:levit_flutter/levit_flutter.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../../l10n/l10n_lookup.dart';
import 'app_settings_models.dart';
import 'app_settings_storage.dart';

class AppSettingsController extends LevitController {
  AppSettingsController({this.prefix = ''});
  final String prefix;

  final theme = LxVar(ThemePreference.system);
  final language = LxVar(LanguagePreference.system);
  final timezone = LxVar(AppTimezone.device);
  final dateFormat = LxVar(DateFormatPreference.system);
  final timeFormat = LxVar(TimeFormatPreference.system);

  static var _timezonesInitialized = false;

  static Future<void> ensureInitialized() async {
    if (_timezonesInitialized) {
      return;
    }
    tz_data.initializeTimeZones();
    _timezonesInitialized = true;
  }

  static Future<void> preload({String prefix = ''}) async {
    await ensureInitialized();
    await AppSettingsStorage.load(prefix: prefix);
  }

  @override
  void onInit() {
    super.onInit();
    autoDispose(theme);
    autoDispose(language);
    autoDispose(timezone);
    autoDispose(dateFormat);
    autoDispose(timeFormat);
    _applySnapshot(AppSettingsStorage.cached);
  }

  ThemeMode get themeMode => theme.value.themeMode;

  Locale? get locale => language.value.locale;

  Locale? resolveLocale(
    Locale? deviceLocale,
    Iterable<Locale> supportedLocales,
  ) {
    return supportedAppLocale(locale ?? deviceLocale, supportedLocales);
  }

  Future<void> setTheme(ThemePreference value) =>
      _update(AppSettingsStorage.cached.copyWith(theme: value));

  Future<void> setLanguage(LanguagePreference value) =>
      _update(AppSettingsStorage.cached.copyWith(language: value));

  Future<void> setTimezone(AppTimezone value) =>
      _update(AppSettingsStorage.cached.copyWith(timezone: value));

  Future<void> setDateFormat(DateFormatPreference value) =>
      _update(AppSettingsStorage.cached.copyWith(dateFormat: value));

  Future<void> setTimeFormat(TimeFormatPreference value) =>
      _update(AppSettingsStorage.cached.copyWith(timeFormat: value));

  DateTime toDisplayTime(DateTime dateTime) {
    final local = dateTime.toLocal();
    final locationName = timezone.value.locationName;
    if (locationName == null) {
      return local;
    }

    final location = tz.getLocation(locationName);
    return tz.TZDateTime.from(local.toUtc(), location);
  }

  Future<void> _update(AppSettingsSnapshot snapshot) async {
    _applySnapshot(await AppSettingsStorage.save(snapshot, prefix: prefix));
  }

  void _applySnapshot(AppSettingsSnapshot snapshot) {
    theme(snapshot.theme);
    language(snapshot.language);
    timezone(snapshot.timezone);
    dateFormat(snapshot.dateFormat);
    timeFormat(snapshot.timeFormat);
  }
}
