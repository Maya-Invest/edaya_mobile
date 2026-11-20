import 'dart:async';

import 'package:edaya_api_client/edaya_api_client.dart' as api;
import 'package:edaya_guardian_v2/features/child_profile/child_profile_controller.dart';
import 'package:edaya_guardian_v2/features/context/academic_year_controller.dart';
import 'package:edaya_guardian_v2/features/context/student_context_controller.dart';
import 'package:edaya_guardian_v2/features/my_students/linked_student.dart';
import 'package:edaya_shared/edaya_shared.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:levit_flutter/levit_flutter.dart';

LinkedStudent child(String id) => LinkedStudent(
  id: id,
  firstName: id,
  lastName: 'Pupil',
  schoolId: 'school',
  status: 'active',
);

class _Year implements AcademicYearController {
  @override
  final selectedYearId = LxVar<String?>('year');
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Pupils implements StudentContextController {
  _Pupils(this.year);
  final _Year year;
  @override
  final activeStudent = LxVar<LinkedStudent?>(child('a'));
  @override
  final isLoading = LxVar(false);
  @override
  GuardianPupilSelection? get verifiedSelection {
    final pupil = activeStudent.value;
    final id = year.selectedYearId.value;
    if (pupil == null || id == null || isLoading.value) return null;
    return (
      accountId: 'account',
      schoolId: 'school',
      guardianId: 'guardian',
      studentId: pupil.id,
      academicYearId: id,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Read {
  _Read(this.url, this.abort, this.body);
  final Uri url;
  final Future<void>? abort;
  final Object? body;
  final result = Completer<Map<String, dynamic>>();
  void photo([Map<String, dynamic> decision = const {'status': 'none'}]) {
    final id = url.queryParameters['studentId'];
    result.complete({
      'academicYearId': url.queryParameters['academicYearId'],
      'student': {
        'id': id,
        'schoolId': 'school',
        'firstName': id,
        'lastName': 'Pupil',
        'status': 'active',
      },
      'decision': decision,
    });
  }

  void papers(List<String> ids, [String? next]) {
    result.complete({
      'academicYearId': url.queryParameters['academicYearId'],
      'studentId': url.queryParameters['studentId'],
      'items': ids
          .map(
            (id) => {
              'id': id,
              'templateKey': 'schooling-certificate.v1',
              'sourceId': id,
              'status': 'ready',
            },
          )
          .toList(),
      'nextCursor': next,
    });
  }
}

class _Transport implements api.Transport {
  final reads = <_Read>[];
  @override
  Future<T> request<T>(
    String method,
    String path, {
    api.TransportRequestOptions? options,
  }) async {
    final url = Uri.parse(path);
    expect(method, url.path.startsWith('/core/queries/') ? 'POST' : 'GET');
    final read = _Read(url, options?.abortTrigger, options?.body);
    reads.add(read);
    return await read.result.future as T;
  }

  _Read last(String section) =>
      reads.lastWhere((r) => r.url.path.endsWith('/$section'));
}

void main() {
  late _Transport wire;
  late _Year year;
  late _Pupils pupils;
  late ChildProfileController controller;
  Future<void> flush() => Future<void>.delayed(Duration.zero);
  setUp(() {
    wire = _Transport();
    year = _Year();
    pupils = _Pupils(year);
    controller = ChildProfileController(
      schoolClient: () => api.createSchoolClient(wire),
      studentContext: pupils,
      academicYear: year,
    );
    controller.onInit();
  });
  tearDown(() => controller.onClose());
  test(
    'download grants the listed paper directly, resolves a replacement, and discards a grant after switching pupils',
    () async {
      final previousOpen = openDocumentUrl;
      final opened = <String>[];
      addTearDown(() => openDocumentUrl = previousOpen);
      openDocumentUrl = (uri) async {
        opened.add(uri.path);
        return true;
      };
      wire.last('photo').photo();
      wire.last('papers').papers(['paper']);
      await flush();
      final paper = controller.leftoverPapers.value.single;
      final direct = controller.downloadLeftover(paper);
      expect(wire.last('grant-document-download').body, {'id': 'paper'});
      wire.last('grant-document-download').result.complete({
        'downloadUrl': 'https://school.example/original',
      });
      expect((await direct).outcome, DocumentJobOutcome.opened);
      expect(wire.reads, hasLength(3));
      final replaced = controller.downloadLeftover(paper);
      wire
          .last('grant-document-download')
          .result
          .completeError(
            api.ApiError(409, {'code': 'DOCUMENT_DOWNLOAD_FORBIDDEN'}),
          );
      await flush();
      final lookup = wire.last('list-document-issuances');
      expect(lookup.body, {
        'studentId': 'a',
        'academicYearId': 'year',
        'templateKey': 'schooling-certificate.v1',
        'sourceId': 'paper',
      });
      lookup.result.complete({
        'items': [
          {
            'id': 'new',
            'status': 'ready',
            'sourceId': 'paper',
            'templateKey': 'schooling-certificate.v1',
          },
        ],
      });
      await flush();
      expect(wire.last('grant-document-download').body, {'id': 'new'});
      wire.last('grant-document-download').result.complete({
        'downloadUrl': 'https://school.example/replacement',
      });
      expect((await replaced).outcome, DocumentJobOutcome.opened);
      final stale = controller.downloadLeftover(paper);
      final staleGrant = wire.last('grant-document-download');
      pupils.activeStudent(child('b'));
      await flush();
      staleGrant.result.complete({
        'downloadUrl': 'https://school.example/stale',
      });
      expect((await stale).outcome, DocumentJobOutcome.missing);
      expect(opened, ['/original', '/replacement']);
      wire.last('photo').photo();
      wire.last('papers').papers([]);
      await flush();
    },
  );
  test(
    'verified header and papers can appear while photo action is undecided; continuation retries without duplicating rows',
    () async {
      expect(controller.student.value?.id, 'a');
      expect(controller.decision.value, isNull);
      expect(wire.reads, hasLength(2));
      wire.last('papers').papers(['d1'], 'cursor');
      await flush();
      expect(controller.leftoverPapers.value.single.id, 'd1');
      expect(controller.decision.value, isNull);
      wire.last('photo').photo({'status': 'pending', 'ownSubmission': null});
      await flush();
      expect(controller.ownSubmission, isNull);
      expect(await controller.withdrawPending(), isFalse);
      final page = controller.loadMorePapers();
      expect(wire.last('papers').url.queryParameters['cursor'], 'cursor');
      wire.last('papers').result.completeError(api.ApiError(503, 'Temporary'));
      await page;
      expect(controller.papersError.value, isNotEmpty);
      expect(controller.leftoverPapers.value.single.id, 'd1');
      final retry = controller.loadMorePapers();
      wire.last('papers').papers(['d2']);
      await retry;
      expect(controller.papersError.value, isEmpty);
      expect(controller.leftoverPapers.value.map((p) => p.id), ['d1', 'd2']);
      expect(controller.nextCursor.value, isNull);
    },
  );
  test(
    'late responses for a previous pupil or academic year cannot restore personal data',
    () async {
      final oldPhoto = wire.last('photo'), oldPapers = wire.last('papers');
      pupils.activeStudent(child('b'));
      await flush();
      await oldPhoto.abort!.timeout(const Duration(seconds: 1));
      expect(controller.student.value?.id, 'b');
      final middlePhoto = wire.last('photo'),
          middlePapers = wire.last('papers');
      year.selectedYearId('next');
      await flush();
      final photo = wire.last('photo'), papers = wire.last('papers');
      expect(photo.url.queryParameters, {
        'studentId': 'b',
        'academicYearId': 'next',
      });
      photo.photo({
        'status': 'pending',
        'ownSubmission': {'id': 'new', 'attachmentId': 'file', 'version': 2},
      });
      papers.papers(['current']);
      await flush();
      oldPhoto.photo();
      oldPapers.papers(['old']);
      middlePhoto.photo();
      middlePapers.papers(['middle']);
      await flush();
      expect(controller.student.value?.id, 'b');
      expect(controller.ownSubmission?['id'], 'new');
      expect(controller.leftoverPapers.value.single.id, 'current');
      pupils.activeStudent(null);
      await flush();
      expect(controller.dataStatus, DataStatus.empty);
      expect(controller.decision.value, isNull);
      expect(controller.leftoverPapers.value, isEmpty);
    },
  );
  test(
    'photo failure retries independently; denied continuation clears both sections',
    () async {
      wire.last('papers').papers(['document'], 'p2');
      wire.last('photo').result.completeError(api.ApiError(503, 'temporary'));
      await flush();
      expect(controller.photoError.value, isNotEmpty);
      expect(controller.leftoverPapers.value.single.id, 'document');
      final retry = controller.retryPhoto();
      wire.last('photo').photo();
      await retry;
      expect(controller.decision.value?['status'], 'none');
      final page = controller.loadMorePapers();
      wire.last('papers').result.completeError(api.ApiError(403, 'removed'));
      await page;
      expect(controller.student.value, isNull);
      expect(controller.leftoverPapers.value, isEmpty);
      expect(controller.decision.value, isNull);
      expect(controller.dataStatus, DataStatus.error);
    },
  );
}
