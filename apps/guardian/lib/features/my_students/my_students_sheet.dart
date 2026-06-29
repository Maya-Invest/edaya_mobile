import 'package:edaya_shared/edaya_shared.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:levit_flutter/levit_flutter.dart';

import '../../access/app_runtime.dart';
import 'guardian_students_controller.dart';
import 'linked_student.dart';

class MyStudentsSheet extends LScopedView<GuardianStudentsController> {
  const MyStudentsSheet({super.key});

  @override
  GuardianStudentsController onConfigScope(LevitScope scope) {
    return scope.put(() => GuardianStudentsController(session: AppRuntime.session));
  }

  @override
  Widget buildView(
    BuildContext context,
    GuardianStudentsController controller,
  ) {
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
                  context.tr.myStudents,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => context.pop(),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.sizeOf(context).height * 0.55,
              ),
              child: LWatch(
                () {
                  if (controller.isBusy.value && controller.students.value.isEmpty) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final error = controller.errorMessage.value;
                  if (error.isNotEmpty) {
                    return Text(
                      error,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    );
                  }

                  final students = controller.students.value;
                  if (students.isEmpty) {
                    return Text(context.tr.noLinkedStudentsFound);
                  }

                  final activeStudentId =
                      AppRuntime.studentContext.activeStudent.value?.id;

                  return ListView.separated(
                    shrinkWrap: true,
                    itemCount: students.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final student = students[index];
                      final isSelected = student.id == activeStudentId;
                      return _StudentRow(
                        student: student,
                        isSelected: isSelected,
                        onSelect: () async {
                          await AppRuntime.studentContext.selectStudent(
                            student.id,
                          );
                          if (context.mounted) {
                            context.pop();
                          }
                        },
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StudentRow extends StatelessWidget {
  const _StudentRow({
    required this.student,
    required this.isSelected,
    required this.onSelect,
  });

  final LinkedStudent student;
  final bool isSelected;
  final VoidCallback onSelect;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        leading: PersonAvatar(
          name: student.fullName,
          initials: student.initials,
          photoUrl: student.photoUrl,
        ),
        title: Text(student.fullName),
        subtitle: Text(
          [
            if (student.matricule != null)
              context.tr.matriculeLabel(student.matricule!),
            context.tr.statusLabel(student.status),
          ].join(' · '),
        ),
        trailing: isSelected ? const Icon(Icons.check_circle) : null,
        onTap: onSelect,
      ),
    );
  }
}
