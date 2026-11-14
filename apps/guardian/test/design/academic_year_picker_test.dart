import 'package:edaya_guardian_v2/design/components/academic_year_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('year picker uses overlay menu beside the closed control', (
    tester,
  ) async {
    String selected = '2026 — 2027';
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) {
              return AcademicYearPicker(
                selectedYear: selected,
                years: const ['2026 — 2027', '2025 — 2026'],
                onSelected: (year) => setState(() => selected = year),
              );
            },
          ),
        ),
      ),
    );

    expect(find.byType(MenuAnchor), findsOneWidget);
    expect(find.text('2026 — 2027'), findsOneWidget);
    expect(find.text('2025 — 2026'), findsNothing);

    await tester.tap(find.byType(TextButton));
    await tester.pumpAndSettle();
    expect(find.text('2025 — 2026'), findsOneWidget);

    await tester.tap(find.text('2025 — 2026'));
    await tester.pumpAndSettle();
    expect(find.text('2025 — 2026'), findsOneWidget);
    expect(find.text('2026 — 2027'), findsNothing);
  });
}
