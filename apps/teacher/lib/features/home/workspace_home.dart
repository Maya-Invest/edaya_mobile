import '../../design/workspace_layout.dart';
import '../../design/components/surface_card.dart';
import '../../design/spacing.dart';
import 'dart:async';
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:levit_flutter/levit_flutter.dart';
import 'package:edaya_shared/edaya_shared.dart';
import '../../app/workspace_navigation.dart';
import '../../di/prototype_module.dart';
import 'home_lesson_list.dart';
import '../../live/runtime.dart';
import '../context/teacher_context_controller.dart';
import '../context/academic_year_controller.dart';

class WorkspaceHome extends StatefulWidget {
  const WorkspaceHome({super.key});
  @override
  State<WorkspaceHome> createState() => _WorkspaceHomeState();
}

class _WorkspaceHomeState extends State<WorkspaceHome>
    with WidgetsBindingObserver {
  final _lessonList = GlobalKey();
  Timer? timer;
  DateTime? wake;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed &&
        mounted &&
        prototypeIsLive(context)) {
      registerKey = '';
      setState(() {});
    }
  }

  void atBoundary(DateTime now, DateTime at) {
    if (at.isAtSameMomentAs(wake ?? now)) return;
    wake = at;
    timer?.cancel();
    timer = Timer(at.difference(now) + const Duration(milliseconds: 50), () {
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    timer?.cancel();
    super.dispose();
  }

  String registerKey = '';
  Future<List<({String id, String label, bool done})>>? registers;
  Future<List<({String id, String label, bool done})>> loadRegisters(
    SchoolClientFactory factory,
    List<AssignedClass> classes,
    DateTime day,
  ) async {
    final api = factory();
    final result = <({String id, String label, bool done})>[];
    for (final c in classes) {
      final call = await api.runQuery('get-teacher-attendance-call', {
        'anchor': {
          'kind': 'daily',
          'classGroupId': c.id,
          'date': DateTime.utc(day.year, day.month, day.day).toIso8601String(),
        },
      });
      result.add((id: c.id, label: c.label, done: call['submitted'] == true));
    }
    return result;
  }

  Widget day(BuildContext context) {
    if (!prototypeIsLive(context)) return const SizedBox.shrink();
    final teacher = context.levit.find<TeacherContextController>();
    final now = teacher.schoolTime(SchoolClock.now());
    final assignment = teacher.activeAssignment;
    final workspace = teacher.selection;
    final teacherId = teacher.teacherId.value;
    final currentClass = assignment?.classGroupId;
    atBoundary(
      now,
      tz.TZDateTime(now.location, now.year, now.month, now.day + 1),
    );
    final homerooms = teacher.assignedClasses.value
        .where(
          (c) =>
              c.dailyAttendance &&
              c.id == currentClass &&
              teacher.assignments.value.any(
                (a) => a.classGroupId == c.id && a.isHomeroom,
              ),
        )
        .toList();
    final key =
        '${workspace?.schoolId}/${teacher.teacherId.value}/${workspace?.academicYearId}/${now.year}-${now.month}-${now.day}/${homerooms.map((c) => c.id).join(",")}';
    if (key != registerKey) {
      registerKey = key;
      registers = loadRegisters(
        context.levit.find<SchoolClientFactory>(),
        homerooms,
        now,
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          header: true,
          child: Text(
            context.tr.teacherTodaySessions,
            style: Theme.of(context).textTheme.titleLarge,
          ),
        ),
        const SizedBox(height: PrototypeSpacing.md),
        FutureBuilder(
          key: ValueKey(registerKey),
          future: registers,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return TextButton(
                onPressed: () => setState(() => registerKey = ''),
                child: const Text('Réessayer le chargement de l’appel'),
              );
            }
            final entries = snapshot.data;
            if (entries == null || entries.isEmpty) {
              return const SizedBox.shrink();
            }
            return Padding(
              padding: const EdgeInsets.only(bottom: PrototypeSpacing.md),
              child: SurfaceCard(
                padding: EdgeInsets.zero,
                child: ListTile(
                  contentPadding: const EdgeInsets.all(PrototypeSpacing.sm),
                  leading: const Icon(Icons.fact_check_outlined),
                  title: Text(
                    entries.length > 1
                        ? 'Appels du jour'
                        : entries.first.done
                        ? 'Consulter l’appel du jour'
                        : 'Faire l’appel du jour',
                  ),
                  onTap: () async {
                    var id = entries.first.id;
                    if (entries.length > 1) {
                      final selected = await showModalBottomSheet<String>(
                        context: context,
                        builder: (sheet) => WorkspaceSheet(
                          title: 'Appels du jour',
                          child: ListView(
                            children: [
                              for (final e in entries)
                                ListTile(
                                  title: Text(e.label),
                                  onTap: () => Navigator.pop(sheet, e.id),
                                ),
                            ],
                          ),
                        ),
                      );
                      if (selected == null || !context.mounted) return;
                      id = selected;
                    }
                    await context.push('/classes/$id/attendance');
                    if (mounted) setState(() => registerKey = '');
                  },
                  trailing: const Icon(Icons.chevron_right),
                ),
              ),
            );
          },
        ),
        if (workspace != null && assignment != null && teacherId != null)
          KeyedSubtree(
            key: _lessonList,
            child: HomeLessonList(
              key: ValueKey((
                workspace.schoolId,
                workspace.academicYearId,
                teacherId,
                assignment.id,
                now.location.name,
              )),
              classId: workspace.classGroupId,
              subjectId: workspace.classSubjectId,
              teacherId: teacherId,
              classLabel: assignment.classLabel,
              location: now.location,
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) => LWatch(() {
      final live = prototypeIsLive(context);
      final tc = live ? context.levit.find<TeacherContextController>() : null;
      final active = tc?.activeAssignment;
      final year = live
          ? context.levit.find<AcademicYearController>().selectedYearLabel
          : null;
      final roles = active == null
          ? ''
          : [
              if (active.classSubjectId != null) active.subjectLabel,
              if (active.isHomeroom) 'Titulaire',
            ].join(' · ');
      bool available(WorkspaceDestination w) {
        if (!live) return true;
        if (active == null) return false;
        if (w.path == '/report-cards') return active.isHomeroom;
        if ([
          '/progress',
          '/evaluations',
          '/evaluations/avis',
        ].contains(w.path)) {
          return active.classSubjectId != null;
        }
        return true;
      }

      Widget tiles(
        List<({String label, String path, IconData icon})> entries,
      ) => GridView.count(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisCount: box.maxWidth >= 700
            ? 3
            : box.maxWidth < 400 &&
                  MediaQuery.textScalerOf(context).scale(14) >= 24
            ? 1
            : 2,
        mainAxisSpacing: PrototypeSpacing.sm,
        crossAxisSpacing: PrototypeSpacing.sm,
        mainAxisExtent: MediaQuery.textScalerOf(
          context,
        ).scale(128).clamp(128, 280).toDouble(),
        children: [
          for (final w in entries)
            SurfaceCard(
              onTap: () => context.push(w.path),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(PrototypeSpacing.xs),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(PrototypeRadii.sm),
                    ),
                    child: Icon(
                      w.icon,
                      size: 24,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: PrototypeSpacing.xs),
                  Text(w.label, style: Theme.of(context).textTheme.titleSmall),
                ],
              ),
            ),
        ],
      );
      final teaching = teachingWorkspaces.where(available).toList();
      final classLife = classLifeWorkspaces.where(available).toList();
      final grid = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (teaching.isNotEmpty) ...[
            Semantics(
              header: true,
              child: Text(
                context.tr.navTeaching,
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            const SizedBox(height: PrototypeSpacing.sm),
            tiles(teaching),
          ],
          if (teaching.isNotEmpty && classLife.isNotEmpty)
            const SizedBox(height: PrototypeSpacing.xl),
          if (classLife.isNotEmpty) ...[
            Semantics(
              header: true,
              child: Text(
                context.tr.teacherClassLife,
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            const SizedBox(height: PrototypeSpacing.sm),
            tiles(classLife),
          ],
        ],
      );
      final landscape = box.maxWidth >= 900 && box.maxWidth > box.maxHeight;
      return ListView(
        padding: EdgeInsets.symmetric(
          horizontal: workspaceGutter(box.maxWidth),
          vertical: PrototypeSpacing.xl,
        ),
        children: [
          SurfaceCard(
            padding: EdgeInsets.zero,
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: PrototypeSpacing.md,
                vertical: PrototypeSpacing.xs,
              ),
              title: Text(
                [
                  active?.classLabel ??
                      (tc?.isLoading.value == true
                          ? context.tr.loading
                          : tc?.loadFailed.value == true
                          ? context.tr.classLabel
                          : 'Aucune affectation'),
                  tc?.schoolName.value,
                  year,
                ].whereType<String>().join(' · '),
              ),
              subtitle: Text(
                roles.isEmpty ? 'Mes classes et mes missions' : roles,
              ),
              trailing: const Icon(Icons.expand_more),
              onTap: live ? () => chooseContext(context) : null,
            ),
          ),
          if (live &&
              context.levit
                  .find<AcademicYearController>()
                  .errorMessage
                  .value
                  .isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: PrototypeSpacing.sm),
              child: Text(
                context.levit.find<AcademicYearController>().errorMessage.value,
              ),
            ),
          if (tc != null && tc.errorMessage.value.isNotEmpty)
            Text(tc.errorMessage.value),
          if (live &&
              (tc!.loadFailed.value ||
                  context.levit
                      .find<AcademicYearController>()
                      .errorMessage
                      .value
                      .isNotEmpty))
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: tc.isLoading.value
                    ? null
                    : () => initializeTeacherAuthenticatedContext(
                        LScope.of(context)!,
                        findEligibleSchool: false,
                      ),
                child: Text(context.tr.retry),
              ),
            ),
          const SizedBox(height: PrototypeSpacing.xl),
          if (teaching.isNotEmpty || classLife.isNotEmpty)
            if (landscape)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: day(context)),
                  const SizedBox(width: PrototypeSpacing.xl),
                  Expanded(flex: 2, child: grid),
                ],
              )
            else ...[
              day(context),
              const SizedBox(height: PrototypeSpacing.xl),
              grid,
            ],
        ],
      );
    }),
  );
}
