import 'dart:async';

import 'package:edaya_shared/edaya_shared.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:levit_flutter/levit_flutter.dart';

import 'academic_year_controller.dart';
import 'student_context_controller.dart';

class AcademicYearPickerSheet extends StatelessWidget {
  const AcademicYearPickerSheet({super.key});

  @override
  Widget build(BuildContext context) {
    return LView<AcademicYearController>(
      builder: (context, academicYear) {
        if (academicYear.years.value.isEmpty && !academicYear.isBusy.value) {
          unawaited(academicYear.loadYears());
        }

        return _AcademicYearPickerBody(academicYear: academicYear);
      },
    );
  }
}

class _AcademicYearPickerBody extends StatelessWidget {
  const _AcademicYearPickerBody({required this.academicYear});

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
                  context.tr.schoolYear,
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
                maxHeight: MediaQuery.sizeOf(context).height * 0.45,
              ),
              child: LWatch(() {
                if (academicYear.isBusy.value &&
                    academicYear.years.value.isEmpty) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: CircularProgressIndicator(),
                    ),
                  );
                }

                final error = academicYear.errorMessage.value;
                if (error.isNotEmpty && academicYear.years.value.isEmpty) {
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        error,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                      const SizedBox(height: 16),
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

                return ListView.separated(
                  shrinkWrap: true,
                  itemCount: years.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final year = years[index];
                    final yearId = year['id'] as String;
                    final yearName = year['name'] as String? ?? yearId;
                    final isActive =
                        year['isActive'] == true || year['isActive'] == 'true';
                    final isSelected = yearId == selectedId;

                    return ListTile(
                      title: Text(yearName),
                      subtitle: isActive ? Text(context.tr.activeYear) : null,
                      trailing: isSelected ? const Icon(Icons.check) : null,
                      onTap: () async {
                        await academicYear.selectYear(yearId);
                        if (!context.mounted) {
                          return;
                        }
                        await context.levit
                            .find<StudentContextController>()
                            .reloadContext();
                        if (context.mounted) {
                          context.pop();
                        }
                      },
                    );
                  },
                );
              }),
            ),
          ],
        ),
      ),
    );
  }
}
