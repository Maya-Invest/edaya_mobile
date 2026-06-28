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

EntityQuery classGroupScope(String classGroupId) {
  return {'classGroupId': classGroupId};
}

EntityQuery studentScope(String studentId) {
  return {'studentId': studentId};
}

EntityQuery academicYearScope(String academicYearId) {
  return {'academicYearId': academicYearId};
}

EntityQuery sessionScope(String sessionId) {
  return {'sessionId': sessionId};
}

EntityQuery recordsForField(String field, List<String> ids) {
  if (ids.isEmpty) {
    return {
      field: {'\$in': ['__no_match__']},
    };
  }
  return {
    field: {'\$in': ids},
  };
}
