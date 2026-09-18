import 'package:edaya_shared/edaya_shared.dart' hide PersonAvatar;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:levit_flutter/levit_flutter.dart';

import '../design/colors.dart';
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
      icon: Icon(Icons.groups_outlined),
      selectedIcon: Icon(Icons.groups),
      label: 'Classes',
    ),
    NavigationDestination(
      icon: Icon(Icons.assignment_outlined),
      selectedIcon: Icon(Icons.assignment),
      label: 'Évaluations',
    ),
    NavigationDestination(
      icon: Icon(Icons.inbox_outlined),
      selectedIcon: Icon(Icons.inbox),
      label: 'Messages',
    ),
  ];

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

  void _showLiveContextSheet(
    BuildContext context,
    TeacherContextController teacherContext,
    AcademicYearController academicYear,
  ) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return LWatch(() {
          teacherContext.assignments.value;
          teacherContext.activeAssignmentId.value;
          academicYear.years.value;
          academicYear.selectedYearId.value;
          final years = academicYear.yearLabels;
          final selected = academicYear.selectedYearLabel ?? '';
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
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        teacherContext.schoolName.value ?? '',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                    if (years.isNotEmpty)
                      AcademicYearPicker(
                        selectedYear: selected,
                        years: years,
                        onSelected: (label) {
                          final id = academicYear.idForYearLabel(label);
                          if (id != null) {
                            academicYear.selectYear(id);
                          }
                        },
                      ),
                  ],
                ),
                const SizedBox(height: PrototypeSpacing.md),
                Text(
                  'Mes classes',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: PrototypeSpacing.sm),
                if (teacherContext.assignments.value.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(
                      vertical: PrototypeSpacing.md,
                    ),
                    child: Text('Aucune affectation pour cette année.'),
                  ),
                for (final a in teacherContext.assignments.value)
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
                            color: PrototypeColors.primary,
                          )
                        : null,
                    onTap: () {
                      teacherContext.selectAssignment(a.id);
                      Navigator.pop(context);
                    },
                  ),
              ],
            ),
          );
        });
      },
    );
  }

  void _showContextSheet(BuildContext context, MockStore store) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return ListenableBuilder(
          listenable: store,
          builder: (context, _) {
            return Padding(
              padding: EdgeInsets.only(
                left: PrototypeSpacing.md,
                right: PrototypeSpacing.md,
                top: PrototypeSpacing.md,
                bottom:
                    MediaQuery.viewInsetsOf(context).bottom +
                    PrototypeSpacing.md,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          store.activeSchool.name,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                      ),
                      AcademicYearPicker(
                        selectedYear: store.selectedYear,
                        years: store.years,
                        onSelected: store.selectYear,
                      ),
                    ],
                  ),
                  const SizedBox(height: PrototypeSpacing.md),
                  Text(
                    'Mes classes',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: PrototypeSpacing.sm),
                  for (final a in store.assignments)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(a.classLabel),
                      subtitle: Text(a.subjectLabel),
                      trailing: store.activeAssignmentId == a.id
                          ? Icon(
                              Icons.check_circle,
                              color: PrototypeColors.primary,
                            )
                          : null,
                      onTap: () {
                        store.selectAssignment(a.id);
                        Navigator.pop(context);
                      },
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
