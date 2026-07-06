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
      test('effective grants resolve teacher actor', () {
        expect(context.grants.kind, 'teacher');
        expect(context.grants.actorId, isNotEmpty);
        expect(context.grants.schoolId, isNotEmpty);
      });

      test('teaching scope matches profile kind', () {
        if (profile.kind == TeacherPortalKind.subject) {
          expect(context.teachingScope.classSubjectIds, isNotEmpty);
        } else {
          expect(context.teachingScope.classGroupIds, isNotEmpty);
        }
      });

      test('teacher assignments include expected scope', () {
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
          final allClassIds = {...assignmentClassIds, ...classIdsFromSubjects};
          expect(
            allClassIds,
            containsAll(profile.expectedClassGroupIds),
          );
        }
      });

      test('academic years list includes configured year', () {
        expect(context.academicYears, isNotEmpty);
        expect(
          context.academicYears.any((year) => year['id'] == profile.academicYearId),
          isTrue,
        );
      });

      test('academic periods list for year', () {
        expect(context.academicPeriods, isNotEmpty);
      });

      test('assigned class groups resolve', () {
        expect(context.assignedClassGroups, isNotEmpty);
        for (final classGroup in context.assignedClassGroups) {
          expect(classGroup['name'], isNotEmpty);
        }
      });

      test('class subjects resolve for subject assignments', () {
        if (profile.kind == TeacherPortalKind.subject) {
          expect(context.classSubjects, isNotEmpty);
        }
      });
    });

    group('calendar / planning', () {
      test('timetable query returns events list per class', () {
        expect(timetableByClass, isNotEmpty);
        for (final entry in timetableByClass.entries) {
          expect(entry.value, isA<List<dynamic>>());
        }
      });

      test('timetable enrichment reads do not fail', () async {
        final events = timetableByClass[profile.primaryClassGroupId] ?? const [];
        await loadTimetableEnrichment(
          session.schoolClient,
          classGroupId: profile.primaryClassGroupId,
          academicYearId: profile.academicYearId,
          events: events,
        );
      });
    });

    group('evaluations', () {
      test('assessments and roster reads for primary class', () {
        expect(evaluationsProbe, isNotNull);
        final probe = evaluationsProbe!;
        expect(probe.enrollments, isNotEmpty);
        // Assessments may be empty in seed; list call succeeding is the probe.
        expect(probe.assessments, isA<List<Map<String, dynamic>>>());
        if (probe.assessments.isNotEmpty) {
          expect(probe.assessmentResults, isA<List<Map<String, dynamic>>>());
          expect(probe.classSubject, isNotNull);
          expect(probe.subject, isNotNull);
        }
      });

      test('createAssessment and recordAssessmentResult persist', () async {
        if (profile.kind != TeacherPortalKind.subject) {
          return;
        }
        final periodId = context.writeProbePeriodId;
        final classSubjectId = profile.expectedClassSubjectIds.first;
        if (periodId == null) {
          markTestSkipped('no academic period configured');
          return;
        }

        await probeTeacherEvaluationWrites(
          session.schoolClient,
          classGroupId: profile.primaryClassGroupId,
          classSubjectId: classSubjectId,
          periodId: periodId,
          academicYearId: profile.academicYearId,
        );
      });
    });

    group('session detail / attendance', () {
      test('lesson session detail chain resolves when class has lessons', () {
        if (sessionProbe == null) {
          markTestSkipped(
            'no lesson sessions for ${profile.primaryClassGroupId} in timetable window',
          );
          return;
        }
        final probe = sessionProbe!;
        expect(probe.lessonSession, isNotEmpty);
        expect(probe.enrollments, isNotEmpty);
        expect(probe.students, isNotEmpty);
        expect(probe.attendanceRows, isA<List<Map<String, dynamic>>>());
        expect(probe.classSubjectMatters, isA<List<Map<String, dynamic>>>());
        expect(probe.classSubjectProgress, isA<List<Map<String, dynamic>>>());
      });

      test(
        profile.kind == TeacherPortalKind.subject
            ? 'recordAttendance persists and reads back'
            : 'recordAttendance is forbidden for homeroom on subject lessons',
        () async {
          final probe = sessionProbe;
          final studentId = probe?.firstStudentId;
          if (probe == null || studentId == null) {
            markTestSkipped(
              'no lesson sessions for ${profile.primaryClassGroupId} in timetable window',
            );
            return;
          }

          if (profile.kind == TeacherPortalKind.subject) {
            await recordLessonAttendance(
              session.schoolClient,
              lessonSessionId: probe.lessonSessionId,
              studentId: studentId,
            );
            return;
          }

          try {
            await recordLessonAttendance(
              session.schoolClient,
              lessonSessionId: probe.lessonSessionId,
              studentId: studentId,
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
      test('students.list by enrollment ids for primary class', () async {
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
      });
    });

    group('negative authorization', () {
      test('staffMembers.get is forbidden for teacher actors', () async {
        try {
          await session.schoolClient.staffMembers.get(context.grants.actorId);
          fail('expected staff member read to be forbidden');
        } on ApiError catch (error) {
          expect(error.status, anyOf(403, 404));
        }
      });
    });
  });
}
