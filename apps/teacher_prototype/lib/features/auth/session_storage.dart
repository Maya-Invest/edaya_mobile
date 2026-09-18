import 'package:edaya_shared/edaya_shared.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SessionStorage extends AuthSessionStorage {
  static const _academicYearIdKey = 'teacher_prototype_academic_year_id';
  static const _assignmentIdKey = 'teacher_prototype_assignment_id';

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
