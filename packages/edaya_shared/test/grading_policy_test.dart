import 'package:edaya_shared/edaya_shared.dart';
import 'package:flutter_test/flutter_test.dart';

GradingPolicyView policy({
  String rounding = 'nearest',
  String status = 'completed',
}) => GradingPolicyView({
  'revision': 2,
  'status': status,
  'mode': 'mention-first',
  'aggregateLabel': 'GPA',
  'scale': {
    'id': 'gpa',
    'maxScore': 4,
    'minScore': 0,
    'intervalConvention': 'continuous',
    'decimalPlaces': 2,
    'roundingMode': rounding,
    'ranges': [
      {'id': 'f', 'letter': 'F', 'minScore': 0, 'maxScore': 2, 'gpaValue': 0},
      {'id': 'b', 'letter': 'B', 'minScore': 2, 'maxScore': 3.5, 'gpaValue': 3},
      {'id': 'a', 'letter': 'A', 'minScore': 3.5, 'maxScore': 4, 'gpaValue': 4},
    ],
  },
});
void main() {
  test('matches rounded boundaries and the final maximum', () {
    expect(policy().mention(1.995)?['letter'], 'B');
    expect(policy(rounding: 'truncate').mention(1.999)?['letter'], 'F');
    expect(policy().mention(4)?['letter'], 'A');
    expect(policy().display(3.333333), '3.33 / 4.0 · B');
  });
  test('thresholds reject out-of-range values before rounding', () {
    for (final value in [-0.001, 4.001, double.nan, double.infinity]) {
      expect(policy().mention(value), isNull);
    }
    expect(policy().mention(0)?['letter'], 'F');
    expect(policy().mention(2)?['letter'], 'B');
    expect(policy().mention(3.5)?['letter'], 'A');
    final empty = policy();
    empty.scale['ranges'] = <Map<String, dynamic>>[];
    expect(empty.mention(2), isNull);
  });
  test('minimum thresholds and legacy snapshots use their own conventions', () {
    final current = policy();
    for (final row in current.scale['ranges'] as List) {
      (row as Map).remove('maxScore');
    }
    expect(current.mention(2)?['letter'], 'B');
    expect(current.mention(4)?['letter'], 'A');
    final legacy = policy();
    legacy.scale.remove('intervalConvention');
    expect(legacy.mention(2)?['letter'], 'F');
    (legacy.scale['ranges'] as List)[0]['maxScore'] = 1.9;
    expect(legacy.mention(1.95), isNull);
  });
  test('averages raw points without replacing them with mention points', () {
    final entries = [
      (
        score: null,
        maximum: 100.0,
        coefficient: 2.0,
        calculation: <String, dynamic>{
          'value': 4,
          'scaleId': 'gpa',
          'policyRevision': 2,
        },
      ),
      (
        score: null,
        maximum: 20.0,
        coefficient: 1.0,
        calculation: <String, dynamic>{
          'value': 3,
          'scaleId': 'gpa',
          'policyRevision': 2,
        },
      ),
    ];
    expect(gradingAverage(entries, policy: policy()), closeTo(11 / 3, 1e-12));
    expect(gradingAverage(entries, policy: policy(status: 'updating')), isNull);
    expect(gradingAverage(entries), isNull);
    entries.last.calculation['policyRevision'] = 1;
    expect(gradingAverage(entries, policy: policy()), isNull);
  });
  test('legacy mixed maxima still normalize to twenty', () {
    expect(
      gradingAverage([
        (score: 80.0, maximum: 100.0, coefficient: 2.0, calculation: null),
        (score: 6.0, maximum: 10.0, coefficient: 1.0, calculation: null),
      ]),
      closeTo(44 / 3, 1e-12),
    );
  });
}
