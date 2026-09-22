import 'dart:convert';

import 'package:edaya_shared/edaya_shared.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SessionLogbookDraft {
  const SessionLogbookDraft({
    required this.sessionNote,
    required this.objectives,
    required this.homework,
    required this.familySummary,
    required this.progressEntries,
    required this.updatedAt,
  });

  final String sessionNote;
  final String objectives;
  final String homework;
  final String familySummary;
  final List<SessionLogbookDraftProgressEntry> progressEntries;
  final DateTime updatedAt;

  Map<String, dynamic> toJson() {
    return {
      'sessionNote': sessionNote,
      'objectives': objectives,
      'homework': homework,
      'familySummary': familySummary,
      'progressEntries': [
        for (final entry in progressEntries) entry.toJson(),
      ],
      'updatedAt': updatedAt.toUtc().toIso8601String(),
    };
  }

  factory SessionLogbookDraft.fromJson(Map<String, dynamic> json) {
    final rawEntries = json['progressEntries'];
    return SessionLogbookDraft(
      sessionNote: json['sessionNote'] as String? ?? '',
      objectives: json['objectives'] as String? ?? '',
      homework: json['homework'] as String? ?? '',
      familySummary: json['familySummary'] as String? ?? '',
      progressEntries: rawEntries is List
          ? rawEntries
                .whereType<Map>()
                .map(
                  (entry) => SessionLogbookDraftProgressEntry.fromJson(
                    entry.cast<String, dynamic>(),
                  ),
                )
                .toList()
          : const [],
      updatedAt: DateTime.tryParse(json['updatedAt'] as String? ?? '') ??
          DateTime.now(),
    );
  }
}

class SessionLogbookDraftProgressEntry {
  const SessionLogbookDraftProgressEntry({
    required this.matterId,
    required this.completedPercentage,
    required this.notes,
    required this.isEditingExisting,
  });

  final String matterId;
  final int completedPercentage;
  final String notes;
  final bool isEditingExisting;

  Map<String, dynamic> toJson() {
    return {
      'matterId': matterId,
      'completedPercentage': completedPercentage,
      'notes': notes,
      'isEditingExisting': isEditingExisting,
    };
  }

  factory SessionLogbookDraftProgressEntry.fromJson(Map<String, dynamic> json) {
    return SessionLogbookDraftProgressEntry(
      matterId: json['matterId'] as String? ?? '',
      completedPercentage: (json['completedPercentage'] as num?)?.toInt() ?? 0,
      notes: json['notes'] as String? ?? '',
      isEditingExisting: json['isEditingExisting'] as bool? ?? false,
    );
  }
}

abstract final class SessionLogbookDraftStorage {
  SessionLogbookDraftStorage._();

  static String _key(String sessionId, TeacherOutboxContext? context) {
    final scope = context == null
        ? 'unscoped'
        : '${context.origin}|${context.subjectId}|${context.actorId}|${context.schoolId}|${context.academicYearId ?? ''}';
    return 'teacher_logbook_draft_${scope}_$sessionId';
  }

  static Future<SessionLogbookDraft?> load(
    String sessionId, {
    TeacherOutboxContext? context,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key(sessionId, context));
    if (raw == null || raw.isEmpty) {
      return null;
    }

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) {
        return null;
      }
      return SessionLogbookDraft.fromJson(decoded);
    } on Object {
      return null;
    }
  }

  static Future<void> save(
    String sessionId,
    SessionLogbookDraft draft, {
    TeacherOutboxContext? context,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key(sessionId, context), jsonEncode(draft.toJson()));
  }

  static Future<void> clear(
    String sessionId, {
    TeacherOutboxContext? context,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key(sessionId, context));
  }
}
