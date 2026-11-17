import 'dart:convert';
import 'package:intl/date_symbol_data_local.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'package:edaya_auth/edaya_auth.dart';
import 'package:edaya_shared/edaya_shared.dart';
import 'package:edaya_shared/src/features/auth/localized_auth_error.dart';
import 'package:edaya_shared/src/features/settings/app_settings_models.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  for (final language in [LanguagePreference.en, LanguagePreference.fr]) {
    final french = language == LanguagePreference.fr;
    final locale = Locale(language.name);
    Future<void> setUpLocale() async {
      await initializeDateFormatting();
      SharedPreferences.setMockInitialValues({
        'edaya_settings_language': language.name,
      });
      await AppSettingsController.preload();
    }

    test(
      '${language.name} formats counts, grades, clock, documents and auth failures',
      () async {
        await setUpLocale();
        final tr = systemL10n();
        expect(
          tr.sessionsToday(1),
          french ? '1 séance aujourd’hui' : '1 session today',
        );
        expect(
          tr.availableMarks(1),
          french ? '1 note disponible' : '1 mark available',
        );
        expect(
          tr.overdueChargesCount(2),
          french ? '2 lignes de frais en retard' : '2 overdue charges',
        );
        expect(
          tr.openSurveyCount(0),
          french ? '0 questionnaires ouverts' : '0 open surveys',
        );
        expect(
          formatCalculatedGrade(12.5, null),
          french ? '12,50 / 20' : '12.50 / 20',
        );
        expect(
          AppDateFormatting.clockFormat(
            TimeFormatPreference.hour12,
            tr.localeName,
          ).format(DateTime(2026, 2, 3, 15, 30)),
          '3:30 PM',
        );
        expect(
          leftoverFamilyPaperLabel('withdrawal-certificate.v1', tr),
          french ? 'Certificat de radiation' : 'School withdrawal certificate',
        );
        expect(
          localizedAuthError(
            const AuthError(message: 'Invalid or expired verification code.'),
            tr.signInFailed,
          ),
          french ? 'Code invalide ou expiré.' : 'Invalid or expired code.',
        );
        expect(
          localizedAuthError(
            const AuthError(message: 'server diagnostics'),
            tr.signInFailed,
          ),
          tr.signInFailed,
        );
        expect(
          supportedAppLocale(
            const Locale('es'),
            AppLocalizations.supportedLocales,
          ),
          const Locale('en'),
        );
      },
    );

    testWidgets('${language.name} displays the offline edit and portrait limit', (
      tester,
    ) async {
      await setUpLocale();
      Widget app(Widget child) => MaterialApp(
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: child),
      );
      await tester.pumpWidget(
        app(
          TeacherOutboxSyncSummaryCard(
            summary: const TeacherOutboxSummary(pendingCount: 0),
            isSyncing: false,
            conflicts: [
              TeacherOutboxEntry(
                id: 'row',
                idempotencyKey: 'row',
                kind: TeacherOutboxKind.mark,
                state: TeacherOutboxState.conflict,
                attemptCount: 1,
                createdAt: DateTime(2026),
                updatedAt: DateTime(2026),
                payload: const {
                  'designation': 'exempt',
                  'studentId': 'student-1',
                  'studentName': 'Ada',
                },
              ),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text(french ? 'Note · Ada' : 'Score · Ada'), findsOneWidget);
      expect(find.text(french ? 'Dispensé' : 'Exempt'), findsOneWidget);
      final png = base64Decode(
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+jRZkAAAAASUVORK5CYII=',
      );
      await tester.pumpWidget(app(ProfilePhotoCropPage(source: png)));
      await tester.pumpAndSettle();
      expect(
        find.textContaining(french ? '1 Mio maximum' : '1 MiB or smaller'),
        findsOneWidget,
      );
    });

    testWidgets(
      '${language.name} sends localized descriptions to Android notifications',
      (tester) async {
        await setUpLocale();
        AndroidFlutterLocalNotificationsPlugin.registerWith();
        const channel = MethodChannel(
          'dexterous.com/flutter/local_notifications',
        );
        final messenger = tester.binding.defaultBinaryMessenger;
        Map? details;
        messenger.setMockMethodCallHandler(channel, (call) async {
          if (call.method == 'show')
            details = call.arguments['platformSpecifics'] as Map;
          return null;
        });
        addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
        for (final config in [
          PushNotificationConfigs.guardian,
          PushNotificationConfigs.teacher,
        ]) {
          await displayEdayaPushNotification(
            const RemoteMessage(data: {'title': 'EDaya'}),
            config,
          );
          final family = config.appId == 'guardian';
          expect(
            details?['channelDescription'],
            french
                ? 'Actualités et alertes de l’établissement pour ${family ? 'les familles' : 'le personnel'}'
                : 'School updates and alerts for ${family ? 'families' : 'staff'}',
          );
        }
      },
      variant: TargetPlatformVariant.only(TargetPlatform.android),
    );
  }
}
