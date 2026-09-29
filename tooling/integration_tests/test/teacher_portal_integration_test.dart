@Tags(['integration'])
library;

import 'package:edaya_api_client/edaya_api_client.dart';
import 'package:edaya_integration_tests/edaya_integration_tests.dart';
import 'package:test/test.dart';

Future<void> main() async {
  final skip = await resolveIntegrationSkipReason();
  if (skip != null) {
    test('teacher portal integration', () {}, skip: skip);
    return;
  }

  for (final profile in TeacherPortalProfile.demoCiProfiles) {
    _teacherPortalSuite(profile);
  }
}

void _teacherPortalSuite(TeacherPortalProfile profile) {
  final baseConfig = IntegrationConfig.fromEnvironment();
  final config = baseConfig.withTeacherEmail(profile.email);

  late PortalSession session;
  late TeacherPortalContext context;
  late Map<String, List<dynamic>> timetableByClass;
  late TeacherSessionProbe? sessionProbe;
  late TeacherEvaluationsProbe? evaluationsProbe;

  group('teacher portal — ${profile.label}', () {
    setUpAll(() async {
      session = await PortalSession.signIn(
        config: config,
        actorKind: 'teacher',
        academicYearId: profile.academicYearId,
      );
      context = await bootstrapTeacherPortal(session, profile);

      final classGroupIds = context.assignedClassGroups
          .map((row) => row['id'] as String)
          .toSet();
      timetableByClass = await loadCalendarTimetables(
        session.schoolClient,
        classGroupIds,
      );

      sessionProbe = null;
      for (final classGroupId in classGroupIds) {
        final events = timetableByClass[classGroupId] ?? const [];
        final preferredSubjectId = profile.expectedClassSubjectIds.isEmpty
            ? null
            : profile.expectedClassSubjectIds.first;
        final lessonSessionId = await resolveLessonSessionIdForClass(
          session.schoolClient,
          classGroupId: classGroupId,
          timetableEvents: events,
          classSubjectId: profile.kind == TeacherPortalKind.subject
              ? preferredSubjectId
              : null,
        );
        if (lessonSessionId == null) {
          continue;
        }
        sessionProbe = await loadTeacherSessionDetail(
          session.schoolClient,
          lessonSessionId: lessonSessionId,
          classGroupId: classGroupId,
          academicYearId: profile.academicYearId,
        );
        break;
      }

      evaluationsProbe = null;
      final periodId = context.firstPeriodId;
      if (periodId != null) {
        evaluationsProbe = await loadTeacherEvaluations(
          session.schoolClient,
          classGroupId: profile.primaryClassGroupId,
          periodId: periodId,
          academicYearId: profile.academicYearId,
          classSubjectIds: profile.expectedClassSubjectIds,
        );
      }
    });

    group('bootstrap / context', () {
      test(
        '[api.teacher.${profile.kind.name}.effective-grants-resolve-teacher-actor] effective grants resolve teacher actor',
        () {
          expect(context.grants.kind, 'teacher');
          expect(context.grants.actorId, isNotEmpty);
          expect(context.grants.schoolId, isNotEmpty);
        },
      );

      test(
        '[api.teacher.${profile.kind.name}.teaching-scope-matches-profile-kind] teaching scope matches profile kind',
        () {
          if (profile.kind == TeacherPortalKind.subject) {
            expect(context.teachingScope.classSubjectIds, isNotEmpty);
          } else {
            expect(context.teachingScope.classGroupIds, isNotEmpty);
          }
        },
      );

      test(
        '[api.teacher.${profile.kind.name}.teacher-assignments-include-expected-scope] teacher assignments include expected scope',
        () {
          expect(context.teacherAssignments, isNotEmpty);
          if (profile.expectedClassSubjectIds.isNotEmpty) {
            final assignmentSubjectIds = context.teacherAssignments
                .map((row) => row['classSubjectId'] as String?)
                .whereType<String>()
                .toSet();
            expect(
              assignmentSubjectIds,
              containsAll(profile.expectedClassSubjectIds),
            );
          }
          if (profile.expectedClassGroupIds.isNotEmpty) {
            final assignmentClassIds = context.teacherAssignments
                .map((row) => row['classGroupId'] as String?)
                .whereType<String>()
                .toSet();
            final classIdsFromSubjects = context.classSubjects
                .map((row) => row['classGroupId'] as String?)
                .whereType<String>()
                .toSet();
            final allClassIds = {
              ...assignmentClassIds,
              ...classIdsFromSubjects,
            };
            expect(allClassIds, containsAll(profile.expectedClassGroupIds));
          }
        },
      );

      test(
        '[api.teacher.${profile.kind.name}.academic-years-list-includes-configured-year] academic years list includes configured year',
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
        '[api.teacher.${profile.kind.name}.academic-periods-list-for-year] academic periods list for year',
        () {
          expect(context.academicPeriods, isNotEmpty);
        },
      );

      test(
        '[api.teacher.${profile.kind.name}.assigned-class-groups-resolve] assigned class groups resolve',
        () {
          expect(context.assignedClassGroups, isNotEmpty);
          for (final classGroup in context.assignedClassGroups) {
            expect(classGroup['name'], isNotEmpty);
          }
        },
      );

      test(
        '[api.teacher.${profile.kind.name}.class-subjects-resolve-for-subject-assignments] class subjects resolve for subject assignments',
        () {
          if (profile.kind == TeacherPortalKind.subject) {
            expect(context.classSubjects, isNotEmpty);
          }
        },
      );
    });

    group('calendar / planning', () {
      test(
        '[api.teacher.${profile.kind.name}.timetable-query-returns-events-list-per-class] timetable query returns events list per class',
        () {
          expect(timetableByClass, isNotEmpty);
          for (final entry in timetableByClass.entries) {
            expect(entry.value, isA<List<dynamic>>());
          }
        },
      );

      test(
        '[api.teacher.${profile.kind.name}.timetable-enrichment-reads-do-not-fail] timetable enrichment reads do not fail',
        () async {
          final events =
              timetableByClass[profile.primaryClassGroupId] ?? const [];
          await loadTimetableEnrichment(
            session.schoolClient,
            classGroupId: profile.primaryClassGroupId,
            academicYearId: profile.academicYearId,
            events: events,
          );
        },
      );
    });

    group('evaluations', () {
      test(
        '[api.teacher.${profile.kind.name}.assessments-and-roster-reads-for-primary-class] assessments and roster reads for primary class',
        () {
          expect(evaluationsProbe, isNotNull);
          final probe = evaluationsProbe!;
          expect(probe.enrollments, isNotEmpty);
          expect(
            probe.assessments,
            isNotEmpty,
            reason: 'Assessment fixture is required',
          );
          expect(
            probe.assessmentResults,
            isNotEmpty,
            reason: 'Graded assessment fixture is required',
          );
          expect(probe.classSubject, isNotNull);
          expect(probe.subject, isNotNull);
        },
      );

      test(
        '[api.teacher.${profile.kind.name}.createassessment-and-recordassessmentresult-persist] createAssessment and recordAssessmentResult persist',
        () async {
          final periodId = context.writeProbePeriodId;
          final classSubjectId =
              context.classSubjects.firstWhere(
                    (row) => row['classGroupId'] == profile.primaryClassGroupId,
                  )['id']
                  as String;
          expect(
            periodId,
            isNotNull,
            reason: 'Academic period fixture is required',
          );

          await probeTeacherEvaluationWrites(
            session.schoolClient,
            classGroupId: profile.primaryClassGroupId,
            classSubjectId: classSubjectId,
            periodId: periodId!,
            academicYearId: profile.academicYearId,
          );
        },
      );
    });

    group('session detail / attendance', () {
      test(
        '[api.teacher.${profile.kind.name}.lesson-session-detail-chain-resolves-when-class-has-lessons] lesson session detail chain resolves when class has lessons',
        () {
          expect(
            sessionProbe,
            isNotNull,
            reason: 'Lesson session fixture is required',
          );
          final probe = sessionProbe!;
          expect(probe.lessonSession, isNotEmpty);
          expect(probe.enrollments, isNotEmpty);
          expect(probe.students, isNotEmpty);
          expect(probe.attendanceRows, isA<List<Map<String, dynamic>>>());
          expect(probe.classSubjectMatters, isA<List<Map<String, dynamic>>>());
          expect(probe.classSubjectProgress, isA<List<Map<String, dynamic>>>());
        },
      );

      test(
        profile.kind == TeacherPortalKind.subject
            ? '[api.teacher.subject.attendance-save] recordAttendance persists and reads back'
            : '[api.teacher.homeroom.attendance-denied] recordAttendance is forbidden for homeroom on subject lessons',
        () async {
          final probe = sessionProbe;
          final studentId = probe?.firstStudentId;
          expect(
            probe,
            isNotNull,
            reason: 'Lesson session fixture is required',
          );
          expect(
            studentId,
            isNotNull,
            reason: 'Enrolled student fixture is required',
          );

          if (profile.kind == TeacherPortalKind.subject) {
            await recordLessonAttendance(
              session.schoolClient,
              lessonSessionId: probe!.lessonSessionId,
              studentId: studentId!,
            );
            return;
          }

          try {
            await recordLessonAttendance(
              session.schoolClient,
              lessonSessionId: probe!.lessonSessionId,
              studentId: studentId!,
            );
            fail(
              'homeroom teacher must not record session attendance for another teacher\'s subject lesson',
            );
          } on ApiError catch (error) {
            expect(error.status, 403);
          }
        },
      );
    });

    group('roster via enrollments', () {
      test(
        '[api.teacher.${profile.kind.name}.students-list-by-enrollment-ids-for-primary-class] students.list by enrollment ids for primary class',
        () async {
          final enrollments = await session.schoolClient.enrollments.list(
            activeEnrollmentsForClass(
              profile.primaryClassGroupId,
              academicYearId: profile.academicYearId,
            ),
          );
          expect(enrollments, isNotEmpty);

          final studentIds = enrollments
              .map((row) => row['studentId'] as String?)
              .whereType<String>()
              .toList();
          final students = await session.schoolClient.students.list(
            entitiesByIds(studentIds),
          );
          expect(students, isNotEmpty);
        },
      );
    });

    group('negative authorization', () {
      test(
        '[api.teacher.${profile.kind.name}.staffmembers-get-is-forbidden-for-teacher-actors] staffMembers.get is forbidden for teacher actors',
        () async {
          try {
            await session.schoolClient.staffMembers.get(context.grants.actorId);
            fail('expected staff member read to be forbidden');
          } on ApiError catch (error) {
            expect(error.status, anyOf(403, 404));
          }
        },
      );
    });
  });
}
