// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get settings => 'Settings';

  @override
  String get language => 'Language';

  @override
  String get selectLanguage => 'Select Language';

  @override
  String get notifications => 'Notifications';

  @override
  String get logout => 'Logout';

  @override
  String get login => 'Login';

  @override
  String get appTitle => 'CareNow';

  @override
  String get welcomeBack => 'Welcome Back';

  @override
  String get email => 'Email';

  @override
  String get password => 'Password';

  @override
  String get myCare => 'My Care';

  @override
  String get resetPassword => 'Reset Password';

  @override
  String get checkEmail => 'Check your email';

  @override
  String get sentRecoveryInstructions =>
      'We have sent password recovery instructions to your email.';

  @override
  String get backToLogin => 'Back to Login';

  @override
  String get enterEmailForReset =>
      'Enter your email address and we will send you a link to reset your password.';

  @override
  String get emailAddress => 'Email Address';

  @override
  String get sendResetLink => 'Send Reset Link';

  @override
  String get createAccount => 'Create Account';

  @override
  String get elderly => 'Elderly';

  @override
  String get caregiver => 'Caregiver';

  @override
  String get staff => 'Staff';

  @override
  String get completeRegistration => 'Complete Registration';

  @override
  String get fullName => 'Full Name';

  @override
  String get simplifiedRegistration =>
      'Simplified Registration for Easy Access';

  @override
  String get dobOptional => 'Date of Birth (Optional)';

  @override
  String get linkToElderly => 'Link your account to an Elderly user';

  @override
  String get elderlyLinkId => 'Elderly Link ID / Code';

  @override
  String get relationship => 'Relationship';

  @override
  String get adminApprovalRequired => 'Registration requires Admin Approval.';

  @override
  String get staffId => 'Staff ID / Badge Number';

  @override
  String get department => 'Department';

  @override
  String get welcomeToCareNow => 'Welcome to\nCareNow';

  @override
  String get selectLanguagePrompt =>
      'Please select your preferred language to continue.';

  @override
  String get medication => 'Medication';

  @override
  String get appointments => 'Appointments';

  @override
  String get emergency => 'Emergency';

  @override
  String get profile => 'Profile';

  @override
  String get dashboardFor => 'Dashboard for';

  @override
  String get nextDose => 'Next Dose';

  @override
  String get vitals => 'Vitals';

  @override
  String get staffPortal => 'Staff Portal';

  @override
  String get searchPatientRecords => 'Search Patient Records...';

  @override
  String get forgotPasswordQuestion => 'Forgot Password?';

  @override
  String get createAccountQuestion => 'New here? Create an Account';

  @override
  String get username => 'Username';

  @override
  String get usernameError => 'Please enter username';

  @override
  String get userNotRegistered => 'User not registered';

  @override
  String get incorrectPassword => 'Incorrect password';

  @override
  String get emailAvailable => 'Email already available';

  @override
  String get registrationFailed => 'Registration failed';

  @override
  String get unexpectedError => 'An unexpected error occurred';

  @override
  String get uniqueId => 'My Unique ID';

  @override
  String get elderlyMode => 'Elderly Mode (Large Text)';

  @override
  String get elderlyModeDesc => 'Increases text size';

  @override
  String get changePassword => 'Change Password';

  @override
  String get currentPassword => 'Current Password';

  @override
  String get newPassword => 'New Password';

  @override
  String get update => 'Update';

  @override
  String get cancel => 'Cancel';

  @override
  String get passwordChanged => 'Password changed successfully';

  @override
  String get manageLinkedElderly => 'Manage Linked Elderly';

  @override
  String linkedMsg(Object count) {
    return '$count / 5 linked';
  }

  @override
  String get noElderlyLinked => 'No elderly linked yet.';

  @override
  String get addElderlyId => 'Add Elderly ID (e.g. ELD-1234)';

  @override
  String get add => 'Add';

  @override
  String get close => 'Close';

  @override
  String get limitReached => 'Limit of 5 reached';

  @override
  String get mandatory => '*';

  @override
  String get accountDisabled =>
      'Your account has been disabled. Contact Admin.';

  @override
  String get staffIdOnly => 'Staff ID';

  @override
  String get condition => 'Condition';

  @override
  String get medicines => 'Medicines';

  @override
  String get profileNotFound => 'Profile not found';

  @override
  String get searchByUniqueId => 'Search by Unique ID';

  @override
  String get dateOfBirth => 'Date of Birth';

  @override
  String get passwordHelper =>
      'Must contain at least 1 special char & 1 number';

  @override
  String get caregiverFamily => 'Caregiver/Family Member';

  @override
  String get volunteer => 'Volunteer';

  @override
  String get ageEligibilityError =>
      'You are not eligible to register as an elderly user';

  @override
  String get medicineTiming => 'Medicine Timing';

  @override
  String get volunteerHub => 'Volunteer Hub';

  @override
  String get welcomeVolunteer => 'Welcome, Volunteer!';

  @override
  String get thankYouVolunteer => 'Thank you for joining our community.';

  @override
  String get viewAvailableTasks => 'View Available Tasks';

  @override
  String get noConditions => 'No conditions recorded';

  @override
  String get noMedicines => 'No medicines recorded';

  @override
  String get noTiming => 'No timing recorded';

  @override
  String get confirmPassword => 'Confirm Password';

  @override
  String get passwordsDoNotMatch => 'Passwords do not match';

  @override
  String get selectRole => 'Select Role';

  @override
  String get requestHospitalAccess => 'Request Hospital Access';

  @override
  String get accessRequested => 'Access Requested';

  @override
  String get accessPending => 'Access Pending';

  @override
  String get accessApproved => 'Access Approved';

  @override
  String get accessRejected => 'Access Rejected';

  @override
  String get approve => 'Approve';

  @override
  String get reject => 'Reject';

  @override
  String get patientRequests => 'Patient Requests';

  @override
  String get approvedPatients => 'Approved Patients';

  @override
  String get myDetails => 'My Details';

  @override
  String get familyMember => 'Family Member';

  @override
  String get volunteerRegistrationSuccess =>
      'Volunteer registration submitted successfully';

  @override
  String get volunteerAlert => 'Please review the volunteer guidelines';

  @override
  String get request => 'Request';

  @override
  String get joinVolunteer => 'Join as a Volunteer to help the community';

  @override
  String get sendRequest => 'Send Request';

  @override
  String get hospitalAccess => 'Hospital Access';

  @override
  String get noId => 'No ID';

  @override
  String get unknown => 'Unknown';

  @override
  String get notAvailable => 'N/A';

  @override
  String get userDoesNotExist => 'User does not exist';

  @override
  String get accountAlreadyLinked =>
      'Elderly Unit ID is already linked to another caregiver and cannot be reused, as one elderly can be connected to only one caregiver.';

  @override
  String get selectDoctor => 'Select Doctor';

  @override
  String get confirmAppointment => 'Confirm Appointment';

  @override
  String get doctor => 'Doctor';

  @override
  String get date => 'Date';

  @override
  String get confirm => 'Confirm';

  @override
  String get appointmentBookedSuccess => 'Appointment booked successfully!';

  @override
  String get appointmentRequests => 'Appointment Requests';

  @override
  String get noPendingAppointments => 'No pending appointments.';

  @override
  String get patientId => 'Patient ID';

  @override
  String get alreadyLinkedByYou => 'You have already linked this Elderly ID.';

  @override
  String get liveQueue => 'Live Queue';

  @override
  String get nowServing => 'Now Serving';

  @override
  String get upNext => 'Up Next';

  @override
  String get waiting => 'Waiting';

  @override
  String get estTime => 'Est. Time';

  @override
  String get callToken => 'Call Token';

  @override
  String get complete => 'Completed';

  @override
  String get noActiveQueue => 'No Active Queue';

  @override
  String get noActiveQueueDesc => 'Appointments for today will appear here.';

  @override
  String get allDone => 'All Done!';

  @override
  String get activeTokenRestriction =>
      'You already have an active token. Please wait until it is completed or cancelled.';

  @override
  String get status => 'Status';

  @override
  String get currentToken => 'Current Token';

  @override
  String get nextToken => 'Next Token';

  @override
  String get waitingForApproval => 'Waiting for Approval';

  @override
  String get appointmentApproved => 'Appointment Approved';

  @override
  String get queueNotActive => 'Queue details will appear after approval.';

  @override
  String get yourToken => 'Your Token';

  @override
  String get pending => 'Pending';

  @override
  String get approved => 'Approved';

  @override
  String get rejected => 'Rejected';

  @override
  String get served => 'Served';

  @override
  String get setToken => 'Set Token (1-100)';

  @override
  String get noAppointmentTaken => 'No appointment taken';

  @override
  String get requestSentPending => 'Request sent – Pending approval';

  @override
  String get appointmentRejected => 'Appointment rejected';

  @override
  String get appointmentExpired => 'Appointment expired';

  @override
  String get token => 'Token';

  @override
  String get enableNotifications => 'Enable Notifications';

  @override
  String get disableNotifications => 'Disable Notifications';

  @override
  String get notificationsEnabled => 'Notifications Enabled';

  @override
  String get notificationsDisabled => 'Notifications Disabled';

  @override
  String get location => 'Location';

  @override
  String get locationNotAvailable => 'Location Not Available';

  @override
  String get locationPermissionDenied => 'Location Permission Denied';

  @override
  String get emergencyAlertSent => 'Emergency Alert Sent!';

  @override
  String get emergencyFor => 'Emergency for';

  @override
  String get activeAppointment => 'Active Appointment';

  @override
  String get pleaseWaitForCompletion =>
      'Please wait for this appointment to complete.';

  @override
  String get bookAppointment => 'Book Appointment';

  @override
  String get emergencyConfirmation => 'Emergency Confirmation';

  @override
  String get confirmEmergency =>
      'Are you sure you want to raise an emergency alert?';

  @override
  String get emergencyDisclaimer =>
      'Once confirmed, your emergency call will be forwarded to the hospital and staff portal immediately.';

  @override
  String confirmEmergencyFor(Object name) {
    return 'Are you sure you want to raise an emergency alert for $name?';
  }

  @override
  String get emergencyForPatient => 'Emergency for Patient';

  @override
  String emergencyAlertSentFor(Object name) {
    return 'Emergency Alert Sent for $name!';
  }

  @override
  String get emergencyAlertTitle => 'EMERGENCY ALERT';

  @override
  String get patientLabel => 'Patient';

  @override
  String get unitIdLabel => 'Unit ID';

  @override
  String get timeLabel => 'Time';

  @override
  String get locationLabel => 'Location';

  @override
  String get accept => 'ACCEPT';

  @override
  String get rejectAction => 'REJECT';

  @override
  String emergencyCount(Object current, Object total) {
    return 'Alert $current of $total';
  }

  @override
  String get okAction => 'OK';

  @override
  String get notificationSettings => 'Notification Settings';

  @override
  String get enableNotificationsDesc => 'Turn on/off all notifications';

  @override
  String get alertPreferences => 'Alert Preferences';

  @override
  String get sound => 'Sound';

  @override
  String get vibration => 'Vibration';

  @override
  String get tokenQueueAlerts => 'Token Queue Alerts';

  @override
  String get tokenAlertThresholdDesc => 'Notify me when my turn is within:';

  @override
  String get tokens => 'tokens';

  @override
  String get smartReminders => 'Smart Reminders';

  @override
  String get appointmentReminders => 'Appointment Reminders';

  @override
  String get appointmentRemindersDesc =>
      'Get notified before scheduled appointments';

  @override
  String get medicineReminders => 'Medicine Reminders';

  @override
  String get medicineRemindersDesc => 'Reminders to take your daily medication';

  @override
  String get notificationsDisabledMsg =>
      'Notifications are currently disabled.\nEnable them to configure preferences.';

  @override
  String get sosSentWaiting => 'Request sent, awaiting staff approval.';

  @override
  String get helpOnTheWay => 'Approved, help or vehicle is on the way';

  @override
  String get emergencyResolved => 'Emergency Resolved.';

  @override
  String get emergencyClosed => 'Emergency Request Closed.';

  @override
  String get helpAccepted => 'Approved, help or vehicle is on the way';

  @override
  String msgClearTimer(Object minutes) {
    return 'Message will clear in $minutes mins.';
  }

  @override
  String get silenceAlarm => 'SILENCE ALARM';

  @override
  String get view => 'VIEW';

  @override
  String activeEmergencies(Object count) {
    return '$count Emergency Request(s) Active!';
  }

  @override
  String get stopSound => 'STOP SOUND';

  @override
  String get upNextAlert => 'You are next';

  @override
  String get patientName => 'Patient Name';

  @override
  String get code => 'Code';

  @override
  String get waitingForGps => 'Waiting for GPS...';

  @override
  String get locationTimeout => 'Location timed out';

  @override
  String get addressNotFound => 'Address not found';

  @override
  String get openMaps => 'Open in Maps';

  @override
  String get acceptSos => 'ACCEPT SOS';

  @override
  String get triggeredBy => 'Triggered By';

  @override
  String get loading => 'Loading...';

  @override
  String get unableToFetchLocation => 'Unable to fetch location details';

  @override
  String get reasonDoctorUnavailable => 'Doctor unavailable';

  @override
  String get reasonSlotFull => 'Slot full';

  @override
  String get reasonIncompleteDetails => 'Incomplete details';

  @override
  String get reasonReschedule => 'Reschedule required';

  @override
  String get reasonEmergencyPriority => 'Emergency case priority';

  @override
  String get reasonOther => 'Other (Type below)';

  @override
  String get reasonLabel => 'Reason:';

  @override
  String get rejectionReasonHint => 'Enter specific reason...';

  @override
  String get rejectAppointmentTitle => 'Reject Appointment';

  @override
  String get pleaseReschedule => 'Please reschedule.';
}
