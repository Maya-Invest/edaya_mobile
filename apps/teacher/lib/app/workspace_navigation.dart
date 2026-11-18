import '../design/workspace_layout.dart';
import 'package:edaya_shared/edaya_shared.dart';
import 'package:edaya_auth/edaya_auth.dart';
import '../features/context/teacher_workspace_catalog.dart';
import '../design/components/surface_card.dart';
import '../design/spacing.dart';
import '../di/prototype_module.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:levit_flutter/levit_flutter.dart';
import 'workspace_browser_history_stub.dart'
    if (dart.library.js_interop) 'workspace_browser_history_web.dart'
    as browser_history;

import '../features/context/academic_year_controller.dart';
import '../features/context/teacher_context_controller.dart';
import '../live/runtime.dart';
import '../features/account/teacher_portrait.dart';

final _routeExitGuards = Expando<Map<LocalKey, bool Function()>>();

final workspaceChangeGuards = Expando<Future<bool> Function()>();
Future<bool> prepareWorkspaceChange(BuildContext context) async =>
    await workspaceChangeGuards[GoRouter.of(context)]?.call() ?? true;

/// Query-only browser history changes keep the same route, so onExit does not run.
Future<OnEnterResult> workspaceCanEnter(
  BuildContext context,
  GoRouterState current,
  GoRouterState next,
  GoRouter router,
) async {
  if (current.uri.path == '/evaluations' &&
      next.uri.path == '/evaluations' &&
      current.uri.queryParameters['assessment'] !=
          next.uri.queryParameters['assessment'] &&
      !(await workspaceChangeGuards[router]?.call() ?? true)) {
    return const Block.stop();
  }
  return const Allow();
}

Future<bool> workspaceCanExit(BuildContext context, GoRouterState state) async {
  if (state.uri.path == '/evaluations' &&
      !await prepareWorkspaceChange(context)) {
    return false;
  }
  if (!context.mounted) return false;
  final key = state.matchedLocation.endsWith('/editor')
      ? _editorRequest(context, state)?.key
      : null;
  return _routeExitGuards[GoRouter.of(context)]?[key ?? state.pageKey]
          ?.call() ??
      true;
}

/// Browser history changes must consult the same PopScopes as Fermer/Retour.
class WorkspaceExitGuard extends StatefulWidget {
  const WorkspaceExitGuard({super.key, required this.child});
  final Widget child;

  @override
  State<WorkspaceExitGuard> createState() => _WorkspaceExitGuardState();
}

class _WorkspaceExitGuardState extends State<WorkspaceExitGuard> {
  Map<LocalKey, bool Function()>? guards;
  LocalKey? pageKey;

  bool allowExit() {
    final route = ModalRoute.of(context);
    if (route?.popDisposition != RoutePopDisposition.doNotPop) return true;
    route!.onPopInvokedWithResult(false, null);
    return false;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final router = GoRouter.maybeOf(context);
    final settings = ModalRoute.of(context)?.settings;
    if (router != null && settings is Page && settings.key != null) {
      guards = _routeExitGuards[router] ??= {};
      pageKey = settings.key;
      guards![pageKey!] = allowExit;
    }
  }

  @override
  void dispose() {
    if (guards?[pageKey] == allowExit) guards?.remove(pageKey);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

Future<bool> _readyToPop(BuildContext context) async {
  final route = ModalRoute.of(context);
  if (route?.animation?.status != AnimationStatus.forward) return true;
  final ready = Completer<void>();
  void settled(AnimationStatus status) {
    if (status == AnimationStatus.completed ||
        status == AnimationStatus.dismissed) {
      route!.animation!.removeStatusListener(settled);
      ready.complete();
    }
  }

  route!.animation!.addStatusListener(settled);
  await ready.future;
  return context.mounted && route.isCurrent;
}

Future<void> backFromWorkspace(
  BuildContext context, {
  String fallback = '/home',
}) async {
  if (!await _readyToPop(context) || !context.mounted) return;
  if (!await prepareWorkspaceChange(context) || !context.mounted) return;
  final router = GoRouter.of(context);
  if (!router.canPop()) {
    Router.neglect(context, () => router.go(fallback));
    return;
  }
  final pushed =
      router.routerDelegate.currentConfiguration.lastOrNull
          is ImperativeRouteMatch;
  Router.neglect(context, () => router.pop());
  if (pushed && browser_history.canGoBack) unawaited(browser_history.goBack());
}

Future<void> closeWorkspaceSheet<T>(BuildContext context, [T? result]) async {
  final route = ModalRoute.of(context);
  final navigator = Navigator.of(context);
  if (!await _readyToPop(context) || !context.mounted) return;
  if (route == null || route.popDisposition != RoutePopDisposition.pop) {
    await navigator.maybePop(result);
    return;
  }
  final router = GoRouter.maybeOf(context);
  final routed = route.settings is Page && router != null;
  final pushed =
      routed &&
      router.routerDelegate.currentConfiguration.lastOrNull
          is ImperativeRouteMatch;
  if (routed) {
    Router.neglect(context, () => navigator.pop(result));
  } else {
    navigator.pop(result);
  }
  if (pushed && browser_history.canGoBack) {
    await browser_history.goBack();
    await WidgetsBinding.instance.endOfFrame;
  }
}

typedef WorkspaceDestination = ({
  String Function(AppLocalizations) label,
  String path,
  IconData icon,
});

final teachingWorkspaces = <WorkspaceDestination>[
  (
    label: (tr) => tr.navAgenda,
    path: '/calendar',
    icon: Icons.calendar_today_outlined,
  ),
  (
    label: (tr) => tr.teachingProgressTab,
    path: '/progress',
    icon: Icons.menu_book_outlined,
  ),
  (
    label: (tr) => tr.navEvaluations,
    path: '/evaluations',
    icon: Icons.assignment_outlined,
  ),
  (
    label: (tr) => tr.navReportCards,
    path: '/report-cards',
    icon: Icons.article_outlined,
  ),
];

final classLifeWorkspaces = <WorkspaceDestination>[
  (label: (tr) => tr.navMessages, path: '/inbox', icon: Icons.forum_outlined),
  (
    label: (tr) => tr.familyFeedbackTitle,
    path: '/evaluations/avis',
    icon: Icons.poll_outlined,
  ),
  (label: (tr) => tr.incidents, path: '/incidents', icon: Icons.flag_outlined),
];

final workspaces = [...teachingWorkspaces, ...classLifeWorkspaces];

Future<void> chooseContext(BuildContext context) async {
  if (!await prepareWorkspaceChange(context) || !context.mounted) return;
  final uri = GoRouterState.of(context).uri;
  return context.push<void>(
    uri.replace(path: '${uri.path}/context').toString(),
  );
}

class ClassContextPicker extends StatefulWidget {
  const ClassContextPicker({super.key});
  @override
  State<ClassContextPicker> createState() => _ClassContextPickerState();
}

class _ClassContextPickerState extends State<ClassContextPicker> {
  bool switching = false;
  String? error;
  Future<List<TeacherSchoolChoices>>? choices;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    choices ??= _loadChoices();
  }

  Future<List<TeacherSchoolChoices>> _loadChoices() => loadTeacherSchoolChoices(
    context.levit.find<AuthClient>(),
    context.levit.find<AppSessionController>(),
    context.levit.find<TeacherContextController>(),
    context.levit.find<AcademicYearController>(),
  );

  Future<void> select(
    TeacherSchoolChoices school,
    TeacherAssignmentOption option,
  ) async {
    if (switching) return;
    final scope = LScope.of(context)!;
    final session = scope.find<AppSessionController>();
    final teacher = scope.find<TeacherContextController>();
    final router = GoRouter.of(context);
    final isGradebook =
        GoRouterState.of(context).uri.path == '/evaluations/context';
    setState(() {
      switching = true;
      error = null;
    });
    try {
      final preview = school.catalog;
      if (preview == null ||
          preview.workspace.account != session.user.value?.id) {
        throw StateError(context.tr.thisProfileIsNoLongerAvailable);
      }
      if (session.schoolIdHeader != school.profile.schoolId ||
          session.actorIdHeader != school.profile.actorId) {
        scope.find<AcademicYearController>().clearSelection();
        final failure = await session.selectProfile(school.profile);
        if (failure != null) throw StateError(failure);
        await initializeTeacherAuthenticatedContext(
          scope,
          findEligibleSchool: false,
          preview: preview,
          preferredAssignment: option.id,
        );
      } else if (teacher.activeAssignmentId.value != option.id ||
          !identical(teacher.catalog, preview) ||
          !preview.fresh ||
          teacher.loadFailed.value) {
        await teacher.reloadContext(
          preview: preview,
          preferredAssignment: option.id,
        );
      }
      if (teacher.loadFailed.value) {
        throw StateError(teacher.errorMessage.value);
      }
      if (session.user.value?.id != preview.workspace.account ||
          teacher.catalog?.workspace != preview.workspace ||
          !teacher.assignments.value.any((a) => a.id == option.id)) {
        if (mounted) choices = _loadChoices();
        throw StateError(context.tr.thisAssignmentIsNoLongerAvailable);
      }
      if (teacher.activeAssignmentId.value != option.id) {
        await teacher.selectAssignment(option.id);
      }
      if (mounted) {
        await closeWorkspaceSheet(context);
        if (isGradebook) router.replace('/evaluations');
      }
    } on Object catch (e) {
      if (mounted) {
        setState(() {
          error = e is StateError ? e.message : '$e';
          switching = false;
        });
      }
    }
  }

  @override
  Widget build(
    BuildContext context,
  ) => FutureBuilder<List<TeacherSchoolChoices>>(
    future: choices,
    builder: (context, snapshot) => LWatch(() {
      final teacher = context.levit.find<TeacherContextController>();
      final session = context.levit.find<AppSessionController>();
      return ListView(
        padding: const EdgeInsets.all(PrototypeSpacing.md),
        children: [
          if (!snapshot.hasData || switching) const LinearProgressIndicator(),
          if (error != null)
            Text(
              error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          for (final school in snapshot.data ?? <TeacherSchoolChoices>[]) ...[
            Text(
              school.profile.schoolName,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            if (school.yearLabel != null)
              Text(
                school.yearLabel!,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            const SizedBox(height: PrototypeSpacing.sm),
            if (school.error != null)
              TextButton(
                onPressed: switching
                    ? null
                    : () => setState(() {
                        choices = _loadChoices();
                      }),
                child: Text(school.error!),
              )
            else if (school.options.isEmpty)
              Text(context.tr.noAssignmentsAvailable),
            SurfaceCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  for (final option in school.options)
                    ListTile(
                      title: Text(option.label),
                      leading: const Icon(Icons.groups_outlined),
                      selected:
                          session.schoolIdHeader == school.profile.schoolId &&
                          teacher.activeAssignmentId.value == option.id,
                      trailing:
                          session.schoolIdHeader == school.profile.schoolId &&
                              teacher.activeAssignmentId.value == option.id
                          ? const Icon(Icons.check_circle_outline)
                          : null,
                      onTap: switching ? null : () => select(school, option),
                    ),
                ],
              ),
            ),
            const SizedBox(height: PrototypeSpacing.xl),
          ],
        ],
      );
    }),
  );
}

/// Full pages own their picker/editor routes so browser Back closes the sheet.
GoRoute workspaceRoute({
  required String path,
  required GoRouterWidgetBuilder builder,
  List<RouteBase> routes = const [],
}) => GoRoute(
  path: path,
  builder: (context, state) => WorkspaceExitGuard(
    child: Material(
      type: MaterialType.transparency,
      child: builder(context, state),
    ),
  ),
  onExit: workspaceCanExit,
  routes: [
    GoRoute(
      path: 'context',
      onExit: workspaceCanExit,
      pageBuilder: (_, state) => RecordSheetPage(
        key: state.pageKey,
        title: systemL10n().classAndSubject,
        child: const ClassContextPicker(),
      ),
    ),
    GoRoute(
      path: 'editor',
      onExit: workspaceCanExit,
      // Transient editors return to their owning page after a hard reload.
      redirect: (context, state) => _editorRequest(context, state) != null
          ? null
          : state.uri
                .replace(
                  path: state.uri.path.substring(
                    0,
                    state.uri.path.lastIndexOf('/'),
                  ),
                  queryParameters: {...state.uri.queryParameters}
                    ..remove('edit'),
                )
                .toString(),
      pageBuilder: (context, state) {
        final request = _editorRequest(context, state);
        if (request == null) {
          return NoTransitionPage<void>(
            key: state.pageKey,
            child: const SizedBox.shrink(),
          );
        }
        return RecordSheetPage(
          key: request.key,
          title: request.title,
          wide: request.wide,
          child: request.child,
        );
      },
    ),
    ...routes,
  ],
);

class WorkspaceEditorRequest {
  WorkspaceEditorRequest({
    required this.title,
    required this.child,
    required this.key,
    this.wide = false,
  });
  final bool wide;
  final String title;
  final Widget child;
  final LocalKey key;
  final result = Completer<Object?>();
  Route<dynamic>? route;
  Object? selected;
  void bind(Route<dynamic>? current) {
    if (current == null || current == route) return;
    route = current;
    current.popped.then((value) {
      if (route == current && !result.isCompleted) {
        result.complete(selected ?? value);
      }
    });
  }
}

// Router refreshes can reconstruct a pushed match without its non-serializable
// extra. Keep only open editors, in their owning router and browser tab.
final _openEditors = Expando<Map<String, WorkspaceEditorRequest>>();
int _nextEditor = 0;
WorkspaceEditorRequest? _editorRequest(
  BuildContext context,
  GoRouterState state,
) => state.extra is WorkspaceEditorRequest
    ? state.extra! as WorkspaceEditorRequest
    : _openEditors[GoRouter.of(context)]?[state.uri.queryParameters['edit']];

class WorkspaceShell extends StatelessWidget {
  const WorkspaceShell({super.key, required this.child, required this.uri});
  final Widget child;
  final Uri uri;
  @override
  Widget build(BuildContext context) {
    final path = uri.path;
    final home = path == '/home' || path.startsWith('/home/');
    final account = path == '/account' || path.startsWith('/account/');
    final live = prototypeIsLive(context);
    final owners =
        workspaces
            .where((w) => path == w.path || path.startsWith('${w.path}/'))
            .toList()
          ..sort((a, b) => b.path.length.compareTo(a.path.length));
    final title = account
        ? context.tr.myProfile
        : owners.firstOrNull?.label(context.tr);
    const classButton = ClassContextButton();
    return Scaffold(
      appBar: home
          ? AppBar(
              automaticallyImplyLeading: false,
              centerTitle: false,
              titleSpacing: workspaceGutter(MediaQuery.sizeOf(context).width),
              actionsPadding: EdgeInsets.only(
                right: workspaceGutter(MediaQuery.sizeOf(context).width),
              ),
              toolbarHeight: MediaQuery.textScalerOf(context).scale(24) + 48,
              title: Text(context.tr.navHome),
              actions: [
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: MediaQuery.sizeOf(context).width * .55,
                  ),
                  child: TextButton.icon(
                    key: const ValueKey('home-profile'),
                    style: ButtonStyle(
                      visualDensity: VisualDensity.standard,
                      tapTargetSize: MaterialTapTargetSize.padded,
                      minimumSize: const WidgetStatePropertyAll(Size(68, 68)),
                      padding: const WidgetStatePropertyAll(
                        EdgeInsets.symmetric(horizontal: 16),
                      ),
                      textStyle: WidgetStatePropertyAll(
                        Theme.of(
                          context,
                        ).textTheme.titleMedium?.copyWith(fontSize: 20),
                      ),
                      foregroundColor: WidgetStatePropertyAll(
                        Theme.of(context).colorScheme.primary,
                      ),
                      overlayColor: WidgetStateProperty.resolveWith((states) {
                        final blue = Theme.of(context).colorScheme.primary;
                        if (states.contains(WidgetState.pressed)) {
                          return blue.withValues(alpha: .16);
                        }
                        if (states.contains(WidgetState.hovered) ||
                            states.contains(WidgetState.focused)) {
                          return blue.withValues(alpha: .09);
                        }
                        return null;
                      }),
                      shape: WidgetStateProperty.resolveWith(
                        (states) => RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                            PrototypeRadii.sm,
                          ),
                          side: states.contains(WidgetState.focused)
                              ? BorderSide(
                                  color: Theme.of(context).colorScheme.primary,
                                  width: 2,
                                )
                              : BorderSide.none,
                        ),
                      ),
                    ),
                    icon: live
                        ? const TeacherPortrait(radius: 17)
                        : LWatch(() {
                            final mock = context.levit
                                .find<MockTeacherContextBridge>()
                                .store;
                            final photo = mock.teacher.photoUrl;
                            if (photo == null || photo.trim().isEmpty) {
                              return const Icon(
                                Icons.account_circle_outlined,
                                size: 34,
                              );
                            }
                            return ExcludeSemantics(
                              child: PersonAvatar(
                                name: mock.teacherFullName,
                                initials: mock.teacherInitials,
                                photoUrl: photo,
                                radius: 17,
                              ),
                            );
                          }),
                    label: Text(context.tr.navProfile),
                    onPressed: () => context.push('/account'),
                  ),
                ),
              ],
            )
          : title == null
          ? null
          : AppBar(
              leading: IconButton(
                tooltip: context.tr.backAction,
                icon: const Icon(Icons.arrow_back),
                onPressed: () => backFromWorkspace(context),
              ),
              toolbarHeight: MediaQuery.textScalerOf(context).scale(20) + 36,
              title: WorkspacePageHeading(
                title: title,
                picker: live && !account ? classButton : null,
              ),
              centerTitle: false,
            ),
      body: SafeArea(
        child: Column(
          children: [
            if (GoRouter.maybeOf(context) case final router?)
              ValueListenableBuilder<RouteInformation>(
                valueListenable: router.routeInformationProvider,
                builder: (_, information, _) =>
                    _AccessNotice(uri: information.uri),
              )
            else
              _AccessNotice(uri: uri),
            Expanded(
              child: home || path.startsWith('/calendar')
                  ? child
                  : Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(
                          maxWidth: workspaceMaxWidth,
                        ),
                        child: SizedBox.expand(child: child),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AccessNotice extends StatelessWidget {
  const _AccessNotice({required this.uri});
  final Uri uri;

  @override
  Widget build(BuildContext context) {
    if (uri.queryParameters['notice'] != 'access') {
      return const SizedBox.shrink();
    }
    return Semantics(
      container: true,
      liveRegion: true,
      child: MaterialBanner(
        content: Text(context.tr.thisRecordIsUnavailableOrYourAccessHas),
        actions: [
          TextButton(
            onPressed: () {
              final query = {...uri.queryParameters}..remove('notice');
              Router.neglect(
                context,
                () => context.replace(
                  uri.replace(queryParameters: query).toString(),
                ),
              );
            },
            child: Text(context.tr.dismissMessage),
          ),
        ],
      ),
    );
  }
}

Future<T?> showWorkspaceEditor<T>({
  required BuildContext context,
  required String title,
  Uri? ownerUri,
  bool wide = false,
  required Widget Function(BuildContext, ValueChanged<T?>) builder,
}) {
  final host = context.findAncestorStateOfType<_WorkspaceSheetState>();
  if (host != null) return host.edit(context, title, builder);
  if (GoRouter.maybeOf(context) case final router?) {
    final uri = ownerUri ?? GoRouterState.of(context).uri;
    final token = '${++_nextEditor}';
    final entries = _openEditors[router] ??= <String, WorkspaceEditorRequest>{};
    late final WorkspaceEditorRequest request;
    request = WorkspaceEditorRequest(
      wide: wide,
      key: ValueKey('workspace-editor-$token'),
      title: title,
      child: LScope.capture(
        context,
        child: Builder(
          builder: (inner) {
            request.bind(ModalRoute.of(inner));
            return builder(inner, (value) {
              request.selected = value;
              closeWorkspaceSheet(inner, value);
            });
          },
        ),
      ),
    );
    entries[token] = request;
    unawaited(
      router
          .push<T>(
            uri
                .replace(
                  path: '${uri.path}/editor',
                  queryParameters: {...uri.queryParameters, 'edit': token},
                )
                .toString(),
            extra: request,
          )
          .then(
            (value) {
              if (request.route == null && !request.result.isCompleted) {
                request.result.complete(value);
              }
            },
            onError: (Object error, StackTrace stack) {
              if (!request.result.isCompleted) {
                request.result.completeError(error, stack);
              }
            },
          ),
    );
    return request.result.future
        .then((value) => value as T?)
        .whenComplete(() => entries.remove(token));
  }
  return showModalBottomSheet<T>(
    context: context,
    useSafeArea: true,
    isScrollControlled: true,
    constraints: BoxConstraints(maxWidth: wide ? 960 : 640),
    builder: (sheetContext) => LScope.capture(
      context,
      child: WorkspaceSheet(
        title: title,
        child: Builder(
          builder: (inner) =>
              builder(inner, (value) => Navigator.pop(sheetContext, value)),
        ),
      ),
    ),
  );
}

Future<bool> confirmWorkspaceDiscard(BuildContext context) {
  final host = context.findAncestorStateOfType<_WorkspaceSheetState>();
  if (host != null) return host.confirmDiscard(context);
  return showWorkspaceEditor<bool>(
    context: context,
    title: context.tr.guardianDiscardChanges,
    builder: (context, finish) => _discardChoices(context, finish),
  ).then((value) => value == true);
}

Widget _discardChoices(BuildContext context, ValueChanged<bool?> finish) =>
    Column(
      children: [
        TextButton(
          onPressed: () => finish(false),
          child: Text(context.tr.gradebookContinue),
        ),
        TextButton(
          onPressed: () => finish(true),
          child: Text(context.tr.gradebookDiscard),
        ),
      ],
    );

class WorkspaceSheet extends StatefulWidget {
  const WorkspaceSheet({super.key, required this.title, required this.child});
  final String title;
  final Widget child;

  @override
  State<WorkspaceSheet> createState() => _WorkspaceSheetState();
}

class _WorkspaceSheetState extends State<WorkspaceSheet>
    with WidgetsBindingObserver {
  Size? viewport;
  FocusNode? editingOnResize;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    viewport = View.of(context).physicalSize;
  }

  @override
  void didChangeMetrics() {
    final size = View.of(context).physicalSize;
    if (viewport == size) return;
    viewport = size;
    final focus = FocusManager.instance.primaryFocus;
    final field = focus?.context;
    if (field != null &&
        field.findAncestorStateOfType<_WorkspaceSheetState>() == this &&
        field.findAncestorStateOfType<EditableTextState>() != null) {
      editingOnResize = focus;
    }
    final original = editingOnResize;
    if (original == null) return;
    // Wrapping can move the caret below the viewport. Bring it back before
    // Chrome removes the offscreen text input from its accessibility tree.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || editingOnResize != original) return;
      editingOnResize = null;
      final field = original.context;
      if (field == null ||
          !field.mounted ||
          ModalRoute.of(field)?.isCurrent != true) {
        return;
      }
      final current = FocusManager.instance.primaryFocus;
      if (current != original &&
          current is! FocusScopeNode &&
          current != null) {
        return;
      }
      final editor = field.findAncestorStateOfType<EditableTextState>();
      if (editor == null) return;
      final scrollBox = Scrollable.maybeOf(
        editor.context,
        axis: Axis.vertical,
      )?.context.findRenderObject();
      final fieldBox = editor.renderEditable;
      if (scrollBox is RenderBox && scrollBox.hasSize && fieldBox.hasSize) {
        final top =
            fieldBox.localToGlobal(Offset.zero).dy -
            scrollBox.localToGlobal(Offset.zero).dy;
        if (top < 0 || top + fieldBox.size.height > scrollBox.size.height) {
          Scrollable.ensureVisible(editor.context, alignment: .45);
        }
      }
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!editor.mounted ||
            !mounted ||
            ModalRoute.of(editor.context)?.isCurrent != true) {
          return;
        }
        final active = FocusManager.instance.primaryFocus;
        if (active != null && active != original && active is! FocusScopeNode) {
          return;
        }
        original.requestFocus();
        editor.requestKeyboard();
      });
      WidgetsBinding.instance.scheduleFrame();
    });
  }

  final _editors = <({Widget child, String title, VoidCallback cancel})>[];
  bool _disposed = false;
  Future<bool>? _discardConfirmation;

  Future<bool> confirmDiscard(BuildContext context) {
    return _discardConfirmation ??=
        edit<bool>(
              context,
              context.tr.guardianDiscardChanges,
              (context, finish) => _discardChoices(context, finish),
            )
            .then((value) => value == true)
            .whenComplete(() => _discardConfirmation = null);
  }

  Future<T?> edit<T>(
    BuildContext source,
    String title,
    Widget Function(BuildContext, ValueChanged<T?>) builder,
  ) {
    final result = Completer<T?>();
    late final ({Widget child, String title, VoidCallback cancel}) entry;
    void finish(T? value) {
      if (!result.isCompleted) result.complete(value);
      if (_disposed) return;
      final index = _editors.indexOf(entry);
      if (index < 0) return;
      setState(() {
        for (final later in _editors.skip(index + 1)) {
          later.cancel();
        }
        _editors.removeRange(index, _editors.length);
      });
    }

    entry = (
      title: title,
      cancel: () {
        if (!result.isCompleted) result.complete(null);
      },
      child: LScope.capture(
        source,
        child: Builder(builder: (context) => builder(context, finish)),
      ),
    );
    setState(() => _editors.add(entry));
    return result.future;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _disposed = true;
    for (final entry in _editors) {
      entry.cancel();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FractionallySizedBox(
    heightFactor: .88,
    child: Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: PrototypeSpacing.md,
            vertical: PrototypeSpacing.xs,
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  _editors.lastOrNull?.title ?? widget.title,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              TextButton(
                onPressed: () => closeWorkspaceSheet(context),
                child: Text(context.tr.closeAction),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: Stack(
            fit: StackFit.expand,
            children: [
              Offstage(offstage: _editors.isNotEmpty, child: widget.child),
              for (final entry in _editors)
                Offstage(
                  key: ObjectKey(entry.child),
                  offstage: entry != _editors.last,
                  child: entry.child,
                ),
            ],
          ),
        ),
      ],
    ),
  );
}

Future<DateTime?> showWorkspaceDatePicker({
  required BuildContext context,
  required DateTime initialDate,
  required DateTime firstDate,
  required DateTime lastDate,
}) => showWorkspaceEditor<DateTime>(
  context: context,
  title: context.tr.chooseDate,
  builder: (context, finish) => SingleChildScrollView(
    child: CalendarDatePicker(
      initialDate: initialDate,
      firstDate: firstDate,
      lastDate: lastDate,
      onDateChanged: finish,
    ),
  ),
);

class RecordSheetPage extends Page<Object?> {
  const RecordSheetPage({
    required super.key,
    required this.title,
    required this.child,
    this.wide = false,
  });
  final bool wide;
  final String title;
  final Widget child;
  @override
  Route<Object?> createRoute(
    BuildContext context,
  ) => ModalBottomSheetRoute<Object?>(
    settings: this,
    backgroundColor: Colors.transparent,
    constraints: BoxConstraints(maxWidth: wide ? 992 : 672),
    isScrollControlled: true,
    useSafeArea: true,
    builder: (context) {
      final page = ModalRoute.of(context)!.settings as RecordSheetPage;
      return WorkspaceExitGuard(
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: MediaQuery.sizeOf(context).width >= 600 ? 16 : 0,
          ),
          child: Material(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(PrototypeRadii.lg),
            ),
            clipBehavior: Clip.antiAlias,
            child: Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.viewInsetsOf(context).bottom,
              ),
              // The sheet already reserves the keyboard space for its editors.
              child: MediaQuery.removeViewInsets(
                context: context,
                removeBottom: true,
                child: WorkspaceSheet(title: page.title, child: page.child),
              ),
            ),
          ),
        ),
      );
    },
  );
}

class ClassContextButton extends StatelessWidget {
  const ClassContextButton({super.key});
  @override
  Widget build(BuildContext context) => TextButton(
    style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
    onPressed: () => chooseContext(context),
    child: Row(
      children: [
        const Icon(Icons.groups_outlined),
        const SizedBox(width: 8),
        Expanded(
          child: LWatch(
            () => Text(
              context.levit
                      .find<TeacherContextController>()
                      .activeAssignment
                      ?.label ??
                  context.tr.noAssignment,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
      ],
    ),
  );
}
