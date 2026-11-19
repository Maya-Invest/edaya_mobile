/// Fixture scale for the Côte d’Ivoire secondary-school demo, on 20 points.
Map<String, dynamic> demoGrade(num value) {
  final reported = (value * 100).round() / 100;
  final (code, label) = switch (reported) {
    >= 18 => ('EX', 'Excellent'),
    >= 16 => ('TB', 'Très bien'),
    >= 14 => ('B', 'Bien'),
    >= 12 => ('AB', 'Assez bien'),
    >= 10 => ('P', 'Passable'),
    >= 8 => ('I', 'Insuffisant'),
    >= 6 => ('TI', 'Très insuffisant'),
    >= 4 => ('F', 'Faible'),
    _ => ('TF', 'Très faible'),
  };
  return {
    'reportedValue': reported,
    'maximum': 20,
    'decimalPlaces': 2,
    'mention': {'code': code, 'label': label},
  };
}
