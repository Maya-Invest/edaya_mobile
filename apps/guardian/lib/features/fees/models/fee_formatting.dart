import 'dart:math' as math;
import 'package:intl/intl.dart';

import 'package:edaya_shared/edaya_shared.dart';

import 'money_amount.dart';
import 'student_charge_line.dart';

String formatMoney(int minorUnits, String currency, [String? locale]) {
  final digits = currencyFractionDigits(currency);
  final major = minorUnits / math.pow(10, digits);
  return NumberFormat.currency(locale: locale ?? Intl.getCurrentLocale(), name: currency,
      symbol: currency == 'EUR' ? '€' : currency, decimalDigits: digits).format(major);
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

String formatPaymentKind(AppLocalizations l10n, String kind) {
  switch (kind) {
    case 'disbursement':
      return l10n.paymentKindDisbursement;
    default:
      return l10n.paymentKindReceipt;
  }
}

String formatChargeStatus(AppLocalizations l10n, ChargeStatus status) {
  switch (status) {
    case ChargeStatus.paid:
      return l10n.feeStatusPaid;
    case ChargeStatus.partial:
      return l10n.feeStatusPartiallyPaid;
    case ChargeStatus.overdue:
      return l10n.feeStatusOverdue;
    case ChargeStatus.cancelled:
      return l10n.feeStatusCancelled;
    case ChargeStatus.waived:
      return l10n.feeStatusWaived;
    case ChargeStatus.pending:
      return l10n.feeStatusDue;
  }
}
