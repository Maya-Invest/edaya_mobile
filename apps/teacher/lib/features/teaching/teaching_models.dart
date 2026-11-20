import 'package:edaya_shared/edaya_shared.dart';

class TeachingClassSubjectOption {
  const TeachingClassSubjectOption({
    required this.id,
    required this.classGroupId,
    required this.subjectName,
    required this.classLabel,
  });

  final String id;
  final String classGroupId;
  final String subjectName;
  final String classLabel;

  String get label => '$classLabel · $subjectName';
}

enum TeachingMatterStatus {
  notStarted,
  inProgress,
  completed;

  static TeachingMatterStatus fromApi(String? value) {
    return switch (value) {
      'completed' => TeachingMatterStatus.completed,
      'in_progress' => TeachingMatterStatus.inProgress,
      _ => TeachingMatterStatus.notStarted,
    };
  }

  String get labelFr => switch (this) {
    TeachingMatterStatus.notStarted => systemL10n().matterStatusNotStarted,
    TeachingMatterStatus.inProgress => systemL10n().matterStatusInProgress,
    TeachingMatterStatus.completed => systemL10n().done,
  };
}

class TeachingMatterProgress {
  const TeachingMatterProgress({
    required this.id,
    required this.name,
    required this.sequenceOrder,
    required this.status,
    required this.completedPercentage,
    this.notes,
  });

  final String id;
  final String name;
  final int sequenceOrder;
  final TeachingMatterStatus status;
  final int completedPercentage;
  final String? notes;
}

class TeachingProgressOverview {
  const TeachingProgressOverview({
    required this.classSubjectCompletedPercentage,
    this.chapterCount = 0,
    this.completedChapterCount = 0,
    this.ongoingChapterCount = 0,
    required this.matters,
  });

  final int classSubjectCompletedPercentage;
  final int chapterCount, completedChapterCount, ongoingChapterCount;
  final List<TeachingMatterProgress> matters;
}

class TeachingLogEntry {
  const TeachingLogEntry({
    required this.lessonSessionId,
    required this.displayLabel,
    required this.startsAt,
    required this.hasContent,
  });

  final String lessonSessionId;
  final String displayLabel;
  final DateTime startsAt;
  final bool hasContent;
}
