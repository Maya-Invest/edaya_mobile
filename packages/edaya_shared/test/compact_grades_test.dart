import 'package:edaya_shared/edaya_shared.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    await (FontLoader('Inter')..addFont(
          rootBundle.load(
            'packages/edaya_shared/assets/fonts/Inter-Regular.ttf',
          ),
        ))
        .load();
  });
  test(
    'nine demo bands include their lower boundary and the scale maximum',
    () {
      const bands = [
        (0, 'TF', 'Très faible'),
        (4, 'F', 'Faible'),
        (6, 'TI', 'Très insuffisant'),
        (8, 'I', 'Insuffisant'),
        (10, 'P', 'Passable'),
        (12, 'AB', 'Assez bien'),
        (14, 'B', 'Bien'),
        (16, 'TB', 'Très bien'),
        (18, 'EX', 'Excellent'),
      ];
      for (var i = 0; i < bands.length; i++) {
        final (start, code, label) = bands[i];
        expect(demoGrade(start)['mention'], {'code': code, 'label': label});
        final end = i + 1 < bands.length ? bands[i + 1].$1 - .01 : 20;
        expect(demoGrade(end)['mention']['code'], code);
      }
      expect(demoGrade(15.996)['mention']['label'], 'Très bien');
    },
  );
  test('ranks follow French and English ordinal conventions', () {
    for (final (rank, suffix) in [
      (1, 'st'),
      (2, 'nd'),
      (3, 'rd'),
      (4, 'th'),
      (11, 'th'),
      (12, 'th'),
      (13, 'th'),
      (21, 'st'),
      (22, 'nd'),
      (23, 'rd'),
      (111, 'th'),
    ]) {
      expect(compactRank(rank, 120, 'en'), '$rank$suffix/120');
      expect(
        compactRank(rank, 120, 'fr'),
        '${rank}${rank == 1 ? 'er' : 'e'}/120',
      );
    }
  });
  testWidgets('GradeValue separates the mention label from its code', (
    tester,
  ) async {
    Future<void> show(String value, Map grading) => tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: GradeValue(value, {'grading': grading}, showRank: false),
        ),
      ),
    );
    await show('16 / 20 · A', {
      'mention': {'label': 'Excellent', 'code': 'A'},
    });
    expect(find.text('16 / 20'), findsOneWidget);
    expect(find.text('Excellent'), findsOneWidget);
    expect(find.text('16 / 20 · A'), findsNothing);
    await show('16 / 20', {});
    expect(find.text('16 / 20'), findsOneWidget);
    expect(find.text('Excellent'), findsNothing);
  });
  testWidgets(
    'numeric, unavailable and mention grades keep their official meaning',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('en'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: const SizedBox(),
        ),
      );
      final context = tester.element(find.byType(SizedBox).last);
      String visual(Map record) => compactGradeSummary(context, record).visual;
      expect(
        visual({
          'originalEntry': {
            'kind': 'mention',
            'code': 'A',
            'label': 'Excellent',
          },
          'grading': {'reportedValue': 4},
        }),
        'A · Excellent',
      );
      expect(visual({'score': 0, 'maxScore': 20, 'rank': 1}), '0/20');
      expect(visual({'rank': 0, 'participantCount': 3}), '');
      expect(visual({}), '');
      expect(visual({'designation': 'absent', 'score': 0}), 'Absent');
    },
  );
  testWidgets(
    'grade rows wrap at enlarged text and retain centered accessible menus',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      for (final width in [320, 390, 393, 599, 600, 1024]) {
        tester.view.physicalSize = Size(width.toDouble(), 852);
        for (final language in ['fr', 'en']) {
          for (final dark in [false, true]) {
            for (final scale in [1.0, 2.0]) {
              final long = scale > 1;
              final name = long
                  ? 'Amina Koné N’Guessan Diabaté Kouamé'
                  : 'Amina Koné';
              final grade = demoGrade(16);
              if (long)
                grade['mention'] = {
                  'code': 'TB',
                  'label': 'Très bonne maîtrise des compétences évaluées',
                };
              await tester.pumpWidget(
                MaterialApp(
                  locale: Locale(language),
                  theme: ThemeData(
                    brightness: dark ? Brightness.dark : Brightness.light,
                    fontFamily: 'Inter',
                  ),
                  supportedLocales: AppLocalizations.supportedLocales,
                  localizationsDelegates:
                      AppLocalizations.localizationsDelegates,
                  builder: (context, child) => MediaQuery(
                    data: MediaQuery.of(
                      context,
                    ).copyWith(textScaler: TextScaler.linear(scale)),
                    child: child!,
                  ),
                  home: Scaffold(
                    body: ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        GradeRecordRow(
                          title: name,
                          result: {
                            'grading': grade,
                            'rank': 1,
                            'participantCount': 3,
                          },
                          details: const Text('Coefficient 2'),
                        ),
                      ],
                    ),
                  ),
                ),
              );
              await tester.pumpAndSettle();
              final menu = find.byType(PopupMenuButton<String>);
              final title = find.text(name);
              final ordinal = language == 'fr' ? '1er/3' : '1st/3';
              final line = find.textContaining(ordinal);
              final words = language == 'fr' ? 'Rang 1 sur 3' : 'Rank 1 of 3';
              expect(tester.widget<Text>(line).semanticsLabel, contains(words));
              expect(tester.getSize(menu).width, greaterThanOrEqualTo(48));
              expect(tester.getSize(menu).height, greaterThanOrEqualTo(48));
              final textMid =
                  (tester.getTopLeft(title).dy +
                      tester.getBottomLeft(line).dy) /
                  2;
              expect(tester.getCenter(menu).dy, closeTo(textMid, 1));
              if (!long) {
                expect(
                  tester.widget<Text>(line).data,
                  language == 'fr'
                      ? '16,00/20 · 1er/3 · Très bien'
                      : '16.00/20 · 1st/3 · Très bien',
                );
                final para = tester.renderObject<RenderParagraph>(
                  find.descendant(of: line, matching: find.byType(RichText)),
                );
                expect(
                  para
                      .getBoxesForSelection(
                        TextSelection(
                          baseOffset: 0,
                          extentOffset: para.text.toPlainText().length,
                        ),
                      )
                      .map((b) => b.top)
                      .toSet(),
                  hasLength(1),
                );
              }
              expect(tester.takeException(), isNull);
            }
          }
        }
      }
      await tester.tap(find.byType(PopupMenuButton<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('View details'));
      await tester.pumpAndSettle();
      expect(find.text('Coefficient 2'), findsOneWidget);
    },
  );
}
