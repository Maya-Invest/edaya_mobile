class AccueilTask {
  const AccueilTask({
    required this.id,
    required this.kind,
    required this.title,
    required this.subtitle,
    required this.route,
    required this.priority,
  });

  final String id;
  final String kind;
  final String title;
  final String subtitle;
  final String route;
  final int priority;
}
