import 'package:edaya_shared/edaya_shared.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persists auth cookies on native platforms and guardian UI context.
class SessionStorage extends AuthSessionStorage {
  SessionStorage({this.contextKey});
  final String Function()? contextKey;
  String get _activeStudentIdKey =>
      'guardian_v2_child::${contextKey?.call() ?? ''}';
  static const _academicYearIdKey = 'guardian_academic_year_id';

  static String _academicYearIdKeyForSchool(String schoolId) =>
      '$_academicYearIdKey::$schoolId';

  Future<String?> readActiveStudentId() async {
    final key = _activeStudentIdKey;
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(key);
  }

  Future<void> writeActiveStudentId(String? studentId) async {
    final key = _activeStudentIdKey;
    final prefs = await SharedPreferences.getInstance();
    if (studentId == null || studentId.isEmpty) {
      await prefs.remove(key);
      return;
    }
    await prefs.setString(key, studentId);
  }

  Future<String?> readAcademicYearId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_academicYearIdKey);
  }

  Future<void> writeAcademicYearId(String? yearId) async {
    final prefs = await SharedPreferences.getInstance();
    if (yearId == null || yearId.isEmpty) {
      await prefs.remove(_academicYearIdKey);
      return;
    }
    await prefs.setString(_academicYearIdKey, yearId);
  }

  Future<String?> readAcademicYearIdForSchool(String schoolId) async {
    if (schoolId.isEmpty) return readAcademicYearId();
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_academicYearIdKeyForSchool(schoolId)) ??
        prefs.getString(_academicYearIdKey);
  }

  Future<void> writeAcademicYearIdForSchool(
    String schoolId,
    String? yearId,
  ) async {
    if (schoolId.isEmpty) {
      await writeAcademicYearId(yearId);
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    final key = _academicYearIdKeyForSchool(schoolId);
    if (yearId == null || yearId.isEmpty) {
      await prefs.remove(key);
      return;
    }
    await prefs.setString(key, yearId);
    await prefs.setString(_academicYearIdKey, yearId);
  }
}
