import 'package:edaya_api_client/edaya_api_client.dart';
import 'package:edaya_shared/edaya_shared.dart';
import 'package:edaya_teacher_legacy/features/calendar/models/teacher_session.dart';
import 'package:edaya_teacher_legacy/features/session/attendance_flow_page.dart';
import 'package:edaya_teacher_legacy/features/session/session_detail_controller.dart';
import 'package:edaya_teacher_legacy/features/session/session_route_args.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:levit_flutter/levit_flutter.dart';

SchoolClient _unimplementedSchoolClient() => throw UnimplementedError();

class _RecordingSessionDetailController extends SessionDetailController {
  _RecordingSessionDetailController({
    required super.session,
    required super.getAcademicYearId,
    required super.schoolClient,
    super.outboxStore,
  });

  @override
  Future<void> loadDetail() async {
    students(const []);
    errorMessage('');
  }
}

TeacherSession _lessonSession() {
  return TeacherSession.fromOccurrence(
    TimetableOccurrence(
      id: 'ls-1',
      kind: 'lesson',
      title: 'Math',
      subjectLabel: 'Math',
      startsAt: DateTime(2026, 4, 1, 9),
      endsAt: DateTime(2026, 4, 1, 10),
      classGroupId: 'cg-1',
      classSubjectId: 'cs-1',
    ),
    classLabel: '6A',
  );
}

Widget _attendanceFlowApp({
  required TeacherSession session,
  required SessionDetailController controller,
}) {
  return MaterialApp(
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: AppLocalizations.supportedLocales,
    home: AttendanceFlowPage(session: session, controller: controller),
  );
}

void main() {
  setUp(() {
    Levit.reset();
    configureTeacherOutboxStoreFactory(InMemoryTeacherOutboxStore.new);
  });

  tearDown(() {
    configureTeacherOutboxStoreFactory(null);
  });

  testWidgets(
    'AttendanceFlowPage reuses shared SessionDetailController without a new scope',
    (tester) async {
      final session = _lessonSession();
      late SessionDetailController sharedController;

      await tester.pumpWidget(
        LScope(
          name: 'attendance-flow-test',
          dependencyFactory: (scope) {
            sharedController = scope.put(
              () => _RecordingSessionDetailController(
                session: session,
                getAcademicYearId: () => '2025-ci',
                schoolClient: _unimplementedSchoolClient,
                outboxStore: InMemoryTeacherOutboxStore(),
              ),
            );
          },
          child: Builder(
            builder: (context) => _attendanceFlowApp(
              session: session,
              controller: sharedController,
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(AttendanceFlowPage), findsOneWidget);
      expect(find.textContaining('6A'), findsWidgets);
    },
  );

  test('AttendanceFlowArgs carries the shared controller reference', () {
    final session = _lessonSession();
    final controller = _RecordingSessionDetailController(
      session: session,
      getAcademicYearId: () => '2025-ci',
      schoolClient: _unimplementedSchoolClient,
      outboxStore: InMemoryTeacherOutboxStore(),
    );

    final args = AttendanceFlowArgs(session: session, controller: controller);

    expect(identical(args.controller, controller), isTrue);
  });
}
