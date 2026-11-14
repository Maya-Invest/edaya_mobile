import 'package:edaya_shared/edaya_shared.dart';

import '../features/context/academic_year_controller.dart';
import '../features/context/student_context_controller.dart';

/// App-wide dependency lookup for code outside the widget tree.
abstract final class AppRuntime {
  static AppSessionController get session =>
      EdayaRootScope.find<AppSessionController>();

  static AcademicYearController get academicYear =>
      EdayaRootScope.find<AcademicYearController>();

  static StudentContextController get studentContext =>
      EdayaRootScope.find<StudentContextController>();

  static SchoolClientFactory get schoolClient =>
      EdayaRootScope.find<SchoolClientFactory>();
}
