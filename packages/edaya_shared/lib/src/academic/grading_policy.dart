import 'dart:math' as math;
import 'package:intl/intl.dart';

import '../l10n/l10n_lookup.dart';

String formatGradeNumber(num? value, {int? precision, String? locale}) {
  if (value == null) return '—';
  final format = NumberFormat.decimalPattern(locale ?? systemL10n().localeName);
  format.turnOffGrouping();
  format.maximumFractionDigits = precision ?? 12;
  format.minimumFractionDigits = precision ?? 0;
  return format.format(value);
}

/// A read-only level/year policy. Original entries are never rewritten here.
class GradingPolicyView {
  GradingPolicyView(this.data);
  final Map<String, dynamic> data;
  int get revision => (data['revision'] as num).toInt();
  bool get isCurrent => data['status'] == 'completed';
  bool get mentionFirst => data['mode'] == 'mention-first';
  String get aggregateLabel => data['aggregateLabel'] as String;
  Map get scale => data['scale'] as Map;
  double get maximum => (scale['maxScore'] as num).toDouble();
  int get precision => (scale['decimalPlaces'] as num?)?.toInt() ?? 2;
  List<Map<String, dynamic>> get intervals => (scale['ranges'] as List)
      .map((row) => Map<String, dynamic>.from(row as Map))
      .toList();

  double round(double value) {
    final factor = math.pow(10, precision);
    final scaled = value * factor;
    final adjusted =
        scaled + 2.220446049250313e-16 * math.max(1, scaled.abs()) * 4;
    return (scale['roundingMode'] == 'truncate'
            ? adjusted.truncate()
            : adjusted.round()) /
        factor;
  }

  Map<String, dynamic>? mention(double value) {
    final minimum = (scale['minScore'] as num?)?.toDouble() ?? 0;
    if (!value.isFinite || value < minimum || value > maximum) return null;
    final reported = round(value);
    final ranges = intervals
      ..sort((a, b) => (a['minScore'] as num).compareTo(b['minScore'] as num));
    if (scale['intervalConvention'] == 'continuous') {
      for (final range in ranges.reversed) {
        if (reported >= (range['minScore'] as num)) return range;
      }
    } else {
      // Old captured scales retain their closed upper bounds and gaps.
      for (final range in ranges) {
        if (reported >= (range['minScore'] as num) &&
            reported <= (range['maxScore'] as num)) {
          return range;
        }
      }
    }
    return null;
  }

  String display(double? value) {
    if (value == null) return '—';
    final code = mention(value)?['letter'];
    final score = formatGradeNumber(round(value), precision: precision);
    final max = formatGradeNumber(
      maximum,
      precision: maximum == maximum.round() ? 1 : null,
    );
    return '$score / $max${code == null ? '' : ' · $code'}';
  }
}

/// Uses full-precision server values. Mixed or unfinished revisions are hidden.
double? gradingAverage(
  Iterable<
    ({
      double? score,
      double maximum,
      double coefficient,
      Map<String, dynamic>? calculation,
    })
  >
  entries, {
  GradingPolicyView? policy,
}) {
  if (policy != null && !policy.isCurrent) return null;
  var weight = 0.0;
  var points = 0.0;
  for (final entry in entries) {
    double? value;
    if (policy != null) {
      if (entry.calculation == null) {
        if (entry.score != null) return null;
        continue;
      }
      if (entry.calculation!['policyRevision'] != policy.revision ||
          entry.calculation!['scaleId'] != policy.scale['id']) {
        return null;
      }
      value = (entry.calculation!['value'] as num).toDouble();
    } else {
      // Never reinterpret newly configured points as legacy percentages.
      if (entry.calculation != null) return null;
      value = entry.score == null || entry.maximum <= 0
          ? null
          : entry.score! / entry.maximum * 20;
    }
    if (value == null || entry.coefficient <= 0) continue;
    points += value * entry.coefficient;
    weight += entry.coefficient;
  }
  return weight == 0 ? null : points / weight;
}

/// Formats immutable report or assessment calculation metadata.
String formatCalculatedGrade(double? value, Map<String, dynamic>? calculation) {
  if (value == null) return '—';
  final precision = (calculation?['decimalPlaces'] as num?)?.toInt() ?? 2;
  final maximum = calculation?['maximum'] ?? 20;
  final code = (calculation?['mention'] as Map?)?['code'];
  return '${formatGradeNumber(value, precision: precision)} / ${formatGradeNumber(maximum as num)}${code == null ? '' : ' · $code'}';
}
