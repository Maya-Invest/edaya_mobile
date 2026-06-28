import 'package:edaya_shared/edaya_shared.dart';

enum StudentFeeStatus { pending, partial, paid, overdue, cancelled }

StudentFeeStatus parseStudentFeeStatus(String? value) {
  switch (value) {
    case 'paid':
      return StudentFeeStatus.paid;
    case 'partial':
      return StudentFeeStatus.partial;
    case 'overdue':
      return StudentFeeStatus.overdue;
    case 'cancelled':
      return StudentFeeStatus.cancelled;
    default:
      return StudentFeeStatus.pending;
  }
}

class StudentFeeLine {
  const StudentFeeLine({
    required this.id,
    required this.feeId,
    required this.label,
    required this.expectedAmount,
    required this.paidAmount,
    required this.currency,
    required this.status,
    this.dueDate,
    this.paymentCount = 0,
  });

  factory StudentFeeLine.fromJson(
    Map<String, dynamic> json, {
    required String label,
    int paymentCount = 0,
  }) {
    return StudentFeeLine(
      id: json['id'] as String,
      feeId: json['feeId'] as String,
      label: label,
      expectedAmount: _moneyAmount(json['expectedAmount']),
      paidAmount: _moneyAmount(json['paidAmount']),
      currency: json['currency'] as String? ?? 'EUR',
      status: parseStudentFeeStatus(json['status'] as String?),
      dueDate: parseApiDateTime(json['dueDate']),
      paymentCount: paymentCount,
    );
  }

  final String id;
  final String feeId;
  final String label;
  final double expectedAmount;
  final double paidAmount;
  final String currency;
  final StudentFeeStatus status;
  final DateTime? dueDate;
  final int paymentCount;

  double get balance => (expectedAmount - paidAmount).clamp(0, expectedAmount);

  bool get isSettled =>
      status == StudentFeeStatus.paid || balance <= 0;
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
