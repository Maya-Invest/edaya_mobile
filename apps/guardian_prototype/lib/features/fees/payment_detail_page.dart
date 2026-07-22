import 'package:flutter/material.dart';
import 'package:levit_flutter/levit_flutter.dart';

import '../../app/formatters.dart';
import '../../design/colors.dart';
import '../../design/components/components.dart';
import '../../design/spacing.dart';
import '../../mock/mock_store.dart';
import 'payment_detail_controller.dart';

class PaymentDetailPage extends LScopedView<PaymentDetailController> {
  const PaymentDetailPage({super.key, required this.paymentId});

  final String paymentId;

  @override
  PaymentDetailController onConfigScope(LevitScope scope) {
    return scope.put(
      () => PaymentDetailController(
        scope.find<MockStore>(),
        paymentId: paymentId,
      ),
    );
  }

  @override
  Widget buildView(BuildContext context, PaymentDetailController controller) {
    return LWatch(() {
      controller.storeTick.value;
      final store = controller.store;
      final embedded = PrototypeBreakpoints.detailDrawerActive(context);
      final payment = store.paymentById(controller.paymentId);
      if (payment == null) {
        return PrototypeDetailScaffold(
          fallbackRoute: '/fees',
          title: 'Reçu de paiement',
          embedded: embedded,
          body: const EmptyState(title: 'Paiement introuvable'),
        );
      }
      return PrototypeDetailScaffold(
        fallbackRoute: '/fees',
        title: 'Reçu de paiement',
        embedded: embedded,
        body: ListView(
          padding: const EdgeInsets.all(PrototypeSpacing.md),
          children: [
            SurfaceCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          'Montant',
                          style: Theme.of(context).textTheme.labelSmall,
                        ),
                      ),
                      Text(
                        formatDate(payment.date),
                        style: Theme.of(context).textTheme.labelSmall,
                      ),
                    ],
                  ),
                  const SizedBox(height: PrototypeSpacing.xs),
                  Text(
                    formatMoney(payment.amount, payment.currency),
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: PrototypeColors.primary,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const Divider(height: PrototypeSpacing.xl),
                  SummaryMetric(label: 'Frais', value: payment.feeLabel),
                  const SizedBox(height: PrototypeSpacing.sm),
                  SummaryMetric(label: 'Mode', value: payment.method),
                ],
              ),
            ),
          ],
        ),
      );
    });
  }
}
