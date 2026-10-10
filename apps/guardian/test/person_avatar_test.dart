import 'package:edaya_guardian/design/components/person_avatar.dart';
import 'package:edaya_shared/edaya_shared.dart' as shared;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('portrait wrapper uses the protected-photo loader', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: PersonAvatar(
          initials: 'TC',
          photoUrl: '/core/files/pending-photo/content',
          radius: 48,
        ),
      ),
    );
    await tester.pumpAndSettle();
    final avatar = tester.widget<shared.PersonAvatar>(
      find.byType(shared.PersonAvatar),
    );
    expect(avatar.photoUrl, '/core/files/pending-photo/content');
    expect(avatar.radius, 48);
    expect(find.text('TC'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
