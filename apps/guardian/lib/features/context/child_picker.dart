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
import 'academic_year_controller.dart';
import 'student_context_controller.dart';

Future<void> prepareGuardianContext({
  required AuthClient auth,
  required AppSessionController session,
  required AcademicYearController year,
  required StudentContextController student,
}) async {
  if (!session.hasSchoolSession && session.isAuthenticated) {
    final choices = await loadChildChoices(auth, session);
    final choice =
        choices.where((g) => g.children.isNotEmpty).firstOrNull ??
        choices.firstOrNull;
    if (choice != null) await session.selectProfile(choice.profile);
  }
  await year.loadYears();
  await student.initializeFromSession();
}

class ChildSchoolChoices {
  const ChildSchoolChoices(
    this.profile, {
    this.children = const [],
    this.classes = const {},
    this.year,
    this.error,
  });
  final SchoolAuthorizationProfile profile;
  final List<LinkedStudent> children;
  final Map<String, String> classes;
  final String? year, error;
}

Future<List<ChildSchoolChoices>> loadChildChoices(
  AuthClient auth,
  AppSessionController session,
) async {
  final profiles =
      session.availableProfiles.value
          .where((p) => p.kind == 'guardian')
          .toList()
        ..sort((a, b) => a.schoolName.compareTo(b.schoolName));
  return Future.wait(
    profiles.map((profile) async {
      String? yearId;
      final client = createEdayaSchoolClient(
        auth,
        getActorKind: () => 'guardian',
        getActorId: () => profile.actorId,
        getSchoolId: () => profile.schoolId,
        getAcademicYearId: () => yearId,
      );
      try {
        final years = await client.academicYears.listAll();
        final year = years.where((y) => y['status'] == 'published').firstOrNull;
        yearId = year?['id'] as String?;
        final ids = await loadGuardianLinkedStudentIds(client, profile.actorId);
        final students = ids.isEmpty
            ? <Map<String, dynamic>>[]
            : await client.students.listAll(entitiesByIds(ids));
        final children = students.map(LinkedStudent.fromJson).toList()
          ..sort((a, b) => a.fullName.compareTo(b.fullName));
        final classes = <String, String>{};
        if (yearId != null && ids.isNotEmpty) {
          final enrollments = await client.enrollments.listAll({
            'studentId': {'\$in': ids},
            'academicYearId': yearId,
            'status': 'active',
          });
          final groupIds = enrollments
              .map((r) => r['classGroupId'])
              .whereType<String>()
              .toSet()
              .toList();
          final groups = groupIds.isEmpty
              ? <Map<String, dynamic>>[]
              : await client.classGroups.listAll(entitiesByIds(groupIds));
          for (final e in enrollments) {
            classes[e['studentId'] as String] =
                groups
                        .where((g) => g['id'] == e['classGroupId'])
                        .firstOrNull?['name']
                    as String? ??
                '';
          }
        }
        return ChildSchoolChoices(
          profile,
          children: children,
          classes: classes,
          year: year?['name'] as String?,
        );
      } catch (_) {
        return ChildSchoolChoices(profile, error: 'unavailable');
      }
    }),
  );
}

class ChildPicker extends StatefulWidget {
  const ChildPicker({super.key});
  @override
  State<ChildPicker> createState() => _ChildPickerState();
}

class _ChildPickerState extends State<ChildPicker> {
  Future<List<ChildSchoolChoices>>? choices;
  bool busy = false;
  String? error;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (prototypeIsLive(context)) {
      choices ??= loadChildChoices(
        context.levit.find<AuthClient>(),
        context.levit.find<AppSessionController>(),
      );
    }
  }

  Future<void> select(ChildSchoolChoices group, LinkedStudent child) async {
    if (busy) return;
    final session = context.levit.find<AppSessionController>();
    final students = context.levit.find<StudentContextController>();
    final year = context.levit.find<AcademicYearController>();
    final account = session.user.value?.id;
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
      await year.loadYears();
      await students.initializeFromSession(preferredStudentId: child.id);
      if (account != session.user.value?.id ||
          !students.linkedStudentIds.value.contains(child.id)) {
        throw StateError('Access changed');
      }
      if (students.activeStudentId != child.id) {
        throw StateError('Selection unavailable');
      }
      if (mounted) context.go('/home');
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
          for (final child in store.students)
            ListTile(
              title: Text(child.fullName),
              onTap: () {
                store.selectStudent(child.id);
                context.go('/home');
              },
            ),
        ],
      );
    }
    return FutureBuilder<List<ChildSchoolChoices>>(
      future: choices,
      builder: (context, snapshot) => ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (!snapshot.hasData || busy) const LinearProgressIndicator(),
          if (error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Text(
                error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          for (final group in snapshot.data ?? <ChildSchoolChoices>[]) ...[
            Text(
              group.profile.schoolName,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            if (group.year != null)
              Text(group.year!, style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 12),
            if (group.error != null)
              TextButton.icon(
                onPressed: busy
                    ? null
                    : () => setState(
                        () => choices = loadChildChoices(
                          context.levit.find<AuthClient>(),
                          context.levit.find<AppSessionController>(),
                        ),
                      ),
                icon: const Icon(Icons.refresh),
                label: Text(words(context, 'Réessayer', 'Retry')),
              ),
            if (group.error == null && group.children.isEmpty)
              Text(words(context, 'Aucun enfant lié', 'No linked children')),
            SurfaceCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  for (final child in group.children)
                    ListTile(
                      leading: PersonAvatar(
                        name: child.fullName,
                        initials: child.initials,
                        photoUrl: child.photoUrl,
                      ),
                      title: Text(child.fullName),
                      subtitle: Text(
                        group.classes[child.id] ??
                            words(
                              context,
                              'Sans inscription actuelle',
                              'No current enrollment',
                            ),
                      ),
                      trailing:
                          context.levit
                                  .find<StudentContextController>()
                                  .activeStudentId ==
                              child.id
                          ? const Icon(Icons.check_circle_outline)
                          : null,
                      onTap: busy ? null : () => select(group, child),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],
        ],
      ),
    );
  }
}
