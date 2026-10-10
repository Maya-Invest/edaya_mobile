import 'package:edaya_shared/edaya_shared.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final dark in [false, true]) {
    testWidgets(
      'logo keeps its width in a stretched ${dark ? "dark" : "light"} layout',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: dark ? AppTheme.dark : AppTheme.light,
            home: const Scaffold(
              body: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  EdayaBrandLogo(
                    variant: EdayaLogoVariant.vertical,
                    width: 160,
                  ),
                ],
              ),
            ),
          ),
        );
        final image = tester.widget<Image>(find.byType(Image));
        expect(tester.getSize(find.byType(Image)).width, 160);
        expect(
          (image.image as AssetImage).assetName,
          endsWith(dark ? 'vertical-blanc.png' : 'vertical-couleur.png'),
        );
      },
    );
  }
  testWidgets('white startup canvas always uses the color logo', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(theme: AppTheme.dark, home: const EdayaStartupScreen()),
    );
    final image = tester.widget<Image>(find.byType(Image));
    expect(
      (image.image as AssetImage).assetName,
      endsWith('symbole-couleur.png'),
    );
  });
}
