import 'package:edaya_shared/edaya_shared.dart' hide PersonAvatar;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:levit_flutter/levit_flutter.dart';

import '../../design/colors.dart';
import '../../design/components/components.dart';
import '../../design/spacing.dart';
import '../../live/runtime.dart';
import '../../mock/mock_store.dart';
import '../context/academic_year_controller.dart';
import '../context/store_bound_controller.dart';
import '../context/teacher_context_controller.dart';
import 'live_roster_controller.dart';

class ClassesPage extends StatelessWidget {
  const ClassesPage({super.key});

  @override
  Widget build(BuildContext context) {
    if (prototypeIsLive(context)) {
      return const _LiveClassesPage();
    }
    return const _MockClassesPage();
  }
}

class _MockClassesPage extends LScopedView<StoreBoundController> {
  const _MockClassesPage();

  @override
  StoreBoundController onConfigScope(LevitScope scope) {
    return scope.put(() => StoreBoundController(scope.find<MockStore>()));
  }

  @override
  Widget buildView(BuildContext context, StoreBoundController controller) {
    controller.storeTick.value;
    final store = controller.store;
    final selectedClassId = GoRouterState.of(context).pathParameters['classId'];

    return AdaptiveContent(
      child: ListView.separated(
        padding: const EdgeInsets.all(PrototypeSpacing.md),
        itemCount: store.assignments.length,
        separatorBuilder: (_, _) => const SizedBox(height: PrototypeSpacing.xs),
        itemBuilder: (context, i) {
          final a = store.assignments[i];
          final selected = selectedClassId == a.classId;
          return ListRow(
            title: a.classLabel,
            subtitle: '${a.subjectLabel} · ${a.studentCount} élèves',
            selected: selected,
            leading: Icon(
              a.isHomeroom ? Icons.star_outline : Icons.groups_outlined,
              color: PrototypeColors.primary,
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.go('/classes/${a.classId}'),
          );
        },
      ),
    );
  }
}

class ClassRosterPage extends StatelessWidget {
  const ClassRosterPage({super.key, required this.classId});

  final String classId;

  @override
  Widget build(BuildContext context) {
    if (prototypeIsLive(context)) {
      return _LiveClassRosterPage(classId: classId);
    }
    return _MockClassRosterPage(classId: classId);
  }
}

class _MockClassRosterPage extends LScopedView<StoreBoundController> {
  const _MockClassRosterPage({required this.classId});

  final String classId;

  @override
  StoreBoundController onConfigScope(LevitScope scope) {
    return scope.put(() => StoreBoundController(scope.find<MockStore>()));
  }

  @override
  Widget buildView(BuildContext context, StoreBoundController controller) {
    controller.storeTick.value;
    final store = controller.store;
    final assignment = store.assignments
        .where((a) => a.classId == classId)
        .firstOrNull;
    final students = store.studentsFor(classId);
    final selectedStudentId = GoRouterState.of(
      context,
    ).pathParameters['studentId'];

    return PrototypeDetailScaffold(
      title: assignment?.classLabel ?? 'Classe',
      fallbackRoute: '/classes',
      body: ListView.separated(
        padding: const EdgeInsets.all(PrototypeSpacing.md),
        itemCount: students.length,
        separatorBuilder: (_, _) => const SizedBox(height: PrototypeSpacing.xs),
        itemBuilder: (context, i) {
          final s = students[i];
          return ListRow(
            title: s.fullName,
            selected: selectedStudentId == s.id,
            leading: PersonAvatar(initials: s.initials, radius: 18),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.go('/classes/$classId/student/${s.id}'),
          );
        },
      ),
    );
  }
}

class StudentProfilePage extends StatelessWidget {
  const StudentProfilePage({
    super.key,
    required this.classId,
    required this.studentId,
  });

  final String classId;
  final String studentId;

  @override
  Widget build(BuildContext context) {
    if (prototypeIsLive(context)) {
      return _LiveStudentProfilePage(classId: classId, studentId: studentId);
    }
    return _MockStudentProfilePage(classId: classId, studentId: studentId);
  }
}

class _MockStudentProfilePage extends LScopedView<StoreBoundController> {
  const _MockStudentProfilePage({
    required this.classId,
    required this.studentId,
  });

  final String classId;
  final String studentId;

  @override
  StoreBoundController onConfigScope(LevitScope scope) {
    return scope.put(() => StoreBoundController(scope.find<MockStore>()));
  }

  @override
  Widget buildView(BuildContext context, StoreBoundController controller) {
    controller.storeTick.value;
    final student = controller.store.studentById(studentId);
    if (student == null) {
      return const PrototypeDetailScaffold(
        title: 'Élève',
        body: EmptyState(title: 'Élève introuvable'),
      );
    }

    return PrototypeDetailScaffold(
      title: student.fullName,
      fallbackRoute: '/classes/$classId',
      body: ListView(
        padding: const EdgeInsets.all(PrototypeSpacing.md),
        children: [
          SurfaceCard(
            child: Row(
              children: [
                PersonAvatar(initials: student.initials, radius: 28),
                const SizedBox(width: PrototypeSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        student.fullName,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      Text(
                        controller.store.assignments
                                .where((a) => a.classId == classId)
                                .firstOrNull
                                ?.classLabel ??
                            classId,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: PrototypeSpacing.md),
          const SectionHeader(title: 'Aperçu rapide'),
          const SizedBox(height: PrototypeSpacing.sm),
          const ListRow(
            title: 'Assiduité',
            subtitle: 'Présent · 94 % ce mois',
            badge: 'OK',
          ),
          const SizedBox(height: PrototypeSpacing.xs),
          const ListRow(
            title: 'Dernière note',
            subtitle: 'Mathématiques · DS Fractions',
            trailing: Text('14/20'),
          ),
        ],
      ),
    );
  }
}

class _LiveClassesPage extends LView<TeacherContextController> {
  const _LiveClassesPage();

  @override
  Widget buildView(BuildContext context, TeacherContextController controller) {
    return LWatch(() {
      controller.assignments.value;
      controller.activeAssignmentId.value;
      final selectedClassId = GoRouterState.of(
        context,
      ).pathParameters['classId'];
      final assignments = controller.assignments.value;
      return AdaptiveContent(
        child: assignments.isEmpty
            ? const EmptyState(title: 'Aucune classe affectée')
            : ListView.separated(
                padding: const EdgeInsets.all(PrototypeSpacing.md),
                itemCount: assignments.length,
                separatorBuilder: (_, _) =>
                    const SizedBox(height: PrototypeSpacing.xs),
                itemBuilder: (context, i) {
                  final a = assignments[i];
                  final selected = selectedClassId == a.classGroupId;
                  return ListRow(
                    title: a.classLabel,
                    subtitle: a.isHomeroom
                        ? '${a.subjectLabel} · Titulaire'
                        : a.subjectLabel,
                    selected: selected,
                    leading: Icon(
                      a.isHomeroom ? Icons.star_outline : Icons.groups_outlined,
                      color: PrototypeColors.primary,
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => context.go('/classes/${a.classGroupId}'),
                  );
                },
              ),
      );
    });
  }
}

class _LiveClassRosterPage extends LScopedView<LiveRosterController> {
  const _LiveClassRosterPage({required this.classId});

  final String classId;

  @override
  LiveRosterController onConfigScope(LevitScope scope) {
    return scope.put(
      () => LiveRosterController(
        classGroupId: classId,
        academicYear: scope.find<AcademicYearController>(),
        teacherContext: scope.find<TeacherContextController>(),
        schoolClient: scope.find<SchoolClientFactory>(),
      ),
    );
  }

  @override
  Widget buildView(BuildContext context, LiveRosterController controller) {
    return LWatch(() {
      controller.students.value;
      controller.errorMessage.value;
      final selectedStudentId = GoRouterState.of(
        context,
      ).pathParameters['studentId'];
      final students = controller.students.value;
      return PrototypeDetailScaffold(
        title: controller.classLabel,
        fallbackRoute: '/classes',
        body: students.isEmpty
            ? EmptyState(
                title: 'Aucun élève',
                message: controller.errorMessage.value,
              )
            : ListView.separated(
                padding: const EdgeInsets.all(PrototypeSpacing.md),
                itemCount: students.length,
                separatorBuilder: (_, _) =>
                    const SizedBox(height: PrototypeSpacing.xs),
                itemBuilder: (context, i) {
                  final s = students[i];
                  return ListRow(
                    title: s.fullName,
                    selected: selectedStudentId == s.id,
                    leading: PersonAvatar(
                      initials: s.initials,
                      photoUrl: s.photoUrl,
                      radius: 18,
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () =>
                        context.go('/classes/$classId/student/${s.id}'),
                  );
                },
              ),
      );
    });
  }
}

class _LiveStudentProfilePage extends LScopedView<LiveRosterController> {
  const _LiveStudentProfilePage({
    required this.classId,
    required this.studentId,
  });

  final String classId;
  final String studentId;

  @override
  LiveRosterController onConfigScope(LevitScope scope) {
    return scope.put(
      () => LiveRosterController(
        classGroupId: classId,
        studentId: studentId,
        academicYear: scope.find<AcademicYearController>(),
        teacherContext: scope.find<TeacherContextController>(),
        schoolClient: scope.find<SchoolClientFactory>(),
      ),
    );
  }

  @override
  Widget buildView(BuildContext context, LiveRosterController controller) {
    return LWatch(() {
      controller.students.value;
      final student = controller.selectedStudent;
      if (student == null) {
        return const PrototypeDetailScaffold(
          title: 'Élève',
          body: EmptyState(title: 'Élève introuvable'),
        );
      }
      return PrototypeDetailScaffold(
        title: student.fullName,
        fallbackRoute: '/classes/$classId',
        body: ListView(
          padding: const EdgeInsets.all(PrototypeSpacing.md),
          children: [
            SurfaceCard(
              child: Row(
                children: [
                  PersonAvatar(
                    initials: student.initials,
                    photoUrl: student.photoUrl,
                    radius: 28,
                  ),
                  const SizedBox(width: PrototypeSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          student.fullName,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        Text(controller.classLabel),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    });
  }
}
