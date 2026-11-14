import 'package:edaya_teacher_v2/app/workspace_navigation.dart';
import 'package:edaya_teacher_v2/live/prototype_runtime.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:levit_flutter/levit_flutter.dart';

void main() {
  Levit.enableAutoLinking();

  testWidgets('route replacement asks a dirty PopScope before leaving', (
    tester,
  ) async {
    final dirty = ValueNotifier(true);
    var prompts = 0;
    final router = GoRouter(
      initialLocation: '/calendar',
      routes: [
        workspaceRoute(
          path: '/calendar',
          builder: (_, _) => ValueListenableBuilder<bool>(
            valueListenable: dirty,
            builder: (_, value, _) => PopScope(
              canPop: !value,
              onPopInvokedWithResult: (popped, _) {
                if (!popped) prompts++;
              },
              child: const Scaffold(body: Text('Draft')),
            ),
          ),
        ),
        GoRoute(
          path: '/home',
          builder: (_, _) => const Scaffold(body: Text('Home')),
        ),
      ],
    );
    addTearDown(router.dispose);
    addTearDown(dirty.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();
    router.go('/home');
    await tester.pumpAndSettle();
    expect(find.text('Draft'), findsOneWidget);
    expect(prompts, 1);
    dirty.value = false;
    await tester.pump();
    router.go('/home');
    await tester.pumpAndSettle();
    expect(find.text('Home'), findsOneWidget);
  });

  testWidgets('routed editor returns its result and reload keeps its owner', (
    tester,
  ) async {
    String? result;
    final router = GoRouter(
      initialLocation: '/calendar',
      routes: [
        workspaceRoute(
          path: '/calendar',
          builder: (context, _) => Scaffold(
            body: TextButton(
              onPressed: () async {
                result = await showWorkspaceEditor<String>(
                  context: context,
                  title: 'Date',
                  builder: (_, finish) => TextButton(
                    onPressed: () => finish('selected'),
                    child: const Text('Select'),
                  ),
                );
              },
              child: const Text('Open date'),
            ),
          ),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      LScope(
        name: 'routed-editor-test',
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Open date'));
    await tester.pumpAndSettle();
    expect(find.byType(BottomSheet), findsOneWidget);
    router.refresh();
    await tester.pumpAndSettle();
    expect(find.text('Select'), findsOneWidget);
    await tester.tap(find.text('Select'));
    await tester.pumpAndSettle();
    expect(result, 'selected');
    expect(find.text('Open date'), findsOneWidget);
    router.go('/calendar/editor');
    await tester.pumpAndSettle();
    expect(router.routeInformationProvider.value.uri.path, '/calendar');
    expect(find.byType(BottomSheet), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('workspace displays the access explanation from its route', (
    tester,
  ) async {
    await tester.pumpWidget(
      LScope(
        name: 'workspace-access-notice-test',
        dependencyFactory: (scope) => scope.put<PrototypeRuntime>(
          () => const PrototypeRuntime(live: false),
        ),
        child: MaterialApp(
          home: WorkspaceShell(
            uri: Uri.parse('/evaluations?notice=access'),
            child: const Text('Assessments'),
          ),
        ),
      ),
    );
    expect(
      find.text(
        'Ce dossier est indisponible ou vos droits d’accès ont changé.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('editing preserves the invoking form inside one bottom sheet', (
    tester,
  ) async {
    var result = '';
    await tester.pumpWidget(
      LScope(
        name: 'single-sheet-test',
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => showWorkspaceEditor<void>(
                  context: context,
                  title: 'Record',
                  builder: (recordContext, _) => StatefulBuilder(
                    builder: (context, setState) => Column(
                      children: [
                        Text('Saved $result'),
                        TextButton(
                          child: const Text('Edit'),
                          onPressed: () async {
                            final value = await showWorkspaceEditor<String>(
                              context: recordContext,
                              title: 'Editor',
                              builder: (_, finish) => TextButton(
                                onPressed: () => finish('value'),
                                child: const Text('Save'),
                              ),
                            );
                            if (context.mounted && value != null) {
                              setState(() => result = value);
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                ),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Edit'));
    await tester.pumpAndSettle();
    expect(find.byType(BottomSheet), findsOneWidget);
    expect(find.text('Edit'), findsNothing);
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(find.text('Saved value'), findsOneWidget);
    expect(find.byType(BottomSheet), findsOneWidget);

    await tester.tap(find.text('Edit'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Fermer'));
    await tester.pumpAndSettle();
    expect(find.byType(BottomSheet), findsNothing);
    expect(result, 'value');
    expect(tester.takeException(), isNull);
  });
}
