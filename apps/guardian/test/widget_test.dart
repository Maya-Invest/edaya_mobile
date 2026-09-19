import 'package:edaya_guardian/app/prototype_app_root.dart';
import 'package:edaya_shared/edaya_shared.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:levit_flutter/levit_flutter.dart';

void main() {
  setUpAll(() async {
    Levit.enableAutoLinking();
    await initializeDateFormatting('fr_FR');
  });

  testWidgets('prototype app builds', (tester) async {
    await tester.pumpWidget(const PrototypeAppRoot());
    await tester.pump();
    expect(find.byType(MaterialApp), findsOneWidget);
    expect(find.byType(EdayaStartupScreen), findsOneWidget);
    expect(find.byType(EdayaBrandLogo), findsOneWidget);
  });
}
