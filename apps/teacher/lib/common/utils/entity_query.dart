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
