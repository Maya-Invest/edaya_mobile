import 'package:edaya_api_client/edaya_api_client.dart';

class TeachingScope {
  const TeachingScope({
    this.classGroupIds = const {},
    this.classSubjectIds = const {},
    this.sessionIds = const {},
  });

  final Set<String> classGroupIds;
  final Set<String> classSubjectIds;
  final Set<String> sessionIds;
}

EntityQuery teacherAssignmentsForTeacherAndYear({
  required String teacherId,
  required String academicYearId,
}) {
  return {
    'teacherId': teacherId,
    'academicYearId': academicYearId,
  };
}

TeachingScope teachingScopeFromTeacherPortalScope(TeacherPortalScope? scope) {
  if (scope == null) {
    return const TeachingScope();
  }

  return TeachingScope(
    classGroupIds: scope.homeroomClassGroupIds.toSet(),
    classSubjectIds: scope.classSubjectIds.toSet(),
  );
}

TeachingScope teachingScopeFromTeacherAssignments(
  List<Map<String, dynamic>> assignments,
) {
  final classGroupIds = <String>{};
  final classSubjectIds = <String>{};

  for (final assignment in assignments) {
    if (assignment['status'] != 'active') {
      continue;
    }

    final kind = assignment['kind'] as String?;
    final classGroupId = assignment['classGroupId'] as String?;
    final classSubjectId = assignment['classSubjectId'] as String?;

    if (kind == 'homeroom' && classGroupId != null && classGroupId.isNotEmpty) {
      classGroupIds.add(classGroupId);
    }
    if (kind == 'subject' && classSubjectId != null && classSubjectId.isNotEmpty) {
      classSubjectIds.add(classSubjectId);
    }
  }

  return TeachingScope(
    classGroupIds: classGroupIds,
    classSubjectIds: classSubjectIds,
  );
}

TeachingScope mergeTeachingScopes(TeachingScope primary, TeachingScope fallback) {
  if (primary.classGroupIds.isNotEmpty || primary.classSubjectIds.isNotEmpty) {
    return primary;
  }
  return fallback;
}
