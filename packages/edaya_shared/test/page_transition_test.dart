import 'dart:ui' as ui;

import 'package:edaya_shared/edaya_shared.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final brightness in Brightness.values) {
    testWidgets(
      'incoming page paints the $brightness canvas during navigation',
      (tester) async {
        final theme = brightness == Brightness.light
            ? AppTheme.light
            : AppTheme.dark;
        final navigator = GlobalKey<NavigatorState>();
        final frame = GlobalKey();
        await tester.pumpWidget(
          RepaintBoundary(
            key: frame,
            child: MaterialApp(
              theme: theme,
              navigatorKey: navigator,
              home: const ColoredBox(color: Colors.red),
            ),
          ),
        );

        // A workspace destination can rely entirely on its shell for a canvas.
        final route = MaterialPageRoute<void>(
          builder: (_) => const SizedBox.expand(),
        );
        navigator.currentState!.push(route);
        await tester.pump();
        await tester.pump(route.transitionDuration * 0.8);
        expect(route.animation!.status, AnimationStatus.forward);

        // At this point the incoming page covers the center on both platforms.
        final boundary = tester.renderObject<RenderRepaintBoundary>(
          find.byKey(frame),
        );
        final image = await boundary.toImage();
        addTearDown(image.dispose);
        final bytes = await tester.runAsync(
          () => image.toByteData(format: ui.ImageByteFormat.rawStraightRgba),
        );
        final offset =
            ((image.height ~/ 2) * image.width + image.width ~/ 2) * 4;
        final color = Color.fromARGB(
          bytes!.getUint8(offset + 3),
          bytes.getUint8(offset),
          bytes.getUint8(offset + 1),
          bytes.getUint8(offset + 2),
        );
        expect(color, theme.scaffoldBackgroundColor);
        await tester.pumpAndSettle();
      },
      variant: const TargetPlatformVariant({
        TargetPlatform.android,
        TargetPlatform.iOS,
      }),
    );
  }
}
