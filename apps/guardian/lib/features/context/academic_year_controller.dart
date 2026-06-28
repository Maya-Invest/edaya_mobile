import 'dart:async';

import 'package:edaya_api_client/edaya_api_client.dart' as api;
import 'package:levit_flutter/levit_flutter.dart';

import '../../access/app_runtime.dart';
import 'package:edaya_shared/edaya_shared.dart';
import '../auth/session_storage.dart';

class AcademicYearController extends LevitController
    with LevitReactiveTasksMixin {
  AcademicYearController({
    required SessionStorage sessionStorage,
    required AppSessionController session,
  }) : _sessionStorage = sessionStorage,
       _session = session;

  final SessionStorage _sessionStorage;
  final AppSessionController _session;

  final years = LxVar<List<Map<String, dynamic>>>(const []);
  final selectedYearId = LxVar<String?>(null);
  final errorMessage = LxVar('');

  @override
  void onInit() {
    super.onInit();
    autoDispose(years);
    autoDispose(selectedYearId);
    autoDispose(errorMessage);
  }

  String? get selectedYearLabel {
    final yearId = selectedYearId.value;
    if (yearId == null) {
      return null;
    }
    for (final year in years.value) {
      if (year['id'] == yearId) {
        return year['name'] as String? ?? yearId;
      }
    }
    return yearId;
  }

  Future<void> loadYears() async {
    if (!_session.isAuthenticated) {
      years(const []);
      selectedYearId(null);
      return;
    }

    errorMessage('');
    await runTask(() async {
      try {
        final rows = await AppRuntime.schoolClient().academicYears.list();
        final resolved = rows.isEmpty
            ? await _loadYearsFromEnrollments()
            : _sortYears(rows);
        if (resolved.isEmpty) {
          errorMessage('No academic years available.');
          years(const []);
          return;
        }
        await _applyYearSelection(resolved);
      } on api.ApiError catch (error) {
        final fallback = await _loadYearsFromEnrollments();
        if (fallback.isNotEmpty) {
          await _applyYearSelection(fallback);
          return;
        }
        errorMessage('Could not load academic years: $error');
        years(const []);
      } on Object catch (error) {
        final fallback = await _loadYearsFromEnrollments();
        if (fallback.isNotEmpty) {
          await _applyYearSelection(fallback);
          return;
        }
        errorMessage('Could not load academic years: $error');
        years(const []);
      }
    });
  }

  Future<void> selectYear(String yearId) async {
    selectedYearId(yearId);
    await _sessionStorage.writeAcademicYearId(yearId);
  }

  Future<void> _applyYearSelection(List<Map<String, dynamic>> sortedYears) async {
    years(sortedYears);

    final persistedId = await _sessionStorage.readAcademicYearId();
    if (persistedId != null &&
        sortedYears.any((year) => year['id'] == persistedId)) {
      selectedYearId(persistedId);
      return;
    }

    final activeYear = sortedYears.cast<Map<String, dynamic>?>().firstWhere(
      (year) => _isActiveYear(year!),
      orElse: () => sortedYears.isEmpty ? null : sortedYears.first,
    );
    if (activeYear != null) {
      await selectYear(activeYear['id'] as String);
    }
  }

  List<Map<String, dynamic>> _sortYears(List<Map<String, dynamic>> rows) {
    final sortedYears = rows.toList(growable: true)
      ..sort((a, b) {
        final aName = a['name'] as String? ?? '';
        final bName = b['name'] as String? ?? '';
        return bName.compareTo(aName);
      });
    return sortedYears;
  }

  Future<List<Map<String, dynamic>>> _loadYearsFromEnrollments() async {
    final grants = _session.grants.value;
    if (grants == null) {
      return const [];
    }

    final studentIds = studentIdsFromScopeGrants(
      grants.effectiveGrants.scopeGrants,
    );
    if (studentIds.isEmpty) {
      return const [];
    }

    final enrollments = await AppRuntime.schoolClient().enrollments.list({
      'studentId': {'\$in': studentIds},
    });

    final yearMeta = <String, bool>{};
    for (final enrollment in enrollments) {
      final yearId = enrollment['academicYearId'] as String?;
      if (yearId == null || yearId.isEmpty) {
        continue;
      }
      final isActiveEnrollment = enrollment['status'] == 'active';
      yearMeta[yearId] = yearMeta[yearId] == true || isActiveEnrollment;
    }

    return yearMeta.entries
        .map(
          (entry) => {
            'id': entry.key,
            'name': entry.key,
            'isActive': entry.value,
          },
        )
        .toList()
      ..sort((a, b) => (b['name'] as String).compareTo(a['name'] as String));
  }

  bool _isActiveYear(Map<String, dynamic> year) {
    final value = year['isActive'];
    return value == true || value == 'true';
  }
}
