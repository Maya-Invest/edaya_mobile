import 'package:edaya_shared/edaya_shared.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SessionStorage extends AuthSessionStorage {
  static const _academicYearIdKey = 'teacher_academic_year_id';
  static const _assignmentIdKey = 'teacher_assignment_id';

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

  Future<String?> readClassSelection(String key) async =>
      (await SharedPreferences.getInstance()).getString(key);

  Future<void> writeClassSelection(String key, String? classId) async {
    final prefs = await SharedPreferences.getInstance();
    if (classId == null) {
      await prefs.remove(key);
    } else {
      await prefs.setString(key, classId);
    }
  }

  Future<String?> readAssignmentId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_assignmentIdKey);
  }

  Future<void> writeAssignmentId(String? assignmentId) async {
    final prefs = await SharedPreferences.getInstance();
    if (assignmentId == null || assignmentId.isEmpty) {
      await prefs.remove(_assignmentIdKey);
      return;
    }
    await prefs.setString(_assignmentIdKey, assignmentId);
  }
}
