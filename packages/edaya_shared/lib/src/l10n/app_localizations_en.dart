// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitleGuardian => 'Edaya';

  @override
  String get appTitleTeacher => 'Edaya Staff';

  @override
  String get accountTitle => 'Account';

  @override
  String get accountProfileTitle => 'Contact profile';

  @override
  String get accountProfileDescription =>
      'Update the name and contact details shown to the school.';

  @override
  String accountProfileLoginEmail(String email) {
    return 'Sign-in email: $email';
  }

  @override
  String get accountProfileUnavailable =>
      'Your school profile is not available.';

  @override
  String accountProfileLoadError(String error) {
    return 'Could not load your profile. $error';
  }

  @override
  String accountProfileSaveError(String error) {
    return 'Could not save your profile. $error';
  }

  @override
  String get accountProfileUpdateSuccess => 'Profile updated.';

  @override
  String get firstNameLabel => 'First name';

  @override
  String get lastNameLabel => 'Last name';

  @override
  String get phoneLabel => 'Phone';

  @override
  String get signingOut => 'Signing out…';

  @override
  String get signOut => 'Sign out';

  @override
  String get nothingToShowYet => 'Nothing to show yet.';

  @override
  String get somethingWentWrong => 'Something went wrong.';

  @override
  String get retry => 'Retry';

  @override
  String get signInTitle => 'Sign in';

  @override
  String get signInButton => 'Sign in';

  @override
  String get contactLabel => 'Email or phone number';

  @override
  String get invalidContact => 'Enter a valid contact.';

  @override
  String get emailLabel => 'Email';

  @override
  String get passwordLabel => 'Password';

  @override
  String get signInFailed => 'Sign-in failed';

  @override
  String signedInSchoolSessionUnavailable(String error) {
    return 'Signed in, but school session is unavailable: $error';
  }

  @override
  String get apiUrlCannotBeEmpty => 'API URL cannot be empty';

  @override
  String get enterValidApiUrl => 'Enter a valid API URL';

  @override
  String get restartRequired => 'Restart required';

  @override
  String apiUrlUpdatedReloadPage(String url) {
    return 'API URL updated to $url. Reload the page to connect to the new server.';
  }

  @override
  String apiUrlUpdatedRestartApp(String url) {
    return 'API URL updated to $url. Restart the app to connect to the new server.';
  }

  @override
  String get restartApp => 'Restart app';

  @override
  String get ok => 'OK';

  @override
  String get help => 'Help';

  @override
  String currentApiUrl(String url) {
    return 'Current: $url';
  }

  @override
  String get usingSavedDevOverride => 'Using saved dev override';

  @override
  String get apiBaseUrlLabel => 'API base URL';

  @override
  String get presetLocalhost => 'Localhost';

  @override
  String get presetAndroidEmulator => 'Android emulator';

  @override
  String get presetStaging => 'Staging';

  @override
  String get presetProduction => 'Production';

  @override
  String get presetLanEditIp => 'LAN (edit IP)';

  @override
  String get resetDefault => 'Reset default';

  @override
  String get save => 'Save';

  @override
  String get developerSettings => 'Developer settings';

  @override
  String get loginSubtitleGuardianDev =>
      'Use dev guardian credentials to test against the local API.';

  @override
  String get loginSubtitleStaffDev =>
      'Use dev staff credentials to test against the local API.';

  @override
  String get missingSessionDetailsRouteData =>
      'Missing session details route data.';

  @override
  String get missingGradeDetailsRouteData =>
      'Missing grade details route data.';

  @override
  String get missingReportCardRouteData => 'Missing report card route data.';

  @override
  String get missingPaymentDetailsRouteData =>
      'Missing payment details route data.';

  @override
  String get missingMessageDetailsRouteData =>
      'Missing message details route data.';

  @override
  String get missingAttendanceFlowRouteData =>
      'Missing attendance flow route data.';

  @override
  String get missingMarksEntryRouteData => 'Missing marks entry route data.';

  @override
  String get signedInNoGuardianProfile =>
      'Signed in, but no linked guardian/staff profile. Run: bun seed --scope auth:link';

  @override
  String get signedInNoStaffProfile =>
      'Signed in, but no linked staff profile. Run: bun seed --scope auth:link';

  @override
  String get signedInNoTeacherProfile =>
      'Signed in, but no linked teacher profile. Run: bun seed --scope auth:link';

  @override
  String get accountNotLinkedToStaff =>
      'This account is not linked to a staff profile.';

  @override
  String get accountNotLinkedToTeacher =>
      'This account is not linked to a teacher profile.';

  @override
  String get navHome => 'Home';

  @override
  String get navAgenda => 'Agenda';

  @override
  String get navClasses => 'Classes';

  @override
  String get navCalendar => 'Calendar';

  @override
  String get navAcademic => 'Academic';

  @override
  String get navFees => 'Fees';

  @override
  String get navInbox => 'Inbox';

  @override
  String get navEvaluations => 'Evaluations';

  @override
  String get navTeaching => 'Teaching';

  @override
  String get navReportCards => 'Report cards';

  @override
  String get teachingTitle => 'Teaching';

  @override
  String get reportCardsTitle => 'Report cards';

  @override
  String get teachingSelectClass => 'Class';

  @override
  String get teachingSelectSubject => 'Subject';

  @override
  String get teachingProgressTab => 'Progress';

  @override
  String get teachingLogbookTab => 'Logbook';

  @override
  String get noTeachingLogEntries => 'No logbook entries for this subject yet.';

  @override
  String couldNotLoadTeachingData(String error) {
    return 'Could not load teaching data: $error';
  }

  @override
  String couldNotLoadReportCards(String error) {
    return 'Could not load report cards: $error';
  }

  @override
  String get reportCardClassNoResults =>
      'No report cards generated for this period.';

  @override
  String reportCardClassProgress(int filled, int total) {
    return '$filled / $total comments filled';
  }

  @override
  String get reportCardRosterComingSoon => 'Student roster coming soon.';

  @override
  String get missingReportCardRosterRouteData =>
      'Missing report card roster route data.';

  @override
  String couldNotLoadReportCardRoster(String error) {
    return 'Could not load report card roster: $error';
  }

  @override
  String couldNotLoadReportCardComments(String error) {
    return 'Could not load report card comments: $error';
  }

  @override
  String couldNotSaveReportCardComment(String error) {
    return 'Could not save report card comment: $error';
  }

  @override
  String get reportCardCommentsTitle => 'Report card comments';

  @override
  String get reportCardCommentHint => 'Enter your comment';

  @override
  String get reportCardCommentsReadOnly =>
      'This report card is published and cannot be edited.';

  @override
  String get reportCardCommentNoEditableFields =>
      'No comment fields are available for your role on this report card.';

  @override
  String subjectComment(String subject) {
    return '$subject comment';
  }

  @override
  String get reportCardStatusDraft => 'Draft';

  @override
  String get reportCardStatusPublished => 'Published';

  @override
  String get tooltipAccount => 'Account';

  @override
  String get loading => 'Loading…';

  @override
  String get selectAStudent => 'Select a student';

  @override
  String get notEnrolled => 'Not enrolled';

  @override
  String get schoolYear => 'School year';

  @override
  String get tooltipMyStudents => 'My students';

  @override
  String get unknownUser => 'Unknown user';

  @override
  String get noAcademicYearsAvailable => 'No academic years available.';

  @override
  String get activeYear => 'Active year';

  @override
  String couldNotLoadAcademicYears(String error) {
    return 'Could not load academic years: $error';
  }

  @override
  String couldNotLoadStudentContext(String error) {
    return 'Could not load student context: $error';
  }

  @override
  String couldNotLoadEnrollment(String error) {
    return 'Could not load enrollment: $error';
  }

  @override
  String get myStudents => 'My students';

  @override
  String get noLinkedStudentsFound => 'No linked students found.';

  @override
  String matriculeLabel(String matricule) {
    return 'Matricule: $matricule';
  }

  @override
  String statusLabel(String status) {
    return 'Status: $status';
  }

  @override
  String couldNotLoadLinkedStudents(String error) {
    return 'Could not load linked students: $error';
  }

  @override
  String get calendarViewTimetable => 'Timetable';

  @override
  String get calendarViewEvents => 'Events';

  @override
  String get allAttendance => 'All attendance';

  @override
  String get selectStudentToViewCalendar =>
      'Select a student to view the calendar.';

  @override
  String get studentNotEnrolledForYear =>
      'This student is not enrolled for the selected school year.';

  @override
  String get noClassesScheduledForDay => 'No classes scheduled for this day.';

  @override
  String get noSchoolEventsForPeriod => 'No school events for this period.';

  @override
  String couldNotLoadCalendar(String error) {
    return 'Could not load calendar: $error';
  }

  @override
  String couldNotLoadSessionDetails(String error) {
    return 'Could not load session details: $error';
  }

  @override
  String couldNotLoadAttendance(String error) {
    return 'Could not load attendance: $error';
  }

  @override
  String get attendance => 'Attendance';

  @override
  String get timetableSessionKindLesson => 'Lesson';

  @override
  String get timetableSessionKindActivity => 'Activity';

  @override
  String get timetableSessionKindAssessment => 'Assessment';

  @override
  String get noAttendanceRecorded => 'No attendance recorded.';

  @override
  String get classLogbook => 'Class logbook';

  @override
  String get noLogbookEntryForSession => 'No logbook entry for this session.';

  @override
  String get homeworkLabel => 'Homework';

  @override
  String homeworkValue(String homework) {
    return 'Homework: $homework';
  }

  @override
  String progressPercent(int percent) {
    return 'Progress: $percent%';
  }

  @override
  String get noAttendanceRecordsForStudent =>
      'No attendance records for this student.';

  @override
  String get tooltipPreviousWeek => 'Previous week';

  @override
  String get tooltipNextWeek => 'Next week';

  @override
  String get dayLetterMon => 'M';

  @override
  String get dayLetterTue => 'T';

  @override
  String get dayLetterWed => 'W';

  @override
  String get dayLetterThu => 'T';

  @override
  String get dayLetterFri => 'F';

  @override
  String get dayLetterSat => 'S';

  @override
  String get dayLetterSun => 'S';

  @override
  String get academicViewGrades => 'Grades';

  @override
  String get academicViewCurriculum => 'Curriculum';

  @override
  String get academicViewReports => 'Reports';

  @override
  String get allPeriods => 'All periods';

  @override
  String get selectStudentToViewAcademic =>
      'Select a student to view academic information.';

  @override
  String get noGradesForPeriod => 'No grades recorded for this period.';

  @override
  String get noCurriculumProgressYet => 'No curriculum progress available yet.';

  @override
  String get noReportCardsYet => 'No published report cards yet.';

  @override
  String couldNotLoadAcademicData(String error) {
    return 'Could not load academic data: $error';
  }

  @override
  String couldNotLoadReportCard(String error) {
    return 'Could not load report card: $error';
  }

  @override
  String get subjectFallback => 'Subject';

  @override
  String get periodFallback => 'Period';

  @override
  String get unitFallback => 'Unit';

  @override
  String gradePeriodCoefficient(String periodName, String coefficient) {
    return '$periodName · Coefficient $coefficient';
  }

  @override
  String get score => 'Score';

  @override
  String get notGradedYet => 'Not graded yet';

  @override
  String get notes => 'Notes';

  @override
  String get average => 'Average';

  @override
  String get scoreOutOfTwenty => '/ 20';

  @override
  String get graded => 'Graded';

  @override
  String get pending => 'Pending';

  @override
  String assessmentCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count assessments',
      one: '1 assessment',
    );
    return '$_temp0';
  }

  @override
  String subjectAverage(String average) {
    return 'Average $average / 20';
  }

  @override
  String get noScoreDash => '—';

  @override
  String percentComplete(int percent) {
    return '$percent% complete';
  }

  @override
  String get noProgrammeUnitsTracked => 'No programme units tracked yet.';

  @override
  String get publishedReportCard => 'Published report card';

  @override
  String publishedOn(String date) {
    return 'Published $date';
  }

  @override
  String scoreOutOfTwentyValue(String average) {
    return '$average / 20';
  }

  @override
  String rankLabel(int rank, int classSize) {
    return 'Rank $rank/$classSize';
  }

  @override
  String get reportCardNotFound => 'Report card not found.';

  @override
  String overallAverage(String average) {
    return 'Overall average: $average / 20';
  }

  @override
  String classRank(int rank, int classSize) {
    return 'Class rank: $rank/$classSize';
  }

  @override
  String get homeroomComment => 'Homeroom comment';

  @override
  String get principalComment => 'Principal comment';

  @override
  String get feeLinesSection => 'Fee lines';

  @override
  String get noFeeLinesForYear => 'No fee lines for this school year.';

  @override
  String get paymentsSection => 'Payments';

  @override
  String get noPaymentsRecordedYet => 'No payments recorded yet.';

  @override
  String get selectStudentToViewFees =>
      'Select a student to view fees and payments.';

  @override
  String get noFeesOrPaymentsForYear =>
      'No fee lines or payments for the selected school year.';

  @override
  String get schoolFee => 'School fee';

  @override
  String couldNotLoadFees(String error) {
    return 'Could not load fees: $error';
  }

  @override
  String get paymentMethodCash => 'Cash';

  @override
  String get paymentMethodCard => 'Card';

  @override
  String get paymentMethodBankTransfer => 'Bank transfer';

  @override
  String get paymentMethodMobileMoney => 'Mobile money';

  @override
  String get paymentMethodOther => 'Other';

  @override
  String get feeStatusPaid => 'Paid';

  @override
  String get feeStatusPartiallyPaid => 'Partially paid';

  @override
  String get feeStatusOverdue => 'Overdue';

  @override
  String get feeStatusCancelled => 'Cancelled';

  @override
  String get feeStatusDue => 'Due';

  @override
  String get summary => 'Summary';

  @override
  String get expected => 'Expected';

  @override
  String get paid => 'Paid';

  @override
  String get balance => 'Balance';

  @override
  String overdueFeeLinesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count overdue fee lines',
      one: '1 overdue fee line',
    );
    return '$_temp0';
  }

  @override
  String dueDate(String date) {
    return 'Due $date';
  }

  @override
  String paymentCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count payments',
      one: '1 payment',
    );
    return '$_temp0';
  }

  @override
  String paidAmount(String amount) {
    return 'Paid $amount';
  }

  @override
  String get paymentDetails => 'Payment details';

  @override
  String get amount => 'Amount';

  @override
  String get date => 'Date';

  @override
  String get method => 'Method';

  @override
  String get reference => 'Reference';

  @override
  String unreadCount(int count) {
    return '$count unread';
  }

  @override
  String get noMessagesInInbox => 'No messages in your inbox yet.';

  @override
  String couldNotLoadInbox(String error) {
    return 'Could not load inbox: $error';
  }

  @override
  String get inboxStatusPending => 'Pending';

  @override
  String get inboxStatusNew => 'New';

  @override
  String get inboxStatusFailed => 'Failed';

  @override
  String get inboxStatusRead => 'Read';

  @override
  String get inboxStatusCancelled => 'Cancelled';

  @override
  String get messageDefaultTitle => 'Message';

  @override
  String get messageTitle => 'Message';

  @override
  String couldNotMarkMessageRead(String error) {
    return 'Could not mark message as read: $error';
  }

  @override
  String get allClasses => 'All classes';

  @override
  String get evaluationsTitle => 'Evaluations';

  @override
  String get calendarTitle => 'Calendar';

  @override
  String evaluationCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count evaluations',
      one: '1 evaluation',
    );
    return '$_temp0';
  }

  @override
  String sessionCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count sessions',
      one: '1 session',
    );
    return '$_temp0';
  }

  @override
  String get tooltipNewEvaluation => 'New evaluation';

  @override
  String get tooltipFilter => 'Filter';

  @override
  String get teacherFallbackName => 'Teacher';

  @override
  String get filterTitle => 'Filter';

  @override
  String get classLabel => 'Class';

  @override
  String couldNotLoadTeachingContext(String error) {
    return 'Could not load teaching context: $error';
  }

  @override
  String get signInToViewCalendar => 'Sign in to view your teaching calendar.';

  @override
  String get noClassesAssignedForYear =>
      'No classes assigned for this school year.';

  @override
  String get classSessionFallback => 'Class session';

  @override
  String get logbook => 'Logbook';

  @override
  String attendanceProgress(int recorded, int total) {
    return 'Attendance $recorded / $total';
  }

  @override
  String get takeAttendance => 'Take attendance';

  @override
  String get logbookNotAvailableForSession =>
      'Logbook is not available for this session.';

  @override
  String get attendanceRecordingLessonOnly =>
      'Attendance can only be recorded for lesson sessions.';

  @override
  String get noCurriculumChaptersLinked =>
      'No curriculum chapters linked to this subject.';

  @override
  String get chapterLabel => 'Chapter';

  @override
  String get contentLabel => 'Content';

  @override
  String get objectivesLabel => 'Objectives (one per line)';

  @override
  String get progressPercentLabel => 'Progress %';

  @override
  String get saveLogbook => 'Save logbook';

  @override
  String get logbookSaved => 'Logbook saved';

  @override
  String get sessionNotesLabel => 'Lesson notes';

  @override
  String get sessionNotesDescription =>
      'Session-wide narrative for this lesson.';

  @override
  String get sessionNotesHint => 'What was covered in this lesson?';

  @override
  String get saveSessionNotes => 'Save notes';

  @override
  String get sessionNotesSaved => 'Lesson notes saved';

  @override
  String couldNotSaveSessionNote(String error) {
    return 'Could not save lesson notes: $error';
  }

  @override
  String get curriculumProgressTitle => 'Curriculum progress';

  @override
  String get curriculumProgressDescription =>
      'Record how far each curriculum matter advanced in this lesson.';

  @override
  String subjectProgressSummary(int percent) {
    return 'Subject $percent%';
  }

  @override
  String cumulativeProgressLabel(int percent) {
    return 'Overall $percent%';
  }

  @override
  String lessonProgressLabel(int percent) {
    return 'This lesson $percent%';
  }

  @override
  String get lessonProgressPercentLabel => 'Progress for this lesson (%)';

  @override
  String get matterNotesLabel => 'Matter notes';

  @override
  String get noMatterProgressForSession =>
      'No progress recorded for this matter in this lesson yet.';

  @override
  String get recordMatterProgress => 'Record progress';

  @override
  String get editMatterProgress => 'Edit progress';

  @override
  String get saveMatterProgress => 'Save progress';

  @override
  String get matterProgressSaved => 'Curriculum progress saved';

  @override
  String couldNotSaveMatterProgress(String error) {
    return 'Could not save curriculum progress: $error';
  }

  @override
  String matterProgressMinimum(int percent) {
    return 'Must be at least $percent%';
  }

  @override
  String progressMustNotDecrease(int percent) {
    return 'Progress must be at least $percent%';
  }

  @override
  String get matterStatusNotStarted => 'Not started';

  @override
  String get matterStatusInProgress => 'In progress';

  @override
  String get matterStatusCompleted => 'Completed';

  @override
  String get addCurriculumProgress => 'Add curriculum progress';

  @override
  String get addAnotherCurriculumProgress => 'Add another matter';

  @override
  String get pickSubjectMatterTitle => 'Select curriculum matter';

  @override
  String get pickSubjectMatterDescription =>
      'Choose the matter you covered in this lesson.';

  @override
  String get noRecordedMatterProgress =>
      'No curriculum progress recorded for this lesson yet.';

  @override
  String get allMattersRecordedForSession =>
      'All linked curriculum matters have been recorded for this lesson.';

  @override
  String get notRecorded => 'Not recorded';

  @override
  String get record => 'Record';

  @override
  String get edit => 'Edit';

  @override
  String get attendanceStatusPresent => 'Present';

  @override
  String get attendanceStatusAbsent => 'Absent';

  @override
  String get attendanceStatusLate => 'Late';

  @override
  String attendanceFlowTitle(String classLabel) {
    return 'Attendance · $classLabel';
  }

  @override
  String get noStudentsToRecord => 'No students to record.';

  @override
  String attendanceRecordedProgress(int recorded, int total) {
    return '$recorded / $total recorded';
  }

  @override
  String get attendanceComplete => 'Attendance complete';

  @override
  String get markAllPresent => 'Mark all present';

  @override
  String get attendanceModeGrid => 'Grid';

  @override
  String get attendanceModeSequential => 'Sequential';

  @override
  String attendanceExceptionTitle(String studentName) {
    return 'Attendance · $studentName';
  }

  @override
  String get attendanceReasonLabel => 'Reason';

  @override
  String get attendanceReasonHint => 'e.g. illness, appointment';

  @override
  String get attendanceNotesLabel => 'Notes';

  @override
  String get attendanceNotesHint => 'Optional context for the school office';

  @override
  String get attendanceSavedLocally => 'Saved locally — will sync when online';

  @override
  String get calendarTodayTitle => 'Today';

  @override
  String get calendarGoToToday => 'Go to today';

  @override
  String get calendarCurrentSession => 'Now';

  @override
  String get calendarNextSession => 'Up next';

  @override
  String get calendarNoSessionsToday => 'No sessions scheduled for today.';

  @override
  String calendarIncompleteAttendance(String classLabel, String subjectLabel) {
    return 'Attendance · $classLabel $subjectLabel';
  }

  @override
  String get sessionAttendanceComplete => 'Attendance complete';

  @override
  String get sessionAttendanceIncomplete => 'Attendance incomplete';

  @override
  String get logbookDraftRestored => 'Restored unsaved logbook draft';

  @override
  String get done => 'Done';

  @override
  String get cancel => 'Cancel';

  @override
  String get reviewAgain => 'Review again';

  @override
  String couldNotLoadSession(String error) {
    return 'Could not load session: $error';
  }

  @override
  String couldNotSaveAttendance(String error) {
    return 'Could not save attendance: $error';
  }

  @override
  String couldNotSaveLogbook(String error) {
    return 'Could not save logbook: $error';
  }

  @override
  String get chapterFallback => 'Chapter';

  @override
  String evaluationGradedProgress(int graded, int total) {
    return '$graded / $total graded';
  }

  @override
  String get selectPeriodToViewEvaluations =>
      'Select a period to view evaluations.';

  @override
  String get noEvaluationsForPeriod => 'No evaluations for this period.';

  @override
  String couldNotLoadEvaluations(String error) {
    return 'Could not load evaluations: $error';
  }

  @override
  String couldNotLoadMarks(String error) {
    return 'Could not load marks: $error';
  }

  @override
  String couldNotSaveMark(String error) {
    return 'Could not save mark: $error';
  }

  @override
  String get publishedReportCardImmutable =>
      'This student\'s report card has already been published for this period. Marks can no longer be changed.';

  @override
  String get marksLockedReportCardPublished => 'Report card published';

  @override
  String get marksEntryPeriodLockedHint =>
      'Report cards have been published for this period. Marks can no longer be recorded for these students.';

  @override
  String couldNotLoadSubjects(String error) {
    return 'Could not load subjects: $error';
  }

  @override
  String couldNotLoadPeriods(String error) {
    return 'Could not load periods: $error';
  }

  @override
  String get titleRequired => 'Title is required.';

  @override
  String get maxScoreMustBePositive => 'Max score must be greater than zero.';

  @override
  String get periodRequired => 'Period is required.';

  @override
  String couldNotCreateEvaluation(String error) {
    return 'Could not create evaluation: $error';
  }

  @override
  String get newEvaluation => 'New evaluation';

  @override
  String get noSubjectsAssignedForYear =>
      'No subjects assigned for this school year.';

  @override
  String get classSubjectLabel => 'Class · Subject';

  @override
  String get titleLabel => 'Title';

  @override
  String get outOfLabel => 'Out of';

  @override
  String get kindLabel => 'Kind';

  @override
  String get evaluationKindQuiz => 'Quiz';

  @override
  String get evaluationKindHomework => 'Homework';

  @override
  String get evaluationKindProject => 'Project';

  @override
  String get evaluationKindOther => 'Other';

  @override
  String get createEvaluation => 'Create evaluation';

  @override
  String get enterValidMaxScore => 'Enter a valid max score.';

  @override
  String get assessmentDateLabel => 'Assessment date';

  @override
  String get homeworkDueDateLabel => 'Homework due date';

  @override
  String get assessmentDateRequired => 'Select an assessment date.';

  @override
  String get homeworkDueDateRequired => 'Select a homework due date.';

  @override
  String invalidScoreValue(String maxScore) {
    return 'Enter a score between 0 and $maxScore.';
  }

  @override
  String get syncStatusSaved => 'Saved';

  @override
  String get syncStatusSavedLocally => 'Saved locally';

  @override
  String get syncStatusPending => 'Waiting to sync';

  @override
  String get syncStatusSyncing => 'Syncing';

  @override
  String get syncStatusSynced => 'Synced';

  @override
  String get syncStatusFailed => 'Sync failed';

  @override
  String get duplicateEvaluation => 'Duplicate';

  @override
  String get completeEvaluation => 'Mark complete';

  @override
  String get ungradedOnlyFilter => 'Ungraded only';

  @override
  String get fillAllMarks => 'Fill all';

  @override
  String get clearAllMarks => 'Clear all';

  @override
  String get familyVisibleSummaryLabel => 'Family-visible summary';

  @override
  String get familyVisiblePreviewLabel => 'Family preview';

  @override
  String get accountSyncSectionTitle => 'Synchronization';

  @override
  String accountPendingSyncSummary(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count items waiting to sync',
      one: '1 item waiting to sync',
    );
    return '$_temp0';
  }

  @override
  String accountPendingSyncOldest(String age) {
    return 'Oldest pending $age';
  }

  @override
  String get accountPendingSyncNone => 'All changes are synced';

  @override
  String get accountSyncNow => 'Sync now';

  @override
  String get accountPendingSyncJustNow => 'just now';

  @override
  String accountPendingSyncMinutes(int minutes) {
    return '$minutes min ago';
  }

  @override
  String accountPendingSyncHours(int hours) {
    return '$hours hr ago';
  }

  @override
  String accountPendingSyncDays(int days) {
    return '$days d ago';
  }

  @override
  String outOfMaxScore(String maxScore) {
    return 'Out of $maxScore';
  }

  @override
  String currentScore(String score) {
    return 'Current: $score';
  }

  @override
  String scoreHintOutOf(String maxScore) {
    return '/ $maxScore';
  }

  @override
  String get periodLabel => 'Period';

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
  String get settingsTitle => 'Settings';

  @override
  String get settingsTheme => 'Theme';

  @override
  String get settingsThemeSystem => 'System default';

  @override
  String get settingsThemeLight => 'Light';

  @override
  String get settingsThemeDark => 'Dark';

  @override
  String get settingsLanguage => 'Language';

  @override
  String get settingsLanguageSystem => 'System default';

  @override
  String get settingsLanguageEnglish => 'English';

  @override
  String get settingsLanguageFrench => 'French';

  @override
  String get settingsTimezone => 'Time zone';

  @override
  String get settingsTimezoneDevice => 'Device time zone';

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
  String get settingsDateFormat => 'Date format';

  @override
  String get settingsDateFormatSystem => 'System default';

  @override
  String get settingsDateFormatShort => 'Short';

  @override
  String get settingsDateFormatMedium => 'Medium';

  @override
  String get settingsDateFormatLong => 'Long';

  @override
  String get settingsTimeFormat => 'Time format';

  @override
  String get settingsTimeFormatSystem => 'System default';

  @override
  String get settingsTimeFormat24h => '24-hour';

  @override
  String get settingsTimeFormat12h => '12-hour';

  @override
  String get emailRequired => 'Enter your email.';

  @override
  String get sendCodeButton => 'Send code';

  @override
  String get otpSendFailed => 'Could not send a verification code.';

  @override
  String get verifyEmailTitle => 'Verify your email';

  @override
  String get otpLabel => 'Verification code';

  @override
  String get verifyCodeButton => 'Verify and continue';

  @override
  String get resendCodeButton => 'Resend code';

  @override
  String get useDifferentEmail => 'Use a different email';

  @override
  String verificationCodeSent(String email) {
    return 'We sent a code to $email.';
  }

  @override
  String get invitationTitle => 'Join your school';

  @override
  String get invitationContinue => 'Continue';

  @override
  String get invitationAcceptCta => 'Accept invitation';

  @override
  String get invitationAccepting => 'Linking your account…';

  @override
  String get invitationSuccess =>
      'Your account is linked. Opening your family view.';

  @override
  String get invitationWrongKind => 'This invitation is for another Edaya app.';

  @override
  String get invitationWrongAccount =>
      'This invitation is for a different account. Sign out, then continue with the invited email.';

  @override
  String get invitationSignOutSwitch => 'Sign out and continue';

  @override
  String get invitationNotFound => 'This invitation link was not found.';

  @override
  String get invitationExpired =>
      'This invitation has expired. Ask the school office for a new link.';

  @override
  String get invitationRevoked =>
      'This invitation was replaced. Open the latest email or ask the school office to resend.';

  @override
  String get invitationInvalid => 'This invitation is not valid.';

  @override
  String get invitationAlreadyAccepted => 'This invitation was already used.';

  @override
  String invitationLoadError(String error) {
    return 'Could not load this invitation. $error';
  }

  @override
  String invitationSummary(String name, String school) {
    return '$name is invited as a guardian at $school.';
  }

  @override
  String invitationExpires(String date) {
    return 'Expires $date';
  }

  @override
  String get missingChargeDetailsRouteData =>
      'Missing charge details route data.';

  @override
  String get waitingForStudentsTitle => 'You\'re signed in';

  @override
  String get waitingForStudentsBody =>
      'Your account is ready. When the school links you to a child, their timetable, grades, and messages will appear here.';

  @override
  String get waitingForStudentsCheckAgain => 'Check again';

  @override
  String get waitingPendingInvitationsTitle => 'Pending invitations';

  @override
  String get waitingNoPendingInvitations =>
      'No pending invitations for this email. If the school sent a link, open it from the email.';

  @override
  String get noChildrenLinkedYet =>
      'No children are linked to your account yet.';

  @override
  String get feeStatusWaived => 'Waived';

  @override
  String get availableAmount => 'Available';

  @override
  String get outstandingAmount => 'Outstanding';

  @override
  String get overdueAmount => 'Overdue';

  @override
  String get remainingAmountLabel => 'Remaining';

  @override
  String get chargeSchedule => 'Payment schedule';

  @override
  String get noInstallmentsForCharge =>
      'No installment schedule for this charge.';

  @override
  String installmentDue(String label, String date) {
    return '$label · due $date';
  }

  @override
  String get paymentKind => 'Type';

  @override
  String get paymentKindReceipt => 'Receipt';

  @override
  String get paymentKindDisbursement => 'Refund';

  @override
  String get mutationConflict =>
      'This change conflicts with the current record. Reload it and review before trying again.';

  @override
  String get mutationSavedRefreshFailed =>
      'Your change was saved, but the screen could not refresh. Reopen this screen to see the saved result.';

  @override
  String get profilePhotoCropTitle => 'Adjust portrait';

  @override
  String get profilePhotoCropHint =>
      'Rotate and confirm a square JPEG under 1 MiB.';

  @override
  String get profilePhotoRotate => 'Rotate';

  @override
  String get profilePhotoConfirmCrop => 'Use this photo';

  @override
  String get profilePhotoTooLarge =>
      'The photo is still larger than 1 MiB after compression.';

  @override
  String get profilePhotoUpdateSuccess => 'Profile photo updated.';

  @override
  String profilePhotoUpdateError(String error) {
    return 'Could not update the profile photo. $error';
  }

  @override
  String get childProfileTitle => 'Child portrait';

  @override
  String get childProfileUnavailable => 'Select a child to propose a portrait.';

  @override
  String childProfileLoadError(String error) {
    return 'Could not load the child portrait. $error';
  }

  @override
  String get childProfilePublished => 'Published portrait';

  @override
  String get childProfileProposed => 'Proposed portrait';

  @override
  String get childProfileNoPublished => 'No published portrait yet.';

  @override
  String get childProfilePending => 'Waiting for school review.';

  @override
  String get childProfilePendingIndicator =>
      'A portrait is waiting for review.';

  @override
  String get childProfileSubmitHint =>
      'Take or choose a photo. The school must approve it before it appears on documents.';

  @override
  String get childProfileSubmit => 'Submit portrait';

  @override
  String get childProfileResubmit => 'Submit a new portrait';

  @override
  String get childProfileWithdraw => 'Withdraw proposal';

  @override
  String get childProfileSubmitted => 'Portrait submitted for review.';

  @override
  String get childProfileWithdrawn => 'Proposal withdrawn.';

  @override
  String childProfileSubmitError(String error) {
    return 'Could not submit the portrait. $error';
  }

  @override
  String childProfileWithdrawError(String error) {
    return 'Could not withdraw the proposal. $error';
  }

  @override
  String childProfileRejected(String reason) {
    return 'The school rejected this portrait: $reason';
  }

  @override
  String get childProfileRejectedNoReason => 'No reason was provided.';

  @override
  String get documentsTitle => 'Official documents';

  @override
  String get tooltipDocuments => 'Official documents';

  @override
  String get documentsEntry => 'Official documents';

  @override
  String get documentsEmpty =>
      'No official documents for this school year yet.';

  @override
  String get documentsDownloadRecall =>
      'Already downloaded files cannot be remotely recalled.';

  @override
  String get documentsDownload => 'Download';

  @override
  String get documentsGeneratePdf => 'Generate PDF';

  @override
  String get documentsOpened => 'Opening the PDF.';

  @override
  String get documentsRendering =>
      'The PDF is still rendering. Open Official documents when it is ready.';

  @override
  String documentsFailed(String code) {
    return 'This document failed ($code).';
  }

  @override
  String get documentsNotIssued => 'No downloadable PDF is ready yet.';

  @override
  String get documentsOpenFailed => 'Could not open the PDF.';

  @override
  String get documentStatusRequested => 'Pending';

  @override
  String get documentStatusRendering => 'Pending';

  @override
  String get documentStatusReady => 'Issued';

  @override
  String get documentStatusFailed => 'Error';

  @override
  String get documentStatusSuperseded => 'Replaced';

  @override
  String get documentStatusVoided => 'Replaced';

  @override
  String get documentStatusPreview => 'Issued';

  @override
  String get exportLogbookPdf => 'Logbook PDF';

  @override
  String get exportTimetablePdf => 'Timetable PDF';

  @override
  String get exportRosterPdf => 'Class roster PDF';

  @override
  String get exportAttendancePdf => 'Attendance sheet PDF';

  @override
  String get familyFeedbackEntry => 'Family feedback';

  @override
  String get familyFeedbackTitle => 'Family feedback';

  @override
  String get familyFeedbackEmpty => 'No family feedback campaigns yet.';

  @override
  String get familyFeedbackConfidential =>
      'Confidential and aggregated. This is not an academic assessment.';

  @override
  String get familyFeedbackSubmit => 'Submit';

  @override
  String get familyFeedbackSubmitted => 'Your response was recorded.';

  @override
  String get familyFeedbackAlreadyCompleted =>
      'A response is already recorded for this student.';

  @override
  String get familyFeedbackClosed => 'This campaign is closed.';

  @override
  String get familyFeedbackComment => 'Optional comment';

  @override
  String get familyFeedbackCannotAssess => 'Cannot assess';

  @override
  String get familyFeedbackInsufficient => 'Insufficient responses';

  @override
  String get familyFeedbackThemes => 'Themes';

  @override
  String get familyFeedbackSlotOpen => 'Open';

  @override
  String get familyFeedbackSlotCompleted => 'Completed';

  @override
  String get teacherTaskFamilyFeedback => 'Family feedback';

  @override
  String get teacherTaskAttendance => 'Attendance to record';

  @override
  String get teacherTaskLogbook => 'Lesson log';

  @override
  String get teacherTaskMarks => 'Marks to enter';

  @override
  String get chooseSchool => 'Choose a school';

  @override
  String get teacherTaskReportComments => 'Report comments';

  @override
  String get outboxConflictTitle => 'Changes needing review';

  @override
  String get outboxDiscardEdit => 'Discard this local edit';

  @override
  String get outboxDiscardConfirm =>
      'This removes only the selected local edit. The server record is unchanged. Review the current record before entering a new edit.';

  @override
  String get marksAbsent => 'Absent';

  @override
  String get marksExempt => 'Exempt';

  @override
  String get marksDesignation => 'Mark designation';

  @override
  String get marksSubmit => 'Submit for approval';

  @override
  String get marksSubmitted => 'Marks submitted and visible to families.';

  @override
  String get marksResolveConflicts =>
      'Resolve pending conflicts before submitting.';

  @override
  String get marksInvalidNumber => 'Enter a valid numeric mark.';

  @override
  String get marksRequestCorrection => 'Request correction';

  @override
  String get marksCorrectionRequested =>
      'Correction requested. Official marks are unchanged.';

  @override
  String get marksCorrectionHint =>
      'Official marks stay unchanged until staff approval.';

  @override
  String get marksCorrectionReason => 'Reason for correction';

  @override
  String get marksCorrectionConfirm => 'I have checked all proposed changes.';

  @override
  String get marksCorrectionPending => 'Pending correction';

  @override
  String get marksCorrectionApproved => 'Approved correction';

  @override
  String get marksCorrectionRejected => 'Rejected correction';

  @override
  String get marksCorrectionWithdrawn => 'Withdrawn correction';

  @override
  String get marksWithdrawCorrection => 'Withdraw request';

  @override
  String get marksComment => 'Mark comment';

  @override
  String get marksPublishedLock => 'Locked by a published report';

  @override
  String get marksOfficial => 'Submitted · official marks';

  @override
  String get marksOriginal => 'Original';

  @override
  String get marksProposed => 'Proposed';

  @override
  String get deliveryChannel => 'Send my code by';

  @override
  String get phoneUnavailable =>
      'Phone verification is temporarily unavailable. Use email.';

  @override
  String get phoneCountryHint =>
      'Côte d’Ivoire mobile numbers only. Example: +2250712345678.';

  @override
  String get authenticatorSetup =>
      'Add this secret to your authenticator app, then enter its code.';

  @override
  String get authenticatorCode => 'Authenticator code';

  @override
  String get recoveryCode => 'Recovery code';

  @override
  String get useRecoveryCode => 'Use a recovery code';

  @override
  String get saveRecoveryCodes =>
      'Save these recovery codes securely. They are shown only once.';

  @override
  String get savedRecoveryCodes => 'I have saved my codes';

  @override
  String get accountSecurity => 'Account security';

  @override
  String get recentSignInHint =>
      'Sign in again before changing login identifiers or your authenticator.';

  @override
  String get linkIdentifier => 'Link another login identifier';

  @override
  String get unlinkIdentifier => 'Unlink and sign out';

  @override
  String get enableAuthenticator => 'Set up authenticator';

  @override
  String get recoveryEligible => 'Allow this identifier for account recovery';

  @override
  String get contactMethod => 'Verify with';

  @override
  String get verifyContactTitle => 'Verify your contact';

  @override
  String verificationContact(String contact) {
    return 'Enter the code for $contact.';
  }

  @override
  String get useMostRecentCode =>
      'Use the most recent code. Each resend replaces the previous code.';

  @override
  String get sendBySms => 'Send by SMS';

  @override
  String resendCountdown(int seconds) {
    return 'You can request another code in ${seconds}s.';
  }

  @override
  String get changeContact => 'Change contact';

  @override
  String get checkWhatsApp => 'Check WhatsApp for the code.';

  @override
  String get checkSms => 'Check your text messages for the code.';

  @override
  String get checkEmailCode => 'Check your email for the code.';

  @override
  String get codeExpired => 'This code has expired. Request a new code.';

  @override
  String get codeDeliveryFailed =>
      'We could not send the code. After the countdown, request another code.';

  @override
  String get codeDeliveryUncertain =>
      'Delivery is not confirmed. If the code arrives, you can still use it.';

  @override
  String get retryRequest => 'Retry request';

  @override
  String get testingOnly => 'Testing only';

  @override
  String get showTestCode => 'Show test code';

  @override
  String get copyTestCode => 'Copy';

  @override
  String get testCodeUnavailable => 'Test code unavailable';

  @override
  String get attendanceIncomplete =>
      'Record every student before finishing attendance.';

  @override
  String get attendanceSubmitNeedsSync =>
      'Synchronize saved drafts before finishing attendance.';

  @override
  String get workflowSynced => 'Synchronized';

  @override
  String get attendanceArrival => 'Record arrival';

  @override
  String get workflowCorrectionPending => 'Correction pending review';

  @override
  String get workflowRequestCorrection => 'Request correction';

  @override
  String get dailyAttendance => 'Daily attendance';

  @override
  String get workflowDiscipline => 'Discipline';

  @override
  String get workflowFollowUp => 'Add follow-up';

  @override
  String get deadlineCompliance => 'Homework submission';

  @override
  String get deadlineMet => 'On time';

  @override
  String get deadlineLate => 'Late';

  @override
  String get deadlineMissed => 'Missed';

  @override
  String get deadlineExcused => 'Excused';

  @override
  String get attendancePresent => 'Present';

  @override
  String get attendanceAbsent => 'Absent';

  @override
  String get attendanceLate => 'Late';

  @override
  String get attendanceFinish => 'Finish';

  @override
  String get attendanceMarkRemaining => 'Mark remaining present';

  @override
  String get workflowReviseCorrection => 'Revise request';

  @override
  String get workflowIncidentTakenOver => 'Staff have taken over this incident';

  @override
  String get workflowIncidentTitle => 'Title';

  @override
  String get workflowIncidentFacts => 'Facts';

  @override
  String get workflowIncidentPositive => 'Positive';

  @override
  String get workflowIncidentMinor => 'Minor incident';

  @override
  String get workflowIncidentMajor => 'Major incident';

  @override
  String get workflowIncidentEmergency => 'Emergency';

  @override
  String get workflowTeacherExplanation => 'Teacher explanation';

  @override
  String get messagingNew => 'New message';

  @override
  String get messagingSchool => 'School';

  @override
  String get messagingTeacher => 'Teacher';

  @override
  String get messagingSubject => 'Subject';

  @override
  String get messagingBody => 'Message';

  @override
  String get messagingSend => 'Send';

  @override
  String get messagingReply => 'Reply';

  @override
  String get messagingEmpty => 'No conversations yet';

  @override
  String get messagingOversight =>
      'Authorized school staff can review teacher conversations.';

  @override
  String get messagingIncludeChild => 'Include the selected child';

  @override
  String get messagingUnavailable =>
      'Messaging is currently unavailable for this recipient.';

  @override
  String get messagingHistory => 'Read-only conversation';

  @override
  String get messagingLoadMore => 'Load older messages';

  @override
  String get messagingRefresh => 'Refresh';

  @override
  String get messagingAwaitingSchool => 'Awaiting school';

  @override
  String get messagingAwaitingGuardian => 'Awaiting guardian';

  @override
  String get messagingResolved => 'Resolved';

  @override
  String get messagingFailed =>
      'Unable to send. Your draft is preserved. Try again.';

  @override
  String get messagingChanged =>
      'New activity is available. Review the conversation before sending again.';

  @override
  String get messagingRequired => 'Enter a subject and a message.';

  @override
  String get messagingSchoolAuthor => 'School staff';

  @override
  String get messagingRead => 'Read';

  @override
  String get messagingUnread => 'Unread';

  @override
  String get messagingConversations => 'Conversations';
}
