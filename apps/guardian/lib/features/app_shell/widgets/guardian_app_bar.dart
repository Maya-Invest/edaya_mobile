import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:levit_flutter/levit_flutter.dart';

import '../../context/academic_year_controller.dart';
import '../../context/student_context_controller.dart';

class GuardianAppBar extends StatelessWidget implements PreferredSizeWidget {
  const GuardianAppBar({super.key});

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight + 28);

  @override
  Widget build(BuildContext context) {
    return LView<StudentContextController>(
      builder: (context, studentContext) {
        return LView<AcademicYearController>(
          builder: (context, academicYear) {
            return _GuardianAppBarContent(
              studentContext: studentContext,
              academicYear: academicYear,
            );
          },
        );
      },
    );
  }
}

class _GuardianAppBarContent extends StatelessWidget
    implements PreferredSizeWidget {
  const _GuardianAppBarContent({
    required this.studentContext,
    required this.academicYear,
  });

  final StudentContextController studentContext;
  final AcademicYearController academicYear;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight + 28);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      leading: IconButton(
        tooltip: 'Account',
        icon: const Icon(Icons.account_circle_outlined),
        onPressed: () => context.push('/account'),
      ),
      title: LWatch(
        () {
          final student = studentContext.activeStudent.value;
          final classLabel = studentContext.classLabel.value;
          final isLoading = studentContext.isLoading.value;

          if (isLoading && student == null) {
            return const Text('Loading…');
          }

          if (student == null) {
            return const Text('Select a student');
          }

          final subtitle = classLabel ?? 'Not enrolled';
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                student.fullName,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              Text(
                subtitle,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          );
        },
      ),
      actions: [
        LWatch(
          () {
            final yearLabel =
                academicYear.selectedYearLabel ?? 'School year';
            return TextButton.icon(
              onPressed: () => context.push('/academic-year-picker'),
              icon: const Icon(Icons.expand_more, size: 18),
              label: Text(yearLabel),
            );
          },
        ),
        IconButton(
          tooltip: 'My students',
          icon: const Icon(Icons.people_outline),
          onPressed: () => context.push('/my-students'),
        ),
      ],
    );
  }
}

