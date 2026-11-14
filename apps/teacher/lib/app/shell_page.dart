import 'package:edaya_shared/edaya_shared.dart' hide PersonAvatar;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:levit_flutter/levit_flutter.dart';

import '../design/components/components.dart';
import '../design/spacing.dart';
import '../di/prototype_module.dart';
import '../features/context/academic_year_controller.dart';
import '../features/context/teacher_context_controller.dart';
import '../live/runtime.dart';
import '../mock/mock_store.dart';
import 'shell_controller.dart';

class PrototypeShell extends LScopedView<PrototypeShellController> {
  const PrototypeShell({super.key, required this.child});

  final Widget child;

  static const _tabs = [
    '/home',
    '/calendar',
    '/classes',
    '/evaluations',
    '/inbox',
  ];

  List<NavigationDestination> _destinations(BuildContext context) {
    final l10n = context.tr;
    return [
      NavigationDestination(
        icon: const Icon(Icons.home_outlined),
        selectedIcon: const Icon(Icons.home),
        label: l10n.navHome,
      ),
      NavigationDestination(
        icon: const Icon(Icons.calendar_month_outlined),
        selectedIcon: const Icon(Icons.calendar_month),
        label: l10n.navAgenda,
      ),
      NavigationDestination(
        icon: const Icon(Icons.groups_outlined),
        selectedIcon: const Icon(Icons.groups),
        label: l10n.navClasses,
      ),
      NavigationDestination(
        icon: const Icon(Icons.assignment_outlined),
        selectedIcon: const Icon(Icons.assignment),
        label: l10n.navEvaluationsShort,
      ),
      NavigationDestination(
        icon: const Icon(Icons.inbox_outlined),
        selectedIcon: const Icon(Icons.inbox),
        label: MediaQuery.textScalerOf(context).scale(1) > 1.3
            ? l10n.navInboxShort
            : l10n.navMessages,
        tooltip: l10n.navMessages,
      ),
    ];
  }

  int? _indexForLocation(String location) {
    if (location.startsWith('/account') || location.startsWith('/settings')) {
      return null;
    }
    if (location.startsWith('/session')) {
      return 1;
    }
    if (location.startsWith('/classes') || location.startsWith('/student')) {
      return 2;
    }
    if (location.startsWith('/evaluations') ||
        location.startsWith('/report-card')) {
      return 3;
    }
    for (var i = 0; i < _tabs.length; i++) {
      if (location.startsWith(_tabs[i])) return i;
    }
    return 0;
  }

  List<NavigationDestination> _navDestinations(
    BuildContext context, {
    required bool noneSelected,
  }) {
    final destinations = _destinations(context);
    if (!noneSelected) return destinations;
    return [
      for (final d in destinations)
        NavigationDestination(
          icon: d.icon,
          selectedIcon: d.icon,
          label: d.label,
          tooltip: d.tooltip,
        ),
    ];
  }

  bool _showChrome(String location) {
    return _tabs.any((t) => location.startsWith(t)) ||
        location.startsWith('/session') ||
        location.startsWith('/student') ||
        location.startsWith('/account') ||
        location.startsWith('/settings');
  }

  void _openHelp(BuildContext context) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Centre d\'aide')));
  }

  @override
  PrototypeShellController onConfigScope(LevitScope scope) {
    return scope.put(() => PrototypeShellController());
  }

  @override
  Widget buildView(BuildContext context, PrototypeShellController controller) {
    if (prototypeIsLive(context)) {
      return LWatch(() {
        final teacherContext = context.levit.find<TeacherContextController>();
        final academicYear = context.levit.find<AcademicYearController>();
        teacherContext.teacherName.value;
        teacherContext.teacherPhotoUrl.value;
        teacherContext.assignments.value;
        teacherContext.activeAssignmentId.value;
        teacherContext.schoolName.value;
        academicYear.selectedYearId.value;
        academicYear.years.value;
        return _shell(
          context,
          contextCard: _liveContextCard(context, teacherContext, academicYear),
        );
      });
    }

    final mockStore = context.levit.find<MockStore>();
    final bridge = context.levit.find<MockTeacherContextBridge>();
    bridge.storeTick.value;
    final assignment = mockStore.activeAssignment;
    return _shell(
      context,
      contextCard: TeacherContextCard(
        teacherName: mockStore.teacherFullName,
        teacherInitials: mockStore.teacherInitials,
        classLabel: assignment.classLabel,
        subjectLabel: assignment.subjectLabel,
        schoolName: mockStore.activeSchool.name,
        schoolYear: mockStore.selectedYear,
        photoUrl: mockStore.teacher.photoUrl,
        onSelectContext: () => _showContextSheet(context, mockStore),
      ),
    );
  }

  TeacherContextCard _liveContextCard(
    BuildContext context,
    TeacherContextController teacherContext,
    AcademicYearController academicYear,
  ) {
    final assignment = teacherContext.activeAssignment;
    return TeacherContextCard(
      teacherName:
          teacherContext.teacherName.value ?? systemL10n().teacherFallbackName,
      teacherInitials: teacherContext.teacherInitials,
      classLabel: assignment?.classLabel ?? 'Classe',
      subjectLabel: assignment == null
          ? 'Aucune affectation'
          : assignment.isHomeroom
          ? '${assignment.subjectLabel} · Titulaire'
          : assignment.subjectLabel,
      schoolName: teacherContext.schoolName.value ?? '',
      schoolYear: academicYear.selectedYearLabel ?? '',
      photoUrl: teacherContext.teacherPhotoUrl.value,
      onSelectContext: () =>
          _showLiveContextSheet(context, teacherContext, academicYear),
    );
  }

  Widget _shell(
    BuildContext context, {
    required TeacherContextCard contextCard,
  }) {
    final location = GoRouterState.of(context).uri.toString();
    final showNav = _showChrome(location);
    final index = _indexForLocation(location);

    return LayoutBuilder(
      builder: (context, constraints) {
        final useRail =
            showNav &&
            PrototypeBreakpoints.useNavigationRail(constraints.maxWidth);

        final mainColumn = ShellChrome(
          showHeader: showNav,
          header: contextCard,
          appBar: useRail ? const PrototypeAppBar() : null,
          child: child,
        );

        final noneSelected = index == null;

        if (!useRail) {
          return Scaffold(
            backgroundColor: Theme.of(context).colorScheme.surface,
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
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                              ),
                            ),
                            labelTextStyle: WidgetStateProperty.all(
                              Theme.of(context).textTheme.labelMedium?.copyWith(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                              ),
                            ),
                          )
                        : const NavigationBarThemeData(),
                    child: NavigationBar(
                      height:
                          80 +
                          40 *
                              (MediaQuery.textScalerOf(context).scale(1) - 1)
                                  .clamp(0, 1),
                      selectedIndex: index ?? 0,
                      onDestinationSelected: (i) => context.go(_tabs[i]),
                      destinations: _navDestinations(
                        context,
                        noneSelected: noneSelected,
                      ),
                    ),
                  )
                : null,
          );
        }

        return Scaffold(
          backgroundColor: Theme.of(context).colorScheme.surface,
          body: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              NavigationRail(
                backgroundColor: Theme.of(context).colorScheme.surface,
                selectedIndex: index,
                onDestinationSelected: (i) => context.go(_tabs[i]),
                labelType: NavigationRailLabelType.all,
                destinations: [
                  for (final d in _destinations(context))
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
                            tooltip: context.tr.accountTitle,
                            icon: const Icon(Icons.account_circle_outlined),
                            onPressed: () => context.go('/account'),
                          ),
                          IconButton(
                            tooltip: context.tr.help,
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
                color: Theme.of(
                  context,
                ).colorScheme.outlineVariant.withValues(alpha: 0.5),
              ),
              Expanded(child: mainColumn),
            ],
          ),
        );
      },
    );
  }

  void _showLiveContextSheet(
    BuildContext context,
    TeacherContextController teacherContext,
    AcademicYearController academicYear,
  ) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) {
        return LWatch(() {
          teacherContext.assignments.value;
          teacherContext.activeAssignmentId.value;
          academicYear.years.value;
          academicYear.selectedYearId.value;
          final years = academicYear.yearLabels;
          final selected = academicYear.selectedYearLabel ?? '';
          final assignments = teacherContext.assignments.value;
          return _ContextPickerSheet(
            schoolName: teacherContext.schoolName.value ?? '',
            yearPicker: years.isEmpty
                ? null
                : AcademicYearPicker(
                    selectedYear: selected,
                    years: years,
                    onSelected: (label) {
                      final id = academicYear.idForYearLabel(label);
                      if (id != null) {
                        academicYear.selectYear(id);
                      }
                    },
                  ),
            children: [
              if (assignments.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: PrototypeSpacing.md),
                  child: Text('Aucune affectation pour cette année.'),
                )
              else
                for (final a in assignments)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(a.classLabel),
                    subtitle: Text(
                      a.isHomeroom
                          ? '${a.subjectLabel} · Titulaire'
                          : a.subjectLabel,
                    ),
                    trailing: teacherContext.activeAssignmentId.value == a.id
                        ? Icon(
                            Icons.check_circle,
                            color: Theme.of(context).colorScheme.primary,
                          )
                        : null,
                    onTap: () {
                      teacherContext.selectAssignment(a.id);
                      Navigator.pop(context);
                    },
                  ),
            ],
          );
        });
      },
    );
  }

  void _showContextSheet(BuildContext context, MockStore store) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) {
        return ListenableBuilder(
          listenable: store,
          builder: (context, _) {
            return _ContextPickerSheet(
              schoolName: store.activeSchool.name,
              yearPicker: AcademicYearPicker(
                selectedYear: store.selectedYear,
                years: store.years,
                onSelected: store.selectYear,
              ),
              children: [
                for (final a in store.assignments)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(a.classLabel),
                    subtitle: Text(a.subjectLabel),
                    trailing: store.activeAssignmentId == a.id
                        ? Icon(
                            Icons.check_circle,
                            color: Theme.of(context).colorScheme.primary,
                          )
                        : null,
                    onTap: () {
                      store.selectAssignment(a.id);
                      Navigator.pop(context);
                    },
                  ),
              ],
            );
          },
        );
      },
    );
  }
}

class _ContextPickerSheet extends StatelessWidget {
  const _ContextPickerSheet({
    required this.schoolName,
    required this.children,
    this.yearPicker,
  });

  final String schoolName;
  final Widget? yearPicker;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: PrototypeSpacing.md,
        right: PrototypeSpacing.md,
        top: PrototypeSpacing.md,
        bottom: MediaQuery.viewInsetsOf(context).bottom + PrototypeSpacing.md,
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.75,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    schoolName,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                ?yearPicker,
              ],
            ),
            const SizedBox(height: PrototypeSpacing.md),
            Text('Mes classes', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: PrototypeSpacing.sm),
            Flexible(child: ListView(shrinkWrap: true, children: children)),
          ],
        ),
      ),
    );
  }
}
