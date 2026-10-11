import 'dart:convert';
import 'package:test/test.dart';
import 'package:edaya_repo/src/integration.dart';
import 'package:edaya_repo/src/runtime.dart';
import 'package:edaya_repo/src/android.dart';
import 'package:edaya_repo/src/smoke.dart';

void main() {
  test('missing or debug Android signing is rejected before packaging', () {
    expect(() => signingProperties(''), throwsStateError);
    expect(
      () => signingProperties(
        'keyAlias=androiddebugkey\nkeyPassword=secret\nstorePassword=secret\nstoreFile=test.jks',
      ),
      throwsStateError,
    );
    expect(
      signingProperties(
        'keyAlias=release\nkeyPassword=key-secret\nstorePassword=store-secret\nstoreFile=test.jks',
      )['keyAlias'],
      'release',
    );
  });
  test('diagnostics redact injected credentials and database URLs', () {
    final text = redact(
      'unique-secret-value postgres://name:password@db/test Basic encoded',
      environment: {'KEY_PASSWORD': 'unique-secret-value'},
    );
    expect(text, isNot(contains('unique-secret-value')));
    expect(text, isNot(contains('name:password')));
    expect(text, isNot(contains('encoded')));
  });
  List<String> events({String result = 'success', bool skipped = false}) => [
    jsonEncode({
      'type': 'testStart',
      'test': {'id': 1, 'name': '[teacher.roster.read] roster', 'line': 42},
    }),
    jsonEncode({
      'type': 'testDone',
      'testID': 1,
      'result': result,
      'skipped': skipped,
    }),
    jsonEncode({'type': 'done', 'success': true}),
  ];
  const required = ['teacher.roster.read'];
  test(
    'accepts complete real execution',
    () => expect(evaluate(events(), 0, required)['ok'], isTrue),
  );
  test(
    'rejects failure despite zero exit',
    () =>
        expect(evaluate(events(result: 'failure'), 0, required)['ok'], isFalse),
  );
  test(
    'rejects skipped test',
    () => expect(evaluate(events(skipped: true), 0, required)['ok'], isFalse),
  );
  test(
    'rejects zero tests',
    () => expect(
      evaluate(['{"type":"done","success":true}'], 0, required)['ok'],
      isFalse,
    ),
  );
  test(
    'rejects missing required scenario',
    () => expect(evaluate(events(), 0, ['another.scenario'])['ok'], isFalse),
  );
  test(
    'rejects incomplete run',
    () => expect(evaluate(events().take(2), 0, required)['ok'], isFalse),
  );
  test(
    'rejects runner errors',
    () => expect(
      evaluate(
        [...events(), '{"type":"error","error":"fixture failed"}'],
        0,
        required,
      )['ok'],
      isFalse,
    ),
  );
  test(
    'rejects duplicate scenario IDs',
    () => expect(
      evaluate(
        [
          ...events(),
          jsonEncode({
            'type': 'testStart',
            'test': {
              'id': 2,
              'name': '[teacher.roster.read] duplicate',
              'line': 10,
            },
          }),
        ],
        0,
        required,
      )['ok'],
      isFalse,
    ),
  );
  final contract = {
    'features': [
      {
        'id': 'teacher.classes',
        'routes': ['/classes'],
        'actions': [
          {'id': 'teacher.classes.read', 'scenarios': required},
        ],
      },
    ],
  };
  test('requires exact route coverage', () {
    expect(featureProblems(contract, required, ['/classes']), isEmpty);
    expect(
      featureProblems(contract, required, ['/classes', '/new']),
      isNotEmpty,
    );
    expect(featureProblems(contract, [], ['/classes']), isNotEmpty);
    expect(featureProblems(contract, required, null), isNotEmpty);
    expect(featureProblems(contract, required, []), isNotEmpty);
  });
  test('redacts credentials while retaining route placeholders', () {
    final safe = redact(
      '/invite/:token /invite/private-token Bearer abc otp=123456',
    );
    expect(safe, contains('/invite/:token'));
    expect(safe, isNot(contains('private-token')));
    expect(safe, isNot(contains('abc')));
    expect(safe, isNot(contains('123456')));
  });
  test('destination controls backend selection', () {
    expect(backendBranch('production'), 'main');
    expect(backendBranch('staging'), 'staging');
    expect(() => backendBranch('feature'), throwsArgumentError);
  });
  test('rejects unsigned, debug and wrong-application APKs', () {
    expect(
      () => verifyApkIdentity(
        'abc',
        'certificate SHA-256 digest: abc',
        'app.id',
        "package: name='app.id'",
      ),
      returnsNormally,
    );
    for (final signature in [
      '',
      'certificate SHA-256 digest: wrong',
      'certificate SHA-256 digest: abc Android Debug',
    ]) {
      expect(
        () => verifyApkIdentity(
          'abc',
          signature,
          'app.id',
          "package: name='app.id'",
        ),
        throwsStateError,
      );
    }
    expect(
      () => verifyApkIdentity(
        'abc',
        'certificate SHA-256 digest: abc',
        'app.id',
        "package: name='other'",
      ),
      throwsStateError,
    );
  });
  test(
    'staging smoke rejects test overrides and missing private sessions',
    () => expect(
      smokePreflight({
        'EDAYA_API_URL': 'http://localhost',
        'TEST_OTP_ACCESS': 'true',
      }),
      hasLength(3),
    ),
  );
}
