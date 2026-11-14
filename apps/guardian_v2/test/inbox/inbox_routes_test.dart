import 'package:edaya_guardian_v2/features/inbox/inbox_routes.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  const deliveryId =
      'delivery:v2:sch:assessment.result_recorded%3Ares-1:login:guardian:g1';

  test('inboxMessagePath round-trips percent-encoded delivery ids', () {
    final encoded = inboxMessagePath(deliveryId);
    expect(encoded, isNot(contains(deliveryId)));
    expect(encoded, contains('%253A'));
    expect(Uri.decodeComponent(encoded.split('/').last), deliveryId);
  });

  testWidgets('GoRouter preserves encoded delivery ids in path parameters', (
    tester,
  ) async {
    String? captured;
    final router = GoRouter(
      initialLocation: inboxMessagePath(deliveryId),
      routes: [
        GoRoute(
          path: '/inbox/message/:id',
          builder: (context, state) {
            captured = state.pathParameters['id'];
            return const SizedBox();
          },
        ),
      ],
    );

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    expect(captured, deliveryId);
  });
}
