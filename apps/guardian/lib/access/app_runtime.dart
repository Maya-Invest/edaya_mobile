import 'package:edaya_api_client/edaya_api_client.dart' as api;
import 'package:edaya_auth/edaya_auth.dart';
import 'package:edaya_shared/edaya_shared.dart';

import '../features/context/academic_year_controller.dart';
import '../features/context/student_context_controller.dart';

class AppRuntime {
  AppRuntime._();

  static AppSessionController get session =>
      EdayaRootScope.find<AppSessionController>();

  static AcademicYearController get academicYear =>
      EdayaRootScope.find<AcademicYearController>();

  static StudentContextController get studentContext =>
      EdayaRootScope.find<StudentContextController>();

  static AuthClient get auth => EdayaRootScope.find<AuthClient>();

  static api.SchoolClient schoolClient() => createEdayaSchoolClient(
    auth,
    getAcademicYearId: () => academicYear.selectedYearId.value,
  );
}
