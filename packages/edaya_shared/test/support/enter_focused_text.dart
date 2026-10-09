import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Reconnects the keyboard after a busy form temporarily disables its field.
/// Live binding focus/connection updates can lag a busy-field rebuild. Refocus
/// and process the frame before sending input, then require the field to accept it.
Future<void> enterFocusedText(
  WidgetTester tester,
  Finder field,
  String text,
) async {
  await tester.ensureVisible(field);
  await tester.tap(field);
  await tester.pump();
  final editable = find.descendant(
    of: field,
    matching: find.byType(EditableText),
  );
  expect(tester.widget<EditableText>(editable).focusNode.hasFocus, isTrue);
  expect(tester.testTextInput.hasAnyClients, isTrue);
  await tester.enterText(field, text);
  await tester.pump();
  // Compare without printing potentially sensitive input on failure.
  expect(
    tester.widget<EditableText>(editable).controller.text == text,
    isTrue,
    reason: 'Simulated input must reach the focused field before submission',
  );
}
