import 'package:flutter/material.dart';
import 'package:levit_flutter/levit_flutter.dart';

import '../../l10n/l10n_extension.dart';
import 'app_settings_controller.dart';
import 'app_settings_models.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key, this.embedded = false, this.footer});
  final bool embedded;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final settings = context.levit.find<AppSettingsController>();

    final content = ListView(
      children: [
        _SectionHeader(title: context.tr.settingsTheme),
        LWatch(
          () => _PreferenceCard(
            child: RadioGroup<ThemePreference>(
              groupValue: settings.theme.value,
              onChanged: (value) {
                if (value != null) {
                  settings.setTheme(value);
                }
              },
              child: Column(
                children: [
                  for (final option in ThemePreference.values)
                    RadioListTile<ThemePreference>(
                      title: Text(_themeLabel(context, option)),
                      value: option,
                    ),
                ],
              ),
            ),
          ),
        ),
        _SectionHeader(title: context.tr.settingsLanguage),
        LWatch(
          () => _PreferenceCard(
            child: RadioGroup<LanguagePreference>(
              groupValue: settings.language.value,
              onChanged: (value) {
                if (value != null) {
                  settings.setLanguage(value);
                }
              },
              child: Column(
                children: [
                  for (final option in LanguagePreference.values)
                    RadioListTile<LanguagePreference>(
                      title: Text(_languageLabel(context, option)),
                      value: option,
                    ),
                ],
              ),
            ),
          ),
        ),
        _SectionHeader(title: context.tr.settingsTimezone),
        LWatch(
          () => _PreferenceCard(
            child: RadioGroup<AppTimezone>(
              groupValue: settings.timezone.value,
              onChanged: (value) {
                if (value != null) {
                  settings.setTimezone(value);
                }
              },
              child: Column(
                children: [
                  for (final option in AppTimezone.values)
                    RadioListTile<AppTimezone>(
                      title: Text(_timezoneLabel(context, option)),
                      value: option,
                    ),
                ],
              ),
            ),
          ),
        ),
        _SectionHeader(title: context.tr.settingsDateFormat),
        LWatch(
          () => _PreferenceCard(
            child: RadioGroup<DateFormatPreference>(
              groupValue: settings.dateFormat.value,
              onChanged: (value) {
                if (value != null) {
                  settings.setDateFormat(value);
                }
              },
              child: Column(
                children: [
                  for (final option in DateFormatPreference.values)
                    RadioListTile<DateFormatPreference>(
                      title: Text(_dateFormatLabel(context, option)),
                      value: option,
                    ),
                ],
              ),
            ),
          ),
        ),
        _SectionHeader(title: context.tr.settingsTimeFormat),
        LWatch(
          () => _PreferenceCard(
            child: RadioGroup<TimeFormatPreference>(
              groupValue: settings.timeFormat.value,
              onChanged: (value) {
                if (value != null) {
                  settings.setTimeFormat(value);
                }
              },
              child: Column(
                children: [
                  for (final option in TimeFormatPreference.values)
                    RadioListTile<TimeFormatPreference>(
                      title: Text(_timeFormatLabel(context, option)),
                      value: option,
                    ),
                ],
              ),
            ),
          ),
        ),
        if (footer != null) footer!,
        const SizedBox(height: 24),
      ],
    );
    return embedded
        ? content
        : Scaffold(
            appBar: AppBar(title: Text(context.tr.settingsTitle)),
            body: content,
          );
  }

  String _themeLabel(BuildContext context, ThemePreference value) {
    return switch (value) {
      ThemePreference.system => context.tr.settingsThemeSystem,
      ThemePreference.light => context.tr.settingsThemeLight,
      ThemePreference.dark => context.tr.settingsThemeDark,
    };
  }

  String _languageLabel(BuildContext context, LanguagePreference value) {
    return switch (value) {
      LanguagePreference.system => context.tr.settingsLanguageSystem,
      LanguagePreference.en => context.tr.settingsLanguageEnglish,
      LanguagePreference.fr => context.tr.settingsLanguageFrench,
    };
  }

  String _timezoneLabel(BuildContext context, AppTimezone value) {
    return switch (value) {
      AppTimezone.device => context.tr.settingsTimezoneDevice,
      AppTimezone.utc => context.tr.settingsTimezoneUtc,
      AppTimezone.europeParis => context.tr.settingsTimezoneParis,
      AppTimezone.africaAbidjan => context.tr.settingsTimezoneAbidjan,
      AppTimezone.africaLagos => context.tr.settingsTimezoneLagos,
      AppTimezone.americaNewYork => context.tr.settingsTimezoneNewYork,
    };
  }

  String _dateFormatLabel(BuildContext context, DateFormatPreference value) {
    return switch (value) {
      DateFormatPreference.system => context.tr.settingsDateFormatSystem,
      DateFormatPreference.short => context.tr.settingsDateFormatShort,
      DateFormatPreference.medium => context.tr.settingsDateFormatMedium,
      DateFormatPreference.long => context.tr.settingsDateFormatLong,
    };
  }

  String _timeFormatLabel(BuildContext context, TimeFormatPreference value) {
    return switch (value) {
      TimeFormatPreference.system => context.tr.settingsTimeFormatSystem,
      TimeFormatPreference.hour24 => context.tr.settingsTimeFormat24h,
      TimeFormatPreference.hour12 => context.tr.settingsTimeFormat12h,
    };
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
          color: Theme.of(context).colorScheme.primary,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _PreferenceCard extends StatelessWidget {
  const _PreferenceCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: child,
    );
  }
}
