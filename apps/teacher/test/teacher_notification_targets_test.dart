import 'package:edaya_shared/edaya_shared.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:edaya_teacher/navigation/teacher_notification_targets.dart';
import 'package:edaya_teacher/navigation/teacher_route_paths.dart';

void main() {
  test('resolveTeacherNotificationPath keeps Accueil shell routes', () {
    expect(
      resolveTeacherNotificationPath(
        const NotificationDeepLink(path: '/evaluations'),
      ),
      '/evaluations',
    );
    expect(
      resolveTeacherNotificationPath(const NotificationDeepLink(path: '/home')),
      '/home',
    );
  });

  test('resolveTeacherNotificationPath maps inbox and remaps teaching', () {
    expect(
      resolveTeacherNotificationPath(
        const NotificationDeepLink(
          path: '/inbox/message',
          data: {'deliveryId': 'd1'},
        ),
      ),
      '/inbox/message/d1',
    );
    expect(
      resolveTeacherNotificationPath(
        const NotificationDeepLink(path: '/teaching'),
      ),
      TeacherRoutePaths.classes,
    );
    expect(
      resolveTeacherNotificationPath(const NotificationDeepLink(path: '/fees')),
      TeacherRoutePaths.home,
    );
  });

  test('resolveTeacherNotificationPath remaps legacy extra-based paths', () {
    expect(
      resolveTeacherNotificationPath(
        const NotificationDeepLink(path: '/calendar/sessions/ls-1'),
      ),
      '/session/ls-1',
    );
    expect(
      resolveTeacherNotificationPath(
        const NotificationDeepLink(
          path: '/evaluations/assessments/asm-1/marks',
        ),
      ),
      '/evaluations/asm-1/marks',
    );
  });

  test(
    'resolveTeacherNotificationPath maps entity ids onto prototype routes',
    () {
      expect(
        resolveTeacherNotificationPath(
          const NotificationDeepLink(
            path: '/calendar',
            data: {'lessonSessionId': 'ls-1'},
          ),
        ),
        '/session/ls-1',
      );
      expect(
        resolveTeacherNotificationPath(
          const NotificationDeepLink(
            path: '/evaluations',
            data: {'assessmentId': 'asm-1'},
          ),
        ),
        '/evaluations/asm-1/marks',
      );
      expect(
        resolveTeacherNotificationPath(
          const NotificationDeepLink(
            path: '/report-cards',
            data: {'classGroupId': 'c1', 'periodId': 'p1', 'studentId': 's1'},
          ),
        ),
        '/evaluations/report-cards/c1/p1/s1',
      );
    },
  );
}
