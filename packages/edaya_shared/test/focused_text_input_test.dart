import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'support/enter_focused_text.dart';

void main() {
  testWidgets(
    'typing reconnects a field disabled during an async form action',
    (tester) async {
      var enabled = true;
      var entered = '';
      late StateSetter rebuild;
      final text = TextEditingController();
      addTearDown(text.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                rebuild = setState;
                return TextFormField(
                  controller: text,
                  enabled: enabled,
                  onChanged: (value) => entered = value,
                );
              },
            ),
          ),
        ),
      );
      final field = find.byType(TextFormField);
      await tester.enterText(field, 'old');
      final editable = tester.state<EditableTextState>(
        find.byType(EditableText),
      );
      rebuild(() => enabled = false);
      await tester.pump();
      expect(tester.testTextInput.hasAnyClients, isFalse);
      text.clear();
      entered = '';
      rebuild(() => enabled = true);
      await tester.pump();
      expect(
        tester.state<EditableTextState>(find.byType(EditableText)),
        same(editable),
      );
      expect(text.text, isEmpty);
      expect(entered, isEmpty);

      await enterFocusedText(tester, field, 'replacement');
      expect(entered, 'replacement');
      expect(text.text, 'replacement');
    },
  );
}
