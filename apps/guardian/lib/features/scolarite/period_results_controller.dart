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
    this.subjectId,
    this.focusMarkId,
  });
  final SchoolClient? client;
  final Future<List<Map<String, dynamic>>> Function()? periodLoader;
  final Future<Map<String, dynamic>> Function(String)? resultLoader;
  final String studentId, yearId;
  final String? initialPeriod, subjectId, focusMarkId;
  final periods = LxVar<List<Map<String, dynamic>>>([]);
  final selectedPeriod = LxVar<String?>(null);
  final result = LxVar<Map<String, dynamic>?>(null);
  final loading = LxVar(true);
  final failed = LxVar(false);
  final loadingMore = LxVar(false);
  final pageFailed = LxVar(false);
  int _generation = 0;
  @override
  void onInit() {
    super.onInit();
    autoDispose(periods);
    autoDispose(selectedPeriod);
    autoDispose(result);
    autoDispose(loading);
    autoDispose(failed);
    autoDispose(loadingMore);
    autoDispose(pageFailed);
    unawaited(initialize());
  }

  Future<void> initialize() async {
    final generation = ++_generation;
    loading(true);
    failed(false);
    try {
      if (client != null && subjectId != null && initialPeriod != null) {
        await select(initialPeriod!);
        return;
      }
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

  Future<Map<String, dynamic>> _read(String period) async {
    if (resultLoader != null) return resultLoader!(period);
    final key = {'studentId': studentId, 'periodId': period};
    try {
      if (subjectId == null) {
        return await client!.getGuardianPeriodOverview(key);
      }
      final page = await client!.getGuardianSubjectMarks({
        ...key,
        'subjectId': subjectId,
        if (focusMarkId != null) 'focusMarkId': focusMarkId,
      });
      if (page['academicYearId'] != yearId || page['periodId'] != period) {
        throw StateError('Unexpected period');
      }
      return {
        ...page,
        'sections': [if (page['section'] != null) page['section']],
        'marks': [
          ...page['marks'] as List,
          if (page['focusedMark'] != null) page['focusedMark'],
        ],
      };
    } on ApiError catch (error) {
      if (error.status != 404 && error.status != 405) rethrow;
      final legacy = await client!.runQuery('get-guardian-period-results', key);
      if (subjectId == null) return legacy;
      final catalog = await client!.academicPeriods.listAll({
        'academicYearId': yearId,
      });
      final selected = catalog.where((row) => row['id'] == period).firstOrNull;
      if (selected == null) throw StateError('Unknown period');
      return {...legacy, 'periodName': selected['name']};
    }
  }

  Future<void> select(String id) async {
    final generation = ++_generation;
    selectedPeriod(id);
    loading(true);
    failed(false);
    result(null);
    loadingMore(false);
    pageFailed(false);
    try {
      final response = await _read(id);
      if (isClosed || generation != _generation) return;
      result(response);
    } catch (_) {
      if (!isClosed && generation == _generation) failed(true);
    } finally {
      if (!isClosed && generation == _generation) loading(false);
    }
  }

  Future<void> loadMore() async {
    final data = result.value;
    final cursor = data?['nextCursor'];
    if (loadingMore.value || data == null || cursor is! String) return;
    final generation = _generation;
    loadingMore(true);
    pageFailed(false);
    try {
      final page = await client!.getGuardianSubjectMarks({
        'studentId': studentId,
        'periodId': selectedPeriod.value,
        'subjectId': subjectId,
        'cursor': cursor,
      });
      if (isClosed || generation != _generation) return;
      if (page['academicYearId'] != yearId ||
          page['periodId'] != selectedPeriod.value) {
        throw StateError('Unexpected period');
      }
      if (page['section'] == null || page['state'] != data['state']) {
        await select(selectedPeriod.value!);
        return;
      }
      final combined = {
        for (final row in [...data['marks'] as List, ...page['marks'] as List])
          row['id']: row,
      };
      result({
        ...data,
        'section': page['section'],
        'sections': [page['section']],
        'marks': combined.values.toList(),
        'nextCursor': page['nextCursor'],
      });
    } catch (error) {
      if (isClosed || generation != _generation) return;
      if (error is ApiError && (error.status == 401 || error.status == 403)) {
        result(null);
        failed(true);
      } else {
        pageFailed(true);
      }
    } finally {
      if (!isClosed && generation == _generation) loadingMore(false);
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
        ..sort((a, b) {
          final date = '${b['date'] ?? ''}'.compareTo('${a['date'] ?? ''}');
          return date == 0 ? '${a['id']}'.compareTo('${b['id']}') : date;
        });
  @override
  void onClose() {
    _generation++;
    super.onClose();
  }
}
