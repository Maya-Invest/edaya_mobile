import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../app/formatters.dart';
import '../design/colors.dart';
import '../design/components/components.dart';
import '../design/spacing.dart';
import '../mock/mock_store.dart';

class _FeeAmountTrailing extends StatelessWidget {
  const _FeeAmountTrailing({
    required this.amount,
    required this.label,
    this.labelColor,
    this.showChevron = false,
  });

  final String amount;
  final String label;
  final Color? labelColor;
  final bool showChevron;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              amount,
              style: textTheme.titleSmall?.copyWith(
                color: PrototypeColors.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (showChevron) ...[
              const SizedBox(width: 2),
              Icon(
                Icons.chevron_right,
                size: 20,
                color: PrototypeColors.onSurfaceVariant,
              ),
            ],
          ],
        ),
        Text(
          label,
          style: textTheme.labelSmall?.copyWith(color: labelColor),
        ),
      ],
    );
  }
}

SemanticTone _feeStatusTone(String status) {
  return switch (status) {
    'En retard' => SemanticTone.error,
    'Payé' => SemanticTone.success,
    'Partiel' => SemanticTone.warning,
    _ => SemanticTone.neutral,
  };
}

class _FeeDetailSummaryCard extends StatelessWidget {
  const _FeeDetailSummaryCard({required this.fee});

  final MockFeeLine fee;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final isOverdue = fee.status == 'En retard';

    return SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              StatusChip(label: fee.status, tone: _feeStatusTone(fee.status)),
              const Spacer(),
              if (fee.dueDate != null)
                Text(
                  'Échéance ${formatDate(fee.dueDate!)}',
                  style: textTheme.labelSmall?.copyWith(
                    color: PrototypeColors.onSurfaceVariant,
                  ),
                ),
            ],
          ),
          const SizedBox(height: PrototypeSpacing.md),
          Row(
            children: [
              Expanded(
                child: SummaryMetric(
                  label: 'Attendu',
                  value: formatMoney(fee.expected, fee.currency),
                ),
              ),
              Expanded(
                child: SummaryMetric(
                  label: 'Payé',
                  value: formatMoney(fee.paid, fee.currency),
                  valueColor: fee.paid > 0 ? PrototypeColors.primary : null,
                ),
              ),
              Expanded(
                child: SummaryMetric(
                  label: 'Solde',
                  value: formatMoney(fee.balance, fee.currency),
                  valueColor: fee.balance > 0 && isOverdue
                      ? PrototypeColors.error
                      : null,
                ),
              ),
            ],
          ),
          const SizedBox(height: PrototypeSpacing.sm),
          PrototypeProgressBar(value: fee.progress),
          const SizedBox(height: PrototypeSpacing.xs),
          Text(
            '${(fee.progress * 100).round()} % réglé',
            style: textTheme.bodySmall?.copyWith(
              color: PrototypeColors.onSurfaceVariant,
            ),
          ),
          if (fee.description != null) ...[
            const SizedBox(height: PrototypeSpacing.md),
            const Divider(height: 1),
            const SizedBox(height: PrototypeSpacing.md),
            Text(
              fee.description!,
              style: textTheme.bodyMedium?.copyWith(
                color: PrototypeColors.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _InstallmentCard extends StatelessWidget {
  const _InstallmentCard({required this.installment});

  final MockFeeInstallment installment;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final isOverdue = installment.status == 'En retard';
    final isPaid = installment.isPaid;
    final tone = _feeStatusTone(installment.status);

    final icon = isPaid
        ? Icons.check_circle_outline
        : isOverdue
        ? Icons.warning_amber_rounded
        : Icons.event_outlined;
    final (iconBg, iconColor) = switch (tone) {
      SemanticTone.error => (
        PrototypeColors.errorContainer,
        PrototypeColors.error,
      ),
      SemanticTone.success => (
        PrototypeColors.primaryContainer,
        PrototypeColors.primary,
      ),
      _ => (
        PrototypeColors.primaryContainer,
        PrototypeColors.primary,
      ),
    };

    return SurfaceCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 20, color: iconColor),
          ),
          const SizedBox(width: PrototypeSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(installment.label, style: textTheme.titleSmall),
                const SizedBox(height: 4),
                Text(
                  'Échéance ${formatDate(installment.dueDate)}',
                  style: textTheme.bodySmall,
                ),
              ],
            ),
          ),
          _FeeAmountTrailing(
            amount: formatMoney(
              isPaid ? installment.amount : installment.balance,
              installment.currency,
            ),
            label: installment.status,
            labelColor: isOverdue ? PrototypeColors.error : null,
          ),
        ],
      ),
    );
  }
}

class FeesPage extends StatelessWidget {
  const FeesPage({super.key, required this.store});
  final MockStore store;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final progress = store.feeExpected == 0
            ? 0.0
            : (store.feePaid / store.feeExpected).clamp(0.0, 1.0);

        return ListView(
          padding: const EdgeInsets.all(PrototypeSpacing.md),
          children: [
            const SectionHeader(title: 'Résumé'),
            SurfaceCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: SummaryMetric(
                          label: 'Attendu',
                          value: formatMoney(store.feeExpected, 'EUR'),
                        ),
                      ),
                      Expanded(
                        child: SummaryMetric(
                          label: 'Payé',
                          value: formatMoney(store.feePaid, 'EUR'),
                        ),
                      ),
                      Expanded(
                        child: SummaryMetric(
                          label: 'Solde',
                          value: formatMoney(store.feeBalance, 'EUR'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: PrototypeSpacing.sm),
                  PrototypeProgressBar(value: progress),
                  const SizedBox(height: PrototypeSpacing.xs),
                  Text(
                    '${(progress * 100).round()} % réglé',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: PrototypeColors.onSurfaceVariant,
                    ),
                  ),
                  if (store.overdueFeeCount > 0) ...[
                    const SizedBox(height: PrototypeSpacing.sm),
                    Text(
                      '${store.overdueFeeCount} ligne de frais en retard',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: PrototypeColors.error,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: PrototypeSpacing.xl),
            const SectionHeader(title: 'Lignes de frais'),
            for (final fee in store.feeLines) ...[
              ListRow(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: fee.status == 'En retard'
                        ? PrototypeColors.errorContainer
                        : PrototypeColors.primaryContainer,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.receipt_long_outlined,
                    size: 20,
                    color: fee.status == 'En retard'
                        ? PrototypeColors.error
                        : PrototypeColors.primary,
                  ),
                ),
                title: fee.label,
                subtitle:
                    'Échéance ${fee.dueDate != null ? formatDate(fee.dueDate!) : '—'} · '
                    '${fee.paymentCount} paiement${fee.paymentCount > 1 ? 's' : ''}',
                trailing: _FeeAmountTrailing(
                  amount: formatMoney(fee.balance, fee.currency),
                  label: fee.status,
                  labelColor: fee.status == 'En retard'
                      ? PrototypeColors.error
                      : null,
                  showChevron: true,
                ),
                onTap: () => context.push('/fee/${fee.id}'),
              ),
              const SizedBox(height: PrototypeSpacing.xs),
            ],
            const SizedBox(height: PrototypeSpacing.xl),
            const SectionHeader(title: 'Paiements'),
            for (final payment in store.payments) ...[
              ListRow(
                title: payment.method,
                subtitle: '${payment.feeLabel} · ${formatDate(payment.date)}',
                trailing: _FeeAmountTrailing(
                  amount: formatMoney(payment.amount, payment.currency),
                  label: 'Reçu',
                  showChevron: true,
                ),
                onTap: () => context.push('/payment/${payment.id}'),
              ),
              const SizedBox(height: PrototypeSpacing.xs),
            ],
          ],
        );
      },
    );
  }
}

class FeeDetailPage extends StatelessWidget {
  const FeeDetailPage({super.key, required this.store, required this.feeId});

  final MockStore store;
  final String feeId;

  @override
  Widget build(BuildContext context) {
    final fee = store.feeById(feeId);
    if (fee == null) {
      return PrototypeDetailScaffold(
        fallbackRoute: '/fees',
        title: 'Détail des frais',
        body: const EmptyState(title: 'Frais introuvables'),
      );
    }

    final installments = store.installmentsForFee(feeId);
    final payments = store.paymentsForFee(feeId);

    return PrototypeDetailScaffold(
      fallbackRoute: '/fees',
      title: fee.label,
      body: ListView(
        padding: const EdgeInsets.all(PrototypeSpacing.md),
        children: [
          _FeeDetailSummaryCard(fee: fee),
          if (installments.isNotEmpty) ...[
            const SizedBox(height: PrototypeSpacing.xl),
            const SectionHeader(title: 'Échéances'),
            for (final installment in installments) ...[
              _InstallmentCard(installment: installment),
              const SizedBox(height: PrototypeSpacing.xs),
            ],
          ],
          if (payments.isNotEmpty) ...[
            const SizedBox(height: PrototypeSpacing.xl),
            const SectionHeader(title: 'Paiements'),
            for (final payment in payments) ...[
              ListRow(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: PrototypeColors.primaryContainer,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.payments_outlined,
                    size: 20,
                    color: PrototypeColors.primary,
                  ),
                ),
                title: payment.method,
                subtitle: formatDate(payment.date),
                trailing: _FeeAmountTrailing(
                  amount: formatMoney(payment.amount, payment.currency),
                  label: 'Reçu',
                  showChevron: true,
                ),
                onTap: () => context.push('/payment/${payment.id}'),
              ),
              const SizedBox(height: PrototypeSpacing.xs),
            ],
          ],
        ],
      ),
    );
  }
}

class PaymentDetailPage extends StatelessWidget {
  const PaymentDetailPage({super.key, required this.store, required this.paymentId});
  final MockStore store;
  final String paymentId;

  @override
  Widget build(BuildContext context) {
    final payment = store.paymentById(paymentId);
    if (payment == null) {
      return PrototypeDetailScaffold(
        fallbackRoute: '/fees',
        title: 'Reçu de paiement',
        body: const EmptyState(title: 'Paiement introuvable'),
      );
    }
    return PrototypeDetailScaffold(
      fallbackRoute: '/fees',
      title: 'Reçu de paiement',
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
  }
}

class InboxPage extends StatelessWidget {
  const InboxPage({super.key, required this.store});
  final MockStore store;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Text(
                '${store.unreadCount} non lu(s)',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.all(PrototypeSpacing.md),
                itemCount: store.messages.length,
                separatorBuilder: (_, _) => const SizedBox(height: PrototypeSpacing.xs),
                itemBuilder: (context, i) {
                  final m = store.messages[i];
                  return ListRow(
                    title: m.title,
                    subtitle: m.body.length > 80 ? '${m.body.substring(0, 80)}…' : m.body,
                    unread: !m.read,
                    badge: m.read ? 'Lu · ${formatDate(m.sentAt)}' : 'Nouveau',
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: m.read
                            ? const Color(0xFFF1F5F9)
                            : PrototypeColors.primaryContainer,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        Icons.mail_outline,
                        size: 20,
                        color: m.read ? PrototypeColors.onSurfaceVariant : PrototypeColors.primary,
                      ),
                    ),
                    onTap: () => context.push('/message/${m.id}'),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}

class MessageDetailPage extends StatefulWidget {
  const MessageDetailPage({super.key, required this.store, required this.messageId});
  final MockStore store;
  final String messageId;

  @override
  State<MessageDetailPage> createState() => _MessageDetailPageState();
}

class _MessageDetailPageState extends State<MessageDetailPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      widget.store.markMessageRead(widget.messageId);
    });
  }

  @override
  Widget build(BuildContext context) {
    final message = widget.store.messageById(widget.messageId);
    if (message == null) {
      return PrototypeDetailScaffold(
        fallbackRoute: '/inbox',
        title: 'Message',
        body: const EmptyState(title: 'Message introuvable'),
      );
    }
    return PrototypeDetailScaffold(
      fallbackRoute: '/inbox',
      title: 'Message',
      body: ListView(
        padding: const EdgeInsets.all(PrototypeSpacing.md),
        children: [
          SurfaceCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(message.title, style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: PrototypeSpacing.sm),
                StatusChip(
                  label: formatDate(message.sentAt),
                  tone: SemanticTone.neutral,
                ),
                const SizedBox(height: PrototypeSpacing.md),
                Text(message.body, style: Theme.of(context).textTheme.bodyLarge),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
