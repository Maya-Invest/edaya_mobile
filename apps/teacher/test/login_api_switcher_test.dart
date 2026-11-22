import 'package:edaya_teacher_v2/features/login/login_page.dart';
import 'package:edaya_teacher_v2/live/prototype_runtime.dart';

import '../../../packages/edaya_shared/test/support/login_api_switcher.dart';

void main() {
  testLoginApiSwitcher(
    app: 'teacher-v2',
    login: const LoginPage(),
    registerRuntime: (scope) =>
        scope.put<PrototypeRuntime>(() => const PrototypeRuntime(live: true)),
  );
}
