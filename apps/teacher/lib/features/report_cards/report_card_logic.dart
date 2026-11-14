bool reportCardHasComment(Map<String, dynamic> row) {
  final teacherComment = row['teacherComment'] as String?;
  if (teacherComment != null && teacherComment.trim().isNotEmpty) {
    return true;
  }
  return _sectionTreeHasComment(row['sectionResults']);
}

bool _sectionTreeHasComment(dynamic sections) {
  if (sections is! List) {
    return false;
  }
  for (final section in sections) {
    if (section is! Map) {
      continue;
    }
    final comment = section['comment'] as String?;
    if (comment != null && comment.trim().isNotEmpty) {
      return true;
    }
    if (_sectionTreeHasComment(section['subResults'])) {
      return true;
    }
  }
  return false;
}

bool reportCardIsGenerated(Map<String, dynamic> row) {
  final status = row['status'] as String?;
  return status == 'draft' || status == 'published';
}
