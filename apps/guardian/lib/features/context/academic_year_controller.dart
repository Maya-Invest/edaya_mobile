import 'dart:async';

import 'package:edaya_api_client/edaya_api_client.dart' as api;
import 'package:levit_flutter/levit_flutter.dart';

import 'package:edaya_shared/edaya_shared.dart';
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

  Future<void> loadYears() async {
    if (!_session.isAuthenticated) {
      years(const []);
      yearsBySchool(const {});
      selectedYearId(null);
      return;
    }

    errorMessage('');
    await runTask(() async {
      try {
        final rows = await _schoolClient().academicYears.list();
        final resolved = rows.isEmpty
            ? await _loadYearsFromEnrollments()
            : _sortYears(rows);
        if (resolved.isEmpty) {
          errorMessage(systemL10n().noAcademicYearsAvailable);
          years(const []);
          yearsBySchool(const {});
          return;
        }
        await _applyYearSelection(resolved);
      } on api.ApiError catch (error) {
        final fallback = await _loadYearsFromEnrollments();
        if (fallback.isNotEmpty) {
          await _applyYearSelection(fallback);
          return;
        }
        errorMessage(systemL10n().couldNotLoadAcademicYears(error.toString()));
        years(const []);
        yearsBySchool(const {});
      } on Object catch (error) {
        final fallback = await _loadYearsFromEnrollments();
        if (fallback.isNotEmpty) {
          await _applyYearSelection(fallback);
          return;
        }
        errorMessage(systemL10n().couldNotLoadAcademicYears(error.toString()));
        years(const []);
        yearsBySchool(const {});
      }
    });
  }

  Future<void> selectYear(String yearId) async {
    selectedYearId(yearId);
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
    if (schoolId.isEmpty) return;
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

    final schoolId = _session.schoolIdHeader;
    final persistedId = schoolId == null || schoolId.isEmpty
        ? await _sessionStorage.readAcademicYearId()
        : await _sessionStorage.readAcademicYearIdForSchool(schoolId);
    if (persistedId != null &&
        sortedYears.any((year) => year['id'] == persistedId)) {
      await selectYear(persistedId);
    } else {
      final activeYear = sortedYears.cast<Map<String, dynamic>?>().firstWhere(
        (year) => _isActiveYear(year!),
        orElse: () => sortedYears.isEmpty ? null : sortedYears.first,
      );
      if (activeYear != null) {
        await selectYear(activeYear['id'] as String);
      }
    }

    await _hydrateStoredYearsForSchools();
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

  Future<void> _hydrateStoredYearsForSchools() async {
    final next = {...selectedYearBySchool.value};
    var changed = false;
    for (final schoolId in yearsBySchool.value.keys) {
      final stored = await _sessionStorage.readAcademicYearIdForSchool(
        schoolId,
      );
      if (stored == null) continue;
      if (!yearsForSchool(schoolId).any((year) => year['id'] == stored)) {
        continue;
      }
      if (next[schoolId] == stored) continue;
      next[schoolId] = stored;
      changed = true;
    }
    if (changed) selectedYearBySchool(next);
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
    if (grants == null || grants.kind != 'guardian') {
      return const [];
    }

    final studentIds = await loadGuardianLinkedStudentIds(
      _schoolClient(),
      grants.actorId,
    );
    if (studentIds.isEmpty) {
      return const [];
    }

    final client = _schoolClient();
    final enrollments = await client.enrollments.list({
      'studentId': {'\$in': studentIds},
    });
    final studentRows = await client.students.list(entitiesByIds(studentIds));
    final schoolByStudent = <String, String>{
      for (final row in studentRows)
        if (row['id'] is String)
          row['id'] as String: row['schoolId'] as String? ?? '',
    };
    final fallbackSchoolId = _session.schoolIdHeader ?? '';

    final yearMeta = <String, bool>{};
    final schoolByYear = <String, String>{};
    for (final enrollment in enrollments) {
      final yearId = enrollment['academicYearId'] as String?;
      if (yearId == null || yearId.isEmpty) {
        continue;
      }
      final isActiveEnrollment = enrollment['status'] == 'active';
      yearMeta[yearId] = yearMeta[yearId] == true || isActiveEnrollment;
      final studentId = enrollment['studentId'] as String?;
      final fromStudent = studentId == null
          ? ''
          : (schoolByStudent[studentId] ?? '');
      final schoolId = fromStudent.isNotEmpty ? fromStudent : fallbackSchoolId;
      if (schoolId.isNotEmpty) {
        schoolByYear.putIfAbsent(yearId, () => schoolId);
      }
    }

    return yearMeta.entries
        .map(
          (entry) => {
            'id': entry.key,
            'name': entry.key,
            'isActive': entry.value,
            if (schoolByYear[entry.key] != null)
              'schoolId': schoolByYear[entry.key],
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
