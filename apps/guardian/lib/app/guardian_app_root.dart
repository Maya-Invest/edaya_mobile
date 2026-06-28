import 'package:edaya_shared/edaya_shared.dart';

import '../di/guardian_module.dart';

class GuardianAppRoot extends EdayaAppRoot {
  const GuardianAppRoot({super.key})
    : super(
        scopeName: 'guardian-app',
        appTitle: 'Edaya Guardian',
        registerDependencies: registerGuardianDependencies,
      );
}
