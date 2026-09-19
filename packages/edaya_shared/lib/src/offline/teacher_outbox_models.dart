enum TeacherOutboxKind { attendance, logbook, mark, comment }

enum TeacherOutboxState {
  savedLocally,
  pending,
  syncing,
  synced,
  failed,
  conflict,
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

  TeacherOutboxEntry copyWith({
    TeacherOutboxState? state,
    int? attemptCount,
    String? lastError,
    DateTime? updatedAt,
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

abstract class TeacherOutboxStore {
  Future<void> enqueue(TeacherOutboxEntry entry);

  Future<List<TeacherOutboxEntry>> listPending();

  Future<void> upsert(TeacherOutboxEntry entry);

  Future<void> remove(String id);

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
