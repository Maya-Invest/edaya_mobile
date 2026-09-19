import 'package:edaya_shared/edaya_shared.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:levit_flutter/levit_flutter.dart';

import '../../context/academic_year_controller.dart';
import '../../context/student_context_controller.dart';

class GuardianAppBar extends StatelessWidget implements PreferredSizeWidget {
  const GuardianAppBar({super.key, this.textScale = 1});

  final double textScale;

  @override
  Size get preferredSize => Size.fromHeight(88 * textScale + 48);

  @override
  Widget build(BuildContext context) {
    return LView<StudentContextController>(
      builder: (context, studentContext) {
        return LView<AcademicYearController>(
          builder: (context, academicYear) {
            return _GuardianAppBarContent(
              textScale: textScale,
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
    required this.textScale,
    required this.studentContext,
    required this.academicYear,
  });

  final double textScale;
  final StudentContextController studentContext;
  final AcademicYearController academicYear;

  @override
  Size get preferredSize => Size.fromHeight(88 * textScale + 48);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      toolbarHeight: 88 * textScale,
      leading: IconButton(
        tooltip: context.tr.tooltipAccount,
        icon: const Icon(Icons.account_circle_outlined),
        onPressed: () => context.push('/account'),
      ),
      title: LWatch(() {
        final student = studentContext.activeStudent.value;
        final classLabel = studentContext.classLabel.value;
        final isLoading = studentContext.isLoading.value;

        if (isLoading && student == null) {
          return Text(context.tr.loading);
        }

        if (student == null) {
          return Text(context.tr.selectAStudent);
        }

        final subtitle = classLabel ?? context.tr.notEnrolled;
        return Row(
          children: [
            PersonAvatar(
              name: student.fullName,
              initials: student.initials,
              photoUrl: student.photoUrl,
              radius: 18,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Tooltip(
                    message: student.fullName,
                    child: Text(
                      student.fullName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  Tooltip(
                    message: subtitle,
                    child: Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      }),
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(48),
        child: Align(
          alignment: Alignment.centerRight,
          child: LWatch(() {
            final yearLabel =
                academicYear.selectedYearLabel ?? context.tr.schoolYear;
            return TextButton.icon(
              onPressed: () => context.push('/academic-year-picker'),
              icon: const Icon(Icons.expand_more, size: 18),
              label: Text(yearLabel),
            );
          }),
        ),
      ),
      actions: [
        IconButton(
          tooltip: context.tr.tooltipDocuments,
          icon: const Icon(Icons.description_outlined),
          onPressed: () => context.push('/documents'),
        ),
        IconButton(
          tooltip: context.tr.tooltipMyStudents,
          icon: const Icon(Icons.people_outline),
          onPressed: () => context.push('/my-students'),
        ),
      ],
    );
  }
}
