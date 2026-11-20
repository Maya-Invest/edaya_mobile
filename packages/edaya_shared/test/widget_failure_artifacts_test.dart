import 'dart:io';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'support/widget_failure_artifacts.dart';

void main() {
  testWidgets(
    'failure artifacts preserve failure reporting without leaking widget secrets',
    (tester) async {
      final directory = Directory.systemTemp.createTempSync(
        'edaya-failure-artifact-',
      );
      final original = reportTestException;
      var reported = false;
      try {
        await tester.pumpWidget(
          const Directionality(
            textDirection: TextDirection.ltr,
            child: Text('PRIVATE-RECOVERY-SECRET'),
          ),
        );
        reportTestException = (_, _) => reported = true;
        installWidgetFailureArtifacts(
          tester.binding,
          artifactDirectory: directory.path,
        );
        reportTestException(
          FlutterErrorDetails(exception: StateError('PRIVATE-TOKEN')),
          '[guardian.example] expected a loaded page',
        );
        expect(reported, isTrue);
        final artifact = File(
          '${directory.path}/guardian.example.widget.json',
        ).readAsStringSync();
        expect(artifact, contains('guardian.example'));
        expect(artifact, contains('Directionality'));
        expect(artifact, isNot(contains('PRIVATE-')));
      } finally {
        reportTestException = original;
        directory.deleteSync(recursive: true);
      }
    },
  );
}
