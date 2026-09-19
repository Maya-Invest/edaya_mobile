import 'package:edaya_shared/edaya_shared.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persists auth cookies on native platforms and guardian UI context.
class SessionStorage extends AuthSessionStorage {
  static const _activeStudentIdKey = 'guardian_active_student_id';
  static const _academicYearIdKey = 'guardian_academic_year_id';

  Future<String?> readActiveStudentId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_activeStudentIdKey);
  }

  Future<void> writeActiveStudentId(String? studentId) async {
    final prefs = await SharedPreferences.getInstance();
    if (studentId == null || studentId.isEmpty) {
      await prefs.remove(_activeStudentIdKey);
      return;
    }
    await prefs.setString(_activeStudentIdKey, studentId);
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
}
