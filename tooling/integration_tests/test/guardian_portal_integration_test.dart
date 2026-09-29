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

  _guardianPortalSuite(GuardianPortalProfile.mariamKone);
  _koffiYaoScope();
}

void _guardianPortalSuite(GuardianPortalProfile profile) {
  final baseConfig = IntegrationConfig.fromEnvironment();
  final config = baseConfig.withGuardianEmail(profile.email);

  late PortalSession session;
  late GuardianPortalContext context;
  late GuardianAcademicProbe academicProbe;
  late GuardianFeesProbe feesProbe;

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
    });

    group('bootstrap / context', () {
      test(
        '[api.guardian.${profile.guardianId}.effective-grants-resolve-guardian-actor] effective grants resolve guardian actor',
        () {
          expect(context.grants.kind, 'guardian');
          expect(context.grants.actorId, profile.guardianId);
          expect(context.grants.schoolId, isNotEmpty);
        },
      );

      test(
        '[api.guardian.${profile.guardianId}.guardian-scope-includes-linked-students] guardian scope includes linked students',
        () {
          final scope = context.grants.guardianScope;
          expect(scope, isNotNull);
          expect(scope!.studentIds, containsAll(profile.expectedStudentIds));
        },
      );

      test(
        '[api.guardian.${profile.guardianId}.guardian-links-resolve-linked-students] guardian links resolve linked students',
        () {
          expect(
            context.linkedStudentIds,
            containsAll(profile.expectedStudentIds),
          );
          expect(
            context.linkedStudents,
            hasLength(profile.expectedStudentIds.length),
          );
        },
      );

      test(
        '[api.guardian.${profile.guardianId}.academic-years-list-includes-configured-year] academic years list includes configured year',
        () {
          expect(context.academicYears, isNotEmpty);
          expect(
            context.academicYears.any(
              (year) => year['id'] == profile.academicYearId,
            ),
            isTrue,
          );
        },
      );

      test(
        '[api.guardian.${profile.guardianId}.primary-student-enrollment-and-class-group-resolve] primary student enrollment and class group resolve',
        () {
          expect(
            context.primaryEnrollment['studentId'],
            profile.primaryStudentId,
          );
          expect(context.primaryClassGroup['id'], profile.primaryClassGroupId);
          expect(context.primaryClassGroup['name'], isNotEmpty);
        },
      );

      test(
        '[api.guardian.${profile.guardianId}.guardian-profile-read-succeeds] guardian profile read succeeds',
        () {
          expect(context.guardianProfile['id'], profile.guardianId);
          expect(context.guardianProfile['firstName'], isNotEmpty);
        },
      );

      test(
        '[api.guardian.${profile.guardianId}.inbox-subject-id-aligns-with-auth-user-id] inbox subject id aligns with auth user id',
        () {
          expect(context.inboxSubjectId, isNotEmpty);
          expect(context.inboxSubjectId, context.authUserId);
        },
      );
    });

    group('academic', () {
      test(
        '[api.guardian.${profile.guardianId}.periods-class-subjects-and-curriculum-reads-succeed] periods, class subjects, and curriculum reads succeed',
        () {
          expect(academicProbe.academicPeriods, isNotEmpty);
          expect(academicProbe.classSubjects, isNotEmpty);
          expect(academicProbe.subjects, isNotEmpty);
        },
      );

      test(
        '[api.guardian.${profile.guardianId}.published-report-cards-are-visible-for-primary-student] published report cards are visible for primary student',
        () {
          expect(
            academicProbe.reportCards,
            isNotEmpty,
            reason: 'Published report card fixture is required',
          );
          expect(
            academicProbe.reportCards.every(
              (row) => row['status'] == 'published',
            ),
            isTrue,
          );
        },
      );

      test(
        '[api.guardian.${profile.guardianId}.report-card-detail-read-succeeds-when-published-cards-exist] report card detail read succeeds when published cards exist',
        () async {
          expect(
            academicProbe.reportCards,
            isNotEmpty,
            reason: 'Published report card fixture is required',
          );
          final reportCardId = academicProbe.reportCards.first['id'] as String;
          final detail = await session.schoolClient.results.get(reportCardId);
          expect(detail['id'], reportCardId);
          expect(detail['studentId'], profile.primaryStudentId);
        },
      );
    });

    group('fees', () {
      test(
        '[api.guardian.${profile.guardianId}.student-finance-summary-charges-and-payments-load-without-error] student finance summary, charges and payments load without error',
        () {
          expect(feesProbe.summary['academicYearId'], profile.academicYearId);
        },
      );

      test(
        '[api.guardian.${profile.guardianId}.primary-student-charges-belong-to-the-configured-academic-year] primary student charges belong to the configured academic year',
        () {
          expect(
            feesProbe.studentCharges.every(
              (row) => row['academicYearId'] == profile.academicYearId,
            ),
            isTrue,
          );
        },
      );
    });

    group('inbox', () {
      test(
        '[api.guardian.${profile.guardianId}.markdeliveryread-persists-when-unread-delivery-exists] markDeliveryRead persists when unread delivery exists',
        () async {
          final deliveryId = await seedGuardianInboxProbeDelivery(
            baseConfig: baseConfig,
            guardianClient: session.schoolClient,
            schoolId: context.grants.schoolId,
            guardianId: profile.guardianId,
            inboxSubjectId: context.inboxSubjectId,
          );
          await probeGuardianMarkDeliveryRead(
            session.schoolClient,
            deliveryId: deliveryId,
          );
        },
      );
    });

    group('negative authorization', () {
      test(
        '[api.guardian.${profile.guardianId}.createassessment-is-forbidden-for-guardian-actors] createAssessment is forbidden for guardian actors',
        () async {
          final periodId = academicProbe.academicPeriods.first['id'] as String;
          final classSubjectId =
              academicProbe.classSubjects.first['id'] as String;
          await expectGuardianCannotCreateAssessment(
            session.schoolClient,
            classGroupId: profile.primaryClassGroupId,
            classSubjectId: classSubjectId,
            periodId: periodId,
          );
        },
      );

      test(
        '[api.guardian.${profile.guardianId}.staffmembers-get-is-forbidden-for-guardian-actors] staffMembers.get is forbidden for guardian actors',
        () async {
          try {
            await session.schoolClient.staffMembers.get(context.grants.actorId);
            fail('expected staff member read to be forbidden');
          } on ApiError catch (error) {
            expect(error.status, anyOf(403, 404));
          }
        },
      );

      test(
        '[api.guardian.${profile.guardianId}.teachers-list-is-forbidden-or-empty-for-guardian-actors] teachers.list is forbidden or empty for guardian actors',
        () async {
          try {
            final teachers = await session.schoolClient.teachers.list({});
            expect(teachers, isEmpty);
          } on ApiError catch (error) {
            expect(error.status, 403);
          }
        },
      );
    });
  });
}

void _koffiYaoScope() {
  final profile = GuardianPortalProfile.koffiYao;
  final config = IntegrationConfig.fromEnvironment().withGuardianEmail(
    profile.email,
  );

  group('guardian portal — ${profile.label}', () {
    late PortalSession session;
    late GuardianPortalContext context;

    setUpAll(() async {
      session = await PortalSession.signIn(
        config: config,
        actorKind: 'guardian',
        academicYearId: profile.academicYearId,
      );
      context = await bootstrapGuardianPortal(session, profile);
    });

    test(
      '[api.guardian.${profile.guardianId}.guardian-scope-contains-every-linked-student] guardian scope contains every linked student',
      () {
        expect(
          context.grants.guardianScope?.studentIds,
          containsAll(profile.expectedStudentIds),
        );
      },
    );
  });
}
