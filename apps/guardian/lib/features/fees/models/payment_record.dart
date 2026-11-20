import 'package:edaya_shared/edaya_shared.dart';

import 'money_amount.dart';

class PaymentRecord {
  const PaymentRecord({
    required this.id,
    required this.feeLabel,
    required this.amount,
    required this.currency,
    required this.paymentDate,
    required this.method,
    required this.status,
    this.kind = 'receipt',
    this.reference,
    this.notes,
  });

  factory PaymentRecord.fromJson(
    Map<String, dynamic> json, {
    required String feeLabel,
    String? currency,
  }) {
    final amount = json['amount'];
    final embeddedCurrency = amount is Map ? amount['currency'] : null;
    final recordCurrency = requireFinanceCurrency(
      json['currency'] ?? embeddedCurrency ?? currency,
    );
    if (currency != null && currency != recordCurrency) {
      throw const FormatException(
        'Payment currency does not match the school currency',
      );
    }
    return PaymentRecord(
      id: json['id'] as String,
      feeLabel: feeLabel,
      amount: parseMinorUnits(json['amount']),
      currency: recordCurrency,
      paymentDate: parseApiDateTime(json['paymentDate']) ?? DateTime.now(),
      method: json['method'] as String? ?? 'other',
      status: json['status'] as String? ?? 'recorded',
      kind: json['kind'] as String? ?? 'receipt',
      reference: json['reference'] as String?,
      notes: json['notes'] as String?,
    );
  }

  final String id;
  final String feeLabel;
  final int amount;
  final String currency;
  final DateTime paymentDate;
  final String method;
  final String status;
  final String kind;
  final String? reference;
  final String? notes;
}

class FeesSummary {
  const FeesSummary({
    required this.available,
    required this.outstanding,
    required this.overdue,
    required this.currency,
  });

  factory FeesSummary.fromJson(Map<String, dynamic> json) {
    return FeesSummary(
      available: parseMinorUnits(json['available']),
      outstanding: parseMinorUnits(json['outstanding']),
      overdue: parseMinorUnits(json['overdue']),
      currency: requireFinanceCurrency(json['currency']),
    );
  }

  final int available;
  final int outstanding;
  final int overdue;
  final String currency;
}

String paymentAllocationLabel(
  Map<String, dynamic> payment,
  Map<String, String> chargeLabelById,
  List<Map> allocations,
) {
  final paymentId = payment['id'];
  final labels = <String>{};
  for (final allocation in allocations) {
    if (allocation['causedByPaymentId'] != paymentId) {
      continue;
    }
    if (allocation['kind'] == 'reverse') {
      continue;
    }
    final chargeId = allocation['chargeId'] as String?;
    final label = chargeId == null ? null : chargeLabelById[chargeId];
    if (label != null && label.isNotEmpty) {
      labels.add(label);
    }
  }
  return paymentDisplayLabel(payment['kind'], labels);
}

String paymentDisplayLabel(Object? kind, Iterable<String> labels) {
  if (labels.isNotEmpty) {
    return labels.join(', ');
  }
  return kind == 'disbursement'
      ? systemL10n().paymentKindDisbursement
      : systemL10n().paymentKindReceipt;
}
