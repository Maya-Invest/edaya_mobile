import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:levit_flutter/levit_flutter.dart';

import 'package:edaya_shared/edaya_shared.dart';
import '../context/academic_year_controller.dart';
import '../context/student_context_controller.dart';
import 'fees_controller.dart';
import 'models/payment_record.dart';
import 'widgets/fee_tiles.dart';
import 'widgets/fees_summary_card.dart';

class FeesPage extends LScopedView<FeesController> {
  const FeesPage({super.key});

  @override
  FeesController onConfigScope(LevitScope scope) {
    return scope.put(
      () => FeesController(
        studentContext: scope.find<StudentContextController>(),
        academicYear: scope.find<AcademicYearController>(),
        schoolClient: scope.find<SchoolClientFactory>(),
      ),
    );
  }

  @override
  Widget buildView(BuildContext context, FeesController controller) {
    return LWatch(() {
      final status = controller.dataStatus;

      return DataState(
        status: status,
        errorMessage: controller.errorMessage.value,
        emptyMessage: controller.emptyMessage,
        onRetry: controller.loadFeesData,
        child: RefreshIndicator(
          onRefresh: controller.loadFeesData,
          child: _FeesBody(controller: controller),
        ),
      );
    });
  }
}

class _FeesBody extends StatelessWidget {
  const _FeesBody({required this.controller});

  final FeesController controller;

  @override
  Widget build(BuildContext context) {
    final summary = controller.summary.value;
    final lines = controller.feeLines.value;
    final payments = controller.payments.value;

    if (summary == null && lines.isEmpty && payments.isEmpty) {
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
        if (summary != null) ...[
          FeesSummaryCard(summary: summary),
          const SizedBox(height: 16),
        ],
        Text(
          context.tr.feeLinesSection,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        if (lines.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(context.tr.noFeeLinesForYear),
          )
        else
          for (final line in lines) ...[
            StudentFeeTile(line: line),
            const SizedBox(height: 8),
          ],
        const SizedBox(height: 8),
        Text(
          context.tr.paymentsSection,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        if (payments.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(context.tr.noPaymentsRecordedYet),
          )
        else
          for (final payment in payments) ...[
            PaymentTile(
              payment: payment,
              onTap: () => _openPaymentDetails(context, payment),
            ),
            const SizedBox(height: 8),
          ],
      ],
    );
  }

  void _openPaymentDetails(BuildContext context, PaymentRecord payment) {
    context.push('/fees/payment-details', extra: payment);
  }
}
