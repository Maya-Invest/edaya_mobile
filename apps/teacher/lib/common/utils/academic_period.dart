import 'date_time_parse.dart';

String? currentAcademicPeriodId(
  List<Map<String, dynamic>> periods, {
  DateTime? onDate,
}) {
  if (periods.isEmpty) {
    return null;
  }

  final date = onDate ?? DateTime.now();
  final calendarDay = DateTime(date.year, date.month, date.day);

  for (final period in periods) {
    final start = parseApiDateTime(period['startDate']);
    final end = parseApiDateTime(period['endDate']);
    if (start == null || end == null) {
      continue;
    }
    final startDay = DateTime(start.year, start.month, start.day);
    final endDay = DateTime(end.year, end.month, end.day);
    if (!calendarDay.isBefore(startDay) && !calendarDay.isAfter(endDay)) {
      return period['id'] as String;
    }
  }

  return periods.first['id'] as String;
}

List<Map<String, dynamic>> sortAcademicPeriods(
  List<Map<String, dynamic>> periods,
) {
  final sorted = periods.toList(growable: true)
    ..sort((a, b) {
      final aStart = parseApiDateTime(a['startDate']);
      final bStart = parseApiDateTime(b['startDate']);
      if (aStart == null || bStart == null) {
        return 0;
      }
      return aStart.compareTo(bStart);
    });
  return sorted;
}

String academicPeriodLabel(Map<String, dynamic> period) {
  return period['name'] as String? ?? period['id'] as String;
}
