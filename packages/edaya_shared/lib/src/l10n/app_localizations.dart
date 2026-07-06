import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_fr.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('fr'),
  ];

  /// No description provided for @appTitleGuardian.
  ///
  /// In en, this message translates to:
  /// **'Edaya'**
  String get appTitleGuardian;

  /// No description provided for @appTitleTeacher.
  ///
  /// In en, this message translates to:
  /// **'Edaya Staff'**
  String get appTitleTeacher;

  /// No description provided for @accountTitle.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get accountTitle;

  /// No description provided for @accountProfileTitle.
  ///
  /// In en, this message translates to:
  /// **'Contact profile'**
  String get accountProfileTitle;

  /// No description provided for @accountProfileDescription.
  ///
  /// In en, this message translates to:
  /// **'Update the name and contact details shown to the school.'**
  String get accountProfileDescription;

  /// No description provided for @accountProfileLoginEmail.
  ///
  /// In en, this message translates to:
  /// **'Sign-in email: {email}'**
  String accountProfileLoginEmail(String email);

  /// No description provided for @accountProfileUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Your school profile is not available.'**
  String get accountProfileUnavailable;

  /// No description provided for @accountProfileLoadError.
  ///
  /// In en, this message translates to:
  /// **'Could not load your profile. {error}'**
  String accountProfileLoadError(String error);

  /// No description provided for @accountProfileSaveError.
  ///
  /// In en, this message translates to:
  /// **'Could not save your profile. {error}'**
  String accountProfileSaveError(String error);

  /// No description provided for @accountProfileUpdateSuccess.
  ///
  /// In en, this message translates to:
  /// **'Profile updated.'**
  String get accountProfileUpdateSuccess;

  /// No description provided for @firstNameLabel.
  ///
  /// In en, this message translates to:
  /// **'First name'**
  String get firstNameLabel;

  /// No description provided for @lastNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Last name'**
  String get lastNameLabel;

  /// No description provided for @phoneLabel.
  ///
  /// In en, this message translates to:
  /// **'Phone'**
  String get phoneLabel;

  /// No description provided for @signingOut.
  ///
  /// In en, this message translates to:
  /// **'Signing out…'**
  String get signingOut;

  /// No description provided for @signOut.
  ///
  /// In en, this message translates to:
  /// **'Sign out'**
  String get signOut;

  /// No description provided for @nothingToShowYet.
  ///
  /// In en, this message translates to:
  /// **'Nothing to show yet.'**
  String get nothingToShowYet;

  /// No description provided for @somethingWentWrong.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong.'**
  String get somethingWentWrong;

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// No description provided for @signInTitle.
  ///
  /// In en, this message translates to:
  /// **'Sign in'**
  String get signInTitle;

  /// No description provided for @signInButton.
  ///
  /// In en, this message translates to:
  /// **'Sign in'**
  String get signInButton;

  /// No description provided for @emailLabel.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get emailLabel;

  /// No description provided for @passwordLabel.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get passwordLabel;

  /// No description provided for @signInFailed.
  ///
  /// In en, this message translates to:
  /// **'Sign-in failed'**
  String get signInFailed;

  /// No description provided for @signedInSchoolSessionUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Signed in, but school session is unavailable: {error}'**
  String signedInSchoolSessionUnavailable(String error);

  /// No description provided for @apiUrlCannotBeEmpty.
  ///
  /// In en, this message translates to:
  /// **'API URL cannot be empty'**
  String get apiUrlCannotBeEmpty;

  /// No description provided for @enterValidApiUrl.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid API URL'**
  String get enterValidApiUrl;

  /// No description provided for @restartRequired.
  ///
  /// In en, this message translates to:
  /// **'Restart required'**
  String get restartRequired;

  /// No description provided for @apiUrlUpdatedReloadPage.
  ///
  /// In en, this message translates to:
  /// **'API URL updated to {url}. Reload the page to connect to the new server.'**
  String apiUrlUpdatedReloadPage(String url);

  /// No description provided for @apiUrlUpdatedRestartApp.
  ///
  /// In en, this message translates to:
  /// **'API URL updated to {url}. Restart the app to connect to the new server.'**
  String apiUrlUpdatedRestartApp(String url);

  /// No description provided for @restartApp.
  ///
  /// In en, this message translates to:
  /// **'Restart app'**
  String get restartApp;

  /// No description provided for @ok.
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get ok;

  /// No description provided for @currentApiUrl.
  ///
  /// In en, this message translates to:
  /// **'Current: {url}'**
  String currentApiUrl(String url);

  /// No description provided for @usingSavedDevOverride.
  ///
  /// In en, this message translates to:
  /// **'Using saved dev override'**
  String get usingSavedDevOverride;

  /// No description provided for @apiBaseUrlLabel.
  ///
  /// In en, this message translates to:
  /// **'API base URL'**
  String get apiBaseUrlLabel;

  /// No description provided for @presetLocalhost.
  ///
  /// In en, this message translates to:
  /// **'Localhost'**
  String get presetLocalhost;

  /// No description provided for @presetAndroidEmulator.
  ///
  /// In en, this message translates to:
  /// **'Android emulator'**
  String get presetAndroidEmulator;

  /// No description provided for @presetStaging.
  ///
  /// In en, this message translates to:
  /// **'Staging'**
  String get presetStaging;

  /// No description provided for @presetProduction.
  ///
  /// In en, this message translates to:
  /// **'Production'**
  String get presetProduction;

  /// No description provided for @presetLanEditIp.
  ///
  /// In en, this message translates to:
  /// **'LAN (edit IP)'**
  String get presetLanEditIp;

  /// No description provided for @resetDefault.
  ///
  /// In en, this message translates to:
  /// **'Reset default'**
  String get resetDefault;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @developerSettings.
  ///
  /// In en, this message translates to:
  /// **'Developer settings'**
  String get developerSettings;

  /// No description provided for @loginSubtitleGuardianDev.
  ///
  /// In en, this message translates to:
  /// **'Use dev guardian credentials to test against the local API.'**
  String get loginSubtitleGuardianDev;

  /// No description provided for @loginSubtitleStaffDev.
  ///
  /// In en, this message translates to:
  /// **'Use dev staff credentials to test against the local API.'**
  String get loginSubtitleStaffDev;

  /// No description provided for @missingSessionDetailsRouteData.
  ///
  /// In en, this message translates to:
  /// **'Missing session details route data.'**
  String get missingSessionDetailsRouteData;

  /// No description provided for @missingGradeDetailsRouteData.
  ///
  /// In en, this message translates to:
  /// **'Missing grade details route data.'**
  String get missingGradeDetailsRouteData;

  /// No description provided for @missingReportCardRouteData.
  ///
  /// In en, this message translates to:
  /// **'Missing report card route data.'**
  String get missingReportCardRouteData;

  /// No description provided for @missingPaymentDetailsRouteData.
  ///
  /// In en, this message translates to:
  /// **'Missing payment details route data.'**
  String get missingPaymentDetailsRouteData;

  /// No description provided for @missingMessageDetailsRouteData.
  ///
  /// In en, this message translates to:
  /// **'Missing message details route data.'**
  String get missingMessageDetailsRouteData;

  /// No description provided for @missingAttendanceFlowRouteData.
  ///
  /// In en, this message translates to:
  /// **'Missing attendance flow route data.'**
  String get missingAttendanceFlowRouteData;

  /// No description provided for @missingMarksEntryRouteData.
  ///
  /// In en, this message translates to:
  /// **'Missing marks entry route data.'**
  String get missingMarksEntryRouteData;

  /// No description provided for @signedInNoGuardianProfile.
  ///
  /// In en, this message translates to:
  /// **'Signed in, but no linked guardian/staff profile. Run: bun seed --scope auth:link'**
  String get signedInNoGuardianProfile;

  /// No description provided for @signedInNoStaffProfile.
  ///
  /// In en, this message translates to:
  /// **'Signed in, but no linked staff profile. Run: bun seed --scope auth:link'**
  String get signedInNoStaffProfile;

  /// No description provided for @signedInNoTeacherProfile.
  ///
  /// In en, this message translates to:
  /// **'Signed in, but no linked teacher profile. Run: bun seed --scope auth:link'**
  String get signedInNoTeacherProfile;

  /// No description provided for @accountNotLinkedToStaff.
  ///
  /// In en, this message translates to:
  /// **'This account is not linked to a staff profile.'**
  String get accountNotLinkedToStaff;

  /// No description provided for @accountNotLinkedToTeacher.
  ///
  /// In en, this message translates to:
  /// **'This account is not linked to a teacher profile.'**
  String get accountNotLinkedToTeacher;

  /// No description provided for @navCalendar.
  ///
  /// In en, this message translates to:
  /// **'Calendar'**
  String get navCalendar;

  /// No description provided for @navAcademic.
  ///
  /// In en, this message translates to:
  /// **'Academic'**
  String get navAcademic;

  /// No description provided for @navFees.
  ///
  /// In en, this message translates to:
  /// **'Fees'**
  String get navFees;

  /// No description provided for @navInbox.
  ///
  /// In en, this message translates to:
  /// **'Inbox'**
  String get navInbox;

  /// No description provided for @navEvaluations.
  ///
  /// In en, this message translates to:
  /// **'Evaluations'**
  String get navEvaluations;

  /// No description provided for @navTeaching.
  ///
  /// In en, this message translates to:
  /// **'Teaching'**
  String get navTeaching;

  /// No description provided for @navReportCards.
  ///
  /// In en, this message translates to:
  /// **'Report cards'**
  String get navReportCards;

  /// No description provided for @teachingTitle.
  ///
  /// In en, this message translates to:
  /// **'Teaching'**
  String get teachingTitle;

  /// No description provided for @reportCardsTitle.
  ///
  /// In en, this message translates to:
  /// **'Report cards'**
  String get reportCardsTitle;

  /// No description provided for @teachingSelectClass.
  ///
  /// In en, this message translates to:
  /// **'Class'**
  String get teachingSelectClass;

  /// No description provided for @teachingSelectSubject.
  ///
  /// In en, this message translates to:
  /// **'Subject'**
  String get teachingSelectSubject;

  /// No description provided for @teachingProgressTab.
  ///
  /// In en, this message translates to:
  /// **'Progress'**
  String get teachingProgressTab;

  /// No description provided for @teachingLogbookTab.
  ///
  /// In en, this message translates to:
  /// **'Logbook'**
  String get teachingLogbookTab;

  /// No description provided for @noTeachingLogEntries.
  ///
  /// In en, this message translates to:
  /// **'No logbook entries for this subject yet.'**
  String get noTeachingLogEntries;

  /// No description provided for @couldNotLoadTeachingData.
  ///
  /// In en, this message translates to:
  /// **'Could not load teaching data: {error}'**
  String couldNotLoadTeachingData(String error);

  /// No description provided for @couldNotLoadReportCards.
  ///
  /// In en, this message translates to:
  /// **'Could not load report cards: {error}'**
  String couldNotLoadReportCards(String error);

  /// No description provided for @reportCardClassNoResults.
  ///
  /// In en, this message translates to:
  /// **'No report cards generated for this period.'**
  String get reportCardClassNoResults;

  /// No description provided for @reportCardClassProgress.
  ///
  /// In en, this message translates to:
  /// **'{filled} / {total} comments filled'**
  String reportCardClassProgress(int filled, int total);

  /// No description provided for @reportCardRosterComingSoon.
  ///
  /// In en, this message translates to:
  /// **'Student roster coming soon.'**
  String get reportCardRosterComingSoon;

  /// No description provided for @tooltipAccount.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get tooltipAccount;

  /// No description provided for @loading.
  ///
  /// In en, this message translates to:
  /// **'Loading…'**
  String get loading;

  /// No description provided for @selectAStudent.
  ///
  /// In en, this message translates to:
  /// **'Select a student'**
  String get selectAStudent;

  /// No description provided for @notEnrolled.
  ///
  /// In en, this message translates to:
  /// **'Not enrolled'**
  String get notEnrolled;

  /// No description provided for @schoolYear.
  ///
  /// In en, this message translates to:
  /// **'School year'**
  String get schoolYear;

  /// No description provided for @tooltipMyStudents.
  ///
  /// In en, this message translates to:
  /// **'My students'**
  String get tooltipMyStudents;

  /// No description provided for @unknownUser.
  ///
  /// In en, this message translates to:
  /// **'Unknown user'**
  String get unknownUser;

  /// No description provided for @noAcademicYearsAvailable.
  ///
  /// In en, this message translates to:
  /// **'No academic years available.'**
  String get noAcademicYearsAvailable;

  /// No description provided for @activeYear.
  ///
  /// In en, this message translates to:
  /// **'Active year'**
  String get activeYear;

  /// No description provided for @couldNotLoadAcademicYears.
  ///
  /// In en, this message translates to:
  /// **'Could not load academic years: {error}'**
  String couldNotLoadAcademicYears(String error);

  /// No description provided for @couldNotLoadStudentContext.
  ///
  /// In en, this message translates to:
  /// **'Could not load student context: {error}'**
  String couldNotLoadStudentContext(String error);

  /// No description provided for @couldNotLoadEnrollment.
  ///
  /// In en, this message translates to:
  /// **'Could not load enrollment: {error}'**
  String couldNotLoadEnrollment(String error);

  /// No description provided for @myStudents.
  ///
  /// In en, this message translates to:
  /// **'My students'**
  String get myStudents;

  /// No description provided for @noLinkedStudentsFound.
  ///
  /// In en, this message translates to:
  /// **'No linked students found.'**
  String get noLinkedStudentsFound;

  /// No description provided for @matriculeLabel.
  ///
  /// In en, this message translates to:
  /// **'Matricule: {matricule}'**
  String matriculeLabel(String matricule);

  /// No description provided for @statusLabel.
  ///
  /// In en, this message translates to:
  /// **'Status: {status}'**
  String statusLabel(String status);

  /// No description provided for @couldNotLoadLinkedStudents.
  ///
  /// In en, this message translates to:
  /// **'Could not load linked students: {error}'**
  String couldNotLoadLinkedStudents(String error);

  /// No description provided for @calendarViewTimetable.
  ///
  /// In en, this message translates to:
  /// **'Timetable'**
  String get calendarViewTimetable;

  /// No description provided for @calendarViewEvents.
  ///
  /// In en, this message translates to:
  /// **'Events'**
  String get calendarViewEvents;

  /// No description provided for @allAttendance.
  ///
  /// In en, this message translates to:
  /// **'All attendance'**
  String get allAttendance;

  /// No description provided for @selectStudentToViewCalendar.
  ///
  /// In en, this message translates to:
  /// **'Select a student to view the calendar.'**
  String get selectStudentToViewCalendar;

  /// No description provided for @studentNotEnrolledForYear.
  ///
  /// In en, this message translates to:
  /// **'This student is not enrolled for the selected school year.'**
  String get studentNotEnrolledForYear;

  /// No description provided for @noClassesScheduledForDay.
  ///
  /// In en, this message translates to:
  /// **'No classes scheduled for this day.'**
  String get noClassesScheduledForDay;

  /// No description provided for @noSchoolEventsForPeriod.
  ///
  /// In en, this message translates to:
  /// **'No school events for this period.'**
  String get noSchoolEventsForPeriod;

  /// No description provided for @couldNotLoadCalendar.
  ///
  /// In en, this message translates to:
  /// **'Could not load calendar: {error}'**
  String couldNotLoadCalendar(String error);

  /// No description provided for @couldNotLoadSessionDetails.
  ///
  /// In en, this message translates to:
  /// **'Could not load session details: {error}'**
  String couldNotLoadSessionDetails(String error);

  /// No description provided for @couldNotLoadAttendance.
  ///
  /// In en, this message translates to:
  /// **'Could not load attendance: {error}'**
  String couldNotLoadAttendance(String error);

  /// No description provided for @attendance.
  ///
  /// In en, this message translates to:
  /// **'Attendance'**
  String get attendance;

  /// No description provided for @timetableSessionKindLesson.
  ///
  /// In en, this message translates to:
  /// **'Lesson'**
  String get timetableSessionKindLesson;

  /// No description provided for @timetableSessionKindActivity.
  ///
  /// In en, this message translates to:
  /// **'Activity'**
  String get timetableSessionKindActivity;

  /// No description provided for @timetableSessionKindAssessment.
  ///
  /// In en, this message translates to:
  /// **'Assessment'**
  String get timetableSessionKindAssessment;

  /// No description provided for @noAttendanceRecorded.
  ///
  /// In en, this message translates to:
  /// **'No attendance recorded.'**
  String get noAttendanceRecorded;

  /// No description provided for @classLogbook.
  ///
  /// In en, this message translates to:
  /// **'Class logbook'**
  String get classLogbook;

  /// No description provided for @noLogbookEntryForSession.
  ///
  /// In en, this message translates to:
  /// **'No logbook entry for this session.'**
  String get noLogbookEntryForSession;

  /// No description provided for @homeworkLabel.
  ///
  /// In en, this message translates to:
  /// **'Homework'**
  String get homeworkLabel;

  /// No description provided for @homeworkValue.
  ///
  /// In en, this message translates to:
  /// **'Homework: {homework}'**
  String homeworkValue(String homework);

  /// No description provided for @progressPercent.
  ///
  /// In en, this message translates to:
  /// **'Progress: {percent}%'**
  String progressPercent(int percent);

  /// No description provided for @noAttendanceRecordsForStudent.
  ///
  /// In en, this message translates to:
  /// **'No attendance records for this student.'**
  String get noAttendanceRecordsForStudent;

  /// No description provided for @tooltipPreviousWeek.
  ///
  /// In en, this message translates to:
  /// **'Previous week'**
  String get tooltipPreviousWeek;

  /// No description provided for @tooltipNextWeek.
  ///
  /// In en, this message translates to:
  /// **'Next week'**
  String get tooltipNextWeek;

  /// No description provided for @dayLetterMon.
  ///
  /// In en, this message translates to:
  /// **'M'**
  String get dayLetterMon;

  /// No description provided for @dayLetterTue.
  ///
  /// In en, this message translates to:
  /// **'T'**
  String get dayLetterTue;

  /// No description provided for @dayLetterWed.
  ///
  /// In en, this message translates to:
  /// **'W'**
  String get dayLetterWed;

  /// No description provided for @dayLetterThu.
  ///
  /// In en, this message translates to:
  /// **'T'**
  String get dayLetterThu;

  /// No description provided for @dayLetterFri.
  ///
  /// In en, this message translates to:
  /// **'F'**
  String get dayLetterFri;

  /// No description provided for @dayLetterSat.
  ///
  /// In en, this message translates to:
  /// **'S'**
  String get dayLetterSat;

  /// No description provided for @dayLetterSun.
  ///
  /// In en, this message translates to:
  /// **'S'**
  String get dayLetterSun;

  /// No description provided for @academicViewGrades.
  ///
  /// In en, this message translates to:
  /// **'Grades'**
  String get academicViewGrades;

  /// No description provided for @academicViewCurriculum.
  ///
  /// In en, this message translates to:
  /// **'Curriculum'**
  String get academicViewCurriculum;

  /// No description provided for @academicViewReports.
  ///
  /// In en, this message translates to:
  /// **'Reports'**
  String get academicViewReports;

  /// No description provided for @allPeriods.
  ///
  /// In en, this message translates to:
  /// **'All periods'**
  String get allPeriods;

  /// No description provided for @selectStudentToViewAcademic.
  ///
  /// In en, this message translates to:
  /// **'Select a student to view academic information.'**
  String get selectStudentToViewAcademic;

  /// No description provided for @noGradesForPeriod.
  ///
  /// In en, this message translates to:
  /// **'No grades recorded for this period.'**
  String get noGradesForPeriod;

  /// No description provided for @noCurriculumProgressYet.
  ///
  /// In en, this message translates to:
  /// **'No curriculum progress available yet.'**
  String get noCurriculumProgressYet;

  /// No description provided for @noReportCardsYet.
  ///
  /// In en, this message translates to:
  /// **'No published report cards yet.'**
  String get noReportCardsYet;

  /// No description provided for @couldNotLoadAcademicData.
  ///
  /// In en, this message translates to:
  /// **'Could not load academic data: {error}'**
  String couldNotLoadAcademicData(String error);

  /// No description provided for @couldNotLoadReportCard.
  ///
  /// In en, this message translates to:
  /// **'Could not load report card: {error}'**
  String couldNotLoadReportCard(String error);

  /// No description provided for @subjectFallback.
  ///
  /// In en, this message translates to:
  /// **'Subject'**
  String get subjectFallback;

  /// No description provided for @periodFallback.
  ///
  /// In en, this message translates to:
  /// **'Period'**
  String get periodFallback;

  /// No description provided for @unitFallback.
  ///
  /// In en, this message translates to:
  /// **'Unit'**
  String get unitFallback;

  /// No description provided for @gradePeriodCoefficient.
  ///
  /// In en, this message translates to:
  /// **'{periodName} · Coefficient {coefficient}'**
  String gradePeriodCoefficient(String periodName, String coefficient);

  /// No description provided for @score.
  ///
  /// In en, this message translates to:
  /// **'Score'**
  String get score;

  /// No description provided for @notGradedYet.
  ///
  /// In en, this message translates to:
  /// **'Not graded yet'**
  String get notGradedYet;

  /// No description provided for @notes.
  ///
  /// In en, this message translates to:
  /// **'Notes'**
  String get notes;

  /// No description provided for @average.
  ///
  /// In en, this message translates to:
  /// **'Average'**
  String get average;

  /// No description provided for @scoreOutOfTwenty.
  ///
  /// In en, this message translates to:
  /// **'/ 20'**
  String get scoreOutOfTwenty;

  /// No description provided for @graded.
  ///
  /// In en, this message translates to:
  /// **'Graded'**
  String get graded;

  /// No description provided for @pending.
  ///
  /// In en, this message translates to:
  /// **'Pending'**
  String get pending;

  /// No description provided for @assessmentCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 assessment} other{{count} assessments}}'**
  String assessmentCount(int count);

  /// No description provided for @subjectAverage.
  ///
  /// In en, this message translates to:
  /// **'Average {average} / 20'**
  String subjectAverage(String average);

  /// No description provided for @noScoreDash.
  ///
  /// In en, this message translates to:
  /// **'—'**
  String get noScoreDash;

  /// No description provided for @percentComplete.
  ///
  /// In en, this message translates to:
  /// **'{percent}% complete'**
  String percentComplete(int percent);

  /// No description provided for @noProgrammeUnitsTracked.
  ///
  /// In en, this message translates to:
  /// **'No programme units tracked yet.'**
  String get noProgrammeUnitsTracked;

  /// No description provided for @publishedReportCard.
  ///
  /// In en, this message translates to:
  /// **'Published report card'**
  String get publishedReportCard;

  /// No description provided for @publishedOn.
  ///
  /// In en, this message translates to:
  /// **'Published {date}'**
  String publishedOn(String date);

  /// No description provided for @scoreOutOfTwentyValue.
  ///
  /// In en, this message translates to:
  /// **'{average} / 20'**
  String scoreOutOfTwentyValue(String average);

  /// No description provided for @rankLabel.
  ///
  /// In en, this message translates to:
  /// **'Rank {rank}/{classSize}'**
  String rankLabel(int rank, int classSize);

  /// No description provided for @reportCardNotFound.
  ///
  /// In en, this message translates to:
  /// **'Report card not found.'**
  String get reportCardNotFound;

  /// No description provided for @overallAverage.
  ///
  /// In en, this message translates to:
  /// **'Overall average: {average} / 20'**
  String overallAverage(String average);

  /// No description provided for @classRank.
  ///
  /// In en, this message translates to:
  /// **'Class rank: {rank}/{classSize}'**
  String classRank(int rank, int classSize);

  /// No description provided for @homeroomComment.
  ///
  /// In en, this message translates to:
  /// **'Homeroom comment'**
  String get homeroomComment;

  /// No description provided for @principalComment.
  ///
  /// In en, this message translates to:
  /// **'Principal comment'**
  String get principalComment;

  /// No description provided for @feeLinesSection.
  ///
  /// In en, this message translates to:
  /// **'Fee lines'**
  String get feeLinesSection;

  /// No description provided for @noFeeLinesForYear.
  ///
  /// In en, this message translates to:
  /// **'No fee lines for this school year.'**
  String get noFeeLinesForYear;

  /// No description provided for @paymentsSection.
  ///
  /// In en, this message translates to:
  /// **'Payments'**
  String get paymentsSection;

  /// No description provided for @noPaymentsRecordedYet.
  ///
  /// In en, this message translates to:
  /// **'No payments recorded yet.'**
  String get noPaymentsRecordedYet;

  /// No description provided for @selectStudentToViewFees.
  ///
  /// In en, this message translates to:
  /// **'Select a student to view fees and payments.'**
  String get selectStudentToViewFees;

  /// No description provided for @noFeesOrPaymentsForYear.
  ///
  /// In en, this message translates to:
  /// **'No fee lines or payments for the selected school year.'**
  String get noFeesOrPaymentsForYear;

  /// No description provided for @schoolFee.
  ///
  /// In en, this message translates to:
  /// **'School fee'**
  String get schoolFee;

  /// No description provided for @couldNotLoadFees.
  ///
  /// In en, this message translates to:
  /// **'Could not load fees: {error}'**
  String couldNotLoadFees(String error);

  /// No description provided for @paymentMethodCash.
  ///
  /// In en, this message translates to:
  /// **'Cash'**
  String get paymentMethodCash;

  /// No description provided for @paymentMethodCard.
  ///
  /// In en, this message translates to:
  /// **'Card'**
  String get paymentMethodCard;

  /// No description provided for @paymentMethodBankTransfer.
  ///
  /// In en, this message translates to:
  /// **'Bank transfer'**
  String get paymentMethodBankTransfer;

  /// No description provided for @paymentMethodMobileMoney.
  ///
  /// In en, this message translates to:
  /// **'Mobile money'**
  String get paymentMethodMobileMoney;

  /// No description provided for @paymentMethodOther.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get paymentMethodOther;

  /// No description provided for @feeStatusPaid.
  ///
  /// In en, this message translates to:
  /// **'Paid'**
  String get feeStatusPaid;

  /// No description provided for @feeStatusPartiallyPaid.
  ///
  /// In en, this message translates to:
  /// **'Partially paid'**
  String get feeStatusPartiallyPaid;

  /// No description provided for @feeStatusOverdue.
  ///
  /// In en, this message translates to:
  /// **'Overdue'**
  String get feeStatusOverdue;

  /// No description provided for @feeStatusCancelled.
  ///
  /// In en, this message translates to:
  /// **'Cancelled'**
  String get feeStatusCancelled;

  /// No description provided for @feeStatusDue.
  ///
  /// In en, this message translates to:
  /// **'Due'**
  String get feeStatusDue;

  /// No description provided for @summary.
  ///
  /// In en, this message translates to:
  /// **'Summary'**
  String get summary;

  /// No description provided for @expected.
  ///
  /// In en, this message translates to:
  /// **'Expected'**
  String get expected;

  /// No description provided for @paid.
  ///
  /// In en, this message translates to:
  /// **'Paid'**
  String get paid;

  /// No description provided for @balance.
  ///
  /// In en, this message translates to:
  /// **'Balance'**
  String get balance;

  /// No description provided for @overdueFeeLinesCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 overdue fee line} other{{count} overdue fee lines}}'**
  String overdueFeeLinesCount(int count);

  /// No description provided for @dueDate.
  ///
  /// In en, this message translates to:
  /// **'Due {date}'**
  String dueDate(String date);

  /// No description provided for @paymentCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 payment} other{{count} payments}}'**
  String paymentCount(int count);

  /// No description provided for @paidAmount.
  ///
  /// In en, this message translates to:
  /// **'Paid {amount}'**
  String paidAmount(String amount);

  /// No description provided for @paymentDetails.
  ///
  /// In en, this message translates to:
  /// **'Payment details'**
  String get paymentDetails;

  /// No description provided for @amount.
  ///
  /// In en, this message translates to:
  /// **'Amount'**
  String get amount;

  /// No description provided for @date.
  ///
  /// In en, this message translates to:
  /// **'Date'**
  String get date;

  /// No description provided for @method.
  ///
  /// In en, this message translates to:
  /// **'Method'**
  String get method;

  /// No description provided for @reference.
  ///
  /// In en, this message translates to:
  /// **'Reference'**
  String get reference;

  /// No description provided for @unreadCount.
  ///
  /// In en, this message translates to:
  /// **'{count} unread'**
  String unreadCount(int count);

  /// No description provided for @noMessagesInInbox.
  ///
  /// In en, this message translates to:
  /// **'No messages in your inbox yet.'**
  String get noMessagesInInbox;

  /// No description provided for @couldNotLoadInbox.
  ///
  /// In en, this message translates to:
  /// **'Could not load inbox: {error}'**
  String couldNotLoadInbox(String error);

  /// No description provided for @inboxStatusPending.
  ///
  /// In en, this message translates to:
  /// **'Pending'**
  String get inboxStatusPending;

  /// No description provided for @inboxStatusNew.
  ///
  /// In en, this message translates to:
  /// **'New'**
  String get inboxStatusNew;

  /// No description provided for @inboxStatusFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed'**
  String get inboxStatusFailed;

  /// No description provided for @inboxStatusRead.
  ///
  /// In en, this message translates to:
  /// **'Read'**
  String get inboxStatusRead;

  /// No description provided for @inboxStatusCancelled.
  ///
  /// In en, this message translates to:
  /// **'Cancelled'**
  String get inboxStatusCancelled;

  /// No description provided for @messageDefaultTitle.
  ///
  /// In en, this message translates to:
  /// **'Message'**
  String get messageDefaultTitle;

  /// No description provided for @messageTitle.
  ///
  /// In en, this message translates to:
  /// **'Message'**
  String get messageTitle;

  /// No description provided for @couldNotMarkMessageRead.
  ///
  /// In en, this message translates to:
  /// **'Could not mark message as read: {error}'**
  String couldNotMarkMessageRead(String error);

  /// No description provided for @allClasses.
  ///
  /// In en, this message translates to:
  /// **'All classes'**
  String get allClasses;

  /// No description provided for @evaluationsTitle.
  ///
  /// In en, this message translates to:
  /// **'Evaluations'**
  String get evaluationsTitle;

  /// No description provided for @calendarTitle.
  ///
  /// In en, this message translates to:
  /// **'Calendar'**
  String get calendarTitle;

  /// No description provided for @evaluationCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 evaluation} other{{count} evaluations}}'**
  String evaluationCount(int count);

  /// No description provided for @sessionCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 session} other{{count} sessions}}'**
  String sessionCount(int count);

  /// No description provided for @tooltipNewEvaluation.
  ///
  /// In en, this message translates to:
  /// **'New evaluation'**
  String get tooltipNewEvaluation;

  /// No description provided for @tooltipFilter.
  ///
  /// In en, this message translates to:
  /// **'Filter'**
  String get tooltipFilter;

  /// No description provided for @teacherFallbackName.
  ///
  /// In en, this message translates to:
  /// **'Teacher'**
  String get teacherFallbackName;

  /// No description provided for @filterTitle.
  ///
  /// In en, this message translates to:
  /// **'Filter'**
  String get filterTitle;

  /// No description provided for @classLabel.
  ///
  /// In en, this message translates to:
  /// **'Class'**
  String get classLabel;

  /// No description provided for @couldNotLoadTeachingContext.
  ///
  /// In en, this message translates to:
  /// **'Could not load teaching context: {error}'**
  String couldNotLoadTeachingContext(String error);

  /// No description provided for @signInToViewCalendar.
  ///
  /// In en, this message translates to:
  /// **'Sign in to view your teaching calendar.'**
  String get signInToViewCalendar;

  /// No description provided for @noClassesAssignedForYear.
  ///
  /// In en, this message translates to:
  /// **'No classes assigned for this school year.'**
  String get noClassesAssignedForYear;

  /// No description provided for @classSessionFallback.
  ///
  /// In en, this message translates to:
  /// **'Class session'**
  String get classSessionFallback;

  /// No description provided for @logbook.
  ///
  /// In en, this message translates to:
  /// **'Logbook'**
  String get logbook;

  /// No description provided for @attendanceProgress.
  ///
  /// In en, this message translates to:
  /// **'Attendance {recorded} / {total}'**
  String attendanceProgress(int recorded, int total);

  /// No description provided for @takeAttendance.
  ///
  /// In en, this message translates to:
  /// **'Take attendance'**
  String get takeAttendance;

  /// No description provided for @logbookNotAvailableForSession.
  ///
  /// In en, this message translates to:
  /// **'Logbook is not available for this session.'**
  String get logbookNotAvailableForSession;

  /// No description provided for @attendanceRecordingLessonOnly.
  ///
  /// In en, this message translates to:
  /// **'Attendance can only be recorded for lesson sessions.'**
  String get attendanceRecordingLessonOnly;

  /// No description provided for @noCurriculumChaptersLinked.
  ///
  /// In en, this message translates to:
  /// **'No curriculum chapters linked to this subject.'**
  String get noCurriculumChaptersLinked;

  /// No description provided for @chapterLabel.
  ///
  /// In en, this message translates to:
  /// **'Chapter'**
  String get chapterLabel;

  /// No description provided for @contentLabel.
  ///
  /// In en, this message translates to:
  /// **'Content'**
  String get contentLabel;

  /// No description provided for @objectivesLabel.
  ///
  /// In en, this message translates to:
  /// **'Objectives (one per line)'**
  String get objectivesLabel;

  /// No description provided for @progressPercentLabel.
  ///
  /// In en, this message translates to:
  /// **'Progress %'**
  String get progressPercentLabel;

  /// No description provided for @saveLogbook.
  ///
  /// In en, this message translates to:
  /// **'Save logbook'**
  String get saveLogbook;

  /// No description provided for @logbookSaved.
  ///
  /// In en, this message translates to:
  /// **'Logbook saved'**
  String get logbookSaved;

  /// No description provided for @sessionNotesLabel.
  ///
  /// In en, this message translates to:
  /// **'Lesson notes'**
  String get sessionNotesLabel;

  /// No description provided for @sessionNotesDescription.
  ///
  /// In en, this message translates to:
  /// **'Session-wide narrative for this lesson.'**
  String get sessionNotesDescription;

  /// No description provided for @sessionNotesHint.
  ///
  /// In en, this message translates to:
  /// **'What was covered in this lesson?'**
  String get sessionNotesHint;

  /// No description provided for @saveSessionNotes.
  ///
  /// In en, this message translates to:
  /// **'Save notes'**
  String get saveSessionNotes;

  /// No description provided for @sessionNotesSaved.
  ///
  /// In en, this message translates to:
  /// **'Lesson notes saved'**
  String get sessionNotesSaved;

  /// No description provided for @couldNotSaveSessionNote.
  ///
  /// In en, this message translates to:
  /// **'Could not save lesson notes: {error}'**
  String couldNotSaveSessionNote(String error);

  /// No description provided for @curriculumProgressTitle.
  ///
  /// In en, this message translates to:
  /// **'Curriculum progress'**
  String get curriculumProgressTitle;

  /// No description provided for @curriculumProgressDescription.
  ///
  /// In en, this message translates to:
  /// **'Record how far each curriculum matter advanced in this lesson.'**
  String get curriculumProgressDescription;

  /// No description provided for @subjectProgressSummary.
  ///
  /// In en, this message translates to:
  /// **'Subject {percent}%'**
  String subjectProgressSummary(int percent);

  /// No description provided for @cumulativeProgressLabel.
  ///
  /// In en, this message translates to:
  /// **'Overall {percent}%'**
  String cumulativeProgressLabel(int percent);

  /// No description provided for @lessonProgressLabel.
  ///
  /// In en, this message translates to:
  /// **'This lesson {percent}%'**
  String lessonProgressLabel(int percent);

  /// No description provided for @lessonProgressPercentLabel.
  ///
  /// In en, this message translates to:
  /// **'Progress for this lesson (%)'**
  String get lessonProgressPercentLabel;

  /// No description provided for @matterNotesLabel.
  ///
  /// In en, this message translates to:
  /// **'Matter notes'**
  String get matterNotesLabel;

  /// No description provided for @noMatterProgressForSession.
  ///
  /// In en, this message translates to:
  /// **'No progress recorded for this matter in this lesson yet.'**
  String get noMatterProgressForSession;

  /// No description provided for @recordMatterProgress.
  ///
  /// In en, this message translates to:
  /// **'Record progress'**
  String get recordMatterProgress;

  /// No description provided for @editMatterProgress.
  ///
  /// In en, this message translates to:
  /// **'Edit progress'**
  String get editMatterProgress;

  /// No description provided for @saveMatterProgress.
  ///
  /// In en, this message translates to:
  /// **'Save progress'**
  String get saveMatterProgress;

  /// No description provided for @matterProgressSaved.
  ///
  /// In en, this message translates to:
  /// **'Curriculum progress saved'**
  String get matterProgressSaved;

  /// No description provided for @couldNotSaveMatterProgress.
  ///
  /// In en, this message translates to:
  /// **'Could not save curriculum progress: {error}'**
  String couldNotSaveMatterProgress(String error);

  /// No description provided for @matterProgressMinimum.
  ///
  /// In en, this message translates to:
  /// **'Must be at least {percent}%'**
  String matterProgressMinimum(int percent);

  /// No description provided for @progressMustNotDecrease.
  ///
  /// In en, this message translates to:
  /// **'Progress must be at least {percent}%'**
  String progressMustNotDecrease(int percent);

  /// No description provided for @matterStatusNotStarted.
  ///
  /// In en, this message translates to:
  /// **'Not started'**
  String get matterStatusNotStarted;

  /// No description provided for @matterStatusInProgress.
  ///
  /// In en, this message translates to:
  /// **'In progress'**
  String get matterStatusInProgress;

  /// No description provided for @matterStatusCompleted.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get matterStatusCompleted;

  /// No description provided for @addCurriculumProgress.
  ///
  /// In en, this message translates to:
  /// **'Add curriculum progress'**
  String get addCurriculumProgress;

  /// No description provided for @addAnotherCurriculumProgress.
  ///
  /// In en, this message translates to:
  /// **'Add another matter'**
  String get addAnotherCurriculumProgress;

  /// No description provided for @pickSubjectMatterTitle.
  ///
  /// In en, this message translates to:
  /// **'Select curriculum matter'**
  String get pickSubjectMatterTitle;

  /// No description provided for @pickSubjectMatterDescription.
  ///
  /// In en, this message translates to:
  /// **'Choose the matter you covered in this lesson.'**
  String get pickSubjectMatterDescription;

  /// No description provided for @noRecordedMatterProgress.
  ///
  /// In en, this message translates to:
  /// **'No curriculum progress recorded for this lesson yet.'**
  String get noRecordedMatterProgress;

  /// No description provided for @allMattersRecordedForSession.
  ///
  /// In en, this message translates to:
  /// **'All linked curriculum matters have been recorded for this lesson.'**
  String get allMattersRecordedForSession;

  /// No description provided for @notRecorded.
  ///
  /// In en, this message translates to:
  /// **'Not recorded'**
  String get notRecorded;

  /// No description provided for @record.
  ///
  /// In en, this message translates to:
  /// **'Record'**
  String get record;

  /// No description provided for @edit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get edit;

  /// No description provided for @attendanceStatusPresent.
  ///
  /// In en, this message translates to:
  /// **'Present'**
  String get attendanceStatusPresent;

  /// No description provided for @attendanceStatusAbsent.
  ///
  /// In en, this message translates to:
  /// **'Absent'**
  String get attendanceStatusAbsent;

  /// No description provided for @attendanceStatusLate.
  ///
  /// In en, this message translates to:
  /// **'Late'**
  String get attendanceStatusLate;

  /// No description provided for @attendanceFlowTitle.
  ///
  /// In en, this message translates to:
  /// **'Attendance · {classLabel}'**
  String attendanceFlowTitle(String classLabel);

  /// No description provided for @noStudentsToRecord.
  ///
  /// In en, this message translates to:
  /// **'No students to record.'**
  String get noStudentsToRecord;

  /// No description provided for @attendanceRecordedProgress.
  ///
  /// In en, this message translates to:
  /// **'{recorded} / {total} recorded'**
  String attendanceRecordedProgress(int recorded, int total);

  /// No description provided for @attendanceComplete.
  ///
  /// In en, this message translates to:
  /// **'Attendance complete'**
  String get attendanceComplete;

  /// No description provided for @done.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get done;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @reviewAgain.
  ///
  /// In en, this message translates to:
  /// **'Review again'**
  String get reviewAgain;

  /// No description provided for @couldNotLoadSession.
  ///
  /// In en, this message translates to:
  /// **'Could not load session: {error}'**
  String couldNotLoadSession(String error);

  /// No description provided for @couldNotSaveAttendance.
  ///
  /// In en, this message translates to:
  /// **'Could not save attendance: {error}'**
  String couldNotSaveAttendance(String error);

  /// No description provided for @couldNotSaveLogbook.
  ///
  /// In en, this message translates to:
  /// **'Could not save logbook: {error}'**
  String couldNotSaveLogbook(String error);

  /// No description provided for @chapterFallback.
  ///
  /// In en, this message translates to:
  /// **'Chapter'**
  String get chapterFallback;

  /// No description provided for @evaluationGradedProgress.
  ///
  /// In en, this message translates to:
  /// **'{graded} / {total} graded'**
  String evaluationGradedProgress(int graded, int total);

  /// No description provided for @selectPeriodToViewEvaluations.
  ///
  /// In en, this message translates to:
  /// **'Select a period to view evaluations.'**
  String get selectPeriodToViewEvaluations;

  /// No description provided for @noEvaluationsForPeriod.
  ///
  /// In en, this message translates to:
  /// **'No evaluations for this period.'**
  String get noEvaluationsForPeriod;

  /// No description provided for @couldNotLoadEvaluations.
  ///
  /// In en, this message translates to:
  /// **'Could not load evaluations: {error}'**
  String couldNotLoadEvaluations(String error);

  /// No description provided for @couldNotLoadMarks.
  ///
  /// In en, this message translates to:
  /// **'Could not load marks: {error}'**
  String couldNotLoadMarks(String error);

  /// No description provided for @couldNotSaveMark.
  ///
  /// In en, this message translates to:
  /// **'Could not save mark: {error}'**
  String couldNotSaveMark(String error);

  /// No description provided for @publishedReportCardImmutable.
  ///
  /// In en, this message translates to:
  /// **'This student\'s report card has already been published for this period. Marks can no longer be changed.'**
  String get publishedReportCardImmutable;

  /// No description provided for @marksLockedReportCardPublished.
  ///
  /// In en, this message translates to:
  /// **'Report card published'**
  String get marksLockedReportCardPublished;

  /// No description provided for @marksEntryPeriodLockedHint.
  ///
  /// In en, this message translates to:
  /// **'Report cards have been published for this period. Marks can no longer be recorded for these students.'**
  String get marksEntryPeriodLockedHint;

  /// No description provided for @couldNotLoadSubjects.
  ///
  /// In en, this message translates to:
  /// **'Could not load subjects: {error}'**
  String couldNotLoadSubjects(String error);

  /// No description provided for @couldNotLoadPeriods.
  ///
  /// In en, this message translates to:
  /// **'Could not load periods: {error}'**
  String couldNotLoadPeriods(String error);

  /// No description provided for @titleRequired.
  ///
  /// In en, this message translates to:
  /// **'Title is required.'**
  String get titleRequired;

  /// No description provided for @maxScoreMustBePositive.
  ///
  /// In en, this message translates to:
  /// **'Max score must be greater than zero.'**
  String get maxScoreMustBePositive;

  /// No description provided for @periodRequired.
  ///
  /// In en, this message translates to:
  /// **'Period is required.'**
  String get periodRequired;

  /// No description provided for @couldNotCreateEvaluation.
  ///
  /// In en, this message translates to:
  /// **'Could not create evaluation: {error}'**
  String couldNotCreateEvaluation(String error);

  /// No description provided for @newEvaluation.
  ///
  /// In en, this message translates to:
  /// **'New evaluation'**
  String get newEvaluation;

  /// No description provided for @noSubjectsAssignedForYear.
  ///
  /// In en, this message translates to:
  /// **'No subjects assigned for this school year.'**
  String get noSubjectsAssignedForYear;

  /// No description provided for @classSubjectLabel.
  ///
  /// In en, this message translates to:
  /// **'Class · Subject'**
  String get classSubjectLabel;

  /// No description provided for @titleLabel.
  ///
  /// In en, this message translates to:
  /// **'Title'**
  String get titleLabel;

  /// No description provided for @outOfLabel.
  ///
  /// In en, this message translates to:
  /// **'Out of'**
  String get outOfLabel;

  /// No description provided for @kindLabel.
  ///
  /// In en, this message translates to:
  /// **'Kind'**
  String get kindLabel;

  /// No description provided for @evaluationKindQuiz.
  ///
  /// In en, this message translates to:
  /// **'Quiz'**
  String get evaluationKindQuiz;

  /// No description provided for @evaluationKindHomework.
  ///
  /// In en, this message translates to:
  /// **'Homework'**
  String get evaluationKindHomework;

  /// No description provided for @evaluationKindProject.
  ///
  /// In en, this message translates to:
  /// **'Project'**
  String get evaluationKindProject;

  /// No description provided for @evaluationKindOther.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get evaluationKindOther;

  /// No description provided for @createEvaluation.
  ///
  /// In en, this message translates to:
  /// **'Create evaluation'**
  String get createEvaluation;

  /// No description provided for @enterValidMaxScore.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid max score.'**
  String get enterValidMaxScore;

  /// No description provided for @outOfMaxScore.
  ///
  /// In en, this message translates to:
  /// **'Out of {maxScore}'**
  String outOfMaxScore(String maxScore);

  /// No description provided for @currentScore.
  ///
  /// In en, this message translates to:
  /// **'Current: {score}'**
  String currentScore(String score);

  /// No description provided for @scoreHintOutOf.
  ///
  /// In en, this message translates to:
  /// **'/ {maxScore}'**
  String scoreHintOutOf(String maxScore);

  /// No description provided for @periodLabel.
  ///
  /// In en, this message translates to:
  /// **'Period'**
  String get periodLabel;

  /// No description provided for @timeRange.
  ///
  /// In en, this message translates to:
  /// **'{start} – {end}'**
  String timeRange(String start, String end);

  /// No description provided for @sessionDateTime.
  ///
  /// In en, this message translates to:
  /// **'{date} · {timeRange}'**
  String sessionDateTime(String date, String timeRange);

  /// No description provided for @paymentMethodAndDate.
  ///
  /// In en, this message translates to:
  /// **'{method} · {date}'**
  String paymentMethodAndDate(String method, String date);

  /// No description provided for @settingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTitle;

  /// No description provided for @settingsTheme.
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get settingsTheme;

  /// No description provided for @settingsThemeSystem.
  ///
  /// In en, this message translates to:
  /// **'System default'**
  String get settingsThemeSystem;

  /// No description provided for @settingsThemeLight.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get settingsThemeLight;

  /// No description provided for @settingsThemeDark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get settingsThemeDark;

  /// No description provided for @settingsLanguage.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get settingsLanguage;

  /// No description provided for @settingsLanguageSystem.
  ///
  /// In en, this message translates to:
  /// **'System default'**
  String get settingsLanguageSystem;

  /// No description provided for @settingsLanguageEnglish.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get settingsLanguageEnglish;

  /// No description provided for @settingsLanguageFrench.
  ///
  /// In en, this message translates to:
  /// **'French'**
  String get settingsLanguageFrench;

  /// No description provided for @settingsTimezone.
  ///
  /// In en, this message translates to:
  /// **'Time zone'**
  String get settingsTimezone;

  /// No description provided for @settingsTimezoneDevice.
  ///
  /// In en, this message translates to:
  /// **'Device time zone'**
  String get settingsTimezoneDevice;

  /// No description provided for @settingsTimezoneUtc.
  ///
  /// In en, this message translates to:
  /// **'UTC'**
  String get settingsTimezoneUtc;

  /// No description provided for @settingsTimezoneParis.
  ///
  /// In en, this message translates to:
  /// **'Paris'**
  String get settingsTimezoneParis;

  /// No description provided for @settingsTimezoneAbidjan.
  ///
  /// In en, this message translates to:
  /// **'Abidjan'**
  String get settingsTimezoneAbidjan;

  /// No description provided for @settingsTimezoneLagos.
  ///
  /// In en, this message translates to:
  /// **'Lagos'**
  String get settingsTimezoneLagos;

  /// No description provided for @settingsTimezoneNewYork.
  ///
  /// In en, this message translates to:
  /// **'New York'**
  String get settingsTimezoneNewYork;

  /// No description provided for @settingsDateFormat.
  ///
  /// In en, this message translates to:
  /// **'Date format'**
  String get settingsDateFormat;

  /// No description provided for @settingsDateFormatSystem.
  ///
  /// In en, this message translates to:
  /// **'System default'**
  String get settingsDateFormatSystem;

  /// No description provided for @settingsDateFormatShort.
  ///
  /// In en, this message translates to:
  /// **'Short'**
  String get settingsDateFormatShort;

  /// No description provided for @settingsDateFormatMedium.
  ///
  /// In en, this message translates to:
  /// **'Medium'**
  String get settingsDateFormatMedium;

  /// No description provided for @settingsDateFormatLong.
  ///
  /// In en, this message translates to:
  /// **'Long'**
  String get settingsDateFormatLong;

  /// No description provided for @settingsTimeFormat.
  ///
  /// In en, this message translates to:
  /// **'Time format'**
  String get settingsTimeFormat;

  /// No description provided for @settingsTimeFormatSystem.
  ///
  /// In en, this message translates to:
  /// **'System default'**
  String get settingsTimeFormatSystem;

  /// No description provided for @settingsTimeFormat24h.
  ///
  /// In en, this message translates to:
  /// **'24-hour'**
  String get settingsTimeFormat24h;

  /// No description provided for @settingsTimeFormat12h.
  ///
  /// In en, this message translates to:
  /// **'12-hour'**
  String get settingsTimeFormat12h;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'fr'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'fr':
      return AppLocalizationsFr();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
