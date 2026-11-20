import 'dart:convert';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// Capture the actual failing widget hierarchy without text fields, image
/// contents, keys or controller values that could contain authentication secrets.
void installWidgetFailureArtifacts(
  TestWidgetsFlutterBinding binding, {
  String? artifactDirectory,
}) {
  final previous = reportTestException;
  reportTestException = (details, description) {
    try {
      final directory =
          artifactDirectory ??
          Platform.environment['EDAYA_INTEGRATION_ARTIFACTS'];
      if (directory != null) {
        final id =
            RegExp(r'\[([^\]]+)\]').firstMatch(description)?.group(1) ??
            'unknown-scenario';
        final widgets = <Map<String, Object?>>[];
        void visit(Element element, int depth) {
          widgets.add({
            'type': element.widget.runtimeType.toString(),
            'depth': depth,
          });
          element.visitChildren((child) => visit(child, depth + 1));
        }

        final root = binding.rootElement;
        if (root != null) visit(root, 0);
        Directory(directory).createSync(recursive: true);
        File(
          '$directory/${id.replaceAll(RegExp(r'[^a-zA-Z0-9_.-]'), '_')}.widget.json',
        ).writeAsStringSync(
          jsonEncode({
            'scenarioId': id,
            'capturedAt': DateTime.now().toUtc().toIso8601String(),
            'widgets': widgets,
            'diagnostics':
                'Expected outcome and exception are in the matching runner JSON events.',
          }),
        );
      }
    } finally {
      // Artifact handling must never suppress the original test failure.
      previous(details, description);
    }
  };
}
