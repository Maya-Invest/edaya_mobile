import 'package:edaya_shared/edaya_shared.dart';

class LogbookEntry {
  const LogbookEntry({
    required this.id,
    required this.chapter,
    required this.content,
    required this.progress,
    required this.date,
    this.homework,
    this.objectives = const [],
  });

  factory LogbookEntry.fromJson(Map<String, dynamic> json) {
    final date = parseApiDateTime(json['date']);
    if (date == null) {
      throw FormatException('Logbook entry ${json['id']} has invalid date');
    }

    return LogbookEntry(
      id: json['id'] as String,
      chapter: json['chapter'] as String,
      content: json['content'] as String,
      progress: json['progress'] as int? ?? 0,
      date: date.toLocal(),
      homework: json['homework'] as String?,
      objectives: (json['objectives'] as List<dynamic>? ?? const [])
          .map((value) => value.toString())
          .toList(),
    );
  }

  final String id;
  final String chapter;
  final String content;
  final int progress;
  final DateTime date;
  final String? homework;
  final List<String> objectives;
}
