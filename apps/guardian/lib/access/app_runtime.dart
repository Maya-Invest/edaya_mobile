import 'package:edaya_api_client/edaya_api_client.dart' as api;
import 'package:edaya_auth/edaya_auth.dart';

import '../features/auth/app_session_controller.dart';
import '../features/context/academic_year_controller.dart';
import '../features/context/student_context_controller.dart';
import 'root_scope.dart';
import 'school_client.dart';

class AppRuntime {
  AppRuntime._();

  static AppSessionController get session =>
      GuardianRootScope.find<AppSessionController>();

  static AcademicYearController get academicYear =>
      GuardianRootScope.find<AcademicYearController>();

  static StudentContextController get studentContext =>
      GuardianRootScope.find<StudentContextController>();

  static AuthClient get auth => GuardianRootScope.find<AuthClient>();

  static api.SchoolClient schoolClient() => createEdayaSchoolClient(
    auth,
    getAcademicYearId: () => academicYear.selectedYearId.value,
  );
}
