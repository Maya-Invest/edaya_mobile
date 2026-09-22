/// Same normalization as backend report-card aggregation: each score is
/// scaled to 20, then weighted by its coefficient. Absent scores are skipped.
double? normalizedAverageOutOf20(
  Iterable<
    ({double? score, double maxScore, double coefficient})
  > entries,
) {
  var totalWeight = 0.0;
  var weightedPoints = 0.0;
  for (final entry in entries) {
    final score = entry.score;
    if (score == null || entry.maxScore <= 0) {
      continue;
    }
    totalWeight += entry.coefficient;
    weightedPoints += (score / entry.maxScore) * 20 * entry.coefficient;
  }
  if (totalWeight == 0) {
    return null;
  }
  return weightedPoints / totalWeight;
}
