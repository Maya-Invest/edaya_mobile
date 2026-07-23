import 'dart:async';

import 'package:edaya_api_client/edaya_api_client.dart' as api;
import 'package:edaya_shared/edaya_shared.dart';
import 'package:levit_flutter/levit_flutter.dart';

import 'models/payment_record.dart';

class PaymentDetailController extends LevitController
    with LevitReactiveTasksMixin {
  PaymentDetailController({
    required this.paymentId,
    required SchoolClientFactory schoolClient,
  }) : _schoolClient = schoolClient;

  final String paymentId;
  final SchoolClientFactory _schoolClient;

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
    await runTask(() async {
      try {
        final client = _schoolClient();
        final row = await client.payments.get(paymentId);
        var feeLabel = systemL10n().schoolFee;
        final studentFeeId = row['studentFeeId'] as String?;
        if (studentFeeId != null) {
          try {
            final studentFee = await client.studentFees.get(studentFeeId);
            final feeId = studentFee['feeId'] as String?;
            if (feeId != null) {
              final fee = await client.fees.get(feeId);
              feeLabel = fee['name'] as String? ?? feeLabel;
            }
          } on Object {
            // keep fallback
          }
        }
        payment(PaymentRecord.fromJson(row, feeLabel: feeLabel));
      } on api.ApiError catch (error) {
        errorMessage(systemL10n().couldNotLoadFees(error.toString()));
        payment(null);
      } on Object catch (error) {
        errorMessage(systemL10n().couldNotLoadFees(error.toString()));
        payment(null);
      }
    }, id: 'load-payment-detail');
  }
}
