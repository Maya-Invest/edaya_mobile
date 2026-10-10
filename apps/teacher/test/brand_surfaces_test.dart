import 'package:edaya_teacher/design/components/surface_card.dart';
import 'package:edaya_teacher/design/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final dark in [false, true]) {
    testWidgets(
      'card text remains readable in ${dark ? "dark" : "light"} mode',
      (tester) async {
        final theme = dark ? PrototypeTheme.dark : PrototypeTheme.light;
        await tester.pumpWidget(
          MaterialApp(
            theme: theme,
            home: const Scaffold(body: SurfaceCard(child: Text('Connexion'))),
          ),
        );
        final material = tester.widget<Material>(
          find.descendant(
            of: find.byType(SurfaceCard),
            matching: find.byType(Material),
          ),
        );
        final context = tester.element(find.text('Connexion'));
        final foreground = DefaultTextStyle.of(context).style.color!;
        final background = material.color!;
        final luminances = [
          foreground.computeLuminance(),
          background.computeLuminance(),
        ]..sort();
        expect(
          (luminances.last + 0.05) / (luminances.first + 0.05),
          greaterThanOrEqualTo(4.5),
        );
        expect(background, theme.colorScheme.surface);
      },
    );
  }
}
