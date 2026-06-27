import 'dart:async';

import 'package:edaya_api_client/edaya_api_client.dart' as api;
import 'package:levit_flutter/levit_flutter.dart';

import '../../access/app_runtime.dart';
import '../../common/utils/entity_query.dart';
import '../auth/app_session_controller.dart';
import 'linked_student.dart';

class GuardianStudentsController extends LevitController
    with LevitReactiveTasksMixin {
  GuardianStudentsController({
    required AppSessionController session,
  }) : _session = session;

  final AppSessionController _session;

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
      if (grants == null) {
        students(const []);
        return;
      }

      final studentIds = studentIdsFromScopeGrants(
        grants.effectiveGrants.scopeGrants,
      );

      if (studentIds.isEmpty) {
        students(const []);
        return;
      }

      try {
        final rows = await AppRuntime.schoolClient().students.list(
          entitiesByIds(studentIds),
        );
        final linkedStudents = rows
            .map(LinkedStudent.fromJson)
            .toList()
          ..sort((a, b) => a.fullName.compareTo(b.fullName));
        students(linkedStudents);
      } on api.ApiError catch (error) {
        errorMessage('Could not load linked students: $error');
        students(const []);
      } on Object catch (error) {
        errorMessage('Could not load linked students: $error');
        students(const []);
      }
    }, id: 'load-students');
  }
}
