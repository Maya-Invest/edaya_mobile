import 'package:edaya_shared/edaya_shared.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:levit_flutter/levit_flutter.dart';
import 'package:intl/intl.dart';
import '../../app/guardian_words.dart';
import '../../app/workspace_shell.dart';
import '../../design/components/surface_card.dart';
import '../../live/runtime.dart';
import '../context/student_context_controller.dart';
import '../context/academic_year_controller.dart';
import 'dashboard_controller.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});
  @override
  Widget build(BuildContext context) => LWatch(() {
    if (!prototypeIsLive(context)) return const _Dashboard();
    final student = context.levit.find<StudentContextController>();
    final year = context.levit.find<AcademicYearController>();
    final id = student.activeStudentId;
    final yearId = year.selectedYearId.value;
    if (id == null || yearId == null) {
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const ChildContextCard(),
          const SizedBox(height: 24),
          Text(
            year.errorMessage.value.isNotEmpty
                ? year.errorMessage.value
                : words(
                    context,
                    'Sélectionnez un enfant pour continuer.',
                    'Select a child to continue.',
                  ),
          ),
        ],
      );
    }
    return _LiveDashboard(
      key: ValueKey((id, yearId, student.activeStudent.value?.schoolId)),
      id: id,
      year: yearId,
      school: student.activeStudent.value!.schoolId,
    );
  });
}

class _LiveDashboard extends LScopedView<DashboardController> {
  const _LiveDashboard({
    super.key,
    required this.id,
    required this.year,
    required this.school,
  });
  final String id, year, school;
  @override
  DashboardController onConfigScope(LevitScope scope) => scope.put(
    () => DashboardController(
      client: scope.find<SchoolClientFactory>()(),
      studentId: id,
      yearId: year,
      schoolId: school,
      guardianSubjectId: scope.find<AppSessionController>().user.value?.id,
      classGroupId: scope.find<StudentContextController>().classGroupId.value,
    ),
  );
  @override
  Widget buildView(BuildContext context, DashboardController controller) =>
      _Dashboard(controller: controller);
}

class _Dashboard extends StatefulWidget {
  const _Dashboard({this.controller});
  final DashboardController? controller;
  @override
  State<_Dashboard> createState() => _DashboardState();
}

class _DashboardState extends State<_Dashboard> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _visibility();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _visibility();
  }

  void _visibility() {
    widget.controller?.setVisible(
      ModalRoute.isCurrentOf(context) != false &&
          (WidgetsBinding.instance.lifecycleState == null ||
              WidgetsBinding.instance.lifecycleState ==
                  AppLifecycleState.resumed),
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) => _visibility();
  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.controller?.setVisible(false);
    super.dispose();
  }

  String highlight(String path) {
    final c = widget.controller;
    final data = c?.highlights.value ?? {};
    final errors = c?.errors.value ?? {};
    final key = switch (path) {
      '/fees' => 'fees',
      '/scolarite/notes' => 'results',
      '/attendance' => 'attendance',
      '/inbox/avis' => 'surveys',
      '/calendar' => 'sessions',
      '/scolarite/progress' => 'progress',
      '/inbox' => 'inbox',
      '/child' => 'child',
      _ => '',
    };
    if (errors.contains(key)) {
      return words(context, 'Indisponible', 'Unavailable');
    }
    return switch (path) {
      '/calendar' =>
        (c?.sessions.value?.isNotEmpty == true)
            ? words(
                context,
                '${c!.sessions.value!.length} séances aujourd’hui',
                '${c.sessions.value!.length} sessions today',
              )
            : words(context, 'Voir l’emploi du temps', 'View the timetable'),
      '/scolarite/progress' =>
        data['progress'] != null
            ? words(
                context,
                '${data['progress']} % du programme',
                '${data['progress']}% of curriculum',
              )
            : words(
                context,
                'Programme et cahier de texte',
                'Curriculum and logbook',
              ),
      '/scolarite/notes' =>
        (data['reports'] as int? ?? 0) > 0
            ? words(context, 'Bulletin disponible', 'Report card available')
            : (data['marks'] as int? ?? 0) > 0
            ? words(
                context,
                '${data['marks']} notes disponibles',
                '${data['marks']} available marks',
              )
            : words(
                context,
                'Notes et moyennes par période',
                'Marks and period results',
              ),
      '/attendance' =>
        data['absent'] == null
            ? words(
                context,
                'Absences et retards',
                'Absences and late arrivals',
              )
            : words(
                context,
                "${data['absent']} absence(s) · ${data['late']} retard(s)",
                "${data['absent']} absence(s) · ${data['late']} late",
              ),
      '/fees' =>
        (data['overdue'] as int? ?? 0) > 0
            ? words(
                context,
                "${data['overdue']} échéance(s) en retard",
                "${data['overdue']} overdue charge(s)",
              )
            : data['dueDate'] is DateTime
            ? words(
                context,
                'Prochaine échéance : ${DateFormat.MMMd(Localizations.localeOf(context).languageCode).format(data['dueDate'] as DateTime)}',
                'Next due: ${DateFormat.MMMd(Localizations.localeOf(context).languageCode).format(data['dueDate'] as DateTime)}',
              )
            : data['balance'] == 0
            ? words(context, 'À jour', 'Up to date')
            : words(
                context,
                'Solde, échéances et reçus',
                'Balance, due dates and receipts',
              ),
      '/inbox' =>
        data['unread'] != null
            ? words(
                context,
                '${data['unread']} message(s) non lu(s)',
                '${data['unread']} unread message(s)',
              )
            : words(
                context,
                'Échanges avec l’école',
                'Conversations with school',
              ),
      '/inbox/avis' =>
        data['surveys'] == null
            ? words(context, 'Votre avis compte', 'Your feedback matters')
            : words(
                context,
                "${data['surveys']} questionnaire(s)",
                "${data['surveys']} survey(s)",
              ),
      _ =>
        data['photo'] == 'rejected'
            ? words(context, 'Photo à mettre à jour', 'Photo needs updating')
            : data['photo'] == 'pending'
            ? words(
                context,
                'Photo en cours de validation',
                'Photo under review',
              )
            : (data['documents'] as int? ?? 0) > 0
            ? words(
                context,
                '${data['documents']} document(s) disponible(s)',
                '${data['documents']} available document(s)',
              )
            : words(context, 'Photo et documents', 'Photo and documents'),
    };
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) => LWatch(() {
      final c = widget.controller;
      // The menu's nested LayoutBuilder runs outside this watch callback.
      // Subscribe here so completed reads refresh its contextual summaries.
      c?.highlights.value;
      c?.errors.value;
      final sessions = c?.preview ?? [];
      final large = MediaQuery.textScalerOf(context).scale(14) > 21;
      Widget heading(String fr, String en) => Semantics(
        header: true,
        child: Text(
          words(context, fr, en),
          style: Theme.of(context).textTheme.titleLarge,
        ),
      );
      final day = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          heading('Séances du jour', 'Today’s sessions'),
          const SizedBox(height: 12),
          if (c != null &&
              c.sessions.value == null &&
              !c.errors.value.contains('sessions'))
            const LinearProgressIndicator(),
          if (c?.errors.value.isNotEmpty == true)
            TextButton.icon(
              onPressed: c!.refresh,
              icon: const Icon(Icons.refresh),
              label: Text(
                words(
                  context,
                  'Actualiser les informations',
                  'Refresh information',
                ),
              ),
            ),
          if ((c == null || c.sessions.value != null) && sessions.isEmpty)
            Text(
              words(
                context,
                'Aucune séance à venir aujourd’hui.',
                'No more sessions today.',
              ),
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          for (final s in sessions)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: SurfaceCard(
                onTap: () =>
                    context.push('/session/${Uri.encodeComponent(s.id)}'),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            s.subjectLabel ?? s.title,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ),
                        const Icon(Icons.chevron_right),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${!s.startsAt.isAfter(c!.now.value) ? words(context, 'En cours', 'In progress') : words(context, 'À venir', 'Up next')} · ${DateFormat.Hm().format(s.startsAt)}–${DateFormat.Hm().format(s.endsAt)}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    if (!s.startsAt.isAfter(c.now.value)) ...[
                      const SizedBox(height: 10),
                      _AttendanceStatus(
                        status: c.attendance.value[s.id],
                        failed: c.errors.value.contains('attendance'),
                      ),
                    ],
                  ],
                ),
              ),
            ),
        ],
      );
      Widget group(bool academic) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          heading(
            academic ? 'Scolarité' : 'Vie scolaire',
            academic ? 'Learning' : 'School life',
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, grid) {
              final columns = large
                  ? 1
                  : grid.maxWidth >= 650
                  ? 3
                  : 2;
              final width = (grid.maxWidth - 12 * (columns - 1)) / columns;
              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  for (final d in destinations.where(
                    (d) => d.academic == academic,
                  ))
                    SizedBox(
                      width: width,
                      child: SurfaceCard(
                        onTap: () => context.push(d.path),
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            minHeight: large ? 130 : 134,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.primaryContainer,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(
                                  d.icon,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                words(context, d.fr, d.en),
                                style: Theme.of(context).textTheme.titleSmall,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                highlight(d.path),
                                maxLines: large ? null : 2,
                                overflow: large ? null : TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onSurfaceVariant,
                                    ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      );
      final menu = Column(
        children: [group(true), const SizedBox(height: 24), group(false)],
      );
      final wide = box.maxWidth >= 1000 && !large;
      return RefreshIndicator(
        onRefresh: () => c?.refresh() ?? Future.value(),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            const ChildContextCard(),
            const SizedBox(height: 24),
            if (wide)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: day),
                  const SizedBox(width: 24),
                  Expanded(flex: 2, child: menu),
                ],
              )
            else ...[
              day,
              const SizedBox(height: 24),
              menu,
            ],
          ],
        ),
      );
    }),
  );
}

class _AttendanceStatus extends StatelessWidget {
  const _AttendanceStatus({this.status, required this.failed});
  final String? status;
  final bool failed;
  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme;
    final label = failed
        ? words(context, 'Présence indisponible', 'Attendance unavailable')
        : switch (status) {
            'present' => words(context, 'Présent', 'Present'),
            'absent' => words(context, 'Absent', 'Absent'),
            'late' => words(context, 'Retard', 'Late'),
            _ => words(context, 'Non renseignée', 'Not recorded'),
          };
    return Row(
      children: [
        Icon(
          status == 'present'
              ? Icons.check_circle_outline
              : status == 'absent'
              ? Icons.cancel_outlined
              : Icons.schedule,
          size: 18,
          color: status == 'absent' ? color.error : color.primary,
        ),
        const SizedBox(width: 6),
        Flexible(
          child: Text(label, style: Theme.of(context).textTheme.labelLarge),
        ),
      ],
    );
  }
}
