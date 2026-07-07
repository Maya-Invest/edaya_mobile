import 'package:edaya_shared/edaya_shared.dart';

import 'student_fee_line.dart';

String formatMoney(double amount, String currency) {
  final formatted = amount == amount.roundToDouble()
      ? amount.toStringAsFixed(0)
      : amount.toStringAsFixed(2);
  return '$formatted $currency';
}

String formatPaymentMethod(AppLocalizations l10n, String method) {
  switch (method) {
    case 'cash':
      return l10n.paymentMethodCash;
    case 'card':
      return l10n.paymentMethodCard;
    case 'bank_transfer':
      return l10n.paymentMethodBankTransfer;
    case 'mobile_money':
      return l10n.paymentMethodMobileMoney;
    default:
      return l10n.paymentMethodOther;
  }
}

String formatFeeStatus(AppLocalizations l10n, StudentFeeStatus status) {
  switch (status) {
    case StudentFeeStatus.paid:
      return l10n.feeStatusPaid;
    case StudentFeeStatus.partial:
      return l10n.feeStatusPartiallyPaid;
    case StudentFeeStatus.overdue:
      return l10n.feeStatusOverdue;
    case StudentFeeStatus.cancelled:
      return l10n.feeStatusCancelled;
    case StudentFeeStatus.pending:
      return l10n.feeStatusDue;
  }
}
