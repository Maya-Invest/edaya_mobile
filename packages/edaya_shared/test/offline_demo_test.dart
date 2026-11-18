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
    'guardian stays local, resumes edits and removes only demo data on exit',
    () async {
      store = await DemoStore.start(DemoRole.guardian);
      final client = createEdayaSchoolClient(store.auth);
      final scope = (await client.effectiveGrants()).guardianScope!;
      expect(scope.studentIds, unorderedEquals(['demo-amina', 'demo-youssef']));
      expect(await client.students.listAll(), hasLength(2));
      final placements = await client.enrollments.listAll({
        'studentId': 'demo-amina',
      });
      expect(
        placements.map((e) => e['academicYearId']).toSet(),
        containsAll(['demo-2025', 'demo-2026']),
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
