import 'dart:convert';

const structuredLogbookPrefix = '{"edayaLogbook":';

/// Teacher-authored lesson note stored in `sessionNote`.
///
/// Guardians should see [content], [objectives] and [homework].
/// [familySummary] stays on the teacher draft and is not a parent-facing field.
class StructuredLogbookContent {
  const StructuredLogbookContent({
    required this.content,
    this.objectives = const [],
    this.homework,
    this.familySummary,
  });

  final String content;
  final List<String> objectives;
  final String? homework;
  final String? familySummary;

  bool get isEmpty =>
      content.trim().isEmpty &&
      objectives.isEmpty &&
      (homework == null || homework!.trim().isEmpty) &&
      (familySummary == null || familySummary!.trim().isEmpty);

  bool get isComplete => !isEmpty;

  /// Parent-facing text. Plain legacy notes are returned unchanged.
  String get guardianText {
    final parts = <String>[
      if (content.trim().isNotEmpty) content.trim(),
      if (objectives.isNotEmpty) objectives.join('\n'),
      if (homework != null && homework!.trim().isNotEmpty) homework!.trim(),
    ];
    return parts.join('\n');
  }
}

StructuredLogbookContent decodeStructuredSessionNote(String? raw) {
  final value = raw?.trim() ?? '';
  if (value.isEmpty) {
    return const StructuredLogbookContent(content: '');
  }
  if (!value.startsWith(structuredLogbookPrefix)) {
    return StructuredLogbookContent(content: value);
  }

  try {
    final decoded = jsonDecode(value);
    if (decoded is! Map<String, dynamic>) {
      return StructuredLogbookContent(content: value);
    }
    final envelope = decoded['edayaLogbook'];
    if (envelope is! Map<String, dynamic>) {
      return StructuredLogbookContent(content: value);
    }

    final objectivesRaw = envelope['objectives'];
    return StructuredLogbookContent(
      content: envelope['content'] as String? ?? '',
      objectives: objectivesRaw is List
          ? objectivesRaw.map((item) => item.toString()).toList()
          : const [],
      homework: envelope['homework'] as String?,
      familySummary: envelope['familySummary'] as String?,
    );
  } on Object {
    return StructuredLogbookContent(content: value);
  }
}

String encodeStructuredSessionNote(StructuredLogbookContent content) {
  if (content.isEmpty) {
    return '';
  }

  final hasStructuredFields =
      content.objectives.isNotEmpty ||
      (content.homework != null && content.homework!.trim().isNotEmpty) ||
      (content.familySummary != null &&
          content.familySummary!.trim().isNotEmpty);
  if (!hasStructuredFields) {
    final trimmed = content.content.trim();
    return trimmed;
  }

  return jsonEncode({
    'edayaLogbook': {
      'v': 1,
      'content': content.content.trim(),
      'objectives': content.objectives
          .map((item) => item.trim())
          .where((item) => item.isNotEmpty)
          .toList(),
      if (content.homework?.trim().isNotEmpty ?? false)
        'homework': content.homework!.trim(),
      if (content.familySummary?.trim().isNotEmpty ?? false)
        'familySummary': content.familySummary!.trim(),
    },
  });
}
