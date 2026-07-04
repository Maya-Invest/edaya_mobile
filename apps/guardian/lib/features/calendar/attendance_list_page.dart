import 'package:flutter/material.dart';
import 'package:levit_flutter/levit_flutter.dart';

import 'package:edaya_shared/edaya_shared.dart';
import '../context/student_context_controller.dart';
import 'calendar_controller.dart';

class AttendanceListPage extends LScopedView<AttendanceListController> {
  const AttendanceListPage({super.key});

  @override
  AttendanceListController onConfigScope(LevitScope scope) {
    return scope.put(
      () => AttendanceListController(
        studentContext: scope.find<StudentContextController>(),
        schoolClient: scope.find<SchoolClientFactory>(),
      ),
    );
  }

  @override
  Widget buildView(
    BuildContext context,
    AttendanceListController controller,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
          child: Row(
            children: [
              const BackButton(),
              Text(
                context.tr.allAttendance,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ],
          ),
        ),
        Expanded(
          child: LWatch(
            () {
              if (controller.isBusy.value && controller.records.value.isEmpty) {
                return const DataState(
                  status: DataStatus.loading,
                  child: SizedBox.shrink(),
                );
              }

              if (controller.errorMessage.value.isNotEmpty &&
                  controller.records.value.isEmpty) {
                return DataState(
                  status: DataStatus.error,
                  errorMessage: controller.errorMessage.value,
                  onRetry: controller.loadAttendance,
                  child: const SizedBox.shrink(),
                );
              }

              final records = controller.records.value;
              if (records.isEmpty) {
                return DataState(
                  status: DataStatus.empty,
                  emptyMessage: context.tr.noAttendanceRecordsForStudent,
                  child: const SizedBox.shrink(),
                );
              }

              final titles = controller.sessionTitles.value;
              return RefreshIndicator(
                onRefresh: controller.loadAttendance,
                child: ListView.separated(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(16),
                  itemCount: records.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final record = records[index];
                    final sessionTitle =
                        titles[record.occurrenceId] ?? record.occurrenceId;

                    return Card(
                      child: ListTile(
                        title: Text(sessionTitle),
                        subtitle: Text(
                          [
                            context.formatLongDate(record.date),
                            record.status,
                            if (record.reason != null) record.reason!,
                          ].join(' · '),
                        ),
                      ),
                    );
                  },
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
