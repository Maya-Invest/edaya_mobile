import 'package:edaya_shared/edaya_shared.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SessionStorage extends AuthSessionStorage {
  static const _academicYearIdKey = 'teacher_academic_year_id';
  static const _classFilterIdKey = 'teacher_class_filter_id';

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

  Future<String?> readClassFilterId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_classFilterIdKey);
  }

  Future<void> writeClassFilterId(String? classGroupId) async {
    final prefs = await SharedPreferences.getInstance();
    if (classGroupId == null || classGroupId.isEmpty) {
      await prefs.remove(_classFilterIdKey);
      return;
    }
    await prefs.setString(_classFilterIdKey, classGroupId);
  }
}
