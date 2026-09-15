import 'package:edaya_shared/edaya_shared.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('parseInvitationDeepLink accepts first-party invite HTTPS URLs', () {
    final link = parseInvitationDeepLink(
      Uri.parse('https://staging.app.edayaplus.com/invite/abc123'),
    );
    expect(link?.token, 'abc123');
    expect(
      parseInvitationDeepLink(
        Uri.parse(
          'https://staging.app.school.edayaplus.com/invite/legacy-token',
        ),
      )?.token,
      'legacy-token',
    );
  });

  test('parseInvitationDeepLink accepts localhost and emulator hosts', () {
    expect(
      parseInvitationDeepLink(
        Uri.parse('http://localhost:5173/invite/local-token'),
      )?.token,
      'local-token',
    );
    expect(
      parseInvitationDeepLink(
        Uri.parse('http://10.0.2.2:5173/invite/emu-token'),
      )?.token,
      'emu-token',
    );
  });

  test('parseInvitationDeepLink rejects unknown hosts', () {
    expect(
      parseInvitationDeepLink(Uri.parse('https://evil.example/invite/abc123')),
      isNull,
    );
  });

  test('parseInvitationDeepLink accepts in-app path-only URIs', () {
    expect(
      parseInvitationDeepLink(Uri.parse('/invite/path-token'))?.token,
      'path-token',
    );
  });

  test('resolveGuardianAuthRedirect keeps invite public before auth', () {
    expect(
      resolveGuardianAuthRedirect(
        isAuthenticated: false,
        matchedLocation: '/invite/abc',
        pendingInvitationToken: 'abc',
      ),
      isNull,
    );
    expect(
      resolveGuardianAuthRedirect(
        isAuthenticated: false,
        matchedLocation: '/calendar',
        pendingInvitationToken: 'abc',
      ),
      '/invite/abc',
    );
    expect(
      resolveGuardianAuthRedirect(
        isAuthenticated: false,
        matchedLocation: '/calendar',
        pendingInvitationToken: null,
      ),
      '/login',
    );
  });

  test('resolveGuardianAuthRedirect keeps an authenticated invite route', () {
    expect(
      resolveGuardianAuthRedirect(
        isAuthenticated: true,
        matchedLocation: '/invite/abc',
        pendingInvitationToken: 'abc',
      ),
      isNull,
    );
  });

  test('resolveGuardianAuthRedirect returns to invite after auth', () {
    expect(
      resolveGuardianAuthRedirect(
        isAuthenticated: true,
        matchedLocation: '/login',
        pendingInvitationToken: 'abc',
      ),
      '/invite/abc',
    );
  });

  test('resolveGuardianAuthRedirect sends unlinked accounts to waiting', () {
    expect(
      resolveGuardianAuthRedirect(
        isAuthenticated: true,
        matchedLocation: '/login',
        pendingInvitationToken: null,
      ),
      '/waiting',
    );
    expect(
      resolveGuardianAuthRedirect(
        isAuthenticated: true,
        matchedLocation: '/calendar',
        pendingInvitationToken: null,
      ),
      '/waiting',
    );
  });

  test(
    'resolveGuardianAuthRedirect keeps login until linked students resolve',
    () {
      expect(
        resolveGuardianAuthRedirect(
          isAuthenticated: true,
          matchedLocation: '/login',
          pendingInvitationToken: null,
          hasSchoolSession: true,
        ),
        isNull,
      );
    },
  );

  test(
    'resolveGuardianAuthRedirect opens calendar when children are linked',
    () {
      expect(
        resolveGuardianAuthRedirect(
          isAuthenticated: true,
          matchedLocation: '/login',
          pendingInvitationToken: null,
          hasSchoolSession: true,
          linkedStudentsResolved: true,
          hasLinkedStudents: true,
        ),
        '/calendar',
      );
      expect(
        resolveGuardianAuthRedirect(
          isAuthenticated: true,
          matchedLocation: '/waiting',
          pendingInvitationToken: null,
          hasSchoolSession: true,
          linkedStudentsResolved: true,
          hasLinkedStudents: true,
        ),
        '/calendar',
      );
    },
  );

  test(
    'resolveGuardianAuthRedirect keeps waiting when no children are linked',
    () {
      expect(
        resolveGuardianAuthRedirect(
          isAuthenticated: true,
          matchedLocation: '/waiting',
          pendingInvitationToken: null,
          hasSchoolSession: true,
          linkedStudentsResolved: true,
        ),
        isNull,
      );
      expect(
        resolveGuardianAuthRedirect(
          isAuthenticated: true,
          matchedLocation: '/settings',
          pendingInvitationToken: null,
          hasSchoolSession: true,
          linkedStudentsResolved: true,
        ),
        isNull,
      );
      expect(
        resolveGuardianPostAuthHome(
          hasSchoolSession: true,
          hasLinkedStudents: false,
        ),
        '/waiting',
      );
    },
  );

  test('PendingInvitationStore round-trips a token until cleared', () async {
    SharedPreferences.setMockInitialValues({});
    final store = PendingInvitationStore();
    await store.save('invite-1');
    expect(store.token, 'invite-1');

    final restored = PendingInvitationStore();
    await restored.hydrate();
    expect(restored.token, 'invite-1');

    await restored.clear();
    expect(restored.token, isNull);
  });
}
