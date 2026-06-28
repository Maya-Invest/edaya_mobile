import 'package:flutter/material.dart';
import 'package:levit_flutter/levit_flutter.dart';

import '../features/auth/app_bootstrap_controller.dart';
import 'edaya_root_scope.dart';
import 'theme.dart';

/// Provides the [RouterConfig] for [MaterialApp.router].
abstract class EdayaAppRouter {
  RouterConfig<Object> config();
}

class EdayaAppRoot extends StatelessWidget {
  const EdayaAppRoot({
    super.key,
    required this.scopeName,
    required this.appTitle,
    required this.registerDependencies,
  });

  final String scopeName;
  final String appTitle;
  final void Function(LevitScope scope) registerDependencies;

  @override
  Widget build(BuildContext context) {
    return LScope(
      name: scopeName,
      dependencyFactory: registerDependencies,
      child: EdayaBootstrapGate(appTitle: appTitle),
    );
  }
}

class EdayaBootstrapGate extends LView<AppBootstrapController> {
  const EdayaBootstrapGate({super.key, required this.appTitle});

  final String appTitle;

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
          title: appTitle,
          theme: AppTheme.light,
          routerConfig: EdayaRootScope.find<EdayaAppRouter>().config(),
        );
      },
    );
  }
}
