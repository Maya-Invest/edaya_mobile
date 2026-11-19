import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:levit_flutter/levit_flutter.dart';
import 'package:edaya_shared/edaya_shared.dart';
import '../features/context/student_context_controller.dart';
import '../features/context/academic_year_controller.dart';
import '../live/runtime.dart';
import '../mock/mock_store.dart';
import '../design/components/surface_card.dart';
import 'guardian_words.dart';

class WorkspaceHost extends InheritedWidget {
  const WorkspaceHost({super.key, required super.child});
  static bool present(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<WorkspaceHost>() != null;
  @override
  bool updateShouldNotify(WorkspaceHost oldWidget) => false;
}

const destinations =
    <({String path, String fr, String en, IconData icon, bool academic})>[
      (
        path: '/calendar',
        fr: 'Agenda',
        en: 'Calendar',
        icon: Icons.calendar_today_outlined,
        academic: true,
      ),
      (
        path: '/scolarite/progress',
        fr: 'Progression',
        en: 'Progress',
        icon: Icons.menu_book_outlined,
        academic: true,
      ),
      (
        path: '/scolarite/notes',
        fr: 'Résultats',
        en: 'Results',
        icon: Icons.assessment_outlined,
        academic: true,
      ),
      (
        path: '/fees',
        fr: 'Frais',
        en: 'Fees',
        icon: Icons.payments_outlined,
        academic: false,
      ),
      (
        path: '/inbox',
        fr: 'Messages',
        en: 'Messages',
        icon: Icons.forum_outlined,
        academic: false,
      ),
      (
        path: '/inbox/avis',
        fr: 'Avis',
        en: 'Feedback',
        icon: Icons.poll_outlined,
        academic: false,
      ),
      (
        path: '/child',
        fr: 'Dossier de l’enfant',
        en: 'Child record',
        icon: Icons.badge_outlined,
        academic: false,
      ),
    ];

class ChildContextCard extends StatelessWidget {
  const ChildContextCard({super.key, this.compact = false});
  final bool compact;
  @override
  Widget build(BuildContext context) => LWatch(() {
    final live = prototypeIsLive(context);
    final student = live
        ? context.levit.find<StudentContextController>()
        : null;
    final mock = live ? null : context.levit.find<MockStore>();
    final active = student?.activeStudent.value;
    final name =
        active?.fullName ??
        mock?.activeStudent.fullName ??
        words(context, 'Choisir un enfant', 'Choose a child');
    final school = student?.schoolName.value ?? mock?.activeSchool.name;
    final year = live
        ? context.levit.find<AcademicYearController>().selectedYearLabel
        : mock?.selectedYear;
    void chooseChild() {
      final path = GoRouterState.of(context).uri.path;
      final root = path.startsWith('/session')
          ? '/calendar'
          : path.startsWith('/scolarite/progress') || path.endsWith('/cahier')
          ? '/scolarite/progress'
          : path.startsWith('/scolarite')
          ? '/scolarite/notes'
          : path.startsWith('/fees')
          ? '/fees'
          : path.startsWith('/inbox/avis')
          ? '/inbox/avis'
          : path.startsWith('/inbox')
          ? '/inbox'
          : path;
      context.push(
        Uri(path: '/children', queryParameters: {'return': root}).toString(),
      );
    }

    if (compact)
      return WorkspacePickerButton(
        name: name,
        icon: Icons.person_outline,
        onPressed: chooseChild,
      );
    return SurfaceCard(
      padding: EdgeInsets.zero,
      onTap: chooseChild,
      child: Padding(
        padding: EdgeInsets.all(compact ? 12 : 16),
        child: Row(
          children: [
            if (!compact)
              PersonAvatar(
                name: name,
                initials: active?.initials ?? 'E',
                photoUrl: active?.photoUrl,
                radius: compact ? 20 : 26,
              ),
            if (!compact) const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    maxLines: compact ? 1 : null,
                    overflow: compact ? TextOverflow.ellipsis : null,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  ...[
                    const SizedBox(height: 4),
                    Text(
                      (compact
                              ? [year, school, student?.classLabel.value]
                              : [school, student?.classLabel.value, year])
                          .whereType<String>()
                          .where((s) => s.isNotEmpty)
                          .join(' · '),
                      maxLines: compact ? 1 : null,
                      overflow: compact ? TextOverflow.ellipsis : null,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.expand_more),
          ],
        ),
      ),
    );
  });
}

class WorkspaceShell extends StatefulWidget {
  const WorkspaceShell({super.key, required this.child, required this.uri});
  final Widget child;
  final Uri uri;
  @override
  State<WorkspaceShell> createState() => _WorkspaceShellState();
}

class _WorkspaceShellState extends State<WorkspaceShell> {
  String? _basePath;
  @override
  Widget build(BuildContext context) {
    final raw = widget.uri.path;
    final overlay =
        raw == '/children' ||
        raw == '/settings' ||
        raw == '/account/profile' ||
        raw.startsWith('/fees/fee/') ||
        raw.startsWith('/fees/payment/') ||
        raw.startsWith('/inbox/message/') ||
        raw.startsWith('/inbox/avis/');
    if (!overlay) _basePath = raw;
    final path = overlay ? _basePath ?? '/home' : raw;
    final home = path == '/home';
    final account = path.startsWith('/account') || path == '/settings';
    final destination = destinations.where((d) => d.path == path).firstOrNull;
    final title = home
        ? words(context, 'Accueil', 'Home')
        : destination != null
        ? words(context, destination.fr, destination.en)
        : path.endsWith('/cahier')
        ? words(context, 'Cahier de texte', 'Logbook')
        : path.startsWith('/scolarite/progress')
        ? words(context, 'Progression', 'Progress')
        : path.startsWith('/scolarite/period')
        ? words(context, 'Résultats de la matière', 'Subject results')
        : path.startsWith('/session')
        ? words(context, 'Séance', 'Session')
        : account
        ? words(context, 'Mon profil', 'My profile')
        : words(context, 'Détails', 'Details');
    return WorkspaceHost(
      child: Scaffold(
        appBar: AppBar(
          centerTitle: false,
          toolbarHeight: home
              ? null
              : WorkspacePageHeading.toolbarHeight(
                  context,
                  hasPicker: !account,
                ),
          title: home
              ? Text(title)
              : WorkspacePageHeading.forAppBar(
                  context,
                  title: title,
                  picker: !account && path != '/children'
                      ? const ChildContextCard(compact: true)
                      : null,
                ),
          automaticallyImplyLeading: false,
          leading: home
              ? null
              : BackButton(
                  onPressed: () {
                    if (context.canPop()) {
                      context.pop();
                    } else {
                      context.go('/home');
                    }
                  },
                ),
          actions: [
            if (home)
              Padding(
                padding: const EdgeInsets.only(right: 16),
                child: TextButton.icon(
                  onPressed: () => context.push('/account'),
                  icon: const Icon(Icons.account_circle_outlined, size: 30),
                  label: Text(words(context, 'Mon profil', 'My profile')),
                  style: TextButton.styleFrom(minimumSize: const Size(68, 68)),
                ),
              ),
          ],
        ),
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1168),
              child: Column(children: [Expanded(child: widget.child)]),
            ),
          ),
        ),
      ),
    );
  }
}

class GuardianSheetPage extends Page<Object?> {
  const GuardianSheetPage({
    super.key,
    required this.child,
    required this.title,
  });
  final Widget child;
  final String title;
  @override
  Route<Object?> createRoute(BuildContext context) =>
      ModalBottomSheetRoute<Object?>(
        settings: this,
        isScrollControlled: true,
        useSafeArea: true,
        showDragHandle: true,
        constraints: const BoxConstraints(maxWidth: 640),
        builder: (context) {
          final page = ModalRoute.of(context)!.settings as GuardianSheetPage;
          return WorkspaceHost(
            child: SizedBox(
              height: MediaQuery.sizeOf(context).height * .88,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 12, 12),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            page.title,
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                        ),
                        IconButton(
                          tooltip: words(context, 'Fermer', 'Close'),
                          onPressed: () => Navigator.of(context).maybePop(),
                          icon: const Icon(Icons.close),
                        ),
                      ],
                    ),
                  ),
                  Expanded(child: page.child),
                ],
              ),
            ),
          );
        },
      );
}
