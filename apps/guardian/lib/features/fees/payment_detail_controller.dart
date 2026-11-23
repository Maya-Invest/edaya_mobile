import 'dart:async';

import 'package:edaya_api_client/edaya_api_client.dart'
    show GeneratedSchoolClientQueries;
import 'package:edaya_shared/edaya_shared.dart';
import 'package:levit_flutter/levit_flutter.dart';

import '../context/academic_year_controller.dart';
import '../context/student_context_controller.dart';
import 'models/payment_record.dart';

class PaymentDetailController extends LevitController
    with LevitReactiveTasksMixin {
  PaymentDetailController({
    required this.paymentId,
    required SchoolClientFactory schoolClient,
    required this.students,
    required this.year,
  }) : _schoolClient = schoolClient;

  final String paymentId;
  final SchoolClientFactory _schoolClient;
  final StudentContextController students;
  final AcademicYearController year;
  GuardianPupilSelection? _selection;
  int _generation = 0;
  Completer<void>? _abort;

  @override
  void onClose() {
    ++_generation;
    _abort?.complete();
    super.onClose();
  }

  final payment = LxVar<PaymentRecord?>(null);
  final errorMessage = LxVar('');

  @override
  void onInit() {
    super.onInit();
    autoDispose(payment);
    autoDispose(errorMessage);
    for (final stream in [
      students.activeStudent.stream,
      students.isLoading.stream,
      year.selectedYearId.stream,
    ]) {
      autoDispose(stream.listen((_) => unawaited(_loadSelection())));
    }
    unawaited(_loadSelection());
  }

  Future<void> _loadSelection() async {
    final selection = students.verifiedSelection;
    if (isClosed || selection == _selection) return;
    _selection = selection;
    final generation = ++_generation;
    _abort?.complete();
    _abort = null;
    payment(null);
    errorMessage('');
    if (selection == null) return;
    final abort = _abort = Completer<void>();
    bool current() =>
        !isClosed &&
        generation == _generation &&
        selection == students.verifiedSelection;
    await runTask(() async {
      try {
        final data = await _schoolClient().getGuardianPaymentDetail({
          'studentId': selection.studentId,
          'academicYearId': selection.academicYearId,
          'paymentId': paymentId,
        }, abortTrigger: abort.future);
        if (!current()) return;
        final row = data['payment'] as Map<String, dynamic>?;
        if (row == null) return;
        if (row['id'] != paymentId) {
          throw const FormatException('Unexpected payment ID');
        }
        payment(
          PaymentRecord.fromJson(
            row,
            feeLabel: paymentDisplayLabel(
              row['kind'],
              (row['chargeLabels'] as List).cast<String>(),
            ),
          ),
        );
      } on Object catch (error) {
        if (!current()) return;
        errorMessage(systemL10n().couldNotLoadFees(error.toString()));
        payment(null);
      }
    }, id: 'load-payment-detail:$generation');
  }

  Future<DocumentJobResult> downloadReceipt() {
    final current = payment.value;
    final selection = students.verifiedSelection;
    if (current == null || selection == null || selection != _selection) {
      return Future.value(const DocumentJobResult.missing());
    }
    return downloadReadyIssuance(
      _schoolClient(),
      sourceId: current.id,
      templateKey: 'receipt.v1',
      studentId: selection.studentId,
      academicYearId: selection.academicYearId,
    );
  }
}
