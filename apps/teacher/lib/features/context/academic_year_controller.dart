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
        final sorted = rows.toList(growable: true)
          ..sort((a, b) {
            final aName = a['name'] as String? ?? '';
            final bName = b['name'] as String? ?? '';
            return bName.compareTo(aName);
          });
        if (sorted.isEmpty) {
          errorMessage('No academic years available.');
          years(const []);
          return;
        }
        await _applyYearSelection(sorted);
      } on api.ApiError catch (error) {
        errorMessage('Could not load academic years: $error');
        years(const []);
      } on Object catch (error) {
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
      (year) => year!['isActive'] == true || year['isActive'] == 'true',
      orElse: () => sortedYears.isEmpty ? null : sortedYears.first,
    );
    if (activeYear != null) {
      await selectYear(activeYear['id'] as String);
    }
  }
}
