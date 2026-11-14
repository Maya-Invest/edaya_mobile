import 'package:edaya_teacher_v2/design/workspace_layout.dart';
import 'package:edaya_teacher_v2/app/workspace_navigation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('an editor keeps its focus and draft when the sections wrap', (
    tester,
  ) async {
    addTearDown(() => tester.view.resetPhysicalSize());
    addTearDown(() => tester.view.resetDevicePixelRatio());
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1024, 768);
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: WorkspaceColumns(
              first: [Text('Context')],
              second: [TextField()],
            ),
          ),
        ),
      ),
    );
    final input = find.byType(TextField);
    await tester.tap(input);
    await tester.enterText(input, 'unsaved');
    final editor = tester.state<EditableTextState>(find.byType(EditableText));
    expect(tester.getTopLeft(input).dx, greaterThanOrEqualTo(320));
    tester.view.physicalSize = const Size(390, 844);
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(input).dx, 0);
    expect(
      tester.state<EditableTextState>(find.byType(EditableText)),
      same(editor),
    );
    expect(editor.widget.focusNode.hasFocus, isTrue);
    expect(editor.widget.controller.text, 'unsaved');
  });
  testWidgets(
    'a sheet keeps the active field on screen after longer content wraps above it',
    (tester) async {
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(1024, 768);
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => Navigator.of(context).push(
                  RecordSheetPage(
                    key: const ValueKey('report'),
                    title: 'Bulletin',
                    wide: true,
                    child: ListView(
                      children: [
                        WorkspaceColumns(
                          first: List.generate(
                            18,
                            (i) =>
                                SizedBox(height: 56, child: Text('Matière $i')),
                          ),
                          second: const [TextField()],
                        ),
                      ],
                    ),
                  ).createRoute(context),
                ),
                child: const Text('Ouvrir'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Ouvrir'));
      await tester.pumpAndSettle();
      final field = find.byType(TextField);
      await tester.tap(field);
      await tester.enterText(field, 'En cours');
      tester.view.physicalSize = const Size(390, 844);
      await tester.pumpAndSettle();
      expect(tester.getRect(field).bottom, lessThanOrEqualTo(844));
      expect(
        tester
            .state<EditableTextState>(find.byType(EditableText))
            .widget
            .focusNode
            .hasFocus,
        isTrue,
      );
      expect(find.text('En cours'), findsOneWidget);
    },
  );
}
