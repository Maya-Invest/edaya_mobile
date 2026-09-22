enum TeacherOutboxKind { attendance, logbook, mark, comment }

enum TeacherOutboxState {
  savedLocally,
  pending,
  syncing,
  synced,
  failed,
  conflict,
  rejected,
}

class TeacherOutboxContext {
  const TeacherOutboxContext({
    required this.origin,
    required this.subjectId,
    required this.actorKind,
    required this.actorId,
    required this.schoolId,
    this.academicYearId,
  });

  final String origin;
  final String subjectId;
  final String actorKind;
  final String actorId;
  final String schoolId;
  final String? academicYearId;

  bool matches(TeacherOutboxContext other) {
    return origin == other.origin &&
        subjectId == other.subjectId &&
        actorKind == other.actorKind &&
        actorId == other.actorId &&
        schoolId == other.schoolId &&
        academicYearId == other.academicYearId;
  }

  Map<String, dynamic> toJson() {
    return {
      'origin': origin,
      'subjectId': subjectId,
      'actorKind': actorKind,
      'actorId': actorId,
      'schoolId': schoolId,
      'academicYearId': academicYearId,
    };
  }

  factory TeacherOutboxContext.fromJson(Map<String, dynamic> json) {
    return TeacherOutboxContext(
      origin: json['origin'] as String? ?? '',
      subjectId: json['subjectId'] as String? ?? '',
      actorKind: json['actorKind'] as String? ?? '',
      actorId: json['actorId'] as String? ?? '',
      schoolId: json['schoolId'] as String? ?? '',
      academicYearId: json['academicYearId'] as String?,
    );
  }
}

class TeacherOutboxEntry {
  const TeacherOutboxEntry({
    required this.id,
    required this.kind,
    required this.idempotencyKey,
    required this.payload,
    required this.state,
    required this.attemptCount,
    this.lastError,
    required this.createdAt,
    required this.updatedAt,
    this.context,
  });

  final String id;
  final TeacherOutboxKind kind;
  final String idempotencyKey;
  final Map<String, dynamic> payload;
  final TeacherOutboxState state;
  final int attemptCount;
  final String? lastError;
  final DateTime createdAt;
  final DateTime updatedAt;
  final TeacherOutboxContext? context;

  TeacherOutboxEntry copyWith({
    TeacherOutboxState? state,
    int? attemptCount,
    String? lastError,
    DateTime? updatedAt,
    TeacherOutboxContext? context,
  }) {
    return TeacherOutboxEntry(
      id: id,
      kind: kind,
      idempotencyKey: idempotencyKey,
      payload: payload,
      state: state ?? this.state,
      attemptCount: attemptCount ?? this.attemptCount,
      lastError: lastError ?? this.lastError,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      context: context ?? this.context,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'kind': kind.name,
      'idempotencyKey': idempotencyKey,
      'payload': payload,
      'state': state.name,
      'attemptCount': attemptCount,
      'lastError': lastError,
      'createdAt': createdAt.toUtc().toIso8601String(),
      'updatedAt': updatedAt.toUtc().toIso8601String(),
      if (context != null) 'context': context!.toJson(),
    };
  }

  factory TeacherOutboxEntry.fromJson(Map<String, dynamic> json) {
    return TeacherOutboxEntry(
      id: json['id'] as String,
      kind: TeacherOutboxKind.values.byName(json['kind'] as String),
      idempotencyKey: json['idempotencyKey'] as String,
      payload: (json['payload'] as Map).cast<String, dynamic>(),
      state: TeacherOutboxState.values.byName(json['state'] as String),
      attemptCount: (json['attemptCount'] as num?)?.toInt() ?? 0,
      lastError: json['lastError'] as String?,
      createdAt:
          DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.now(),
      updatedAt:
          DateTime.tryParse(json['updatedAt'] as String? ?? '') ??
          DateTime.now(),
      context: json['context'] is Map
          ? TeacherOutboxContext.fromJson(
              (json['context'] as Map).cast<String, dynamic>(),
            )
          : null,
    );
  }
}

class TeacherOutboxSummary {
  const TeacherOutboxSummary({
    required this.pendingCount,
    this.oldestPendingAt,
  });

  final int pendingCount;
  final DateTime? oldestPendingAt;

  bool get hasPending => pendingCount > 0;

  factory TeacherOutboxSummary.fromEntries(List<TeacherOutboxEntry> entries) {
    if (entries.isEmpty) {
      return const TeacherOutboxSummary(pendingCount: 0);
    }

    final oldest = entries
        .map((entry) => entry.createdAt)
        .reduce((a, b) => a.isBefore(b) ? a : b);
    return TeacherOutboxSummary(
      pendingCount: entries.length,
      oldestPendingAt: oldest,
    );
  }
}

bool teacherOutboxEntryIsReplayable(TeacherOutboxEntry entry) {
  return entry.state == TeacherOutboxState.pending ||
      entry.state == TeacherOutboxState.savedLocally ||
      entry.state == TeacherOutboxState.failed;
}

bool teacherOutboxEntryMatchesContext(
  TeacherOutboxEntry entry,
  TeacherOutboxContext? context,
) {
  if (context == null) {
    return entry.context == null;
  }
  final entryContext = entry.context;
  if (entryContext == null) {
    return false;
  }
  return entryContext.matches(context);
}

TeacherOutboxEntry stampTeacherOutboxContext(
  TeacherOutboxEntry entry,
  TeacherOutboxContext? context,
) {
  if (entry.context != null || context == null) {
    return entry;
  }
  return entry.copyWith(context: context);
}

abstract class TeacherOutboxStore {
  Future<void> enqueue(TeacherOutboxEntry entry);

  Future<List<TeacherOutboxEntry>> listPending();

  Future<void> upsert(TeacherOutboxEntry entry);

  Future<void> remove(String id);

  Future<void> removeByIdempotencyKey(String idempotencyKey);

  void bindContext(TeacherOutboxContext? context);

  Future<void> discardBoundContext();

  Future<int> pendingCount();

  Future<TeacherOutboxSummary> summary();
}

String teacherAttendanceIdempotencyKey({
  required String occurrenceId,
  required String studentId,
}) {
  return 'attendance:$occurrenceId:$studentId';
}

String teacherLogbookIdempotencyKey({
  required String lessonSessionId,
  String? matterId,
}) {
  if (matterId == null || matterId.isEmpty) {
    return 'logbook:$lessonSessionId:note';
  }
  return 'logbook:$lessonSessionId:$matterId';
}

String formatTeacherOutboxPendingAge({
  required DateTime oldestPendingAt,
  required DateTime now,
  required String Function() justNow,
  required String Function(int minutes) minutesAgo,
  required String Function(int hours) hoursAgo,
  required String Function(int days) daysAgo,
}) {
  final diff = now.difference(oldestPendingAt);
  if (diff.inMinutes < 1) {
    return justNow();
  }
  if (diff.inMinutes < 60) {
    return minutesAgo(diff.inMinutes);
  }
  if (diff.inHours < 24) {
    return hoursAgo(diff.inHours);
  }
  return daysAgo(diff.inDays);
}
