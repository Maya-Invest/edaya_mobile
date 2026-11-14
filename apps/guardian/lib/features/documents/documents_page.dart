import 'package:edaya_shared/edaya_shared.dart';
import 'package:flutter/material.dart';
import 'package:levit_flutter/levit_flutter.dart';

import '../context/academic_year_controller.dart';
import '../context/student_context_controller.dart';
import 'documents_controller.dart';

class DocumentsPage extends LScopedView<DocumentsController> {
  const DocumentsPage({super.key});

  @override
  DocumentsController onConfigScope(LevitScope scope) {
    return scope.put(
      () => DocumentsController(
        studentContext: scope.find<StudentContextController>(),
        academicYear: scope.find<AcademicYearController>(),
        schoolClient: scope.find<SchoolClientFactory>(),
      ),
    );
  }

  @override
  Widget buildView(BuildContext context, DocumentsController controller) {
    return LWatch(
      () => DataState(
        status: controller.dataStatus,
        errorMessage: controller.errorMessage.value,
        emptyMessage: controller.emptyMessage,
        onRetry: controller.loadDocuments,
        child: RefreshIndicator(
          onRefresh: controller.loadDocuments,
          child: _DocumentsBody(controller: controller),
        ),
      ),
    );
  }
}

class _DocumentsBody extends StatelessWidget {
  const _DocumentsBody({required this.controller});

  final DocumentsController controller;

  @override
  Widget build(BuildContext context) {
    final items = controller.issuances.value;
    if (items.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          const SizedBox(height: 48),
          Center(child: Text(controller.emptyMessage)),
        ],
      );
    }

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          context.tr.documentsDownloadRecall,
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 12),
        for (final issuance in items) ...[
          Card(
            child: ListTile(
              title: Text(issuance.title ?? issuance.templateKey),
              subtitle: Text(
                [
                  documentStatusLabel(context.tr, issuance.status),
                  if (issuance.number != null) issuance.number,
                  if (issuance.failureCode != null) issuance.failureCode,
                ].join(' · '),
              ),
              trailing: issuance.isDownloadable
                  ? IconButton(
                      tooltip: context.tr.documentsDownload,
                      icon: const Icon(Icons.download_outlined),
                      onPressed: () async {
                        try {
                          final result = await controller.download(issuance);
                          if (context.mounted) {
                            showDocumentJobSnackBar(context, result);
                          }
                        } on Object catch (error) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  mutationFailureMessage(
                                    error,
                                    context.tr.documentsOpenFailed,
                                  ),
                                ),
                              ),
                            );
                          }
                        }
                      },
                    )
                  : null,
            ),
          ),
          const SizedBox(height: 8),
        ],
      ],
    );
  }
}
