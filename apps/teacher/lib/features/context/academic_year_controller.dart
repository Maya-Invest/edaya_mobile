import 'dart:async';

import 'package:edaya_api_client/edaya_api_client.dart' as api;
import 'package:edaya_shared/edaya_shared.dart';
import 'package:levit_flutter/levit_flutter.dart';

import '../auth/session_storage.dart';

class AcademicYearController extends LevitController
    with LevitReactiveTasksMixin {
  AcademicYearController({
    required SessionStorage sessionStorage,
    required AppSessionController session,
    required SchoolClientFactory schoolClient,
  }) : _sessionStorage = sessionStorage,
       _session = session,
       _schoolClient = schoolClient;

  final SessionStorage _sessionStorage;
  final AppSessionController _session;
  final SchoolClientFactory _schoolClient;

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

  List<String> get yearLabels => years.value
      .map((year) => year['name'] as String? ?? year['id'] as String)
      .toList();

  String? idForYearLabel(String label) {
    for (final year in years.value) {
      final name = year['name'] as String? ?? year['id'] as String;
      if (name == label) {
        return year['id'] as String?;
      }
    }
    return null;
  }

  int _generation = 0;
  bool confirmedNoPublishedYear = false;

  void clearSelection() {
    _generation++;
    confirmedNoPublishedYear = false;
    years(const []);
    selectedYearId(null);
    errorMessage('');
  }

  Future<void> loadYears() async {
    final generation = ++_generation;
    confirmedNoPublishedYear = false;
    if (!_session.hasSchoolSession) {
      years(const []);
      selectedYearId(null);
      return;
    }

    errorMessage('');
    await runTask(() async {
      try {
        final rows = await _schoolClient().academicYears.listAll();
        if (isClosed || generation != _generation) return;
        final sorted = rows.toList(growable: true)
          ..sort((a, b) {
            final aName = a['name'] as String? ?? '';
            final bName = b['name'] as String? ?? '';
            return bName.compareTo(aName);
          });
        if (sorted.isEmpty) {
          confirmedNoPublishedYear = true;
          selectedYearId(null);
          errorMessage(systemL10n().noAcademicYearsAvailable);
          years(const []);
          return;
        }
        await _applyYearSelection(sorted);
      } on api.ApiError catch (error) {
        if (isClosed || generation != _generation) return;
        selectedYearId(null);
        errorMessage(systemL10n().couldNotLoadAcademicYears('$error'));
        years(const []);
      } on Object catch (error) {
        if (isClosed || generation != _generation) return;
        selectedYearId(null);
        errorMessage(systemL10n().couldNotLoadAcademicYears('$error'));
        years(const []);
      }
    });
  }

  Future<void> selectYear(String yearId) async {
    selectedYearId(yearId);
    await _sessionStorage.writeAcademicYearId(yearId);
  }

  Future<void> _applyYearSelection(
    List<Map<String, dynamic>> sortedYears,
  ) async {
    years(sortedYears);

    // Teacher work follows the school's published year, never a saved year
    // from another school or a future draft chosen by alphabetical order.
    final activeYear = publishedTeacherYear(sortedYears);
    selectedYearId(activeYear?['id'] as String?);
    if (activeYear == null) {
      confirmedNoPublishedYear = true;
      errorMessage(systemL10n().thisSchoolHasNoPublishedSchoolYear);
    }
  }
}

Map<String, dynamic>? publishedTeacherYear(List<Map<String, dynamic>> years) =>
    years.where((year) => year['status'] == 'published').firstOrNull;
