import 'package:edaya_shared/edaya_shared.dart';

class SchoolEvent {
  const SchoolEvent({
    required this.id,
    required this.title,
    required this.startDate,
    required this.endDate,
    required this.kind,
    required this.isNonSchoolDay,
    this.description,
  });

  factory SchoolEvent.fromJson(Map<String, dynamic> json) {
    final startDate = parseApiDateTime(json['startDate']);
    final endDate = parseApiDateTime(json['endDate']);
    if (startDate == null || endDate == null) {
      throw FormatException('Calendar event ${json['id']} has invalid dates');
    }

    return SchoolEvent(
      id: json['id'] as String,
      title: json['title'] as String,
      startDate: startDate.toLocal(),
      endDate: endDate.toLocal(),
      kind: json['kind'] as String? ?? 'event',
      isNonSchoolDay: json['isNonSchoolDay'] as bool? ?? false,
      description: json['description'] as String?,
    );
  }

  final String id;
  final String title;
  final DateTime startDate;
  final DateTime endDate;
  final String kind;
  final bool isNonSchoolDay;
  final String? description;

  String kindLabel(AppLocalizations tr) => switch (kind) {
    'holiday' => tr.calendarHoliday,
    'break' => tr.calendarBreak,
    'event' => tr.calendarEvent,
    _ => tr.evaluationKindOther,
  };

  bool occursOn(DateTime day) {
    final start = DateTime(startDate.year, startDate.month, startDate.day);
    final end = DateTime(endDate.year, endDate.month, endDate.day);
    final target = DateTime(day.year, day.month, day.day);
    return !target.isBefore(start) && !target.isAfter(end);
  }
}
