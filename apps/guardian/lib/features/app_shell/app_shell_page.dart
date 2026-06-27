import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:levit_flutter/levit_flutter.dart';

import '../../app/router.dart';
import 'app_shell_controller.dart';
import 'widgets/guardian_app_bar.dart';

class AppShellPage extends LScopedView<AppShellController> {
  const AppShellPage({super.key, required this.child});

  final Widget child;

  @override
  AppShellController onConfigScope(LevitScope scope) {
    return scope.put(
      () => AppShellController(appRouter: scope.find<AppRouter>()),
    );
  }

  @override
  Widget buildView(BuildContext context, AppShellController controller) {
    final location = GoRouterState.of(context).uri.toString();
    final selectedIndex = controller.selectedIndexForLocation(location);

    return Scaffold(
      appBar: const GuardianAppBar(),
      body: child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: selectedIndex,
        onDestinationSelected: controller.onDestinationSelected,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.calendar_month_outlined),
            selectedIcon: Icon(Icons.calendar_month),
            label: 'Calendar',
          ),
          NavigationDestination(
            icon: Icon(Icons.school_outlined),
            selectedIcon: Icon(Icons.school),
            label: 'Academic',
          ),
          NavigationDestination(
            icon: Icon(Icons.payments_outlined),
            selectedIcon: Icon(Icons.payments),
            label: 'Fees',
          ),
          NavigationDestination(
            icon: Icon(Icons.inbox_outlined),
            selectedIcon: Icon(Icons.inbox),
            label: 'Inbox',
          ),
        ],
      ),
    );
  }
}
