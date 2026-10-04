import 'package:edaya_api_client/edaya_api_client.dart';

import '../config/api_base_url_config.dart';
import '../features/auth/app_session_controller.dart';
import 'teacher_outbox_models.dart';

TeacherOutboxContext? teacherOutboxContextForSession({
  required AppSessionController session,
  String? academicYearId,
}) {
  final user = session.user.value;
  final grants = session.grants.value;
  if (user == null || grants == null || grants.kind != 'teacher') {
    return null;
  }
  return TeacherOutboxContext(
    origin: ApiBaseUrlConfig.baseUrl,
    subjectId: user.id,
    actorKind: grants.kind,
    actorId: grants.actorId,
    schoolId: grants.schoolId,
    academicYearId: academicYearId,
  );
}

/// Network loss and server overload can be retried. Validation, authorization,
/// conflicts and local contract errors must stay visible and must not replay.
bool isRetryableTeacherWriteFailure(Object error) {
  if (error is ApiError) {
    return error.status == 408 || error.status == 429 || error.status >= 500;
  }
  if (error is StateError ||
      error is ArgumentError ||
      error is FormatException) {
    return false;
  }
  final text = error.toString();
  return text.contains('SocketException') ||
      text.contains('ClientException') ||
      text.contains('TimeoutException') ||
      text.contains('HandshakeException') ||
      text.contains('Connection') ||
      text.contains('offline');
}
