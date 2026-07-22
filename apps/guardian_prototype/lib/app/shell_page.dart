import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../design/colors.dart';
import '../design/components/components.dart';
import '../design/spacing.dart';
import '../mock/mock_store.dart';

class PrototypeShell extends StatelessWidget {
  const PrototypeShell({super.key, required this.store, required this.child});

  final MockStore store;
  final Widget child;

  static const _tabs = ['/home', '/calendar', '/scolarite', '/fees', '/inbox'];

  int _indexForLocation(String location) {
    for (var i = 0; i < _tabs.length; i++) {
      if (location.startsWith(_tabs[i])) return i;
    }
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).uri.toString();
    final showNav = _tabs.any((t) => location.startsWith(t));
    final index = _indexForLocation(location);

    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final student = store.activeStudent;
        final school = store.activeSchool;
        return Scaffold(
          backgroundColor: PrototypeColors.background,
          appBar: showNav
              ? PrototypeAppBar(
                  onProfileTap: () => context.push('/account'),
                  onHelpTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Centre d\'aide — prototype')),
                    );
                  },
                )
              : null,
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (showNav)
                StudentContextCard(
                  studentName: student.fullName,
                  studentInitials: student.initials,
                  classLabel: student.classLabel,
                  schoolName: school.name,
                  schoolYear: store.selectedYear,
                  photoUrl: student.photoUrl,
                  onSelectStudent: () => _showContextSheet(context),
                ),
              Expanded(child: child),
            ],
          ),
          bottomNavigationBar: showNav
              ? NavigationBar(
                  selectedIndex: index,
                  onDestinationSelected: (i) => context.go(_tabs[i]),
                  destinations: const [
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
                  ],
                )
              : null,
        );
      },
    );
  }

  void _showContextSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => ListenableBuilder(
        listenable: store,
        builder: (context, _) {
          final groups = store.studentsBySchool;
          return Padding(
            padding: EdgeInsets.only(
              left: PrototypeSpacing.md,
              right: PrototypeSpacing.md,
              top: PrototypeSpacing.md,
              bottom: MediaQuery.viewInsetsOf(context).bottom + PrototypeSpacing.md,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Mes enfants', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: PrototypeSpacing.md),
                for (var i = 0; i < groups.length; i++) ...[
                  if (i > 0) const SizedBox(height: PrototypeSpacing.md),
                  _SchoolStudentSection(
                    group: groups[i],
                    selectedYear: store.selectedYearForSchool(groups[i].school.id),
                    onYearSelected: (year) =>
                        store.selectYearForSchool(groups[i].school.id, year),
                    activeStudentId: store.activeStudentId,
                    onStudentSelected: (studentId) {
                      store.selectStudent(studentId);
                      Navigator.pop(context);
                    },
                  ),
                ],
              ],
            ),
          );
        },
      ),
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
