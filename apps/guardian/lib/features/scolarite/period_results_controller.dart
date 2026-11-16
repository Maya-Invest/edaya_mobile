import 'dart:async';
import 'package:edaya_shared/edaya_shared.dart' show SchoolClock;
import 'package:edaya_api_client/edaya_api_client.dart';
import 'package:levit_flutter/levit_flutter.dart';

class PeriodResultsController extends LevitController {
  PeriodResultsController({
    this.client,
    this.periodLoader,
    this.resultLoader,
    required this.studentId,
    required this.yearId,
    this.initialPeriod,
  });
  final SchoolClient? client;
  final Future<List<Map<String, dynamic>>> Function()? periodLoader;
  final Future<Map<String, dynamic>> Function(String)? resultLoader;
  final String studentId, yearId;
  final String? initialPeriod;
  final periods = LxVar<List<Map<String, dynamic>>>([]);
  final selectedPeriod = LxVar<String?>(null);
  final result = LxVar<Map<String, dynamic>?>(null);
  final loading = LxVar(true);
  final failed = LxVar(false);
  int _generation = 0;
  @override
  void onInit() {
    super.onInit();
    autoDispose(periods);
    autoDispose(selectedPeriod);
    autoDispose(result);
    autoDispose(loading);
    autoDispose(failed);
    unawaited(initialize());
  }

  Future<void> initialize() async {
    final generation = ++_generation;
    loading(true);
    failed(false);
    try {
      final rows =
          await (periodLoader?.call() ??
              client!.academicPeriods.listAll({'academicYearId': yearId}));
      rows.sort((a, b) => '${a['startDate']}'.compareTo('${b['startDate']}'));
      if (isClosed || generation != _generation) return;
      periods(rows);
      if (initialPeriod != null &&
          !rows.any((row) => row['id'] == initialPeriod)) {
        failed(true);
        loading(false);
        return;
      }
      final now = SchoolClock.now();
      final selected =
          rows.where((p) => p['id'] == initialPeriod).firstOrNull ??
          rows.where((p) {
            final start = DateTime.tryParse('${p['startDate']}');
            final end = DateTime.tryParse('${p['endDate']}');
            return start != null &&
                end != null &&
                !now.isBefore(start) &&
                now.isBefore(end.add(const Duration(days: 1)));
          }).firstOrNull ??
          rows.lastOrNull;
      if (selected == null) {
        loading(false);
        return;
      }
      await select(selected['id'] as String);
    } catch (_) {
      if (!isClosed && generation == _generation) {
        failed(true);
        loading(false);
      }
    }
  }

  Future<void> select(String id) async {
    final generation = ++_generation;
    selectedPeriod(id);
    loading(true);
    failed(false);
    result(null);
    try {
      final response =
          await (resultLoader?.call(id) ??
              client!.runQuery('get-guardian-period-results', {
                'studentId': studentId,
                'periodId': id,
              }));
      if (isClosed || generation != _generation) return;
      result(response);
    } catch (_) {
      if (!isClosed && generation == _generation) failed(true);
    } finally {
      if (!isClosed && generation == _generation) loading(false);
    }
  }

  List<Map<String, dynamic>> get sections =>
      (result.value?['sections'] as List? ?? [])
          .map((r) => Map<String, dynamic>.from(r as Map))
          .toList();
  List<Map<String, dynamic>> get marks =>
      (result.value?['marks'] as List? ?? [])
          .map((r) => Map<String, dynamic>.from(r as Map))
          .toList()
        ..sort((a, b) => '${b['date'] ?? ''}'.compareTo('${a['date'] ?? ''}'));
  @override
  void onClose() {
    _generation++;
    super.onClose();
  }
}
