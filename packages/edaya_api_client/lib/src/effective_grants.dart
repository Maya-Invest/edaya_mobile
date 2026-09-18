/// Identity and a display projection of the server's action policies.
/// Relationships are fetched through their own endpoints, never embedded here.
class EffectiveGrantsResponse {
  const EffectiveGrantsResponse({
    required this.kind,
    required this.actorId,
    required this.schoolId,
    required this.assuranceLevel,
    required this.grants,
  });

  factory EffectiveGrantsResponse.fromJson(Map<String, dynamic> json) =>
      EffectiveGrantsResponse(
        kind: json['kind'] as String,
        actorId: json['actorId'] as String,
        schoolId: json['schoolId'] as String,
        assuranceLevel: json['assuranceLevel'] as String,
        grants: List.unmodifiable(
          (json['grants'] as List).map(
            (entry) =>
                ActionGrant.fromJson(Map<String, dynamic>.from(entry as Map)),
          ),
        ),
      );

  final String kind;
  final String actorId;
  final String schoolId;
  final String assuranceLevel;
  final List<ActionGrant> grants;

  TeacherPortalScope? get teacherScope {
    if (kind != 'teacher') {
      return null;
    }
    final classSubjectIds = <String>{};
    final homeroomClassGroupIds = <String>{};
    for (final grant in grants) {
      for (final scope in grant.scopes) {
        switch (scope) {
          case ClassSubjectGrantScope(
            :final classSubjectId,
            :final classGroupId,
          ):
            if (classSubjectId != null) {
              classSubjectIds.add(classSubjectId);
            }
            homeroomClassGroupIds.add(classGroupId);
          case ClassGroupGrantScope(:final classGroupId):
            homeroomClassGroupIds.add(classGroupId);
          default:
            break;
        }
      }
    }
    return TeacherPortalScope(
      classSubjectIds: classSubjectIds.toList(),
      homeroomClassGroupIds: homeroomClassGroupIds.toList(),
    );
  }

  Map<String, dynamic> toJson() => {
    'kind': kind,
    'actorId': actorId,
    'schoolId': schoolId,
    'assuranceLevel': assuranceLevel,
    'grants': grants.map((grant) => grant.toJson()).toList(),
  };
}

class TeacherPortalScope {
  const TeacherPortalScope({
    required this.classSubjectIds,
    required this.homeroomClassGroupIds,
  });

  final List<String> classSubjectIds;
  final List<String> homeroomClassGroupIds;
}

enum GrantSource { manual, assignment, relationship, owner }

enum GrantGrain {
  gradeLevel('grade_level'),
  gradeLevelSubject('grade_level_subject'),
  classGroup('class_group'),
  classSubject('class_subject'),
  activity('activity'),
  student('student');

  const GrantGrain(this.value);
  final String value;
  static GrantGrain parse(String value) => values.firstWhere(
    (grain) => grain.value == value,
    orElse: () => throw FormatException('Unknown grant grain: $value'),
  );
}

class ActionGrant {
  const ActionGrant({
    required this.permission,
    required this.scopes,
    required this.source,
    this.academicYearId,
    this.startsAt,
    this.endsAt,
  });
  factory ActionGrant.fromJson(Map<String, dynamic> json) => ActionGrant(
    permission: json['permission'] as String,
    scopes: List.unmodifiable(
      (json['scopes'] as List).map(
        (scope) => GrantScope.fromJson(Map<String, dynamic>.from(scope as Map)),
      ),
    ),
    source: GrantSource.values.byName(json['source'] as String),
    academicYearId: json['academicYearId'] as String?,
    startsAt: json['startsAt'] == null
        ? null
        : DateTime.parse(json['startsAt'] as String),
    endsAt: json['endsAt'] == null
        ? null
        : DateTime.parse(json['endsAt'] as String),
  );
  final String permission;
  final List<GrantScope> scopes;
  final GrantSource source;
  final String? academicYearId;
  final DateTime? startsAt;
  final DateTime? endsAt;

  Map<String, dynamic> toJson() => {
    'permission': permission,
    'scopes': scopes.map((scope) => scope.toJson()).toList(),
    'source': source.name,
    if (academicYearId != null) 'academicYearId': academicYearId,
    if (startsAt != null) 'startsAt': startsAt!.toUtc().toIso8601String(),
    if (endsAt != null) 'endsAt': endsAt!.toUtc().toIso8601String(),
  };
}

String _identifier(Map<String, dynamic> json, String field) {
  final value = json[field];
  if (value is! String || value.trim().isEmpty) {
    throw FormatException('Grant scope requires $field');
  }
  return value;
}

void _fields(Map<String, dynamic> json, Set<String> allowed) {
  if (json.keys.any((key) => !allowed.contains(key))) {
    throw const FormatException('Unexpected grant scope field');
  }
}

sealed class GrantScope {
  const GrantScope();
  factory GrantScope.fromJson(Map<String, dynamic> json) {
    switch (json['kind']) {
      case 'school':
        _fields(json, {'kind'});
        return SchoolGrantScope();
      case 'all':
        _fields(json, {'kind', 'grain'});
        return AllGrantScope(grain: GrantGrain.parse(json['grain'] as String));
      case 'grade_level':
        _fields(json, {'kind', 'gradeLevelId'});
        return GradeLevelGrantScope(
          gradeLevelId: _identifier(json, 'gradeLevelId'),
        );
      case 'grade_level_subject':
        _fields(json, {'kind', 'gradeLevelId', 'gradeLevelSubjectId'});
        return GradeLevelSubjectGrantScope(
          gradeLevelId: _identifier(json, 'gradeLevelId'),
          gradeLevelSubjectId: json.containsKey('gradeLevelSubjectId')
              ? _identifier(json, 'gradeLevelSubjectId')
              : null,
        );
      case 'class_group':
        _fields(json, {'kind', 'classGroupId'});
        return ClassGroupGrantScope(
          classGroupId: _identifier(json, 'classGroupId'),
        );
      case 'class_subject':
        _fields(json, {'kind', 'classGroupId', 'classSubjectId'});
        return ClassSubjectGrantScope(
          classGroupId: _identifier(json, 'classGroupId'),
          classSubjectId: json.containsKey('classSubjectId')
              ? _identifier(json, 'classSubjectId')
              : null,
        );
      case 'activity':
        _fields(json, {'kind', 'activityId', 'classGroupId'});
        if (!json.containsKey('activityId') &&
            !json.containsKey('classGroupId')) {
          throw const FormatException(
            'Activity scope requires an activity or class',
          );
        }
        return ActivityGrantScope(
          activityId: json.containsKey('activityId')
              ? _identifier(json, 'activityId')
              : null,
          classGroupId: json.containsKey('classGroupId')
              ? _identifier(json, 'classGroupId')
              : null,
        );
      case 'student':
        _fields(json, {'kind', 'studentId'});
        return StudentGrantScope(studentId: _identifier(json, 'studentId'));
      default:
        throw FormatException('Unknown grant scope: ${json['kind']}');
    }
  }
  Map<String, dynamic> toJson();
}

final class SchoolGrantScope extends GrantScope {
  const SchoolGrantScope();
  @override
  Map<String, dynamic> toJson() => {'kind': 'school'};
}

final class AllGrantScope extends GrantScope {
  const AllGrantScope({required this.grain});
  final GrantGrain grain;
  @override
  Map<String, dynamic> toJson() => {'kind': 'all', 'grain': grain.value};
}

final class GradeLevelGrantScope extends GrantScope {
  const GradeLevelGrantScope({required this.gradeLevelId});
  final String gradeLevelId;
  @override
  Map<String, dynamic> toJson() => {
    'kind': 'grade_level',
    'gradeLevelId': gradeLevelId,
  };
}

final class GradeLevelSubjectGrantScope extends GrantScope {
  const GradeLevelSubjectGrantScope({
    required this.gradeLevelId,
    this.gradeLevelSubjectId,
  });
  final String gradeLevelId;
  final String? gradeLevelSubjectId;
  @override
  Map<String, dynamic> toJson() => {
    'kind': 'grade_level_subject',
    'gradeLevelId': gradeLevelId,
    if (gradeLevelSubjectId != null) 'gradeLevelSubjectId': gradeLevelSubjectId,
  };
}

final class ClassGroupGrantScope extends GrantScope {
  const ClassGroupGrantScope({required this.classGroupId});
  final String classGroupId;
  @override
  Map<String, dynamic> toJson() => {
    'kind': 'class_group',
    'classGroupId': classGroupId,
  };
}

final class ClassSubjectGrantScope extends GrantScope {
  const ClassSubjectGrantScope({
    required this.classGroupId,
    this.classSubjectId,
  });
  final String classGroupId;
  final String? classSubjectId;
  @override
  Map<String, dynamic> toJson() => {
    'kind': 'class_subject',
    'classGroupId': classGroupId,
    if (classSubjectId != null) 'classSubjectId': classSubjectId,
  };
}

final class ActivityGrantScope extends GrantScope {
  const ActivityGrantScope({this.activityId, this.classGroupId});
  final String? activityId;
  final String? classGroupId;
  @override
  Map<String, dynamic> toJson() => {
    'kind': 'activity',
    if (activityId != null) 'activityId': activityId,
    if (classGroupId != null) 'classGroupId': classGroupId,
  };
}

final class StudentGrantScope extends GrantScope {
  const StudentGrantScope({required this.studentId});
  final String studentId;
  @override
  Map<String, dynamic> toJson() => {'kind': 'student', 'studentId': studentId};
}
