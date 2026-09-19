import 'dart:async';

import 'package:edaya_api_client/edaya_api_client.dart' as api;
import 'package:levit_flutter/levit_flutter.dart';

import 'package:edaya_shared/edaya_shared.dart';
import '../../common/utils/entity_filters.dart';
import '../context/academic_year_controller.dart';
import '../context/student_context_controller.dart';
import 'models/payment_record.dart';
import 'models/student_charge_line.dart';

class FeesController extends LevitController with LevitReactiveTasksMixin {
  FeesController({
    required StudentContextController studentContext,
    required AcademicYearController academicYear,
    required SchoolClientFactory schoolClient,
  }) : _studentContext = studentContext,
       _academicYear = academicYear,
       _schoolClient = schoolClient;

  final StudentContextController _studentContext;
  final AcademicYearController _academicYear;
  final SchoolClientFactory _schoolClient;

  final charges = LxVar<List<StudentChargeLine>>(const []);
  final payments = LxVar<List<PaymentRecord>>(const []);
  final summary = LxVar<FeesSummary?>(null);
  final errorMessage = LxVar('');

  @override
  void onInit() {
    super.onInit();
    autoDispose(charges);
    autoDispose(payments);
    autoDispose(summary);
    autoDispose(errorMessage);

    for (final subscription in [
      _studentContext.classGroupId.stream,
      _studentContext.activeStudent.stream,
      _studentContext.isEnrolled.stream,
      _academicYear.selectedYearId.stream,
    ]) {
      autoDispose(subscription.listen((_) => unawaited(loadFeesData())));
    }
    autoDispose(
      _studentContext.isLoading.stream.listen((loading) {
        if (!loading) {
          unawaited(loadFeesData());
        }
      }),
    );

    unawaited(loadFeesData());
  }

  DataStatus get dataStatus {
    if (isBusy.value &&
        charges.value.isEmpty &&
        payments.value.isEmpty &&
        summary.value == null) {
      return DataStatus.loading;
    }
    if (errorMessage.value.isNotEmpty &&
        charges.value.isEmpty &&
        payments.value.isEmpty &&
        summary.value == null) {
      return DataStatus.error;
    }
    if (_studentContext.activeStudent.value == null) {
      return DataStatus.empty;
    }
    return DataStatus.ready;
  }

  String get emptyMessage {
    final l10n = systemL10n();
    if (_studentContext.activeStudent.value == null) {
      return l10n.selectStudentToViewFees;
    }
    if (charges.value.isEmpty && payments.value.isEmpty) {
      return l10n.noFeesOrPaymentsForYear;
    }
    return l10n.nothingToShowYet;
  }

  Future<void> loadFeesData() async {
    final studentId = _studentContext.activeStudentId;
    final yearId = _academicYear.selectedYearId.value;

    if (studentId == null || yearId == null) {
      charges(const []);
      payments(const []);
      summary(null);
      errorMessage('');
      return;
    }

    errorMessage('');
    await runTask(() async {
      try {
        final client = _schoolClient();
        final financeQuery = {'studentId': studentId, 'academicYearId': yearId};
        final results = await Future.wait([
          client.getStudentFinanceSummary(financeQuery),
          client.studentCharges.list(
            studentChargesForStudent(
              studentId: studentId,
              academicYearId: yearId,
            ),
          ),
        ]);
        final financeSummary = results[0] as Map<String, dynamic>;
        final chargeRows = (results[1] as List<Map<String, dynamic>>)
            .where((row) => row['status'] != 'cancelled')
            .toList();

        final accountId = financeSummary['accountId'] as String?;
        Map<String, dynamic> history = const {};
        if (accountId != null && accountId.isNotEmpty) {
          try {
            history = await client.getPaymentSettlementHistory({
              'accountId': accountId,
            });
          } on Object {
            history = const {};
          }
        }

        final allocationRows =
            (history['allocations'] as List?)?.whereType<Map>().toList() ??
            const [];
        var paymentRows = ((history['payments'] as List?) ?? const [])
            .whereType<Map>()
            .map((row) => Map<String, dynamic>.from(row))
            .toList();
        if (paymentRows.isEmpty) {
          try {
            paymentRows = await client.payments.list({
              'studentId': studentId,
              'academicYearId': yearId,
            });
          } on Object {
            paymentRows = const [];
          }
        }
        final parsedCharges = chargeRows.map((row) {
          final id = row['id'] as String;
          return StudentChargeLine.fromJson(
            row,
            settlementCount: _settleCountForCharge(id, allocationRows),
          );
        }).toList()..sort(_compareCharges);

        final chargeLabelById = {
          for (final charge in parsedCharges) charge.id: charge.label,
        };
        final currency =
            financeSummary['currency'] as String? ??
            (parsedCharges.isNotEmpty
                ? parsedCharges.first.currency
                : history['currency'] as String? ?? 'XOF');
        final parsedPayments = paymentRows.map((json) {
          return PaymentRecord.fromJson(
            json,
            feeLabel: _paymentLabel(json, chargeLabelById, allocationRows),
            currency: currency,
          );
        }).toList()..sort((a, b) => b.paymentDate.compareTo(a.paymentDate));

        charges(parsedCharges);
        payments(parsedPayments);
        summary(FeesSummary.fromJson(financeSummary));
      } on api.ApiError catch (error) {
        errorMessage(systemL10n().couldNotLoadFees(error.toString()));
        charges(const []);
        payments(const []);
        summary(null);
      } on Object catch (error) {
        errorMessage(systemL10n().couldNotLoadFees(error.toString()));
        charges(const []);
        payments(const []);
        summary(null);
      }
    });
  }

  int get overdueCount =>
      charges.value.where((line) => line.status == ChargeStatus.overdue).length;

  int get totalExpected =>
      charges.value.fold<int>(0, (sum, line) => sum + line.expectedAmount);

  int get totalPaid =>
      charges.value.fold<int>(0, (sum, line) => sum + line.allocatedAmount);

  int get totalBalance =>
      charges.value.fold<int>(0, (sum, line) => sum + line.remainingObligation);

  Future<DocumentJobResult> downloadStatement({required String? schoolId}) {
    final studentId = _studentContext.activeStudentId;
    final yearId = _academicYear.selectedYearId.value;
    final currency = summary.value?.currency ??
        (charges.value.isNotEmpty ? charges.value.first.currency : 'XOF');
    if (schoolId == null || studentId == null || yearId == null) {
      return Future.value(const DocumentJobResult.missing());
    }
    return downloadReadyIssuance(
      _schoolClient(),
      sourceId: studentYearAccountSourceId(
        schoolId: schoolId,
        studentId: studentId,
        academicYearId: yearId,
        currency: currency,
      ),
      templateKey: 'account-statement.v1',
      studentId: studentId,
      academicYearId: yearId,
    );
  }

  int _settleCountForCharge(String chargeId, List<Map> allocations) {
    return allocations
        .where(
          (row) =>
              row['chargeId'] == chargeId &&
              (row['kind'] == null || row['kind'] == 'settle'),
        )
        .length;
  }

  String _paymentLabel(
    Map<String, dynamic> payment,
    Map<String, String> chargeLabelById,
    List<Map> allocations,
  ) {
    final paymentId = payment['id'];
    final labels = <String>{};
    for (final allocation in allocations) {
      if (allocation['causedByPaymentId'] != paymentId) {
        continue;
      }
      if (allocation['kind'] == 'reverse') {
        continue;
      }
      final chargeId = allocation['chargeId'] as String?;
      final label = chargeId == null ? null : chargeLabelById[chargeId];
      if (label != null && label.isNotEmpty) {
        labels.add(label);
      }
    }
    if (labels.isNotEmpty) {
      return labels.join(', ');
    }
    return payment['kind'] == 'disbursement'
        ? systemL10n().paymentKindDisbursement
        : systemL10n().paymentKindReceipt;
  }

  int _compareCharges(StudentChargeLine a, StudentChargeLine b) {
    final aDate = a.dueDate;
    final bDate = b.dueDate;
    if (aDate == null && bDate == null) {
      return a.label.compareTo(b.label);
    }
    if (aDate == null) {
      return 1;
    }
    if (bDate == null) {
      return -1;
    }
    final byDate = aDate.compareTo(bDate);
    if (byDate != 0) {
      return byDate;
    }
    return a.id.compareTo(b.id);
  }
}

class PaymentDetailsController extends LevitController {
  PaymentDetailsController({
    required this.payment,
    required SchoolClientFactory schoolClient,
    required this.studentId,
    required this.academicYearId,
  }) : _schoolClient = schoolClient;

  final PaymentRecord payment;
  final SchoolClientFactory _schoolClient;
  final String? studentId;
  final String? academicYearId;

  Future<DocumentJobResult> downloadReceipt() {
    return downloadReadyIssuance(
      _schoolClient(),
      sourceId: payment.id,
      templateKey: 'receipt.v1',
      studentId: studentId,
      academicYearId: academicYearId,
    );
  }
}

class ChargeDetailsController extends LevitController {
  ChargeDetailsController({
    required this.charge,
    required SchoolClientFactory schoolClient,
    required this.studentId,
    required this.academicYearId,
    required this.schoolId,
  }) : _schoolClient = schoolClient;

  final StudentChargeLine charge;
  final SchoolClientFactory _schoolClient;
  final String? studentId;
  final String? academicYearId;
  final String? schoolId;

  Future<DocumentJobResult> downloadInvoice() {
    final schoolId = this.schoolId;
    final studentId = this.studentId;
    final yearId = academicYearId;
    if (schoolId == null || studentId == null || yearId == null) {
      return Future.value(const DocumentJobResult.missing());
    }
    return downloadReadyIssuance(
      _schoolClient(),
      sourceId: studentYearAccountSourceId(
        schoolId: schoolId,
        studentId: studentId,
        academicYearId: yearId,
        currency: charge.currency,
      ),
      templateKey: 'invoice.v1',
      studentId: studentId,
      academicYearId: yearId,
    );
  }
}
