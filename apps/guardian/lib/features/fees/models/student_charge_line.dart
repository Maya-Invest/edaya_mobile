import 'package:edaya_shared/edaya_shared.dart';

import 'money_amount.dart';

enum ChargeStatus { pending, partial, paid, overdue, cancelled, waived }

ChargeStatus parseChargeStatus(String? value) {
  switch (value) {
    case 'paid':
      return ChargeStatus.paid;
    case 'partial':
      return ChargeStatus.partial;
    case 'overdue':
      return ChargeStatus.overdue;
    case 'cancelled':
      return ChargeStatus.cancelled;
    case 'waived':
      return ChargeStatus.waived;
    default:
      return ChargeStatus.pending;
  }
}

class ChargeInstallment {
  const ChargeInstallment({
    required this.id,
    required this.label,
    required this.expectedAmount,
    this.dueDate,
  });

  factory ChargeInstallment.fromJson(Map<String, dynamic> json) {
    return ChargeInstallment(
      id: json['id'] as String? ?? json['label'] as String? ?? '',
      label: json['label'] as String? ?? '',
      expectedAmount: parseMinorUnits(json['expectedAmount']),
      dueDate: parseApiDateTime(json['dueDate']),
    );
  }

  final String id;
  final String label;
  final int expectedAmount;
  final DateTime? dueDate;
}

class StudentChargeLine {
  const StudentChargeLine({
    required this.id,
    required this.label,
    required this.expectedAmount,
    required this.allocatedAmount,
    required this.adjustmentAmount,
    required this.waiverAmount,
    required this.currency,
    required this.status,
    this.dueDate,
    this.installments = const [],
    this.settlementCount = 0,
  });

  factory StudentChargeLine.fromJson(
    Map<String, dynamic> json, {
    int settlementCount = 0,
  }) {
    final currency = json['currency'] as String? ?? 'XOF';
    final installmentRows = json['installments'];
    return StudentChargeLine(
      id: json['id'] as String,
      label: json['label'] as String? ?? json['id'] as String,
      expectedAmount: parseMinorUnits(json['expectedAmount']),
      allocatedAmount: parseMinorUnits(json['allocatedAmount']),
      adjustmentAmount: parseMinorUnits(json['adjustmentAmount']),
      waiverAmount: parseMinorUnits(json['waiverAmount']),
      currency: currency,
      status: parseChargeStatus(json['status'] as String?),
      dueDate: parseApiDateTime(json['dueDate']),
      installments: installmentRows is List
          ? installmentRows
                .whereType<Map>()
                .map(
                  (row) => ChargeInstallment.fromJson(
                    Map<String, dynamic>.from(row),
                  ),
                )
                .toList()
          : const [],
      settlementCount: settlementCount,
    );
  }

  final String id;
  final String label;
  final int expectedAmount;
  final int allocatedAmount;
  final int adjustmentAmount;
  final int waiverAmount;
  final String currency;
  final ChargeStatus status;
  final DateTime? dueDate;
  final List<ChargeInstallment> installments;
  final int settlementCount;

  int get remainingObligation {
    if (status == ChargeStatus.cancelled) {
      return 0;
    }
    final net = expectedAmount - adjustmentAmount - waiverAmount;
    final remaining = net - allocatedAmount;
    return remaining < 0 ? 0 : remaining;
  }
}
