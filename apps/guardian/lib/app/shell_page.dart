import 'package:edaya_shared/edaya_shared.dart' hide PersonAvatar;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:levit_flutter/levit_flutter.dart';

import '../design/colors.dart';
import '../design/components/components.dart';
import '../design/spacing.dart';
import '../features/context/academic_year_controller.dart';
import '../features/context/student_context_controller.dart';
import '../features/my_students/guardian_students_controller.dart';
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

  int? _indexForLocation(String location) {
    if (location.startsWith('/account') ||
        location.startsWith('/settings') ||
        location.startsWith('/child')) {
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
        location.startsWith('/settings') ||
        location.startsWith('/child');
  }

  void _openHelp(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Centre d\'aide')),
    );
  }

  @override
  PrototypeShellController onConfigScope(LevitScope scope) {
    return scope.put(() => PrototypeShellController());
  }

  @override
  Widget buildView(BuildContext context, PrototypeShellController controller) {
    final location = GoRouterState.of(context).uri.toString();
    final showNav = _showChrome(location);
    final index = _indexForLocation(location);

    final contextCard = LView<StudentContextController>(
      builder: (context, studentContext) {
        return LView<AcademicYearController>(
          builder: (context, academicYear) {
            return LWatch(() {
              final student = studentContext.activeStudent.value;
              final classLabel = studentContext.classLabel.value;
              final yearLabel = academicYear.selectedYearLabel ?? '—';
              final schoolId =
                  context.levit.find<AppSessionController>().schoolIdHeader;
              return StudentContextCard(
                studentName: student?.fullName ?? 'Sélectionnez un élève',
                studentInitials: student?.initials ?? '?',
                classLabel: classLabel ?? 'Non inscrit',
                schoolName: schoolId ?? 'École',
                schoolYear: yearLabel,
                photoUrl: student?.photoUrl,
                onOpenProfile: student == null
                    ? null
                    : () => context.go('/child'),
                onSelectStudent: () => _showApiContextSheet(context),
              );
            });
          },
        );
      },
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

  void _showApiContextSheet(BuildContext context) {
    showLevitModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return LScope(
          name: 'guardian-context-sheet-${identityHashCode(ctx)}',
          dependencyFactory: (scope) {
            scope.put(
              () => GuardianStudentsController(
                session: context.levit.find<AppSessionController>(),
                schoolClient: context.levit.find<SchoolClientFactory>(),
              ),
            );
          },
          child: const _ApiContextSheetBody(),
        );
      },
    );
  }
}

class _ApiContextSheetBody extends LView<GuardianStudentsController> {
  const _ApiContextSheetBody();

  @override
  Widget buildView(BuildContext context, GuardianStudentsController controller) {
    final studentContext = context.levit.find<StudentContextController>();
    final academicYear = context.levit.find<AcademicYearController>();

    return Padding(
      padding: EdgeInsets.only(
        left: PrototypeSpacing.md,
        right: PrototypeSpacing.md,
        top: PrototypeSpacing.md,
        bottom: MediaQuery.viewInsetsOf(context).bottom + PrototypeSpacing.md,
      ),
      child: LWatch(() {
        final students = controller.students.value;
        final yearLabel = academicYear.selectedYearLabel ?? '—';
        final years = [
          for (final y in academicYear.years.value)
            y['name'] as String? ?? y['id'] as String,
        ];
        final yearIds = [
          for (final y in academicYear.years.value) y['id'] as String,
        ];

        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Mes enfants',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: PrototypeSpacing.md),
            if (years.isNotEmpty)
              Align(
                alignment: Alignment.centerRight,
                child: AcademicYearPicker(
                  selectedYear: yearLabel,
                  years: years,
                  onSelected: (label) async {
                    final index = years.indexOf(label);
                    if (index >= 0) {
                      await academicYear.selectYear(yearIds[index]);
                    }
                  },
                ),
              ),
            const SizedBox(height: PrototypeSpacing.sm),
            if (controller.isBusy.value && students.isEmpty)
              const Padding(
                padding: EdgeInsets.all(PrototypeSpacing.lg),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (controller.errorMessage.value.isNotEmpty)
              Text(controller.errorMessage.value)
            else if (students.isEmpty)
              const Text('Aucun élève lié')
            else
              for (final student in students)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: PersonAvatar(
                    initials: student.initials,
                    photoUrl: student.photoUrl,
                    radius: 20,
                  ),
                  title: Text(student.fullName),
                  subtitle: Text(
                    studentContext.activeStudent.value?.id == student.id
                        ? (studentContext.classLabel.value ?? '')
                        : '',
                  ),
                  trailing: studentContext.activeStudent.value?.id == student.id
                      ? Icon(Icons.check_circle, color: PrototypeColors.primary)
                      : null,
                  onTap: () async {
                    await studentContext.selectStudent(student.id);
                    if (context.mounted) Navigator.pop(context);
                  },
                ),
          ],
        );
      }),
    );
  }
}
