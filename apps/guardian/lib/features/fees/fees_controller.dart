import 'dart:async';

import 'package:edaya_api_client/edaya_api_client.dart' as api;
import 'package:levit_flutter/levit_flutter.dart';

import 'package:edaya_shared/edaya_shared.dart';
import '../../common/utils/entity_filters.dart';
import '../context/academic_year_controller.dart';
import '../context/student_context_controller.dart';
import 'models/payment_record.dart';
import 'models/student_fee_line.dart';

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

  final feeLines = LxVar<List<StudentFeeLine>>(const []);
  final payments = LxVar<List<PaymentRecord>>(const []);
  final summary = LxVar<FeesSummary?>(null);
  final errorMessage = LxVar('');

  @override
  void onInit() {
    super.onInit();
    autoDispose(feeLines);
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
    if (isBusy.value && feeLines.value.isEmpty && payments.value.isEmpty) {
      return DataStatus.loading;
    }
    if (errorMessage.value.isNotEmpty && feeLines.value.isEmpty && payments.value.isEmpty) {
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
    if (feeLines.value.isEmpty && payments.value.isEmpty) {
      return l10n.noFeesOrPaymentsForYear;
    }
    return l10n.nothingToShowYet;
  }

  Future<void> loadFeesData() async {
    final studentId = _studentContext.activeStudentId;
    final yearId = _academicYear.selectedYearId.value;

    if (studentId == null || yearId == null) {
      feeLines(const []);
      payments(const []);
      summary(null);
      errorMessage('');
      return;
    }

    errorMessage('');
    await runTask(() async {
      try {
        final client = _schoolClient();
        final studentFeeRows = await client.studentFees.list(studentFeesForStudent(studentId));
        final yearFees = studentFeeRows
            .where((row) => row['academicYearId'] == yearId)
            .where((row) => row['status'] != 'cancelled')
            .toList();

        final feeIds = yearFees.map((row) => row['feeId'] as String?).whereType<String>().toSet().toList();
        final feeNameById = await _loadFeeNames(client, feeIds);

        final studentFeeIds = yearFees.map((row) => row['id'] as String).toList();
        final paymentRows = studentFeeIds.isEmpty
            ? <Map<String, dynamic>>[]
            : await client.payments.list(paymentsForStudentFees(studentFeeIds));

        final paymentsByFeeId = <String, List<Map<String, dynamic>>>{};
        for (final payment in paymentRows) {
          if (payment['status'] != 'recorded') {
            continue;
          }
          final studentFeeId = payment['studentFeeId'] as String;
          paymentsByFeeId.putIfAbsent(studentFeeId, () => []).add(payment);
        }

        final lines =
            yearFees.map((row) {
              final id = row['id'] as String;
              final feeId = row['feeId'] as String;
              return StudentFeeLine.fromJson(
                row,
                label: feeNameById[feeId] ?? systemL10n().schoolFee,
                paymentCount: paymentsByFeeId[id]?.length ?? 0,
              );
            }).toList()..sort((a, b) {
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
              return aDate.compareTo(bDate);
            });

        final feeLabelById = {for (final line in lines) line.id: line.label};
        final parsedPayments =
            paymentRows
                .where((row) => row['status'] == 'recorded')
                .map((row) => PaymentRecord.fromJson(row, feeLabel: feeLabelById[row['studentFeeId'] as String] ?? systemL10n().schoolFee))
                .toList()
              ..sort((a, b) => b.paymentDate.compareTo(a.paymentDate));

        final currency = lines.isNotEmpty
            ? lines.first.currency
            : parsedPayments.isNotEmpty
            ? parsedPayments.first.currency
            : 'EUR';
        final totalExpected = lines.fold<double>(0, (sum, line) => sum + line.expectedAmount);
        final totalPaid = lines.fold<double>(0, (sum, line) => sum + line.paidAmount);
        final overdueCount = lines.where((line) => line.status == StudentFeeStatus.overdue).length;

        feeLines(lines);
        payments(parsedPayments);
        summary(
          FeesSummary(
            totalExpected: totalExpected,
            totalPaid: totalPaid,
            totalBalance: (totalExpected - totalPaid).clamp(0, totalExpected),
            overdueCount: overdueCount,
            currency: currency,
          ),
        );
      } on api.ApiError catch (error) {
        errorMessage(systemL10n().couldNotLoadFees(error.toString()));
        feeLines(const []);
        payments(const []);
        summary(null);
      } on Object catch (error) {
        errorMessage(systemL10n().couldNotLoadFees(error.toString()));
        feeLines(const []);
        payments(const []);
        summary(null);
      }
    });
  }

  Future<Map<String, String>> _loadFeeNames(api.SchoolClient client, List<String> feeIds) async {
    final names = <String, String>{};
    for (final feeId in feeIds) {
      try {
        final fee = await client.fees.get(feeId);
        names[feeId] = fee['name'] as String? ?? feeId;
      } on Object {
        names[feeId] = systemL10n().schoolFee;
      }
    }
    return names;
  }
}

class PaymentDetailsController extends LevitController {
  PaymentDetailsController({required this.payment});

  final PaymentRecord payment;
}
