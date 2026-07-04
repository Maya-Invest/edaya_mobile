import 'package:edaya_auth/edaya_auth.dart';
import 'package:edaya_shared/edaya_shared.dart';

import '../features/context/academic_year_controller.dart';
import '../features/context/staff_context_controller.dart';

/// App-wide dependency lookup for code outside the widget tree.
abstract final class AppRuntime {
  static AppSessionController get session =>
      EdayaRootScope.find<AppSessionController>();

  static AcademicYearController get academicYear =>
      EdayaRootScope.find<AcademicYearController>();

  static StaffContextController get staffContext =>
      EdayaRootScope.find<StaffContextController>();

  static AuthClient get auth => EdayaRootScope.find<AuthClient>();

  static SchoolClientFactory get schoolClient =>
      EdayaRootScope.find<SchoolClientFactory>();
}
