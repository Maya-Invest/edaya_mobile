import 'package:flutter/material.dart';
import 'package:levit_flutter/levit_flutter.dart';

import '../access/root_scope.dart';
import '../app/router.dart';
import '../app/theme.dart';
import '../di/guardian_module.dart';
import '../features/auth/app_bootstrap_controller.dart';

class GuardianAppRoot extends StatelessWidget {
  const GuardianAppRoot({super.key});

  @override
  Widget build(BuildContext context) {
    return LScope(
      name: 'guardian-app',
      dependencyFactory: registerGuardianDependencies,
      child: const GuardianBootstrapGate(),
    );
  }
}

class GuardianBootstrapGate extends LView<AppBootstrapController> {
  const GuardianBootstrapGate({super.key});

  @override
  Widget buildView(BuildContext context, AppBootstrapController controller) {
    return LWatch(
      () {
        if (!controller.isReady.value) {
          return MaterialApp(
            theme: AppTheme.light,
            home: const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            ),
          );
        }

        return MaterialApp.router(
          title: 'Edaya Guardian',
          theme: AppTheme.light,
          routerConfig: GuardianRootScope.find<AppRouter>().config(),
        );
      },
    );
  }
}
