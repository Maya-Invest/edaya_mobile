import '../teaching/teaching_models.dart';
import 'package:edaya_shared/edaya_shared.dart' hide PersonAvatar;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:levit_flutter/levit_flutter.dart';

import '../../design/components/components.dart';
import '../../design/spacing.dart';
import '../../live/runtime.dart';
import '../../mock/mock_store.dart';
import '../context/academic_year_controller.dart';
import '../context/store_bound_controller.dart';
import '../context/teacher_context_controller.dart';
import '../teaching/live_class_workspace_controller.dart';
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
            subtitle: context.tr.subjectPupilCount(
              a.subjectLabel,
              a.studentCount,
            ),
            selected: selected,
            leading: Icon(
              a.isHomeroom ? Icons.star_outline : Icons.groups_outlined,
              color: Theme.of(context).colorScheme.primary,
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
      title: assignment?.classLabel ?? context.tr.teachingSelectClass,
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
      return PrototypeDetailScaffold(
        title: context.tr.student,
        body: EmptyState(title: context.tr.studentNotFound),
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
          SectionHeader(title: context.tr.quickOverview),
          const SizedBox(height: PrototypeSpacing.sm),
          ListRow(
            title: context.tr.attendance,
            subtitle: 'Présent · 94 % ce mois',
            badge: 'OK',
          ),
          const SizedBox(height: PrototypeSpacing.xs),
          ListRow(
            title: context.tr.latestMark,
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
            ? EmptyState(title: context.tr.noAssignedClasses)
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
                        ? context.tr.homeroomTeacherLabel(a.subjectLabel)
                        : a.subjectLabel,
                    selected: selected,
                    leading: Icon(
                      a.isHomeroom ? Icons.star_outline : Icons.groups_outlined,
                      color: Theme.of(context).colorScheme.primary,
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
    scope.put(
      () => LiveClassWorkspaceController(
        classGroupId: classId,
        teacherContext: scope.find<TeacherContextController>(),
        schoolClient: scope.find<SchoolClientFactory>(),
      ),
    );
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
    return DefaultTabController(
      length: 3,
      child: PrototypeDetailScaffold(
        title: controller.classLabel,
        fallbackRoute: '/classes',
        body: Column(
          children: [
            TextButton(
              onPressed: () => context.go('/classes/$classId/discipline'),
              child: Text(context.tr.workflowDiscipline),
            ),
            if (controller.canRecordDaily.value)
              Padding(
                padding: const EdgeInsets.all(PrototypeSpacing.sm),
                child: OutlinedButton(
                  onPressed: () => context.go('/classes/$classId/attendance'),
                  child: Text(context.tr.dailyAttendance),
                ),
              ),
            TabBar(
              tabs: [
                Tab(text: context.tr.students),
                Tab(text: context.tr.teachingProgressTab),
                Tab(text: context.tr.logbook),
              ],
            ),
            Expanded(
              child: TabBarView(
                children: [
                  _LiveRosterList(classId: classId, controller: controller),
                  const _LiveProgressTab(),
                  const _LiveClassLogbookTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LiveRosterList extends StatelessWidget {
  const _LiveRosterList({required this.classId, required this.controller});

  final String classId;
  final LiveRosterController controller;

  @override
  Widget build(BuildContext context) {
    return LWatch(() {
      controller.students.value;
      controller.errorMessage.value;
      final selectedStudentId = GoRouterState.of(
        context,
      ).pathParameters['studentId'];
      final students = controller.students.value;
      if (students.isEmpty) {
        return EmptyState(
          title: context.tr.noStudents,
          message: controller.errorMessage.value,
        );
      }
      return ListView.separated(
        padding: const EdgeInsets.all(PrototypeSpacing.md),
        itemCount: students.length,
        separatorBuilder: (_, _) => const SizedBox(height: PrototypeSpacing.xs),
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
            onTap: () => context.go('/classes/$classId/student/${s.id}'),
          );
        },
      );
    });
  }
}

class _LiveProgressTab extends LView<LiveClassWorkspaceController> {
  const _LiveProgressTab();

  @override
  Widget buildView(
    BuildContext context,
    LiveClassWorkspaceController controller,
  ) {
    return LWatch(() {
      controller.classSubjectOptions.value;
      controller.selectedClassSubjectId.value;
      controller.progressOverview.value;
      controller.errorMessage.value;
      final overview = controller.progressOverview.value;
      return ListView(
        padding: const EdgeInsets.all(PrototypeSpacing.md),
        children: [
          if (controller.classSubjectOptions.value.isNotEmpty)
            DropdownButtonFormField<String>(
              initialValue: controller.selectedClassSubjectId.value,
              decoration: InputDecoration(
                labelText: context.tr.teachingSelectSubject,
                border: OutlineInputBorder(),
              ),
              items: [
                for (final option in controller.classSubjectOptions.value)
                  DropdownMenuItem(
                    value: option.id,
                    child: Text(option.subjectName),
                  ),
              ],
              onChanged: controller.selectSubject,
            ),
          const SizedBox(height: PrototypeSpacing.md),
          if (overview == null)
            EmptyState(
              title: context.tr.teachingProgressTab,
              message: controller.errorMessage.value,
            )
          else ...[
            Text(
              context.tr.curriculum(overview.classSubjectCompletedPercentage),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            Text(
              overview.chapterCount == 0
                  ? context.tr.logbookEmptyCurriculum
                  : context.tr.logbookChapterCounts(
                      overview.completedChapterCount,
                      overview.chapterCount,
                      overview.ongoingChapterCount,
                    ),
            ),
            const SizedBox(height: PrototypeSpacing.md),
            for (final matter in overview.matters) ...[
              ListRow(
                title: matter.name,
                subtitle: switch (matter.status) {
                  TeachingMatterStatus.completed =>
                    context.tr.matterStatusCompleted,
                  TeachingMatterStatus.inProgress =>
                    context.tr.matterStatusInProgress,
                  TeachingMatterStatus.notStarted =>
                    context.tr.matterStatusNotStarted,
                },
              ),
              const SizedBox(height: PrototypeSpacing.xs),
            ],
          ],
        ],
      );
    });
  }
}

class _LiveClassLogbookTab extends LView<LiveClassWorkspaceController> {
  const _LiveClassLogbookTab();

  @override
  Widget buildView(
    BuildContext context,
    LiveClassWorkspaceController controller,
  ) {
    return LWatch(() {
      controller.logbookEntries.value;
      controller.errorMessage.value;
      final entries = controller.logbookEntries.value;
      if (entries.isEmpty) {
        return EmptyState(
          title: context.tr.logbook,
          message: controller.errorMessage.value,
        );
      }
      return ListView.separated(
        padding: const EdgeInsets.all(PrototypeSpacing.md),
        itemCount: entries.length,
        separatorBuilder: (_, _) => const SizedBox(height: PrototypeSpacing.xs),
        itemBuilder: (context, i) {
          final entry = entries[i];
          return ListRow(
            title: entry.displayLabel,
            subtitle: entry.hasContent
                ? context.tr.matterStatusCompleted
                : context.tr.notRecorded,
            onTap: () =>
                context.go('/session/${entry.lessonSessionId}/logbook'),
          );
        },
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
        return PrototypeDetailScaffold(
          title: context.tr.student,
          body: EmptyState(title: context.tr.studentNotFound),
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
