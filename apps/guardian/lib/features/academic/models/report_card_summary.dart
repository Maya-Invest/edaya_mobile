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

  factory ReportCardSectionMark.fromJson(
    Map<String, dynamic> json, {
    Map<String, String> subjectNameByClassSubjectId = const {},
    Set<String>? globalSeenClassSubjectIds,
  }) {
    return ReportCardSectionMark(
      name: json['name'] as String? ?? 'Section',
      average: (json['average'] as num?)?.toDouble() ?? 0,
      comment: json['comment'] as String?,
      subjects: _collectSubjectMarks(
        json['subResults'],
        subjectNameByClassSubjectId,
        globalSeenClassSubjectIds: globalSeenClassSubjectIds,
      ),
    );
  }

  static List<ReportCardSubjectMark> _collectSubjectMarks(
    dynamic subResults,
    Map<String, String> subjectNameByClassSubjectId, {
    Set<String>? globalSeenClassSubjectIds,
  }) {
    final subjects = <ReportCardSubjectMark>[];
    final seenClassSubjectIds = globalSeenClassSubjectIds ?? <String>{};

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
              !seenClassSubjectIds.add(classSubjectId)) {
            continue;
          }
          subjects.add(
            ReportCardSubjectMark.fromJson(
              node,
              resolvedName: subjectNameByClassSubjectId[classSubjectId],
            ),
          );
        } else if (kind == 'group') {
          visit(node['subResults']);
        }
      }
    }

    visit(subResults);
    return subjects;
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

  factory ReportCardSubjectMark.fromJson(
    Map<String, dynamic> json, {
    String? resolvedName,
  }) {
    return ReportCardSubjectMark(
      name: resolvedName ??
          json['name'] as String? ??
          systemL10n().subjectFallback,
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
    Map<String, String> subjectNameByClassSubjectId = const {},
  }) {
    final sectionResults = json['sectionResults'];
    final sections = <ReportCardSectionMark>[];
    final seenSectionIds = <String>{};
    final seenSectionNames = <String>{};
    final globalSeenClassSubjectIds = <String>{};
    if (sectionResults is List) {
      for (final entry in sectionResults) {
        if (entry is! Map<String, dynamic> ||
            entry['sectionKind'] != 'group') {
          continue;
        }
        final sectionId = entry['sectionId'] as String?;
        final sectionName = (entry['name'] as String? ?? '').trim();
        if (sectionId == null ||
            sectionName.isEmpty ||
            !seenSectionIds.add(sectionId) ||
            !seenSectionNames.add(sectionName)) {
          continue;
        }
        final section = ReportCardSectionMark.fromJson(
          entry,
          subjectNameByClassSubjectId: subjectNameByClassSubjectId,
          globalSeenClassSubjectIds: globalSeenClassSubjectIds,
        );
        if (section.subjects.isEmpty) {
          continue;
        }
        sections.add(section);
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
