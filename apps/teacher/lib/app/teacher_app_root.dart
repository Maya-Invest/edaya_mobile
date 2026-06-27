import 'package:flutter/material.dart';
import 'package:levit_flutter/levit_flutter.dart';

import '../access/root_scope.dart';
import '../app/router.dart';
import '../app/theme.dart';
import '../di/teacher_module.dart';
import '../features/auth/app_bootstrap_controller.dart';

class TeacherAppRoot extends StatelessWidget {
  const TeacherAppRoot({super.key});

  @override
  Widget build(BuildContext context) {
    return LScope(
      name: 'teacher-app',
      dependencyFactory: registerTeacherDependencies,
      child: const TeacherBootstrapGate(),
    );
  }
}

class TeacherBootstrapGate extends LView<AppBootstrapController> {
  const TeacherBootstrapGate({super.key});

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
          title: 'Edaya Teacher',
          theme: AppTheme.light,
          routerConfig: TeacherRootScope.find<AppRouter>().config(),
        );
      },
    );
  }
}
