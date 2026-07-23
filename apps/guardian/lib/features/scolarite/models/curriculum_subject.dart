class CurriculumUnit {
  const CurriculumUnit({
    required this.name,
    required this.completedPercentage,
    required this.status,
  });

  final String name;
  final int completedPercentage;
  final String status;
}

class CurriculumSubject {
  const CurriculumSubject({
    required this.subjectName,
    required this.completedPercentage,
    required this.units,
  });

  final String subjectName;
  final int completedPercentage;
  final List<CurriculumUnit> units;
}
