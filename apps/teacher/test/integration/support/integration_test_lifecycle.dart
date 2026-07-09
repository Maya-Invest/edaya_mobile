import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:levit_flutter/levit_flutter.dart';

/// Resets the widget tree and Levit state between integration widget tests.
Future<void> resetIntegrationTestSurface(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
  Levit.reset();
}

void configureIntegrationTestViewport() {
  final view = TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
  view.physicalSize = const Size(390, 844);
  view.devicePixelRatio = 1.0;
}

void resetIntegrationTestViewport() {
  final view = TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
  view.resetPhysicalSize();
  view.resetDevicePixelRatio();
}
