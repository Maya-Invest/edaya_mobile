import 'dart:async';

import 'package:edaya_api_client/edaya_api_client.dart' as api;
import 'package:edaya_shared/edaya_shared.dart';
import 'package:levit_flutter/levit_flutter.dart';

import '../../live/entity_queries.dart';
import '../../live/runtime.dart';
import '../context/academic_year_controller.dart';
import '../context/teacher_context_controller.dart';

class LiveRosterStudent {
  const LiveRosterStudent({
    required this.id,
    required this.fullName,
    required this.initials,
    this.photoUrl,
  });

  final String id;
  final String fullName;
  final String initials;
  final String? photoUrl;
}

class LiveRosterController extends LevitController
    with LevitReactiveTasksMixin {
  LiveRosterController({
    required this.classGroupId,
    this.studentId,
    required AcademicYearController academicYear,
    required TeacherContextController teacherContext,
    required SchoolClientFactory schoolClient,
  }) : _academicYear = academicYear,
       _teacherContext = teacherContext,
       _schoolClient = schoolClient;

  final String classGroupId;
  final String? studentId;
  final AcademicYearController _academicYear;
  final TeacherContextController _teacherContext;
  final SchoolClientFactory _schoolClient;

  final students = LxVar<List<LiveRosterStudent>>(const []);
  final errorMessage = LxVar('');
  final canRecordDaily = LxVar(false);

  String get classLabel {
    for (final assigned in _teacherContext.assignedClasses.value) {
      if (assigned.id == classGroupId) {
        return assigned.label;
      }
    }
    return classGroupId;
  }

  LiveRosterStudent? get selectedStudent {
    final id = studentId;
    if (id == null) {
      return null;
    }
    for (final student in students.value) {
      if (student.id == id) {
        return student;
      }
    }
    return null;
  }

  @override
  void onInit() {
    super.onInit();
    autoDispose(students);
    autoDispose(errorMessage);
    autoDispose(canRecordDaily);
    unawaited(load());
  }

  Future<void> load() async {
    errorMessage('');
    await runTask(() async {
      try {
        final client = _schoolClient();
        final group = await client.classGroups.get(classGroupId);
        canRecordDaily(
          group['attendanceMode'] == 'daily' &&
              _teacherContext.assignments.value.any(
                (a) => a.isHomeroom && a.classGroupId == classGroupId,
              ),
        );
        final enrollmentRows = await client.enrollments.list(
          activeEnrollmentsForClass(
            classGroupId,
            academicYearId: _academicYear.selectedYearId.value,
          ),
        );
        final studentIds = enrollmentRows
            .map((row) => row['studentId'] as String?)
            .whereType<String>()
            .toList();
        final studentRows = studentIds.isEmpty
            ? <Map<String, dynamic>>[]
            : await client.students.list(entitiesByIds(studentIds));
        final roster = studentRows.map((row) {
          final id = row['id'] as String;
          final firstName = row['firstName'] as String? ?? '';
          final lastName = row['lastName'] as String? ?? '';
          final fullName = '$firstName $lastName'.trim();
          final displayName = fullName.isEmpty ? id : fullName;
          return LiveRosterStudent(
            id: id,
            fullName: displayName,
            initials: personInitials(displayName),
            photoUrl: row['photoUrl'] as String?,
          );
        }).toList()..sort((a, b) => a.fullName.compareTo(b.fullName));
        students(roster);
      } on api.ApiError catch (error) {
        errorMessage('$error');
      } on Object catch (error) {
        errorMessage('$error');
      }
    });
  }
}
