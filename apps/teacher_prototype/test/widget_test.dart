import 'package:edaya_shared/edaya_shared.dart' hide LoginPage;
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:levit_flutter/levit_flutter.dart';
import 'package:teacher_prototype/app/prototype_app_root.dart';
import 'package:teacher_prototype/features/login/login_page.dart';
import 'package:teacher_prototype/mock/mock_store.dart';

void main() {
  testWidgets('boots login for signed-out store', (tester) async {
    Levit.enableAutoLinking();
    await initializeDateFormatting('fr_FR');
    await tester.pumpWidget(PrototypeAppRoot(store: MockStore()));
    await tester.pumpAndSettle();
    expect(find.byType(LoginPage), findsOneWidget);
    expect(find.byType(EdayaBrandLogo), findsOneWidget);
  });
}
