import 'dart:convert';

import 'package:edaya_shared/edaya_shared.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// One editor's values. A chapter edit never contains general-information fields.
class LogbookEdit {
  const LogbookEdit.general(
    this.note, {
    this.reason = '',
    this.needsReview = false,
  }) : chapterId = null,
       completed = null,
       removed = false,
       chapterNotes = null;
  const LogbookEdit.chapter(
    String this.chapterId,
    bool this.completed, {
    this.chapterNotes,
    this.reason = '',
    this.removed = false,
    this.needsReview = false,
  }) : note = null;

  final StructuredLogbookContent? note;
  final String? chapterId;
  final String? chapterNotes;
  final bool? completed;
  final bool removed;
  final bool needsReview;
  final String reason;
  String get key => chapterId == null ? 'general' : 'chapter:$chapterId';

  Map<String, dynamic> toJson() => {
    if (note != null) 'sessionNote': encodeStructuredSessionNote(note!),
    if (chapterId != null) 'chapterId': chapterId,
    if (completed != null) 'completed': completed,
    if (removed) 'removed': true,
    if (chapterNotes != null) 'chapterNotes': chapterNotes,
    if (needsReview) 'needsReview': true,
    'reason': reason,
  };

  factory LogbookEdit.fromJson(
    Map<String, dynamic> json, {
    bool stale = false,
  }) {
    final reason = json['reason'] as String? ?? '';
    if (json['chapterId'] case final String id) {
      return LogbookEdit.chapter(
        id,
        json['completed'] as bool? ?? json['percentage'] == 100,
        chapterNotes: json['chapterNotes'] as String?,
        removed: json['removed'] == true,
        reason: reason,
        needsReview:
            stale ||
            json['needsReview'] == true ||
            json.containsKey('percentage'),
      );
    }
    return LogbookEdit.general(
      decodeStructuredSessionNote(json['sessionNote'] as String?),
      reason: reason,
      needsReview: stale || json['needsReview'] == true,
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
    int? proposalVersion, {
    String prefix = '',
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(prefix + _key(sessionId, context));
    if (raw == null) return {};
    try {
      final data = jsonDecode(raw) as Map<String, dynamic>;
      final stale =
          (data['revision'] ?? 0) != revision ||
          data['proposalVersion'] != proposalVersion;
      if (data['sections'] case final Map sections) {
        return {
          for (final entry in sections.entries)
            entry.key as String: LogbookEdit.fromJson(
              Map<String, dynamic>.from(entry.value as Map),
              stale: stale,
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
        'general': LogbookEdit.general(
          note,
          reason: reason,
          needsReview: stale,
        ),
        for (final row
            in (data['progressEntries'] as List? ?? const []).whereType<Map>())
          if (row['matterId'] is String && row['completedPercentage'] is int)
            'chapter:${row['matterId']}': LogbookEdit.chapter(
              row['matterId'] as String,
              row['completedPercentage'] == 100,
              needsReview: true,
              reason: reason,
            ),
      };
    } on Object {
      return {};
    }
  }

  /// Restore the edited section when known. Legacy split writes carry per-chapter notes.
  static Map<String, LogbookEdit> fromQueued(Map<String, dynamic> payload) {
    final body = payload['body'] as Map?;
    final proposal = body?['proposal'] as Map?;
    final reason = body?['reason'] as String? ?? '';
    final section = payload['section'];
    final note = proposal ?? payload['notePayload'] as Map?;
    final edits = <String, LogbookEdit>{};
    if (note != null && (section == null || section == 'general')) {
      edits['general'] = LogbookEdit.general(
        decodeStructuredSessionNote(note['sessionNote'] as String?),
        reason: reason,
        needsReview: true,
      );
    }
    final rows = proposal != null
        ? (proposal['progress'] as List? ?? []).whereType<Map>()
        : (payload['progressOps'] as List? ?? [])
              .whereType<Map>()
              .map((op) => op['payload'])
              .whereType<Map>();
    for (final row in rows) {
      final id = (row['matterId'] ?? row['classSubjectMatterId']) as String;
      if (section != null && section != 'chapter:$id') continue;
      final edit = LogbookEdit.chapter(
        id,
        row['completedPercentage'] == 100,
        chapterNotes: row['notes'] as String?,
        reason: reason,
        needsReview: true,
      );
      edits[edit.key] = edit;
    }
    if (section is String &&
        section.startsWith('chapter:') &&
        !edits.containsKey(section) &&
        proposal != null) {
      edits[section] = LogbookEdit.chapter(
        section.substring('chapter:'.length),
        false,
        removed: true,
        reason: reason,
        needsReview: true,
      );
    }
    return edits;
  }

  // Keep a newer local section visible first. Conflicting queued edits are
  // promoted one at a time when the teacher resolves that section.
  static Map<String, LogbookEdit> mergeRecovered(
    Map<String, LogbookEdit> drafts,
    Map<String, LogbookEdit> recovered,
    String sourceId,
  ) {
    final merged = Map.of(drafts);
    for (final entry in recovered.entries) {
      final existing = merged[entry.key];
      if (existing == null) {
        merged[entry.key] = entry.value;
      } else if (jsonEncode(existing.toJson()) !=
          jsonEncode(entry.value.toJson())) {
        merged['recovered:${jsonEncode([sourceId, entry.key])}'] = entry.value;
      }
    }
    return merged;
  }

  static Map<String, LogbookEdit> resolveSection(
    Map<String, LogbookEdit> drafts,
    String? section,
  ) {
    final remaining = Map.of(drafts)..remove(section);
    final next = remaining.entries
        .where(
          (entry) =>
              entry.key.startsWith('recovered:') && entry.value.key == section,
        )
        .firstOrNull;
    if (next != null) {
      remaining.remove(next.key);
      remaining[next.value.key] = next.value;
    }
    return remaining;
  }

  static Future<void> archiveQueue(
    String sessionId,
    TeacherOutboxContext? context,
    String prefix,
    TeacherOutboxEntry entry,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final body = entry.payload['body'] as Map?;
    final key =
        '${prefix}${_key(sessionId, context)}_recovery_${body?['requestId'] ?? entry.idempotencyKey}';
    if (!await prefs.setString(key, jsonEncode(entry.toJson())))
      throw StateError('Could not retain queued logbook evidence');
  }

  static Future<void> save(
    String sessionId,
    TeacherOutboxContext? context,
    int revision,
    int? proposalVersion,
    Map<String, LogbookEdit> sections, {
    String prefix = '',
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final key = prefix + _key(sessionId, context);
    if (sections.isEmpty) {
      await prefs.remove(key);
      return;
    }
    final original = prefs.getString(key);
    if (original != null &&
        (jsonDecode(original) as Map)['formatVersion'] != 2 &&
        !prefs.containsKey('${key}_legacy') &&
        !await prefs.setString('${key}_legacy', original)) {
      throw StateError('Could not retain the original logbook draft');
    }
    final persisted = await prefs.setString(
      key,
      jsonEncode({
        'formatVersion': 2,
        'revision': revision,
        'proposalVersion': proposalVersion,
        'sections': {
          for (final entry in sections.entries) entry.key: entry.value.toJson(),
        },
      }),
    );
    if (!persisted) throw StateError('Could not persist logbook draft');
  }
}
