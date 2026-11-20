import 'package:flutter/material.dart';

enum ThemePreference { system, light, dark }

enum LanguagePreference { system, en, fr }

enum DateFormatPreference { system, short, medium, long }

enum TimeFormatPreference { system, hour24, hour12 }

/// Supported IANA time zones. `null` means use the device time zone.
enum AppTimezone {
  device,
  utc,
  europeParis,
  africaAbidjan,
  africaLagos,
  americaNewYork,
}

extension ThemePreferenceX on ThemePreference {
  ThemeMode get themeMode => switch (this) {
    ThemePreference.system => ThemeMode.system,
    ThemePreference.light => ThemeMode.light,
    ThemePreference.dark => ThemeMode.dark,
  };
}

extension LanguagePreferenceX on LanguagePreference {
  Locale? get locale => switch (this) {
    LanguagePreference.system => null,
    LanguagePreference.en => const Locale('en'),
    LanguagePreference.fr => const Locale('fr'),
  };
}

extension AppTimezoneX on AppTimezone {
  String? get locationName => switch (this) {
    AppTimezone.device => null,
    AppTimezone.utc => 'UTC',
    AppTimezone.europeParis => 'Europe/Paris',
    AppTimezone.africaAbidjan => 'Africa/Abidjan',
    AppTimezone.africaLagos => 'Africa/Lagos',
    AppTimezone.americaNewYork => 'America/New_York',
  };

  static AppTimezone fromStorage(String? value) {
    if (value == null || value.isEmpty) {
      return AppTimezone.device;
    }
    return AppTimezone.values.firstWhere(
      (zone) => zone.name == value,
      orElse: () => AppTimezone.device,
    );
  }
}

class AppSettingsSnapshot {
  const AppSettingsSnapshot({
    required this.theme,
    required this.language,
    required this.timezone,
    required this.dateFormat,
    required this.timeFormat,
  });

  final ThemePreference theme;
  final LanguagePreference language;
  final AppTimezone timezone;
  final DateFormatPreference dateFormat;
  final TimeFormatPreference timeFormat;

  static const defaults = AppSettingsSnapshot(
    theme: ThemePreference.system,
    language: LanguagePreference.system,
    timezone: AppTimezone.device,
    dateFormat: DateFormatPreference.system,
    timeFormat: TimeFormatPreference.system,
  );

  AppSettingsSnapshot copyWith({
    ThemePreference? theme,
    LanguagePreference? language,
    AppTimezone? timezone,
    DateFormatPreference? dateFormat,
    TimeFormatPreference? timeFormat,
  }) {
    return AppSettingsSnapshot(
      theme: theme ?? this.theme,
      language: language ?? this.language,
      timezone: timezone ?? this.timezone,
      dateFormat: dateFormat ?? this.dateFormat,
      timeFormat: timeFormat ?? this.timeFormat,
    );
  }
}
