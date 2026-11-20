import 'package:edaya_api_client/edaya_api_client.dart';
import 'package:edaya_auth/edaya_auth.dart';
import 'package:edaya_shared/edaya_shared.dart';
import 'academic_year_controller.dart';
import 'teacher_assignment_catalog.dart';
import 'teacher_context_controller.dart' show TeacherContextController;

class TeacherSchoolChoices {
  const TeacherSchoolChoices(
    this.profile, {
    this.catalog,
    this.yearLabel,
    this.error,
  });
  final SchoolAuthorizationProfile profile;
  final TeacherAssignmentCatalog? catalog;
  final String? yearLabel, error;
  List<TeacherAssignmentOption> get options => catalog?.options ?? const [];
}

/// Build the picker with fixed school/actor headers; browsing never changes the active session.
Future<List<TeacherSchoolChoices>> loadTeacherSchoolChoices(
  AuthClient auth,
  AppSessionController session,
  TeacherContextController teacher,
  AcademicYearController year,
) async {
  final account = session.user.value?.id;
  if (account == null) return [];
  final sorted = [
    ...session.availableProfiles.value.where((p) => p.kind == 'teacher'),
  ]..sort((a, b) => a.schoolName.compareTo(b.schoolName));
  return Future.wait(
    sorted.map((profile) async {
      final current = teacher.catalog;
      if (!teacher.loadFailed.value &&
          !teacher.isLoading.value &&
          current != null &&
          current.fresh &&
          current.workspace ==
              (
                account: account,
                school: profile.schoolId,
                actor: profile.actorId,
                year: year.selectedYearId.value,
              )) {
        return TeacherSchoolChoices(
          profile,
          catalog: current,
          yearLabel: year.selectedYearLabel,
        );
      }
      if (profile.schoolId != session.schoolIdHeader ||
          profile.actorId != session.actorIdHeader) {
        final recent = teacher.recentCatalog(profile.schoolId, profile.actorId);
        if (recent != null) {
          return TeacherSchoolChoices(
            profile,
            catalog: recent.catalog,
            yearLabel: recent.yearLabel,
          );
        }
      }
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
        final published = publishedTeacherYear(years);
        yearId = published?['id'] as String?;
        if (yearId == null) {
          return TeacherSchoolChoices(
            profile,
            error: systemL10n().noPublishedSchoolYear,
          );
        }
        final data = await readTeacherAssignmentCatalog(client, (
          account: account,
          school: profile.schoolId,
          actor: profile.actorId,
          year: yearId,
        ));
        final label = published?['name'] as String?;
        teacher.rememberCatalog(data, label);
        return TeacherSchoolChoices(profile, catalog: data, yearLabel: label);
      } on Object {
        return TeacherSchoolChoices(
          profile,
          error: systemL10n().couldNotLoadAssignmentsTryAgain,
        );
      }
    }),
  );
}
