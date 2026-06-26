import 'package:edaya_auth/edaya_auth.dart';
import 'package:levit_flutter/levit_flutter.dart';

import '../auth/app_bootstrap_controller.dart';
import '../auth/app_session_controller.dart';
import '../auth/session_storage.dart';
import 'edaya_module.dart';

void registerGuardianDependencies(LevitScope scope) {
  final cookieJar = CookieJar();
  scope.put<CookieJar>(() => cookieJar, permanent: true);
  scope.put<SessionStorage>(() => SessionStorage(), permanent: true);
  registerEdayaDependencies(scope, cookieJar: cookieJar);
  scope.put(
    () => AppSessionController(
      authClient: scope.find<AuthClient>(),
      sessionStorage: scope.find<SessionStorage>(),
    ),
    permanent: true,
  );
  scope.put(
    () => AppBootstrapController(
      cookieJar: scope.find<CookieJar>(),
      sessionStorage: scope.find<SessionStorage>(),
      session: scope.find<AppSessionController>(),
    ),
    permanent: true,
  );
}
