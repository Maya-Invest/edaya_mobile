import 'package:edaya_shared/edaya_shared.dart';

class AcademicPeriod {
  const AcademicPeriod({
    required this.id,
    required this.name,
    required this.startDate,
    required this.endDate,
  });

  factory AcademicPeriod.fromJson(Map<String, dynamic> json) {
    final startDate = parseApiDateTime(json['startDate']);
    final endDate = parseApiDateTime(json['endDate']);
    if (startDate == null || endDate == null) {
      throw FormatException('Academic period ${json['id']} has invalid dates');
    }

    return AcademicPeriod(
      id: json['id'] as String,
      name: json['name'] as String,
      startDate: startDate,
      endDate: endDate,
    );
  }

  final String id;
  final String name;
  final DateTime startDate;
  final DateTime endDate;
}
