import 'package:edaya_shared/edaya_shared.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:levit_flutter/levit_flutter.dart';

import '../../app/router.dart';
import '../calendar/calendar_controller.dart';
import '../context/academic_year_controller.dart';
import '../context/teacher_context_controller.dart';
import 'app_shell_controller.dart';
import 'widgets/teacher_app_bar.dart';

class AppShellPage extends LScopedView<AppShellController> {
  const AppShellPage({super.key, required this.child});

  final Widget child;

  @override
  AppShellController onConfigScope(LevitScope scope) {
    scope.put(
      () => CalendarController(
        teacherContext: scope.find<TeacherContextController>(),
        academicYear: scope.find<AcademicYearController>(),
        schoolClient: scope.find<SchoolClientFactory>(),
      ),
    );
    return scope.put(
      () => AppShellController(appRouter: scope.find<AppRouter>()),
    );
  }

  @override
  Widget buildView(BuildContext context, AppShellController controller) {
    final location = GoRouterState.of(context).uri.toString();
    final selectedIndex = controller.selectedIndexForLocation(location);

    return Scaffold(
      appBar: TeacherAppBar(
        textScale: MediaQuery.textScalerOf(context).scale(14) / 14,
      ),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1120),
          child: child,
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: selectedIndex,
        onDestinationSelected: controller.onDestinationSelected,
        destinations: [
          NavigationDestination(
            icon: Icon(Icons.calendar_month_outlined),
            selectedIcon: Icon(Icons.calendar_month),
            label: context.tr.navCalendar,
          ),
          NavigationDestination(
            icon: Icon(Icons.grade_outlined),
            selectedIcon: Icon(Icons.grade),
            label: context.tr.navEvaluations,
          ),
          NavigationDestination(
            icon: Icon(Icons.school_outlined),
            selectedIcon: Icon(Icons.school),
            label: context.tr.navTeaching,
          ),
          NavigationDestination(
            icon: Icon(Icons.description_outlined),
            selectedIcon: Icon(Icons.description),
            label: context.tr.navReportCards,
          ),
        ],
      ),
    );
  }
}
