import 'dart:io';
import 'dart:ui' as ui;
import 'package:edaya_shared/edaya_shared.dart';
import 'package:edaya_shared/src/features/messaging/conversation_message_bubble.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    for (final family in ['Inter', 'Poppins']) {
      final loader = FontLoader('packages/edaya_shared/$family');
      final weights = family == 'Inter'
          ? ['Regular', 'Medium', 'SemiBold', 'Bold']
          : ['SemiBold'];
      for (final weight in weights) {
        loader.addFont(rootBundle.load('assets/fonts/$family-$weight.ttf'));
      }
      await loader.load();
    }
  });
  test('direction matches both profile kind and actor ID', () {
    for (final kind in ['guardian', 'teacher']) {
      expect(
        isOutgoingConversationMessage(
          authorKind: kind,
          authorId: 'same',
          viewerKind: kind,
          viewerId: 'same',
        ),
        isTrue,
      );
      expect(
        isOutgoingConversationMessage(
          authorKind: kind,
          authorId: 'other',
          viewerKind: kind,
          viewerId: 'same',
        ),
        isFalse,
      );
      expect(
        isOutgoingConversationMessage(
          authorKind: 'staff',
          authorId: 'same',
          viewerKind: kind,
          viewerId: 'same',
        ),
        isFalse,
      );
    }
    expect(
      isOutgoingConversationMessage(
        authorKind: 'guardian',
        authorId: '',
        viewerKind: null,
        viewerId: null,
      ),
      isFalse,
    );
  });

  for (final portal in ['guardian', 'teacher']) {
    for (final language in ['fr', 'en']) {
      for (final dark in [false, true]) {
        for (final width in [390.0, 900.0]) {
          for (final scale in [1.0, 2.0]) {
            final name =
                '$portal-$language-${dark ? 'dark' : 'light'}-${width.toInt()}-${scale.toInt()}x';
            testWidgets(name, (tester) async {
              await tester.binding.setSurfaceSize(Size(width, 1100));
              addTearDown(() => tester.binding.setSurfaceSize(null));
              final semantics = tester.ensureSemantics();
              try {
                await tester.pumpWidget(
                  MaterialApp(
                    theme: dark ? AppTheme.dark : AppTheme.light,
                    locale: Locale(language),
                    localizationsDelegates:
                        AppLocalizations.localizationsDelegates,
                    supportedLocales: AppLocalizations.supportedLocales,
                    builder: (context, child) => MediaQuery(
                      data: MediaQuery.of(
                        context,
                      ).copyWith(textScaler: TextScaler.linear(scale)),
                      child: child!,
                    ),
                    home: RepaintBoundary(
                      key: const Key('capture'),
                      child: Scaffold(
                        appBar: AppBar(
                          title: Text(
                            language == 'fr'
                                ? 'Absence de mon enfant'
                                : 'My child’s absence',
                          ),
                        ),
                        body: ListView(
                          padding: const EdgeInsets.all(16),
                          children: [
                            ConversationMessageBubble(
                              outgoing: portal == 'guardian',
                              author: 'Mariam Koné',
                              body: language == 'fr'
                                  ? 'Mon enfant sera absent demain.\nMerci de votre compréhension.'
                                  : 'My child will be absent tomorrow.\nThank you for understanding.',
                              timestamp: language == 'fr'
                                  ? '9 oct. 2026 · 22:26'
                                  : 'Oct 9, 2026 · 10:26 PM',
                            ),
                            ConversationMessageBubble(
                              outgoing: portal == 'teacher',
                              author: 'Aminata Koné',
                              body: language == 'fr'
                                  ? 'Merci de nous apporter le justificatif d’absence.'
                                  : 'Please bring the absence documentation.',
                              timestamp: language == 'fr'
                                  ? '9 oct. 2026 · 22:27'
                                  : 'Oct 9, 2026 · 10:27 PM',
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
                await tester.pumpAndSettle();
                expect(tester.takeException(), isNull);
                expect(find.text('Mariam Koné'), findsOneWidget);
                final sent = language == 'fr' ? 'Envoyé par' : 'Sent by';
                final received = language == 'fr' ? 'Reçu de' : 'Received from';
                expect(
                  find.bySemanticsLabel(
                    RegExp(
                      '$sent ${portal == 'guardian' ? 'Mariam' : 'Aminata'}',
                    ),
                  ),
                  findsOneWidget,
                );
                expect(
                  find.bySemanticsLabel(
                    RegExp(
                      '$received ${portal == 'guardian' ? 'Aminata' : 'Mariam'}',
                    ),
                  ),
                  findsOneWidget,
                );

                final boxes = find.descendant(
                  of: find.byType(ConversationMessageBubble),
                  matching: find.byType(DecoratedBox),
                );
                final first = tester.getRect(boxes.at(0));
                final second = tester.getRect(boxes.at(1));
                expect(
                  portal == 'guardian' ? first.right : second.right,
                  closeTo(width - 16, 1),
                );
                expect(
                  portal == 'guardian' ? second.left : first.left,
                  closeTo(16, 1),
                );
                expect(first.width, lessThanOrEqualTo(560));
                expect(
                  await textContrastGuideline.evaluate(tester),
                  isA<Evaluation>().having((r) => r.passed, 'contrast', isTrue),
                );
                final output = Platform.environment['EDAYA_MESSAGE_CAPTURES'];
                if (output != null) {
                  final boundary = tester.renderObject<RenderRepaintBoundary>(
                    find.byKey(const Key('capture')),
                  );
                  final image = await boundary.toImage();
                  final bytes = await tester.runAsync(
                    () => image.toByteData(format: ui.ImageByteFormat.png),
                  );
                  File('$output/$name.png')
                    ..parent.createSync(recursive: true)
                    ..writeAsBytesSync(bytes!.buffer.asUint8List());
                  image.dispose();
                }
                await tester.pumpWidget(const SizedBox.shrink());
              } finally {
                semantics.dispose();
              }
            });
          }
        }
      }
    }
  }
  testWidgets(
    'long author and 10000 unbroken characters wrap without truncation',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 700));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final body = 'https://example.test/${'x' * 9979}';
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: SingleChildScrollView(
              child: ConversationMessageBubble(
                outgoing: true,
                author: 'A very long sender name ' * 5,
                body: body,
                timestamp: 'Oct 9, 2026 · 10:26 PM',
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(
        tester.widget<SelectableText>(find.byType(SelectableText)).data,
        body,
      );
      expect(
        tester.getSize(find.byType(DecoratedBox).last).width,
        lessThanOrEqualTo(288),
      );
    },
  );
}
