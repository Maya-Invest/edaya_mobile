import 'package:edaya_api_client/edaya_api_client.dart' as api;

/// Loads linked student ids for a guardian from `guardian-links` entity rows.
Future<List<String>> loadGuardianLinkedStudentIds(
  api.SchoolClient client,
  String guardianId,
) async {
  final links = await client.guardianLinks.list({'guardianId': guardianId});
  final ids = <String>{};
  for (final link in links) {
    final studentId = link['studentId'] as String?;
    if (studentId != null && studentId.isNotEmpty) {
      ids.add(studentId);
    }
  }
  return ids.toList()..sort();
}
