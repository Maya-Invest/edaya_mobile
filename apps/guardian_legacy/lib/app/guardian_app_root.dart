import 'package:edaya_shared/edaya_shared.dart';

import '../di/guardian_module.dart';

class GuardianAppRoot extends EdayaAppRoot {
  GuardianAppRoot({super.key})
    : super(
        scopeName: 'guardian-app',
        appTitle: systemL10n().appTitleGuardian,
        registerDependencies: registerGuardianDependencies,
      );
}
