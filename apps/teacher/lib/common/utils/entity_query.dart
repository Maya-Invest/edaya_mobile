import 'package:edaya_shared/edaya_shared.dart';

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

EntityQuery staffAssignmentsForStaffAndYear({
  required String staffId,
  required String academicYearId,
}) {
  return {
    'staffId': staffId,
    'academicYearId': academicYearId,
  };
}

TeachingScope teachingScopeFromStaffAssignments(
  List<Map<String, dynamic>> assignments,
) {
  final classGroupIds = <String>{};
  final classSubjectIds = <String>{};
  final sessionIds = <String>{};

  for (final assignment in assignments) {
    final classGroupId = assignment['classGroupId'] as String?;
    final classSubjectId = assignment['classSubjectId'] as String?;
    final lessonSessionId = assignment['lessonSessionId'] as String?;
    final activitySessionId = assignment['activitySessionId'] as String?;

    if (classGroupId != null && classGroupId.isNotEmpty) {
      classGroupIds.add(classGroupId);
    }
    if (classSubjectId != null && classSubjectId.isNotEmpty) {
      classSubjectIds.add(classSubjectId);
    }
    if (lessonSessionId != null && lessonSessionId.isNotEmpty) {
      sessionIds.add(lessonSessionId);
    }
    if (activitySessionId != null && activitySessionId.isNotEmpty) {
      sessionIds.add(activitySessionId);
    }
  }

  return TeachingScope(
    classGroupIds: classGroupIds,
    classSubjectIds: classSubjectIds,
    sessionIds: sessionIds,
  );
}
