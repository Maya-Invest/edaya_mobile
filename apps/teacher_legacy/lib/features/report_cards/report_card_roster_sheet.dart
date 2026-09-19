import 'package:edaya_shared/edaya_shared.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:levit_flutter/levit_flutter.dart';

import '../context/academic_year_controller.dart';
import '../../navigation/teacher_route_paths.dart';
import 'models/report_card_roster_models.dart';
import 'report_card_roster_controller.dart';

class ReportCardRosterSheet extends LScopedView<ReportCardRosterController> {
  const ReportCardRosterSheet({super.key, required this.rosterArgs});

  final ReportCardRosterArgs rosterArgs;

  @override
  ReportCardRosterController onConfigScope(LevitScope scope) {
    return scope.put(
      () => ReportCardRosterController(
        args: rosterArgs,
        getAcademicYearId: () =>
            scope.find<AcademicYearController>().selectedYearId.value,
        schoolClient: scope.find<SchoolClientFactory>(),
      ),
    );
  }

  @override
  Widget buildView(BuildContext context, ReportCardRosterController controller) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.92,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Material(
          color: Theme.of(context).scaffoldBackgroundColor,
          child: LWatch(
            () => _buildContent(context, scrollController, controller),
          ),
        );
      },
    );
  }

  Widget _buildContent(
    BuildContext context,
    ScrollController scrollController,
    ReportCardRosterController controller,
  ) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 8, 0),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      rosterArgs.classLabel,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    Text(rosterArgs.periodLabel),
                  ],
                ),
              ),
              IconButton(
                onPressed: () => context.pop(),
                icon: const Icon(Icons.close),
                tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
              ),
            ],
          ),
        ),
        Expanded(
          child: DataState(
            status: controller.dataStatus,
            errorMessage: controller.errorMessage.value,
            emptyMessage: controller.emptyMessage,
            onRetry: controller.loadRoster,
            child: RefreshIndicator(
              onRefresh: controller.loadRoster,
              child: ListView.builder(
                controller: scrollController,
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                itemCount: controller.students.value.length,
                itemBuilder: (context, index) {
                  final row = controller.students.value[index];
                  return Padding(
                    padding: EdgeInsets.only(top: index == 0 ? 0 : 8),
                    child: _ReportCardStudentTile(
                      row: row,
                      onTap: row.hasReportCard
                          ? () => _openCommentEditor(context, controller, row)
                          : null,
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _openCommentEditor(
    BuildContext context,
    ReportCardRosterController controller,
    ReportCardStudentRow row,
  ) async {
    final reportCardId = row.reportCardId;
    if (reportCardId == null) {
      return;
    }

    final saved = await context.push<bool>(
      TeacherRoutePaths.reportCardComment(
        resultId: reportCardId,
        studentId: row.studentId,
      ),
    );
    if (saved == true) {
      await controller.loadRoster();
    }
  }
}

class _ReportCardStudentTile extends StatelessWidget {
  const _ReportCardStudentTile({required this.row, this.onTap});

  final ReportCardStudentRow row;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final subtitle = row.hasReportCard
        ? _resultSubtitle(context, row)
        : context.tr.reportCardClassNoResults;

    return Card(
      child: ListTile(
        onTap: onTap,
        leading: PersonAvatar(
          name: row.studentName,
          initials: row.studentInitials ?? '?',
          photoUrl: row.photoUrl,
        ),
        title: Text(row.studentName),
        subtitle: Text(subtitle),
        trailing: row.hasReportCard
            ? Icon(
                row.hasComment ? Icons.comment : Icons.comment_outlined,
                color: row.hasComment
                    ? theme.colorScheme.primary
                    : theme.colorScheme.outline,
              )
            : null,
      ),
    );
  }

  String _resultSubtitle(BuildContext context, ReportCardStudentRow row) {
    final parts = <String>[];
    if (row.overallAverage != null) {
      parts.add(row.overallAverage!.toStringAsFixed(1));
    }
    if (row.rank != null && row.classSize != null) {
      parts.add('${row.rank}/${row.classSize}');
    }
    if (row.status != null) {
      parts.add(_statusLabel(context, row.status!));
    }
    return parts.isEmpty ? context.tr.notRecorded : parts.join(' · ');
  }

  String _statusLabel(BuildContext context, String status) {
    return switch (status) {
      'published' => context.tr.reportCardStatusPublished,
      'draft' => context.tr.reportCardStatusDraft,
      _ => status,
    };
  }
}
