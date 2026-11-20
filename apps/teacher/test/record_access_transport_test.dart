import 'dart:async';
import 'package:edaya_api_client/edaya_api_client.dart';
import 'package:edaya_teacher_v2/navigation/record_access_transport.dart';
import 'package:flutter_test/flutter_test.dart';

class _ResponseTransport implements Transport {
  final response = Completer<Object?>();
  @override
  Future<T> request<T>(
    String method,
    String path, {
    TransportRequestOptions? options,
  }) async => await response.future as T;
}

void main() {
  test(
    'denied record reads return to their owner while writes retain their form',
    () async {
      var current = Uri.parse('/evaluations/assessment/marks');
      final owners = <String>[];
      final delegate = _ResponseTransport();
      final transport = RecordAccessTransport(
        delegate,
        location: () => current,
        onUnavailable: owners.add,
      );
      final request = transport.request<Object?>(
        'POST',
        '/core/queries/get-assessment-marks-review',
        options: const TransportRequestOptions(
          body: {'assessmentId': 'assessment'},
        ),
      );
      final expectation = expectLater(request, throwsA(isA<ApiError>()));
      delegate.response.completeError(ApiError(403, {'error': 'denied'}));
      await expectation;
      expect(owners, ['/evaluations']);
      expect(
        recordOwnerForRead(
          Uri.parse('/inbox/new'),
          '/core/commands/start-teacher-conversation',
          {},
        ),
        isNull,
      );
      expect(
        recordOwnerForRead(
          current,
          '/core/queries/get-assessment-marks-review',
          {'assessmentId': 'another'},
        ),
        isNull,
      );
    },
  );

  test('an incident redirect belongs to the exact opened class and record', () {
    final location = Uri.parse('/incidents/c/i');
    const route = '/core/teacher/incidents/detail';
    expect(
      recordOwnerForRead(location, '$route?classGroupId=c&incidentId=i', {}),
      '/incidents',
    );
    expect(
      recordOwnerForRead(
        location,
        '$route?classGroupId=other&incidentId=i',
        {},
      ),
      isNull,
    );
    expect(
      recordOwnerForRead(
        location,
        '$route?classGroupId=c&incidentId=other',
        {},
      ),
      isNull,
    );
  });

  test('a late denial cannot redirect a different page', () async {
    var current = Uri.parse('/evaluations/assessment/marks');
    final owners = <String>[];
    final delegate = _ResponseTransport();
    final transport = RecordAccessTransport(
      delegate,
      location: () => current,
      onUnavailable: owners.add,
    );
    final request = transport.request<Object?>(
      'POST',
      '/core/queries/get-assessment-marks-review',
      options: const TransportRequestOptions(
        body: {'assessmentId': 'assessment'},
      ),
    );
    final expectation = expectLater(request, throwsA(isA<ApiError>()));
    current = Uri.parse('/home');
    delegate.response.completeError(ApiError(404, {'error': 'missing'}));
    await expectation;
    expect(owners, isEmpty);
  });
}
