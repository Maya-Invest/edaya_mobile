import 'dart:async';

import 'package:edaya_api_client/edaya_api_client.dart' as api;
import 'package:levit_flutter/levit_flutter.dart';

import '../../access/app_runtime.dart';
import '../../common/utils/entity_filters.dart';
import 'package:edaya_shared/edaya_shared.dart';
import '../context/academic_year_controller.dart';
import '../context/student_context_controller.dart';
import 'models/payment_record.dart';
import 'models/student_fee_line.dart';

class FeesController extends LevitController with LevitReactiveTasksMixin {
  FeesController({
    required StudentContextController studentContext,
    required AcademicYearController academicYear,
  }) : _studentContext = studentContext,
       _academicYear = academicYear;

  final StudentContextController _studentContext;
  final AcademicYearController _academicYear;

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

    unawaited(loadFeesData());
  }

  DataStatus get dataStatus {
    if (isBusy.value && feeLines.value.isEmpty && payments.value.isEmpty) {
      return DataStatus.loading;
    }
    if (errorMessage.value.isNotEmpty &&
        feeLines.value.isEmpty &&
        payments.value.isEmpty) {
      return DataStatus.error;
    }
    if (_studentContext.activeStudent.value == null) {
      return DataStatus.empty;
    }
    return DataStatus.ready;
  }

  String get emptyMessage {
    if (_studentContext.activeStudent.value == null) {
      return 'Select a student to view fees and payments.';
    }
    if (feeLines.value.isEmpty && payments.value.isEmpty) {
      return 'No fee lines or payments for the selected school year.';
    }
    return 'Nothing to show yet.';
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
        final client = AppRuntime.schoolClient();
        final studentFeeRows = await client.studentFees.list(
          studentFeesForStudent(studentId),
        );
        final yearFees = studentFeeRows
            .where((row) => row['academicYearId'] == yearId)
            .where((row) => row['status'] != 'cancelled')
            .toList();

        final feeIds = yearFees
            .map((row) => row['feeId'] as String?)
            .whereType<String>()
            .toSet()
            .toList();
        final feeNameById = await _loadFeeNames(client, feeIds);

        final studentFeeIds = yearFees
            .map((row) => row['id'] as String)
            .toList();
        final paymentRows = studentFeeIds.isEmpty
            ? <Map<String, dynamic>>[]
            : await client.payments.list(
                paymentsForStudentFees(studentFeeIds),
              );

        final paymentsByFeeId = <String, List<Map<String, dynamic>>>{};
        for (final payment in paymentRows) {
          if (payment['status'] != 'recorded') {
            continue;
          }
          final studentFeeId = payment['studentFeeId'] as String;
          paymentsByFeeId
              .putIfAbsent(studentFeeId, () => [])
              .add(payment);
        }

        final lines = yearFees
            .map((row) {
              final id = row['id'] as String;
              final feeId = row['feeId'] as String;
              return StudentFeeLine.fromJson(
                row,
                label: feeNameById[feeId] ?? 'School fee',
                paymentCount: paymentsByFeeId[id]?.length ?? 0,
              );
            })
            .toList()
          ..sort((a, b) {
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
        final parsedPayments = paymentRows
            .where((row) => row['status'] == 'recorded')
            .map(
              (row) => PaymentRecord.fromJson(
                row,
                feeLabel: feeLabelById[row['studentFeeId'] as String] ??
                    'School fee',
              ),
            )
            .toList()
          ..sort((a, b) => b.paymentDate.compareTo(a.paymentDate));

        final currency = lines.isNotEmpty
            ? lines.first.currency
            : parsedPayments.isNotEmpty
            ? parsedPayments.first.currency
            : 'EUR';
        final totalExpected = lines.fold<double>(
          0,
          (sum, line) => sum + line.expectedAmount,
        );
        final totalPaid = lines.fold<double>(
          0,
          (sum, line) => sum + line.paidAmount,
        );
        final overdueCount = lines
            .where((line) => line.status == StudentFeeStatus.overdue)
            .length;

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
        errorMessage('Could not load fees: $error');
        feeLines(const []);
        payments(const []);
        summary(null);
      } on Object catch (error) {
        errorMessage('Could not load fees: $error');
        feeLines(const []);
        payments(const []);
        summary(null);
      }
    });
  }

  Future<Map<String, String>> _loadFeeNames(
    api.SchoolClient client,
    List<String> feeIds,
  ) async {
    final names = <String, String>{};
    for (final feeId in feeIds) {
      try {
        final fee = await client.fees.get(feeId);
        names[feeId] = fee['name'] as String? ?? feeId;
      } on Object {
        names[feeId] = 'School fee';
      }
    }
    return names;
  }
}

class PaymentDetailsController extends LevitController {
  PaymentDetailsController({required this.payment});

  final PaymentRecord payment;
}
