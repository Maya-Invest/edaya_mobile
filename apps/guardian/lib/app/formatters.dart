import 'package:edaya_shared/edaya_shared.dart';
import 'package:intl/intl.dart';

String formatMoney(double amount, String currency) {
  final formatter = NumberFormat.currency(
    locale: systemL10n().localeName,
    symbol: currency == 'EUR' ? '€' : currency,
    name: currency,
  );
  return formatter.format(amount);
}

String formatDayOfMonth(DateTime date) =>
    DateFormat.d(systemL10n().localeName).format(date);

String formatMonthAbbrev(DateTime date) =>
    DateFormat.MMM(systemL10n().localeName).format(date);

String formatDate(DateTime date) =>
    DateFormat.yMMMd(systemL10n().localeName).format(date);

String formatDateTime(DateTime date) => '${formatDate(date)} · ${_clock(date)}';

String formatFullDate(DateTime date) =>
    DateFormat.yMMMMEEEEd(systemL10n().localeName).format(date);

String _clock(DateTime date) => AppDateFormatting.clockFormat(
  AppSettingsStorage.cached.timeFormat,
  systemL10n().localeName,
).format(date);

String formatTimeRange(int startHour, int endHour) => formatClockRange(
  DateTime(2000, 1, 1, startHour),
  DateTime(2000, 1, 1, endHour),
);

String formatClockRange(DateTime start, DateTime end) =>
    '${_clock(start)} – ${_clock(end)}';
