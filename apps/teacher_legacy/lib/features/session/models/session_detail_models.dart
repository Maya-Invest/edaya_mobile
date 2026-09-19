import 'package:edaya_shared/edaya_shared.dart';

enum SessionAttendanceStatus {
  present,
  absent,
  late;

  static SessionAttendanceStatus? fromApi(String? value) {
    return switch (value) {
      'present' => SessionAttendanceStatus.present,
      'absent' => SessionAttendanceStatus.absent,
      'late' => SessionAttendanceStatus.late,
      _ => null,
    };
  }

  String get apiValue => name;

  String label(AppLocalizations l10n) => switch (this) {
    SessionAttendanceStatus.present => l10n.attendanceStatusPresent,
    SessionAttendanceStatus.absent => l10n.attendanceStatusAbsent,
    SessionAttendanceStatus.late => l10n.attendanceStatusLate,
  };
}

class SessionStudentRow {
  const SessionStudentRow({
    required this.studentId,
    required this.studentName,
    required this.studentInitials,
    this.photoUrl,
    this.attendanceId,
    this.status,
    this.reason,
    this.notes,
  });

  final String studentId;
  final String studentName;
  final String studentInitials;
  final String? photoUrl;
  final String? attendanceId;
  final SessionAttendanceStatus? status;
  final String? reason;
  final String? notes;

  SessionStudentRow copyWith({
    String? attendanceId,
    SessionAttendanceStatus? status,
    String? reason,
    String? notes,
  }) {
    return SessionStudentRow(
      studentId: studentId,
      studentName: studentName,
      studentInitials: studentInitials,
      photoUrl: photoUrl,
      attendanceId: attendanceId ?? this.attendanceId,
      status: status ?? this.status,
      reason: reason ?? this.reason,
      notes: notes ?? this.notes,
    );
  }
}

enum ClassSubjectMatterStatus {
  notStarted,
  inProgress,
  completed;

  String label(AppLocalizations l10n) => switch (this) {
    ClassSubjectMatterStatus.notStarted => l10n.matterStatusNotStarted,
    ClassSubjectMatterStatus.inProgress => l10n.matterStatusInProgress,
    ClassSubjectMatterStatus.completed => l10n.matterStatusCompleted,
  };
}

/// Per-lesson progress snapshot for one curriculum matter.
class SessionMatterProgress {
  const SessionMatterProgress({
    required this.id,
    required this.classSubjectMatterId,
    required this.completedPercentage,
    this.notes,
    this.recordedAt,
  });

  final String id;
  final String classSubjectMatterId;
  final int completedPercentage;
  final String? notes;
  final DateTime? recordedAt;
}

/// Curriculum matter linked to the class subject, with cumulative and session progress.
class SessionSubjectMatterOption {
  const SessionSubjectMatterOption({
    required this.id,
    required this.name,
    required this.sequenceOrder,
    required this.status,
    required this.cumulativePercentage,
    this.sessionProgress,
  });

  final String id;
  final String name;
  final int sequenceOrder;
  final ClassSubjectMatterStatus status;
  final int cumulativePercentage;
  final SessionMatterProgress? sessionProgress;

  bool get hasSessionProgress => sessionProgress != null;
}

/// Pending progress entry to save with the session note.
class LogbookProgressDraft {
  const LogbookProgressDraft({
    required this.matterId,
    required this.completedPercentage,
    this.notes,
  });

  final String matterId;
  final int completedPercentage;
  final String? notes;
}
