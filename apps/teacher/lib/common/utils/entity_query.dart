import 'package:edaya_api_client/edaya_api_client.dart';

typedef EntityQuery = Map<String, dynamic>;

EntityQuery entitiesByIds(List<String> ids) {
  if (ids.isEmpty) {
    return {
      'id': {'\$in': ['__no_match__']},
    };
  }

  return {
    'id': {'\$in': ids},
  };
}

List<String> studentIdsFromScopeGrants(List<ScopeGrant> scopeGrants) {
  final ids = <String>{};
  for (final grant in scopeGrants) {
    if (grant.scopeType == 'student') {
      ids.addAll(grant.scopeEntityIds);
    }
  }
  return ids.toList();
}

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

TeachingScope teachingScopeFromScopeGrants(List<ScopeGrant> scopeGrants) {
  final classGroupIds = <String>{};
  final classSubjectIds = <String>{};
  final sessionIds = <String>{};
  for (final grant in scopeGrants) {
    switch (grant.scopeType) {
      case 'class_group':
        classGroupIds.addAll(grant.scopeEntityIds);
      case 'course_assignment':
        classSubjectIds.addAll(grant.scopeEntityIds);
      case 'session':
        sessionIds.addAll(grant.scopeEntityIds);
    }
  }
  return TeachingScope(
    classGroupIds: classGroupIds,
    classSubjectIds: classSubjectIds,
    sessionIds: sessionIds,
  );
}
