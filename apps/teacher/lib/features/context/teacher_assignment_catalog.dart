import 'package:edaya_api_client/edaya_api_client.dart';
import 'package:edaya_shared/edaya_shared.dart';
import 'package:flutter/foundation.dart' show setEquals;
import '../../live/entity_queries.dart';

class TeacherAssignmentOption {
  const TeacherAssignmentOption({
    required this.id,
    required this.classGroupId,
    required this.classLabel,
    required this.subjectLabel,
    required this.isHomeroom,
    this.classSubjectId,
  });

  final String id;
  final String classGroupId;
  final String classLabel;
  final String subjectLabel;
  final bool isHomeroom;
  final String? classSubjectId;
  String get label => [
    classLabel,
    if (classSubjectId != null) subjectLabel,
    if (isHomeroom) 'Titulaire',
  ].join(' · ');
}

class AssignedClass {
  const AssignedClass({
    required this.id,
    required this.label,
    this.dailyAttendance = false,
  });

  final String id;
  final String label;
  final bool dailyAttendance;
}

typedef AssignmentWorkspace = ({
  String account,
  String school,
  String actor,
  String year,
});

class TeacherAssignmentCatalog {
  TeacherAssignmentCatalog(
    this.workspace,
    this.scope,
    this.options,
    this.classes,
    this.classByAssignmentId,
    this._groupBySubject,
    this._validUntil,
  );
  final AssignmentWorkspace workspace;
  final TeachingScope scope;
  final List<TeacherAssignmentOption> options;
  final List<AssignedClass> classes;
  final Map<String, String> classByAssignmentId, _groupBySubject;
  final DateTime _validUntil;
  bool get fresh => DateTime.now().isBefore(_validUntil);
}

/// Assignment rows are authoritative on activation. A recent picker result can
/// supply the class and subject metadata when the eligible IDs still match.
Future<TeacherAssignmentCatalog> readTeacherAssignmentCatalog(
  SchoolClient client,
  AssignmentWorkspace workspace, {
  TeacherAssignmentCatalog? previous,
}) async {
  final rows = await client.teacherAssignments.listAll(
    teacherAssignmentsForTeacherAndYear(
      teacherId: workspace.actor,
      academicYearId: workspace.year,
    ),
  );
  final scope = teachingScopeFromTeacherAssignments(rows);
  final now = DateTime.now();
  var validUntil = now.add(const Duration(minutes: 1));
  for (final row in rows) {
    for (final key in ['startsAt', 'endsAt']) {
      final date = DateTime.tryParse(row[key] as String? ?? '');
      if (date != null && date.isAfter(now) && date.isBefore(validUntil)) {
        validUntil = date;
      }
    }
  }
  Map<String, String> assignmentClasses(Map<String, String> groups) => {
    for (final row in rows)
      if ((row['classGroupId'] ?? groups[row['classSubjectId']])
          case final String group)
        row['id'] as String: group,
  };
  if (previous != null &&
      previous.workspace == workspace &&
      previous.fresh &&
      setEquals(previous.scope.classGroupIds, scope.classGroupIds) &&
      setEquals(previous.scope.classSubjectIds, scope.classSubjectIds)) {
    return TeacherAssignmentCatalog(
      workspace,
      scope,
      previous.options,
      previous.classes,
      assignmentClasses(previous._groupBySubject),
      previous._groupBySubject,
      previous._validUntil.isBefore(validUntil)
          ? previous._validUntil
          : validUntil,
    );
  }

  final subjects = scope.classSubjectIds.isEmpty
      ? <Map<String, dynamic>>[]
      : await client.classSubjects.listAll(
          entitiesByIds(scope.classSubjectIds.toList()),
        );
  final groups = {
    for (final s in subjects) s['id'] as String: s['classGroupId'] as String,
  };
  final subjectIds = subjects
      .map((s) => s['subjectId'] as String?)
      .whereType<String>()
      .toSet();
  final classIds = {...scope.classGroupIds, ...groups.values};
  final results = await Future.wait([
    if (subjectIds.isEmpty)
      Future.value(<Map<String, dynamic>>[])
    else
      client.subjects.listAll(entitiesByIds(subjectIds.toList())),
    if (classIds.isEmpty)
      Future.value(<Map<String, dynamic>>[])
    else
      client.classGroups.listAll(entitiesByIds(classIds.toList())),
  ]);
  final names = {
    for (final s in results.first) s['id'] as String: s['name'] as String?,
  };
  final byId = {for (final c in results.last) c['id'] as String: c};
  String classLabel(String id) => byId[id]?['name'] as String? ?? id;
  final classes = [
    for (final id in classIds)
      AssignedClass(
        id: id,
        label: classLabel(id),
        dailyAttendance: byId[id]?['attendanceMode'] == 'daily',
      ),
  ]..sort((a, b) => a.label.compareTo(b.label));
  final taughtClasses = groups.values.toSet();
  final options =
      [
        for (final id in scope.classGroupIds)
          if (!taughtClasses.contains(id))
            TeacherAssignmentOption(
              id: 'homeroom-$id',
              classGroupId: id,
              classLabel: classLabel(id),
              subjectLabel: 'Titulaire',
              isHomeroom: true,
            ),
        for (final s in subjects)
          TeacherAssignmentOption(
            id: s['id'] as String,
            classSubjectId: s['id'] as String,
            classGroupId: s['classGroupId'] as String,
            classLabel: classLabel(s['classGroupId'] as String),
            subjectLabel: names[s['subjectId']] ?? systemL10n().subjectFallback,
            isHomeroom: scope.classGroupIds.contains(s['classGroupId']),
          ),
      ]..sort((a, b) {
        final c = a.classLabel.compareTo(b.classLabel);
        return c == 0 ? a.subjectLabel.compareTo(b.subjectLabel) : c;
      });
  return TeacherAssignmentCatalog(
    workspace,
    scope,
    options,
    classes,
    assignmentClasses(groups),
    groups,
    validUntil,
  );
}
