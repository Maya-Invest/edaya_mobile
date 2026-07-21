import 'dart:convert';

import 'models/session_detail_models.dart';

const _structuredLogbookPrefix = '{"edayaLogbook":';

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
}

StructuredLogbookContent decodeStructuredSessionNote(String? raw) {
  final value = raw?.trim() ?? '';
  if (value.isEmpty) {
    return const StructuredLogbookContent(content: '');
  }
  if (!value.startsWith(_structuredLogbookPrefix)) {
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

  final hasStructuredFields = content.objectives.isNotEmpty ||
      (content.homework?.trim().isNotEmpty ?? false) ||
      (content.familySummary?.trim().isNotEmpty ?? false);

  if (!hasStructuredFields) {
    return normalizeSessionNote(content.content) ?? '';
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

String composeFamilyVisiblePreview(StructuredLogbookContent content) {
  final sections = <String>[];
  if (content.content.trim().isNotEmpty) {
    sections.add(content.content.trim());
  }
  if (content.objectives.isNotEmpty) {
    sections.add(content.objectives.map((item) => '• $item').join('\n'));
  }
  if (content.homework?.trim().isNotEmpty ?? false) {
    sections.add(content.homework!.trim());
  }
  final summary = content.familySummary?.trim();
  if (summary != null && summary.isNotEmpty) {
    return summary;
  }
  return sections.join('\n\n');
}

String? normalizeSessionNote(String? value) {
  final trimmed = value?.trim() ?? '';
  return trimmed.isEmpty ? null : trimmed;
}

ClassSubjectMatterStatus parseMatterStatus(String? value) {
  return switch (value) {
    'completed' => ClassSubjectMatterStatus.completed,
    'in_progress' => ClassSubjectMatterStatus.inProgress,
    _ => ClassSubjectMatterStatus.notStarted,
  };
}

SessionMatterProgress? parseSessionMatterProgress(Map<String, dynamic>? row) {
  if (row == null) {
    return null;
  }

  final recordedAtRaw = row['recordedAt'];
  return SessionMatterProgress(
    id: row['id'] as String,
    classSubjectMatterId: row['classSubjectMatterId'] as String,
    completedPercentage: (row['completedPercentage'] as num).toInt(),
    notes: row['notes'] as String?,
    recordedAt: recordedAtRaw == null
        ? null
        : DateTime.tryParse(recordedAtRaw.toString()),
  );
}

List<SessionSubjectMatterOption> buildSessionSubjectMatters({
  required List<Map<String, dynamic>> matterLinks,
  required List<Map<String, dynamic>> subjectMatters,
  required List<Map<String, dynamic>> sessionProgressRows,
  required String fallbackName,
}) {
  final matterNameById = {
    for (final matter in subjectMatters)
      matter['id'] as String: matter['name'] as String? ?? fallbackName,
  };
  final sequenceById = {
    for (final matter in subjectMatters)
      matter['id'] as String: (matter['sequenceOrder'] as num?)?.toInt() ?? 0,
  };
  final progressByMatterId = {
    for (final row in sessionProgressRows)
      row['classSubjectMatterId'] as String: row,
  };

  final options =
      matterLinks.map((link) {
        final linkId = link['id'] as String;
        final subjectMatterId = link['subjectMatterId'] as String;
        final progressRow = progressByMatterId[linkId];
        final cumulative = (link['completedPercentage'] as num?)?.toInt() ?? 0;
        return SessionSubjectMatterOption(
          id: linkId,
          name: matterNameById[subjectMatterId] ?? fallbackName,
          sequenceOrder: sequenceById[subjectMatterId] ?? 0,
          status: progressRow != null
              ? ClassSubjectMatterStatus.inProgress
              : parseMatterStatus(link['status'] as String?),
          cumulativePercentage: cumulative,
          sessionProgress: parseSessionMatterProgress(progressRow),
        );
      }).toList()..sort((left, right) {
        final orderCompare = left.sequenceOrder.compareTo(right.sequenceOrder);
        if (orderCompare != 0) {
          return orderCompare;
        }
        return left.name.compareTo(right.name);
      });

  return options;
}

/// Matters that already have a progress snapshot for this lesson session.
List<SessionSubjectMatterOption> recordedSessionMatters(
  List<SessionSubjectMatterOption> matters,
) {
  return matters.where((matter) => matter.hasSessionProgress).toList();
}

/// Matters linked to the class subject that are not yet recorded for this session.
List<SessionSubjectMatterOption> pickableSessionMatters(
  List<SessionSubjectMatterOption> matters,
) {
  return matters.where((matter) => !matter.hasSessionProgress).toList();
}

int minMatterProgressPercentage(SessionSubjectMatterOption matter) {
  return matter.sessionProgress?.completedPercentage ??
      matter.cumulativePercentage;
}

bool isProgressCreate(SessionMatterProgress? existing) => existing == null;

String newProgressId(String lessonSessionId) {
  return 'csp-$lessonSessionId-${DateTime.now().millisecondsSinceEpoch}';
}

Map<String, dynamic> lessonSessionNotePayload({
  required Map<String, dynamic> lessonSession,
  required String? sessionNote,
  required String displayLabelFallback,
}) {
  return {
    ...lessonSession,
    'displayLabel':
        lessonSession['displayLabel'] as String? ?? displayLabelFallback,
    'sessionNote': normalizeSessionNote(sessionNote),
  };
}

Map<String, dynamic> recordLessonProgressPayload({
  required String id,
  required String classSubjectMatterId,
  required String lessonSessionId,
  required int completedPercentage,
  required String? notes,
  required DateTime recordedAt,
}) {
  final normalizedNotes = normalizeSessionNote(notes);
  return {
    'id': id,
    'classSubjectMatterId': classSubjectMatterId,
    'lessonSessionId': lessonSessionId,
    'completedPercentage': completedPercentage,
    'notes': ?normalizedNotes,
    'recordedAt': recordedAt.toUtc().toIso8601String(),
  };
}

Map<String, dynamic> updateProgressPayload({
  required Map<String, dynamic> existing,
  required int completedPercentage,
  required String? notes,
  required DateTime recordedAt,
}) {
  return {
    ...existing,
    'completedPercentage': completedPercentage,
    'notes': normalizeSessionNote(notes),
    'recordedAt': recordedAt.toUtc().toIso8601String(),
  };
}
