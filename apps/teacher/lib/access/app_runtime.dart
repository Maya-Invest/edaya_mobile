import 'package:edaya_api_client/edaya_api_client.dart' as api;
import 'package:edaya_auth/edaya_auth.dart';

import '../features/auth/app_session_controller.dart';
import '../features/calendar/calendar_controller.dart';
import '../features/context/academic_year_controller.dart';
import '../features/context/staff_context_controller.dart';
import '../features/evaluations/evaluations_controller.dart';
import 'root_scope.dart';
import 'school_client.dart';

class AppRuntime {
  AppRuntime._();

  static AppSessionController get session =>
      TeacherRootScope.find<AppSessionController>();

  static AcademicYearController get academicYear =>
      TeacherRootScope.find<AcademicYearController>();

  static StaffContextController get staffContext =>
      TeacherRootScope.find<StaffContextController>();

  static CalendarController get calendar =>
      TeacherRootScope.find<CalendarController>();

  static EvaluationsController get evaluations =>
      TeacherRootScope.find<EvaluationsController>();

  static AuthClient get auth => TeacherRootScope.find<AuthClient>();

  static api.SchoolClient schoolClient() => createEdayaSchoolClient(
    auth,
    getAcademicYearId: () => academicYear.selectedYearId.value,
  );
}
