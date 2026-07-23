import 'package:intl/intl.dart';

String formatMoney(double amount, String currency) {
  final formatter = NumberFormat.currency(
    locale: 'fr_FR',
    symbol: currency == 'EUR' ? 'EUR' : currency,
    decimalDigits: 0,
  );
  return formatter.format(amount);
}

String formatDayOfMonth(DateTime date) {
  return DateFormat('d', 'fr_FR').format(date);
}

String formatMonthAbbrev(DateTime date) {
  final raw = DateFormat('MMM', 'fr_FR').format(date).replaceAll('.', '').trim();
  if (raw.length <= 3) return raw;
  return raw.substring(0, 3);
}

String formatDate(DateTime date) {
  return DateFormat('d MMM yyyy', 'fr_FR').format(date);
}

String formatDateTime(DateTime date) {
  return DateFormat('d MMM yyyy · HH:mm', 'fr_FR').format(date);
}

String formatFullDate(DateTime date) {
  final formatted = DateFormat('EEEE d MMMM yyyy', 'fr_FR').format(date);
  if (formatted.isEmpty) return formatted;
  return '${formatted[0].toUpperCase()}${formatted.substring(1)}';
}

String formatTimeRange(int startHour, int endHour) {
  return '${startHour.toString().padLeft(2, '0')}:00 – ${endHour.toString().padLeft(2, '0')}:00';
}
