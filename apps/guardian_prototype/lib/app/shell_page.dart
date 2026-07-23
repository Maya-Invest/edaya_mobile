import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:levit_flutter/levit_flutter.dart';

import '../design/colors.dart';
import '../design/components/components.dart';
import '../design/spacing.dart';
import '../features/context/student_context_controller.dart';
import '../mock/mock_store.dart';
import 'shell_controller.dart';

class PrototypeShell extends LScopedView<PrototypeShellController> {
  const PrototypeShell({super.key, required this.child});

  final Widget child;

  static const _tabs = ['/home', '/calendar', '/scolarite', '/fees', '/inbox'];

  static const _destinations = [
    NavigationDestination(
      icon: Icon(Icons.home_outlined),
      selectedIcon: Icon(Icons.home),
      label: 'Accueil',
    ),
    NavigationDestination(
      icon: Icon(Icons.calendar_month_outlined),
      selectedIcon: Icon(Icons.calendar_month),
      label: 'Agenda',
    ),
    NavigationDestination(
      icon: Icon(Icons.school_outlined),
      selectedIcon: Icon(Icons.school),
      label: 'Scolarité',
    ),
    NavigationDestination(
      icon: Icon(Icons.payments_outlined),
      selectedIcon: Icon(Icons.payments),
      label: 'Frais',
    ),
    NavigationDestination(
      icon: Icon(Icons.inbox_outlined),
      selectedIcon: Icon(Icons.inbox),
      label: 'Messages',
    ),
  ];

  /// Primary tab index, or `null` when none should be highlighted (account/settings).
  int? _indexForLocation(String location) {
    if (location.startsWith('/account') || location.startsWith('/settings')) {
      return null;
    }
    if (location.startsWith('/session') ||
        location.startsWith('/attendance')) {
      return 1;
    }
    if (location.startsWith('/scolarite') ||
        location.startsWith('/grade') ||
        location.startsWith('/report-card')) {
      return 2;
    }
    for (var i = 0; i < _tabs.length; i++) {
      if (location.startsWith(_tabs[i])) return i;
    }
    return 0;
  }

  List<NavigationDestination> _navDestinations({required bool noneSelected}) {
    if (!noneSelected) return _destinations;
    // NavigationBar requires a selectedIndex; keep visuals fully unselected.
    return [
      for (final d in _destinations)
        NavigationDestination(
          icon: d.icon,
          selectedIcon: d.icon,
          label: d.label,
        ),
    ];
  }

  bool _showChrome(String location) {
    return _tabs.any((t) => location.startsWith(t)) ||
        location.startsWith('/session') ||
        location.startsWith('/attendance') ||
        location.startsWith('/grade') ||
        location.startsWith('/report-card') ||
        location.startsWith('/account') ||
        location.startsWith('/settings');
  }

  void _openHelp(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Centre d\'aide — prototype')),
    );
  }

  @override
  PrototypeShellController onConfigScope(LevitScope scope) {
    return scope.put(
      () => PrototypeShellController(
        studentContext: scope.find<StudentContextController>(),
      ),
    );
  }

  @override
  Widget buildView(BuildContext context, PrototypeShellController controller) {
    final location = GoRouterState.of(context).uri.toString();
    final showNav = _showChrome(location);
    final index = _indexForLocation(location);
    final ctx = controller.studentContext;

        ctx.storeTick.value;
    final student = ctx.activeStudent;
    final school = ctx.activeSchool;

    final contextCard = StudentContextCard(
      studentName: student.fullName,
      studentInitials: student.initials,
      classLabel: student.classLabel,
      schoolName: school.name,
      schoolYear: ctx.selectedYear,
      photoUrl: student.photoUrl,
      onSelectStudent: () => _showContextSheet(context, ctx),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final useRail =
            showNav && PrototypeBreakpoints.useNavigationRail(constraints.maxWidth);

        final mainColumn = ShellChrome(
          showHeader: showNav,
          header: contextCard,
          appBar: useRail ? const PrototypeAppBar() : null,
          child: child,
        );

        final noneSelected = index == null;

        if (!useRail) {
          return Scaffold(
            backgroundColor: PrototypeColors.background,
            appBar: showNav
                ? PrototypeAppBar(
                    onProfileTap: () => context.go('/account'),
                    onHelpTap: () => _openHelp(context),
                  )
                : null,
            body: mainColumn,
            bottomNavigationBar: showNav
                ? NavigationBarTheme(
                    data: noneSelected
                        ? NavigationBarThemeData(
                            indicatorColor: Colors.transparent,
                            iconTheme: WidgetStateProperty.all(
                              IconThemeData(
                                color: PrototypeColors.onSurfaceVariant,
                              ),
                            ),
                            labelTextStyle: WidgetStateProperty.all(
                              Theme.of(context).textTheme.labelMedium?.copyWith(
                                color: PrototypeColors.onSurfaceVariant,
                              ),
                            ),
                          )
                        : const NavigationBarThemeData(),
                    child: NavigationBar(
                      selectedIndex: index ?? 0,
                      onDestinationSelected: (i) => context.go(_tabs[i]),
                      destinations: _navDestinations(
                        noneSelected: noneSelected,
                      ),
                    ),
                  )
                : null,
          );
        }

        return Scaffold(
          backgroundColor: PrototypeColors.background,
          body: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              NavigationRail(
                backgroundColor: PrototypeColors.background,
                selectedIndex: index,
                onDestinationSelected: (i) => context.go(_tabs[i]),
                labelType: NavigationRailLabelType.all,
                destinations: [
                  for (final d in _destinations)
                    NavigationRailDestination(
                      icon: d.icon,
                      selectedIcon: noneSelected ? d.icon : d.selectedIcon,
                      label: Text(d.label),
                    ),
                ],
                trailing: Expanded(
                  child: Align(
                    alignment: Alignment.bottomCenter,
                    child: Padding(
                      padding: const EdgeInsets.only(
                        bottom: PrototypeSpacing.md,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            tooltip: 'Mon compte',
                            icon: const Icon(Icons.account_circle_outlined),
                            onPressed: () => context.go('/account'),
                          ),
                          IconButton(
                            tooltip: 'Aide',
                            icon: const Icon(Icons.help_outline),
                            onPressed: () => _openHelp(context),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              VerticalDivider(
                width: 1,
                color: PrototypeColors.outlineVariant.withValues(alpha: 0.5),
              ),
              Expanded(child: mainColumn),
            ],
          ),
        );
      },
    );
  }

  void _showContextSheet(
    BuildContext context,
    StudentContextController studentContext,
  ) {
    showLevitModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return ListenableBuilder(
          listenable: studentContext.store,
          builder: (context, _) {
            final groups = studentContext.studentsBySchool;
            return Padding(
              padding: EdgeInsets.only(
                left: PrototypeSpacing.md,
                right: PrototypeSpacing.md,
                top: PrototypeSpacing.md,
                bottom:
                    MediaQuery.viewInsetsOf(context).bottom + PrototypeSpacing.md,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Mes enfants',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: PrototypeSpacing.md),
                  for (var i = 0; i < groups.length; i++) ...[
                    if (i > 0) const SizedBox(height: PrototypeSpacing.md),
                    _SchoolStudentSection(
                      group: groups[i],
                      selectedYear: studentContext.store.selectedYearForSchool(
                        groups[i].school.id,
                      ),
                      onYearSelected: (year) =>
                          studentContext.selectYearForSchool(
                        groups[i].school.id,
                        year,
                      ),
                      activeStudentId: studentContext.activeStudentId,
                      onStudentSelected: (studentId) {
                        studentContext.selectStudent(studentId);
                        Navigator.pop(context);
                      },
                    ),
                  ],
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _SchoolStudentSection extends StatelessWidget {
  const _SchoolStudentSection({
    required this.group,
    required this.selectedYear,
    required this.onYearSelected,
    required this.activeStudentId,
    required this.onStudentSelected,
  });

  final SchoolStudentGroup group;
  final String selectedYear;
  final ValueChanged<String> onYearSelected;
  final String activeStudentId;
  final ValueChanged<String> onStudentSelected;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Text(
                group.school.name,
                style: Theme.of(context).textTheme.titleSmall,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: PrototypeSpacing.sm),
            AcademicYearPicker(
              selectedYear: selectedYear,
              years: group.school.years,
              onSelected: onYearSelected,
            ),
          ],
        ),
        const SizedBox(height: PrototypeSpacing.xs),
        for (final student in group.students)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: PersonAvatar(
              initials: student.initials,
              photoUrl: student.photoUrl,
              radius: 20,
            ),
            title: Text(student.fullName),
            subtitle: Text(student.classLabel),
            trailing: activeStudentId == student.id
                ? Icon(Icons.check_circle, color: PrototypeColors.primary)
                : null,
            onTap: () => onStudentSelected(student.id),
          ),
      ],
    );
  }
}
