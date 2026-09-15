import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:levit_flutter/levit_flutter.dart';

import 'package:edaya_shared/edaya_shared.dart';
import 'fees_controller.dart';
import 'models/fee_formatting.dart';
import 'models/student_charge_line.dart';

class ChargeDetailsDialog extends LScopedView<ChargeDetailsController> {
  const ChargeDetailsDialog({super.key, required this.charge});

  final StudentChargeLine charge;

  @override
  ChargeDetailsController onConfigScope(LevitScope scope) {
    return scope.put(() => ChargeDetailsController(charge: charge));
  }

  @override
  Widget buildView(BuildContext context, ChargeDetailsController controller) {
    final charge = controller.charge;
    final l10n = context.tr;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      charge.label,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  IconButton(
                    onPressed: () => context.pop(),
                    icon: const Icon(Icons.close),
                    tooltip: MaterialLocalizations.of(
                      context,
                    ).closeButtonTooltip,
                  ),
                ],
              ),
              Text(formatChargeStatus(l10n, charge.status)),
              const SizedBox(height: 16),
              _DetailRow(
                label: l10n.expected,
                value: formatMoney(charge.expectedAmount, charge.currency),
              ),
              _DetailRow(
                label: l10n.paid,
                value: formatMoney(charge.allocatedAmount, charge.currency),
              ),
              _DetailRow(
                label: l10n.remainingAmountLabel,
                value: formatMoney(charge.remainingObligation, charge.currency),
              ),
              if (charge.dueDate != null)
                _DetailRow(
                  label: l10n.date,
                  value: context.formatLongDate(charge.dueDate!),
                ),
              const SizedBox(height: 16),
              Text(
                l10n.chargeSchedule,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              if (charge.installments.isEmpty)
                Text(l10n.noInstallmentsForCharge)
              else
                for (final installment in charge.installments)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            installment.dueDate == null
                                ? installment.label
                                : l10n.installmentDue(
                                    installment.label,
                                    context.formatShortDate(
                                      installment.dueDate!,
                                    ),
                                  ),
                          ),
                        ),
                        Text(
                          formatMoney(
                            installment.expectedAmount,
                            charge.currency,
                          ),
                          style: Theme.of(context).textTheme.titleSmall
                              ?.copyWith(
                                fontFeatures: const [
                                  FontFeature.tabularFigures(),
                                ],
                              ),
                        ),
                      ],
                    ),
                  ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          Text(
            value,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}
