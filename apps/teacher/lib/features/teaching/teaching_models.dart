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
    TeachingMatterStatus.notStarted => 'Non commencé',
    TeachingMatterStatus.inProgress => 'En cours',
    TeachingMatterStatus.completed => 'Terminé',
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

class TeachingLogMatterSnapshot {
  const TeachingLogMatterSnapshot({
    required this.matterName,
    required this.completed,
    this.notes,
  });

  final String matterName;
  final bool? completed;
  final String? notes;
}

class TeachingLogEntry {
  const TeachingLogEntry({
    required this.lessonSessionId,
    required this.classGroupId,
    required this.classSubjectId,
    required this.displayLabel,
    required this.subjectLabel,
    required this.classLabel,
    required this.startsAt,
    required this.endsAt,
    this.sessionNote,
    this.matterSnapshots = const [],
  });

  final String lessonSessionId;
  final String classGroupId;
  final String classSubjectId;
  final String displayLabel;
  final String subjectLabel;
  final String classLabel;
  final DateTime startsAt;
  final DateTime endsAt;
  final String? sessionNote;
  final List<TeachingLogMatterSnapshot> matterSnapshots;

  bool get hasContent =>
      (sessionNote != null && sessionNote!.trim().isNotEmpty) ||
      matterSnapshots.isNotEmpty;
}
