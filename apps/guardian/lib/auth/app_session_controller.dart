import 'dart:async';

import 'package:edaya_api_client/edaya_api_client.dart' as api;
import 'package:edaya_auth/edaya_auth.dart';
import 'package:levit_flutter/levit_flutter.dart';

import '../di/edaya_module.dart';
import 'session_storage.dart';

/// Root session state shared across auth screens.
class AppSessionController extends LevitController {
  AppSessionController({
    required AuthClient authClient,
    required SessionStorage sessionStorage,
  }) : _authClient = authClient,
       _sessionStorage = sessionStorage;

  final AuthClient _authClient;
  final SessionStorage _sessionStorage;

  final user = LxVar<AuthUser?>(null);
  final grants = LxVar<api.EffectiveGrantsResponse?>(null);
  final isBootstrapping = LxVar(true);
  final isSigningOut = LxVar(false);

  bool get isAuthenticated => user.value != null;

  @override
  void onInit() {
    super.onInit();
    autoDispose(user);
    autoDispose(grants);
    autoDispose(isBootstrapping);
    autoDispose(isSigningOut);
  }

  Future<void> restoreSession() async {
    isBootstrapping(true);

    try {
      if (await _sessionStorage.isLoggedOut()) {
        return;
      }

      final result = await _authClient.getSession();
      if (!result.isSuccess || result.data == null) {
        return;
      }

      final error = await _loadSchoolSession(result.data!.user);
      if (error != null) {
        await _clearLocalSession(persistCookies: false);
      }
    } finally {
      isBootstrapping(false);
    }
  }

  Future<String?> completeSignIn(AuthUser signedInUser) async {
    final error = await _loadSchoolSession(signedInUser);
    if (error != null) {
      return error;
    }

    await _sessionStorage.markLoggedIn();
    await _sessionStorage.persist(_authClient.cookieJar);
    return null;
  }

  Future<void> signOut() async {
    if (isSigningOut.value) {
      return;
    }

    isSigningOut(true);
    try {
      await _authClient.signOut();
      await _sessionStorage.markLoggedOut();
      await _clearLocalSession();
    } finally {
      isSigningOut(false);
    }
  }

  Future<String?> _loadSchoolSession(AuthUser signedInUser) async {
    final schoolClient = createEdayaSchoolClient(_authClient);
    try {
      final effectiveGrants = await schoolClient.effectiveGrants();
      user(signedInUser);
      grants(effectiveGrants);
      return null;
    } on api.ApiError catch (error) {
      if (error.status == 401) {
        return 'Signed in, but no linked guardian/staff profile. Run: bun run seed:auth:link';
      }
      return 'Signed in, but school session is unavailable: $error';
    } on Object catch (error) {
      return 'Signed in, but school session is unavailable: $error';
    }
  }

  Future<void> _clearLocalSession({bool persistCookies = true}) async {
    user(null);
    grants(null);
    if (persistCookies) {
      await _sessionStorage.clearCookies();
      _authClient.cookieJar.clear();
    }
  }
}
