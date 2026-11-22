import 'package:edaya_guardian_v2/features/login/login_page.dart';
import 'package:edaya_guardian_v2/live/prototype_runtime.dart';

import '../../../packages/edaya_shared/test/support/login_api_switcher.dart';

void main() {
  testLoginApiSwitcher(
    app: 'guardian-v2',
    login: LoginPage(defaultEmail: '', onSignInSuccess: () async {}),
    registerRuntime: (scope) =>
        scope.put<PrototypeRuntime>(() => const PrototypeRuntime(live: true)),
  );
}
