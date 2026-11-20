import '../../l10n/app_localizations.dart';

String timetableSessionKindLabel(AppLocalizations l10n, String kind) {
  return switch (kind) {
    'activity' => l10n.timetableSessionKindActivity,
    'assessment' => l10n.timetableSessionKindAssessment,
    _ => l10n.timetableSessionKindLesson,
  };
}
