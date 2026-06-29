import 'package:intl/intl.dart';

import 'app_settings_controller.dart';
import 'app_settings_models.dart';

abstract final class AppDateFormatting {
  static String shortDate(
    DateTime dateTime, {
    required AppSettingsController settings,
    required String localeTag,
  }) {
    final display = settings.toDisplayTime(dateTime);
    return _dateFormat(settings.dateFormat.value, localeTag).format(display);
  }

  static String longDate(
    DateTime dateTime, {
    required AppSettingsController settings,
    required String localeTag,
  }) {
    final display = settings.toDisplayTime(dateTime);
    return DateFormat.yMMMMEEEEd(localeTag).format(display);
  }

  static String weekRange(
    DateTime weekStart, {
    required AppSettingsController settings,
    required String localeTag,
  }) {
    final weekEnd = weekStart.add(const Duration(days: 6));
    return '${shortDate(weekStart, settings: settings, localeTag: localeTag)} – ${shortDate(weekEnd, settings: settings, localeTag: localeTag)}';
  }

  static String timeOfDay(
    DateTime dateTime, {
    required AppSettingsController settings,
    required String localeTag,
  }) {
    final display = settings.toDisplayTime(dateTime);
    return _timeFormat(settings.timeFormat.value, localeTag).format(display);
  }

  static DateFormat _dateFormat(DateFormatPreference preference, String locale) {
    return switch (preference) {
      DateFormatPreference.system => DateFormat.yMMMd(locale),
      DateFormatPreference.short => DateFormat.yMd(locale),
      DateFormatPreference.medium => DateFormat.yMMMd(locale),
      DateFormatPreference.long => DateFormat.yMMMEd(locale),
    };
  }

  static DateFormat _timeFormat(TimeFormatPreference preference, String locale) {
    return switch (preference) {
      TimeFormatPreference.system => DateFormat.jm(locale),
      TimeFormatPreference.hour24 => DateFormat.Hm(locale),
      TimeFormatPreference.hour12 => DateFormat.jm(locale),
    };
  }
}
