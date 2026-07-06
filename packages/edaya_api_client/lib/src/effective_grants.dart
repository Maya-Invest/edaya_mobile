class EffectiveGrantsResponse {
  const EffectiveGrantsResponse({
    required this.kind,
    required this.actorId,
    required this.schoolId,
    required this.assuranceLevel,
    required this.effectiveGrants,
    this.capabilities = const [],
    this.scope,
  });

  factory EffectiveGrantsResponse.fromJson(Map<String, dynamic> json) {
    final scopeRaw = json['scope'];
    return EffectiveGrantsResponse(
      kind: json['kind'] as String,
      actorId: json['actorId'] as String,
      schoolId: json['schoolId'] as String,
      assuranceLevel: json['assuranceLevel'] as String,
      effectiveGrants: EffectiveGrants.fromJson(
        Map<String, dynamic>.from(json['effectiveGrants'] as Map),
      ),
      capabilities: (json['capabilities'] as List<dynamic>?)
              ?.map((entry) => entry as String)
              .toList() ??
          const [],
      scope: scopeRaw is Map
          ? Map<String, dynamic>.from(scopeRaw)
          : null,
    );
  }

  final String kind;
  final String actorId;
  final String schoolId;
  final String assuranceLevel;
  final EffectiveGrants effectiveGrants;
  final List<String> capabilities;
  final Map<String, dynamic>? scope;

  TeacherPortalScope? get teacherScope {
    final scopeMap = scope;
    if (scopeMap == null) {
      return null;
    }
    return TeacherPortalScope.fromJson(scopeMap);
  }

  GuardianPortalScope? get guardianScope {
    final scopeMap = scope;
    if (scopeMap == null) {
      return null;
    }
    return GuardianPortalScope.fromJson(scopeMap);
  }

  Map<String, dynamic> toJson() => {
    'kind': kind,
    'actorId': actorId,
    'schoolId': schoolId,
    'assuranceLevel': assuranceLevel,
    'effectiveGrants': effectiveGrants.toJson(),
    if (capabilities.isNotEmpty) 'capabilities': capabilities,
    if (scope != null) 'scope': scope,
  };
}

class TeacherPortalScope {
  const TeacherPortalScope({
    required this.classSubjectIds,
    required this.homeroomClassGroupIds,
  });

  factory TeacherPortalScope.fromJson(Map<String, dynamic> json) {
    final teaching = json['teaching'];
    final homeroom = json['homeroom'];
    return TeacherPortalScope(
      classSubjectIds: teaching is Map
          ? (teaching['classSubjectIds'] as List<dynamic>?)
                  ?.map((entry) => entry as String)
                  .toList() ??
              const []
          : const [],
      homeroomClassGroupIds: homeroom is Map
          ? (homeroom['classGroupIds'] as List<dynamic>?)
                  ?.map((entry) => entry as String)
                  .toList() ??
              const []
          : const [],
    );
  }

  final List<String> classSubjectIds;
  final List<String> homeroomClassGroupIds;
}

class GuardianPortalScope {
  const GuardianPortalScope({
    required this.studentIds,
    required this.classGroupIds,
  });

  factory GuardianPortalScope.fromJson(Map<String, dynamic> json) {
    return GuardianPortalScope(
      studentIds: (json['studentIds'] as List<dynamic>?)
              ?.map((entry) => entry as String)
              .toList() ??
          const [],
      classGroupIds: (json['classGroupIds'] as List<dynamic>?)
              ?.map((entry) => entry as String)
              .toList() ??
          const [],
    );
  }

  final List<String> studentIds;
  final List<String> classGroupIds;
}

class EffectiveGrants {
  const EffectiveGrants({
    required this.permissions,
    required this.scopeGrants,
    required this.scopeIdsByPermission,
    required this.isElevated,
    this.expiresAt,
  });

  factory EffectiveGrants.fromJson(Map<String, dynamic> json) {
    final scopeIdsRaw = json['scopeIdsByPermission'];
    return EffectiveGrants(
      permissions: (json['permissions'] as List<dynamic>?)
              ?.map((entry) => entry as String)
              .toList() ??
          const [],
      scopeGrants: (json['scopeGrants'] as List<dynamic>?)
              ?.map(
                (entry) => ScopeGrant.fromJson(
                  Map<String, dynamic>.from(entry as Map),
                ),
              )
              .toList() ??
          const [],
      scopeIdsByPermission: scopeIdsRaw is Map
          ? Map<String, String>.from(
              scopeIdsRaw.map(
                (key, value) => MapEntry('$key', '$value'),
              ),
            )
          : const {},
      isElevated: json['isElevated'] as bool? ?? false,
      expiresAt: json['expiresAt'] as String?,
    );
  }

  final List<String> permissions;
  final List<ScopeGrant> scopeGrants;
  final Map<String, String> scopeIdsByPermission;
  final bool isElevated;
  final String? expiresAt;

  Map<String, dynamic> toJson() => {
    'permissions': permissions,
    'scopeGrants': scopeGrants.map((entry) => entry.toJson()).toList(),
    'scopeIdsByPermission': scopeIdsByPermission,
    'isElevated': isElevated,
    if (expiresAt != null) 'expiresAt': expiresAt,
  };
}

class ScopeGrant {
  const ScopeGrant({
    required this.permission,
    required this.scopeType,
    required this.scopeEntityIds,
  });

  factory ScopeGrant.fromJson(Map<String, dynamic> json) {
    return ScopeGrant(
      permission: json['permission'] as String,
      scopeType: json['scopeType'] as String,
      scopeEntityIds: (json['scopeEntityIds'] as List<dynamic>)
          .map((entry) => entry as String)
          .toList(),
    );
  }

  final String permission;
  final String scopeType;
  final List<String> scopeEntityIds;

  Map<String, dynamic> toJson() => {
    'permission': permission,
    'scopeType': scopeType,
    'scopeEntityIds': scopeEntityIds,
  };
}
