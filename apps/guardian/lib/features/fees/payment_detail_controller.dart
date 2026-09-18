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
    await runTask(() async {
      try {
        final row = await _schoolClient().payments.get(paymentId);
        payment(
          PaymentRecord.fromJson(
            row,
            feeLabel: systemL10n().schoolFee,
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
