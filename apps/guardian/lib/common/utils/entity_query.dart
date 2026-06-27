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
