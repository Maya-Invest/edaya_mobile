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

  GuardianPortalScope? get guardianScope {
    if (kind != 'guardian') {
      return null;
    }
    final studentIds = <String>{};
    final classGroupIds = <String>{};
    for (final grant in grants) {
      for (final scope in grant.scopes) {
        switch (scope) {
          case StudentGrantScope(:final studentId):
            studentIds.add(studentId);
          case ClassGroupGrantScope(:final classGroupId):
            classGroupIds.add(classGroupId);
          case SubjectGrantScope(:final classGroupId):
            if (classGroupId != null) classGroupIds.add(classGroupId);
          default:
            break;
        }
      }
    }
    return GuardianPortalScope(
      studentIds: studentIds.toList(),
      classGroupIds: classGroupIds.toList(),
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

class GuardianPortalScope {
  const GuardianPortalScope({
    required this.studentIds,
    required this.classGroupIds,
  });

  final List<String> studentIds;
  final List<String> classGroupIds;
}

enum GrantSource { manual, assignment, relationship, owner }

enum GrantGrain {
  gradeLevel('grade_level'),
  subject('subject'),
  classGroup('class_group'),
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
        return const SchoolGrantScope();
      case 'all':
        _fields(json, {'kind', 'grain'});
        return AllGrantScope(grain: GrantGrain.parse(json['grain'] as String));
      case 'grade_level':
        _fields(json, {'kind', 'gradeLevelId'});
        return GradeLevelGrantScope(
          gradeLevelId: _identifier(json, 'gradeLevelId'),
        );
      case 'subject':
        _fields(json, {'kind', 'gradeLevelId', 'subjectId', 'classGroupId'});
        return SubjectGrantScope(
          classGroupId: json.containsKey('classGroupId') ? _identifier(json, 'classGroupId') : null,
          gradeLevelId: _identifier(json, 'gradeLevelId'),
          subjectId: json.containsKey('subjectId')
              ? _identifier(json, 'subjectId')
              : null,
        );
      case 'class_group':
        _fields(json, {'kind', 'classGroupId'});
        return ClassGroupGrantScope(
          classGroupId: _identifier(json, 'classGroupId'),
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

final class SubjectGrantScope extends GrantScope {
  const SubjectGrantScope({
    required this.gradeLevelId,
    this.subjectId,
    this.classGroupId,
  });
  final String gradeLevelId;
  final String? subjectId;
  final String? classGroupId;
  @override
  Map<String, dynamic> toJson() => {
    'kind': 'subject',
    'gradeLevelId': gradeLevelId,
    if (subjectId != null) 'subjectId': subjectId,
    if (classGroupId != null) 'classGroupId': classGroupId,
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
