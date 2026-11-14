import 'package:edaya_shared/edaya_shared.dart';

class ReportCardSummary {
  const ReportCardSummary({
    required this.id,
    required this.periodId,
    required this.periodName,
    this.overallAverage,
    this.grading,
    this.aggregateLabel,
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
      grading: (json['grading'] as Map?)?.cast<String, dynamic>(),
      aggregateLabel: json['aggregateLabel'] as String?,
      rank: json['rank'] as int?,
      classSize: json['classSize'] as int?,
      publishedAt: parseApiDateTime(json['publishedAt']),
    );
  }

  final String id;
  final String periodId;
  final String periodName;
  final double? overallAverage;
  final Map<String, dynamic>? grading;
  final String? aggregateLabel;
  String get averageLabel => formatCalculatedGrade(overallAverage, grading);
  final int? rank;
  final int? classSize;
  final DateTime? publishedAt;
}

class ReportCardSectionMark {
  const ReportCardSectionMark({
    required this.name,
    required this.average,
    this.grading,
    this.weight,
    this.weightingMode,
    this.comment,
    this.subjects = const [],
    this.groupComments = const [],
  });

  factory ReportCardSectionMark.fromJson(
    Map<String, dynamic> json, {
    Map<String, String> subjectNameByClassSubjectId = const {},
  }) {
    return ReportCardSectionMark(
      name: json['name'] as String? ?? 'Section',
      average: (json['average'] as num?)?.toDouble(),
      grading: (json['grading'] as Map?)?.cast<String, dynamic>(),
      weight: (json['weight'] as num?)?.toDouble(),
      weightingMode: json['weightingMode'] as String?,
      comment: json['comment'] as String?,
      groupComments: _collectGroupComments(json['subResults']),
      subjects: json['sectionKind'] == 'subject'
          ? [
              ReportCardSubjectMark.fromJson(
                json,
                resolvedName:
                    subjectNameByClassSubjectId[json['classSubjectId']],
              ),
            ]
          : _collectSubjectMarks(
              json['subResults'],
              subjectNameByClassSubjectId,
            ),
    );
  }

  static List<ReportCardGroupComment> _collectGroupComments(dynamic nodes) {
    if (nodes is! List) return const [];
    final comments = <ReportCardGroupComment>[];
    for (final node in nodes) {
      if (node is! Map<String, dynamic> || node['sectionKind'] != 'module') {
        continue;
      }
      final comment = node['comment'] as String?;
      if (comment != null && comment.trim().isNotEmpty) {
        comments.add(
          ReportCardGroupComment(
            name: node['name'] as String? ?? 'Section',
            comment: comment,
          ),
        );
      }
      comments.addAll(_collectGroupComments(node['subResults']));
    }
    return comments;
  }

  static List<ReportCardSubjectMark> _collectSubjectMarks(
    dynamic subResults,
    Map<String, String> subjectNameByClassSubjectId,
  ) {
    final subjects = <ReportCardSubjectMark>[];
    final seenSectionIds = <String>{};

    void visit(dynamic nodes) {
      if (nodes is! List) {
        return;
      }
      for (final node in nodes) {
        if (node is! Map<String, dynamic>) {
          continue;
        }
        final kind = node['sectionKind'];
        if (kind == 'subject') {
          final classSubjectId = node['classSubjectId'] as String?;
          if (classSubjectId == null ||
              !seenSectionIds.add(
                node['sectionId'] as String? ?? classSubjectId,
              )) {
            continue;
          }
          subjects.add(
            ReportCardSubjectMark.fromJson(
              node,
              resolvedName: subjectNameByClassSubjectId[classSubjectId],
            ),
          );
        } else if (kind == 'module') {
          visit(node['subResults']);
        }
      }
    }

    visit(subResults);
    return subjects;
  }

  final double? weight;
  final String? weightingMode;
  final String name;
  final double? average;
  final Map<String, dynamic>? grading;
  String get averageLabel => formatCalculatedGrade(average, grading);
  final String? comment;
  final List<ReportCardSubjectMark> subjects;
  final List<ReportCardGroupComment> groupComments;
}

class ReportCardGroupComment {
  const ReportCardGroupComment({required this.name, required this.comment});
  final String name;
  final String comment;
}

class ReportCardSubjectMark {
  const ReportCardSubjectMark({
    required this.name,
    required this.average,
    this.grading,
    this.coefficient,
    this.rank,
    this.comment,
  });

  factory ReportCardSubjectMark.fromJson(
    Map<String, dynamic> json, {
    String? resolvedName,
  }) {
    return ReportCardSubjectMark(
      name:
          json['name'] as String? ??
          resolvedName ??
          systemL10n().subjectFallback,
      average: (json['average'] as num?)?.toDouble(),
      grading: (json['grading'] as Map?)?.cast<String, dynamic>(),
      coefficient: (json['coefficient'] as num?)?.toDouble(),
      rank: json['rank'] as int?,
      comment: json['comment'] as String?,
    );
  }

  final double? coefficient;
  final String name;
  final double? average;
  final Map<String, dynamic>? grading;
  String get averageLabel => formatCalculatedGrade(average, grading);
  final int? rank;
  final String? comment;
}

class ReportCardDetail {
  const ReportCardDetail({
    required this.id,
    required this.periodName,
    this.overallAverage,
    this.grading,
    this.aggregateLabel,
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
    Map<String, String> subjectNameByClassSubjectId = const {},
  }) {
    final sectionResults = json['sectionResults'];
    final sections = <ReportCardSectionMark>[];
    final seenSectionIds = <String>{};
    if (sectionResults is List) {
      for (final entry in sectionResults) {
        if (entry is! Map<String, dynamic> ||
            !const ['module', 'subject'].contains(entry['sectionKind'])) {
          continue;
        }
        final sectionId = entry['sectionId'] as String?;
        final sectionName = (entry['name'] as String? ?? '').trim();
        if (sectionId == null ||
            sectionName.isEmpty ||
            !seenSectionIds.add(sectionId)) {
          continue;
        }
        final section = ReportCardSectionMark.fromJson(
          entry,
          subjectNameByClassSubjectId: subjectNameByClassSubjectId,
        );
        if (section.subjects.isEmpty &&
            (section.comment?.trim().isEmpty ?? true) &&
            section.groupComments.isEmpty) {
          continue;
        }
        sections.add(section);
      }
    }

    return ReportCardDetail(
      id: json['id'] as String,
      periodName: periodName,
      overallAverage: (json['overallAverage'] as num?)?.toDouble(),
      grading: (json['grading'] as Map?)?.cast<String, dynamic>(),
      aggregateLabel: json['aggregateLabel'] as String?,
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
  final Map<String, dynamic>? grading;
  final String? aggregateLabel;
  String get averageLabel => formatCalculatedGrade(overallAverage, grading);
  final int? rank;
  final int? classSize;
  final String? teacherComment;
  final String? principalComment;
  final DateTime? publishedAt;
  final List<ReportCardSectionMark> sections;
}
