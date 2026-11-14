import 'package:edaya_shared/edaya_shared.dart' hide PersonAvatar;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:levit_flutter/levit_flutter.dart';

import '../design/components/components.dart';
import '../design/spacing.dart';
import '../di/prototype_module.dart';
import '../features/account/account_controller.dart';
import '../features/calendar/calendar_page.dart';
import '../features/context/academic_year_controller.dart';
import '../features/context/student_context_controller.dart';
import '../features/fees/fees_page.dart';
import '../features/home/home_page.dart';
import '../features/inbox/inbox_page.dart';
import '../features/my_students/guardian_students_controller.dart';
import '../features/my_students/linked_student.dart';
import '../features/scolarite/results_page.dart';
import '../live/runtime.dart';
import '../mock/mock_store.dart';
import 'shell_controller.dart';
import 'shell_tabs.dart';

class PrototypeShell extends LScopedView<PrototypeShellController> {
  const PrototypeShell({super.key, required this.child});

  final Widget child;

  List<NavigationDestination> _destinations(BuildContext context) => [
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
      label: MediaQuery.textScalerOf(context).scale(1) > 1.3
          ? context.tr.navInboxShort
          : context.tr.navMessages,
      tooltip: context.tr.navMessages,
    ),
  ];

  static const _hubs = [
    HomePage(),
    CalendarPage(),
    ResultsPage(),
    FeesPage(),
    InboxPage(),
  ];

  @override
  PrototypeShellController onConfigScope(LevitScope scope) {
    if (prototypeRuntimeIsLive(scope)) {
      scope.put(
        () => AccountController(
          session: scope.find<AppSessionController>(),
          studentContext: scope.find<StudentContextController>(),
        ),
      );
    }
    return scope.put(() => PrototypeShellController());
  }

  @override
  Widget buildView(BuildContext context, PrototypeShellController controller) {
    final path = GoRouterState.of(context).uri.path;
    controller.rememberFromLocation(path);
    final tabIndex = controller.lastTabIndex;
    final hubPath = controller.lastHubPath;
    final overlay = !GuardianShellTabs.isHub(path);

    final header = prototypeIsLive(context)
        ? _ShellHeaderCards(
            onSelectStudent: () => _showApiContextSheet(context),
          )
        : _MockShellHeaderCards(
            onSelectStudent: () => _showMockContextSheet(context),
          );

    return GuardianShellScope(
      hubPath: hubPath,
      tabIndex: tabIndex,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final useRail = PrototypeBreakpoints.useNavigationRail(
            constraints.maxWidth,
          );
          final useDrawer = PrototypeBreakpoints.useDetailDrawer(
            constraints.maxWidth,
          );

          final hubBody = Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              header,
              Expanded(
                child: DetailDrawerScaffold(
                  master: IndexedStack(index: tabIndex, children: _hubs),
                  detail: child,
                  hasSelection: overlay && useDrawer,
                  listPath: hubPath,
                ),
              ),
            ],
          );

          final Widget shell;
          if (!useRail) {
            shell = Scaffold(
              backgroundColor: Theme.of(context).colorScheme.surface,
              body: SafeArea(bottom: false, child: hubBody),
              bottomNavigationBar: NavigationBar(
                height:
                    80 +
                    40 *
                        (MediaQuery.textScalerOf(context).scale(1) - 1).clamp(
                          0,
                          1,
                        ),
                selectedIndex: tabIndex,
                onDestinationSelected: (i) =>
                    context.go(GuardianShellTabs.hubPathForIndex(i)),
                destinations: _destinations(context),
              ),
            );
          } else {
            shell = Scaffold(
              backgroundColor: Theme.of(context).colorScheme.surface,
              body: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  NavigationRail(
                    backgroundColor: Theme.of(context).colorScheme.surface,
                    selectedIndex: tabIndex,
                    onDestinationSelected: (i) =>
                        context.go(GuardianShellTabs.hubPathForIndex(i)),
                    labelType: NavigationRailLabelType.all,
                    destinations: [
                      for (final d in _destinations(context))
                        NavigationRailDestination(
                          icon: d.icon,
                          selectedIcon: d.selectedIcon,
                          label: Text(d.label),
                        ),
                    ],
                  ),
                  VerticalDivider(
                    width: 1,
                    color: Theme.of(
                      context,
                    ).colorScheme.outlineVariant.withValues(alpha: 0.5),
                  ),
                  Expanded(child: SafeArea(bottom: false, child: hubBody)),
                ],
              ),
            );
          }

          if (!overlay || useDrawer) return shell;

          return Stack(
            fit: StackFit.expand,
            children: [
              Offstage(child: shell),
              Positioned.fill(
                child: Material(
                  color: Theme.of(context).colorScheme.surface,
                  child: child,
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showMockContextSheet(BuildContext context) {
    showLevitModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return const _MockContextSheetBody();
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

class _MockShellHeaderCards extends StatelessWidget {
  const _MockShellHeaderCards({required this.onSelectStudent});

  final VoidCallback onSelectStudent;

  @override
  Widget build(BuildContext context) {
    final bridge = context.levit.find<MockGuardianContextBridge>();
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        PrototypeSpacing.md,
        PrototypeSpacing.sm,
        PrototypeSpacing.md,
        PrototypeSpacing.sm,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: LWatch(() {
              bridge.storeTick.value;
              final store = bridge.store;
              final student = store.activeStudent;
              return StudentContextCard(
                studentName: student.fullName,
                studentInitials: student.initials,
                classLabel: student.classLabel,
                schoolName: store.activeSchool.name,
                schoolYear: store.selectedYear,
                photoUrl: student.photoUrl,
                onSelectStudent: onSelectStudent,
              );
            }),
          ),
          const SizedBox(width: PrototypeSpacing.sm),
          LWatch(() {
            bridge.storeTick.value;
            return ParentAccountCard(
              initials: bridge.store.guardianInitials,
              onTap: () => context.push('/account'),
            );
          }),
        ],
      ),
    );
  }
}

class _MockContextSheetBody extends StatelessWidget {
  const _MockContextSheetBody();

  @override
  Widget build(BuildContext context) {
    final store = context.levit.find<MockStore>();
    final bridge = context.levit.find<MockGuardianContextBridge>();
    return SafeArea(
      child: Padding(
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
          child: LWatch(() {
            bridge.storeTick.value;
            final groups = store.studentsBySchool;
            return SingleChildScrollView(
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
                    if (i > 0) const Divider(height: PrototypeSpacing.lg),
                    _MockSchoolChildrenGroup(group: groups[i], store: store),
                  ],
                ],
              ),
            );
          }),
        ),
      ),
    );
  }
}

class _MockSchoolChildrenGroup extends StatelessWidget {
  const _MockSchoolChildrenGroup({required this.group, required this.store});

  final SchoolStudentGroup group;
  final MockStore store;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SchoolGroupHeader(
          schoolName: group.school.name,
          selectedYear: store.selectedYearForSchool(group.school.id),
          years: store.schoolYearsFor(group.school.id),
          onYearSelected: (year) =>
              store.selectYearForSchool(group.school.id, year),
        ),
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
            trailing: store.activeStudentId == student.id
                ? Icon(
                    Icons.check_circle,
                    color: Theme.of(context).colorScheme.primary,
                  )
                : null,
            onTap: () {
              store.selectStudent(student.id);
              Navigator.pop(context);
            },
          ),
      ],
    );
  }
}

class _ShellHeaderCards extends StatelessWidget {
  const _ShellHeaderCards({required this.onSelectStudent});

  final VoidCallback onSelectStudent;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        PrototypeSpacing.md,
        PrototypeSpacing.sm,
        PrototypeSpacing.md,
        PrototypeSpacing.sm,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: LView<StudentContextController>(
              builder: (context, studentContext) {
                return LView<AcademicYearController>(
                  builder: (context, academicYear) {
                    return LWatch(() {
                      final student = studentContext.activeStudent.value;
                      final classLabel = studentContext.classLabel.value;
                      final yearLabel = academicYear.selectedYearLabel ?? '—';
                      final schoolId = context.levit
                          .find<AppSessionController>()
                          .schoolIdHeader;
                      final schoolName =
                          studentContext.schoolName.value ??
                          schoolId ??
                          'École';
                      return StudentContextCard(
                        studentName:
                            student?.fullName ?? 'Sélectionnez un élève',
                        studentInitials: student?.initials ?? '?',
                        classLabel: classLabel ?? 'Non inscrit',
                        schoolName: schoolName,
                        schoolYear: yearLabel,
                        photoUrl: student?.photoUrl,
                        onOpenProfile: student == null
                            ? null
                            : () => context.push('/child'),
                        onSelectStudent: onSelectStudent,
                      );
                    });
                  },
                );
              },
            ),
          ),
          const SizedBox(width: PrototypeSpacing.sm),
          LView<AccountController>(
            builder: (context, account) {
              return LWatch(() {
                account.session.user.value;
                return ParentAccountCard(
                  initials: account.initials,
                  onTap: () => context.push('/account'),
                );
              });
            },
          ),
        ],
      ),
    );
  }
}

class _ApiContextSheetBody extends LView<GuardianStudentsController> {
  const _ApiContextSheetBody();

  @override
  Widget buildView(
    BuildContext context,
    GuardianStudentsController controller,
  ) {
    final studentContext = context.levit.find<StudentContextController>();
    final academicYear = context.levit.find<AcademicYearController>();

    return SafeArea(
      child: Padding(
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
          child: LWatch(() {
            final groups = controller.groups.value;
            final students = controller.students.value;
            academicYear.selectedYearId.value;
            academicYear.selectedYearBySchool.value;
            academicYear.yearsBySchool.value;
            academicYear.years.value;
            studentContext.activeStudent.value;
            studentContext.classLabel.value;

            return SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Mes enfants',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: PrototypeSpacing.md),
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
                    for (var i = 0; i < groups.length; i++) ...[
                      if (i > 0) ...[
                        const Divider(height: PrototypeSpacing.lg),
                      ],
                      _SchoolChildrenGroup(
                        group: groups[i],
                        academicYear: academicYear,
                        studentContext: studentContext,
                      ),
                    ],
                ],
              ),
            );
          }),
        ),
      ),
    );
  }
}

class _SchoolChildrenGroup extends StatelessWidget {
  const _SchoolChildrenGroup({
    required this.group,
    required this.academicYear,
    required this.studentContext,
  });

  final GuardianSchoolGroup group;
  final AcademicYearController academicYear;
  final StudentContextController studentContext;

  @override
  Widget build(BuildContext context) {
    final schoolYears = academicYear.yearsForSchool(group.schoolId);
    final yearLabels = [
      for (final year in schoolYears)
        year['name'] as String? ?? year['id'] as String,
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SchoolGroupHeader(
          schoolName: group.schoolName,
          selectedYear:
              academicYear.selectedYearLabelForSchool(group.schoolId) ?? '—',
          years: yearLabels,
          onYearSelected: yearLabels.isEmpty
              ? null
              : (label) async {
                  for (final year in schoolYears) {
                    final yearLabel =
                        year['name'] as String? ?? year['id'] as String;
                    if (yearLabel != label) continue;
                    await academicYear.selectYearForSchool(
                      group.schoolId,
                      year['id'] as String,
                    );
                    return;
                  }
                },
        ),
        for (final student in group.students)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: PersonAvatar(
              initials: student.initials,
              photoUrl: student.photoUrl,
              radius: 20,
            ),
            title: Text(student.fullName),
            subtitle:
                studentContext.activeStudent.value?.id == student.id &&
                    (studentContext.classLabel.value ?? '').isNotEmpty
                ? Text(studentContext.classLabel.value!)
                : null,
            trailing: studentContext.activeStudent.value?.id == student.id
                ? Icon(
                    Icons.check_circle,
                    color: Theme.of(context).colorScheme.primary,
                  )
                : null,
            onTap: () async {
              await studentContext.selectStudent(student.id);
              if (context.mounted) Navigator.pop(context);
            },
          ),
      ],
    );
  }
}

class _SchoolGroupHeader extends StatelessWidget {
  const _SchoolGroupHeader({
    required this.schoolName,
    required this.selectedYear,
    required this.years,
    this.onYearSelected,
  });

  final String schoolName;
  final String selectedYear;
  final List<String> years;
  final ValueChanged<String>? onYearSelected;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            schoolName,
            style: Theme.of(context).textTheme.titleMedium,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (onYearSelected != null && years.isNotEmpty)
          AcademicYearPicker(
            selectedYear: selectedYear,
            years: years,
            onSelected: onYearSelected!,
          ),
      ],
    );
  }
}
