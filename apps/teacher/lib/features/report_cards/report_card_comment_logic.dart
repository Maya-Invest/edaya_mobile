class ReportCardCommentField {
  const ReportCardCommentField({
    required this.sectionId,
    required this.label,
    required this.kind,
    this.classSubjectId,
    this.initialComment = '',
  });

  final String sectionId;
  final String label;
  final String kind;
  final String? classSubjectId;
  final String initialComment;

  bool get isHomeroom => kind == 'homeroom';
  bool get isGroup => kind == 'module';
  bool get isSubject => kind == 'subject';
}

List<ReportCardCommentField> extractWritableReportCardCommentFields({
  required Map<String, dynamic> result,
  required String classGroupId,
  required Set<String> homeroomClassGroupIds,
  required Set<String> taughtClassSubjectIds,
}) {
  final fields = <ReportCardCommentField>[];
  final isHomeroomTeacher = homeroomClassGroupIds.contains(classGroupId);

  if (isHomeroomTeacher) {
    fields.add(
      ReportCardCommentField(
        sectionId: '__homeroom__',
        label: 'homeroom',
        kind: 'homeroom',
        initialComment: result['teacherComment'] as String? ?? '',
      ),
    );
  }

  fields.addAll(
    _sectionCommentFields(
      sections: result['sectionResults'],
      homeroomClassGroupIds: homeroomClassGroupIds,
      classGroupId: classGroupId,
      taughtClassSubjectIds: taughtClassSubjectIds,
    ),
  );

  return fields;
}

List<ReportCardCommentField> _sectionCommentFields({
  required dynamic sections,
  required Set<String> homeroomClassGroupIds,
  required String classGroupId,
  required Set<String> taughtClassSubjectIds,
}) {
  if (sections is! List) {
    return const [];
  }

  final fields = <ReportCardCommentField>[];
  final isHomeroomTeacher = homeroomClassGroupIds.contains(classGroupId);

  for (final section in sections) {
    if (section is! Map) {
      continue;
    }

    final sectionId = section['sectionId'] as String?;
    if (sectionId == null) {
      continue;
    }

    final sectionKind = section['sectionKind'] as String? ?? '';
    final classSubjectId = section['classSubjectId'] as String?;
    final name = section['name'] as String? ?? sectionId;

    final canEditGroup = isHomeroomTeacher && sectionKind == 'module';
    final canEditSubject =
        sectionKind == 'subject' &&
        classSubjectId != null &&
        taughtClassSubjectIds.contains(classSubjectId);

    if (canEditGroup || canEditSubject) {
      fields.add(
        ReportCardCommentField(
          sectionId: sectionId,
          label: name,
          kind: sectionKind == 'subject' ? 'subject' : 'module',
          classSubjectId: classSubjectId,
          initialComment: section['comment'] as String? ?? '',
        ),
      );
    }

    fields.addAll(
      _sectionCommentFields(
        sections: section['subResults'],
        homeroomClassGroupIds: homeroomClassGroupIds,
        classGroupId: classGroupId,
        taughtClassSubjectIds: taughtClassSubjectIds,
      ),
    );
  }

  return fields;
}

Map<String, dynamic> applyReportCardCommentUpdates(
  Map<String, dynamic> result, {
  required Map<String, String> commentsBySectionId,
}) {
  final updated = Map<String, dynamic>.from(result);

  final homeroomComment = commentsBySectionId['__homeroom__'];
  if (homeroomComment != null) {
    updated['teacherComment'] = homeroomComment;
  }

  final sectionResults = updated['sectionResults'];
  if (sectionResults is List) {
    updated['sectionResults'] = _applySectionCommentUpdates(
      sectionResults,
      commentsBySectionId,
    );
  }

  return updated;
}

List<dynamic> _applySectionCommentUpdates(
  List<dynamic> sections,
  Map<String, String> commentsBySectionId,
) {
  return sections.map((section) {
    if (section is! Map) {
      return section;
    }

    final updated = Map<String, dynamic>.from(section);
    final sectionId = updated['sectionId'] as String?;
    if (sectionId != null && commentsBySectionId.containsKey(sectionId)) {
      updated['comment'] = commentsBySectionId[sectionId];
    }

    final subResults = updated['subResults'];
    if (subResults is List) {
      updated['subResults'] = _applySectionCommentUpdates(
        subResults,
        commentsBySectionId,
      );
    }

    return updated;
  }).toList();
}

bool reportCardCommentsEditable(Map<String, dynamic> result) {
  return result['status'] != 'published';
}
