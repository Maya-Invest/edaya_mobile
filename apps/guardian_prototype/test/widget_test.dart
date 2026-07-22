import 'package:flutter_test/flutter_test.dart';
import 'package:guardian_prototype/main.dart';
import 'package:guardian_prototype/mock/mock_store.dart';

void main() {
  testWidgets('prototype app builds', (tester) async {
    final store = MockStore();
    await tester.pumpWidget(GuardianPrototypeApp(store: store));
    expect(find.text('edaya'), findsOneWidget);
  });
}
