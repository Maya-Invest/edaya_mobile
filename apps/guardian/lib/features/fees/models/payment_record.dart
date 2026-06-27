import '../../../common/utils/date_time_parse.dart';

class PaymentRecord {
  const PaymentRecord({
    required this.id,
    required this.studentFeeId,
    required this.feeLabel,
    required this.amount,
    required this.currency,
    required this.paymentDate,
    required this.method,
    required this.status,
    this.reference,
    this.notes,
  });

  factory PaymentRecord.fromJson(
    Map<String, dynamic> json, {
    required String feeLabel,
  }) {
    return PaymentRecord(
      id: json['id'] as String,
      studentFeeId: json['studentFeeId'] as String,
      feeLabel: feeLabel,
      amount: _moneyAmount(json['amount']),
      currency: json['currency'] as String? ?? 'EUR',
      paymentDate: parseApiDateTime(json['paymentDate']) ?? DateTime.now(),
      method: json['method'] as String? ?? 'other',
      status: json['status'] as String? ?? 'recorded',
      reference: json['reference'] as String?,
      notes: json['notes'] as String?,
    );
  }

  final String id;
  final String studentFeeId;
  final String feeLabel;
  final double amount;
  final String currency;
  final DateTime paymentDate;
  final String method;
  final String status;
  final String? reference;
  final String? notes;
}

double _moneyAmount(Object? value) {
  if (value is num) {
    return value.toDouble();
  }
  if (value is Map<String, dynamic>) {
    final amount = value['amount'];
    if (amount is num) {
      return amount.toDouble();
    }
  }
  return 0;
}

class FeesSummary {
  const FeesSummary({
    required this.totalExpected,
    required this.totalPaid,
    required this.totalBalance,
    required this.overdueCount,
    required this.currency,
  });

  final double totalExpected;
  final double totalPaid;
  final double totalBalance;
  final int overdueCount;
  final String currency;
}
