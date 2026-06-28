import 'dart:async';

import 'package:edaya_api_client/edaya_api_client.dart' as api;
import 'package:levit_flutter/levit_flutter.dart';

import '../../access/app_runtime.dart';
import '../../common/utils/entity_query.dart';
import '../auth/app_session_controller.dart';
import '../auth/session_storage.dart';
import 'academic_year_controller.dart';

class AssignedClass {
  const AssignedClass({required this.id, required this.label});

  final String id;
  final String label;
}

class StaffContextController extends LevitController
    with LevitReactiveTasksMixin {
  StaffContextController({
    required SessionStorage sessionStorage,
    required AppSessionController session,
    required AcademicYearController academicYear,
  }) : _sessionStorage = sessionStorage,
       _session = session,
       _academicYear = academicYear;

  final SessionStorage _sessionStorage;
  final AppSessionController _session;
  final AcademicYearController _academicYear;

  final staffName = LxVar<String?>(null);
  final staffPhotoUrl = LxVar<String?>(null);
  final staffId = LxVar<String?>(null);
  final assignedClasses = LxVar<List<AssignedClass>>(const []);
  final classFilterId = LxVar<String?>(null);
  final taughtClassSubjectIds = LxVar<Set<String>>({});
  final assignedSessionIds = LxVar<Set<String>>({});
  final assignedClassGroupIds = LxVar<Set<String>>({});
  final isLoading = LxVar(false);
  final errorMessage = LxVar('');

  @override
  void onInit() {
    super.onInit();
    autoDispose(staffName);
    autoDispose(staffPhotoUrl);
    autoDispose(staffId);
    autoDispose(assignedClasses);
    autoDispose(classFilterId);
    autoDispose(taughtClassSubjectIds);
    autoDispose(assignedSessionIds);
    autoDispose(assignedClassGroupIds);
    autoDispose(isLoading);
    autoDispose(errorMessage);

    autoDispose(
      _academicYear.selectedYearId.stream.listen((_) {
        unawaited(reloadContext());
      }),
    );
  }

  List<String> get visibleClassGroupIds {
    final filter = classFilterId.value;
    if (filter != null) {
      return [filter];
    }
    return assignedClasses.value.map((entry) => entry.id).toList();
  }

  String? get classFilterLabel {
    final filter = classFilterId.value;
    if (filter == null) {
      return null;
    }
    for (final assigned in assignedClasses.value) {
      if (assigned.id == filter) {
        return assigned.label;
      }
    }
    return filter;
  }

  Future<void> initializeFromSession() async {
    final persistedFilter = await _sessionStorage.readClassFilterId();
    classFilterId(persistedFilter);
    await reloadContext();
  }

  Future<void> selectClassFilter(String? classGroupId) async {
    classFilterId(classGroupId);
    await _sessionStorage.writeClassFilterId(classGroupId);
  }

  Future<void> reloadContext() async {
    final grants = _session.grants.value;
    if (grants == null || grants.kind != 'staff') {
      staffId(null);
      staffName(null);
      staffPhotoUrl(null);
      assignedClasses(const []);
      taughtClassSubjectIds({});
      assignedSessionIds({});
      assignedClassGroupIds({});
      return;
    }

    final resolvedStaffId = grants.actorId;
    staffId(resolvedStaffId);
    errorMessage('');

    await runTask(() async {
      isLoading(true);
      try {
        final client = AppRuntime.schoolClient();
        try {
          final staff = await client.staffMembers.get(resolvedStaffId);
          final firstName = staff['firstName'] as String? ?? '';
          final lastName = staff['lastName'] as String? ?? '';
          final fullName = '$firstName $lastName'.trim();
          staffName(
            fullName.isEmpty ? (_session.user.value?.name ?? 'Teacher') : fullName,
          );
          staffPhotoUrl(staff['photoUrl'] as String?);
        } on Object {
          staffName(_session.user.value?.name ?? 'Teacher');
          staffPhotoUrl(null);
        }

        final teachingScope = teachingScopeFromScopeGrants(
          grants.effectiveGrants.scopeGrants,
        );
        final sessionIds = teachingScope.sessionIds;
        final classGroupIds = teachingScope.classGroupIds;
        final taughtSubjectIds = teachingScope.classSubjectIds;

        final classSubjectRows = taughtSubjectIds.isEmpty
            ? <Map<String, dynamic>>[]
            : await client.classSubjects.list(
                entitiesByIds(taughtSubjectIds.toList()),
              );
        taughtClassSubjectIds(taughtSubjectIds);
        assignedSessionIds(sessionIds);
        assignedClassGroupIds(classGroupIds);

        final allClassGroupIds = {
          ...classGroupIds,
          ...classSubjectRows.map((row) => row['classGroupId'] as String),
        };

        final classes = <AssignedClass>[];
        for (final classGroupId in allClassGroupIds) {
          try {
            final classGroup = await client.classGroups.get(classGroupId);
            classes.add(
              AssignedClass(
                id: classGroupId,
                label: classGroup['name'] as String? ?? classGroupId,
              ),
            );
          } on Object {
            classes.add(AssignedClass(id: classGroupId, label: classGroupId));
          }
        }
        classes.sort((a, b) => a.label.compareTo(b.label));
        assignedClasses(classes);

        final persistedFilter = await _sessionStorage.readClassFilterId();
        if (persistedFilter != null &&
            !classes.any((entry) => entry.id == persistedFilter)) {
          await selectClassFilter(null);
        }
      } on api.ApiError catch (error) {
        errorMessage('Could not load teaching context: $error');
      } on Object catch (error) {
        errorMessage('Could not load teaching context: $error');
      } finally {
        isLoading(false);
      }
    });
  }

  bool canTeachSession({
    required String sessionId,
    required String? classGroupId,
    required String? classSubjectId,
  }) {
    if (assignedSessionIds.value.contains(sessionId)) {
      return true;
    }
    if (classGroupId != null &&
        assignedClassGroupIds.value.contains(classGroupId) &&
        classSubjectId == null) {
      return true;
    }
    if (classSubjectId != null &&
        taughtClassSubjectIds.value.contains(classSubjectId)) {
      return true;
    }
    if (classGroupId != null &&
        assignedClassGroupIds.value.contains(classGroupId)) {
      return true;
    }
    return false;
  }
}
