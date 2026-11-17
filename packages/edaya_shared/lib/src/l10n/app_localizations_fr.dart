// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for French (`fr`).
class AppLocalizationsFr extends AppLocalizations {
  AppLocalizationsFr([String locale = 'fr']) : super(locale);

  @override
  String get navInboxShort => 'Boîte';

  @override
  String get navEvaluationsShort => 'Éval.';

  @override
  String get navMessages => 'Messages';

  @override
  String get teacherSpace => 'Espace enseignant';

  @override
  String get guardianSpace => 'Espace famille';

  @override
  String get signInContactSubtitle =>
      'Connectez-vous avec votre e-mail ou votre numéro de téléphone.';

  @override
  String get signInEmailSubtitle => 'Connectez-vous avec votre adresse e-mail.';

  @override
  String get demoTry => 'Essayer la démo';

  @override
  String get demoExit => 'Quitter la démo';

  @override
  String get demoExitDetail =>
      'Quitter et effacer vos modifications de démonstration sur cet appareil ?';

  @override
  String get demoLabel => 'Démo';

  @override
  String get appTitleGuardian => 'EDaya';

  @override
  String get appTitleTeacher => 'EDaya Prof';

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
  String get contactLabel => 'E-mail ou numéro de téléphone';

  @override
  String get invalidContact => 'Saisissez un contact valide.';

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
      'Aucun profil famille n’est associé à votre compte. Contactez votre établissement.';

  @override
  String get signedInNoStaffProfile =>
      'Aucun profil de membre du personnel n’est associé à votre compte. Contactez votre établissement.';

  @override
  String get signedInNoTeacherProfile =>
      'Aucun profil enseignant n’est associé à votre compte. Contactez votre établissement.';

  @override
  String get accountNotLinkedToStaff =>
      'Ce compte n\'est pas lié à un profil personnel.';

  @override
  String get accountNotLinkedToTeacher =>
      'Ce compte n\'est pas lié à un profil enseignant.';

  @override
  String get navProfile => 'Profil';

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
  String get teacherMockSignInHint =>
      'Dans cette démo, vous pouvez utiliser une adresse e-mail de votre choix.';

  @override
  String get teacherMockVerifyHint =>
      'Saisissez un code de votre choix pour continuer la démo.';

  @override
  String get teacherTodaySessions => 'Séances du jour';

  @override
  String get teacherNoUpcomingSessions => 'Aucune séance à venir';

  @override
  String get teacherSessionsAgendaHint =>
      'Les séances de la journée restent accessibles dans l’agenda.';

  @override
  String get teacherClassLife => 'Vie en classe';

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
  String get teachingLogbookTab => 'Cahier de texte';

  @override
  String get noTeachingLogEntries =>
      'Aucune entrée de cahier de texte pour cette matière.';

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
  String identifierLabel(String identifier) {
    return 'Matricule : $identifier';
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
  String get classLogbook => 'Cahier de texte';

  @override
  String get noLogbookEntryForSession =>
      'Aucune entrée de cahier de texte pour cette séance.';

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
      zero: '0 évaluations',
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
      zero: '0 lignes de frais en retard',
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
      zero: '0 paiements',
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
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count messages non lus',
      one: '1 message non lu',
      zero: '0 messages non lus',
    );
    return '$_temp0';
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
      zero: '0 évaluations',
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
      zero: '0 séances',
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
  String get logbook => 'Cahier de texte';

  @override
  String attendanceProgress(int recorded, int total) {
    return 'Présence $recorded / $total';
  }

  @override
  String get takeAttendance => 'Faire l\'appel';

  @override
  String get logbookNotAvailableForSession =>
      'Le cahier de texte n’est pas disponible pour cette séance.';

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
  String get saveLogbook => 'Enregistrer le cahier de texte';

  @override
  String get logbookSaved => 'Cahier de texte enregistré';

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
  String get rollWriteRejected =>
      'La modification n’a pas été enregistrée. Vérifiez le registre puis réessayez.';

  @override
  String get rollRegisterChanged =>
      'Le registre a changé. Vérifiez les présences actualisées avant de terminer.';

  @override
  String get rollExcused => 'Justifié par l’établissement';

  @override
  String get rollUnmarked => 'À saisir';

  @override
  String get rollList => 'Liste';

  @override
  String rollRosterCount(int total, int marked) {
    return '$marked/$total renseignés';
  }

  @override
  String get bookGeneral => 'Informations générales';

  @override
  String get bookChapters => 'Chapitres abordés';

  @override
  String get bookAddChapter => 'Ajouter un chapitre';

  @override
  String bookEditChapter(String name) {
    return 'Modifier $name';
  }

  @override
  String get bookAllLinked =>
      'Tous les chapitres du programme sont liés à cette séance.';

  @override
  String get bookNoProgramme =>
      'Aucun chapitre disponible pour cette classe et cette matière.';

  @override
  String get bookProgress => 'Progression';

  @override
  String get rollMarkRemaining => 'Marquer les élèves restants présents';

  @override
  String get rollOneByOne => 'Mode photo';

  @override
  String rollPosition(int position, int total) {
    return '$position sur $total';
  }

  @override
  String get rollToSend => 'À envoyer · Réessayer';

  @override
  String rollLeftAt(String time) {
    return 'Départ à $time';
  }

  @override
  String get rollDeparture => 'Enregistrer le départ';

  @override
  String get rollAttendance => 'Appel';

  @override
  String get rollLocalDraft => 'Brouillon local disponible';

  @override
  String get rollProposedLogbook => 'Cahier de texte proposé';

  @override
  String get rollContent => 'Contenu abordé';

  @override
  String get rollObjectives => 'Objectifs';

  @override
  String get rollHomework => 'Devoirs';

  @override
  String get rollFamilySummary => 'Synthèse familles';

  @override
  String get rollChapters => 'Progression des chapitres';

  @override
  String get rollRequestChange => 'Demander une modification';

  @override
  String get rollCreateBook => 'Renseigner le cahier de texte';

  @override
  String get rollEditBook => 'Modifier le cahier de texte';

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
  String get logbookDraftRestored => 'Brouillon du cahier de texte restauré';

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
    return 'Impossible d’enregistrer le cahier de texte : $error';
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
      zero: '0 éléments en attente',
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
  String get noEmailAccount =>
      'Aucun compte n’est associé à cette adresse e-mail.';

  @override
  String get invitationGuidance =>
      'Demandez une invitation à votre établissement pour créer un compte.';

  @override
  String get createEmailAccount => 'Créer un compte';

  @override
  String get useAnotherEmail => 'Utiliser une autre adresse e-mail';

  @override
  String get emailSendUnconfirmed =>
      'L’envoi du code n’a pas pu être confirmé.';

  @override
  String get restartEmailVerification =>
      'Vérifiez de nouveau votre adresse e-mail pour continuer.';

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
      'Cette invitation concerne une autre application EDaya.';

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
  String profilePhotoCropHint(String limit) {
    return 'Ajustez puis confirmez un JPEG carré de $limit maximum.';
  }

  @override
  String get profilePhotoRotate => 'Pivoter';

  @override
  String get profilePhotoConfirmCrop => 'Utiliser cette photo';

  @override
  String profilePhotoTooLarge(String limit) {
    return 'La photo dépasse encore $limit après compression.';
  }

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
  String get documentStatusVoided => 'Annulé';

  @override
  String get documentStatusPreview => 'Aperçu';

  @override
  String get exportLogbookPdf => 'PDF du cahier de texte';

  @override
  String get exportTimetablePdf => 'PDF de l’emploi du temps';

  @override
  String get exportRosterPdf => 'PDF de la liste de classe';

  @override
  String get exportAttendancePdf => 'PDF de la feuille d’appel';

  @override
  String get familyFeedbackEntry => 'Avis des familles';

  @override
  String get familyFeedbackTitle => 'Avis des familles';

  @override
  String get familyFeedbackEmpty =>
      'Aucune campagne d’avis des familles pour le moment.';

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
  String get familyFeedbackCannotAssess => 'Je ne peux pas évaluer';

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

  @override
  String get outboxConflictTitle => 'Modifications à vérifier';

  @override
  String get outboxDiscardEdit => 'Abandonner cette modification locale';

  @override
  String get outboxDiscardConfirm =>
      'Seule cette modification locale sera supprimée. Le dossier enregistré reste inchangé. Vérifiez la version actuelle avant de saisir une nouvelle modification.';

  @override
  String get marksAbsent => 'Absent';

  @override
  String get marksExempt => 'Dispensé';

  @override
  String get marksDesignation => 'Désignation de la note';

  @override
  String get marksSubmit => 'Soumettre pour validation';

  @override
  String get marksSubmitted => 'Notes soumises et visibles aux familles.';

  @override
  String get marksResolveConflicts =>
      'Résolvez les conflits avant de soumettre.';

  @override
  String get marksInvalidNumber => 'Saisissez une note numérique valide.';

  @override
  String get marksRequestCorrection => 'Demander une correction';

  @override
  String get marksCorrectionRequested =>
      'Correction demandée. Les notes officielles restent inchangées.';

  @override
  String get marksCorrectionHint =>
      'Les notes officielles restent inchangées jusqu’à la validation du personnel.';

  @override
  String get marksCorrectionReason => 'Motif de la correction';

  @override
  String get marksCorrectionConfirm =>
      'Toutes les modifications proposées ont été vérifiées.';

  @override
  String get marksCorrectionPending => 'Correction en attente';

  @override
  String get marksCorrectionApproved => 'Correction approuvée';

  @override
  String get marksCorrectionRejected => 'Correction rejetée';

  @override
  String get marksCorrectionWithdrawn => 'Correction retirée';

  @override
  String get marksWithdrawCorrection => 'Retirer la demande';

  @override
  String get marksComment => 'Commentaire de note';

  @override
  String get marksPublishedLock => 'Verrouillée par un bulletin publié';

  @override
  String get marksOfficial => 'Soumises · notes officielles';

  @override
  String get marksOriginal => 'Valeur initiale';

  @override
  String get marksProposed => 'Valeur proposée';

  @override
  String get deliveryChannel => 'Recevoir mon code par';

  @override
  String get phoneUnavailable =>
      'La vérification par téléphone est temporairement indisponible. Utilisez une adresse e-mail.';

  @override
  String get phoneCountryHint =>
      'Numéros mobiles de Côte d’Ivoire uniquement. Exemple : +2250712345678.';

  @override
  String get authenticatorSetup =>
      'Ajoutez cette clé à votre application d’authentification, puis saisissez son code.';

  @override
  String get authenticatorCode => 'Code de l’application';

  @override
  String get recoveryCode => 'Code de récupération';

  @override
  String get useRecoveryCode => 'Utiliser un code de récupération';

  @override
  String get saveRecoveryCodes =>
      'Conservez ces codes en lieu sûr. Ils ne seront affichés qu’une fois.';

  @override
  String get savedRecoveryCodes => 'J’ai conservé mes codes';

  @override
  String get accountSecurity => 'Sécurité du compte';

  @override
  String get recentSignInHint =>
      'Reconnectez-vous avant de modifier vos identifiants ou votre application d’authentification.';

  @override
  String get linkIdentifier => 'Associer un autre identifiant';

  @override
  String get unlinkIdentifier => 'Dissocier et se déconnecter';

  @override
  String get enableAuthenticator => 'Configurer l’application';

  @override
  String get recoveryEligible =>
      'Autoriser cet identifiant pour récupérer le compte';

  @override
  String get contactMethod => 'Vérifier avec';

  @override
  String get verifyContactTitle => 'Saisissez votre code de vérification';

  @override
  String verificationContact(String contact) {
    return 'Saisissez le code pour $contact.';
  }

  @override
  String get useMostRecentCode =>
      'Utilisez le dernier code reçu. Chaque nouvel envoi remplace le code précédent.';

  @override
  String get sendBySms => 'Envoyer par SMS';

  @override
  String resendCountdown(int seconds) {
    return 'Vous pourrez demander un autre code dans $seconds s.';
  }

  @override
  String get changeContact => 'Modifier le contact';

  @override
  String get checkWhatsApp => 'Consultez WhatsApp pour obtenir le code.';

  @override
  String get checkSms => 'Consultez vos SMS pour obtenir le code.';

  @override
  String get checkEmailCode => 'Consultez votre e-mail pour obtenir le code.';

  @override
  String get codeExpired => 'Ce code a expiré. Demandez un nouveau code.';

  @override
  String get codeDeliveryFailed =>
      'Le code n’a pas pu être envoyé. Après le décompte, demandez un nouveau code.';

  @override
  String get codeDeliveryUncertain =>
      'La réception du code n’est pas confirmée. Vous pouvez l’utiliser s’il arrive.';

  @override
  String get retryRequest => 'Réessayer la demande';

  @override
  String get testingOnly => 'Réservé aux tests';

  @override
  String get testCodeAutofilled =>
      'Mode test activé. Le code de vérification a été saisi automatiquement.';

  @override
  String get showTestCode => 'Afficher le code de test';

  @override
  String get copyTestCode => 'Copier';

  @override
  String get testCodeUnavailable => 'Code de test indisponible';

  @override
  String get attendanceIncomplete =>
      'Renseignez chaque élève avant de terminer l’appel.';

  @override
  String get attendanceSubmitNeedsSync =>
      'Synchronisez les brouillons avant de terminer l’appel.';

  @override
  String get workflowSynced => 'Synchronisé';

  @override
  String get attendanceArrival => 'Enregistrer l’arrivée';

  @override
  String get workflowCorrectionPending => 'Correction en attente de validation';

  @override
  String get workflowRequestCorrection => 'Demander une correction';

  @override
  String get dailyAttendance => 'Appel du jour';

  @override
  String get workflowDiscipline => 'Discipline';

  @override
  String get workflowFollowUp => 'Ajouter un suivi';

  @override
  String get deadlineCompliance => 'Remise du devoir';

  @override
  String get deadlineMet => 'À temps';

  @override
  String get deadlineLate => 'En retard';

  @override
  String get deadlineMissed => 'Non rendu';

  @override
  String get deadlineExcused => 'Justifié';

  @override
  String get attendancePresent => 'Présent';

  @override
  String get attendanceAbsent => 'Absent';

  @override
  String get attendanceLate => 'En retard';

  @override
  String get attendanceFinish => 'Terminer';

  @override
  String get attendanceMarkRemaining => 'Marquer les autres présents';

  @override
  String get workflowReviseCorrection => 'Réviser la demande';

  @override
  String get workflowIncidentTakenOver => 'Incident pris en charge';

  @override
  String get workflowIncidentTitle => 'Titre';

  @override
  String get workflowIncidentFacts => 'Faits';

  @override
  String get workflowIncidentPositive => 'Positif';

  @override
  String get workflowIncidentMinor => 'Incident mineur';

  @override
  String get workflowIncidentMajor => 'Incident majeur';

  @override
  String get workflowIncidentEmergency => 'Urgence';

  @override
  String get workflowTeacherExplanation => 'Explication de l’enseignant';

  @override
  String get messagingNew => 'Nouveau message';

  @override
  String get messagingSchool => 'École';

  @override
  String get messagingTeacher => 'Enseignant';

  @override
  String get messagingSubject => 'Objet';

  @override
  String get messagingBody => 'Message';

  @override
  String get messagingSend => 'Envoyer';

  @override
  String get messagingReply => 'Répondre';

  @override
  String get messagingEmpty => 'Aucune conversation';

  @override
  String get messagingOversight =>
      'Le personnel autorisé de l’école peut consulter les échanges avec les enseignants.';

  @override
  String get messagingIncludeChild => 'Préciser l’enfant sélectionné';

  @override
  String get messagingUnavailable =>
      'La messagerie est actuellement indisponible pour ce destinataire.';

  @override
  String get messagingHistory => 'Conversation en lecture seule';

  @override
  String get messagingLoadMore => 'Charger les messages précédents';

  @override
  String get messagingRefresh => 'Actualiser';

  @override
  String get messagingAwaitingSchool => 'En attente de l’école';

  @override
  String get messagingAwaitingGuardian =>
      'En attente d’une réponse du responsable légal';

  @override
  String get messagingResolved => 'Résolu';

  @override
  String get messagingFailed =>
      'Envoi impossible. Votre brouillon est conservé. Réessayez.';

  @override
  String get messagingChanged =>
      'De nouveaux échanges sont disponibles. Consultez-les avant de renvoyer votre message.';

  @override
  String get messagingRequired => 'Saisissez un objet et un message.';

  @override
  String get messagingSchoolAuthor => 'Personnel de l’école';

  @override
  String get messagingRead => 'Lu';

  @override
  String get messagingUnread => 'Non lu';

  @override
  String get messagingConversations => 'Conversations';

  @override
  String get teacherSignatureTitle => 'Signature';

  @override
  String get teacherSignatureUsage =>
      'Votre signature est utilisée automatiquement sur les nouveaux bulletins périodiques et annuels et les rapports d’incident que vous créez dans cet établissement.';

  @override
  String get teacherSignatureEmpty => 'Aucune signature enregistrée';

  @override
  String get teacherSignatureDraw => 'Dessiner';

  @override
  String get teacherSignatureChooseImage => 'Choisir une image';

  @override
  String get teacherSignatureTakePhoto => 'Prendre une photo';

  @override
  String get teacherSignatureUndo => 'Annuler le dernier trait';

  @override
  String get teacherSignatureClear => 'Effacer';

  @override
  String get teacherSignatureUse => 'Utiliser la signature';

  @override
  String get teacherSignaturePreview => 'Aperçu de la signature';

  @override
  String get teacherSignatureDrawHint =>
      'Signez dans le cadre avec votre doigt ou un stylet.';

  @override
  String get teacherSignatureCropHint =>
      'Faites glisser votre doigt sur l’image pour sélectionner votre signature. Vous pouvez tourner l’image ou réinitialiser le recadrage.';

  @override
  String get teacherSignatureResetCrop => 'Réinitialiser le recadrage';

  @override
  String get teacherSignatureRemove => 'Supprimer la signature';

  @override
  String get teacherSignatureRemoveConfirm =>
      'Supprimer votre signature ? Elle ne figurera plus sur les nouveaux rapports. Les documents déjà demandés ou émis conservent leur signature.';

  @override
  String get teacherSignatureSaved => 'Signature enregistrée';

  @override
  String get teacherSignatureRemoved => 'Signature supprimée';

  @override
  String get teacherSignatureSaveError =>
      'Impossible d’enregistrer votre signature. Vérifiez votre connexion et réessayez. Votre signature enregistrée est conservée.';

  @override
  String get teacherSignatureLoadError =>
      'Impossible de charger votre signature. Réessayez.';

  @override
  String get teacherSignatureImageError =>
      'Cette image ne peut pas être utilisée. Choisissez une image valide de 20 Mo maximum.';

  @override
  String get teacherSignatureTooLarge =>
      'La signature doit faire moins de 1 Mo. Recadrez-la plus précisément et réessayez.';

  @override
  String get teacherSignatureDiscard => 'Abandonner les modifications';

  @override
  String get teacherSignatureDraft => 'Aperçu avant enregistrement';

  @override
  String messagingSentDescription(String author, String timestamp) {
    return 'Envoyé par $author, $timestamp';
  }

  @override
  String messagingReceivedDescription(String author, String timestamp) {
    return 'Reçu de $author, $timestamp';
  }

  @override
  String get gradingMention => 'Mention';

  @override
  String get termsConfirm => 'Accepter';

  @override
  String get termsRead => 'Lire les conditions d’utilisation';

  @override
  String get termsAccept => 'J’accepte les conditions d’utilisation';

  @override
  String get termsLoading => 'Chargement des conditions d’utilisation…';

  @override
  String get termsUnavailable =>
      'Impossible de charger les conditions d’utilisation. Réessayez pour continuer.';

  @override
  String get termsRetry => 'Recharger les conditions';

  @override
  String get termsRequired =>
      'Acceptez les conditions d’utilisation avant de continuer.';

  @override
  String get termsChanged =>
      'Les conditions d’utilisation ont changé. Lisez et acceptez la nouvelle version pour continuer.';

  @override
  String get termsDraft =>
      'Aperçu du projet — ce texte attend une approbation et n’est pas un accord publié.';

  @override
  String get guardianMainPhone => 'Téléphone principal';

  @override
  String get guardianAlternativePhone => 'Téléphone secondaire';

  @override
  String get guardianNotificationDestinations =>
      'Les SMS utilisent votre téléphone principal et les e-mails votre adresse enregistrée. Les messages restent disponibles dans la boîte de réception de l’application.';

  @override
  String get guardianEmailNotifications => 'Notifications par e-mail';

  @override
  String get guardianSmsNotifications => 'Notifications par SMS';

  @override
  String get guardianPushNotifications => 'Notifications push';

  @override
  String get guardianDiscardChanges => 'Abandonner les modifications ?';

  @override
  String get guardianDiscard => 'Abandonner';

  @override
  String get reportModuleExplicitWeight => 'Poids explicite';

  @override
  String get reportModuleCoefficientWeight => 'Coefficients contributifs';

  @override
  String get reportSubjectCoefficient => 'Coefficient';

  @override
  String get teacherQuickLogin => 'Connexion par code rapide';

  @override
  String get teacherQuickHint =>
      'Saisissez le code transmis par votre établissement.';

  @override
  String get teacherQuickLabel => 'Code enseignant à 8 caractères';

  @override
  String get teacherQuickInvalid => 'Code invalide ou expiré.';

  @override
  String get logbookNotSaved => 'Cahier de texte non enregistré';

  @override
  String get logbookCompleted => 'Cahier de texte complété';

  @override
  String get noCompletedLogbook => 'Aucun cahier de texte complété';

  @override
  String get gradebookSave => 'Enregistrer';

  @override
  String get gradebookSubmit => 'Soumettre les notes';

  @override
  String get gradebookUnsaved => 'Modifications non enregistrées';

  @override
  String get gradebookSaved => 'Brouillon enregistré';

  @override
  String get gradebookQueued => 'À envoyer';

  @override
  String get gradebookClear => 'Effacer la saisie';

  @override
  String get gradebookEdit => 'Modifier la note';

  @override
  String get gradebookOfficial => 'Note officielle';

  @override
  String get gradebookProposed => 'Résultat proposé';

  @override
  String get gradebookReason => 'Motif';

  @override
  String get gradebookSend => 'Envoyer la demande';

  @override
  String get gradebookUpdate => 'Mettre à jour la demande';

  @override
  String get gradebookWithdraw => 'Retirer la demande';

  @override
  String get gradebookApproval =>
      'Le résultat officiel reste inchangé jusqu’à approbation.';

  @override
  String get gradebookPending => 'En attente d’approbation';

  @override
  String get gradebookGrouped =>
      'Ce motif appartient à une demande groupée existante. Les propositions des autres élèves seront conservées.';

  @override
  String get gradebookLocked =>
      'Vos droits actuels ne permettent pas de modifier ce résultat.';

  @override
  String get gradebookDiscard => 'Abandonner les modifications';

  @override
  String get gradebookContinue => 'Continuer la saisie';

  @override
  String get gradebookDraft => 'Brouillon';

  @override
  String get gradebookResult => 'Résultat';

  @override
  String get gradebookPupil => 'Élève';

  @override
  String get gradebookMissing => 'À compléter';

  @override
  String get gradebookInvalid =>
      'Saisissez un résultat valide dans le barème de l’évaluation.';

  @override
  String get gradebookWithdrawConfirm =>
      'Retirer la modification proposée pour cet élève ?';

  @override
  String get gradebookOptions => 'Options du résultat';

  @override
  String get seeYourChildrenSSchoolInformation =>
      'Accédez aux informations scolaires de vos enfants.';

  @override
  String get assignments => 'Affectations';

  @override
  String get showMore => 'Afficher la suite';

  @override
  String get quickOverview => 'Aperçu rapide';

  @override
  String get dailyAttendanceRegisters => 'Appels du jour';

  @override
  String get approved => 'Approuvée';

  @override
  String get approvedAwaitingPublication =>
      'Approuvée · En attente de publication';

  @override
  String get reportComment => 'Appréciation';

  @override
  String get subjectCommentLabel => 'Appréciation de la matière';

  @override
  String publishedComment(Object comment) {
    return 'Appréciation publiée · $comment';
  }

  @override
  String get commentEntered => 'Appréciation renseignée';

  @override
  String get commentNeeded => 'Appréciation à compléter';

  @override
  String get archive => 'Archive';

  @override
  String get noPdfIsAvailableForThisReportCard =>
      'Aucun PDF disponible pour ce bulletin.';

  @override
  String get noSchoolNotices => 'Aucun avis';

  @override
  String get noFeedbackPublishedForThisClassAndSubject =>
      'Aucun avis publié pour cet enseignement';

  @override
  String get noReportCardsPrepared => 'Aucun bulletin préparé.';

  @override
  String get noEditableFields => 'Aucun champ modifiable';

  @override
  String get noCommentHasBeenSharedForThisActivity =>
      'Aucun commentaire partagé pour cette activité.';

  @override
  String get noClassesScheduled => 'Aucun cours prévu';

  @override
  String get noDetailsAvailableForThisAssessment =>
      'Aucun détail disponible pour cette évaluation.';

  @override
  String get noTeachingAssignmentSelected => 'Aucun enseignement sélectionné.';

  @override
  String get noIncidents => 'Aucun incident';

  @override
  String get noMessages => 'Aucun message';

  @override
  String get noCurriculum => 'Aucun programme';

  @override
  String get noStudents => 'Aucun élève';

  @override
  String get noStudentsEnrolledInThisClassAndSubject =>
      'Aucun élève inscrit à cet enseignement.';

  @override
  String get noStudentsFound => 'Aucun élève trouvé.';

  @override
  String get noAssignment => 'Aucune affectation';

  @override
  String get noActiveAssignmentForThisSchoolYear =>
      'Aucune affectation active pour cette année scolaire.';

  @override
  String get noAssignmentsAvailable => 'Aucune affectation disponible.';

  @override
  String get thisSchoolHasNoPublishedSchoolYear =>
      'Aucune année scolaire publiée pour cet établissement.';

  @override
  String get noPublishedSchoolYear => 'Aucune année scolaire publiée.';

  @override
  String get noAssignedClasses => 'Aucune classe affectée';

  @override
  String get noLogbookEntriesForThisSubject =>
      'Aucune entrée pour cette matière';

  @override
  String get noMarks => 'Aucune note';

  @override
  String get noSessionsToday => 'Aucune séance ce jour';

  @override
  String get otherMarks => 'Autres notes';

  @override
  String get feedback => 'Avis';

  @override
  String get reportCard => 'Bulletin';

  @override
  String get reportCardNotGenerated => 'Bulletin non généré';

  @override
  String get reportCardNotPrepared => 'Bulletin non préparé';

  @override
  String get reportCardPrepared => 'Bulletin préparé';

  @override
  String reportCardLabel(Object period) {
    return 'Bulletin · $period';
  }

  @override
  String get reportCardNeedsUpdating => 'Bulletin à actualiser';

  @override
  String get campaignsAndArchives => 'Campagnes et archives';

  @override
  String get thisRecordIsUnavailableOrYourAccessHas =>
      'Ce dossier est indisponible ou vos droits d’accès ont changé.';

  @override
  String get thisProfileIsNoLongerAvailable =>
      'Ce profil n’est plus disponible.';

  @override
  String get helpCenter => 'Centre d\'aide';

  @override
  String get thisAssignmentIsNoLongerAvailable =>
      'Cette affectation n’est plus disponible.';

  @override
  String get thisAssessmentIsUnavailableOrYourAccessHas =>
      'Cette évaluation est indisponible ou vos droits ont changé.';

  @override
  String get changeClass => 'Changer de classe';

  @override
  String get chapters => 'Chapitres';

  @override
  String couldNotLoadStudents(Object error) {
    return 'Chargement des élèves impossible. $error';
  }

  @override
  String get chooseDate => 'Choisir la date';

  @override
  String get chooseAClass => 'Choisir une classe';

  @override
  String get classAndSubject => 'Classe et matière';

  @override
  String get selectAClassAndAPeriod => 'Classe et période requises';

  @override
  String get code => 'Code';

  @override
  String coefficient(Object coefficient) {
    return 'Coefficient $coefficient';
  }

  @override
  String get comment => 'Commentaire';

  @override
  String get staffComment => 'Commentaire de l\'équipe';

  @override
  String get commentSaved => 'Commentaire enregistré';

  @override
  String get generalComment => 'Commentaire général';

  @override
  String get homeroomTeacherComment => 'Commentaire titulaire';

  @override
  String get complete => 'Complet';

  @override
  String get theReportCardHasChangedReloadItAnd =>
      'Conflit de version : rechargez le bulletin et réconciliez votre commentaire.';

  @override
  String get instructions => 'Consignes';

  @override
  String get viewDailyAttendance => 'Consulter l’appel du jour';

  @override
  String get viewComment => 'Consulter l’appréciation';

  @override
  String get conversation => 'Conversation';

  @override
  String get create => 'Créer';

  @override
  String get createAssessment => 'Créer une évaluation';

  @override
  String get latestMark => 'Dernière note';

  @override
  String get documents => 'Documents';

  @override
  String get chargeDetails => 'Détail des frais';

  @override
  String pendingPupilCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'En attente · $count élèves',
      one: 'En attente · 1 élève',
      zero: 'En attente · 0 élèves',
    );
    return '$_temp0';
  }

  @override
  String get couldNotSaveChanges => 'Enregistrement impossible';

  @override
  String couldNotSaveChangesLabel(Object error) {
    return 'Enregistrement impossible. $error';
  }

  @override
  String get saveIncident => 'Enregistrer l’incident';

  @override
  String get teachingAssignments => 'Enseignements';

  @override
  String get entries => 'Entrées';

  @override
  String get invoice => 'Facture';

  @override
  String get takeDailyAttendance => 'Faire l’appel du jour';

  @override
  String get positiveIncident => 'Fait positif';

  @override
  String get whatHappened => 'Faits observés';

  @override
  String get closeAction => 'Fermer';

  @override
  String get dismissMessage => 'Fermer le message';

  @override
  String get chargeNotFound => 'Frais introuvables';

  @override
  String get schedule => 'Horaire';

  @override
  String get couldNotLoadTheCalendar => 'Impossible de charger le calendrier';

  @override
  String get couldNotLoadAssignmentsTryAgain =>
      'Impossible de charger les affectations. Réessayez.';

  @override
  String get couldNotLoadResultsTryAgain =>
      'Impossible de charger les résultats. Réessayez.';

  @override
  String get incident => 'Incident';

  @override
  String incidentSavedStillToLink(Object students, Object error) {
    return 'Incident enregistré. Élèves restant à associer : $students. $error';
  }

  @override
  String get incidents => 'Incidents';

  @override
  String get thePdfIsBeingGeneratedTryAgainShortly =>
      'Le PDF est en cours de génération. Réessayez dans un instant.';

  @override
  String get logbookEntriesWillAppearHereAsTheyAre =>
      'Le cahier de texte sera affiché ici au fur et à mesure.';

  @override
  String get reportCardsAreAvailableToTheHomeroomTeacher =>
      'Les bulletins sont réservés au titulaire de cette classe.';

  @override
  String get detailsAreHiddenUntilTheConfidentialityThresholdIs =>
      'Les détails sont masqués tant que le seuil de confidentialité n\'est pas atteint.';

  @override
  String get theseResultsReflectTheMostRecentCalculation =>
      'Les résultats ci-dessous sont ceux du dernier calcul.';

  @override
  String get downloadLinkUnavailable => 'Lien de téléchargement indisponible.';

  @override
  String read(Object date) {
    return 'Lu · $date';
  }

  @override
  String get theCommentWillBeAvailableOnceTheSchool =>
      'L’appréciation sera disponible lorsque l’établissement aura préparé le bulletin.';

  @override
  String get myClassesAndRoles => 'Mes classes et mes missions';

  @override
  String get messageNotFound => 'Message introuvable';

  @override
  String get unreadMessages => 'Messages non lus';

  @override
  String get paymentMethod => 'Mode';

  @override
  String get change => 'Modification';

  @override
  String get editComment => 'Modifier l’appréciation';

  @override
  String get myAccount => 'Mon compte';

  @override
  String get myProfile => 'Mon profil';

  @override
  String avgRank(Object average, Object rank) {
    return 'Moy. $average · Rang $rank';
  }

  @override
  String get periodAverage => 'Moyenne de la période';

  @override
  String get indicativeAverageAcrossTheSubjectsTracked =>
      'Moyenne indicative sur les matières suivies.';

  @override
  String averageRank(Object average, Object rank) {
    return 'Moyenne $average · Rang $rank';
  }

  @override
  String get incidentType => 'Nature du fait';

  @override
  String get name => 'Nom';

  @override
  String get studentSMark => 'Note de l\'élève';

  @override
  String get maximumScore => 'Note maximale';

  @override
  String officialMark(Object result) {
    return 'Note officielle · $result';
  }

  @override
  String get marks => 'Notes';

  @override
  String get newFeedbackFromHomePastFeedbackHere =>
      'Nouveaux retours depuis Accueil, historique ici';

  @override
  String get newFeedbackIsAvailablePastFeedbackStaysUnder =>
      'Nouveaux retours à consulter. L\'archive reste dans Évaluations.';

  @override
  String get newConversation => 'Nouvelle conversation';

  @override
  String get newAssessment => 'Nouvelle évaluation';

  @override
  String get openAllSettings => 'Ouvrir les paramètres complets';

  @override
  String get paymentNotFound => 'Paiement introuvable';

  @override
  String get parent => 'Parent';

  @override
  String get noSchool => 'Pas d\'école';

  @override
  String get photo => 'Photo';

  @override
  String get firstMessage => 'Premier message';

  @override
  String get studentProfile => 'Profil élève';

  @override
  String curriculum(Object percent) {
    return 'Programme · $percent %';
  }

  @override
  String get preferences => 'Préférences';

  @override
  String period(Object period) {
    return 'Période · $period';
  }

  @override
  String get searchForAStudent => 'Rechercher un élève';

  @override
  String get accountStatement => 'Relevé de compte';

  @override
  String get fillWithMaximumScore => 'Remplir max';

  @override
  String get guardianRecipient => 'Responsable destinataire';

  @override
  String guardiansUnavailable(Object error) {
    return 'Responsables indisponibles. $error';
  }

  @override
  String get backAction => 'Retour';

  @override
  String get paymentReceipt => 'Reçu de paiement';

  @override
  String get nothingScheduledForThisDay => 'Rien de prévu ce jour';

  @override
  String get retryLoadingAttendance => 'Réessayer le chargement de l’appel';

  @override
  String get retryLinkingStudents => 'Réessayer les associations';

  @override
  String get archivedResultsForThisCampaign =>
      'Résultat archivé pour cette campagne.';

  @override
  String get resultNotFound => 'Résultat introuvable';

  @override
  String get results => 'Résultats';

  @override
  String enterTheCodeSentTo(Object contact) {
    return 'Saisissez le code envoyé à $contact.';
  }

  @override
  String cannotAssess(Object count) {
    return 'Sans avis · $count';
  }

  @override
  String get noClassSpecified => 'Sans classe précisée';

  @override
  String get academics => 'Scolarité';

  @override
  String get confidentialityThreshold => 'Seuil de confidentialité';

  @override
  String get reportAnIncident => 'Signaler un incident';

  @override
  String couldNotSubmit(Object error) {
    return 'Soumission impossible : $error';
  }

  @override
  String get status => 'Statut';

  @override
  String get followUp => 'Suivi';

  @override
  String get session => 'Séance';

  @override
  String get sessionNotFound => 'Séance introuvable';

  @override
  String responseRate(Object percent) {
    return 'Taux de réponse · $percent %';
  }

  @override
  String get homeroomTeacher => 'Titulaire';

  @override
  String get viewAllAttendance => 'Toutes les présences';

  @override
  String get downloadReceipt => 'Télécharger le reçu';

  @override
  String get confirmEachMarkWithEnterOrNext =>
      'Validez chaque note avec Entrée ou Suivant.';

  @override
  String get yourAssignmentHasChangedAnotherTeachingAssignmentHas =>
      'Votre affectation a changé. Un autre enseignement a été sélectionné.';

  @override
  String get verifyCode => 'Vérifier le code';

  @override
  String ofTheCurriculumCovered(Object percent) {
    return '$percent % du programme couvert';
  }

  @override
  String paidLabel(Object percent) {
    return '$percent % réglé';
  }

  @override
  String returnToResults(Object error) {
    return '$error Retour aux résultats.';
  }

  @override
  String pendingCommentCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count commentaires en attente',
      one: '1 commentaire en attente',
      zero: '0 commentaires en attente',
    );
    return '$_temp0';
  }

  @override
  String overdueChargesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count lignes de frais en retard',
      one: '1 ligne de frais en retard',
      zero: '0 lignes de frais en retard',
    );
    return '$_temp0';
  }

  @override
  String responseCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count réponses',
      one: '1 réponse',
      zero: '0 réponses',
    );
    return '$_temp0';
  }

  @override
  String rank(Object label, Object average, Object rank) {
    return '$label $average · Rang $rank';
  }

  @override
  String pendingApproval(Object label, Object proposal) {
    return '$label · En attente d’approbation : $proposal';
  }

  @override
  String homeroomTeacherLabel(Object subject) {
    return '$subject · Titulaire';
  }

  @override
  String pendingLabel(Object className, Object count) {
    return '$className · $count en attente';
  }

  @override
  String gradedLabel(
    Object className,
    Object period,
    Object graded,
    Object total,
  ) {
    return '$className · $period · $graded/$total notés';
  }

  @override
  String subjectPupilCount(Object subject, Object count) {
    return '$subject · $count élèves';
  }

  @override
  String toRead(Object count) {
    return '$count à lire';
  }

  @override
  String surveyResponseRatio(Object completed, Object eligible) {
    return '$completed/$eligible réponses';
  }

  @override
  String get dueDateLabel => 'Échéance';

  @override
  String get dueDateRequired => 'Échéance requise';

  @override
  String due(Object date) {
    return 'Échéance · $date';
  }

  @override
  String get feeInstallments => 'Échéances';

  @override
  String get student => 'Élève';

  @override
  String get studentNotFound => 'Élève introuvable';

  @override
  String get studentNotFoundForThisSurvey => 'Élève introuvable pour cet avis.';

  @override
  String get students => 'Élèves';

  @override
  String get assessmentNotFound => 'Évaluation introuvable';

  @override
  String get assessmentWorkspace => 'Évaluations';

  @override
  String get attendanceSubmitFailed =>
      'Impossible de transmettre l’appel. Réessayez.';

  @override
  String get attendanceSaveFailed =>
      'Impossible d’enregistrer la modification de présence.';

  @override
  String get attendanceCorrectionHint =>
      'Demandez une correction pour modifier un appel transmis.';

  @override
  String get commentCorrectionFailed =>
      'Impossible d’envoyer la demande de correction du commentaire. Réessayez.';

  @override
  String get calendarHoliday => 'Jour férié';

  @override
  String get calendarBreak => 'Vacances scolaires';

  @override
  String get calendarEvent => 'Événement';

  @override
  String get paperSchoolCertificate => 'Certificat de scolarité';

  @override
  String get paperEnrollment => 'Dossier d’inscription';

  @override
  String get paperStudentId => 'Carte d’élève';

  @override
  String get paperWithdrawal => 'Certificat de radiation';

  @override
  String get paperSummons => 'Convocation';

  @override
  String get feedbackCommunication => 'Communication';

  @override
  String get feedbackClarity => 'Clarté des attentes';

  @override
  String get feedbackSupport => 'Accompagnement de l’élève';

  @override
  String get feedbackExperience => 'Expérience de l’élève';

  @override
  String get feedbackQuestion => 'Question du questionnaire';

  @override
  String get guardianPushDescription =>
      'Actualités et alertes de l’établissement pour les familles';

  @override
  String get teacherPushDescription =>
      'Actualités et alertes de l’établissement pour le personnel';

  @override
  String duplicateTitle(String title) {
    return '$title (copie)';
  }

  @override
  String get schoolSessionUnavailable =>
      'Impossible d’ouvrir votre session scolaire. Réessayez.';

  @override
  String get verificationInvalid => 'Code invalide ou expiré.';

  @override
  String sessionsToday(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count séances aujourd’hui',
      one: '1 séance aujourd’hui',
      zero: '0 séances aujourd’hui',
    );
    return '$_temp0';
  }

  @override
  String availableMarks(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count notes disponibles',
      one: '1 note disponible',
      zero: '0 notes disponibles',
    );
    return '$_temp0';
  }

  @override
  String absenceCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count absences',
      one: '1 absence',
      zero: '0 absences',
    );
    return '$_temp0';
  }

  @override
  String lateArrivals(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count retards',
      one: '1 retard',
      zero: '0 retards',
    );
    return '$_temp0';
  }

  @override
  String surveyCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count questionnaires',
      one: '1 questionnaire',
      zero: '0 questionnaires',
    );
    return '$_temp0';
  }

  @override
  String openSurveyCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count questionnaires ouverts',
      one: '1 questionnaire ouvert',
      zero: '0 questionnaires ouverts',
    );
    return '$_temp0';
  }

  @override
  String availableDocuments(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count documents disponibles',
      one: '1 document disponible',
      zero: '0 documents disponibles',
    );
    return '$_temp0';
  }

  @override
  String get outboxCorrection => 'Demande de correction';

  @override
  String get accountActionFailed =>
      'Impossible de terminer cette opération sur votre compte. Réessayez.';

  @override
  String get academicSubjects => 'Enseignements';
}
