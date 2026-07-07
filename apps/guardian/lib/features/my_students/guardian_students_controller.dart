import 'dart:async';

import 'package:edaya_api_client/edaya_api_client.dart' as api;
import 'package:levit_flutter/levit_flutter.dart';

import 'package:edaya_shared/edaya_shared.dart';
import '../my_students/linked_student.dart';

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
  final errorMessage = LxVar('');

  @override
  void onInit() {
    super.onInit();
    autoDispose(students);
    autoDispose(errorMessage);
    unawaited(loadStudents());
  }

  Future<void> loadStudents() async {
    errorMessage('');
    await runTask(() async {
      final grants = _session.grants.value;
      if (grants == null || grants.kind != 'guardian') {
        students(const []);
        return;
      }

      try {
        final studentIds = await loadGuardianLinkedStudentIds(
          _schoolClient(),
          grants.actorId,
        );

        if (studentIds.isEmpty) {
          students(const []);
          return;
        }

        final rows = await _schoolClient().students.list(
          entitiesByIds(studentIds),
        );
        final linkedStudents = rows.map(LinkedStudent.fromJson).toList()
          ..sort((a, b) => a.fullName.compareTo(b.fullName));
        students(linkedStudents);
      } on api.ApiError catch (error) {
        errorMessage(systemL10n().couldNotLoadLinkedStudents(error.toString()));
        students(const []);
      } on Object catch (error) {
        errorMessage(systemL10n().couldNotLoadLinkedStudents(error.toString()));
        students(const []);
      }
    }, id: 'load-students');
  }
}
