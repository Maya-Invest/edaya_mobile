import 'dart:async';

import 'package:edaya_api_client/edaya_api_client.dart' as api;
import 'package:edaya_shared/edaya_shared.dart';
import 'package:levit_flutter/levit_flutter.dart';

import 'models/payment_record.dart';
import 'models/student_fee_line.dart';

class FeeInstallment {
  const FeeInstallment({
    required this.id,
    required this.label,
    required this.amount,
    required this.paid,
    required this.currency,
    required this.dueDate,
    required this.status,
  });

  final String id;
  final String label;
  final double amount;
  final double paid;
  final String currency;
  final DateTime dueDate;
  final String status;

  double get balance => (amount - paid).clamp(0, amount);
  double get progress => amount == 0 ? 0 : (paid / amount).clamp(0, 1);
  bool get isPaid => paid >= amount;
}

String frenchFeeStatus(StudentFeeStatus status) {
  return switch (status) {
    StudentFeeStatus.paid => 'Payé',
    StudentFeeStatus.partial => 'Partiel',
    StudentFeeStatus.overdue => 'En retard',
    StudentFeeStatus.cancelled => 'Annulé',
    StudentFeeStatus.pending => 'À payer',
  };
}

String frenchPaymentMethod(String method) {
  return switch (method) {
    'cash' => 'Espèces',
    'card' => 'Carte',
    'bank_transfer' => 'Virement',
    'mobile_money' => 'Mobile money',
    _ => 'Autre',
  };
}

/// Loads one student fee line, embedded installments, and related payments.
class FeeDetailController extends LevitController with LevitReactiveTasksMixin {
  FeeDetailController({
    required this.feeId,
    required SchoolClientFactory schoolClient,
  }) : _schoolClient = schoolClient;

  final String feeId;
  final SchoolClientFactory _schoolClient;

  final feeLine = LxVar<StudentFeeLine?>(null);
  final installments = LxVar<List<FeeInstallment>>(const []);
  final payments = LxVar<List<PaymentRecord>>(const []);
  final errorMessage = LxVar('');

  @override
  void onInit() {
    super.onInit();
    autoDispose(feeLine);
    autoDispose(installments);
    autoDispose(payments);
    autoDispose(errorMessage);
    unawaited(load());
  }

  Future<void> load() async {
    await runTask(() async {
      try {
        final client = _schoolClient();
        final row = await client.studentFees.get(feeId);
        String label = systemL10n().schoolFee;
        final catalogFeeId = row['feeId'] as String?;
        if (catalogFeeId != null) {
          try {
            final fee = await client.fees.get(catalogFeeId);
            label = fee['name'] as String? ?? label;
          } on Object {
            // keep fallback
          }
        }

        final paymentRows = await client.payments.list({
          'studentFeeId': feeId,
        });
        final recorded = paymentRows
            .where((p) => p['status'] == 'recorded')
            .toList();
        final parsedPayments =
            recorded
                .map((p) => PaymentRecord.fromJson(p, feeLabel: label))
                .toList()
              ..sort((a, b) => b.paymentDate.compareTo(a.paymentDate));

        feeLine(
          StudentFeeLine.fromJson(
            row,
            label: label,
            paymentCount: parsedPayments.length,
          ),
        );
        payments(parsedPayments);
        installments(
          _parseInstallments(
            row,
            currency: row['currency'] as String? ?? 'EUR',
            totalPaid: _money(row['paidAmount']),
          ),
        );
      } on api.ApiError catch (error) {
        errorMessage(systemL10n().couldNotLoadFees(error.toString()));
        feeLine(null);
        installments(const []);
        payments(const []);
      } on Object catch (error) {
        errorMessage(systemL10n().couldNotLoadFees(error.toString()));
        feeLine(null);
        installments(const []);
        payments(const []);
      }
    }, id: 'load-fee-detail');
  }

  List<FeeInstallment> _parseInstallments(
    Map<String, dynamic> row, {
    required String currency,
    required double totalPaid,
  }) {
    final raw = row['installments'];
    if (raw is! List || raw.isEmpty) {
      final due = parseApiDateTime(row['dueDate']);
      if (due == null) return const [];
      final expected = _money(row['expectedAmount']);
      final paid = totalPaid.clamp(0.0, expected).toDouble();
      final status = paid >= expected
          ? 'Payé'
          : (due.isBefore(DateTime.now()) && paid < expected)
          ? 'En retard'
          : paid > 0
          ? 'Partiel'
          : 'À payer';
      return [
        FeeInstallment(
          id: '${row['id']}-due',
          label: 'Échéance',
          amount: expected,
          paid: paid,
          currency: currency,
          dueDate: due,
          status: status,
        ),
      ];
    }

    var remainingPaid = totalPaid;
    final result = <FeeInstallment>[];
    for (final item in raw) {
      if (item is! Map<String, dynamic>) continue;
      final amount = _money(item['expectedAmount']);
      final paid = remainingPaid.clamp(0.0, amount).toDouble();
      remainingPaid = (remainingPaid - paid).clamp(0.0, double.infinity).toDouble();
      final due =
          parseApiDateTime(item['dueDate']) ??
          parseApiDateTime(row['dueDate']) ??
          DateTime.now();
      final status = paid >= amount
          ? 'Payé'
          : (due.isBefore(DateTime.now()) && paid < amount)
          ? 'En retard'
          : paid > 0
          ? 'Partiel'
          : 'À payer';
      result.add(
        FeeInstallment(
          id: item['id'] as String? ?? '${row['id']}-${result.length}',
          label: item['label'] as String? ?? 'Échéance',
          amount: amount,
          paid: paid,
          currency: currency,
          dueDate: due,
          status: status,
        ),
      );
    }
    return result;
  }
}

double _money(Object? value) {
  if (value is num) return value.toDouble();
  if (value is Map<String, dynamic>) {
    final amount = value['amount'];
    if (amount is num) return amount.toDouble();
  }
  return 0;
}
