import 'dart:async';

import 'package:edaya_api_client/edaya_api_client.dart' as api;
import 'package:edaya_shared/edaya_shared.dart';
import 'package:levit_flutter/levit_flutter.dart';

import 'models/student_charge_line.dart';

String frenchChargeStatus(ChargeStatus status) {
  return switch (status) {
    ChargeStatus.paid => 'Payé',
    ChargeStatus.partial => 'Partiel',
    ChargeStatus.overdue => 'En retard',
    ChargeStatus.cancelled => 'Annulé',
    ChargeStatus.waived => 'Exonéré',
    ChargeStatus.pending => 'À payer',
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

class FeeDetailController extends LevitController with LevitReactiveTasksMixin {
  FeeDetailController({
    required this.feeId,
    required SchoolClientFactory schoolClient,
    required this.studentId,
    required this.academicYearId,
    required this.schoolId,
  }) : _schoolClient = schoolClient;

  final String feeId;
  final SchoolClientFactory _schoolClient;
  final String? studentId;
  final String? academicYearId;
  final String? schoolId;

  final charge = LxVar<StudentChargeLine?>(null);
  final errorMessage = LxVar('');

  @override
  void onInit() {
    super.onInit();
    autoDispose(charge);
    autoDispose(errorMessage);
    unawaited(load());
  }

  Future<void> load() async {
    await runTask(() async {
      try {
        final row = await _schoolClient().studentCharges.get(feeId);
        charge(StudentChargeLine.fromJson(row));
      } on api.ApiError catch (error) {
        errorMessage(systemL10n().couldNotLoadFees(error.toString()));
        charge(null);
      } on Object catch (error) {
        errorMessage(systemL10n().couldNotLoadFees(error.toString()));
        charge(null);
      }
    }, id: 'load-fee-detail');
  }

  Future<DocumentJobResult> downloadInvoice() {
    final schoolId = this.schoolId;
    final studentId = this.studentId;
    final yearId = academicYearId;
    final current = charge.value;
    if (schoolId == null || studentId == null || yearId == null || current == null) {
      return Future.value(const DocumentJobResult.missing());
    }
    return downloadReadyIssuance(
      _schoolClient(),
      sourceId: studentYearAccountSourceId(
        schoolId: schoolId,
        studentId: studentId,
        academicYearId: yearId,
        currency: current.currency,
      ),
      templateKey: 'invoice.v1',
      studentId: studentId,
      academicYearId: yearId,
    );
  }
}
