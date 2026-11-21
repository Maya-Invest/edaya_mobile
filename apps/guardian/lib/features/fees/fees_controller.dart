import 'dart:async';

import 'package:edaya_api_client/edaya_api_client.dart' as api;
import 'package:levit_flutter/levit_flutter.dart';

import 'package:edaya_shared/edaya_shared.dart';
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

  final chargeTotals = LxVar<({int expected, int paid, int overdue})?>(null);
  final historyStatus = LxVar(DataStatus.loading);
  final nextChargeCursor = LxVar<String?>(null);
  final nextPaymentCursor = LxVar<String?>(null);
  final loadingCharges = LxVar(false);
  final loadingPayments = LxVar(false);
  final chargePageError = LxVar('');
  final paymentPageError = LxVar('');
  String? _accountId;
  Completer<void>? _abort;
  GuardianPupilSelection? _selection;
  int _generation = 0;
  Future<void>? _pending;

  @override
  void onInit() {
    super.onInit();
    autoDispose(charges);
    autoDispose(payments);
    autoDispose(summary);
    autoDispose(errorMessage);
    autoDispose(chargeTotals);
    autoDispose(historyStatus);
    autoDispose(nextChargeCursor);
    autoDispose(nextPaymentCursor);
    autoDispose(loadingCharges);
    autoDispose(loadingPayments);
    autoDispose(chargePageError);
    autoDispose(paymentPageError);

    for (final stream in [
      _studentContext.activeStudent.stream,
      _academicYear.selectedYearId.stream,
      _studentContext.isLoading.stream,
    ]) {
      autoDispose(stream.listen((_) => unawaited(_select())));
    }
    unawaited(_select());
  }

  DataStatus get dataStatus {
    final selection = _studentContext.verifiedSelection;
    if (selection == null) {
      return _studentContext.isLoading.value
          ? DataStatus.loading
          : DataStatus.empty;
    }
    if (_selection != selection) return DataStatus.loading;
    if (summary.value != null) return DataStatus.ready;
    return errorMessage.value.isEmpty ? DataStatus.loading : DataStatus.error;
  }

  String get emptyMessage {
    final l10n = systemL10n();
    return _studentContext.activeStudent.value == null
        ? l10n.selectStudentToViewFees
        : l10n.noFeesOrPaymentsForYear;
  }

  Future<void> loadFeesData() => _select(refresh: true);

  Future<void> _select({bool refresh = false}) {
    if (isClosed) return Future.value();
    final selection = _studentContext.verifiedSelection;
    final changed = selection != _selection;
    final loading = _pending != null && historyStatus.value != DataStatus.error;
    if (!changed && (!refresh || loading)) {
      return _pending ?? Future.value();
    }
    final generation = ++_generation;
    _selection = selection;
    _pending = null;
    _cancelReads();
    _clear();
    errorMessage('');
    historyStatus(DataStatus.loading);
    if (selection == null) return Future.value();
    _abort = Completer<void>();
    return _pending = runTask(() => _read(selection, generation)).whenComplete(
      () {
        if (_generation == generation) _pending = null;
      },
    );
  }

  void _clear() {
    summary(null);
    chargeTotals(null);
    charges(const []);
    payments(const []);
    nextChargeCursor(null);
    nextPaymentCursor(null);
    paymentPageError('');
    chargePageError('');
    loadingPayments(false);
    loadingCharges(false);
    _accountId = null;
  }

  void _cancelReads() {
    _abort?.complete();
    _abort = null;
  }

  @override
  void onClose() {
    _cancelReads();
    super.onClose();
  }

  bool _current(GuardianPupilSelection selection, int generation) =>
      !isClosed &&
      generation == _generation &&
      selection == _studentContext.verifiedSelection;

  Map<String, dynamic> _scope(GuardianPupilSelection selection) => {
    'studentId': selection.studentId,
    'academicYearId': selection.academicYearId,
  };

  void _verifyScope(
    Map<String, dynamic> data,
    GuardianPupilSelection selection,
  ) {
    if (data['studentId'] != selection.studentId ||
        data['academicYearId'] != selection.academicYearId) {
      throw const FormatException('Unexpected settlement pupil or year');
    }
  }

  bool _denied(Object error) =>
      error is api.ApiError && (error.status == 401 || error.status == 403);

  void _report(Object error) {
    if (_denied(error)) {
      ++_generation;
      _pending = null;
      _cancelReads();
      _clear();
    }
    errorMessage(systemL10n().couldNotLoadFees(error.toString()));
    historyStatus(DataStatus.error);
  }

  Future<void> _read(GuardianPupilSelection selection, int generation) async {
    final abort = _abort!.future;
    final query = _scope(selection);
    Future<void> readBalance() async {
      try {
        final data = await _schoolClient().getGuardianFeesSummary(
          query,
          abortTrigger: abort,
        );
        if (!_current(selection, generation)) return;
        _verifyScope(data, selection);
        final balance = FeesSummary.fromJson(data);
        _accountId = data['accountId'] as String?;
        chargeTotals((
          expected: data['expected'] as int,
          paid: data['paid'] as int,
          overdue: data['overdueCount'] as int,
        ));
        summary(balance);
      } on Object catch (error) {
        if (_current(selection, generation)) _report(error);
      }
    }

    final balance = readBalance();
    try {
      final page = await _schoolClient().getGuardianSettlements(
        query,
        abortTrigger: abort,
      );
      await balance;
      if (_current(selection, generation) && summary.value != null) {
        _applyPage(page, selection);
        historyStatus(DataStatus.ready);
      }
    } on Object catch (error) {
      if (_current(selection, generation)) _report(error);
    }
    await balance;
  }

  void _applyPage(
    Map<String, dynamic> page,
    GuardianPupilSelection selection, {
    bool? chargeSection,
  }) {
    _verifyScope(page, selection);
    final currency = summary.value!.currency;
    if (page['accountId'] != _accountId || page['currency'] != currency) {
      throw const FormatException('Unexpected settlement account or currency');
    }
    final lines = (page['charges'] as List).cast<Map<String, dynamic>>().map((
      row,
    ) {
      if (StudentChargeLine.currencyFromJson(row) != currency) {
        throw const FormatException('Unexpected charge currency');
      }
      return StudentChargeLine.fromJson(
        row,
        settlementCount: row['settlementCount'] as int,
      );
    }).toList();
    final records = (page['payments'] as List)
        .cast<Map<String, dynamic>>()
        .map(
          (row) => PaymentRecord.fromJson(
            row,
            feeLabel: paymentDisplayLabel(
              row['kind'],
              (row['chargeLabels'] as List).cast<String>(),
            ),
            currency: currency,
          ),
        )
        .toList();
    if (chargeSection != false) {
      final next = page['nextChargeCursor'] as String?;
      if (next != null && next == nextChargeCursor.value) {
        throw const FormatException('Charge cursor did not advance');
      }
      charges(
        {
          for (final line in [...charges.value, ...lines]) line.id: line,
        }.values.toList(),
      );
      nextChargeCursor(next);
    }
    if (chargeSection != true) {
      final next = page['nextPaymentCursor'] as String?;
      if (next != null && next == nextPaymentCursor.value) {
        throw const FormatException('Payment cursor did not advance');
      }
      payments(
        {
          for (final record in [...payments.value, ...records])
            record.id: record,
        }.values.toList(),
      );
      nextPaymentCursor(next);
    }
  }

  Future<void> loadMoreCharges() => _loadMore(true);
  Future<void> loadMorePayments() => _loadMore(false);

  Future<void> _loadMore(bool chargeSection) async {
    final selection = _selection;
    final generation = _generation;
    final busy = chargeSection ? loadingCharges : loadingPayments;
    final errorText = chargeSection ? chargePageError : paymentPageError;
    final cursor = (chargeSection ? nextChargeCursor : nextPaymentCursor).value;
    if (selection == null ||
        !_current(selection, generation) ||
        cursor == null ||
        busy.value) {
      return;
    }
    busy(true);
    errorText('');
    try {
      final page = await _schoolClient().getGuardianSettlements({
        ..._scope(selection),
        'cursor': cursor,
      }, abortTrigger: _abort!.future);
      if (_current(selection, generation)) {
        _applyPage(page, selection, chargeSection: chargeSection);
      }
    } on Object catch (error) {
      if (!_current(selection, generation)) return;
      if (_denied(error)) {
        _report(error);
      } else {
        errorText(systemL10n().couldNotLoadFees(error.toString()));
      }
    } finally {
      if (_current(selection, generation)) busy(false);
    }
  }

  int get overdueCount => chargeTotals.value?.overdue ?? 0;
  int get totalExpected => chargeTotals.value?.expected ?? 0;
  int get totalPaid => chargeTotals.value?.paid ?? 0;
  int get totalBalance => summary.value?.outstanding ?? 0;

  Future<DocumentJobResult> downloadStatement({required String? schoolId}) {
    final selection = _studentContext.verifiedSelection;
    final studentId = selection?.studentId;
    final yearId = selection?.academicYearId;
    final currency = summary.value?.currency;
    if (selection != _selection ||
        schoolId != selection?.schoolId ||
        schoolId == null ||
        studentId == null ||
        yearId == null ||
        currency == null) {
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
