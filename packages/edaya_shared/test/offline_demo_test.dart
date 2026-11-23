import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:edaya_api_client/edaya_api_client.dart';
import 'package:edaya_shared/edaya_shared.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;
  late Directory directory;
  late DemoStore store;

  setUp(() async {
    SharedPreferences.setMockInitialValues({
      'edaya_selected_actor_id': 'real-actor',
    });
    directory = await Directory.systemTemp.createTemp('edaya-school-');
    await databaseFactory.setDatabasesPath(directory.path);
  });
  tearDown(() async {
    if (!store.closed) await store.erase();
    await directory.delete(recursive: true);
  });

  test(
    'a version-one demo updates captured grade wording and keeps saved work',
    () async {
      store = await DemoStore.start(DemoRole.teacher);
      final id = store.id;
      await store.close();
      final db = await databaseFactory.openDatabase(
        '${directory.path}/edaya-demo-$id.db',
      );
      final row = (await db.query('school')).single;
      final school = jsonDecode(row['body'] as String) as Map;
      final report = (school['results'] as List).firstWhere(
        (r) => r['status'] == 'published',
      );
      final section = report['sectionResults'][0];
      expect(section['grading']['mention']['label'], 'Très bien');
      for (final record in [report, section]) {
        record['grading']['mention'] = {
          'code': 'TB',
          'label': 'Très bonne maîtrise des compétences évaluées',
        };
      }
      section['comment'] = 'Commentaire conservé';
      await db.update('school', {'body': jsonEncode(school)}, where: 'id = 1');
      await db.setVersion(1);
      await db.close();
      store = (await DemoStore.resume(DemoRole.teacher))!;
      expect(store.id, id);
      final archive = createEdayaSchoolClient(
        store.auth,
        getAcademicYearId: () => 'demo-2025',
      );
      final updated = await archive.results.get(report['id'] as String);
      expect(updated['grading']['mention'], demoGrade(16)['mention']);
      expect(
        updated['sectionResults'][0]['grading']['mention'],
        demoGrade(16)['mention'],
      );
      expect(updated['sectionResults'][0]['comment'], 'Commentaire conservé');
    },
  );

  test(
    'guardian stays local, resumes edits and removes only demo data on exit',
    () async {
      store = await DemoStore.start(DemoRole.guardian);
      final client = createEdayaSchoolClient(store.auth);
      final scope = (await client.effectiveGrants()).guardianScope!;
      await expectLater(
        client.getClassReportRoster({
          'classGroupId': 'demo-class-b',
          'periodId': 'demo-t1',
        }),
        throwsA(isA<ApiError>().having((e) => e.status, 'status', 403)),
      );
      expect(scope.studentIds, unorderedEquals(['demo-amina', 'demo-youssef']));
      expect(await client.students.listAll(), hasLength(2));
      final placements = await client.enrollments.listAll({
        'studentId': 'demo-amina',
      });
      expect(
        placements.map((e) => e['academicYearId']).toSet(),
        containsAll(['demo-2025', 'demo-2026']),
      );
      final choices = await client.getGuardianChildChoices({});
      expect(choices['school']['timeZone'], 'Africa/Abidjan');
      expect(
        (choices['children'] as List).map((row) => row['id']),
        unorderedEquals(scope.studentIds),
      );
      final year = 'demo-2026';
      final occurrenceInput = {
        'studentId': 'demo-amina',
        'academicYearId': year,
        'occurrenceId': 'demo-math-a-lesson-0',
        'kind': 'assessment',
      };
      final event = (await client.getGuardianOccurrenceDetail(
        occurrenceInput,
      ))['occurrence'];
      expect(event['kind'], 'lesson');
      expect(
        event['logbook']['chapters'].first['name'],
        'Fractions et proportions',
      );
      expect(
        (await client.getGuardianOccurrenceDetail({
          ...occurrenceInput,
          'studentId': 'demo-youssef',
        }))['occurrence'],
        isNull,
      );
      expect(
        (await client.getGuardianOccurrenceDetail({
          ...occurrenceInput,
          'academicYearId': 'demo-2025',
        }))['occurrence'],
        isNull,
      );
      final pupil = {'studentId': 'demo-amina', 'academicYearId': year};
      final balance = await client.getGuardianFeesSummary(pupil);
      expect(balance['expected'], 50000);
      expect(balance['paid'], 30000);
      expect(balance['outstanding'], 20000);
      final page = await client.getGuardianSettlements({...pupil, 'limit': 1});
      expect(page['accountId'], balance['accountId']);
      expect(page['charges'].single['settlementCount'], 1);
      expect(page['payments'].single['chargeLabels'], [
        'Scolarité du trimestre',
      ]);
      expect(page['nextPaymentCursor'], isNull);
      final archivedFees = await client.getGuardianSettlements({
        ...pupil,
        'academicYearId': 'demo-2025',
      });
      expect(archivedFees['accountId'], isNull);
      expect(archivedFees['payments'], isEmpty);
      await expectLater(
        client.getGuardianSettlements({...pupil, 'cursor': 'invalid'}),
        throwsA(isA<ApiError>()),
      );
      final paymentInput = {
        'studentId': 'demo-amina',
        'academicYearId': year,
        'paymentId': 'demo-amina-receipt',
      };
      final receiptDetail = (await client.getGuardianPaymentDetail(
        paymentInput,
      ))['payment'];
      expect(receiptDetail['amount'], 30000);
      expect(receiptDetail['chargeLabels'], ['Scolarité du trimestre']);
      expect(
        (await client.getGuardianPaymentDetail({
          ...paymentInput,
          'studentId': 'demo-youssef',
        }))['payment'],
        isNull,
      );
      expect(
        (await client.getGuardianPaymentDetail({
          ...paymentInput,
          'academicYearId': 'demo-2025',
        }))['payment'],
        isNull,
      );
      final group = placements.firstWhere(
        (p) => p['academicYearId'] == year,
      )['classGroupId'];
      final selected = {
        'academicYearId': year,
        'day': '2026-11-10',
        'studentId': 'demo-amina',
        'classGroupId': group,
      };
      final highlights = await client.getGuardianHighlights(selected);
      expect(highlights['unavailable'], isEmpty);
      expect(highlights['cards']['balance'], 20000);
      expect(highlights['cards']['surveys'], 1);
      expect(highlights['attendance'], isA<Map>());
      await expectLater(
        client.getGuardianHighlights({...selected, 'studentId': 'demo-fatou'}),
        throwsA(isA<ApiError>()),
      );
      final sessions = await client.runQuery('get-student-session-history', {
        'studentId': 'demo-amina',
        'academicYearId': 'demo-2026',
        'startDate': '2026-11-01',
        'endDate': '2026-11-10',
      });
      expect(sessions['entries'], isA<List>());
      expect(sessions['timeZone'], 'Africa/Abidjan');
      expect(sessions['hasMore'], true);
      await expectLater(
        client.students.get('demo-fatou'),
        throwsA(isA<ApiError>()),
      );
      final finance = await client.getStudentFinanceSummary({
        'studentId': 'demo-amina',
      });
      expect(finance['outstanding'], 20000);
      final history = await client.getPaymentSettlementHistory({
        'accountId': finance['accountId'],
      });
      expect(history['payments'], hasLength(1));
      final archive = createEdayaSchoolClient(
        store.auth,
        getAcademicYearId: () => 'demo-2025',
      );
      final report = await archive.runQuery('get-guardian-period-results', {
        'studentId': 'demo-amina',
        'periodId': 'demo-archive-period',
      });
      final overview = await client.getGuardianPeriodResults({
        'studentId': 'demo-amina',
        'periodId': 'demo-t1',
      });
      final mark = (overview['marks'] as List).first as Map;
      final detail = await client.getGuardianAssessmentResult({
        'studentId': 'demo-amina',
        'assessmentId': mark['assessmentId'],
      });
      for (final key in ['score', 'rank', 'participantCount', 'grading']) {
        expect(mark[key], isNotNull);
        expect(detail['mark'][key], mark[key]);
      }
      final archived = await archive.results.list({'studentId': 'demo-amina'});
      expect(archived.single['status'], 'published');
      final published = await archive.getGuardianPeriodResults({
        'studentId': 'demo-amina',
        'periodId': archived.single['periodId'],
      });
      expect(published['reportId'], archived.single['id']);
      expect(report['state'], 'provisional');
      final docs = await listDocumentIssuances(
        archive,
        studentId: 'demo-amina',
      );
      expect(docs, isNotEmpty);
      for (final doc in docs) {
        final record = await archive.getDocumentIssuance({'id': doc.id});
        final bytes = await rootBundle.load(
          'packages/edaya_shared/assets/demo/${record['asset']}.pdf',
        );
        expect(
          String.fromCharCodes(bytes.buffer.asUint8List().take(4)),
          '%PDF',
        );
      }
      final survey = (await listGuardianFamilyFeedbackCampaigns(client))
          .where((s) => s.slotState == 'open' && s.studentId == 'demo-amina')
          .single;
      final receipt = await client.submitFamilyFeedbackResponse({
        'studentId': survey.studentId,
        'campaignId': survey.campaignId,
        'answers': {'clarity': 4},
      });
      expect(receipt['slotState'], 'completed');
      final photo = await uploadProfilePhoto(
        client: client,
        schoolId: 'demo-school',
        ownerKind: 'student',
        ownerId: 'demo-amina',
        jpegBytes: Uint8List.fromList([1, 2, 3]),
      );
      final cmd = {
        'requestId': 'photo-1',
        'studentId': 'demo-amina',
        'attachmentId': photo.attachmentId,
      };
      final submission = await client.submitStudentPhoto(cmd);
      expect((await client.submitStudentPhoto(cmd))['id'], submission['id']);
      final photoProfile = await client.getGuardianChildPhoto(pupil);
      expect(photoProfile['student']['id'], pupil['studentId']);
      expect(photoProfile['decision']['ownSubmission']['id'], submission['id']);
      final familyPapers = await client.getGuardianPapers(pupil);
      expect(
        (familyPapers['items'] as List).every(
          (row) => isLeftoverFamilyPaper(row['templateKey'] as String),
        ),
        isTrue,
      );
      await expectLater(
        client.getGuardianPapers({...pupil, 'academicYearId': 'different'}),
        throwsA(isA<ApiError>()),
      );

      await expectLater(
        store.auth.httpClient.get(Uri.https('example.com', '/')),
        throwsStateError,
      );
      final prefs = await SharedPreferences.getInstance();
      final firstId = store.id;
      await prefs.setString('${store.prefix}test', 'sample');
      await store.close();
      store = (await DemoStore.resume(DemoRole.guardian))!;
      expect(store.id, firstId);
      expect(await store.readMedia(photo.attachmentId), [1, 2, 3]);
      final resumed = createEdayaSchoolClient(store.auth);
      expect(
        (await resumed.studentPhotoSubmissions.list({
          'studentId': 'demo-amina',
        })).single['status'],
        'pending',
      );
      await store.erase();
      expect(await DemoStore.resume(DemoRole.guardian), isNull);
      expect(prefs.getKeys(), {'edaya_selected_actor_id'});
      expect(prefs.getString('edaya_selected_actor_id'), 'real-actor');
      store = await DemoStore.start(DemoRole.guardian);
      expect(store.id, isNot(firstId));
      expect(
        await createEdayaSchoolClient(
          store.auth,
        ).studentPhotoSubmissions.list({'studentId': 'demo-amina'}),
        isEmpty,
      );
      expect(await store.readMedia(photo.attachmentId), isNull);
    },
  );

  test(
    'homeroom report roster reads saved cards and reflects comment edits',
    () async {
      store = await DemoStore.start(DemoRole.teacher);
      final client = createEdayaSchoolClient(store.auth);
      const selection = {'classGroupId': 'demo-class-b', 'periodId': 'demo-t1'};
      final page = await client.getClassReportRoster(selection);
      final pupils = (page['items'] as List).cast<Map>();
      expect(pupils.map((p) => p['studentName']), ['Inès Yao', 'Youssef Koné']);
      expect(page['matchedPupils'], 2);
      expect(page['nextCursor'], isNull);
      final report = pupils.first['report'] as Map;
      expect(report['status'], 'draft');
      expect(report['overallAverage'], 15);
      expect(report['hasComment'], isTrue);
      expect(page['totals'], {
        'generatedCount': 2,
        'publishedCount': 0,
        'commentFilledCount': 2,
        'remainingFields': 0,
      });
      final draft = await client.results.get(report['id'] as String);
      await client.writeHomeroomReportComment({
        'id': draft['id'],
        'expectedVersion': draft['version'],
        'teacherComment': ' ',
        'requestId': 'demo-clear-comment',
      });
      final filtered = await client.getClassReportRoster({
        ...selection,
        'q': 'INÈS',
        'status': 'draft',
      });
      expect(filtered['matchedPupils'], 1);
      expect(filtered['items'].single['report']['hasComment'], isFalse);
      final summary = await client.getClassReportRoster({
        ...selection,
        'view': 'summary',
      });
      expect(summary['items'], isEmpty);
      expect(summary['totals'], filtered['totals']);
      expect(summary['totals']['remainingFields'], 1);
      expect(summary['totals']['commentFilledCount'], 1);
      expect(
        (await client.getClassReportRoster({
          ...selection,
          'classGroupId': 'demo-class-a',
          'view': 'summary',
        }))['totals']['generatedCount'],
        3,
      );
      await expectLater(
        client.getClassReportRoster({
          ...selection,
          'periodId': 'demo-archive-t3',
        }),
        throwsA(isA<ApiError>().having((e) => e.status, 'status', 403)),
      );
    },
  );

  test('teacher Progress reads the selected demo class logbook', () async {
    store = await DemoStore.start(DemoRole.teacher);
    final client = createEdayaSchoolClient(store.auth);
    const selection = {
      'classGroupId': 'demo-class-b',
      'classSubjectId': 'demo-math-b',
      'view': 'recorded',
    };
    final recorded = await client.getTeacherLogbook(selection);
    expect(recorded['items'], [
      {
        'id': 'demo-math-b-lesson-0',
        'displayLabel': 'Fractions et proportions',
        'startsAt': '2026-11-09T09:00:00.000Z',
        'recorded': true,
      },
    ]);
    expect(recorded['nextCursor'], isNull);
    final all = await client.getTeacherLogbook({...selection, 'view': 'all'});
    expect(
      [for (final lesson in all['items']) (lesson['id'], lesson['recorded'])],
      [
        ('demo-math-b-lesson-3', false),
        ('demo-math-b-lesson-2', false),
        ('demo-math-b-lesson-1', false),
        ('demo-math-b-lesson-0', true),
      ],
    );

    await client.saveTeacherLogbook({
      'requestId': 'record-demo-lesson',
      'expectedVersion': 0,
      'proposal': {
        'workflow': 'logbook',
        'targetId': 'demo-math-b-lesson-1',
        'sessionNote': '',
        'progress': [
          {'matterId': 'demo-math-b-chapter', 'completed': false},
        ],
      },
    });
    final refreshed = await client.getTeacherLogbook(selection);
    expect(
      [for (final lesson in refreshed['items']) lesson['id']],
      ['demo-math-b-lesson-1', 'demo-math-b-lesson-0'],
    );
    await expectLater(
      client.getTeacherLogbook({...selection, 'classSubjectId': 'demo-math-a'}),
      throwsA(isA<ApiError>().having((e) => e.status, 'status', 403)),
    );
  });

  test(
    'demo logbook continues after tied dates within the same view',
    () async {
      store = await DemoStore.start(DemoRole.teacher);
      final client = createEdayaSchoolClient(store.auth);
      const selection = {
        'classGroupId': 'demo-class-b',
        'classSubjectId': 'demo-math-b',
        'view': 'recorded',
      };
      final lesson = await client.lessonSessions.get('demo-math-b-lesson-0');
      for (var i = 0; i < 30; i++) {
        await client.lessonSessions.save({
          ...lesson,
          'id': 'copy-${i.toString().padLeft(2, '0')}',
        });
      }
      final first = await client.getTeacherLogbook(selection);
      expect(first['items'], hasLength(30));
      expect(first['items'].last['id'], 'copy-01');
      final cursor = first['nextCursor'] as String;
      final next = await client.getTeacherLogbook({
        ...selection,
        'cursor': cursor,
      });
      expect(next['items'].single['id'], 'copy-00');
      expect(next['nextCursor'], isNull);
      await expectLater(
        client.getTeacherLogbook({
          ...selection,
          'view': 'all',
          'cursor': cursor,
        }),
        throwsA(isA<ApiError>().having((e) => e.status, 'status', 400)),
      );
    },
  );

  test('teacher Home daily status follows the selected register', () async {
    store = await DemoStore.start(DemoRole.teacher);
    final client = createEdayaSchoolClient(store.auth);
    const query = {'classGroupId': 'demo-class-b', 'date': '2026-10-01'};
    final anchor = {'kind': 'daily', ...query};
    expect(await client.getTeacherDailyAttendanceStatus(query), {
      'submitted': false,
    });
    final register = await client.getTeacherAttendanceCall({'anchor': anchor});
    await client.submitTeacherAttendance({
      'anchor': anchor,
      'expectedVersion': register['version'],
      'entries': [
        for (final student in register['students'])
          {'studentId': student['id'], 'status': 'present'},
      ],
    });
    expect(await client.getTeacherDailyAttendanceStatus(query), {
      'submitted': true,
    });
    await expectLater(
      client.getTeacherDailyAttendanceStatus({
        ...query,
        'classGroupId': 'demo-class-a',
      }),
      throwsA(isA<ApiError>().having((error) => error.status, 'status', 403)),
    );
  });

  test(
    'teacher commits attendance and marks, and keeps a correction pending',
    () async {
      store = await DemoStore.start(DemoRole.teacher);
      final client = createEdayaSchoolClient(store.auth);
      expect((await client.effectiveGrants()).kind, 'teacher');
      final anchor = {
        'kind': 'lesson',
        'lessonSessionId': 'demo-math-a-lesson-1',
      };
      final call = await client.getTeacherAttendanceCall({'anchor': anchor});
      expect(call['submitted'], false);
      final entries = [
        for (final student in call['students'])
          {'studentId': student['id'], 'status': 'present'},
      ];
      final saved = await client.saveTeacherAttendanceDraft({
        'anchor': anchor,
        'entries': entries,
        'expectedVersion': 0,
      });
      final submitted = await client.submitTeacherAttendance({
        'anchor': anchor,
        'entries': entries,
        'expectedVersion': saved['version'],
      });
      expect(submitted['submitted'], true);
      expect(
        (await client.getTeacherAttendanceCall({'anchor': anchor}))['records'],
        hasLength(entries.length),
      );
      const assessment = 'demo-math-a-draft';
      final review = await client.getAssessmentMarksReview({
        'assessmentId': assessment,
      });
      final results = [
        for (final student in review['students'])
          {'studentId': student['id'], 'designation': 'scored', 'score': 14},
      ];
      final batch = {
        'assessmentId': assessment,
        'requestId': 'marks-1',
        'expectedRevision': 0,
        'results': results,
      };
      await client.runListCommand('record-assessment-results', batch);
      await client.runListCommand('record-assessment-results', batch);
      final sheet = await client.submitAssessmentMarks({
        'assessmentId': assessment,
        'expectedRevision': results.length,
      });
      expect(sheet['marksStatus'], 'submitted');
      final correction = await client.requestAssessmentMarksCorrection({
        'assessmentId': assessment,
        'reason': 'Relecture',
        'changes': [
          {
            'studentId': 'demo-amina',
            'proposed': {'score': 15, 'designation': 'scored'},
          },
        ],
      });
      expect(correction['status'], 'pending');
      final after = await client.getAssessmentMarksReview({
        'assessmentId': assessment,
      });
      expect(
        (after['results'] as List).map((r) => r['score']),
        everyElement(14),
      );
      expect((after['corrections'] as List).single['status'], 'pending');
      final intent = await client.createTeacherSignatureUpload({
        'attachmentId': 'signed',
      });
      final media = schoolMediaClient(client);
      await media.put(
        Uri.parse(intent['uploadUrl']),
        body: Uint8List.fromList([2, 3]),
      );
      final signature = await client.completeTeacherSignatureUpload({
        'attachmentId': 'signed',
      });
      expect(signature['signatureAttachmentId'], 'signed');
      expect(await store.readMedia('signed'), [2, 3]);
      expect(
        (await client.clearTeacherSignature({
          'attachmentId': 'signed',
        }))['signatureAttachmentId'],
        isNull,
      );
      media.close();
      final created = await client.runCommand('start-teacher-conversation', {
        'classGroupId': 'demo-class-b',
        'studentId': 'demo-youssef',
        'guardianId': 'demo-guardian',
        'subject': 'Devoirs',
        'body': 'Travail du soir',
      });
      expect(created['assignmentIds'], contains('demo-math-b-assignment'));
      final message = {
        'conversationId': 'demo-thread',
        'body': 'Merci',
        'requestId': 'reply-1',
      };
      final thread = await client.replyConversation(message);
      expect(
        (await client.replyConversation(message))['version'],
        thread['version'],
      );
      final detail = await client.getConversation({
        'conversationId': 'demo-thread',
      });
      expect(detail['conversation']['assignmentIds'], [
        'demo-math-a-assignment',
      ]);
      expect((detail['messages'] as List).last['authorKind'], 'teacher');
      expect(
        (detail['messages'] as List).where((m) => m['body'] == 'Merci'),
        hasLength(1),
      );
    },
  );
}
