import 'dart:io';
import 'dart:convert';
import 'dart:ui' as ui;
import 'package:edaya_shared/edaya_shared.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:levit_flutter/levit_flutter.dart';

const reviewCases = [
  (
    name: 'phone-fr-light',
    locale: 'fr',
    size: Size(390, 844),
    dark: false,
    scale: 1.0,
    keyboardInset: 0.0,
  ),
  (
    name: 'phone-en-dark',
    locale: 'en',
    size: Size(390, 844),
    dark: true,
    scale: 1.0,
    keyboardInset: 0.0,
  ),
  (
    name: 'tablet-en-light',
    locale: 'en',
    size: Size(1024, 1366),
    dark: false,
    scale: 1.0,
    keyboardInset: 0.0,
  ),
  (
    name: 'phone-fr-large',
    locale: 'fr',
    size: Size(390, 844),
    dark: false,
    scale: 2.0,
    keyboardInset: 0.0,
  ),
  (
    name: 'phone-en-keyboard',
    locale: 'en',
    size: Size(390, 844),
    dark: false,
    scale: 1.0,
    keyboardInset: 320.0,
  ),
];

Future<void> loadReviewFonts() async {
  TestWidgetsFlutterBinding.ensureInitialized();
  final manifest =
      jsonDecode(await rootBundle.loadString('FontManifest.json')) as List;
  for (final entry in manifest) {
    final loader = FontLoader(entry['family'] as String);
    for (final font in entry['fonts'] as List) {
      loader.addFont(rootBundle.load(font['asset'] as String));
    }
    await loader.load();
  }
}

Future<void> captureReview(
  WidgetTester tester,
  String name,
  Widget app,
  Size size, {
  double keyboardInset = 0,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  tester.view.viewInsets = FakeViewPadding(bottom: keyboardInset);
  addTearDown(tester.view.resetViewInsets);
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final key = GlobalKey();
  await tester.pumpWidget(RepaintBoundary(key: key, child: app));
  await tester.pumpAndSettle();
  if (keyboardInset > 0) {
    await tester.tap(find.byType(TextFormField).last);
    await tester.ensureVisible(find.byType(FilledButton));
    await tester.pumpAndSettle();
    expect(
      tester.getBottomRight(find.byType(FilledButton)).dy,
      lessThanOrEqualTo(size.height - keyboardInset),
    );
  }
  expect(
    tester.takeException(),
    isNull,
    reason: '$name must lay out without overflow',
  );
  if (Platform.environment['EDAYA_CAPTURE_DESIGN_REVIEW'] == '1') {
    await tester.runAsync(() async {
      final boundary =
          key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = await boundary.toImage();
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      final file = File('design-review/current/$name.png');
      await file.parent.create(recursive: true);
      await file.writeAsBytes(bytes!.buffer.asUint8List());
      image.dispose();
    });
  }
}

Widget reviewScope({
  required Widget child,
  void Function(LevitScope)? dependencies,
}) => LScope(
  name: 'edaya-design-review',
  dependencyFactory: (scope) {
    scope.put(() => AppSettingsController());
    dependencies?.call(scope);
  },
  child: child,
);
