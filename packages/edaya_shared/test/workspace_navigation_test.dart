import 'dart:async';
import 'package:edaya_shared/edaya_shared.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  test(
    'history windows stop at year start and stale refresh cannot replace data',
    () async {
      final reads = <Map<String, dynamic>>[];
      final responses = <Completer<Map<String, dynamic>>>[];
      final c = SessionHistoryController(
        year: {'id': 'old', 'startDate': '2025-01-01', 'endDate': '2025-02-15'},
        read: (range) {
          reads.add(range);
          final response = Completer<Map<String, dynamic>>();
          responses.add(response);
          return response.future;
        },
      );
      final initial = c.load();
      final fresh = c.refresh();
      responses[1].complete({
        'entries': [
          {'id': 'new', 'kind': 'lesson', 'startsAt': '2025-02-10'},
        ],
        'startDate': reads[1]['startDate'],
        'hasMore': true,
      });
      await fresh;
      responses[0].complete({
        'entries': [
          {'id': 'stale', 'kind': 'lesson', 'startsAt': '2025-02-11'},
        ],
        'startDate': reads[0]['startDate'],
        'hasMore': true,
      });
      await initial;
      expect(c.entries.value.single['id'], 'new');
      final older = c.load();
      expect(reads.last['startDate'], '2025-01-01');
      expect(reads.last['endDate'], '2025-01-15');
      responses.last.complete({
        'entries': [],
        'startDate': '2025-01-01',
        'hasMore': false,
      });
      await older;
      await c.load();
      expect(reads, hasLength(3));
      expect(c.hasMore.value, isFalse);
    },
  );

  for (final width in [320.0, 390.0, 599.0, 600.0, 1024.0]) {
    for (final scale in [1.0, 2.0]) {
      for (final brightness in Brightness.values) {
        testWidgets(
          'feature header and tabs at $width/$scale/$brightness retain labels and scroll',
          (tester) async {
            await tester.binding.setSurfaceSize(Size(width, 844));
            addTearDown(() => tester.binding.setSurfaceSize(null));
            final scroll = ScrollController();
            addTearDown(scroll.dispose);
            final router = GoRouter(
              routes: [
                GoRoute(
                  path: '/',
                  builder: (context, _) => Scaffold(
                    appBar: AppBar(
                      toolbarHeight: WorkspacePageHeading.toolbarHeight(
                        context,
                      ),
                      title: WorkspacePageHeading.forAppBar(
                        context,
                        title: 'Évaluations',
                        picker: WorkspacePickerButton(
                          name:
                              'Alexandra Antoinette / Classe de mathématiques',
                          icon: Icons.person_outline,
                          onPressed: () {},
                        ),
                      ),
                    ),
                    body: WorkspaceTabs(
                      labels: const ['Conversations', 'Notifications'],
                      values: const ['conversations', 'notifications'],
                      children: [
                        ListView(
                          controller: scroll,
                          children: [
                            for (var i = 0; i < 60; i++)
                              ListTile(title: Text('Message $i')),
                          ],
                        ),
                        const Center(child: Text('Notifications list')),
                      ],
                    ),
                  ),
                ),
              ],
            );
            addTearDown(router.dispose);
            await tester.pumpWidget(
              MaterialApp.router(
                theme: ThemeData(brightness: brightness),
                routerConfig: router,
                builder: (_, child) => MediaQuery(
                  data: MediaQueryData(
                    size: Size(width, 844),
                    textScaler: TextScaler.linear(scale),
                  ),
                  child: child!,
                ),
              ),
            );
            await tester.pumpAndSettle();
            final title = find.text('Évaluations');
            final picker = find.byType(WorkspacePickerButton);
            expect(tester.widget<Text>(title).style?.fontSize, 18);
            expect(tester.getSize(picker).height, greaterThanOrEqualTo(48));
            if (scale == 2 && width < 600) {
              expect(
                tester.getTopLeft(picker).dy,
                greaterThanOrEqualTo(tester.getBottomLeft(title).dy),
              );
            }
            scroll.jumpTo(300);
            await tester.ensureVisible(
              find.widgetWithText(Tab, 'Notifications'),
            );
            await tester.pumpAndSettle();
            await tester.tap(find.widgetWithText(Tab, 'Notifications'));
            await tester.pumpAndSettle();
            expect(
              router.routeInformationProvider.value.uri.queryParameters['tab'],
              'notifications',
            );
            await tester.ensureVisible(
              find.widgetWithText(Tab, 'Conversations'),
            );
            await tester.pumpAndSettle();
            await tester.tap(find.widgetWithText(Tab, 'Conversations'));
            await tester.pumpAndSettle();
            expect(scroll.offset, 300);
            expect(tester.takeException(), isNull);
          },
        );
      }
    }
  }
}
