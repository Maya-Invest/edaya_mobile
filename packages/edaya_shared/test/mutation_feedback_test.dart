import 'package:edaya_api_client/edaya_api_client.dart';
import 'package:edaya_shared/src/api/mutation_feedback.dart';
import 'package:edaya_shared/src/l10n/app_localizations_en.dart';
import 'package:edaya_shared/src/l10n/app_localizations_fr.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'conflicts use localized reload guidance; other feature errors survive',
    () {
      for (final l10n in [AppLocalizationsEn(), AppLocalizationsFr()]) {
        expect(
          mutationFailureMessage(
            ApiError(409, {'message': 'private-receipt'}),
            'fallback',
            l10n: l10n,
          ),
          l10n.mutationConflict,
        );
        expect(
          mutationFailureMessage(
            ApiError(403, {}),
            'Access denied',
            l10n: l10n,
          ),
          'Access denied',
        );
        expect(
          mutationFailureMessage(StateError('offline'), 'Offline', l10n: l10n),
          'Offline',
        );
      }
    },
  );

  test(
    'a failed display refresh reports saved state and does not throw or retry',
    () async {
      var refreshes = 0;
      final warnings = <String>[];
      final l10n = AppLocalizationsEn();
      await refreshAfterMutation(
        () async {
          refreshes++;
          throw ApiError(503, {});
        },
        showWarning: warnings.add,
        l10n: l10n,
      );
      expect(refreshes, 1);
      expect(warnings, [l10n.mutationSavedRefreshFailed]);
    },
  );

  test('successful display refresh has no warning', () async {
    final warnings = <String>[];
    var refreshed = false;
    await refreshAfterMutation(() async {
      refreshed = true;
    }, showWarning: warnings.add);
    expect(refreshed, isTrue);
    expect(warnings, isEmpty);
  });
}
