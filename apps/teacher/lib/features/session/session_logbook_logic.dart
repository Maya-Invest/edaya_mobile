import 'package:edaya_shared/edaya_shared.dart';

export 'package:edaya_shared/edaya_shared.dart'
    show
        StructuredLogbookContent,
        decodeStructuredSessionNote,
        encodeStructuredSessionNote;

enum ClassSubjectMatterStatus { notStarted, inProgress, completed }

class SessionSubjectMatterOption {
  const SessionSubjectMatterOption({
    required this.id,
    required this.name,
    required this.sequenceOrder,
    required this.status,
    required this.cumulativePercentage,
  });

  final String id;
  final String name;
  final int sequenceOrder;
  final ClassSubjectMatterStatus status;
  final int cumulativePercentage;
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

List<SessionSubjectMatterOption> buildSessionSubjectMatters({
  required List<Map<String, dynamic>> matterLinks,
  required List<Map<String, dynamic>> subjectMatters,
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
  final options =
      matterLinks.map((link) {
        final linkId = link['id'] as String;
        final subjectMatterId = link['subjectMatterId'] as String;
        final cumulative = (link['completedPercentage'] as num?)?.toInt() ?? 0;
        return SessionSubjectMatterOption(
          id: linkId,
          name: matterNameById[subjectMatterId] ?? fallbackName,
          sequenceOrder: sequenceById[subjectMatterId] ?? 0,
          status: parseMatterStatus(link['status'] as String?),
          cumulativePercentage: cumulative,
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

bool sessionNoteIndicatesComplete(String? raw) {
  return decodeStructuredSessionNote(raw).isComplete;
}
