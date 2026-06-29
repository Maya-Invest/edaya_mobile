import 'package:edaya_shared/edaya_shared.dart';
import 'package:edaya_shared/src/l10n/l10n_lookup.dart';

class ReportCardSummary {
  const ReportCardSummary({
    required this.id,
    required this.periodId,
    required this.periodName,
    this.overallAverage,
    this.rank,
    this.classSize,
    this.publishedAt,
  });

  factory ReportCardSummary.fromJson(
    Map<String, dynamic> json, {
    required String periodName,
  }) {
    return ReportCardSummary(
      id: json['id'] as String,
      periodId: json['periodId'] as String,
      periodName: periodName,
      overallAverage: (json['overallAverage'] as num?)?.toDouble(),
      rank: json['rank'] as int?,
      classSize: json['classSize'] as int?,
      publishedAt: parseApiDateTime(json['publishedAt']),
    );
  }

  final String id;
  final String periodId;
  final String periodName;
  final double? overallAverage;
  final int? rank;
  final int? classSize;
  final DateTime? publishedAt;
}

class ReportCardSectionMark {
  const ReportCardSectionMark({
    required this.name,
    required this.average,
    this.comment,
    this.subjects = const [],
  });

  factory ReportCardSectionMark.fromJson(Map<String, dynamic> json) {
    final subResults = json['subResults'];
    final subjects = <ReportCardSubjectMark>[];
    if (subResults is List) {
      for (final entry in subResults) {
        if (entry is Map<String, dynamic> &&
            entry['sectionKind'] == 'subject') {
          subjects.add(ReportCardSubjectMark.fromJson(entry));
        }
      }
    }

    return ReportCardSectionMark(
      name: json['name'] as String? ?? 'Section',
      average: (json['average'] as num?)?.toDouble() ?? 0,
      comment: json['comment'] as String?,
      subjects: subjects,
    );
  }

  final String name;
  final double average;
  final String? comment;
  final List<ReportCardSubjectMark> subjects;
}

class ReportCardSubjectMark {
  const ReportCardSubjectMark({
    required this.name,
    required this.average,
    this.comment,
  });

  factory ReportCardSubjectMark.fromJson(Map<String, dynamic> json) {
    return ReportCardSubjectMark(
      name: json['name'] as String? ?? systemL10n().subjectFallback,
      average: (json['average'] as num?)?.toDouble() ?? 0,
      comment: json['comment'] as String?,
    );
  }

  final String name;
  final double average;
  final String? comment;
}

class ReportCardDetail {
  const ReportCardDetail({
    required this.id,
    required this.periodName,
    this.overallAverage,
    this.rank,
    this.classSize,
    this.teacherComment,
    this.principalComment,
    this.publishedAt,
    this.sections = const [],
  });

  factory ReportCardDetail.fromJson(
    Map<String, dynamic> json, {
    required String periodName,
  }) {
    final sectionResults = json['sectionResults'];
    final sections = <ReportCardSectionMark>[];
    if (sectionResults is List) {
      for (final entry in sectionResults) {
        if (entry is Map<String, dynamic> &&
            entry['sectionKind'] == 'group') {
          sections.add(ReportCardSectionMark.fromJson(entry));
        }
      }
    }

    return ReportCardDetail(
      id: json['id'] as String,
      periodName: periodName,
      overallAverage: (json['overallAverage'] as num?)?.toDouble(),
      rank: json['rank'] as int?,
      classSize: json['classSize'] as int?,
      teacherComment: json['teacherComment'] as String?,
      principalComment: json['principalComment'] as String?,
      publishedAt: parseApiDateTime(json['publishedAt']),
      sections: sections,
    );
  }

  final String id;
  final String periodName;
  final double? overallAverage;
  final int? rank;
  final int? classSize;
  final String? teacherComment;
  final String? principalComment;
  final DateTime? publishedAt;
  final List<ReportCardSectionMark> sections;
}
