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

/// Synchronous guardian auth redirect. Persist incoming invite tokens before
/// calling this so a login bounce cannot drop the URI.
String? resolveGuardianAuthRedirect({
  required bool isAuthenticated,
  required String matchedLocation,
  required String? pendingInvitationToken,
}) {
  final isInviteRoute = matchedLocation.startsWith('/invite');
  final isLoginRoute = matchedLocation == '/login';

  if (!isAuthenticated) {
    if (isInviteRoute || isLoginRoute) {
      return null;
    }
    if (pendingInvitationToken != null && pendingInvitationToken.isNotEmpty) {
      return invitationRoutePath(pendingInvitationToken);
    }
    return '/login';
  }

  if (pendingInvitationToken != null &&
      pendingInvitationToken.isNotEmpty &&
      !isInviteRoute) {
    return invitationRoutePath(pendingInvitationToken);
  }

  if (isLoginRoute) {
    return '/calendar';
  }
  return null;
}
