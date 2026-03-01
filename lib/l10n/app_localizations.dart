import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_ml.dart';

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
    Locale('ml'),
  ];

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @selectLanguage.
  ///
  /// In en, this message translates to:
  /// **'Select Language'**
  String get selectLanguage;

  /// No description provided for @notifications.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get notifications;

  /// No description provided for @logout.
  ///
  /// In en, this message translates to:
  /// **'Logout'**
  String get logout;

  /// No description provided for @login.
  ///
  /// In en, this message translates to:
  /// **'Login'**
  String get login;

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'CareNow'**
  String get appTitle;

  /// No description provided for @welcomeBack.
  ///
  /// In en, this message translates to:
  /// **'Welcome Back'**
  String get welcomeBack;

  /// No description provided for @email.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get email;

  /// No description provided for @password.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get password;

  /// No description provided for @myCare.
  ///
  /// In en, this message translates to:
  /// **'My Care'**
  String get myCare;

  /// No description provided for @resetPassword.
  ///
  /// In en, this message translates to:
  /// **'Reset Password'**
  String get resetPassword;

  /// No description provided for @checkEmail.
  ///
  /// In en, this message translates to:
  /// **'Check your email'**
  String get checkEmail;

  /// No description provided for @sentRecoveryInstructions.
  ///
  /// In en, this message translates to:
  /// **'We have sent password recovery instructions to your email.'**
  String get sentRecoveryInstructions;

  /// No description provided for @backToLogin.
  ///
  /// In en, this message translates to:
  /// **'Back to Login'**
  String get backToLogin;

  /// No description provided for @enterEmailForReset.
  ///
  /// In en, this message translates to:
  /// **'Enter your email address and we will send you a link to reset your password.'**
  String get enterEmailForReset;

  /// No description provided for @emailAddress.
  ///
  /// In en, this message translates to:
  /// **'Email Address'**
  String get emailAddress;

  /// No description provided for @sendResetLink.
  ///
  /// In en, this message translates to:
  /// **'Send Reset Link'**
  String get sendResetLink;

  /// No description provided for @createAccount.
  ///
  /// In en, this message translates to:
  /// **'Create Account'**
  String get createAccount;

  /// No description provided for @elderly.
  ///
  /// In en, this message translates to:
  /// **'Elderly'**
  String get elderly;

  /// No description provided for @caregiver.
  ///
  /// In en, this message translates to:
  /// **'Caregiver'**
  String get caregiver;

  /// No description provided for @staff.
  ///
  /// In en, this message translates to:
  /// **'Staff'**
  String get staff;

  /// No description provided for @completeRegistration.
  ///
  /// In en, this message translates to:
  /// **'Complete Registration'**
  String get completeRegistration;

  /// No description provided for @fullName.
  ///
  /// In en, this message translates to:
  /// **'Full Name'**
  String get fullName;

  /// No description provided for @simplifiedRegistration.
  ///
  /// In en, this message translates to:
  /// **'Simplified Registration for Easy Access'**
  String get simplifiedRegistration;

  /// No description provided for @dobOptional.
  ///
  /// In en, this message translates to:
  /// **'Date of Birth (Optional)'**
  String get dobOptional;

  /// No description provided for @linkToElderly.
  ///
  /// In en, this message translates to:
  /// **'Link your account to an Elderly user'**
  String get linkToElderly;

  /// No description provided for @elderlyLinkId.
  ///
  /// In en, this message translates to:
  /// **'Elderly Link ID / Code'**
  String get elderlyLinkId;

  /// No description provided for @relationship.
  ///
  /// In en, this message translates to:
  /// **'Relationship'**
  String get relationship;

  /// No description provided for @adminApprovalRequired.
  ///
  /// In en, this message translates to:
  /// **'Registration requires Admin Approval.'**
  String get adminApprovalRequired;

  /// No description provided for @staffId.
  ///
  /// In en, this message translates to:
  /// **'Staff ID / Badge Number'**
  String get staffId;

  /// No description provided for @department.
  ///
  /// In en, this message translates to:
  /// **'Department'**
  String get department;

  /// No description provided for @welcomeToCareNow.
  ///
  /// In en, this message translates to:
  /// **'Welcome to\nCareNow'**
  String get welcomeToCareNow;

  /// No description provided for @selectLanguagePrompt.
  ///
  /// In en, this message translates to:
  /// **'Please select your preferred language to continue.'**
  String get selectLanguagePrompt;

  /// No description provided for @medication.
  ///
  /// In en, this message translates to:
  /// **'Medication'**
  String get medication;

  /// No description provided for @appointments.
  ///
  /// In en, this message translates to:
  /// **'Appointments'**
  String get appointments;

  /// No description provided for @emergency.
  ///
  /// In en, this message translates to:
  /// **'Emergency'**
  String get emergency;

  /// No description provided for @profile.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get profile;

  /// No description provided for @dashboardFor.
  ///
  /// In en, this message translates to:
  /// **'Dashboard for'**
  String get dashboardFor;

  /// No description provided for @nextDose.
  ///
  /// In en, this message translates to:
  /// **'Next Dose'**
  String get nextDose;

  /// No description provided for @vitals.
  ///
  /// In en, this message translates to:
  /// **'Vitals'**
  String get vitals;

  /// No description provided for @staffPortal.
  ///
  /// In en, this message translates to:
  /// **'Staff Portal'**
  String get staffPortal;

  /// No description provided for @searchPatientRecords.
  ///
  /// In en, this message translates to:
  /// **'Search Patient Records...'**
  String get searchPatientRecords;

  /// No description provided for @forgotPasswordQuestion.
  ///
  /// In en, this message translates to:
  /// **'Forgot Password?'**
  String get forgotPasswordQuestion;

  /// No description provided for @createAccountQuestion.
  ///
  /// In en, this message translates to:
  /// **'New here? Create an Account'**
  String get createAccountQuestion;

  /// No description provided for @username.
  ///
  /// In en, this message translates to:
  /// **'Username'**
  String get username;

  /// No description provided for @usernameError.
  ///
  /// In en, this message translates to:
  /// **'Please enter username'**
  String get usernameError;

  /// No description provided for @userNotRegistered.
  ///
  /// In en, this message translates to:
  /// **'User not registered'**
  String get userNotRegistered;

  /// No description provided for @incorrectPassword.
  ///
  /// In en, this message translates to:
  /// **'Incorrect password'**
  String get incorrectPassword;

  /// No description provided for @emailAvailable.
  ///
  /// In en, this message translates to:
  /// **'Email already available'**
  String get emailAvailable;

  /// No description provided for @registrationFailed.
  ///
  /// In en, this message translates to:
  /// **'Registration failed'**
  String get registrationFailed;

  /// No description provided for @unexpectedError.
  ///
  /// In en, this message translates to:
  /// **'An unexpected error occurred'**
  String get unexpectedError;

  /// No description provided for @uniqueId.
  ///
  /// In en, this message translates to:
  /// **'My Unique ID'**
  String get uniqueId;

  /// No description provided for @elderlyMode.
  ///
  /// In en, this message translates to:
  /// **'Elderly Mode (Large Text)'**
  String get elderlyMode;

  /// No description provided for @elderlyModeDesc.
  ///
  /// In en, this message translates to:
  /// **'Increases text size'**
  String get elderlyModeDesc;

  /// No description provided for @changePassword.
  ///
  /// In en, this message translates to:
  /// **'Change Password'**
  String get changePassword;

  /// No description provided for @currentPassword.
  ///
  /// In en, this message translates to:
  /// **'Current Password'**
  String get currentPassword;

  /// No description provided for @newPassword.
  ///
  /// In en, this message translates to:
  /// **'New Password'**
  String get newPassword;

  /// No description provided for @update.
  ///
  /// In en, this message translates to:
  /// **'Update'**
  String get update;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @passwordChanged.
  ///
  /// In en, this message translates to:
  /// **'Password changed successfully'**
  String get passwordChanged;

  /// No description provided for @manageLinkedElderly.
  ///
  /// In en, this message translates to:
  /// **'Manage Linked Elderly'**
  String get manageLinkedElderly;

  /// No description provided for @linkedMsg.
  ///
  /// In en, this message translates to:
  /// **'{count} / 5 linked'**
  String linkedMsg(Object count);

  /// No description provided for @noElderlyLinked.
  ///
  /// In en, this message translates to:
  /// **'No elderly linked yet.'**
  String get noElderlyLinked;

  /// No description provided for @addElderlyId.
  ///
  /// In en, this message translates to:
  /// **'Add Elderly ID (e.g. ELD-1234)'**
  String get addElderlyId;

  /// No description provided for @add.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get add;

  /// No description provided for @close.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get close;

  /// No description provided for @limitReached.
  ///
  /// In en, this message translates to:
  /// **'Limit of 5 reached'**
  String get limitReached;

  /// No description provided for @mandatory.
  ///
  /// In en, this message translates to:
  /// **'*'**
  String get mandatory;

  /// No description provided for @accountDisabled.
  ///
  /// In en, this message translates to:
  /// **'Your account has been disabled. Contact Admin.'**
  String get accountDisabled;

  /// No description provided for @staffIdOnly.
  ///
  /// In en, this message translates to:
  /// **'Staff ID'**
  String get staffIdOnly;

  /// No description provided for @condition.
  ///
  /// In en, this message translates to:
  /// **'Condition'**
  String get condition;

  /// No description provided for @medicines.
  ///
  /// In en, this message translates to:
  /// **'Medicines'**
  String get medicines;

  /// No description provided for @profileNotFound.
  ///
  /// In en, this message translates to:
  /// **'Profile not found'**
  String get profileNotFound;

  /// No description provided for @searchByUniqueId.
  ///
  /// In en, this message translates to:
  /// **'Search by Unique ID'**
  String get searchByUniqueId;

  /// No description provided for @dateOfBirth.
  ///
  /// In en, this message translates to:
  /// **'Date of Birth'**
  String get dateOfBirth;

  /// No description provided for @passwordHelper.
  ///
  /// In en, this message translates to:
  /// **'Must contain at least 1 special char & 1 number'**
  String get passwordHelper;

  /// No description provided for @caregiverFamily.
  ///
  /// In en, this message translates to:
  /// **'Caregiver/Family Member'**
  String get caregiverFamily;

  /// No description provided for @volunteer.
  ///
  /// In en, this message translates to:
  /// **'Volunteer'**
  String get volunteer;

  /// No description provided for @ageEligibilityError.
  ///
  /// In en, this message translates to:
  /// **'You are not eligible to register as an elderly user'**
  String get ageEligibilityError;

  /// No description provided for @medicineTiming.
  ///
  /// In en, this message translates to:
  /// **'Medicine Timing'**
  String get medicineTiming;

  /// No description provided for @volunteerHub.
  ///
  /// In en, this message translates to:
  /// **'Volunteer Hub'**
  String get volunteerHub;

  /// No description provided for @welcomeVolunteer.
  ///
  /// In en, this message translates to:
  /// **'Welcome, Volunteer!'**
  String get welcomeVolunteer;

  /// No description provided for @thankYouVolunteer.
  ///
  /// In en, this message translates to:
  /// **'Thank you for joining our community.'**
  String get thankYouVolunteer;

  /// No description provided for @viewAvailableTasks.
  ///
  /// In en, this message translates to:
  /// **'View Available Tasks'**
  String get viewAvailableTasks;

  /// No description provided for @noConditions.
  ///
  /// In en, this message translates to:
  /// **'No conditions recorded'**
  String get noConditions;

  /// No description provided for @noMedicines.
  ///
  /// In en, this message translates to:
  /// **'No medicines recorded'**
  String get noMedicines;

  /// No description provided for @noTiming.
  ///
  /// In en, this message translates to:
  /// **'No timing recorded'**
  String get noTiming;

  /// No description provided for @confirmPassword.
  ///
  /// In en, this message translates to:
  /// **'Confirm Password'**
  String get confirmPassword;

  /// No description provided for @passwordsDoNotMatch.
  ///
  /// In en, this message translates to:
  /// **'Passwords do not match'**
  String get passwordsDoNotMatch;

  /// No description provided for @selectRole.
  ///
  /// In en, this message translates to:
  /// **'Select Role'**
  String get selectRole;

  /// No description provided for @requestHospitalAccess.
  ///
  /// In en, this message translates to:
  /// **'Request Hospital Access'**
  String get requestHospitalAccess;

  /// No description provided for @accessRequested.
  ///
  /// In en, this message translates to:
  /// **'Access Requested'**
  String get accessRequested;

  /// No description provided for @accessPending.
  ///
  /// In en, this message translates to:
  /// **'Access Pending'**
  String get accessPending;

  /// No description provided for @accessApproved.
  ///
  /// In en, this message translates to:
  /// **'Access Approved'**
  String get accessApproved;

  /// No description provided for @accessRejected.
  ///
  /// In en, this message translates to:
  /// **'Access Rejected'**
  String get accessRejected;

  /// No description provided for @approve.
  ///
  /// In en, this message translates to:
  /// **'Approve'**
  String get approve;

  /// No description provided for @reject.
  ///
  /// In en, this message translates to:
  /// **'Reject'**
  String get reject;

  /// No description provided for @patientRequests.
  ///
  /// In en, this message translates to:
  /// **'Patient Requests'**
  String get patientRequests;

  /// No description provided for @approvedPatients.
  ///
  /// In en, this message translates to:
  /// **'Approved Patients'**
  String get approvedPatients;

  /// No description provided for @myDetails.
  ///
  /// In en, this message translates to:
  /// **'My Details'**
  String get myDetails;

  /// No description provided for @familyMember.
  ///
  /// In en, this message translates to:
  /// **'Family Member'**
  String get familyMember;

  /// No description provided for @volunteerRegistrationSuccess.
  ///
  /// In en, this message translates to:
  /// **'Volunteer registration submitted successfully'**
  String get volunteerRegistrationSuccess;

  /// No description provided for @volunteerAlert.
  ///
  /// In en, this message translates to:
  /// **'Please review the volunteer guidelines'**
  String get volunteerAlert;

  /// No description provided for @request.
  ///
  /// In en, this message translates to:
  /// **'Request'**
  String get request;

  /// No description provided for @joinVolunteer.
  ///
  /// In en, this message translates to:
  /// **'Join as a Volunteer to help the community'**
  String get joinVolunteer;

  /// No description provided for @sendRequest.
  ///
  /// In en, this message translates to:
  /// **'Send Request'**
  String get sendRequest;

  /// No description provided for @hospitalAccess.
  ///
  /// In en, this message translates to:
  /// **'Hospital Access'**
  String get hospitalAccess;

  /// No description provided for @noId.
  ///
  /// In en, this message translates to:
  /// **'No ID'**
  String get noId;

  /// No description provided for @unknown.
  ///
  /// In en, this message translates to:
  /// **'Unknown'**
  String get unknown;

  /// No description provided for @notAvailable.
  ///
  /// In en, this message translates to:
  /// **'N/A'**
  String get notAvailable;

  /// No description provided for @userDoesNotExist.
  ///
  /// In en, this message translates to:
  /// **'User does not exist'**
  String get userDoesNotExist;

  /// No description provided for @accountAlreadyLinked.
  ///
  /// In en, this message translates to:
  /// **'Elderly Unit ID is already linked to another caregiver and cannot be reused, as one elderly can be connected to only one caregiver.'**
  String get accountAlreadyLinked;

  /// No description provided for @selectDoctor.
  ///
  /// In en, this message translates to:
  /// **'Select Doctor'**
  String get selectDoctor;

  /// No description provided for @confirmAppointment.
  ///
  /// In en, this message translates to:
  /// **'Confirm Appointment'**
  String get confirmAppointment;

  /// No description provided for @doctor.
  ///
  /// In en, this message translates to:
  /// **'Doctor'**
  String get doctor;

  /// No description provided for @date.
  ///
  /// In en, this message translates to:
  /// **'Date'**
  String get date;

  /// No description provided for @confirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get confirm;

  /// No description provided for @appointmentBookedSuccess.
  ///
  /// In en, this message translates to:
  /// **'Appointment booked successfully!'**
  String get appointmentBookedSuccess;

  /// No description provided for @appointmentRequests.
  ///
  /// In en, this message translates to:
  /// **'Appointment Requests'**
  String get appointmentRequests;

  /// No description provided for @noPendingAppointments.
  ///
  /// In en, this message translates to:
  /// **'No pending appointments.'**
  String get noPendingAppointments;

  /// No description provided for @patientId.
  ///
  /// In en, this message translates to:
  /// **'Patient ID'**
  String get patientId;

  /// No description provided for @alreadyLinkedByYou.
  ///
  /// In en, this message translates to:
  /// **'You have already linked this Elderly ID.'**
  String get alreadyLinkedByYou;

  /// No description provided for @liveQueue.
  ///
  /// In en, this message translates to:
  /// **'Live Queue'**
  String get liveQueue;

  /// No description provided for @nowServing.
  ///
  /// In en, this message translates to:
  /// **'Now Serving'**
  String get nowServing;

  /// No description provided for @upNext.
  ///
  /// In en, this message translates to:
  /// **'Up Next'**
  String get upNext;

  /// No description provided for @waiting.
  ///
  /// In en, this message translates to:
  /// **'Waiting'**
  String get waiting;

  /// No description provided for @estTime.
  ///
  /// In en, this message translates to:
  /// **'Est. Time'**
  String get estTime;

  /// No description provided for @callToken.
  ///
  /// In en, this message translates to:
  /// **'Call Token'**
  String get callToken;

  /// No description provided for @complete.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get complete;

  /// No description provided for @noActiveQueue.
  ///
  /// In en, this message translates to:
  /// **'No Active Queue'**
  String get noActiveQueue;

  /// No description provided for @noActiveQueueDesc.
  ///
  /// In en, this message translates to:
  /// **'Appointments for today will appear here.'**
  String get noActiveQueueDesc;

  /// No description provided for @allDone.
  ///
  /// In en, this message translates to:
  /// **'All Done!'**
  String get allDone;

  /// No description provided for @activeTokenRestriction.
  ///
  /// In en, this message translates to:
  /// **'You already have an active token. Please wait until it is completed or cancelled.'**
  String get activeTokenRestriction;

  /// No description provided for @status.
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get status;

  /// No description provided for @currentToken.
  ///
  /// In en, this message translates to:
  /// **'Current Token'**
  String get currentToken;

  /// No description provided for @nextToken.
  ///
  /// In en, this message translates to:
  /// **'Next Token'**
  String get nextToken;

  /// No description provided for @waitingForApproval.
  ///
  /// In en, this message translates to:
  /// **'Waiting for Approval'**
  String get waitingForApproval;

  /// No description provided for @appointmentApproved.
  ///
  /// In en, this message translates to:
  /// **'Appointment Approved'**
  String get appointmentApproved;

  /// No description provided for @queueNotActive.
  ///
  /// In en, this message translates to:
  /// **'Queue details will appear after approval.'**
  String get queueNotActive;

  /// No description provided for @yourToken.
  ///
  /// In en, this message translates to:
  /// **'Your Token'**
  String get yourToken;

  /// No description provided for @pending.
  ///
  /// In en, this message translates to:
  /// **'Pending'**
  String get pending;

  /// No description provided for @approved.
  ///
  /// In en, this message translates to:
  /// **'Approved'**
  String get approved;

  /// No description provided for @rejected.
  ///
  /// In en, this message translates to:
  /// **'Rejected'**
  String get rejected;

  /// No description provided for @served.
  ///
  /// In en, this message translates to:
  /// **'Served'**
  String get served;

  /// No description provided for @setToken.
  ///
  /// In en, this message translates to:
  /// **'Set Token (1-100)'**
  String get setToken;

  /// No description provided for @noAppointmentTaken.
  ///
  /// In en, this message translates to:
  /// **'No appointment taken'**
  String get noAppointmentTaken;

  /// No description provided for @requestSentPending.
  ///
  /// In en, this message translates to:
  /// **'Request sent – Pending approval'**
  String get requestSentPending;

  /// No description provided for @appointmentRejected.
  ///
  /// In en, this message translates to:
  /// **'Appointment rejected'**
  String get appointmentRejected;

  /// No description provided for @appointmentExpired.
  ///
  /// In en, this message translates to:
  /// **'Appointment expired'**
  String get appointmentExpired;

  /// No description provided for @token.
  ///
  /// In en, this message translates to:
  /// **'Token'**
  String get token;

  /// No description provided for @enableNotifications.
  ///
  /// In en, this message translates to:
  /// **'Enable Notifications'**
  String get enableNotifications;

  /// No description provided for @disableNotifications.
  ///
  /// In en, this message translates to:
  /// **'Disable Notifications'**
  String get disableNotifications;

  /// No description provided for @notificationsEnabled.
  ///
  /// In en, this message translates to:
  /// **'Notifications Enabled'**
  String get notificationsEnabled;

  /// No description provided for @notificationsDisabled.
  ///
  /// In en, this message translates to:
  /// **'Notifications Disabled'**
  String get notificationsDisabled;

  /// No description provided for @location.
  ///
  /// In en, this message translates to:
  /// **'Location'**
  String get location;

  /// No description provided for @locationNotAvailable.
  ///
  /// In en, this message translates to:
  /// **'Location Not Available'**
  String get locationNotAvailable;

  /// No description provided for @locationPermissionDenied.
  ///
  /// In en, this message translates to:
  /// **'Location Permission Denied'**
  String get locationPermissionDenied;

  /// No description provided for @emergencyAlertSent.
  ///
  /// In en, this message translates to:
  /// **'Emergency Alert Sent!'**
  String get emergencyAlertSent;

  /// No description provided for @emergencyFor.
  ///
  /// In en, this message translates to:
  /// **'Emergency for'**
  String get emergencyFor;

  /// No description provided for @activeAppointment.
  ///
  /// In en, this message translates to:
  /// **'Active Appointment'**
  String get activeAppointment;

  /// No description provided for @pleaseWaitForCompletion.
  ///
  /// In en, this message translates to:
  /// **'Please wait for this appointment to complete.'**
  String get pleaseWaitForCompletion;

  /// No description provided for @bookAppointment.
  ///
  /// In en, this message translates to:
  /// **'Book Appointment'**
  String get bookAppointment;

  /// No description provided for @emergencyConfirmation.
  ///
  /// In en, this message translates to:
  /// **'Emergency Confirmation'**
  String get emergencyConfirmation;

  /// No description provided for @confirmEmergency.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to raise an emergency alert?'**
  String get confirmEmergency;

  /// No description provided for @emergencyDisclaimer.
  ///
  /// In en, this message translates to:
  /// **'Once confirmed, your emergency call will be forwarded to the hospital and staff portal immediately.'**
  String get emergencyDisclaimer;

  /// No description provided for @confirmEmergencyFor.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to raise an emergency alert for {name}?'**
  String confirmEmergencyFor(Object name);

  /// No description provided for @emergencyForPatient.
  ///
  /// In en, this message translates to:
  /// **'Emergency for Patient'**
  String get emergencyForPatient;

  /// No description provided for @emergencyAlertSentFor.
  ///
  /// In en, this message translates to:
  /// **'Emergency Alert Sent for {name}!'**
  String emergencyAlertSentFor(Object name);

  /// No description provided for @emergencyAlertTitle.
  ///
  /// In en, this message translates to:
  /// **'EMERGENCY ALERT'**
  String get emergencyAlertTitle;

  /// No description provided for @patientLabel.
  ///
  /// In en, this message translates to:
  /// **'Patient'**
  String get patientLabel;

  /// No description provided for @unitIdLabel.
  ///
  /// In en, this message translates to:
  /// **'Unit ID'**
  String get unitIdLabel;

  /// No description provided for @timeLabel.
  ///
  /// In en, this message translates to:
  /// **'Time'**
  String get timeLabel;

  /// No description provided for @locationLabel.
  ///
  /// In en, this message translates to:
  /// **'Location'**
  String get locationLabel;

  /// No description provided for @accept.
  ///
  /// In en, this message translates to:
  /// **'ACCEPT'**
  String get accept;

  /// No description provided for @rejectAction.
  ///
  /// In en, this message translates to:
  /// **'REJECT'**
  String get rejectAction;

  /// No description provided for @emergencyCount.
  ///
  /// In en, this message translates to:
  /// **'Alert {current} of {total}'**
  String emergencyCount(Object current, Object total);

  /// No description provided for @okAction.
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get okAction;

  /// No description provided for @notificationSettings.
  ///
  /// In en, this message translates to:
  /// **'Notification Settings'**
  String get notificationSettings;

  /// No description provided for @enableNotificationsDesc.
  ///
  /// In en, this message translates to:
  /// **'Turn on/off all notifications'**
  String get enableNotificationsDesc;

  /// No description provided for @alertPreferences.
  ///
  /// In en, this message translates to:
  /// **'Alert Preferences'**
  String get alertPreferences;

  /// No description provided for @sound.
  ///
  /// In en, this message translates to:
  /// **'Sound'**
  String get sound;

  /// No description provided for @vibration.
  ///
  /// In en, this message translates to:
  /// **'Vibration'**
  String get vibration;

  /// No description provided for @tokenQueueAlerts.
  ///
  /// In en, this message translates to:
  /// **'Token Queue Alerts'**
  String get tokenQueueAlerts;

  /// No description provided for @tokenAlertThresholdDesc.
  ///
  /// In en, this message translates to:
  /// **'Notify me when my turn is within:'**
  String get tokenAlertThresholdDesc;

  /// No description provided for @tokens.
  ///
  /// In en, this message translates to:
  /// **'tokens'**
  String get tokens;

  /// No description provided for @smartReminders.
  ///
  /// In en, this message translates to:
  /// **'Smart Reminders'**
  String get smartReminders;

  /// No description provided for @appointmentReminders.
  ///
  /// In en, this message translates to:
  /// **'Appointment Reminders'**
  String get appointmentReminders;

  /// No description provided for @appointmentRemindersDesc.
  ///
  /// In en, this message translates to:
  /// **'Get notified before scheduled appointments'**
  String get appointmentRemindersDesc;

  /// No description provided for @medicineReminders.
  ///
  /// In en, this message translates to:
  /// **'Medicine Reminders'**
  String get medicineReminders;

  /// No description provided for @medicineRemindersDesc.
  ///
  /// In en, this message translates to:
  /// **'Reminders to take your daily medication'**
  String get medicineRemindersDesc;

  /// No description provided for @notificationsDisabledMsg.
  ///
  /// In en, this message translates to:
  /// **'Notifications are currently disabled.\nEnable them to configure preferences.'**
  String get notificationsDisabledMsg;

  /// No description provided for @sosSentWaiting.
  ///
  /// In en, this message translates to:
  /// **'Request sent, awaiting staff approval.'**
  String get sosSentWaiting;

  /// No description provided for @helpOnTheWay.
  ///
  /// In en, this message translates to:
  /// **'Approved, help or vehicle is on the way'**
  String get helpOnTheWay;

  /// No description provided for @emergencyResolved.
  ///
  /// In en, this message translates to:
  /// **'Emergency Resolved.'**
  String get emergencyResolved;

  /// No description provided for @emergencyClosed.
  ///
  /// In en, this message translates to:
  /// **'Emergency Request Closed.'**
  String get emergencyClosed;

  /// No description provided for @helpAccepted.
  ///
  /// In en, this message translates to:
  /// **'Approved, help or vehicle is on the way'**
  String get helpAccepted;

  /// No description provided for @msgClearTimer.
  ///
  /// In en, this message translates to:
  /// **'Message will clear in {minutes} mins.'**
  String msgClearTimer(Object minutes);

  /// No description provided for @silenceAlarm.
  ///
  /// In en, this message translates to:
  /// **'SILENCE ALARM'**
  String get silenceAlarm;

  /// No description provided for @view.
  ///
  /// In en, this message translates to:
  /// **'VIEW'**
  String get view;

  /// No description provided for @activeEmergencies.
  ///
  /// In en, this message translates to:
  /// **'{count} Emergency Request(s) Active!'**
  String activeEmergencies(Object count);

  /// No description provided for @stopSound.
  ///
  /// In en, this message translates to:
  /// **'STOP SOUND'**
  String get stopSound;

  /// No description provided for @upNextAlert.
  ///
  /// In en, this message translates to:
  /// **'You are next'**
  String get upNextAlert;

  /// No description provided for @patientName.
  ///
  /// In en, this message translates to:
  /// **'Patient Name'**
  String get patientName;

  /// No description provided for @code.
  ///
  /// In en, this message translates to:
  /// **'Code'**
  String get code;

  /// No description provided for @waitingForGps.
  ///
  /// In en, this message translates to:
  /// **'Waiting for GPS...'**
  String get waitingForGps;

  /// No description provided for @locationTimeout.
  ///
  /// In en, this message translates to:
  /// **'Location timed out'**
  String get locationTimeout;

  /// No description provided for @addressNotFound.
  ///
  /// In en, this message translates to:
  /// **'Address not found'**
  String get addressNotFound;

  /// No description provided for @openMaps.
  ///
  /// In en, this message translates to:
  /// **'Open in Maps'**
  String get openMaps;

  /// No description provided for @acceptSos.
  ///
  /// In en, this message translates to:
  /// **'ACCEPT SOS'**
  String get acceptSos;

  /// No description provided for @triggeredBy.
  ///
  /// In en, this message translates to:
  /// **'Triggered By'**
  String get triggeredBy;

  /// No description provided for @loading.
  ///
  /// In en, this message translates to:
  /// **'Loading...'**
  String get loading;

  /// No description provided for @unableToFetchLocation.
  ///
  /// In en, this message translates to:
  /// **'Unable to fetch location details'**
  String get unableToFetchLocation;

  /// No description provided for @reasonDoctorUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Doctor unavailable'**
  String get reasonDoctorUnavailable;

  /// No description provided for @reasonSlotFull.
  ///
  /// In en, this message translates to:
  /// **'Slot full'**
  String get reasonSlotFull;

  /// No description provided for @reasonIncompleteDetails.
  ///
  /// In en, this message translates to:
  /// **'Incomplete details'**
  String get reasonIncompleteDetails;

  /// No description provided for @reasonReschedule.
  ///
  /// In en, this message translates to:
  /// **'Reschedule required'**
  String get reasonReschedule;

  /// No description provided for @reasonEmergencyPriority.
  ///
  /// In en, this message translates to:
  /// **'Emergency case priority'**
  String get reasonEmergencyPriority;

  /// No description provided for @reasonOther.
  ///
  /// In en, this message translates to:
  /// **'Other (Type below)'**
  String get reasonOther;

  /// No description provided for @reasonLabel.
  ///
  /// In en, this message translates to:
  /// **'Reason:'**
  String get reasonLabel;

  /// No description provided for @rejectionReasonHint.
  ///
  /// In en, this message translates to:
  /// **'Enter specific reason...'**
  String get rejectionReasonHint;

  /// No description provided for @rejectAppointmentTitle.
  ///
  /// In en, this message translates to:
  /// **'Reject Appointment'**
  String get rejectAppointmentTitle;

  /// No description provided for @pleaseReschedule.
  ///
  /// In en, this message translates to:
  /// **'Please reschedule.'**
  String get pleaseReschedule;
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
      <String>['en', 'ml'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'ml':
      return AppLocalizationsMl();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
