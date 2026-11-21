import 'package:edaya_api_client/edaya_api_client.dart';
import 'package:edaya_auth/edaya_auth.dart';
import 'package:edaya_shared/edaya_shared.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:levit_flutter/levit_flutter.dart';
import '../../app/guardian_words.dart';
import '../../design/components/surface_card.dart';
import '../../live/runtime.dart';
import '../../mock/mock_store.dart';
import '../my_students/linked_student.dart';
import 'guardian_choices.dart';
import 'student_context_controller.dart';
import 'pupil_enrollment_years.dart';

Future<void> prepareGuardianContext({
  required AuthClient auth,
  required AppSessionController session,
  required StudentContextController student,
}) async {
  GuardianChoices? verified;
  if (!session.hasSchoolSession && session.isAuthenticated) {
    final account = session.user.value?.id;
    final choices = await loadChildChoices(auth, session);
    if (account != session.user.value?.id) return;
    final choice =
        choices.where((g) => g.children.isNotEmpty).firstOrNull ??
        choices.where((g) => g.data != null).firstOrNull ??
        choices.firstOrNull;
    if (choice != null) {
      final failure = await session.selectProfile(choice.profile);
      if (account != session.user.value?.id) return;
      if (failure != null) throw StateError(failure);
      verified = choice.data;
    }
  }
  await student.initializeFromSession(choices: verified);
}

class ChildSchoolChoices {
  ChildSchoolChoices(this.profile, this.data)
    : children = [...?data?.children]
        ..sort((a, b) => a.fullName.compareTo(b.fullName));
  final SchoolAuthorizationProfile profile;
  final GuardianChoices? data;
  final List<LinkedStudent> children;
  List<Map<String, dynamic>> get years => data?.years ?? const [];
  List<Map<String, dynamic>> get enrollments => data?.enrollments ?? const [];
  String? classFor(String studentId, String? year) {
    final rows =
        enrollments
            .where(
              (e) => e['studentId'] == studentId && e['academicYearId'] == year,
            )
            .toList()
          ..sort(
            (a, b) => (b['enrollmentIndex'] as int).compareTo(
              a['enrollmentIndex'] as int,
            ),
          );
    return rows.firstOrNull?['classLabel'] as String?;
  }
}

List<SchoolAuthorizationProfile> _guardianProfiles(
  AppSessionController session,
) =>
    session.availableProfiles.value.where((p) => p.kind == 'guardian').toList()
      ..sort((a, b) => a.schoolName.compareTo(b.schoolName));

Future<ChildSchoolChoices> _loadSchoolChoice(
  AuthClient auth,
  SchoolAuthorizationProfile profile,
  String? account,
) async {
  final client = createEdayaSchoolClient(
    auth,
    getActorKind: () => 'guardian',
    getActorId: () => profile.actorId,
    getSchoolId: () => profile.schoolId,
    getAcademicYearId: () => null,
  );
  try {
    final data = GuardianChoices.fromJson(
      await client.getGuardianChildChoices({}),
      accountId: account,
    );
    if (data.guardianId != profile.actorId ||
        data.schoolId != profile.schoolId) {
      throw StateError('Guardian profile changed');
    }
    return ChildSchoolChoices(profile, data);
  } catch (_) {
    return ChildSchoolChoices(profile, null);
  }
}

Future<List<ChildSchoolChoices>> loadChildChoices(
  AuthClient auth,
  AppSessionController session,
) => Future.wait([
  for (final profile in _guardianProfiles(session))
    _loadSchoolChoice(auth, profile, session.user.value?.id),
]);

class ChildPicker extends StatefulWidget {
  const ChildPicker({super.key});
  @override
  State<ChildPicker> createState() => _ChildPickerState();
}

class _ChildPickerState extends State<ChildPicker> {
  final _reads = <(String?, String, String), Future<ChildSchoolChoices>>{};
  bool busy = false;
  String? error;
  final expanded = <String>{};
  final selectedYears = <String, String>{};

  Future<void> select(
    ChildSchoolChoices group,
    LinkedStudent child, {
    String? yearId,
  }) async {
    if (busy) return;
    final session = context.levit.find<AppSessionController>();
    final students = context.levit.find<StudentContextController>();
    final account = session.user.value?.id;
    if (account != group.data?.accountId) return;
    setState(() {
      busy = true;
      error = null;
    });
    students.beginSwitch();
    try {
      if (session.schoolIdHeader != group.profile.schoolId ||
          session.actorIdHeader != group.profile.actorId) {
        final failure = await session.selectProfile(group.profile);
        if (failure != null) throw StateError(failure);
      }
      if (account != session.user.value?.id) {
        throw StateError('Account changed');
      }
      await students.initializeFromSession(
        preferredStudentId: child.id,
        preferredYearId: yearId,
      );
      if (account != session.user.value?.id ||
          !students.linkedStudentIds.value.contains(child.id)) {
        throw StateError('Access changed');
      }
      if (students.activeStudentId != child.id) {
        throw StateError('Selection unavailable');
      }
      if (mounted) context.go(_returnPath(context));
    } catch (_) {
      if (mounted) {
        setState(() {
          busy = false;
          error = words(
            context,
            'Impossible de sélectionner cet enfant. Réessayez.',
            'Unable to select this child. Try again.',
          );
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!prototypeIsLive(context)) {
      final store = context.levit.find<MockStore>();
      return ListView(
        children: [
          for (final group in store.studentsBySchool) ...[
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                group.school.name,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            for (final child in group.students)
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 4,
                ),
                child: SurfaceCard(
                  child: ListTile(
                    title: Text(child.fullName),
                    subtitle: Text(
                      store.selectedYearForSchool(group.school.id),
                    ),
                    onTap: () {
                      store.selectStudent(child.id);
                      context.go(_returnPath(context));
                    },
                  ),
                ),
              ),
          ],
        ],
      );
    }
    final session = context.levit.find<AppSessionController>();
    final auth = context.levit.find<AuthClient>();
    return LWatch(() {
      final account = session.user.value?.id;
      final profiles = _guardianProfiles(session);
      final keys = {for (final p in profiles) (account, p.schoolId, p.actorId)};
      _reads.removeWhere((key, _) => !keys.contains(key));
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (busy) const LinearProgressIndicator(),
          if (error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Text(
                error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          for (final profile in profiles)
            FutureBuilder<ChildSchoolChoices>(
              key: ValueKey((account, profile.schoolId, profile.actorId)),
              future: _reads.putIfAbsent((
                account,
                profile.schoolId,
                profile.actorId,
              ), () => _loadSchoolChoice(auth, profile, account)),
              builder: (context, snapshot) {
                final group = snapshot.data;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      profile.schoolName,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 12),
                    if (snapshot.connectionState != ConnectionState.done)
                      const LinearProgressIndicator()
                    else if (group?.data == null)
                      TextButton.icon(
                        onPressed: busy
                            ? null
                            : () => setState(() {
                                _reads.remove((
                                  account,
                                  profile.schoolId,
                                  profile.actorId,
                                ));
                              }),
                        icon: const Icon(Icons.refresh),
                        label: Text(words(context, 'Réessayer', 'Retry')),
                      )
                    else if (group!.children.isEmpty)
                      Text(
                        words(
                          context,
                          'Aucun enfant lié',
                          'No linked children',
                        ),
                      ),
                    if (group != null &&
                        snapshot.connectionState == ConnectionState.done)
                      for (final child in group.children)
                        Builder(
                          builder: (context) {
                            final key =
                                '$account/${profile.schoolId}/${profile.actorId}/${child.id}';
                            final years = pupilEnrollmentYears(
                              group.years,
                              group.enrollments,
                              child.id,
                            );
                            final current = context.levit
                                .find<StudentContextController>();
                            final active =
                                current.activeStudentId == child.id &&
                                session.schoolIdHeader == profile.schoolId &&
                                session.actorIdHeader == profile.actorId;
                            final selected =
                                selectedYears[key] ??
                                (active &&
                                        years.any(
                                          (y) =>
                                              y['id'] == current.activeYearId,
                                        )
                                    ? current.activeYearId
                                    : defaultPupilYear(years));
                            final open =
                                expanded.contains(key) && years.length > 1;
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: SurfaceCard(
                                padding: EdgeInsets.zero,
                                child: Column(
                                  children: [
                                    ListTile(
                                      leading: PersonAvatar(
                                        name: child.fullName,
                                        initials: child.initials,
                                        photoUrl: child.photoUrl,
                                      ),
                                      title: Text(child.fullName),
                                      subtitle: Text(
                                        years.isEmpty
                                            ? words(
                                                context,
                                                'Sans inscription',
                                                'No enrollment',
                                              )
                                            : [
                                                group.classFor(
                                                  child.id,
                                                  selected,
                                                ),
                                                years
                                                        .where(
                                                          (y) =>
                                                              y['id'] ==
                                                              selected,
                                                        )
                                                        .firstOrNull?['name']
                                                    as String?,
                                              ].whereType<String>().join(' · '),
                                      ),
                                      selected: active,
                                      onTap: busy
                                          ? null
                                          : years.length > 1
                                          ? () => setState(() {
                                              if (!expanded.add(key)) {
                                                expanded.remove(key);
                                              }
                                            })
                                          : () => select(
                                              group,
                                              child,
                                              yearId: selected,
                                            ),
                                      trailing: years.length <= 1
                                          ? null
                                          : IconButton(
                                              key: ValueKey('pupil-years-$key'),
                                              tooltip: words(
                                                context,
                                                'Choisir une année scolaire',
                                                'Choose a school year',
                                              ),
                                              onPressed: busy
                                                  ? null
                                                  : () => setState(() {
                                                      if (!expanded.add(key)) {
                                                        expanded.remove(key);
                                                      }
                                                    }),
                                              icon: Icon(
                                                open
                                                    ? Icons.expand_less
                                                    : Icons.expand_more,
                                              ),
                                            ),
                                    ),
                                    if (open)
                                      Padding(
                                        padding: const EdgeInsets.fromLTRB(
                                          16,
                                          0,
                                          16,
                                          16,
                                        ),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.stretch,
                                          children: [
                                            DropdownButtonFormField<String>(
                                              key: ValueKey((key, selected)),
                                              initialValue: selected,
                                              isExpanded: true,
                                              decoration: InputDecoration(
                                                labelText: words(
                                                  context,
                                                  'Année scolaire',
                                                  'School year',
                                                ),
                                              ),
                                              items: [
                                                for (final year in years)
                                                  DropdownMenuItem(
                                                    value: year['id'] as String,
                                                    child: Text(
                                                      year['name'] as String? ??
                                                          year['id'] as String,
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                    ),
                                                  ),
                                              ],
                                              onChanged: busy
                                                  ? null
                                                  : (id) {
                                                      if (id != null) {
                                                        setState(
                                                          () =>
                                                              selectedYears[key] =
                                                                  id,
                                                        );
                                                      }
                                                    },
                                            ),
                                            const SizedBox(height: 8),
                                            FilledButton(
                                              onPressed: busy
                                                  ? null
                                                  : () => select(
                                                      group,
                                                      child,
                                                      yearId: selected,
                                                    ),
                                              child: Text(
                                                words(
                                                  context,
                                                  'Appliquer',
                                                  'Apply',
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                    const SizedBox(height: 24),
                  ],
                );
              },
            ),
        ],
      );
    });
  }
}

String _returnPath(BuildContext context) {
  final path = GoRouterState.of(context).uri.queryParameters['return'];
  return const [
        '/home',
        '/calendar',
        '/scolarite/progress',
        '/scolarite/notes',
        '/fees',
        '/inbox',
        '/inbox/avis',
        '/child',
      ].contains(path)
      ? path!
      : '/home';
}
