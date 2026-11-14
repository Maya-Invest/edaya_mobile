import 'package:edaya_shared/edaya_shared.dart';

import '../features/context/academic_year_controller.dart';
import '../features/context/teacher_context_controller.dart';

/// App-wide dependency lookup for code outside the widget tree.
abstract final class AppRuntime {
  static AppSessionController get session =>
      EdayaRootScope.find<AppSessionController>();

  static AcademicYearController get academicYear =>
      EdayaRootScope.find<AcademicYearController>();

  static TeacherContextController get teacherContext =>
      EdayaRootScope.find<TeacherContextController>();

  static SchoolClientFactory get schoolClient =>
      EdayaRootScope.find<SchoolClientFactory>();
}
