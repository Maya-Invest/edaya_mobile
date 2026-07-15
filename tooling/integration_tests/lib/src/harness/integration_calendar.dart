import '../config/integration_config.dart';

/// Demo-ci narrative calendar day for widget and API integration probes.
DateTime integrationCalendarReferenceDay() {
  final parsed = IntegrationConfig.fromEnvironment().calendarReferenceDay;
  final local = DateTime(parsed.year, parsed.month, parsed.day);
  if (local.weekday == DateTime.saturday) {
    return local.subtract(const Duration(days: 5));
  }
  if (local.weekday == DateTime.sunday) {
    return local.subtract(const Duration(days: 6));
  }
  return local;
}

/// Picks the school calendar event whose [startDate] is closest to the reference day.
Map<String, dynamic>? calendarEventNearReference(
  List<Map<String, dynamic>> events, {
  DateTime? reference,
}) {
  if (events.isEmpty) {
    return null;
  }

  final anchor = reference ?? integrationCalendarReferenceDay();
  Map<String, dynamic>? closest;
  var closestDistance = 1 << 30;

  for (final event in events) {
    final startDate = event['startDate'] as String?;
    if (startDate == null) {
      continue;
    }
    final day = DateTime.parse(startDate);
    final distance = day.difference(anchor).inDays.abs();
    if (distance < closestDistance) {
      closestDistance = distance;
      closest = event;
    }
  }

  return closest;
}
