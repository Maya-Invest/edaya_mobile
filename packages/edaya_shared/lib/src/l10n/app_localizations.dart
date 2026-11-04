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

  /// No description provided for @navInboxShort.
  ///
  /// In en, this message translates to:
  /// **'Inbox'**
  String get navInboxShort;

  /// No description provided for @navEvaluationsShort.
  ///
  /// In en, this message translates to:
  /// **'Grades'**
  String get navEvaluationsShort;

  /// No description provided for @navMessages.
  ///
  /// In en, this message translates to:
  /// **'Messages'**
  String get navMessages;

  /// No description provided for @teacherSpace.
  ///
  /// In en, this message translates to:
  /// **'Teacher space'**
  String get teacherSpace;

  /// No description provided for @guardianSpace.
  ///
  /// In en, this message translates to:
  /// **'Family space'**
  String get guardianSpace;

  /// No description provided for @signInContactSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Sign in with your email or phone number.'**
  String get signInContactSubtitle;

  /// No description provided for @signInEmailSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Sign in with your email address.'**
  String get signInEmailSubtitle;

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

  /// No description provided for @contactLabel.
  ///
  /// In en, this message translates to:
  /// **'Email or phone number'**
  String get contactLabel;

  /// No description provided for @invalidContact.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid contact.'**
  String get invalidContact;

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

  /// No description provided for @help.
  ///
  /// In en, this message translates to:
  /// **'Help'**
  String get help;

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

  /// No description provided for @navHome.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get navHome;

  /// No description provided for @navAgenda.
  ///
  /// In en, this message translates to:
  /// **'Agenda'**
  String get navAgenda;

  /// No description provided for @navClasses.
  ///
  /// In en, this message translates to:
  /// **'Classes'**
  String get navClasses;

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

  /// No description provided for @missingReportCardRosterRouteData.
  ///
  /// In en, this message translates to:
  /// **'Missing report card roster route data.'**
  String get missingReportCardRosterRouteData;

  /// No description provided for @couldNotLoadReportCardRoster.
  ///
  /// In en, this message translates to:
  /// **'Could not load report card roster: {error}'**
  String couldNotLoadReportCardRoster(String error);

  /// No description provided for @couldNotLoadReportCardComments.
  ///
  /// In en, this message translates to:
  /// **'Could not load report card comments: {error}'**
  String couldNotLoadReportCardComments(String error);

  /// No description provided for @couldNotSaveReportCardComment.
  ///
  /// In en, this message translates to:
  /// **'Could not save report card comment: {error}'**
  String couldNotSaveReportCardComment(String error);

  /// No description provided for @reportCardCommentsTitle.
  ///
  /// In en, this message translates to:
  /// **'Report card comments'**
  String get reportCardCommentsTitle;

  /// No description provided for @reportCardCommentHint.
  ///
  /// In en, this message translates to:
  /// **'Enter your comment'**
  String get reportCardCommentHint;

  /// No description provided for @reportCardCommentsReadOnly.
  ///
  /// In en, this message translates to:
  /// **'This report card is published and cannot be edited.'**
  String get reportCardCommentsReadOnly;

  /// No description provided for @reportCardCommentNoEditableFields.
  ///
  /// In en, this message translates to:
  /// **'No comment fields are available for your role on this report card.'**
  String get reportCardCommentNoEditableFields;

  /// No description provided for @subjectComment.
  ///
  /// In en, this message translates to:
  /// **'{subject} comment'**
  String subjectComment(String subject);

  /// No description provided for @reportCardStatusDraft.
  ///
  /// In en, this message translates to:
  /// **'Draft'**
  String get reportCardStatusDraft;

  /// No description provided for @reportCardStatusPublished.
  ///
  /// In en, this message translates to:
  /// **'Published'**
  String get reportCardStatusPublished;

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

  /// No description provided for @markAllPresent.
  ///
  /// In en, this message translates to:
  /// **'Mark all present'**
  String get markAllPresent;

  /// No description provided for @attendanceModeGrid.
  ///
  /// In en, this message translates to:
  /// **'Grid'**
  String get attendanceModeGrid;

  /// No description provided for @attendanceModeSequential.
  ///
  /// In en, this message translates to:
  /// **'Sequential'**
  String get attendanceModeSequential;

  /// No description provided for @attendanceExceptionTitle.
  ///
  /// In en, this message translates to:
  /// **'Attendance · {studentName}'**
  String attendanceExceptionTitle(String studentName);

  /// No description provided for @attendanceReasonLabel.
  ///
  /// In en, this message translates to:
  /// **'Reason'**
  String get attendanceReasonLabel;

  /// No description provided for @attendanceReasonHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. illness, appointment'**
  String get attendanceReasonHint;

  /// No description provided for @attendanceNotesLabel.
  ///
  /// In en, this message translates to:
  /// **'Notes'**
  String get attendanceNotesLabel;

  /// No description provided for @attendanceNotesHint.
  ///
  /// In en, this message translates to:
  /// **'Optional context for the school office'**
  String get attendanceNotesHint;

  /// No description provided for @attendanceSavedLocally.
  ///
  /// In en, this message translates to:
  /// **'Saved locally — will sync when online'**
  String get attendanceSavedLocally;

  /// No description provided for @calendarTodayTitle.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get calendarTodayTitle;

  /// No description provided for @calendarGoToToday.
  ///
  /// In en, this message translates to:
  /// **'Go to today'**
  String get calendarGoToToday;

  /// No description provided for @calendarCurrentSession.
  ///
  /// In en, this message translates to:
  /// **'Now'**
  String get calendarCurrentSession;

  /// No description provided for @calendarNextSession.
  ///
  /// In en, this message translates to:
  /// **'Up next'**
  String get calendarNextSession;

  /// No description provided for @calendarNoSessionsToday.
  ///
  /// In en, this message translates to:
  /// **'No sessions scheduled for today.'**
  String get calendarNoSessionsToday;

  /// No description provided for @calendarIncompleteAttendance.
  ///
  /// In en, this message translates to:
  /// **'Attendance · {classLabel} {subjectLabel}'**
  String calendarIncompleteAttendance(String classLabel, String subjectLabel);

  /// No description provided for @sessionAttendanceComplete.
  ///
  /// In en, this message translates to:
  /// **'Attendance complete'**
  String get sessionAttendanceComplete;

  /// No description provided for @sessionAttendanceIncomplete.
  ///
  /// In en, this message translates to:
  /// **'Attendance incomplete'**
  String get sessionAttendanceIncomplete;

  /// No description provided for @logbookDraftRestored.
  ///
  /// In en, this message translates to:
  /// **'Restored unsaved logbook draft'**
  String get logbookDraftRestored;

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

  /// No description provided for @assessmentDateLabel.
  ///
  /// In en, this message translates to:
  /// **'Assessment date'**
  String get assessmentDateLabel;

  /// No description provided for @homeworkDueDateLabel.
  ///
  /// In en, this message translates to:
  /// **'Homework due date'**
  String get homeworkDueDateLabel;

  /// No description provided for @assessmentDateRequired.
  ///
  /// In en, this message translates to:
  /// **'Select an assessment date.'**
  String get assessmentDateRequired;

  /// No description provided for @homeworkDueDateRequired.
  ///
  /// In en, this message translates to:
  /// **'Select a homework due date.'**
  String get homeworkDueDateRequired;

  /// No description provided for @invalidScoreValue.
  ///
  /// In en, this message translates to:
  /// **'Enter a score between 0 and {maxScore}.'**
  String invalidScoreValue(String maxScore);

  /// No description provided for @syncStatusSaved.
  ///
  /// In en, this message translates to:
  /// **'Saved'**
  String get syncStatusSaved;

  /// No description provided for @syncStatusSavedLocally.
  ///
  /// In en, this message translates to:
  /// **'Saved locally'**
  String get syncStatusSavedLocally;

  /// No description provided for @syncStatusPending.
  ///
  /// In en, this message translates to:
  /// **'Waiting to sync'**
  String get syncStatusPending;

  /// No description provided for @syncStatusSyncing.
  ///
  /// In en, this message translates to:
  /// **'Syncing'**
  String get syncStatusSyncing;

  /// No description provided for @syncStatusSynced.
  ///
  /// In en, this message translates to:
  /// **'Synced'**
  String get syncStatusSynced;

  /// No description provided for @syncStatusFailed.
  ///
  /// In en, this message translates to:
  /// **'Sync failed'**
  String get syncStatusFailed;

  /// No description provided for @duplicateEvaluation.
  ///
  /// In en, this message translates to:
  /// **'Duplicate'**
  String get duplicateEvaluation;

  /// No description provided for @completeEvaluation.
  ///
  /// In en, this message translates to:
  /// **'Mark complete'**
  String get completeEvaluation;

  /// No description provided for @ungradedOnlyFilter.
  ///
  /// In en, this message translates to:
  /// **'Ungraded only'**
  String get ungradedOnlyFilter;

  /// No description provided for @fillAllMarks.
  ///
  /// In en, this message translates to:
  /// **'Fill all'**
  String get fillAllMarks;

  /// No description provided for @clearAllMarks.
  ///
  /// In en, this message translates to:
  /// **'Clear all'**
  String get clearAllMarks;

  /// No description provided for @familyVisibleSummaryLabel.
  ///
  /// In en, this message translates to:
  /// **'Family-visible summary'**
  String get familyVisibleSummaryLabel;

  /// No description provided for @familyVisiblePreviewLabel.
  ///
  /// In en, this message translates to:
  /// **'Family preview'**
  String get familyVisiblePreviewLabel;

  /// No description provided for @accountSyncSectionTitle.
  ///
  /// In en, this message translates to:
  /// **'Synchronization'**
  String get accountSyncSectionTitle;

  /// No description provided for @accountPendingSyncSummary.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 item waiting to sync} other{{count} items waiting to sync}}'**
  String accountPendingSyncSummary(int count);

  /// No description provided for @accountPendingSyncOldest.
  ///
  /// In en, this message translates to:
  /// **'Oldest pending {age}'**
  String accountPendingSyncOldest(String age);

  /// No description provided for @accountPendingSyncNone.
  ///
  /// In en, this message translates to:
  /// **'All changes are synced'**
  String get accountPendingSyncNone;

  /// No description provided for @accountSyncNow.
  ///
  /// In en, this message translates to:
  /// **'Sync now'**
  String get accountSyncNow;

  /// No description provided for @accountPendingSyncJustNow.
  ///
  /// In en, this message translates to:
  /// **'just now'**
  String get accountPendingSyncJustNow;

  /// No description provided for @accountPendingSyncMinutes.
  ///
  /// In en, this message translates to:
  /// **'{minutes} min ago'**
  String accountPendingSyncMinutes(int minutes);

  /// No description provided for @accountPendingSyncHours.
  ///
  /// In en, this message translates to:
  /// **'{hours} hr ago'**
  String accountPendingSyncHours(int hours);

  /// No description provided for @accountPendingSyncDays.
  ///
  /// In en, this message translates to:
  /// **'{days} d ago'**
  String accountPendingSyncDays(int days);

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

  /// No description provided for @emailRequired.
  ///
  /// In en, this message translates to:
  /// **'Enter your email.'**
  String get emailRequired;

  /// No description provided for @sendCodeButton.
  ///
  /// In en, this message translates to:
  /// **'Send code'**
  String get sendCodeButton;

  /// No description provided for @noEmailAccount.
  ///
  /// In en, this message translates to:
  /// **'No account exists for this email.'**
  String get noEmailAccount;

  /// No description provided for @invitationGuidance.
  ///
  /// In en, this message translates to:
  /// **'Ask your school for an invitation to create an account.'**
  String get invitationGuidance;

  /// No description provided for @createEmailAccount.
  ///
  /// In en, this message translates to:
  /// **'Create account'**
  String get createEmailAccount;

  /// No description provided for @useAnotherEmail.
  ///
  /// In en, this message translates to:
  /// **'Use another email'**
  String get useAnotherEmail;

  /// No description provided for @emailSendUnconfirmed.
  ///
  /// In en, this message translates to:
  /// **'We couldn’t confirm whether the code was sent.'**
  String get emailSendUnconfirmed;

  /// No description provided for @restartEmailVerification.
  ///
  /// In en, this message translates to:
  /// **'Verify your email again to continue.'**
  String get restartEmailVerification;

  /// No description provided for @otpSendFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not send a verification code.'**
  String get otpSendFailed;

  /// No description provided for @verifyEmailTitle.
  ///
  /// In en, this message translates to:
  /// **'Verify your email'**
  String get verifyEmailTitle;

  /// No description provided for @otpLabel.
  ///
  /// In en, this message translates to:
  /// **'Verification code'**
  String get otpLabel;

  /// No description provided for @verifyCodeButton.
  ///
  /// In en, this message translates to:
  /// **'Verify and continue'**
  String get verifyCodeButton;

  /// No description provided for @resendCodeButton.
  ///
  /// In en, this message translates to:
  /// **'Resend code'**
  String get resendCodeButton;

  /// No description provided for @useDifferentEmail.
  ///
  /// In en, this message translates to:
  /// **'Use a different email'**
  String get useDifferentEmail;

  /// No description provided for @verificationCodeSent.
  ///
  /// In en, this message translates to:
  /// **'We sent a code to {email}.'**
  String verificationCodeSent(String email);

  /// No description provided for @invitationTitle.
  ///
  /// In en, this message translates to:
  /// **'Join your school'**
  String get invitationTitle;

  /// No description provided for @invitationContinue.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get invitationContinue;

  /// No description provided for @invitationAcceptCta.
  ///
  /// In en, this message translates to:
  /// **'Accept invitation'**
  String get invitationAcceptCta;

  /// No description provided for @invitationAccepting.
  ///
  /// In en, this message translates to:
  /// **'Linking your account…'**
  String get invitationAccepting;

  /// No description provided for @invitationSuccess.
  ///
  /// In en, this message translates to:
  /// **'Your account is linked. Opening your family view.'**
  String get invitationSuccess;

  /// No description provided for @invitationWrongKind.
  ///
  /// In en, this message translates to:
  /// **'This invitation is for another Edaya app.'**
  String get invitationWrongKind;

  /// No description provided for @invitationWrongAccount.
  ///
  /// In en, this message translates to:
  /// **'This invitation is for a different account. Sign out, then continue with the invited email.'**
  String get invitationWrongAccount;

  /// No description provided for @invitationSignOutSwitch.
  ///
  /// In en, this message translates to:
  /// **'Sign out and continue'**
  String get invitationSignOutSwitch;

  /// No description provided for @invitationNotFound.
  ///
  /// In en, this message translates to:
  /// **'This invitation link was not found.'**
  String get invitationNotFound;

  /// No description provided for @invitationExpired.
  ///
  /// In en, this message translates to:
  /// **'This invitation has expired. Ask the school office for a new link.'**
  String get invitationExpired;

  /// No description provided for @invitationRevoked.
  ///
  /// In en, this message translates to:
  /// **'This invitation was replaced. Open the latest email or ask the school office to resend.'**
  String get invitationRevoked;

  /// No description provided for @invitationInvalid.
  ///
  /// In en, this message translates to:
  /// **'This invitation is not valid.'**
  String get invitationInvalid;

  /// No description provided for @invitationAlreadyAccepted.
  ///
  /// In en, this message translates to:
  /// **'This invitation was already used.'**
  String get invitationAlreadyAccepted;

  /// No description provided for @invitationLoadError.
  ///
  /// In en, this message translates to:
  /// **'Could not load this invitation. {error}'**
  String invitationLoadError(String error);

  /// No description provided for @invitationSummary.
  ///
  /// In en, this message translates to:
  /// **'{name} is invited as a guardian at {school}.'**
  String invitationSummary(String name, String school);

  /// No description provided for @invitationExpires.
  ///
  /// In en, this message translates to:
  /// **'Expires {date}'**
  String invitationExpires(String date);

  /// No description provided for @missingChargeDetailsRouteData.
  ///
  /// In en, this message translates to:
  /// **'Missing charge details route data.'**
  String get missingChargeDetailsRouteData;

  /// No description provided for @waitingForStudentsTitle.
  ///
  /// In en, this message translates to:
  /// **'You\'re signed in'**
  String get waitingForStudentsTitle;

  /// No description provided for @waitingForStudentsBody.
  ///
  /// In en, this message translates to:
  /// **'Your account is ready. When the school links you to a child, their timetable, grades, and messages will appear here.'**
  String get waitingForStudentsBody;

  /// No description provided for @waitingForStudentsCheckAgain.
  ///
  /// In en, this message translates to:
  /// **'Check again'**
  String get waitingForStudentsCheckAgain;

  /// No description provided for @waitingPendingInvitationsTitle.
  ///
  /// In en, this message translates to:
  /// **'Pending invitations'**
  String get waitingPendingInvitationsTitle;

  /// No description provided for @waitingNoPendingInvitations.
  ///
  /// In en, this message translates to:
  /// **'No pending invitations for this email. If the school sent a link, open it from the email.'**
  String get waitingNoPendingInvitations;

  /// No description provided for @noChildrenLinkedYet.
  ///
  /// In en, this message translates to:
  /// **'No children are linked to your account yet.'**
  String get noChildrenLinkedYet;

  /// No description provided for @feeStatusWaived.
  ///
  /// In en, this message translates to:
  /// **'Waived'**
  String get feeStatusWaived;

  /// No description provided for @availableAmount.
  ///
  /// In en, this message translates to:
  /// **'Available'**
  String get availableAmount;

  /// No description provided for @outstandingAmount.
  ///
  /// In en, this message translates to:
  /// **'Outstanding'**
  String get outstandingAmount;

  /// No description provided for @overdueAmount.
  ///
  /// In en, this message translates to:
  /// **'Overdue'**
  String get overdueAmount;

  /// No description provided for @remainingAmountLabel.
  ///
  /// In en, this message translates to:
  /// **'Remaining'**
  String get remainingAmountLabel;

  /// No description provided for @chargeSchedule.
  ///
  /// In en, this message translates to:
  /// **'Payment schedule'**
  String get chargeSchedule;

  /// No description provided for @noInstallmentsForCharge.
  ///
  /// In en, this message translates to:
  /// **'No installment schedule for this charge.'**
  String get noInstallmentsForCharge;

  /// No description provided for @installmentDue.
  ///
  /// In en, this message translates to:
  /// **'{label} · due {date}'**
  String installmentDue(String label, String date);

  /// No description provided for @paymentKind.
  ///
  /// In en, this message translates to:
  /// **'Type'**
  String get paymentKind;

  /// No description provided for @paymentKindReceipt.
  ///
  /// In en, this message translates to:
  /// **'Receipt'**
  String get paymentKindReceipt;

  /// No description provided for @paymentKindDisbursement.
  ///
  /// In en, this message translates to:
  /// **'Refund'**
  String get paymentKindDisbursement;

  /// No description provided for @mutationConflict.
  ///
  /// In en, this message translates to:
  /// **'This change conflicts with the current record. Reload it and review before trying again.'**
  String get mutationConflict;

  /// No description provided for @mutationSavedRefreshFailed.
  ///
  /// In en, this message translates to:
  /// **'Your change was saved, but the screen could not refresh. Reopen this screen to see the saved result.'**
  String get mutationSavedRefreshFailed;

  /// No description provided for @profilePhotoCropTitle.
  ///
  /// In en, this message translates to:
  /// **'Adjust portrait'**
  String get profilePhotoCropTitle;

  /// No description provided for @profilePhotoCropHint.
  ///
  /// In en, this message translates to:
  /// **'Rotate and confirm a square JPEG under 1 MiB.'**
  String get profilePhotoCropHint;

  /// No description provided for @profilePhotoRotate.
  ///
  /// In en, this message translates to:
  /// **'Rotate'**
  String get profilePhotoRotate;

  /// No description provided for @profilePhotoConfirmCrop.
  ///
  /// In en, this message translates to:
  /// **'Use this photo'**
  String get profilePhotoConfirmCrop;

  /// No description provided for @profilePhotoTooLarge.
  ///
  /// In en, this message translates to:
  /// **'The photo is still larger than 1 MiB after compression.'**
  String get profilePhotoTooLarge;

  /// No description provided for @profilePhotoUpdateSuccess.
  ///
  /// In en, this message translates to:
  /// **'Profile photo updated.'**
  String get profilePhotoUpdateSuccess;

  /// No description provided for @profilePhotoUpdateError.
  ///
  /// In en, this message translates to:
  /// **'Could not update the profile photo. {error}'**
  String profilePhotoUpdateError(String error);

  /// No description provided for @childProfileTitle.
  ///
  /// In en, this message translates to:
  /// **'Child portrait'**
  String get childProfileTitle;

  /// No description provided for @childProfileUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Select a child to propose a portrait.'**
  String get childProfileUnavailable;

  /// No description provided for @childProfileLoadError.
  ///
  /// In en, this message translates to:
  /// **'Could not load the child portrait. {error}'**
  String childProfileLoadError(String error);

  /// No description provided for @childProfilePublished.
  ///
  /// In en, this message translates to:
  /// **'Published portrait'**
  String get childProfilePublished;

  /// No description provided for @childProfileProposed.
  ///
  /// In en, this message translates to:
  /// **'Proposed portrait'**
  String get childProfileProposed;

  /// No description provided for @childProfileNoPublished.
  ///
  /// In en, this message translates to:
  /// **'No published portrait yet.'**
  String get childProfileNoPublished;

  /// No description provided for @childProfilePending.
  ///
  /// In en, this message translates to:
  /// **'Waiting for school review.'**
  String get childProfilePending;

  /// No description provided for @childProfilePendingIndicator.
  ///
  /// In en, this message translates to:
  /// **'A portrait is waiting for review.'**
  String get childProfilePendingIndicator;

  /// No description provided for @childProfileSubmitHint.
  ///
  /// In en, this message translates to:
  /// **'Take or choose a photo. The school must approve it before it appears on documents.'**
  String get childProfileSubmitHint;

  /// No description provided for @childProfileSubmit.
  ///
  /// In en, this message translates to:
  /// **'Submit portrait'**
  String get childProfileSubmit;

  /// No description provided for @childProfileResubmit.
  ///
  /// In en, this message translates to:
  /// **'Submit a new portrait'**
  String get childProfileResubmit;

  /// No description provided for @childProfileWithdraw.
  ///
  /// In en, this message translates to:
  /// **'Withdraw proposal'**
  String get childProfileWithdraw;

  /// No description provided for @childProfileSubmitted.
  ///
  /// In en, this message translates to:
  /// **'Portrait submitted for review.'**
  String get childProfileSubmitted;

  /// No description provided for @childProfileWithdrawn.
  ///
  /// In en, this message translates to:
  /// **'Proposal withdrawn.'**
  String get childProfileWithdrawn;

  /// No description provided for @childProfileSubmitError.
  ///
  /// In en, this message translates to:
  /// **'Could not submit the portrait. {error}'**
  String childProfileSubmitError(String error);

  /// No description provided for @childProfileWithdrawError.
  ///
  /// In en, this message translates to:
  /// **'Could not withdraw the proposal. {error}'**
  String childProfileWithdrawError(String error);

  /// No description provided for @childProfileRejected.
  ///
  /// In en, this message translates to:
  /// **'The school rejected this portrait: {reason}'**
  String childProfileRejected(String reason);

  /// No description provided for @childProfileRejectedNoReason.
  ///
  /// In en, this message translates to:
  /// **'No reason was provided.'**
  String get childProfileRejectedNoReason;

  /// No description provided for @documentsTitle.
  ///
  /// In en, this message translates to:
  /// **'Official documents'**
  String get documentsTitle;

  /// No description provided for @tooltipDocuments.
  ///
  /// In en, this message translates to:
  /// **'Official documents'**
  String get tooltipDocuments;

  /// No description provided for @documentsEntry.
  ///
  /// In en, this message translates to:
  /// **'Official documents'**
  String get documentsEntry;

  /// No description provided for @documentsEmpty.
  ///
  /// In en, this message translates to:
  /// **'No official documents for this school year yet.'**
  String get documentsEmpty;

  /// No description provided for @documentsDownloadRecall.
  ///
  /// In en, this message translates to:
  /// **'Already downloaded files cannot be remotely recalled.'**
  String get documentsDownloadRecall;

  /// No description provided for @documentsDownload.
  ///
  /// In en, this message translates to:
  /// **'Download'**
  String get documentsDownload;

  /// No description provided for @documentsGeneratePdf.
  ///
  /// In en, this message translates to:
  /// **'Generate PDF'**
  String get documentsGeneratePdf;

  /// No description provided for @documentsOpened.
  ///
  /// In en, this message translates to:
  /// **'Opening the PDF.'**
  String get documentsOpened;

  /// No description provided for @documentsRendering.
  ///
  /// In en, this message translates to:
  /// **'The PDF is still rendering. Open Official documents when it is ready.'**
  String get documentsRendering;

  /// No description provided for @documentsFailed.
  ///
  /// In en, this message translates to:
  /// **'This document failed ({code}).'**
  String documentsFailed(String code);

  /// No description provided for @documentsNotIssued.
  ///
  /// In en, this message translates to:
  /// **'No downloadable PDF is ready yet.'**
  String get documentsNotIssued;

  /// No description provided for @documentsOpenFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not open the PDF.'**
  String get documentsOpenFailed;

  /// No description provided for @documentStatusRequested.
  ///
  /// In en, this message translates to:
  /// **'Pending'**
  String get documentStatusRequested;

  /// No description provided for @documentStatusRendering.
  ///
  /// In en, this message translates to:
  /// **'Pending'**
  String get documentStatusRendering;

  /// No description provided for @documentStatusReady.
  ///
  /// In en, this message translates to:
  /// **'Issued'**
  String get documentStatusReady;

  /// No description provided for @documentStatusFailed.
  ///
  /// In en, this message translates to:
  /// **'Error'**
  String get documentStatusFailed;

  /// No description provided for @documentStatusSuperseded.
  ///
  /// In en, this message translates to:
  /// **'Replaced'**
  String get documentStatusSuperseded;

  /// No description provided for @documentStatusVoided.
  ///
  /// In en, this message translates to:
  /// **'Replaced'**
  String get documentStatusVoided;

  /// No description provided for @documentStatusPreview.
  ///
  /// In en, this message translates to:
  /// **'Issued'**
  String get documentStatusPreview;

  /// No description provided for @exportLogbookPdf.
  ///
  /// In en, this message translates to:
  /// **'Logbook PDF'**
  String get exportLogbookPdf;

  /// No description provided for @exportTimetablePdf.
  ///
  /// In en, this message translates to:
  /// **'Timetable PDF'**
  String get exportTimetablePdf;

  /// No description provided for @exportRosterPdf.
  ///
  /// In en, this message translates to:
  /// **'Class roster PDF'**
  String get exportRosterPdf;

  /// No description provided for @exportAttendancePdf.
  ///
  /// In en, this message translates to:
  /// **'Attendance sheet PDF'**
  String get exportAttendancePdf;

  /// No description provided for @familyFeedbackEntry.
  ///
  /// In en, this message translates to:
  /// **'Family feedback'**
  String get familyFeedbackEntry;

  /// No description provided for @familyFeedbackTitle.
  ///
  /// In en, this message translates to:
  /// **'Family feedback'**
  String get familyFeedbackTitle;

  /// No description provided for @familyFeedbackEmpty.
  ///
  /// In en, this message translates to:
  /// **'No family feedback campaigns yet.'**
  String get familyFeedbackEmpty;

  /// No description provided for @familyFeedbackConfidential.
  ///
  /// In en, this message translates to:
  /// **'Confidential and aggregated. This is not an academic assessment.'**
  String get familyFeedbackConfidential;

  /// No description provided for @familyFeedbackSubmit.
  ///
  /// In en, this message translates to:
  /// **'Submit'**
  String get familyFeedbackSubmit;

  /// No description provided for @familyFeedbackSubmitted.
  ///
  /// In en, this message translates to:
  /// **'Your response was recorded.'**
  String get familyFeedbackSubmitted;

  /// No description provided for @familyFeedbackAlreadyCompleted.
  ///
  /// In en, this message translates to:
  /// **'A response is already recorded for this student.'**
  String get familyFeedbackAlreadyCompleted;

  /// No description provided for @familyFeedbackClosed.
  ///
  /// In en, this message translates to:
  /// **'This campaign is closed.'**
  String get familyFeedbackClosed;

  /// No description provided for @familyFeedbackComment.
  ///
  /// In en, this message translates to:
  /// **'Optional comment'**
  String get familyFeedbackComment;

  /// No description provided for @familyFeedbackCannotAssess.
  ///
  /// In en, this message translates to:
  /// **'Cannot assess'**
  String get familyFeedbackCannotAssess;

  /// No description provided for @familyFeedbackInsufficient.
  ///
  /// In en, this message translates to:
  /// **'Insufficient responses'**
  String get familyFeedbackInsufficient;

  /// No description provided for @familyFeedbackThemes.
  ///
  /// In en, this message translates to:
  /// **'Themes'**
  String get familyFeedbackThemes;

  /// No description provided for @familyFeedbackSlotOpen.
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get familyFeedbackSlotOpen;

  /// No description provided for @familyFeedbackSlotCompleted.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get familyFeedbackSlotCompleted;

  /// No description provided for @teacherTaskFamilyFeedback.
  ///
  /// In en, this message translates to:
  /// **'Family feedback'**
  String get teacherTaskFamilyFeedback;

  /// No description provided for @teacherTaskAttendance.
  ///
  /// In en, this message translates to:
  /// **'Attendance to record'**
  String get teacherTaskAttendance;

  /// No description provided for @teacherTaskLogbook.
  ///
  /// In en, this message translates to:
  /// **'Lesson log'**
  String get teacherTaskLogbook;

  /// No description provided for @teacherTaskMarks.
  ///
  /// In en, this message translates to:
  /// **'Marks to enter'**
  String get teacherTaskMarks;

  /// No description provided for @chooseSchool.
  ///
  /// In en, this message translates to:
  /// **'Choose a school'**
  String get chooseSchool;

  /// No description provided for @teacherTaskReportComments.
  ///
  /// In en, this message translates to:
  /// **'Report comments'**
  String get teacherTaskReportComments;

  /// No description provided for @outboxConflictTitle.
  ///
  /// In en, this message translates to:
  /// **'Changes needing review'**
  String get outboxConflictTitle;

  /// No description provided for @outboxDiscardEdit.
  ///
  /// In en, this message translates to:
  /// **'Discard this local edit'**
  String get outboxDiscardEdit;

  /// No description provided for @outboxDiscardConfirm.
  ///
  /// In en, this message translates to:
  /// **'This removes only the selected local edit. The server record is unchanged. Review the current record before entering a new edit.'**
  String get outboxDiscardConfirm;

  /// No description provided for @marksAbsent.
  ///
  /// In en, this message translates to:
  /// **'Absent'**
  String get marksAbsent;

  /// No description provided for @marksExempt.
  ///
  /// In en, this message translates to:
  /// **'Exempt'**
  String get marksExempt;

  /// No description provided for @marksDesignation.
  ///
  /// In en, this message translates to:
  /// **'Mark designation'**
  String get marksDesignation;

  /// No description provided for @marksSubmit.
  ///
  /// In en, this message translates to:
  /// **'Submit for approval'**
  String get marksSubmit;

  /// No description provided for @marksSubmitted.
  ///
  /// In en, this message translates to:
  /// **'Marks submitted and visible to families.'**
  String get marksSubmitted;

  /// No description provided for @marksResolveConflicts.
  ///
  /// In en, this message translates to:
  /// **'Resolve pending conflicts before submitting.'**
  String get marksResolveConflicts;

  /// No description provided for @marksInvalidNumber.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid numeric mark.'**
  String get marksInvalidNumber;

  /// No description provided for @marksRequestCorrection.
  ///
  /// In en, this message translates to:
  /// **'Request correction'**
  String get marksRequestCorrection;

  /// No description provided for @marksCorrectionRequested.
  ///
  /// In en, this message translates to:
  /// **'Correction requested. Official marks are unchanged.'**
  String get marksCorrectionRequested;

  /// No description provided for @marksCorrectionHint.
  ///
  /// In en, this message translates to:
  /// **'Official marks stay unchanged until staff approval.'**
  String get marksCorrectionHint;

  /// No description provided for @marksCorrectionReason.
  ///
  /// In en, this message translates to:
  /// **'Reason for correction'**
  String get marksCorrectionReason;

  /// No description provided for @marksCorrectionConfirm.
  ///
  /// In en, this message translates to:
  /// **'I have checked all proposed changes.'**
  String get marksCorrectionConfirm;

  /// No description provided for @marksCorrectionPending.
  ///
  /// In en, this message translates to:
  /// **'Pending correction'**
  String get marksCorrectionPending;

  /// No description provided for @marksCorrectionApproved.
  ///
  /// In en, this message translates to:
  /// **'Approved correction'**
  String get marksCorrectionApproved;

  /// No description provided for @marksCorrectionRejected.
  ///
  /// In en, this message translates to:
  /// **'Rejected correction'**
  String get marksCorrectionRejected;

  /// No description provided for @marksCorrectionWithdrawn.
  ///
  /// In en, this message translates to:
  /// **'Withdrawn correction'**
  String get marksCorrectionWithdrawn;

  /// No description provided for @marksWithdrawCorrection.
  ///
  /// In en, this message translates to:
  /// **'Withdraw request'**
  String get marksWithdrawCorrection;

  /// No description provided for @marksComment.
  ///
  /// In en, this message translates to:
  /// **'Mark comment'**
  String get marksComment;

  /// No description provided for @marksPublishedLock.
  ///
  /// In en, this message translates to:
  /// **'Locked by a published report'**
  String get marksPublishedLock;

  /// No description provided for @marksOfficial.
  ///
  /// In en, this message translates to:
  /// **'Submitted · official marks'**
  String get marksOfficial;

  /// No description provided for @marksOriginal.
  ///
  /// In en, this message translates to:
  /// **'Original'**
  String get marksOriginal;

  /// No description provided for @marksProposed.
  ///
  /// In en, this message translates to:
  /// **'Proposed'**
  String get marksProposed;

  /// No description provided for @deliveryChannel.
  ///
  /// In en, this message translates to:
  /// **'Send my code by'**
  String get deliveryChannel;

  /// No description provided for @phoneUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Phone verification is temporarily unavailable. Use email.'**
  String get phoneUnavailable;

  /// No description provided for @phoneCountryHint.
  ///
  /// In en, this message translates to:
  /// **'Côte d’Ivoire mobile numbers only. Example: +2250712345678.'**
  String get phoneCountryHint;

  /// No description provided for @authenticatorSetup.
  ///
  /// In en, this message translates to:
  /// **'Add this secret to your authenticator app, then enter its code.'**
  String get authenticatorSetup;

  /// No description provided for @authenticatorCode.
  ///
  /// In en, this message translates to:
  /// **'Authenticator code'**
  String get authenticatorCode;

  /// No description provided for @recoveryCode.
  ///
  /// In en, this message translates to:
  /// **'Recovery code'**
  String get recoveryCode;

  /// No description provided for @useRecoveryCode.
  ///
  /// In en, this message translates to:
  /// **'Use a recovery code'**
  String get useRecoveryCode;

  /// No description provided for @saveRecoveryCodes.
  ///
  /// In en, this message translates to:
  /// **'Save these recovery codes securely. They are shown only once.'**
  String get saveRecoveryCodes;

  /// No description provided for @savedRecoveryCodes.
  ///
  /// In en, this message translates to:
  /// **'I have saved my codes'**
  String get savedRecoveryCodes;

  /// No description provided for @accountSecurity.
  ///
  /// In en, this message translates to:
  /// **'Account security'**
  String get accountSecurity;

  /// No description provided for @recentSignInHint.
  ///
  /// In en, this message translates to:
  /// **'Sign in again before changing login identifiers or your authenticator.'**
  String get recentSignInHint;

  /// No description provided for @linkIdentifier.
  ///
  /// In en, this message translates to:
  /// **'Link another login identifier'**
  String get linkIdentifier;

  /// No description provided for @unlinkIdentifier.
  ///
  /// In en, this message translates to:
  /// **'Unlink and sign out'**
  String get unlinkIdentifier;

  /// No description provided for @enableAuthenticator.
  ///
  /// In en, this message translates to:
  /// **'Set up authenticator'**
  String get enableAuthenticator;

  /// No description provided for @recoveryEligible.
  ///
  /// In en, this message translates to:
  /// **'Allow this identifier for account recovery'**
  String get recoveryEligible;

  /// No description provided for @contactMethod.
  ///
  /// In en, this message translates to:
  /// **'Verify with'**
  String get contactMethod;

  /// No description provided for @verifyContactTitle.
  ///
  /// In en, this message translates to:
  /// **'Verify your contact'**
  String get verifyContactTitle;

  /// No description provided for @verificationContact.
  ///
  /// In en, this message translates to:
  /// **'Enter the code for {contact}.'**
  String verificationContact(String contact);

  /// No description provided for @useMostRecentCode.
  ///
  /// In en, this message translates to:
  /// **'Use the most recent code. Each resend replaces the previous code.'**
  String get useMostRecentCode;

  /// No description provided for @sendBySms.
  ///
  /// In en, this message translates to:
  /// **'Send by SMS'**
  String get sendBySms;

  /// No description provided for @resendCountdown.
  ///
  /// In en, this message translates to:
  /// **'You can request another code in {seconds}s.'**
  String resendCountdown(int seconds);

  /// No description provided for @changeContact.
  ///
  /// In en, this message translates to:
  /// **'Change contact'**
  String get changeContact;

  /// No description provided for @checkWhatsApp.
  ///
  /// In en, this message translates to:
  /// **'Check WhatsApp for the code.'**
  String get checkWhatsApp;

  /// No description provided for @checkSms.
  ///
  /// In en, this message translates to:
  /// **'Check your text messages for the code.'**
  String get checkSms;

  /// No description provided for @checkEmailCode.
  ///
  /// In en, this message translates to:
  /// **'Check your email for the code.'**
  String get checkEmailCode;

  /// No description provided for @codeExpired.
  ///
  /// In en, this message translates to:
  /// **'This code has expired. Request a new code.'**
  String get codeExpired;

  /// No description provided for @codeDeliveryFailed.
  ///
  /// In en, this message translates to:
  /// **'We could not send the code. After the countdown, request another code.'**
  String get codeDeliveryFailed;

  /// No description provided for @codeDeliveryUncertain.
  ///
  /// In en, this message translates to:
  /// **'Delivery is not confirmed. If the code arrives, you can still use it.'**
  String get codeDeliveryUncertain;

  /// No description provided for @retryRequest.
  ///
  /// In en, this message translates to:
  /// **'Retry request'**
  String get retryRequest;

  /// No description provided for @testingOnly.
  ///
  /// In en, this message translates to:
  /// **'Testing only'**
  String get testingOnly;

  /// No description provided for @showTestCode.
  ///
  /// In en, this message translates to:
  /// **'Show test code'**
  String get showTestCode;

  /// No description provided for @copyTestCode.
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get copyTestCode;

  /// No description provided for @testCodeUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Test code unavailable'**
  String get testCodeUnavailable;

  /// No description provided for @attendanceIncomplete.
  ///
  /// In en, this message translates to:
  /// **'Record every student before finishing attendance.'**
  String get attendanceIncomplete;

  /// No description provided for @attendanceSubmitNeedsSync.
  ///
  /// In en, this message translates to:
  /// **'Synchronize saved drafts before finishing attendance.'**
  String get attendanceSubmitNeedsSync;

  /// No description provided for @workflowSynced.
  ///
  /// In en, this message translates to:
  /// **'Synchronized'**
  String get workflowSynced;

  /// No description provided for @attendanceArrival.
  ///
  /// In en, this message translates to:
  /// **'Record arrival'**
  String get attendanceArrival;

  /// No description provided for @workflowCorrectionPending.
  ///
  /// In en, this message translates to:
  /// **'Correction pending review'**
  String get workflowCorrectionPending;

  /// No description provided for @workflowRequestCorrection.
  ///
  /// In en, this message translates to:
  /// **'Request correction'**
  String get workflowRequestCorrection;

  /// No description provided for @dailyAttendance.
  ///
  /// In en, this message translates to:
  /// **'Daily attendance'**
  String get dailyAttendance;

  /// No description provided for @workflowDiscipline.
  ///
  /// In en, this message translates to:
  /// **'Discipline'**
  String get workflowDiscipline;

  /// No description provided for @workflowFollowUp.
  ///
  /// In en, this message translates to:
  /// **'Add follow-up'**
  String get workflowFollowUp;

  /// No description provided for @deadlineCompliance.
  ///
  /// In en, this message translates to:
  /// **'Homework submission'**
  String get deadlineCompliance;

  /// No description provided for @deadlineMet.
  ///
  /// In en, this message translates to:
  /// **'On time'**
  String get deadlineMet;

  /// No description provided for @deadlineLate.
  ///
  /// In en, this message translates to:
  /// **'Late'**
  String get deadlineLate;

  /// No description provided for @deadlineMissed.
  ///
  /// In en, this message translates to:
  /// **'Missed'**
  String get deadlineMissed;

  /// No description provided for @deadlineExcused.
  ///
  /// In en, this message translates to:
  /// **'Excused'**
  String get deadlineExcused;

  /// No description provided for @attendancePresent.
  ///
  /// In en, this message translates to:
  /// **'Present'**
  String get attendancePresent;

  /// No description provided for @attendanceAbsent.
  ///
  /// In en, this message translates to:
  /// **'Absent'**
  String get attendanceAbsent;

  /// No description provided for @attendanceLate.
  ///
  /// In en, this message translates to:
  /// **'Late'**
  String get attendanceLate;

  /// No description provided for @attendanceFinish.
  ///
  /// In en, this message translates to:
  /// **'Finish'**
  String get attendanceFinish;

  /// No description provided for @attendanceMarkRemaining.
  ///
  /// In en, this message translates to:
  /// **'Mark remaining present'**
  String get attendanceMarkRemaining;

  /// No description provided for @workflowReviseCorrection.
  ///
  /// In en, this message translates to:
  /// **'Revise request'**
  String get workflowReviseCorrection;

  /// No description provided for @workflowIncidentTakenOver.
  ///
  /// In en, this message translates to:
  /// **'Staff have taken over this incident'**
  String get workflowIncidentTakenOver;

  /// No description provided for @workflowIncidentTitle.
  ///
  /// In en, this message translates to:
  /// **'Title'**
  String get workflowIncidentTitle;

  /// No description provided for @workflowIncidentFacts.
  ///
  /// In en, this message translates to:
  /// **'Facts'**
  String get workflowIncidentFacts;

  /// No description provided for @workflowIncidentPositive.
  ///
  /// In en, this message translates to:
  /// **'Positive'**
  String get workflowIncidentPositive;

  /// No description provided for @workflowIncidentMinor.
  ///
  /// In en, this message translates to:
  /// **'Minor incident'**
  String get workflowIncidentMinor;

  /// No description provided for @workflowIncidentMajor.
  ///
  /// In en, this message translates to:
  /// **'Major incident'**
  String get workflowIncidentMajor;

  /// No description provided for @workflowIncidentEmergency.
  ///
  /// In en, this message translates to:
  /// **'Emergency'**
  String get workflowIncidentEmergency;

  /// No description provided for @workflowTeacherExplanation.
  ///
  /// In en, this message translates to:
  /// **'Teacher explanation'**
  String get workflowTeacherExplanation;

  /// No description provided for @messagingNew.
  ///
  /// In en, this message translates to:
  /// **'New message'**
  String get messagingNew;

  /// No description provided for @messagingSchool.
  ///
  /// In en, this message translates to:
  /// **'School'**
  String get messagingSchool;

  /// No description provided for @messagingTeacher.
  ///
  /// In en, this message translates to:
  /// **'Teacher'**
  String get messagingTeacher;

  /// No description provided for @messagingSubject.
  ///
  /// In en, this message translates to:
  /// **'Subject'**
  String get messagingSubject;

  /// No description provided for @messagingBody.
  ///
  /// In en, this message translates to:
  /// **'Message'**
  String get messagingBody;

  /// No description provided for @messagingSend.
  ///
  /// In en, this message translates to:
  /// **'Send'**
  String get messagingSend;

  /// No description provided for @messagingReply.
  ///
  /// In en, this message translates to:
  /// **'Reply'**
  String get messagingReply;

  /// No description provided for @messagingEmpty.
  ///
  /// In en, this message translates to:
  /// **'No conversations yet'**
  String get messagingEmpty;

  /// No description provided for @messagingOversight.
  ///
  /// In en, this message translates to:
  /// **'Authorized school staff can review teacher conversations.'**
  String get messagingOversight;

  /// No description provided for @messagingIncludeChild.
  ///
  /// In en, this message translates to:
  /// **'Include the selected child'**
  String get messagingIncludeChild;

  /// No description provided for @messagingUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Messaging is currently unavailable for this recipient.'**
  String get messagingUnavailable;

  /// No description provided for @messagingHistory.
  ///
  /// In en, this message translates to:
  /// **'Read-only conversation'**
  String get messagingHistory;

  /// No description provided for @messagingLoadMore.
  ///
  /// In en, this message translates to:
  /// **'Load older messages'**
  String get messagingLoadMore;

  /// No description provided for @messagingRefresh.
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get messagingRefresh;

  /// No description provided for @messagingAwaitingSchool.
  ///
  /// In en, this message translates to:
  /// **'Awaiting school'**
  String get messagingAwaitingSchool;

  /// No description provided for @messagingAwaitingGuardian.
  ///
  /// In en, this message translates to:
  /// **'Awaiting guardian'**
  String get messagingAwaitingGuardian;

  /// No description provided for @messagingResolved.
  ///
  /// In en, this message translates to:
  /// **'Resolved'**
  String get messagingResolved;

  /// No description provided for @messagingFailed.
  ///
  /// In en, this message translates to:
  /// **'Unable to send. Your draft is preserved. Try again.'**
  String get messagingFailed;

  /// No description provided for @messagingChanged.
  ///
  /// In en, this message translates to:
  /// **'New activity is available. Review the conversation before sending again.'**
  String get messagingChanged;

  /// No description provided for @messagingRequired.
  ///
  /// In en, this message translates to:
  /// **'Enter a subject and a message.'**
  String get messagingRequired;

  /// No description provided for @messagingSchoolAuthor.
  ///
  /// In en, this message translates to:
  /// **'School staff'**
  String get messagingSchoolAuthor;

  /// No description provided for @messagingRead.
  ///
  /// In en, this message translates to:
  /// **'Read'**
  String get messagingRead;

  /// No description provided for @messagingUnread.
  ///
  /// In en, this message translates to:
  /// **'Unread'**
  String get messagingUnread;

  /// No description provided for @messagingConversations.
  ///
  /// In en, this message translates to:
  /// **'Conversations'**
  String get messagingConversations;

  /// No description provided for @teacherSignatureTitle.
  ///
  /// In en, this message translates to:
  /// **'Signature'**
  String get teacherSignatureTitle;

  /// No description provided for @teacherSignatureUsage.
  ///
  /// In en, this message translates to:
  /// **'Your signature is used automatically on new periodic and annual report cards and incident reports you create at this school.'**
  String get teacherSignatureUsage;

  /// No description provided for @teacherSignatureEmpty.
  ///
  /// In en, this message translates to:
  /// **'No signature saved'**
  String get teacherSignatureEmpty;

  /// No description provided for @teacherSignatureDraw.
  ///
  /// In en, this message translates to:
  /// **'Draw'**
  String get teacherSignatureDraw;

  /// No description provided for @teacherSignatureChooseImage.
  ///
  /// In en, this message translates to:
  /// **'Choose image'**
  String get teacherSignatureChooseImage;

  /// No description provided for @teacherSignatureTakePhoto.
  ///
  /// In en, this message translates to:
  /// **'Take photo'**
  String get teacherSignatureTakePhoto;

  /// No description provided for @teacherSignatureUndo.
  ///
  /// In en, this message translates to:
  /// **'Undo'**
  String get teacherSignatureUndo;

  /// No description provided for @teacherSignatureClear.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get teacherSignatureClear;

  /// No description provided for @teacherSignatureUse.
  ///
  /// In en, this message translates to:
  /// **'Use signature'**
  String get teacherSignatureUse;

  /// No description provided for @teacherSignaturePreview.
  ///
  /// In en, this message translates to:
  /// **'Signature preview'**
  String get teacherSignaturePreview;

  /// No description provided for @teacherSignatureDrawHint.
  ///
  /// In en, this message translates to:
  /// **'Sign inside the box with your finger or stylus.'**
  String get teacherSignatureDrawHint;

  /// No description provided for @teacherSignatureCropHint.
  ///
  /// In en, this message translates to:
  /// **'Drag over the image to select your signature. Rotate or reset the crop if needed.'**
  String get teacherSignatureCropHint;

  /// No description provided for @teacherSignatureResetCrop.
  ///
  /// In en, this message translates to:
  /// **'Reset crop'**
  String get teacherSignatureResetCrop;

  /// No description provided for @teacherSignatureRemove.
  ///
  /// In en, this message translates to:
  /// **'Remove signature'**
  String get teacherSignatureRemove;

  /// No description provided for @teacherSignatureRemoveConfirm.
  ///
  /// In en, this message translates to:
  /// **'Remove your signature? It will no longer appear on new reports. Already requested and issued documents keep their signature.'**
  String get teacherSignatureRemoveConfirm;

  /// No description provided for @teacherSignatureSaved.
  ///
  /// In en, this message translates to:
  /// **'Signature saved'**
  String get teacherSignatureSaved;

  /// No description provided for @teacherSignatureRemoved.
  ///
  /// In en, this message translates to:
  /// **'Signature removed'**
  String get teacherSignatureRemoved;

  /// No description provided for @teacherSignatureSaveError.
  ///
  /// In en, this message translates to:
  /// **'Unable to save your signature. Check your connection and try again. Your saved signature is preserved.'**
  String get teacherSignatureSaveError;

  /// No description provided for @teacherSignatureLoadError.
  ///
  /// In en, this message translates to:
  /// **'Unable to load your signature. Try again.'**
  String get teacherSignatureLoadError;

  /// No description provided for @teacherSignatureImageError.
  ///
  /// In en, this message translates to:
  /// **'This image cannot be used. Choose a valid image up to 20 MB.'**
  String get teacherSignatureImageError;

  /// No description provided for @teacherSignatureTooLarge.
  ///
  /// In en, this message translates to:
  /// **'The signature must be smaller than 1 MB. Crop it more closely and try again.'**
  String get teacherSignatureTooLarge;

  /// No description provided for @teacherSignatureDiscard.
  ///
  /// In en, this message translates to:
  /// **'Discard changes'**
  String get teacherSignatureDiscard;

  /// No description provided for @teacherSignatureDraft.
  ///
  /// In en, this message translates to:
  /// **'Preview before saving'**
  String get teacherSignatureDraft;

  /// No description provided for @messagingSentDescription.
  ///
  /// In en, this message translates to:
  /// **'Sent by {author}, {timestamp}'**
  String messagingSentDescription(String author, String timestamp);

  /// No description provided for @messagingReceivedDescription.
  ///
  /// In en, this message translates to:
  /// **'Received from {author}, {timestamp}'**
  String messagingReceivedDescription(String author, String timestamp);

  /// No description provided for @gradingMention.
  ///
  /// In en, this message translates to:
  /// **'Mention'**
  String get gradingMention;

  /// No description provided for @termsConfirm.
  ///
  /// In en, this message translates to:
  /// **'Accept'**
  String get termsConfirm;

  /// No description provided for @termsRead.
  ///
  /// In en, this message translates to:
  /// **'Read the Terms of Use'**
  String get termsRead;

  /// No description provided for @termsAccept.
  ///
  /// In en, this message translates to:
  /// **'I accept the Terms of Use'**
  String get termsAccept;

  /// No description provided for @termsLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading the Terms of Use…'**
  String get termsLoading;

  /// No description provided for @termsUnavailable.
  ///
  /// In en, this message translates to:
  /// **'The Terms of Use could not be loaded. Please retry to continue.'**
  String get termsUnavailable;

  /// No description provided for @termsRetry.
  ///
  /// In en, this message translates to:
  /// **'Retry loading terms'**
  String get termsRetry;

  /// No description provided for @termsRequired.
  ///
  /// In en, this message translates to:
  /// **'Accept the Terms of Use before continuing.'**
  String get termsRequired;

  /// No description provided for @termsChanged.
  ///
  /// In en, this message translates to:
  /// **'The Terms of Use have changed. Read and accept the new version to continue.'**
  String get termsChanged;

  /// No description provided for @termsDraft.
  ///
  /// In en, this message translates to:
  /// **'Draft preview — this text is awaiting approval and is not a published agreement.'**
  String get termsDraft;

  /// No description provided for @guardianMainPhone.
  ///
  /// In en, this message translates to:
  /// **'Main phone'**
  String get guardianMainPhone;

  /// No description provided for @guardianAlternativePhone.
  ///
  /// In en, this message translates to:
  /// **'Alternative phone'**
  String get guardianAlternativePhone;

  /// No description provided for @guardianNotificationDestinations.
  ///
  /// In en, this message translates to:
  /// **'SMS uses your main phone and email uses your saved address. Messages remain available in your app inbox.'**
  String get guardianNotificationDestinations;

  /// No description provided for @guardianEmailNotifications.
  ///
  /// In en, this message translates to:
  /// **'Email notifications'**
  String get guardianEmailNotifications;

  /// No description provided for @guardianSmsNotifications.
  ///
  /// In en, this message translates to:
  /// **'SMS notifications'**
  String get guardianSmsNotifications;

  /// No description provided for @guardianPushNotifications.
  ///
  /// In en, this message translates to:
  /// **'Push notifications'**
  String get guardianPushNotifications;

  /// No description provided for @guardianDiscardChanges.
  ///
  /// In en, this message translates to:
  /// **'Discard unsaved changes?'**
  String get guardianDiscardChanges;

  /// No description provided for @guardianDiscard.
  ///
  /// In en, this message translates to:
  /// **'Discard'**
  String get guardianDiscard;

  /// No description provided for @reportModuleExplicitWeight.
  ///
  /// In en, this message translates to:
  /// **'Explicit weight'**
  String get reportModuleExplicitWeight;

  /// No description provided for @reportModuleCoefficientWeight.
  ///
  /// In en, this message translates to:
  /// **'Contributing coefficients'**
  String get reportModuleCoefficientWeight;

  /// No description provided for @reportSubjectCoefficient.
  ///
  /// In en, this message translates to:
  /// **'Coefficient'**
  String get reportSubjectCoefficient;

  /// No description provided for @teacherQuickLogin.
  ///
  /// In en, this message translates to:
  /// **'Sign in with a quick code'**
  String get teacherQuickLogin;

  /// No description provided for @teacherQuickHint.
  ///
  /// In en, this message translates to:
  /// **'Enter the code sent by your school.'**
  String get teacherQuickHint;

  /// No description provided for @teacherQuickLabel.
  ///
  /// In en, this message translates to:
  /// **'8-character teacher code'**
  String get teacherQuickLabel;

  /// No description provided for @teacherQuickInvalid.
  ///
  /// In en, this message translates to:
  /// **'Invalid or expired code.'**
  String get teacherQuickInvalid;
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
