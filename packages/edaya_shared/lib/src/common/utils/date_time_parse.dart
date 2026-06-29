import 'package:intl/intl.dart';

DateTime? parseApiDateTime(Object? value) {
  if (value == null) {
    return null;
  }
  if (value is DateTime) {
    return value;
  }
  if (value is String && value.isNotEmpty) {
    return DateTime.tryParse(value);
  }
  return DateTime.tryParse(value.toString());
}

DateTime startOfWeek(DateTime date) {
  final local = DateTime(date.year, date.month, date.day);
  final weekday = local.weekday;
  return local.subtract(Duration(days: weekday - DateTime.monday));
}

bool isSameCalendarDay(DateTime a, DateTime b) {
  return a.year == b.year && a.month == b.month && a.day == b.day;
}

DateTime defaultCalendarDay([DateTime? reference]) {
  final local = reference ?? DateTime.now();
  final day = DateTime(local.year, local.month, local.day);
  if (day.weekday == DateTime.saturday) {
    return day.subtract(const Duration(days: 5));
  }
  if (day.weekday == DateTime.sunday) {
    return day.subtract(const Duration(days: 6));
  }
  return day;
}

String formatTimeOfDay(DateTime dateTime, [String? locale]) {
  return DateFormat.Hm(locale).format(dateTime);
}

String formatShortDate(DateTime dateTime, [String? locale]) {
  return DateFormat.MMMEd(locale).format(dateTime);
}

String formatWeekRange(DateTime weekStart, [String? locale]) {
  final weekEnd = weekStart.add(const Duration(days: 6));
  return '${formatShortDate(weekStart, locale)} – ${formatShortDate(weekEnd, locale)}';
}

String formatLongDate(DateTime dateTime, [String? locale]) {
  return DateFormat.yMMMMEEEEd(locale).format(dateTime);
}
