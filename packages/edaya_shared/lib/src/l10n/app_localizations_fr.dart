// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for French (`fr`).
class AppLocalizationsFr extends AppLocalizations {
  AppLocalizationsFr([String locale = 'fr']) : super(locale);

  @override
  String get appTitleGuardian => 'Edaya';

  @override
  String get appTitleTeacher => 'Edaya Staff';

  @override
  String get accountTitle => 'Compte';

  @override
  String get accountProfileTitle => 'Profil de contact';

  @override
  String get accountProfileDescription =>
      'Mettez à jour le nom et les coordonnées visibles par l\'établissement.';

  @override
  String accountProfileLoginEmail(String email) {
    return 'E-mail de connexion : $email';
  }

  @override
  String get accountProfileUnavailable =>
      'Votre profil scolaire n\'est pas disponible.';

  @override
  String accountProfileLoadError(String error) {
    return 'Impossible de charger votre profil. $error';
  }

  @override
  String accountProfileSaveError(String error) {
    return 'Impossible d\'enregistrer votre profil. $error';
  }

  @override
  String get accountProfileUpdateSuccess => 'Profil mis à jour.';

  @override
  String get firstNameLabel => 'Prénom';

  @override
  String get lastNameLabel => 'Nom';

  @override
  String get phoneLabel => 'Téléphone';

  @override
  String get signingOut => 'Déconnexion…';

  @override
  String get signOut => 'Se déconnecter';

  @override
  String get nothingToShowYet => 'Rien à afficher pour le moment.';

  @override
  String get somethingWentWrong => 'Une erreur s\'est produite.';

  @override
  String get retry => 'Réessayer';

  @override
  String get signInTitle => 'Connexion';

  @override
  String get signInButton => 'Se connecter';

  @override
  String get emailLabel => 'E-mail';

  @override
  String get passwordLabel => 'Mot de passe';

  @override
  String get signInFailed => 'Échec de la connexion';

  @override
  String signedInSchoolSessionUnavailable(String error) {
    return 'Connecté, mais la session scolaire est indisponible : $error';
  }

  @override
  String get apiUrlCannotBeEmpty => 'L\'URL de l\'API ne peut pas être vide';

  @override
  String get enterValidApiUrl => 'Saisissez une URL d\'API valide';

  @override
  String get restartRequired => 'Redémarrage requis';

  @override
  String apiUrlUpdatedReloadPage(String url) {
    return 'URL de l\'API mise à jour vers $url. Rechargez la page pour vous connecter au nouveau serveur.';
  }

  @override
  String apiUrlUpdatedRestartApp(String url) {
    return 'URL de l\'API mise à jour vers $url. Redémarrez l\'application pour vous connecter au nouveau serveur.';
  }

  @override
  String get restartApp => 'Redémarrer l\'application';

  @override
  String get ok => 'OK';

  @override
  String get help => 'Aide';

  @override
  String currentApiUrl(String url) {
    return 'Actuelle : $url';
  }

  @override
  String get usingSavedDevOverride =>
      'Utilisation d\'une surcharge de développement enregistrée';

  @override
  String get apiBaseUrlLabel => 'URL de base de l\'API';

  @override
  String get presetLocalhost => 'Localhost';

  @override
  String get presetAndroidEmulator => 'Émulateur Android';

  @override
  String get presetStaging => 'Staging';

  @override
  String get presetProduction => 'Production';

  @override
  String get presetLanEditIp => 'LAN (modifier l\'IP)';

  @override
  String get resetDefault => 'Réinitialiser';

  @override
  String get save => 'Enregistrer';

  @override
  String get developerSettings => 'Paramètres développeur';

  @override
  String get loginSubtitleGuardianDev =>
      'Utilisez les identifiants de développement tuteur pour tester l\'API locale.';

  @override
  String get loginSubtitleStaffDev =>
      'Utilisez les identifiants de développement personnel pour tester l\'API locale.';

  @override
  String get missingSessionDetailsRouteData =>
      'Données de route des détails de séance manquantes.';

  @override
  String get missingGradeDetailsRouteData =>
      'Données de route des détails de note manquantes.';

  @override
  String get missingReportCardRouteData =>
      'Données de route du bulletin manquantes.';

  @override
  String get missingPaymentDetailsRouteData =>
      'Données de route des détails de paiement manquantes.';

  @override
  String get missingMessageDetailsRouteData =>
      'Données de route des détails du message manquantes.';

  @override
  String get missingAttendanceFlowRouteData =>
      'Données de route du flux de présence manquantes.';

  @override
  String get missingMarksEntryRouteData =>
      'Données de route de saisie des notes manquantes.';

  @override
  String get signedInNoGuardianProfile =>
      'Connecté, mais aucun profil tuteur/personnel lié. Exécutez : bun seed --scope auth:link';

  @override
  String get signedInNoStaffProfile =>
      'Connecté, mais aucun profil personnel lié. Exécutez : bun seed --scope auth:link';

  @override
  String get signedInNoTeacherProfile =>
      'Connecté, mais aucun profil enseignant lié. Exécutez : bun seed --scope auth:link';

  @override
  String get accountNotLinkedToStaff =>
      'Ce compte n\'est pas lié à un profil personnel.';

  @override
  String get accountNotLinkedToTeacher =>
      'Ce compte n\'est pas lié à un profil enseignant.';

  @override
  String get navHome => 'Accueil';

  @override
  String get navAgenda => 'Agenda';

  @override
  String get navClasses => 'Classes';

  @override
  String get navCalendar => 'Calendrier';

  @override
  String get navAcademic => 'Scolarité';

  @override
  String get navFees => 'Frais';

  @override
  String get navInbox => 'Boîte de réception';

  @override
  String get navEvaluations => 'Évaluations';

  @override
  String get navTeaching => 'Enseignement';

  @override
  String get navReportCards => 'Bulletins';

  @override
  String get teachingTitle => 'Enseignement';

  @override
  String get reportCardsTitle => 'Bulletins';

  @override
  String get teachingSelectClass => 'Classe';

  @override
  String get teachingSelectSubject => 'Matière';

  @override
  String get teachingProgressTab => 'Progression';

  @override
  String get teachingLogbookTab => 'Cahier';

  @override
  String get noTeachingLogEntries =>
      'Aucune entrée de cahier pour cette matière.';

  @override
  String couldNotLoadTeachingData(String error) {
    return 'Impossible de charger les données d\'enseignement : $error';
  }

  @override
  String couldNotLoadReportCards(String error) {
    return 'Impossible de charger les bulletins : $error';
  }

  @override
  String get reportCardClassNoResults =>
      'Aucun bulletin généré pour cette période.';

  @override
  String reportCardClassProgress(int filled, int total) {
    return '$filled / $total commentaires renseignés';
  }

  @override
  String get reportCardRosterComingSoon =>
      'Liste des élèves bientôt disponible.';

  @override
  String get missingReportCardRosterRouteData =>
      'Données de route de la liste des bulletins manquantes.';

  @override
  String couldNotLoadReportCardRoster(String error) {
    return 'Impossible de charger la liste des bulletins : $error';
  }

  @override
  String couldNotLoadReportCardComments(String error) {
    return 'Impossible de charger les commentaires du bulletin : $error';
  }

  @override
  String couldNotSaveReportCardComment(String error) {
    return 'Impossible d\'enregistrer le commentaire du bulletin : $error';
  }

  @override
  String get reportCardCommentsTitle => 'Commentaires du bulletin';

  @override
  String get reportCardCommentHint => 'Saisissez votre commentaire';

  @override
  String get reportCardCommentsReadOnly =>
      'Ce bulletin est publié et ne peut pas être modifié.';

  @override
  String get reportCardCommentNoEditableFields =>
      'Aucun champ de commentaire n\'est disponible pour votre rôle sur ce bulletin.';

  @override
  String subjectComment(String subject) {
    return 'Commentaire $subject';
  }

  @override
  String get reportCardStatusDraft => 'Brouillon';

  @override
  String get reportCardStatusPublished => 'Publié';

  @override
  String get tooltipAccount => 'Compte';

  @override
  String get loading => 'Chargement…';

  @override
  String get selectAStudent => 'Sélectionner un élève';

  @override
  String get notEnrolled => 'Non inscrit';

  @override
  String get schoolYear => 'Année scolaire';

  @override
  String get tooltipMyStudents => 'Mes élèves';

  @override
  String get unknownUser => 'Utilisateur inconnu';

  @override
  String get noAcademicYearsAvailable => 'Aucune année scolaire disponible.';

  @override
  String get activeYear => 'Année active';

  @override
  String couldNotLoadAcademicYears(String error) {
    return 'Impossible de charger les années scolaires : $error';
  }

  @override
  String couldNotLoadStudentContext(String error) {
    return 'Impossible de charger le contexte élève : $error';
  }

  @override
  String couldNotLoadEnrollment(String error) {
    return 'Impossible de charger l\'inscription : $error';
  }

  @override
  String get myStudents => 'Mes élèves';

  @override
  String get noLinkedStudentsFound => 'Aucun élève lié trouvé.';

  @override
  String matriculeLabel(String matricule) {
    return 'Matricule : $matricule';
  }

  @override
  String statusLabel(String status) {
    return 'Statut : $status';
  }

  @override
  String couldNotLoadLinkedStudents(String error) {
    return 'Impossible de charger les élèves liés : $error';
  }

  @override
  String get calendarViewTimetable => 'Emploi du temps';

  @override
  String get calendarViewEvents => 'Événements';

  @override
  String get allAttendance => 'Toutes les présences';

  @override
  String get selectStudentToViewCalendar =>
      'Sélectionnez un élève pour afficher le calendrier.';

  @override
  String get studentNotEnrolledForYear =>
      'Cet élève n\'est pas inscrit pour l\'année scolaire sélectionnée.';

  @override
  String get noClassesScheduledForDay => 'Aucun cours prévu ce jour.';

  @override
  String get noSchoolEventsForPeriod =>
      'Aucun événement scolaire pour cette période.';

  @override
  String couldNotLoadCalendar(String error) {
    return 'Impossible de charger le calendrier : $error';
  }

  @override
  String couldNotLoadSessionDetails(String error) {
    return 'Impossible de charger les détails de la séance : $error';
  }

  @override
  String couldNotLoadAttendance(String error) {
    return 'Impossible de charger les présences : $error';
  }

  @override
  String get attendance => 'Présence';

  @override
  String get timetableSessionKindLesson => 'Cours';

  @override
  String get timetableSessionKindActivity => 'Activité';

  @override
  String get timetableSessionKindAssessment => 'Évaluation';

  @override
  String get noAttendanceRecorded => 'Aucune présence enregistrée.';

  @override
  String get classLogbook => 'Cahier de classe';

  @override
  String get noLogbookEntryForSession =>
      'Aucune entrée de cahier pour cette séance.';

  @override
  String get homeworkLabel => 'Devoirs';

  @override
  String homeworkValue(String homework) {
    return 'Devoirs : $homework';
  }

  @override
  String progressPercent(int percent) {
    return 'Progression : $percent %';
  }

  @override
  String get noAttendanceRecordsForStudent =>
      'Aucun enregistrement de présence pour cet élève.';

  @override
  String get tooltipPreviousWeek => 'Semaine précédente';

  @override
  String get tooltipNextWeek => 'Semaine suivante';

  @override
  String get dayLetterMon => 'L';

  @override
  String get dayLetterTue => 'M';

  @override
  String get dayLetterWed => 'M';

  @override
  String get dayLetterThu => 'J';

  @override
  String get dayLetterFri => 'V';

  @override
  String get dayLetterSat => 'S';

  @override
  String get dayLetterSun => 'D';

  @override
  String get academicViewGrades => 'Notes';

  @override
  String get academicViewCurriculum => 'Programme';

  @override
  String get academicViewReports => 'Bulletins';

  @override
  String get allPeriods => 'Toutes les périodes';

  @override
  String get selectStudentToViewAcademic =>
      'Sélectionnez un élève pour afficher les informations scolaires.';

  @override
  String get noGradesForPeriod => 'Aucune note enregistrée pour cette période.';

  @override
  String get noCurriculumProgressYet =>
      'Aucune progression de programme disponible pour le moment.';

  @override
  String get noReportCardsYet => 'Aucun bulletin publié pour le moment.';

  @override
  String couldNotLoadAcademicData(String error) {
    return 'Impossible de charger les données scolaires : $error';
  }

  @override
  String couldNotLoadReportCard(String error) {
    return 'Impossible de charger le bulletin : $error';
  }

  @override
  String get subjectFallback => 'Matière';

  @override
  String get periodFallback => 'Période';

  @override
  String get unitFallback => 'Unité';

  @override
  String gradePeriodCoefficient(String periodName, String coefficient) {
    return '$periodName · Coefficient $coefficient';
  }

  @override
  String get score => 'Note';

  @override
  String get notGradedYet => 'Pas encore noté';

  @override
  String get notes => 'Remarques';

  @override
  String get average => 'Moyenne';

  @override
  String get scoreOutOfTwenty => '/ 20';

  @override
  String get graded => 'Noté';

  @override
  String get pending => 'En attente';

  @override
  String assessmentCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count évaluations',
      one: '1 évaluation',
    );
    return '$_temp0';
  }

  @override
  String subjectAverage(String average) {
    return 'Moyenne $average / 20';
  }

  @override
  String get noScoreDash => '—';

  @override
  String percentComplete(int percent) {
    return '$percent % terminé';
  }

  @override
  String get noProgrammeUnitsTracked =>
      'Aucune unité de programme suivie pour le moment.';

  @override
  String get publishedReportCard => 'Bulletin publié';

  @override
  String publishedOn(String date) {
    return 'Publié le $date';
  }

  @override
  String scoreOutOfTwentyValue(String average) {
    return '$average / 20';
  }

  @override
  String rankLabel(int rank, int classSize) {
    return 'Rang $rank/$classSize';
  }

  @override
  String get reportCardNotFound => 'Bulletin introuvable.';

  @override
  String overallAverage(String average) {
    return 'Moyenne générale : $average / 20';
  }

  @override
  String classRank(int rank, int classSize) {
    return 'Rang dans la classe : $rank/$classSize';
  }

  @override
  String get homeroomComment => 'Commentaire du professeur principal';

  @override
  String get principalComment => 'Commentaire du chef d\'établissement';

  @override
  String get feeLinesSection => 'Lignes de frais';

  @override
  String get noFeeLinesForYear =>
      'Aucune ligne de frais pour cette année scolaire.';

  @override
  String get paymentsSection => 'Paiements';

  @override
  String get noPaymentsRecordedYet =>
      'Aucun paiement enregistré pour le moment.';

  @override
  String get selectStudentToViewFees =>
      'Sélectionnez un élève pour afficher les frais et paiements.';

  @override
  String get noFeesOrPaymentsForYear =>
      'Aucune ligne de frais ni paiement pour l\'année scolaire sélectionnée.';

  @override
  String get schoolFee => 'Frais scolaires';

  @override
  String couldNotLoadFees(String error) {
    return 'Impossible de charger les frais : $error';
  }

  @override
  String get paymentMethodCash => 'Espèces';

  @override
  String get paymentMethodCard => 'Carte';

  @override
  String get paymentMethodBankTransfer => 'Virement bancaire';

  @override
  String get paymentMethodMobileMoney => 'Mobile money';

  @override
  String get paymentMethodOther => 'Autre';

  @override
  String get feeStatusPaid => 'Payé';

  @override
  String get feeStatusPartiallyPaid => 'Partiellement payé';

  @override
  String get feeStatusOverdue => 'En retard';

  @override
  String get feeStatusCancelled => 'Annulé';

  @override
  String get feeStatusDue => 'À payer';

  @override
  String get summary => 'Résumé';

  @override
  String get expected => 'Attendu';

  @override
  String get paid => 'Payé';

  @override
  String get balance => 'Solde';

  @override
  String overdueFeeLinesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count lignes de frais en retard',
      one: '1 ligne de frais en retard',
    );
    return '$_temp0';
  }

  @override
  String dueDate(String date) {
    return 'Échéance $date';
  }

  @override
  String paymentCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count paiements',
      one: '1 paiement',
    );
    return '$_temp0';
  }

  @override
  String paidAmount(String amount) {
    return 'Payé $amount';
  }

  @override
  String get paymentDetails => 'Détails du paiement';

  @override
  String get amount => 'Montant';

  @override
  String get date => 'Date';

  @override
  String get method => 'Méthode';

  @override
  String get reference => 'Référence';

  @override
  String unreadCount(int count) {
    return '$count non lu(s)';
  }

  @override
  String get noMessagesInInbox =>
      'Aucun message dans votre boîte de réception.';

  @override
  String couldNotLoadInbox(String error) {
    return 'Impossible de charger la boîte de réception : $error';
  }

  @override
  String get inboxStatusPending => 'En attente';

  @override
  String get inboxStatusNew => 'Nouveau';

  @override
  String get inboxStatusFailed => 'Échec';

  @override
  String get inboxStatusRead => 'Lu';

  @override
  String get inboxStatusCancelled => 'Annulé';

  @override
  String get messageDefaultTitle => 'Message';

  @override
  String get messageTitle => 'Message';

  @override
  String couldNotMarkMessageRead(String error) {
    return 'Impossible de marquer le message comme lu : $error';
  }

  @override
  String get allClasses => 'Toutes les classes';

  @override
  String get evaluationsTitle => 'Évaluations';

  @override
  String get calendarTitle => 'Calendrier';

  @override
  String evaluationCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count évaluations',
      one: '1 évaluation',
    );
    return '$_temp0';
  }

  @override
  String sessionCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count séances',
      one: '1 séance',
    );
    return '$_temp0';
  }

  @override
  String get tooltipNewEvaluation => 'Nouvelle évaluation';

  @override
  String get tooltipFilter => 'Filtrer';

  @override
  String get teacherFallbackName => 'Enseignant';

  @override
  String get filterTitle => 'Filtre';

  @override
  String get classLabel => 'Classe';

  @override
  String couldNotLoadTeachingContext(String error) {
    return 'Impossible de charger le contexte d\'enseignement : $error';
  }

  @override
  String get signInToViewCalendar =>
      'Connectez-vous pour afficher votre calendrier d\'enseignement.';

  @override
  String get noClassesAssignedForYear =>
      'Aucune classe assignée pour cette année scolaire.';

  @override
  String get classSessionFallback => 'Séance de cours';

  @override
  String get logbook => 'Cahier de textes';

  @override
  String attendanceProgress(int recorded, int total) {
    return 'Présence $recorded / $total';
  }

  @override
  String get takeAttendance => 'Faire l\'appel';

  @override
  String get logbookNotAvailableForSession =>
      'Le cahier de textes n\'est pas disponible pour cette séance.';

  @override
  String get attendanceRecordingLessonOnly =>
      'La présence ne peut être enregistrée que pour les cours.';

  @override
  String get noCurriculumChaptersLinked =>
      'Aucun chapitre de programme lié à cette matière.';

  @override
  String get chapterLabel => 'Chapitre';

  @override
  String get contentLabel => 'Contenu';

  @override
  String get objectivesLabel => 'Objectifs (un par ligne)';

  @override
  String get progressPercentLabel => 'Progression %';

  @override
  String get saveLogbook => 'Enregistrer le cahier';

  @override
  String get logbookSaved => 'Cahier enregistré';

  @override
  String get sessionNotesLabel => 'Notes de séance';

  @override
  String get sessionNotesDescription => 'Compte rendu global de cette séance.';

  @override
  String get sessionNotesHint => 'Qu\'avez-vous traité pendant ce cours ?';

  @override
  String get saveSessionNotes => 'Enregistrer les notes';

  @override
  String get sessionNotesSaved => 'Notes de séance enregistrées';

  @override
  String couldNotSaveSessionNote(String error) {
    return 'Impossible d\'enregistrer les notes : $error';
  }

  @override
  String get curriculumProgressTitle => 'Avancement du programme';

  @override
  String get curriculumProgressDescription =>
      'Indiquez l\'avancement de chaque notion couverte pendant cette séance.';

  @override
  String subjectProgressSummary(int percent) {
    return 'Matière $percent %';
  }

  @override
  String cumulativeProgressLabel(int percent) {
    return 'Global $percent %';
  }

  @override
  String lessonProgressLabel(int percent) {
    return 'Cette séance $percent %';
  }

  @override
  String get lessonProgressPercentLabel => 'Progression pour cette séance (%)';

  @override
  String get matterNotesLabel => 'Notes sur la notion';

  @override
  String get noMatterProgressForSession =>
      'Aucun avancement enregistré pour cette notion dans cette séance.';

  @override
  String get recordMatterProgress => 'Enregistrer l\'avancement';

  @override
  String get editMatterProgress => 'Modifier l\'avancement';

  @override
  String get saveMatterProgress => 'Enregistrer l\'avancement';

  @override
  String get matterProgressSaved => 'Avancement enregistré';

  @override
  String couldNotSaveMatterProgress(String error) {
    return 'Impossible d\'enregistrer l\'avancement : $error';
  }

  @override
  String matterProgressMinimum(int percent) {
    return 'Doit être au moins $percent %';
  }

  @override
  String progressMustNotDecrease(int percent) {
    return 'La progression doit être d\'au moins $percent %';
  }

  @override
  String get matterStatusNotStarted => 'Non commencé';

  @override
  String get matterStatusInProgress => 'En cours';

  @override
  String get matterStatusCompleted => 'Terminé';

  @override
  String get addCurriculumProgress => 'Ajouter un avancement';

  @override
  String get addAnotherCurriculumProgress => 'Ajouter une autre notion';

  @override
  String get pickSubjectMatterTitle => 'Choisir une notion';

  @override
  String get pickSubjectMatterDescription =>
      'Sélectionnez la notion couverte pendant cette séance.';

  @override
  String get noRecordedMatterProgress =>
      'Aucun avancement enregistré pour cette séance.';

  @override
  String get allMattersRecordedForSession =>
      'Toutes les notions liées ont été enregistrées pour cette séance.';

  @override
  String get notRecorded => 'Non enregistré';

  @override
  String get record => 'Enregistrer';

  @override
  String get edit => 'Modifier';

  @override
  String get attendanceStatusPresent => 'Présent';

  @override
  String get attendanceStatusAbsent => 'Absent';

  @override
  String get attendanceStatusLate => 'En retard';

  @override
  String attendanceFlowTitle(String classLabel) {
    return 'Présence · $classLabel';
  }

  @override
  String get noStudentsToRecord => 'Aucun élève à enregistrer.';

  @override
  String attendanceRecordedProgress(int recorded, int total) {
    return '$recorded / $total enregistré(s)';
  }

  @override
  String get attendanceComplete => 'Appel terminé';

  @override
  String get markAllPresent => 'Tout marquer présent';

  @override
  String get attendanceModeGrid => 'Grille';

  @override
  String get attendanceModeSequential => 'Séquentiel';

  @override
  String attendanceExceptionTitle(String studentName) {
    return 'Présence · $studentName';
  }

  @override
  String get attendanceReasonLabel => 'Motif';

  @override
  String get attendanceReasonHint => 'ex. maladie, rendez-vous';

  @override
  String get attendanceNotesLabel => 'Notes';

  @override
  String get attendanceNotesHint => 'Contexte optionnel pour la vie scolaire';

  @override
  String get attendanceSavedLocally =>
      'Enregistré localement — synchronisation à la reconnexion';

  @override
  String get calendarTodayTitle => 'Aujourd\'hui';

  @override
  String get calendarGoToToday => 'Aller à aujourd\'hui';

  @override
  String get calendarCurrentSession => 'En cours';

  @override
  String get calendarNextSession => 'À suivre';

  @override
  String get calendarNoSessionsToday => 'Aucune séance prévue aujourd\'hui.';

  @override
  String calendarIncompleteAttendance(String classLabel, String subjectLabel) {
    return 'Présence · $classLabel $subjectLabel';
  }

  @override
  String get sessionAttendanceComplete => 'Présence complète';

  @override
  String get sessionAttendanceIncomplete => 'Présence incomplète';

  @override
  String get logbookDraftRestored => 'Brouillon de cahier restauré';

  @override
  String get done => 'Terminé';

  @override
  String get cancel => 'Annuler';

  @override
  String get reviewAgain => 'Revoir';

  @override
  String couldNotLoadSession(String error) {
    return 'Impossible de charger la séance : $error';
  }

  @override
  String couldNotSaveAttendance(String error) {
    return 'Impossible d\'enregistrer la présence : $error';
  }

  @override
  String couldNotSaveLogbook(String error) {
    return 'Impossible d\'enregistrer le cahier : $error';
  }

  @override
  String get chapterFallback => 'Chapitre';

  @override
  String evaluationGradedProgress(int graded, int total) {
    return '$graded / $total noté(s)';
  }

  @override
  String get selectPeriodToViewEvaluations =>
      'Sélectionnez une période pour afficher les évaluations.';

  @override
  String get noEvaluationsForPeriod => 'Aucune évaluation pour cette période.';

  @override
  String couldNotLoadEvaluations(String error) {
    return 'Impossible de charger les évaluations : $error';
  }

  @override
  String couldNotLoadMarks(String error) {
    return 'Impossible de charger les notes : $error';
  }

  @override
  String couldNotSaveMark(String error) {
    return 'Impossible d\'enregistrer la note : $error';
  }

  @override
  String get publishedReportCardImmutable =>
      'Le bulletin de cet élève a déjà été publié pour cette période. Les notes ne peuvent plus être modifiées.';

  @override
  String get marksLockedReportCardPublished => 'Bulletin publié';

  @override
  String get marksEntryPeriodLockedHint =>
      'Les bulletins ont été publiés pour cette période. Les notes ne peuvent plus être saisies pour ces élèves.';

  @override
  String couldNotLoadSubjects(String error) {
    return 'Impossible de charger les matières : $error';
  }

  @override
  String couldNotLoadPeriods(String error) {
    return 'Impossible de charger les périodes : $error';
  }

  @override
  String get titleRequired => 'Le titre est obligatoire.';

  @override
  String get maxScoreMustBePositive =>
      'La note maximale doit être supérieure à zéro.';

  @override
  String get periodRequired => 'La période est obligatoire.';

  @override
  String couldNotCreateEvaluation(String error) {
    return 'Impossible de créer l\'évaluation : $error';
  }

  @override
  String get newEvaluation => 'Nouvelle évaluation';

  @override
  String get noSubjectsAssignedForYear =>
      'Aucune matière assignée pour cette année scolaire.';

  @override
  String get classSubjectLabel => 'Classe · Matière';

  @override
  String get titleLabel => 'Titre';

  @override
  String get outOfLabel => 'Sur';

  @override
  String get kindLabel => 'Type';

  @override
  String get evaluationKindQuiz => 'Interrogation';

  @override
  String get evaluationKindHomework => 'Devoir';

  @override
  String get evaluationKindProject => 'Projet';

  @override
  String get evaluationKindOther => 'Autre';

  @override
  String get createEvaluation => 'Créer l\'évaluation';

  @override
  String get enterValidMaxScore => 'Saisissez une note maximale valide.';

  @override
  String get assessmentDateLabel => 'Date de l\'évaluation';

  @override
  String get homeworkDueDateLabel => 'Date limite du devoir';

  @override
  String get assessmentDateRequired => 'Sélectionnez une date d\'évaluation.';

  @override
  String get homeworkDueDateRequired =>
      'Sélectionnez une date limite pour le devoir.';

  @override
  String invalidScoreValue(String maxScore) {
    return 'Saisissez une note entre 0 et $maxScore.';
  }

  @override
  String get syncStatusSaved => 'Enregistré';

  @override
  String get syncStatusSavedLocally => 'Enregistré localement';

  @override
  String get syncStatusPending => 'En attente de synchronisation';

  @override
  String get syncStatusSyncing => 'Synchronisation';

  @override
  String get syncStatusSynced => 'Synchronisé';

  @override
  String get syncStatusFailed => 'Échec de synchronisation';

  @override
  String get duplicateEvaluation => 'Dupliquer';

  @override
  String get completeEvaluation => 'Marquer terminée';

  @override
  String get ungradedOnlyFilter => 'Non notés seulement';

  @override
  String get fillAllMarks => 'Remplir tout';

  @override
  String get clearAllMarks => 'Effacer tout';

  @override
  String get familyVisibleSummaryLabel => 'Résumé visible par les familles';

  @override
  String get familyVisiblePreviewLabel => 'Aperçu famille';

  @override
  String get accountSyncSectionTitle => 'Synchronisation';

  @override
  String accountPendingSyncSummary(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count éléments en attente',
      one: '1 élément en attente',
    );
    return '$_temp0';
  }

  @override
  String accountPendingSyncOldest(String age) {
    return 'Le plus ancien : $age';
  }

  @override
  String get accountPendingSyncNone =>
      'Toutes les modifications sont synchronisées';

  @override
  String get accountSyncNow => 'Synchroniser';

  @override
  String get accountPendingSyncJustNow => 'à l\'instant';

  @override
  String accountPendingSyncMinutes(int minutes) {
    return 'il y a $minutes min';
  }

  @override
  String accountPendingSyncHours(int hours) {
    return 'il y a $hours h';
  }

  @override
  String accountPendingSyncDays(int days) {
    return 'il y a $days j';
  }

  @override
  String outOfMaxScore(String maxScore) {
    return 'Sur $maxScore';
  }

  @override
  String currentScore(String score) {
    return 'Actuelle : $score';
  }

  @override
  String scoreHintOutOf(String maxScore) {
    return '/ $maxScore';
  }

  @override
  String get periodLabel => 'Période';

  @override
  String timeRange(String start, String end) {
    return '$start – $end';
  }

  @override
  String sessionDateTime(String date, String timeRange) {
    return '$date · $timeRange';
  }

  @override
  String paymentMethodAndDate(String method, String date) {
    return '$method · $date';
  }

  @override
  String get settingsTitle => 'Paramètres';

  @override
  String get settingsTheme => 'Thème';

  @override
  String get settingsThemeSystem => 'Par défaut du système';

  @override
  String get settingsThemeLight => 'Clair';

  @override
  String get settingsThemeDark => 'Sombre';

  @override
  String get settingsLanguage => 'Langue';

  @override
  String get settingsLanguageSystem => 'Par défaut du système';

  @override
  String get settingsLanguageEnglish => 'Anglais';

  @override
  String get settingsLanguageFrench => 'Français';

  @override
  String get settingsTimezone => 'Fuseau horaire';

  @override
  String get settingsTimezoneDevice => 'Fuseau de l\'appareil';

  @override
  String get settingsTimezoneUtc => 'UTC';

  @override
  String get settingsTimezoneParis => 'Paris';

  @override
  String get settingsTimezoneAbidjan => 'Abidjan';

  @override
  String get settingsTimezoneLagos => 'Lagos';

  @override
  String get settingsTimezoneNewYork => 'New York';

  @override
  String get settingsDateFormat => 'Format de date';

  @override
  String get settingsDateFormatSystem => 'Par défaut du système';

  @override
  String get settingsDateFormatShort => 'Court';

  @override
  String get settingsDateFormatMedium => 'Moyen';

  @override
  String get settingsDateFormatLong => 'Long';

  @override
  String get settingsTimeFormat => 'Format de l\'heure';

  @override
  String get settingsTimeFormatSystem => 'Par défaut du système';

  @override
  String get settingsTimeFormat24h => '24 heures';

  @override
  String get settingsTimeFormat12h => '12 heures';

  @override
  String get emailRequired => 'Saisissez votre e-mail.';

  @override
  String get sendCodeButton => 'Envoyer le code';

  @override
  String get otpSendFailed => 'Impossible d\'envoyer un code de vérification.';

  @override
  String get verifyEmailTitle => 'Vérifiez votre e-mail';

  @override
  String get otpLabel => 'Code de vérification';

  @override
  String get verifyCodeButton => 'Vérifier et continuer';

  @override
  String get resendCodeButton => 'Renvoyer le code';

  @override
  String get useDifferentEmail => 'Utiliser une autre adresse e-mail';

  @override
  String verificationCodeSent(String email) {
    return 'Nous avons envoyé un code à $email.';
  }

  @override
  String get invitationTitle => 'Rejoindre l\'établissement';

  @override
  String get invitationContinue => 'Continuer';

  @override
  String get invitationAcceptCta => 'Accepter l\'invitation';

  @override
  String get invitationAccepting => 'Liaison du compte…';

  @override
  String get invitationSuccess =>
      'Votre compte est relié. Ouverture de la vue famille.';

  @override
  String get invitationWrongKind =>
      'Cette invitation concerne une autre application Edaya.';

  @override
  String get invitationWrongAccount =>
      'Cette invitation concerne un autre compte. Déconnectez-vous, puis continuez avec l\'e-mail invité.';

  @override
  String get invitationSignOutSwitch => 'Se déconnecter et continuer';

  @override
  String get invitationNotFound => 'Ce lien d\'invitation est introuvable.';

  @override
  String get invitationExpired =>
      'Cette invitation a expiré. Demandez un nouveau lien au secrétariat.';

  @override
  String get invitationRevoked =>
      'Cette invitation a été remplacée. Ouvrez le dernier e-mail ou demandez un renvoi au secrétariat.';

  @override
  String get invitationInvalid => 'Cette invitation n\'est pas valide.';

  @override
  String get invitationAlreadyAccepted =>
      'Cette invitation a déjà été utilisée.';

  @override
  String invitationLoadError(String error) {
    return 'Impossible de charger cette invitation. $error';
  }

  @override
  String invitationSummary(String name, String school) {
    return '$name est invité(e) en tant que tuteur à $school.';
  }

  @override
  String invitationExpires(String date) {
    return 'Expire le $date';
  }

  @override
  String get missingChargeDetailsRouteData =>
      'Données de route des détails de la charge manquantes.';

  @override
  String get waitingForStudentsTitle => 'Vous êtes connecté';

  @override
  String get waitingForStudentsBody =>
      'Votre compte est prêt. Lorsque l\'école vous liera à un enfant, son emploi du temps, ses notes et ses messages apparaîtront ici.';

  @override
  String get waitingForStudentsCheckAgain => 'Vérifier à nouveau';

  @override
  String get waitingPendingInvitationsTitle => 'Invitations en attente';

  @override
  String get waitingNoPendingInvitations =>
      'Aucune invitation en attente pour cet e-mail. Si l\'école a envoyé un lien, ouvrez-le depuis le message.';

  @override
  String get noChildrenLinkedYet =>
      'Aucun enfant n\'est encore lié à votre compte.';

  @override
  String get feeStatusWaived => 'Exonéré';

  @override
  String get availableAmount => 'Disponible';

  @override
  String get outstandingAmount => 'Restant dû';

  @override
  String get overdueAmount => 'En retard';

  @override
  String get remainingAmountLabel => 'Reste à payer';

  @override
  String get chargeSchedule => 'Échéancier';

  @override
  String get noInstallmentsForCharge => 'Aucun échéancier pour cette charge.';

  @override
  String installmentDue(String label, String date) {
    return '$label · échéance $date';
  }

  @override
  String get paymentKind => 'Type';

  @override
  String get paymentKindReceipt => 'Encaissement';

  @override
  String get paymentKindDisbursement => 'Remboursement';

  @override
  String get mutationConflict =>
      'Cette modification est en conflit avec les données actuelles. Rechargez-les et vérifiez-les avant de réessayer.';

  @override
  String get mutationSavedRefreshFailed =>
      'Votre modification est enregistrée, mais l’affichage n’a pas pu être actualisé. Rouvrez cet écran pour voir le résultat.';

  @override
  String get profilePhotoCropTitle => 'Ajuster le portrait';

  @override
  String get profilePhotoCropHint =>
      'Faites pivoter et confirmez un JPEG carré de 1 Mo maximum.';

  @override
  String get profilePhotoRotate => 'Pivoter';

  @override
  String get profilePhotoConfirmCrop => 'Utiliser cette photo';

  @override
  String get profilePhotoTooLarge =>
      'La photo dépasse encore 1 Mo après compression.';

  @override
  String get profilePhotoUpdateSuccess => 'Photo de profil mise à jour.';

  @override
  String profilePhotoUpdateError(String error) {
    return 'Impossible de mettre à jour la photo de profil. $error';
  }

  @override
  String get childProfileTitle => 'Portrait de l’enfant';

  @override
  String get childProfileUnavailable =>
      'Sélectionnez un enfant pour proposer un portrait.';

  @override
  String childProfileLoadError(String error) {
    return 'Impossible de charger le portrait de l’enfant. $error';
  }

  @override
  String get childProfilePublished => 'Portrait publié';

  @override
  String get childProfileProposed => 'Portrait proposé';

  @override
  String get childProfileNoPublished => 'Aucun portrait publié pour le moment.';

  @override
  String get childProfilePending =>
      'En attente de validation par l’établissement.';

  @override
  String get childProfilePendingIndicator =>
      'Un portrait est en attente de validation.';

  @override
  String get childProfileSubmitHint =>
      'Prenez ou choisissez une photo. L’établissement doit l’approuver avant qu’elle n’apparaisse sur les documents.';

  @override
  String get childProfileSubmit => 'Envoyer le portrait';

  @override
  String get childProfileResubmit => 'Envoyer un nouveau portrait';

  @override
  String get childProfileWithdraw => 'Retirer la proposition';

  @override
  String get childProfileSubmitted => 'Portrait envoyé pour validation.';

  @override
  String get childProfileWithdrawn => 'Proposition retirée.';

  @override
  String childProfileSubmitError(String error) {
    return 'Impossible d’envoyer le portrait. $error';
  }

  @override
  String childProfileWithdrawError(String error) {
    return 'Impossible de retirer la proposition. $error';
  }

  @override
  String childProfileRejected(String reason) {
    return 'L’établissement a refusé ce portrait : $reason';
  }

  @override
  String get childProfileRejectedNoReason => 'Aucun motif n’a été indiqué.';

  @override
  String get documentsTitle => 'Documents officiels';

  @override
  String get tooltipDocuments => 'Documents officiels';

  @override
  String get documentsEntry => 'Documents officiels';

  @override
  String get documentsEmpty =>
      'Aucun document officiel pour cette année scolaire.';

  @override
  String get documentsDownloadRecall =>
      'Les fichiers déjà téléchargés ne peuvent pas être rappelés à distance.';

  @override
  String get documentsDownload => 'Télécharger';

  @override
  String get documentsGeneratePdf => 'Générer le PDF';

  @override
  String get documentsOpened => 'Ouverture du PDF.';

  @override
  String get documentsRendering =>
      'Le PDF est encore en cours de génération. Ouvrez Documents officiels lorsqu’il sera prêt.';

  @override
  String documentsFailed(String code) {
    return 'Ce document a échoué ($code).';
  }

  @override
  String get documentsNotIssued =>
      'Aucun PDF téléchargeable n’est encore prêt.';

  @override
  String get documentsOpenFailed => 'Impossible d’ouvrir le PDF.';

  @override
  String get documentStatusRequested => 'En attente';

  @override
  String get documentStatusRendering => 'En attente';

  @override
  String get documentStatusReady => 'Émis';

  @override
  String get documentStatusFailed => 'Erreur';

  @override
  String get documentStatusSuperseded => 'Remplacé';

  @override
  String get documentStatusVoided => 'Remplacé';

  @override
  String get documentStatusPreview => 'Émis';

  @override
  String get exportLogbookPdf => 'PDF du cahier de textes';

  @override
  String get exportTimetablePdf => 'PDF de l’emploi du temps';

  @override
  String get exportRosterPdf => 'PDF de la liste de classe';

  @override
  String get exportAttendancePdf => 'PDF de la feuille d’appel';

  @override
  String get familyFeedbackEntry => 'Retour des familles';

  @override
  String get familyFeedbackTitle => 'Retour des familles';

  @override
  String get familyFeedbackEmpty =>
      'Aucune campagne de retour des familles pour le moment.';

  @override
  String get familyFeedbackConfidential =>
      'Confidentiel et agrégé. Ce n’est pas une évaluation scolaire.';

  @override
  String get familyFeedbackSubmit => 'Envoyer';

  @override
  String get familyFeedbackSubmitted => 'Votre réponse a été enregistrée.';

  @override
  String get familyFeedbackAlreadyCompleted =>
      'Une réponse est déjà enregistrée pour cet élève.';

  @override
  String get familyFeedbackClosed => 'Cette campagne est close.';

  @override
  String get familyFeedbackComment => 'Commentaire facultatif';

  @override
  String get familyFeedbackCannotAssess => 'Ne peut pas évaluer';

  @override
  String get familyFeedbackInsufficient => 'Réponses insuffisantes';

  @override
  String get familyFeedbackThemes => 'Thèmes';

  @override
  String get familyFeedbackSlotOpen => 'Ouverte';

  @override
  String get familyFeedbackSlotCompleted => 'Terminée';

  @override
  String get teacherTaskFamilyFeedback => 'Avis des familles';

  @override
  String get teacherTaskAttendance => 'Présences à saisir';

  @override
  String get teacherTaskLogbook => 'Cahier de texte';

  @override
  String get teacherTaskMarks => 'Notes à saisir';

  @override
  String get chooseSchool => 'Choisir un établissement';

  @override
  String get teacherTaskReportComments => 'Commentaires de bulletin';
}
