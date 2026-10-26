import 'package:edaya_api_client/edaya_api_client.dart';
import 'package:edaya_auth/edaya_auth.dart';
import 'package:edaya_shared/src/features/account/account_profile_page.dart';
import 'package:edaya_shared/src/features/auth/app_session_controller.dart';
import 'package:edaya_shared/src/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:levit_flutter/levit_flutter.dart';

class GuardianSession implements AppSessionController {
  @override
  final grants = LxVar<EffectiveGrantsResponse?>(
    const EffectiveGrantsResponse(
      kind: 'guardian',
      actorId: 'guardian',
      schoolId: 'school',
      assuranceLevel: 'standard',
      grants: [],
    ),
  );
  @override
  final user = LxVar<AuthUser?>(null);
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class GuardianTransport implements Transport {
  final writes = <Map<String, dynamic>>[];
  @override
  Future<T> request<T>(
    String method,
    String path, {
    TransportRequestOptions? options,
  }) async {
    if (method == 'GET')
      return <String, dynamic>{
            'id': 'guardian',
            'firstName': 'Ada',
            'lastName': 'Parent',
            'phone': '+22501020304',
            'alternativePhone': '+22505060708',
            'emailNotificationsEnabled': false,
            'smsNotificationsEnabled': false,
            'pushNotificationsEnabled': false,
          }
          as T;
    writes.add(Map<String, dynamic>.from(options!.body as Map));
    throw ApiError(409, {});
  }
}

void main() {
  for (final language in ['en', 'fr']) {
    testWidgets(
      'guardian $language narrow profile preserves draft on failure and supports dirty dismissal',
      (tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final session = GuardianSession();
        final transport = GuardianTransport();
        await tester.pumpWidget(
          LScope(
            name: 'guardian-$language',
            child: MaterialApp(
              locale: Locale(language),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: Builder(
                builder: (context) => Scaffold(
                  body: TextButton(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => AccountProfilePage(
                          session: session,
                          schoolClient: () => createSchoolClient(transport),
                        ),
                      ),
                    ),
                    child: const Text('Open profile'),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('Open profile'));
        await tester.pumpAndSettle();
        final mainLabel = language == 'fr'
            ? 'Téléphone principal'
            : 'Main phone';
        final phone = find.byWidgetPredicate(
          (widget) =>
              widget is TextField && widget.decoration?.labelText == mainLabel,
        );
        await tester.ensureVisible(phone);
        await tester.enterText(phone, '+22509999999');
        await tester.pump();
        final save = find.byType(FilledButton);
        await tester.ensureVisible(save);
        await tester.tap(save);
        await tester.pumpAndSettle();
        expect(transport.writes, hasLength(1));
        expect(transport.writes.single['smsNotificationsEnabled'], isFalse);
        await tester.ensureVisible(phone);
        expect(
          (tester.widget(phone) as TextField).controller!.text,
          '+22509999999',
        );
        await tester.tap(find.byType(BackButton));
        await tester.pumpAndSettle();
        expect(find.byType(AlertDialog), findsOneWidget);
        final cancel = language == 'fr' ? 'Annuler' : 'Cancel';
        await tester.tap(find.text(cancel));
        await tester.pumpAndSettle();
        expect(find.byType(AccountProfilePage), findsOneWidget);
        await tester.tap(find.byType(BackButton));
        await tester.pumpAndSettle();
        final discard = language == 'fr' ? 'Abandonner' : 'Discard';
        await tester.tap(find.text(discard));
        await tester.pumpAndSettle();
        expect(find.text('Open profile'), findsOneWidget);
        expect(find.byType(AccountProfilePage), findsNothing);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }
}
