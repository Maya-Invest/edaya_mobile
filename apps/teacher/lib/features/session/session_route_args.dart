import '../calendar/models/teacher_session.dart';
import 'session_detail_controller.dart';

class AttendanceFlowArgs {
  const AttendanceFlowArgs({required this.session, this.controller});

  final TeacherSession session;
  final SessionDetailController? controller;
}
