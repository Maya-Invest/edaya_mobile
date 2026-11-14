import 'dart:convert';

import 'package:edaya_shared/edaya_shared.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// One editor's values. A chapter edit never contains general-information fields.
class LogbookEdit {
  const LogbookEdit.general(this.note, {this.reason = ''})
    : chapterId = null,
      percentage = null;
  const LogbookEdit.chapter(
    String this.chapterId,
    int this.percentage, {
    this.reason = '',
  }) : note = null;

  final StructuredLogbookContent? note;
  final String? chapterId;
  final int? percentage;
  final String reason;
  String get key => chapterId == null ? 'general' : 'chapter:$chapterId';

  Map<String, dynamic> toJson() => {
    if (note != null) 'sessionNote': encodeStructuredSessionNote(note!),
    if (chapterId != null) 'chapterId': chapterId,
    if (percentage != null) 'percentage': percentage,
    'reason': reason,
  };

  factory LogbookEdit.fromJson(Map<String, dynamic> json) {
    final reason = json['reason'] as String? ?? '';
    if (json['chapterId'] case final String id) {
      return LogbookEdit.chapter(id, json['percentage'] as int, reason: reason);
    }
    return LogbookEdit.general(
      decodeStructuredSessionNote(json['sessionNote'] as String?),
      reason: reason,
    );
  }
}

abstract final class SessionLogbookDraftStorage {
  static String _key(String sessionId, TeacherOutboxContext? context) {
    final scope = context == null
        ? 'unscoped'
        : '${context.origin}|${context.subjectId}|${context.actorId}|${context.schoolId}|${context.academicYearId ?? ''}';
    return 'teacher_logbook_draft_${scope}_$sessionId';
  }

  static Future<Map<String, LogbookEdit>> load(
    String sessionId,
    TeacherOutboxContext? context,
    int revision,
    int? proposalVersion,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key(sessionId, context));
    if (raw == null) return {};
    try {
      final data = jsonDecode(raw) as Map<String, dynamic>;
      if ((data['revision'] ?? 0) != revision ||
          data['proposalVersion'] != proposalVersion) {
        return {};
      }
      if (data['sections'] case final Map sections) {
        return {
          for (final entry in sections.entries)
            entry.key as String: LogbookEdit.fromJson(
              Map<String, dynamic>.from(entry.value as Map),
            ),
        };
      }
      // The previous combined form stored the note and one selected chapter together.
      final reason = data['correctionReason'] as String? ?? '';
      final note = StructuredLogbookContent(
        content: data['sessionNote'] as String? ?? '',
        objectives: (data['objectives'] as String? ?? '')
            .split('\n')
            .where((s) => s.isNotEmpty)
            .toList(),
        homework: data['homework'] as String?,
        familySummary: data['familySummary'] as String?,
      );
      return {
        'general': LogbookEdit.general(note, reason: reason),
        for (final row
            in (data['progressEntries'] as List? ?? const []).whereType<Map>())
          if (row['matterId'] is String && row['completedPercentage'] is int)
            'chapter:${row['matterId']}': LogbookEdit.chapter(
              row['matterId'] as String,
              row['completedPercentage'] as int,
              reason: reason,
            ),
      };
    } on Object {
      return {};
    }
  }

  static Future<void> save(
    String sessionId,
    TeacherOutboxContext? context,
    int revision,
    int? proposalVersion,
    Map<String, LogbookEdit> sections,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final key = _key(sessionId, context);
    if (sections.isEmpty) {
      await prefs.remove(key);
      return;
    }
    await prefs.setString(
      key,
      jsonEncode({
        'revision': revision,
        'proposalVersion': proposalVersion,
        'sections': {
          for (final entry in sections.entries) entry.key: entry.value.toJson(),
        },
      }),
    );
  }
}
