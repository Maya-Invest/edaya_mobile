import 'dart:async';

import 'package:edaya_api_client/edaya_api_client.dart' as api;
import 'package:levit_flutter/levit_flutter.dart';

import 'package:edaya_shared/edaya_shared.dart';
import '../auth/session_storage.dart';

class AcademicYearController extends LevitController
    with LevitReactiveTasksMixin {
  AcademicYearController({
    this.archive = false,
    this.initialYearId,
    required SessionStorage sessionStorage,
    required AppSessionController session,
    required SchoolClientFactory schoolClient,
  }) : _sessionStorage = sessionStorage,
       _session = session,
       _schoolClient = schoolClient;

  final bool archive;
  final String? initialYearId;
  final SessionStorage _sessionStorage;
  final AppSessionController _session;
  final SchoolClientFactory _schoolClient;

  final years = LxVar<List<Map<String, dynamic>>>(const []);
  final yearsBySchool = LxVar<Map<String, List<Map<String, dynamic>>>>(
    const {},
  );
  final selectedYearId = LxVar<String?>(null);
  final selectedYearBySchool = LxVar<Map<String, String>>(const {});
  final errorMessage = LxVar('');

  @override
  void onInit() {
    super.onInit();
    autoDispose(years);
    autoDispose(yearsBySchool);
    autoDispose(selectedYearId);
    autoDispose(selectedYearBySchool);
    autoDispose(errorMessage);
  }

  String? get selectedYearLabel {
    return yearLabelFor(selectedYearId.value);
  }

  String? selectedYearLabelForSchool(String schoolId) {
    final yearId = selectedYearBySchool.value[schoolId] ?? selectedYearId.value;
    return yearLabelFor(yearId, schoolId: schoolId);
  }

  List<Map<String, dynamic>> yearsForSchool(String schoolId) {
    if (schoolId.isNotEmpty) {
      final scoped = yearsBySchool.value[schoolId];
      if (scoped != null && scoped.isNotEmpty) return scoped;
    }
    return years.value;
  }

  String? yearLabelFor(String? yearId, {String? schoolId}) {
    if (yearId == null) return null;
    final pool = schoolId == null ? years.value : yearsForSchool(schoolId);
    for (final year in pool) {
      if (year['id'] == yearId) {
        return year['name'] as String? ?? yearId;
      }
    }
    if (schoolId != null) {
      for (final year in years.value) {
        if (year['id'] == yearId) {
          return year['name'] as String? ?? yearId;
        }
      }
    }
    return yearId;
  }

  int _loadGeneration = 0;
  Future<void> loadYears() async {
    final generation = ++_loadGeneration;
    final school = _session.schoolIdHeader;
    bool current() =>
        !isClosed &&
        generation == _loadGeneration &&
        school == _session.schoolIdHeader;
    if (!_session.isAuthenticated || !_session.hasSchoolSession) {
      years(const []);
      yearsBySchool(const {});
      selectedYearId(null);
      return;
    }
    errorMessage('');
    await runTask(() async {
      try {
        final rows = await _schoolClient().academicYears.listAll();
        if (!current()) return;
        if (rows.isEmpty) {
          years(const []);
          yearsBySchool(const {});
          selectedYearId(null);
          errorMessage(systemL10n().noAcademicYearsAvailable);
          return;
        }
        await _applyYearSelection(_sortYears(rows));
      } catch (error) {
        if (!current()) return;
        years(const []);
        yearsBySchool(const {});
        selectedYearId(null);
        errorMessage(systemL10n().couldNotLoadAcademicYears(error.toString()));
      }
    });
  }

  Future<void> selectYear(String yearId) async {
    selectedYearId(yearId);
    if (archive) return;
    final schoolId = _session.schoolIdHeader;
    if (schoolId != null && schoolId.isNotEmpty) {
      selectedYearBySchool({...selectedYearBySchool.value, schoolId: yearId});
      await _sessionStorage.writeAcademicYearIdForSchool(schoolId, yearId);
      return;
    }
    await _sessionStorage.writeAcademicYearId(yearId);
  }

  Future<void> selectYearForSchool(String schoolId, String yearId) async {
    if (schoolId.isEmpty) {
      await selectYear(yearId);
      return;
    }
    selectedYearBySchool({...selectedYearBySchool.value, schoolId: yearId});
    await _sessionStorage.writeAcademicYearIdForSchool(schoolId, yearId);
    final currentSchool = _session.schoolIdHeader;
    if (currentSchool == null ||
        currentSchool.isEmpty ||
        currentSchool == schoolId) {
      selectedYearId(yearId);
    }
  }

  Future<void> applyStoredYearForSchool(String schoolId) async {
    if (!archive || schoolId.isEmpty) return;
    final stored = await _sessionStorage.readAcademicYearIdForSchool(schoolId);
    if (stored == null || stored == selectedYearId.value) return;
    if (!yearsForSchool(schoolId).any((year) => year['id'] == stored) &&
        !years.value.any((year) => year['id'] == stored)) {
      return;
    }
    await selectYearForSchool(schoolId, stored);
  }

  Future<void> _applyYearSelection(
    List<Map<String, dynamic>> sortedYears,
  ) async {
    years(sortedYears);
    _indexYearsBySchool(sortedYears);

    final requested = archive ? initialYearId : null;
    final selected =
        sortedYears.where((y) => y['id'] == requested).firstOrNull ??
        sortedYears.where((y) => y['status'] == 'published').firstOrNull;
    selectedYearId(selected?['id'] as String?);
    if (selected == null) errorMessage(systemL10n().noPublishedSchoolYear);
  }

  void _indexYearsBySchool(List<Map<String, dynamic>> rows) {
    final map = <String, List<Map<String, dynamic>>>{};
    for (final row in rows) {
      final schoolId = row['schoolId'] as String? ?? '';
      if (schoolId.isEmpty) continue;
      map.putIfAbsent(schoolId, () => []).add(row);
    }
    final current = _session.schoolIdHeader;
    if (map.isEmpty && current != null && current.isNotEmpty) {
      map[current] = List<Map<String, dynamic>>.from(rows);
    }
    yearsBySchool(map);
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
}
