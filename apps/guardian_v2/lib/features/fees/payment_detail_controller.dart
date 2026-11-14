import 'dart:async';

import 'package:edaya_api_client/edaya_api_client.dart' as api;
import 'package:edaya_shared/edaya_shared.dart';
import 'package:levit_flutter/levit_flutter.dart';

import 'models/payment_record.dart';
import 'models/money_amount.dart';

class PaymentDetailController extends LevitController
    with LevitReactiveTasksMixin {
  PaymentDetailController({
    required this.paymentId,
    required SchoolClientFactory schoolClient,
    required this.studentId,
    required this.academicYearId,
  }) : _schoolClient = schoolClient;

  final String paymentId;
  final SchoolClientFactory _schoolClient;
  final String? studentId;
  final String? academicYearId;

  final payment = LxVar<PaymentRecord?>(null);
  final errorMessage = LxVar('');

  @override
  void onInit() {
    super.onInit();
    autoDispose(payment);
    autoDispose(errorMessage);
    unawaited(load());
  }

  Future<void> load() async {
    if (studentId == null || academicYearId == null) return;
    await runTask(() async {
      try {
        final client = _schoolClient();
        final summary = await client.getStudentFinanceSummary({
          'studentId': studentId,
          'academicYearId': academicYearId,
        });
        final accountId = summary['accountId'];
        if (accountId is! String) return;
        final history = await client.getPaymentSettlementHistory({
          'accountId': accountId,
        });
        final row = (history['payments'] as List? ?? const [])
            .whereType<Map>()
            .where((row) => row['id'] == paymentId)
            .firstOrNull;
        if (row == null || isClosed) return;
        final charges = await client.studentCharges.listAll({
          'studentId': studentId,
          'academicYearId': academicYearId,
        });
        if (isClosed) return;
        final data = Map<String, dynamic>.from(row);
        payment(
          PaymentRecord.fromJson(
            data,
            currency: requireFinanceCurrency(summary['currency']),
            feeLabel: paymentAllocationLabel(
              data,
              {
                for (final charge in charges)
                  charge['id'] as String: charge['label'] as String? ?? '',
              },
              (history['allocations'] as List? ?? const [])
                  .whereType<Map>()
                  .toList(),
            ),
          ),
        );
      } on api.ApiError catch (error) {
        errorMessage(systemL10n().couldNotLoadFees(error.toString()));
        payment(null);
      } on Object catch (error) {
        errorMessage(systemL10n().couldNotLoadFees(error.toString()));
        payment(null);
      }
    }, id: 'load-payment-detail');
  }

  Future<DocumentJobResult> downloadReceipt() {
    final current = payment.value;
    if (current == null) {
      return Future.value(const DocumentJobResult.missing());
    }
    return downloadReadyIssuance(
      _schoolClient(),
      sourceId: current.id,
      templateKey: 'receipt.v1',
      studentId: studentId,
      academicYearId: academicYearId,
    );
  }
}
