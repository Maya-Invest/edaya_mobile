import 'package:edaya_api_client/edaya_api_client.dart';
import 'package:edaya_auth/edaya_auth.dart';
import 'package:edaya_shared/edaya_shared.dart';
import '../../live/entity_queries.dart';
import 'academic_year_controller.dart';
import 'teacher_context_controller.dart';

class TeacherSchoolChoices {
  const TeacherSchoolChoices(
    this.profile,
    this.options, {
    this.yearLabel,
    this.error,
  });
  final SchoolAuthorizationProfile profile;
  final List<TeacherAssignmentOption> options;
  final String? yearLabel;
  final String? error;
}

/// Read other schools with fixed headers; browsing never changes the active session.
Future<List<TeacherSchoolChoices>> loadTeacherSchoolChoices(
  AuthClient auth,
  List<SchoolAuthorizationProfile> profiles,
) async {
  final sorted = [...profiles.where((p) => p.kind == 'teacher')]
    ..sort((a, b) => a.schoolName.compareTo(b.schoolName));
  return Future.wait(
    sorted.map((profile) async {
      String? yearId;
      final client = createEdayaSchoolClient(
        auth,
        getSchoolId: () => profile.schoolId,
        getActorId: () => profile.actorId,
        getActorKind: () => 'teacher',
        getAcademicYearId: () => yearId,
      );
      try {
        final years = await client.academicYears.listAll();
        years.sort((a, b) => '${b['name']}'.compareTo('${a['name']}'));
        final year = publishedTeacherYear(years);
        yearId = year?['id'] as String?;
        if (yearId == null) {
          return TeacherSchoolChoices(
            profile,
            const [],
            error: 'Aucune année scolaire publiée.',
          );
        }
        final assignments = await client.teacherAssignments.list(
          teacherAssignmentsForTeacherAndYear(
            teacherId: profile.actorId,
            academicYearId: yearId,
          ),
        );
        final scope = teachingScopeFromTeacherAssignments(assignments);
        final subjects = scope.classSubjectIds.isEmpty
            ? <Map<String, dynamic>>[]
            : await client.classSubjects.list(
                entitiesByIds(scope.classSubjectIds.toList()),
              );
        final subjectIds = subjects
            .map((s) => s['subjectId'] as String)
            .toSet();
        final names = subjectIds.isEmpty
            ? <Map<String, dynamic>>[]
            : await client.subjects.list(entitiesByIds(subjectIds.toList()));
        final classIds = {
          ...scope.classGroupIds,
          ...subjects.map((s) => s['classGroupId'] as String),
        };
        final classes = classIds.isEmpty
            ? <Map<String, dynamic>>[]
            : await client.classGroups.list(entitiesByIds(classIds.toList()));
        final labels = {for (final c in classes) c['id']: c['name'] as String};
        final subjectLabels = {
          for (final s in names) s['id']: s['name'] as String,
        };
        final options = <TeacherAssignmentOption>[
          for (final subject in subjects)
            TeacherAssignmentOption(
              id: subject['id'] as String,
              classSubjectId: subject['id'] as String,
              classGroupId: subject['classGroupId'] as String,
              classLabel:
                  labels[subject['classGroupId']] ??
                  '${subject['classGroupId']}',
              subjectLabel: subjectLabels[subject['subjectId']] ?? 'Matière',
              isHomeroom: scope.classGroupIds.contains(subject['classGroupId']),
            ),
          for (final id in scope.classGroupIds)
            if (!subjects.any((s) => s['classGroupId'] == id))
              TeacherAssignmentOption(
                id: 'homeroom-$id',
                classGroupId: id,
                classLabel: labels[id] ?? id,
                subjectLabel: 'Titulaire',
                isHomeroom: true,
              ),
        ]..sort((a, b) => a.label.compareTo(b.label));
        return TeacherSchoolChoices(
          profile,
          options,
          yearLabel: year?['name'] as String?,
        );
      } on Object {
        return TeacherSchoolChoices(
          profile,
          const [],
          error: 'Impossible de charger les affectations. Réessayez.',
        );
      }
    }),
  );
}
