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

String formatTimeOfDay(DateTime dateTime) {
  final hours = dateTime.hour.toString().padLeft(2, '0');
  final minutes = dateTime.minute.toString().padLeft(2, '0');
  return '$hours:$minutes';
}

String formatShortDate(DateTime dateTime) {
  const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  final weekday = weekdays[dateTime.weekday - 1];
  return '$weekday ${dateTime.day}/${dateTime.month}';
}

String formatLongDate(DateTime dateTime) {
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  const weekdays = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];
  return '${weekdays[dateTime.weekday - 1]}, ${dateTime.day} ${months[dateTime.month - 1]} ${dateTime.year}';
}
