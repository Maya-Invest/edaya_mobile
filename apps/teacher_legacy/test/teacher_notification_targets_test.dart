import 'package:edaya_shared/edaya_shared.dart';
import 'package:edaya_teacher_legacy/navigation/teacher_notification_targets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('resolveTeacherNotificationPath keeps teacher shell routes', () {
    expect(
      resolveTeacherNotificationPath(
        const NotificationDeepLink(path: '/evaluations'),
      ),
      '/evaluations',
    );
  });

  test('resolveTeacherNotificationPath falls back for inbox and guardian routes', () {
    expect(
      resolveTeacherNotificationPath(
        const NotificationDeepLink(path: '/inbox/message', data: {'deliveryId': 'd1'}),
      ),
      '/calendar',
    );
    expect(
      resolveTeacherNotificationPath(
        const NotificationDeepLink(path: '/fees'),
      ),
      '/calendar',
    );
    expect(
      resolveTeacherNotificationPath(
        const NotificationDeepLink(path: '/academic'),
      ),
      '/calendar',
    );
  });

  test('resolveTeacherNotificationPath normalizes nested calendar routes', () {
    expect(
      resolveTeacherNotificationPath(
        const NotificationDeepLink(path: '/calendar/session-details'),
      ),
      '/calendar',
    );
  });

  test('resolveTeacherNotificationPath uses custom fallback', () {
    expect(
      resolveTeacherNotificationPath(
        const NotificationDeepLink(path: '/unknown'),
        fallback: '/teaching',
      ),
      '/teaching',
    );
  });

  test('resolveTeacherNotificationPath maps lesson session id', () {
    expect(
      resolveTeacherNotificationPath(
        const NotificationDeepLink(
          path: '/calendar',
          data: {'lessonSessionId': 'ls-1'},
        ),
      ),
      '/calendar/sessions/ls-1',
    );
  });

  test('resolveTeacherNotificationPath maps assessment id', () {
    expect(
      resolveTeacherNotificationPath(
        const NotificationDeepLink(
          path: '/evaluations',
          data: {'assessmentId': 'asm-1'},
        ),
      ),
      '/evaluations/assessments/asm-1/marks',
    );
  });

  test('resolveTeacherNotificationPath maps report card comment ids', () {
    expect(
      resolveTeacherNotificationPath(
        const NotificationDeepLink(
          path: '/report-cards',
          data: {'resultId': 'rc-1', 'studentId': 'stu-1'},
        ),
      ),
      '/report-cards/results/rc-1/students/stu-1/comment',
    );
  });
}
