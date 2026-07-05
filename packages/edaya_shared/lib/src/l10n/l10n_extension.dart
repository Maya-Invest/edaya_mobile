import 'package:flutter/material.dart';
import 'package:levit_flutter/levit_flutter.dart';

import '../features/settings/app_date_formatting.dart';
import '../features/settings/app_settings_controller.dart';
import 'app_localizations.dart';

export 'app_localizations.dart';

extension AppLocalizationsContext on BuildContext {
  AppLocalizations get tr => AppLocalizations.of(this)!;

  AppSettingsController get appSettings => levit.find<AppSettingsController>();

  /// BCP 47 locale tag for [intl] date/time formatters.
  String get localeTag => Localizations.localeOf(this).toString();

  String formatShortDate(DateTime dateTime) => AppDateFormatting.shortDate(
    dateTime,
    settings: appSettings,
    localeTag: localeTag,
  );

  String formatLongDate(DateTime dateTime) => AppDateFormatting.longDate(
    dateTime,
    settings: appSettings,
    localeTag: localeTag,
  );

  String formatWeekRange(DateTime weekStart) => AppDateFormatting.weekRange(
    weekStart,
    settings: appSettings,
    localeTag: localeTag,
  );

  String formatTimeOfDay(DateTime dateTime) => AppDateFormatting.timeOfDay(
    dateTime,
    settings: appSettings,
    localeTag: localeTag,
  );
}
