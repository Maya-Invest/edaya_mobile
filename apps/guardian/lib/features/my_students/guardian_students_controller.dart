import 'dart:async';

import 'package:edaya_api_client/edaya_api_client.dart' as api;
import 'package:edaya_shared/edaya_shared.dart';
import 'package:levit_flutter/levit_flutter.dart';

import 'linked_student.dart';

class GuardianStudentsController extends LevitController
    with LevitReactiveTasksMixin {
  GuardianStudentsController({
    required AppSessionController session,
    required SchoolClientFactory schoolClient,
  }) : _session = session,
       _schoolClient = schoolClient;

  final AppSessionController _session;
  final SchoolClientFactory _schoolClient;

  final students = LxVar<List<LinkedStudent>>(const []);
  final groups = LxVar<List<GuardianSchoolGroup>>(const []);
  final errorMessage = LxVar('');

  @override
  void onInit() {
    super.onInit();
    autoDispose(students);
    autoDispose(groups);
    autoDispose(errorMessage);
    unawaited(loadStudents());
  }

  Future<void> loadStudents() async {
    errorMessage('');
    await runTask(() async {
      final grants = _session.grants.value;
      if (grants == null || grants.kind != 'guardian') {
        students(const []);
        groups(const []);
        return;
      }

      try {
        final studentIds = await loadGuardianLinkedStudentIds(
          _schoolClient(),
          grants.actorId,
        );

        if (studentIds.isEmpty) {
          students(const []);
          groups(const []);
          return;
        }

        final rows = await _schoolClient().students.list(
          entitiesByIds(studentIds),
        );
        final linkedStudents = rows.map(LinkedStudent.fromJson).toList();
        final schoolIds = <String>{
          if (grants.schoolId.isNotEmpty) grants.schoolId,
          for (final student in linkedStudents)
            if (student.schoolId.isNotEmpty) student.schoolId,
        };
        final schoolNames = <String, String>{};
        for (final schoolId in schoolIds) {
          schoolNames[schoolId] = await _loadSchoolName(schoolId);
        }

        students(linkedStudents);
        groups(
          groupStudentsBySchool(
            students: linkedStudents,
            schoolNames: schoolNames,
            fallbackSchoolId: grants.schoolId,
          ),
        );
      } on api.ApiError catch (error) {
        errorMessage(systemL10n().couldNotLoadLinkedStudents(error.toString()));
        students(const []);
        groups(const []);
      } on Object catch (error) {
        errorMessage(systemL10n().couldNotLoadLinkedStudents(error.toString()));
        students(const []);
        groups(const []);
      }
    }, id: 'load-students');
  }

  Future<String> _loadSchoolName(String schoolId) async {
    try {
      final row = await _schoolClient().schools.get(schoolId);
      final name = row['name'] as String?;
      if (name != null && name.trim().isNotEmpty) return name;
    } on Object {
      // Fall back to the school id when the name is not readable.
    }
    return schoolId;
  }
}
