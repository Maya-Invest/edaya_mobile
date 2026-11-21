import 'dart:async';

import 'package:edaya_api_client/edaya_api_client.dart' as api;
import 'package:edaya_guardian_v2/features/context/academic_year_controller.dart';
import 'package:edaya_guardian_v2/features/context/student_context_controller.dart';
import 'package:edaya_guardian_v2/features/fees/payment_detail_controller.dart';
import 'package:edaya_guardian_v2/features/my_students/linked_student.dart';
import 'package:edaya_shared/edaya_shared.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:levit_flutter/levit_flutter.dart';

class _Year implements AcademicYearController {
  @override
  final selectedYearId = LxVar<String?>('year');

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

LinkedStudent pupil(String id) =>
    LinkedStudent(id: id, firstName: id, lastName: 'Pupil', status: 'active');

class _Students implements StudentContextController {
  @override
  final activeStudent = LxVar<LinkedStudent?>(pupil('first'));
  @override
  final isLoading = LxVar(false);
  @override
  GuardianPupilSelection? get verifiedSelection {
    final student = activeStudent.value;
    if (student == null || isLoading.value) return null;
    return (
      accountId: 'account',
      schoolId: 'school',
      guardianId: 'guardian',
      studentId: student.id,
      academicYearId: 'year',
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Transport implements api.Transport {
  final pending = <String, Completer<Map<String, dynamic>>>{};
  final downloads = <Object?>[];
  final aborted = <String>[];

  @override
  Future<T> request<T>(
    String method,
    String path, {
    api.TransportRequestOptions? options,
  }) async {
    final uri = Uri.parse(path);
    if (uri.path == '/core/queries/list-document-issuances') {
      downloads.add(options?.body);
      return <dynamic>[
            {
              'id': 'document',
              'sourceId': 'receipt',
              'templateKey': 'receipt.v1',
              'status': 'ready',
            },
          ]
          as T;
    }
    if (uri.path == '/core/queries/grant-document-download') {
      expect(options?.body, {'id': 'document'});
      return {'downloadUrl': 'https://files.example.test/issued-receipt.pdf'}
          as T;
    }
    expect(method, 'GET');
    expect(uri.path, '/core/guardian/payment');
    expect(uri.queryParameters['paymentId'], 'receipt');
    final response = Completer<Map<String, dynamic>>();
    final pupil = uri.queryParameters['studentId']!;
    pending[pupil] = response;
    unawaited(options!.abortTrigger!.then((_) => aborted.add(pupil)));
    return await response.future as T;
  }
}

void main() {
  test(
    'a late response after a pupil switch cannot replace the selected receipt or redirect its download',
    () async {
      final transport = _Transport();
      final students = _Students();
      final c = PaymentDetailController(
        paymentId: 'receipt',
        students: students,
        year: _Year(),
        schoolClient: () => api.createSchoolClient(transport),
      );
      c.onInit();
      addTearDown(c.onClose);
      await Future<void>.delayed(Duration.zero);
      students.activeStudent(pupil('second'));
      await Future<void>.delayed(Duration.zero);
      expect(transport.pending.keys, orderedEquals(['first', 'second']));
      expect(transport.aborted, ['first']);
      final payment = {
        'id': 'receipt',
        'currency': 'USD',
        'paymentDate': '2026-10-12T00:00:00Z',
        'kind': 'disbursement',
        'amount': 200,
        'chargeLabels': <String>[],
      };
      transport.pending['second']!.complete({'payment': payment});
      await Future<void>.delayed(Duration.zero);
      expect(c.payment.value?.feeLabel, systemL10n().paymentKindDisbursement);
      transport.pending['first']!.complete({
        'payment': {...payment, 'amount': 999},
      });
      await Future<void>.delayed(Duration.zero);
      expect(c.payment.value?.amount, 200);
      expect(transport.downloads, isEmpty);
      final originalOpen = openDocumentUrl;
      addTearDown(() => openDocumentUrl = originalOpen);
      final opened = <Uri>[];
      openDocumentUrl = (uri) async {
        opened.add(uri);
        return true;
      };
      expect((await c.downloadReceipt()).outcome, DocumentJobOutcome.opened);
      expect(opened.single.path, '/issued-receipt.pdf');
      expect(transport.downloads.single, {
        'sourceId': 'receipt',
        'templateKey': 'receipt.v1',
        'academicYearId': 'year',
        'studentId': 'second',
      });
      students.isLoading(true);
      await Future<void>.delayed(Duration.zero);
      expect(c.payment.value, isNull);
      expect(transport.aborted, ['first', 'second']);
      expect((await c.downloadReceipt()).outcome, DocumentJobOutcome.missing);
      expect(transport.downloads, hasLength(1));
    },
  );
}
