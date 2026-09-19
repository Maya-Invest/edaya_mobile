class ReportCardRosterArgs {
  const ReportCardRosterArgs({
    required this.classGroupId,
    required this.classLabel,
    required this.periodId,
    required this.periodLabel,
  });

  final String classGroupId;
  final String classLabel;
  final String periodId;
  final String periodLabel;
}

class ReportCardCommentRouteArgs {
  const ReportCardCommentRouteArgs({
    required this.rosterArgs,
    required this.student,
  });

  final ReportCardRosterArgs rosterArgs;
  final ReportCardStudentRow student;
}

class ReportCardStudentRow {
  const ReportCardStudentRow({
    required this.studentId,
    required this.studentName,
    this.studentInitials,
    this.photoUrl,
    this.reportCardId,
    this.status,
    this.overallAverage,
    this.rank,
    this.classSize,
    this.hasComment = false,
  });

  final String studentId;
  final String studentName;
  final String? studentInitials;
  final String? photoUrl;
  final String? reportCardId;
  final String? status;
  final double? overallAverage;
  final int? rank;
  final int? classSize;
  final bool hasComment;

  bool get hasReportCard => reportCardId != null;
}
