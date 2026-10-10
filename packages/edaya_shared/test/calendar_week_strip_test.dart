import 'package:edaya_shared/edaya_shared.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final dark in [false, true]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets(
        'week remains accessible at ${scale}x in ${dark ? "dark" : "light"} mode',
        (tester) async {
          final semantics = tester.ensureSemantics();
          try {
            final days = List.generate(7, (i) => DateTime(2026, 10, 5 + i));
            DateTime? selected;
            var shifts = 0;
            await tester.pumpWidget(
              MaterialApp(
                theme: dark ? AppTheme.dark : AppTheme.light,
                localizationsDelegates: AppLocalizations.localizationsDelegates,
                supportedLocales: AppLocalizations.supportedLocales,
                home: Scaffold(
                  body: MediaQuery(
                    data: MediaQueryData(textScaler: TextScaler.linear(scale)),
                    child: Align(
                      alignment: Alignment.topCenter,
                      child: SizedBox(
                        width: 320,
                        child: CalendarWeekStrip(
                          days: days,
                          selected: days.first,
                          onSelected: (value) => selected = value,
                          onPreviousWeek: () => shifts--,
                          onNextWeek: () => shifts++,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
            await tester.pumpAndSettle();
            await expectLater(
              tester,
              meetsGuideline(androidTapTargetGuideline),
            );
            await expectLater(
              tester,
              meetsGuideline(labeledTapTargetGuideline),
            );
            await tester.tap(find.byTooltip('Next week'));
            expect(shifts, 1);
            await tester.tap(find.byType(FilledButton).first);
            expect(selected, days.first);
            await tester.drag(
              find.byType(SingleChildScrollView),
              const Offset(-1000, 0),
            );
            await tester.pumpAndSettle();
            await tester.tap(find.byType(FilledButton).last);
            expect(selected, days.last);
            expect(tester.takeException(), isNull);
          } finally {
            semantics.dispose();
          }
        },
      );
    }
  }
}
