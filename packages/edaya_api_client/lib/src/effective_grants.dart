class EffectiveGrantsResponse {
  const EffectiveGrantsResponse({
    required this.kind,
    required this.actorId,
    required this.schoolId,
    required this.assuranceLevel,
    required this.effectiveGrants,
  });

  factory EffectiveGrantsResponse.fromJson(Map<String, dynamic> json) {
    return EffectiveGrantsResponse(
      kind: json['kind'] as String,
      actorId: json['actorId'] as String,
      schoolId: json['schoolId'] as String,
      assuranceLevel: json['assuranceLevel'] as String,
      effectiveGrants: EffectiveGrants.fromJson(
        Map<String, dynamic>.from(json['effectiveGrants'] as Map),
      ),
    );
  }

  final String kind;
  final String actorId;
  final String schoolId;
  final String assuranceLevel;
  final EffectiveGrants effectiveGrants;

  Map<String, dynamic> toJson() => {
    'kind': kind,
    'actorId': actorId,
    'schoolId': schoolId,
    'assuranceLevel': assuranceLevel,
    'effectiveGrants': effectiveGrants.toJson(),
  };
}

class EffectiveGrants {
  const EffectiveGrants({
    required this.permissions,
    required this.scopeGrants,
    required this.isElevated,
    this.expiresAt,
  });

  factory EffectiveGrants.fromJson(Map<String, dynamic> json) {
    return EffectiveGrants(
      permissions: (json['permissions'] as List<dynamic>)
          .map((entry) => entry as String)
          .toList(),
      scopeGrants: (json['scopeGrants'] as List<dynamic>)
          .map(
            (entry) => ScopeGrant.fromJson(
              Map<String, dynamic>.from(entry as Map),
            ),
          )
          .toList(),
      isElevated: json['isElevated'] as bool,
      expiresAt: json['expiresAt'] as String?,
    );
  }

  final List<String> permissions;
  final List<ScopeGrant> scopeGrants;
  final bool isElevated;
  final String? expiresAt;

  Map<String, dynamic> toJson() => {
    'permissions': permissions,
    'scopeGrants': scopeGrants.map((entry) => entry.toJson()).toList(),
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
