@Tags(['integration'])
library;

import 'package:edaya_api_client/edaya_api_client.dart';
import 'package:edaya_integration_tests/edaya_integration_tests.dart';
import 'package:test/test.dart';

Future<void> main() async {
  final skip = await resolveIntegrationSkipReason();
  if (skip != null) {
    test('guardian portal integration', () {}, skip: skip);
    return;
  }

  for (final profile in GuardianPortalProfile.demoCiProfiles) {
    _guardianPortalSuite(profile);
  }
}

void _guardianPortalSuite(GuardianPortalProfile profile) {
  final baseConfig = IntegrationConfig.fromEnvironment();
  final config = baseConfig.withGuardianEmail(profile.email);

  late PortalSession session;
  late GuardianPortalContext context;
  late GuardianAcademicProbe academicProbe;
  late GuardianFeesProbe feesProbe;
  late GuardianCalendarProbe calendarProbe;
  late GuardianInboxProbe inboxProbe;

  group('guardian portal — ${profile.label}', () {
    setUpAll(() async {
      session = await PortalSession.signIn(
        config: config,
        actorKind: 'guardian',
        academicYearId: profile.academicYearId,
      );
      context = await bootstrapGuardianPortal(session, profile);

      academicProbe = await loadGuardianAcademicData(
        session.schoolClient,
        studentId: profile.primaryStudentId,
        classGroupId: profile.primaryClassGroupId,
        academicYearId: profile.academicYearId,
      );
      feesProbe = await loadGuardianFeesData(
        session.schoolClient,
        studentId: profile.primaryStudentId,
        academicYearId: profile.academicYearId,
      );
      calendarProbe = await loadGuardianCalendarData(
        session.schoolClient,
        classGroupId: profile.primaryClassGroupId,
        academicYearId: profile.academicYearId,
      );
      inboxProbe = await loadGuardianInbox(
        session.schoolClient,
        inboxSubjectId: context.inboxSubjectId,
      );
    });

    group('bootstrap / context', () {
      test('effective grants resolve guardian actor', () {
        expect(context.grants.kind, 'guardian');
        expect(context.grants.actorId, profile.guardianId);
        expect(context.grants.schoolId, isNotEmpty);
      });

      test('guardian scope includes linked students', () {
        final scope = context.grants.guardianScope;
        expect(scope, isNotNull);
        expect(scope!.studentIds, containsAll(profile.expectedStudentIds));
        expect(scope.classGroupIds, isNotEmpty);
      });

      test('guardian links resolve linked students', () {
        expect(
          context.linkedStudentIds,
          containsAll(profile.expectedStudentIds),
        );
        expect(
          context.linkedStudents,
          hasLength(profile.expectedStudentIds.length),
        );
      });

      test('academic years list includes configured year', () {
        expect(context.academicYears, isNotEmpty);
        expect(
          context.academicYears.any(
            (year) => year['id'] == profile.academicYearId,
          ),
          isTrue,
        );
      });

      test('primary student enrollment and class group resolve', () {
        expect(
          context.primaryEnrollment['studentId'],
          profile.primaryStudentId,
        );
        expect(context.primaryClassGroup['id'], profile.primaryClassGroupId);
        expect(context.primaryClassGroup['name'], isNotEmpty);
      });

      test('guardian profile read succeeds', () {
        expect(context.guardianProfile['id'], profile.guardianId);
        expect(context.guardianProfile['firstName'], isNotEmpty);
      });

      test('inbox subject id aligns with auth user id', () {
        expect(context.inboxSubjectId, isNotEmpty);
        expect(context.inboxSubjectId, context.authUserId);
      });
    });

    group('academic', () {
      test('periods, class subjects, and curriculum reads succeed', () {
        expect(academicProbe.academicPeriods, isNotEmpty);
        expect(academicProbe.classSubjects, isNotEmpty);
        expect(academicProbe.subjects, isNotEmpty);
        expect(
          academicProbe.classSubjectMatters,
          isA<List<Map<String, dynamic>>>(),
        );
        expect(academicProbe.subjectMatters, isA<List<Map<String, dynamic>>>());
      });

      test('assessments and student results list without error', () {
        expect(academicProbe.assessments, isA<List<Map<String, dynamic>>>());
        expect(
          academicProbe.assessmentResults,
          isA<List<Map<String, dynamic>>>(),
        );
      });

      test('published report cards are visible for primary student', () {
        if (profile.primaryStudentId !=
            GuardianPortalProfile.mariamKone.primaryStudentId) {
          return;
        }
        expect(academicProbe.reportCards, isNotEmpty);
        expect(
          academicProbe.reportCards.every(
            (row) => row['status'] == 'published',
          ),
          isTrue,
        );
      });

      test(
        'report card detail read succeeds when published cards exist',
        () async {
          if (academicProbe.reportCards.isEmpty) {
            markTestSkipped('no published report cards seeded for student');
            return;
          }
          final reportCardId = academicProbe.reportCards.first['id'] as String;
          final detail = await session.schoolClient.results.get(reportCardId);
          expect(detail['id'], reportCardId);
          expect(detail['studentId'], profile.primaryStudentId);
        },
      );
    });

    group('fees', () {
      test('student fees and payments list without error', () {
        expect(feesProbe.studentFees, isA<List<Map<String, dynamic>>>());
        expect(feesProbe.payments, isA<List<Map<String, dynamic>>>());
      });

      test('primary student has billed fees for configured academic year', () {
        if (profile.primaryStudentId !=
            GuardianPortalProfile.mariamKone.primaryStudentId) {
          return;
        }
        expect(feesProbe.studentFees, isNotEmpty);
        expect(
          feesProbe.studentFees.every(
            (row) => row['academicYearId'] == profile.academicYearId,
          ),
          isTrue,
        );
      });

      test('fee names resolve when student fees exist', () async {
        if (feesProbe.studentFees.isEmpty) {
          return;
        }
        final feeId = feesProbe.studentFees.first['feeId'] as String;
        expect(feesProbe.feeNamesById[feeId], isNotEmpty);
      });
    });

    group('calendar / planning', () {
      test('timetable and school events reads succeed', () {
        expect(calendarProbe.timetableEvents, isA<List<dynamic>>());
        expect(calendarProbe.calendarEvents, isA<List<Map<String, dynamic>>>());
      });

      test('student attendance list succeeds', () async {
        final rows = await loadGuardianAttendance(
          session.schoolClient,
          studentId: profile.primaryStudentId,
        );
        expect(rows, isA<List<Map<String, dynamic>>>());
      });
    });

    group('inbox', () {
      test('message deliveries list for guardian subject id', () {
        expect(inboxProbe.deliveries, isA<List<Map<String, dynamic>>>());
      });

      test('markDeliveryRead persists when unread delivery exists', () async {
        final deliveryId = inboxProbe.unreadDeliveryId;
        if (deliveryId == null) {
          markTestSkipped(
            'no unread deliveries seeded for guardian inbox subject',
          );
          return;
        }
        await probeGuardianMarkDeliveryRead(
          session.schoolClient,
          deliveryId: deliveryId,
        );
      });
    });

    group('negative authorization', () {
      test('createAssessment is forbidden for guardian actors', () async {
        final periodId = academicProbe.academicPeriods.first['id'] as String;
        final classSubjectId =
            academicProbe.classSubjects.first['id'] as String;
        await expectGuardianCannotCreateAssessment(
          session.schoolClient,
          classGroupId: profile.primaryClassGroupId,
          classSubjectId: classSubjectId,
          periodId: periodId,
        );
      });

      test('staffMembers.get is forbidden for guardian actors', () async {
        try {
          await session.schoolClient.staffMembers.get(context.grants.actorId);
          fail('expected staff member read to be forbidden');
        } on ApiError catch (error) {
          expect(error.status, anyOf(403, 404));
        }
      });

      test('teachers.list is forbidden or empty for guardian actors', () async {
        try {
          final teachers = await session.schoolClient.teachers.list({});
          expect(teachers, isEmpty);
        } on ApiError catch (error) {
          expect(error.status, 403);
        }
      });
    });
  });
}
