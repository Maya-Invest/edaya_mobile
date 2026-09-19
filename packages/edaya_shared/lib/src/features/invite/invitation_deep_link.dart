const invitationLinkHosts = {
  'app.edayaplus.com',
  'staging.app.edayaplus.com',
  'app.school.edayaplus.com',
  'staging.app.school.edayaplus.com',
  'localhost',
  '127.0.0.1',
  '10.0.2.2',
};

final _invitePath = RegExp(r'^/invite/([^/]+)/?$');

class InvitationDeepLink {
  const InvitationDeepLink(this.token);

  final String token;
}

InvitationDeepLink? parseInvitationDeepLink(Uri uri) {
  final match = _invitePath.firstMatch(uri.path);
  if (match == null) {
    return null;
  }
  if (uri.host.isNotEmpty && !invitationLinkHosts.contains(uri.host)) {
    return null;
  }
  final token = Uri.decodeComponent(match.group(1)!).trim();
  if (token.isEmpty) {
    return null;
  }
  return InvitationDeepLink(token);
}

String invitationRoutePath(String token) => '/invite/$token';

const guardianLoginRoute = '/login';
const guardianHomeRoute = '/home';
const guardianWaitingRoute = '/waiting';

bool guardianHasLinkedChildren({
  required bool hasSchoolSession,
  required bool hasLinkedStudents,
}) {
  return hasSchoolSession && hasLinkedStudents;
}

String resolveGuardianPostAuthHome({
  required bool hasSchoolSession,
  required bool hasLinkedStudents,
}) {
  return guardianHasLinkedChildren(
        hasSchoolSession: hasSchoolSession,
        hasLinkedStudents: hasLinkedStudents,
      )
      ? guardianHomeRoute
      : guardianWaitingRoute;
}

bool _isGuardianIdentityOnlyRoute(String matchedLocation) {
  return matchedLocation == guardianWaitingRoute ||
      matchedLocation == '/settings' ||
      matchedLocation == '/account' ||
      matchedLocation.startsWith('/account/');
}

/// Synchronous guardian auth redirect. Persist incoming invite tokens before
/// calling this so a login bounce cannot drop the URI.
String? resolveGuardianAuthRedirect({
  required bool isAuthenticated,
  required String matchedLocation,
  required String? pendingInvitationToken,
  bool hasSchoolSession = false,
  bool linkedStudentsResolved = false,
  bool hasLinkedStudents = false,
}) {
  final isInviteRoute = matchedLocation.startsWith('/invite');
  final isLoginRoute = matchedLocation == guardianLoginRoute;

  if (!isAuthenticated) {
    if (isInviteRoute || isLoginRoute) {
      return null;
    }
    if (pendingInvitationToken != null && pendingInvitationToken.isNotEmpty) {
      return invitationRoutePath(pendingInvitationToken);
    }
    return guardianLoginRoute;
  }

  if (pendingInvitationToken != null &&
      pendingInvitationToken.isNotEmpty &&
      !isInviteRoute) {
    return invitationRoutePath(pendingInvitationToken);
  }

  final readyForHome = guardianHasLinkedChildren(
    hasSchoolSession: hasSchoolSession,
    hasLinkedStudents: hasLinkedStudents,
  );
  final waitingForChildren =
      !readyForHome && (linkedStudentsResolved || !hasSchoolSession);

  if (isLoginRoute) {
    if (!linkedStudentsResolved && hasSchoolSession) {
      return null;
    }
    return resolveGuardianPostAuthHome(
      hasSchoolSession: hasSchoolSession,
      hasLinkedStudents: hasLinkedStudents,
    );
  }

  if (waitingForChildren &&
      !isInviteRoute &&
      !_isGuardianIdentityOnlyRoute(matchedLocation)) {
    return guardianWaitingRoute;
  }

  if (readyForHome && matchedLocation == guardianWaitingRoute) {
    return guardianHomeRoute;
  }

  return null;
}
