import 'student_fee_line.dart';

String formatMoney(double amount, String currency) {
  final formatted = amount == amount.roundToDouble()
      ? amount.toStringAsFixed(0)
      : amount.toStringAsFixed(2);
  return '$formatted $currency';
}

String formatPaymentMethod(String method) {
  switch (method) {
    case 'cash':
      return 'Cash';
    case 'card':
      return 'Card';
    case 'bank_transfer':
      return 'Bank transfer';
    case 'mobile_money':
      return 'Mobile money';
    default:
      return 'Other';
  }
}

String formatFeeStatus(StudentFeeStatus status) {
  switch (status) {
    case StudentFeeStatus.paid:
      return 'Paid';
    case StudentFeeStatus.partial:
      return 'Partially paid';
    case StudentFeeStatus.overdue:
      return 'Overdue';
    case StudentFeeStatus.cancelled:
      return 'Cancelled';
    case StudentFeeStatus.pending:
      return 'Due';
  }
}
