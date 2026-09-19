import 'dart:async';

import 'package:edaya_shared/edaya_shared.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:levit_flutter/levit_flutter.dart';

import 'academic_year_controller.dart';
import 'teacher_context_controller.dart';

class ClassFilterSheet extends StatelessWidget {
  const ClassFilterSheet({super.key});

  @override
  Widget build(BuildContext context) {
    return LView<TeacherContextController>(
      builder: (context, teacherContext) {
        return LView<AcademicYearController>(
          builder: (context, academicYear) {
            if (academicYear.years.value.isEmpty &&
                !academicYear.isBusy.value) {
              unawaited(academicYear.loadYears());
            }

            return _ClassFilterBody(
              teacherContext: teacherContext,
              academicYear: academicYear,
            );
          },
        );
      },
    );
  }
}

class _ClassFilterBody extends StatelessWidget {
  const _ClassFilterBody({
    required this.teacherContext,
    required this.academicYear,
  });

  final TeacherContextController teacherContext;
  final AcademicYearController academicYear;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Text(
                  context.tr.filterTitle,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => context.pop(),
                  icon: const Icon(Icons.close),
                  tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
                ),
              ],
            ),
            const SizedBox(height: 8),
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.sizeOf(context).height * 0.7,
              ),
              child: ListView(
                shrinkWrap: true,
                children: [
                  Text(
                    context.tr.schoolYear,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 4),
                  _SchoolYearSection(
                    academicYear: academicYear,
                    teacherContext: teacherContext,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    context.tr.classLabel,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 4),
                  LWatch(() {
                    final classes = teacherContext.assignedClasses.value;
                    final selected = teacherContext.classFilterId.value;

                    return Column(
                      children: [
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(context.tr.allClasses),
                          trailing: selected == null
                              ? const Icon(Icons.check)
                              : null,
                          onTap: () async {
                            await teacherContext.selectClassFilter(null);
                            if (context.mounted) {
                              context.pop();
                            }
                          },
                        ),
                        for (final assigned in classes)
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(assigned.label),
                            trailing: selected == assigned.id
                                ? const Icon(Icons.check)
                                : null,
                            onTap: () async {
                              await teacherContext.selectClassFilter(
                                assigned.id,
                              );
                              if (context.mounted) {
                                context.pop();
                              }
                            },
                          ),
                      ],
                    );
                  }),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SchoolYearSection extends StatelessWidget {
  const _SchoolYearSection({
    required this.academicYear,
    required this.teacherContext,
  });

  final AcademicYearController academicYear;
  final TeacherContextController teacherContext;

  @override
  Widget build(BuildContext context) {
    return LWatch(() {
      if (academicYear.isBusy.value && academicYear.years.value.isEmpty) {
        return const Padding(
          padding: EdgeInsets.symmetric(vertical: 12),
          child: Center(child: CircularProgressIndicator()),
        );
      }

      final error = academicYear.errorMessage.value;
      if (error.isNotEmpty && academicYear.years.value.isEmpty) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              error,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: academicYear.loadYears,
              child: Text(context.tr.retry),
            ),
          ],
        );
      }

      final years = academicYear.years.value;
      final selectedId = academicYear.selectedYearId.value;

      if (years.isEmpty) {
        return Text(context.tr.noAcademicYearsAvailable);
      }

      return Column(
        children: [
          for (final year in years)
            Builder(
              builder: (context) {
                final yearId = year['id'] as String;
                final yearName = year['name'] as String? ?? yearId;
                final isActive =
                    year['isActive'] == true || year['isActive'] == 'true';
                final isSelected = yearId == selectedId;

                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(yearName),
                  subtitle: isActive ? Text(context.tr.activeYear) : null,
                  trailing: isSelected ? const Icon(Icons.check) : null,
                  onTap: () async {
                    await academicYear.selectYear(yearId);
                    await teacherContext.reloadContext();
                  },
                );
              },
            ),
        ],
      );
    });
  }
}
