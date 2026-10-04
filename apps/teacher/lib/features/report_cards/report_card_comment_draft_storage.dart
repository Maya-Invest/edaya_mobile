import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class ReportCardCommentDraft {
  const ReportCardCommentDraft({
    required this.commentsBySectionId,
    required this.updatedAt,
  });

  final Map<String, String> commentsBySectionId;
  final DateTime updatedAt;

  Map<String, dynamic> toJson() {
    return {
      'commentsBySectionId': commentsBySectionId,
      'updatedAt': updatedAt.toUtc().toIso8601String(),
    };
  }

  factory ReportCardCommentDraft.fromJson(Map<String, dynamic> json) {
    final raw = json['commentsBySectionId'];
    return ReportCardCommentDraft(
      commentsBySectionId: raw is Map
          ? raw.map((key, value) => MapEntry('$key', '$value'))
          : const {},
      updatedAt:
          DateTime.tryParse(json['updatedAt'] as String? ?? '') ??
          DateTime.now(),
    );
  }
}

abstract final class ReportCardCommentDraftStorage {
  ReportCardCommentDraftStorage._();

  static String _key(String resultId, String studentId) =>
      'teacher_report_comment_draft_${resultId}_$studentId';

  static Future<ReportCardCommentDraft?> load({
    required String resultId,
    required String studentId,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key(resultId, studentId));
    if (raw == null || raw.isEmpty) {
      return null;
    }

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) {
        return null;
      }
      return ReportCardCommentDraft.fromJson(decoded);
    } on Object {
      return null;
    }
  }

  static Future<void> save({
    required String resultId,
    required String studentId,
    required ReportCardCommentDraft draft,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _key(resultId, studentId),
      jsonEncode(draft.toJson()),
    );
  }

  static Future<void> clear({
    required String resultId,
    required String studentId,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key(resultId, studentId));
  }
}
