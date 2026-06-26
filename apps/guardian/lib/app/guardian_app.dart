import 'package:flutter/material.dart';
import 'package:levit_flutter/levit_flutter.dart';

import '../auth/app_bootstrap_controller.dart';
import '../auth/auth_gate.dart';
import '../di/guardian_module.dart';

class GuardianApp extends StatelessWidget {
  const GuardianApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Edaya Guardian',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        useMaterial3: true,
      ),
      home: const AuthGate(),
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
          return const MaterialApp(
            home: Scaffold(
              body: Center(child: CircularProgressIndicator()),
            ),
          );
        }

        return const GuardianApp();
      },
    );
  }
}

/// Root widget that owns the app-wide Levit scope for all routes.
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
