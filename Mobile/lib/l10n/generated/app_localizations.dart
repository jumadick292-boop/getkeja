import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_sw.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/app_localizations.dart';
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
    Locale('sw'),
  ];

  /// No description provided for @account.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get account;

  /// No description provided for @personalInformation.
  ///
  /// In en, this message translates to:
  /// **'Personal information'**
  String get personalInformation;

  /// No description provided for @passwordAndLogin.
  ///
  /// In en, this message translates to:
  /// **'Password & login'**
  String get passwordAndLogin;

  /// No description provided for @twoFactorAuthentication.
  ///
  /// In en, this message translates to:
  /// **'Two-factor authentication'**
  String get twoFactorAuthentication;

  /// No description provided for @connectedAccounts.
  ///
  /// In en, this message translates to:
  /// **'Connected accounts'**
  String get connectedAccounts;

  /// No description provided for @activeSessions.
  ///
  /// In en, this message translates to:
  /// **'Active sessions'**
  String get activeSessions;

  /// No description provided for @trustedDevices.
  ///
  /// In en, this message translates to:
  /// **'Trusted devices'**
  String get trustedDevices;

  /// No description provided for @securityActivity.
  ///
  /// In en, this message translates to:
  /// **'Security activity'**
  String get securityActivity;

  /// No description provided for @preferencesAndNotifications.
  ///
  /// In en, this message translates to:
  /// **'Preferences & notifications'**
  String get preferencesAndNotifications;

  /// No description provided for @privacyAndData.
  ///
  /// In en, this message translates to:
  /// **'Privacy & data'**
  String get privacyAndData;

  /// No description provided for @accountStatus.
  ///
  /// In en, this message translates to:
  /// **'Account status'**
  String get accountStatus;

  /// No description provided for @organizationAndAccess.
  ///
  /// In en, this message translates to:
  /// **'Organization & access'**
  String get organizationAndAccess;

  /// No description provided for @languageAndRegion.
  ///
  /// In en, this message translates to:
  /// **'Language & region'**
  String get languageAndRegion;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @english.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get english;

  /// No description provided for @kiswahili.
  ///
  /// In en, this message translates to:
  /// **'Kiswahili'**
  String get kiswahili;

  /// No description provided for @categoryWifiInstallation.
  ///
  /// In en, this message translates to:
  /// **'Wi-Fi Installation & Configuration'**
  String get categoryWifiInstallation;

  /// No description provided for @categoryInternetInstallation.
  ///
  /// In en, this message translates to:
  /// **'Internet Installation & Connectivity'**
  String get categoryInternetInstallation;

  /// No description provided for @categorySolarInstallation.
  ///
  /// In en, this message translates to:
  /// **'Solar Installation & Maintenance'**
  String get categorySolarInstallation;

  /// No description provided for @categoryPaintingDecoration.
  ///
  /// In en, this message translates to:
  /// **'Painting & Decoration'**
  String get categoryPaintingDecoration;

  /// No description provided for @movingJobs.
  ///
  /// In en, this message translates to:
  /// **'Moving jobs'**
  String get movingJobs;

  /// No description provided for @providerMovingJobs.
  ///
  /// In en, this message translates to:
  /// **'Assigned moving jobs'**
  String get providerMovingJobs;

  /// No description provided for @movingJobDetails.
  ///
  /// In en, this message translates to:
  /// **'Moving job details'**
  String get movingJobDetails;

  /// No description provided for @movingStatus.
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get movingStatus;

  /// No description provided for @movingOrigin.
  ///
  /// In en, this message translates to:
  /// **'Origin'**
  String get movingOrigin;

  /// No description provided for @movingDestination.
  ///
  /// In en, this message translates to:
  /// **'Destination'**
  String get movingDestination;

  /// No description provided for @movingSchedule.
  ///
  /// In en, this message translates to:
  /// **'Schedule'**
  String get movingSchedule;

  /// No description provided for @movingChecklist.
  ///
  /// In en, this message translates to:
  /// **'Preparation checklist'**
  String get movingChecklist;

  /// No description provided for @movingProgress.
  ///
  /// In en, this message translates to:
  /// **'Progress'**
  String get movingProgress;

  /// No description provided for @movingAcceptedQuotation.
  ///
  /// In en, this message translates to:
  /// **'Accepted quotation'**
  String get movingAcceptedQuotation;

  /// No description provided for @movingAssessments.
  ///
  /// In en, this message translates to:
  /// **'Assessments'**
  String get movingAssessments;

  /// No description provided for @movingAmendments.
  ///
  /// In en, this message translates to:
  /// **'Amendments'**
  String get movingAmendments;

  /// No description provided for @movingConfirmCompletion.
  ///
  /// In en, this message translates to:
  /// **'Confirm completion'**
  String get movingConfirmCompletion;

  /// No description provided for @movingReportIncomplete.
  ///
  /// In en, this message translates to:
  /// **'Report incomplete work'**
  String get movingReportIncomplete;

  /// No description provided for @movingCancelJob.
  ///
  /// In en, this message translates to:
  /// **'Cancel job'**
  String get movingCancelJob;

  /// No description provided for @movingNoJobs.
  ///
  /// In en, this message translates to:
  /// **'No moving jobs yet'**
  String get movingNoJobs;

  /// No description provided for @movingRetry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get movingRetry;

  /// No description provided for @garbageJobs.
  ///
  /// In en, this message translates to:
  /// **'Garbage collections'**
  String get garbageJobs;

  /// No description provided for @providerGarbageJobs.
  ///
  /// In en, this message translates to:
  /// **'Assigned collections'**
  String get providerGarbageJobs;

  /// No description provided for @garbageJobDetails.
  ///
  /// In en, this message translates to:
  /// **'Collection details'**
  String get garbageJobDetails;

  /// No description provided for @garbageSchedule.
  ///
  /// In en, this message translates to:
  /// **'Schedule'**
  String get garbageSchedule;

  /// No description provided for @garbageChecklist.
  ///
  /// In en, this message translates to:
  /// **'Collection checklist'**
  String get garbageChecklist;

  /// No description provided for @garbageAgreements.
  ///
  /// In en, this message translates to:
  /// **'Recurring plans'**
  String get garbageAgreements;

  /// No description provided for @providerGarbageAgreements.
  ///
  /// In en, this message translates to:
  /// **'Recurring agreements'**
  String get providerGarbageAgreements;

  /// No description provided for @garbageConfirmCompletion.
  ///
  /// In en, this message translates to:
  /// **'Confirm collection'**
  String get garbageConfirmCompletion;

  /// No description provided for @garbageReportIssue.
  ///
  /// In en, this message translates to:
  /// **'Report an issue'**
  String get garbageReportIssue;

  /// No description provided for @garbageCancelJob.
  ///
  /// In en, this message translates to:
  /// **'Cancel collection'**
  String get garbageCancelJob;

  /// No description provided for @garbageNoJobs.
  ///
  /// In en, this message translates to:
  /// **'No collections yet'**
  String get garbageNoJobs;

  /// No description provided for @garbageNoAgreements.
  ///
  /// In en, this message translates to:
  /// **'No recurring plans yet'**
  String get garbageNoAgreements;

  /// No description provided for @garbageRetry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get garbageRetry;

  /// No description provided for @garbageAccept.
  ///
  /// In en, this message translates to:
  /// **'Accept'**
  String get garbageAccept;

  /// No description provided for @garbageDecline.
  ///
  /// In en, this message translates to:
  /// **'Decline'**
  String get garbageDecline;

  /// No description provided for @garbageStatus.
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get garbageStatus;

  /// No description provided for @laundryOrders.
  ///
  /// In en, this message translates to:
  /// **'Laundry orders'**
  String get laundryOrders;

  /// No description provided for @providerLaundryOrders.
  ///
  /// In en, this message translates to:
  /// **'Assigned laundry orders'**
  String get providerLaundryOrders;

  /// No description provided for @laundryOrderDetails.
  ///
  /// In en, this message translates to:
  /// **'Laundry order details'**
  String get laundryOrderDetails;

  /// No description provided for @laundryNoOrders.
  ///
  /// In en, this message translates to:
  /// **'No laundry orders yet'**
  String get laundryNoOrders;

  /// No description provided for @laundryRetry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get laundryRetry;

  /// No description provided for @laundryStatus.
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get laundryStatus;

  /// No description provided for @laundrySchedule.
  ///
  /// In en, this message translates to:
  /// **'Schedule'**
  String get laundrySchedule;

  /// No description provided for @laundryItems.
  ///
  /// In en, this message translates to:
  /// **'Items'**
  String get laundryItems;

  /// No description provided for @laundryConfirmDelivery.
  ///
  /// In en, this message translates to:
  /// **'Confirm delivery'**
  String get laundryConfirmDelivery;

  /// No description provided for @schedulingCalendar.
  ///
  /// In en, this message translates to:
  /// **'Operational calendar'**
  String get schedulingCalendar;

  /// No description provided for @schedulingAppointments.
  ///
  /// In en, this message translates to:
  /// **'My appointments'**
  String get schedulingAppointments;

  /// No description provided for @schedulingDay.
  ///
  /// In en, this message translates to:
  /// **'Day'**
  String get schedulingDay;

  /// No description provided for @schedulingWeek.
  ///
  /// In en, this message translates to:
  /// **'Week'**
  String get schedulingWeek;

  /// No description provided for @schedulingMonth.
  ///
  /// In en, this message translates to:
  /// **'Month'**
  String get schedulingMonth;

  /// No description provided for @schedulingRetry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get schedulingRetry;

  /// No description provided for @schedulingNoActivities.
  ///
  /// In en, this message translates to:
  /// **'No scheduled activities'**
  String get schedulingNoActivities;

  /// No description provided for @schedulingNoAppointments.
  ///
  /// In en, this message translates to:
  /// **'No appointments yet'**
  String get schedulingNoAppointments;

  /// No description provided for @domainMoving.
  ///
  /// In en, this message translates to:
  /// **'Moving'**
  String get domainMoving;

  /// No description provided for @domainGarbage.
  ///
  /// In en, this message translates to:
  /// **'Garbage'**
  String get domainGarbage;

  /// No description provided for @domainLaundry.
  ///
  /// In en, this message translates to:
  /// **'Laundry'**
  String get domainLaundry;

  /// No description provided for @timezone.
  ///
  /// In en, this message translates to:
  /// **'Timezone'**
  String get timezone;

  /// No description provided for @dateFormat.
  ///
  /// In en, this message translates to:
  /// **'Date format'**
  String get dateFormat;

  /// No description provided for @numberFormat.
  ///
  /// In en, this message translates to:
  /// **'Number format'**
  String get numberFormat;

  /// No description provided for @appearance.
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get appearance;

  /// No description provided for @theme.
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get theme;

  /// No description provided for @systemDefault.
  ///
  /// In en, this message translates to:
  /// **'System default'**
  String get systemDefault;

  /// No description provided for @light.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get light;

  /// No description provided for @dark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get dark;

  /// No description provided for @currency.
  ///
  /// In en, this message translates to:
  /// **'Currency'**
  String get currency;

  /// No description provided for @defaultCurrency.
  ///
  /// In en, this message translates to:
  /// **'Default currency'**
  String get defaultCurrency;

  /// No description provided for @notificationChannels.
  ///
  /// In en, this message translates to:
  /// **'Channels'**
  String get notificationChannels;

  /// No description provided for @pushNotifications.
  ///
  /// In en, this message translates to:
  /// **'Push notifications'**
  String get pushNotifications;

  /// No description provided for @pushNotificationsDescription.
  ///
  /// In en, this message translates to:
  /// **'Receive push notifications on this device'**
  String get pushNotificationsDescription;

  /// No description provided for @emailNotifications.
  ///
  /// In en, this message translates to:
  /// **'Email notifications'**
  String get emailNotifications;

  /// No description provided for @emailNotificationsDescription.
  ///
  /// In en, this message translates to:
  /// **'Receive important updates via email'**
  String get emailNotificationsDescription;

  /// No description provided for @smsNotifications.
  ///
  /// In en, this message translates to:
  /// **'SMS notifications'**
  String get smsNotifications;

  /// No description provided for @smsNotificationsDescription.
  ///
  /// In en, this message translates to:
  /// **'Receive critical alerts via SMS'**
  String get smsNotificationsDescription;

  /// No description provided for @savePreferences.
  ///
  /// In en, this message translates to:
  /// **'Save preferences'**
  String get savePreferences;

  /// No description provided for @preferencesSaved.
  ///
  /// In en, this message translates to:
  /// **'Preferences saved successfully'**
  String get preferencesSaved;

  /// No description provided for @regionalFormats.
  ///
  /// In en, this message translates to:
  /// **'Regional formats'**
  String get regionalFormats;

  /// No description provided for @accountSettings.
  ///
  /// In en, this message translates to:
  /// **'Account settings'**
  String get accountSettings;

  /// No description provided for @emailPhone.
  ///
  /// In en, this message translates to:
  /// **'Email or phone'**
  String get emailPhone;

  /// No description provided for @changePasswordManageLogin.
  ///
  /// In en, this message translates to:
  /// **'Change password, manage login methods'**
  String get changePasswordManageLogin;

  /// No description provided for @authenticatorSmsBackup.
  ///
  /// In en, this message translates to:
  /// **'Authenticator app, SMS, backup codes'**
  String get authenticatorSmsBackup;

  /// No description provided for @googleAccountLinking.
  ///
  /// In en, this message translates to:
  /// **'Google account linking'**
  String get googleAccountLinking;

  /// No description provided for @whereSignedIn.
  ///
  /// In en, this message translates to:
  /// **'Where you’re signed in'**
  String get whereSignedIn;

  /// No description provided for @manageRegisteredDevices.
  ///
  /// In en, this message translates to:
  /// **'Manage your registered devices'**
  String get manageRegisteredDevices;

  /// No description provided for @recentSignInsSecurityEvents.
  ///
  /// In en, this message translates to:
  /// **'Recent sign-ins and security events'**
  String get recentSignInsSecurityEvents;

  /// No description provided for @dataExportAccountDeletion.
  ///
  /// In en, this message translates to:
  /// **'Data export, account deletion'**
  String get dataExportAccountDeletion;

  /// No description provided for @verificationRestrictions.
  ///
  /// In en, this message translates to:
  /// **'Verification status, restrictions'**
  String get verificationRestrictions;

  /// No description provided for @organizationMemberships.
  ///
  /// In en, this message translates to:
  /// **'Your organization memberships'**
  String get organizationMemberships;

  /// No description provided for @systemEmail.
  ///
  /// In en, this message translates to:
  /// **'System email'**
  String get systemEmail;

  /// No description provided for @kenyaEnglish.
  ///
  /// In en, this message translates to:
  /// **'English (Kenya) - 1,234.56'**
  String get kenyaEnglish;

  /// No description provided for @ukEnglish.
  ///
  /// In en, this message translates to:
  /// **'English (UK) - 1,234.56'**
  String get ukEnglish;

  /// No description provided for @kenyaSwahili.
  ///
  /// In en, this message translates to:
  /// **'Kiswahili (Kenya) - 1,234.56'**
  String get kenyaSwahili;

  /// No description provided for @dateDayFirst.
  ///
  /// In en, this message translates to:
  /// **'DD/MM/YYYY (31/12/2024)'**
  String get dateDayFirst;

  /// No description provided for @dateMonthFirst.
  ///
  /// In en, this message translates to:
  /// **'MM/DD/YYYY (12/31/2024)'**
  String get dateMonthFirst;

  /// No description provided for @dateIso.
  ///
  /// In en, this message translates to:
  /// **'YYYY-MM-DD (2024-12-31)'**
  String get dateIso;

  /// No description provided for @nairobiTimezone.
  ///
  /// In en, this message translates to:
  /// **'Nairobi (EAT) UTC+3'**
  String get nairobiTimezone;

  /// No description provided for @kampalaTimezone.
  ///
  /// In en, this message translates to:
  /// **'Kampala (EAT) UTC+3'**
  String get kampalaTimezone;

  /// No description provided for @darEsSalaamTimezone.
  ///
  /// In en, this message translates to:
  /// **'Dar es Salaam (EAT) UTC+3'**
  String get darEsSalaamTimezone;

  /// No description provided for @utcTimezone.
  ///
  /// In en, this message translates to:
  /// **'UTC (Coordinated Universal Time)'**
  String get utcTimezone;

  /// No description provided for @currencyKes.
  ///
  /// In en, this message translates to:
  /// **'KES - Kenyan Shilling'**
  String get currencyKes;

  /// No description provided for @currencyUsd.
  ///
  /// In en, this message translates to:
  /// **'USD - US Dollar'**
  String get currencyUsd;

  /// No description provided for @currencyEur.
  ///
  /// In en, this message translates to:
  /// **'EUR - Euro'**
  String get currencyEur;

  /// No description provided for @currencyGbp.
  ///
  /// In en, this message translates to:
  /// **'GBP - British Pound'**
  String get currencyGbp;

  /// No description provided for @home.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get home;

  /// No description provided for @explore.
  ///
  /// In en, this message translates to:
  /// **'Explore'**
  String get explore;

  /// No description provided for @visits.
  ///
  /// In en, this message translates to:
  /// **'Visits'**
  String get visits;

  /// No description provided for @profile.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get profile;

  /// No description provided for @whatDoYouNeed.
  ///
  /// In en, this message translates to:
  /// **'What do you need?'**
  String get whatDoYouNeed;

  /// No description provided for @properties.
  ///
  /// In en, this message translates to:
  /// **'Properties'**
  String get properties;

  /// No description provided for @laundries.
  ///
  /// In en, this message translates to:
  /// **'Laundries'**
  String get laundries;

  /// No description provided for @movers.
  ///
  /// In en, this message translates to:
  /// **'Movers'**
  String get movers;

  /// No description provided for @garbage.
  ///
  /// In en, this message translates to:
  /// **'Garbage'**
  String get garbage;

  /// No description provided for @featuredHomes.
  ///
  /// In en, this message translates to:
  /// **'Featured homes'**
  String get featuredHomes;

  /// No description provided for @seeAll.
  ///
  /// In en, this message translates to:
  /// **'See all'**
  String get seeAll;

  /// No description provided for @findYourNextHome.
  ///
  /// In en, this message translates to:
  /// **'Find your next home'**
  String get findYourNextHome;

  /// No description provided for @homeHeroDescription.
  ///
  /// In en, this message translates to:
  /// **'Verified listings, trusted landlords and honest prices across Nairobi.'**
  String get homeHeroDescription;

  /// No description provided for @searchSuburbEstatePrice.
  ///
  /// In en, this message translates to:
  /// **'Search suburb, estate or price'**
  String get searchSuburbEstatePrice;

  /// No description provided for @verified.
  ///
  /// In en, this message translates to:
  /// **'Verified'**
  String get verified;

  /// No description provided for @perMonth.
  ///
  /// In en, this message translates to:
  /// **'/month'**
  String get perMonth;

  /// No description provided for @viewProfile.
  ///
  /// In en, this message translates to:
  /// **'View profile'**
  String get viewProfile;

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @signOut.
  ///
  /// In en, this message translates to:
  /// **'Sign out'**
  String get signOut;

  /// No description provided for @getKejaMember.
  ///
  /// In en, this message translates to:
  /// **'GetKeja member'**
  String get getKejaMember;

  /// No description provided for @specializedProfiles.
  ///
  /// In en, this message translates to:
  /// **'Specialized profiles'**
  String get specializedProfiles;

  /// No description provided for @specializedProfilesDescription.
  ///
  /// In en, this message translates to:
  /// **'Create and manage your seeker, provider, or business profiles'**
  String get specializedProfilesDescription;

  /// No description provided for @editProfile.
  ///
  /// In en, this message translates to:
  /// **'Edit profile'**
  String get editProfile;

  /// No description provided for @editProfileDescription.
  ///
  /// In en, this message translates to:
  /// **'Update your name, phone, and other details'**
  String get editProfileDescription;

  /// No description provided for @changePassword.
  ///
  /// In en, this message translates to:
  /// **'Change password'**
  String get changePassword;

  /// No description provided for @updatePassword.
  ///
  /// In en, this message translates to:
  /// **'Update your password'**
  String get updatePassword;

  /// No description provided for @manageConnectedAccounts.
  ///
  /// In en, this message translates to:
  /// **'Manage Google and other linked accounts'**
  String get manageConnectedAccounts;

  /// No description provided for @security.
  ///
  /// In en, this message translates to:
  /// **'Security'**
  String get security;

  /// No description provided for @mfaMethods.
  ///
  /// In en, this message translates to:
  /// **'MFA methods'**
  String get mfaMethods;

  /// No description provided for @manageMfaMethods.
  ///
  /// In en, this message translates to:
  /// **'Manage authenticator apps and recovery codes'**
  String get manageMfaMethods;

  /// No description provided for @devices.
  ///
  /// In en, this message translates to:
  /// **'Devices'**
  String get devices;

  /// No description provided for @manageDevices.
  ///
  /// In en, this message translates to:
  /// **'View and manage your trusted devices'**
  String get manageDevices;

  /// No description provided for @reviewSessions.
  ///
  /// In en, this message translates to:
  /// **'Review and revoke active sign-ins'**
  String get reviewSessions;

  /// No description provided for @email.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get email;

  /// No description provided for @phone.
  ///
  /// In en, this message translates to:
  /// **'Phone'**
  String get phone;

  /// No description provided for @mfa.
  ///
  /// In en, this message translates to:
  /// **'MFA'**
  String get mfa;

  /// No description provided for @enabled.
  ///
  /// In en, this message translates to:
  /// **'Enabled'**
  String get enabled;

  /// No description provided for @disabled.
  ///
  /// In en, this message translates to:
  /// **'Disabled'**
  String get disabled;

  /// No description provided for @unverified.
  ///
  /// In en, this message translates to:
  /// **'Unverified'**
  String get unverified;

  /// No description provided for @unknown.
  ///
  /// In en, this message translates to:
  /// **'Unknown'**
  String get unknown;

  /// No description provided for @aboutThisHome.
  ///
  /// In en, this message translates to:
  /// **'About This Home'**
  String get aboutThisHome;

  /// No description provided for @accountReference.
  ///
  /// In en, this message translates to:
  /// **'Account Reference'**
  String get accountReference;

  /// No description provided for @active.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get active;

  /// No description provided for @activeFilters.
  ///
  /// In en, this message translates to:
  /// **'Active Filters'**
  String get activeFilters;

  /// No description provided for @alertDaily.
  ///
  /// In en, this message translates to:
  /// **'Alert Daily'**
  String get alertDaily;

  /// No description provided for @alertFrequency.
  ///
  /// In en, this message translates to:
  /// **'Alert Frequency'**
  String get alertFrequency;

  /// No description provided for @alertImmediately.
  ///
  /// In en, this message translates to:
  /// **'Alert Immediately'**
  String get alertImmediately;

  /// No description provided for @alertsOff.
  ///
  /// In en, this message translates to:
  /// **'Alerts off'**
  String get alertsOff;

  /// No description provided for @alertsOn.
  ///
  /// In en, this message translates to:
  /// **'Alerts on'**
  String get alertsOn;

  /// No description provided for @alertWeekly.
  ///
  /// In en, this message translates to:
  /// **'Alert Weekly'**
  String get alertWeekly;

  /// No description provided for @amenities.
  ///
  /// In en, this message translates to:
  /// **'Amenities'**
  String get amenities;

  /// No description provided for @amenitiesAndFeatures.
  ///
  /// In en, this message translates to:
  /// **'Amenities And Features'**
  String get amenitiesAndFeatures;

  /// No description provided for @amountLabel.
  ///
  /// In en, this message translates to:
  /// **'Amount Label'**
  String get amountLabel;

  /// No description provided for @amountOutstanding.
  ///
  /// In en, this message translates to:
  /// **'Amount Outstanding'**
  String get amountOutstanding;

  /// No description provided for @amountPaid.
  ///
  /// In en, this message translates to:
  /// **'Amount Paid'**
  String get amountPaid;

  /// No description provided for @any.
  ///
  /// In en, this message translates to:
  /// **'Any'**
  String get any;

  /// No description provided for @applyFiltersSaveSearch.
  ///
  /// In en, this message translates to:
  /// **'Apply Filters Save Search'**
  String get applyFiltersSaveSearch;

  /// No description provided for @applyNow.
  ///
  /// In en, this message translates to:
  /// **'Apply Now'**
  String get applyNow;

  /// No description provided for @availableFrom.
  ///
  /// In en, this message translates to:
  /// **'Available From'**
  String get availableFrom;

  /// No description provided for @bedrooms.
  ///
  /// In en, this message translates to:
  /// **'Bedrooms'**
  String get bedrooms;

  /// No description provided for @businessNumber.
  ///
  /// In en, this message translates to:
  /// **'Business Number'**
  String get businessNumber;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @categoryApartments.
  ///
  /// In en, this message translates to:
  /// **'Category Apartments'**
  String get categoryApartments;

  /// No description provided for @categoryBedsitters.
  ///
  /// In en, this message translates to:
  /// **'Category Bedsitters'**
  String get categoryBedsitters;

  /// No description provided for @categoryCommercial.
  ///
  /// In en, this message translates to:
  /// **'Category Commercial'**
  String get categoryCommercial;

  /// No description provided for @categoryHouses.
  ///
  /// In en, this message translates to:
  /// **'Category Houses'**
  String get categoryHouses;

  /// No description provided for @categoryLand.
  ///
  /// In en, this message translates to:
  /// **'Category Land'**
  String get categoryLand;

  /// No description provided for @categoryStudios.
  ///
  /// In en, this message translates to:
  /// **'Category Studios'**
  String get categoryStudios;

  /// No description provided for @categoryTownhouses.
  ///
  /// In en, this message translates to:
  /// **'Category Townhouses'**
  String get categoryTownhouses;

  /// No description provided for @checkingStatus.
  ///
  /// In en, this message translates to:
  /// **'Checking Status'**
  String get checkingStatus;

  /// No description provided for @checkoutFailed.
  ///
  /// In en, this message translates to:
  /// **'Checkout Failed'**
  String get checkoutFailed;

  /// No description provided for @checkoutUrl.
  ///
  /// In en, this message translates to:
  /// **'Checkout Url'**
  String get checkoutUrl;

  /// No description provided for @checkStatus.
  ///
  /// In en, this message translates to:
  /// **'Check Status'**
  String get checkStatus;

  /// No description provided for @chooseDifferentMethod.
  ///
  /// In en, this message translates to:
  /// **'Choose Different Method'**
  String get chooseDifferentMethod;

  /// No description provided for @clearFilters.
  ///
  /// In en, this message translates to:
  /// **'Clear Filters'**
  String get clearFilters;

  /// No description provided for @closeGallery.
  ///
  /// In en, this message translates to:
  /// **'Close Gallery'**
  String get closeGallery;

  /// No description provided for @compareAdded.
  ///
  /// In en, this message translates to:
  /// **'Compare Added'**
  String get compareAdded;

  /// No description provided for @compareAllowed.
  ///
  /// In en, this message translates to:
  /// **'Compare Allowed'**
  String get compareAllowed;

  /// No description provided for @compareAlreadyAdded.
  ///
  /// In en, this message translates to:
  /// **'Compare Already Added'**
  String get compareAlreadyAdded;

  /// No description provided for @compareAmenities.
  ///
  /// In en, this message translates to:
  /// **'Amenities'**
  String get compareAmenities;

  /// No description provided for @compareAtMax.
  ///
  /// In en, this message translates to:
  /// **'Comparison list is full. Remove a property to add another.'**
  String get compareAtMax;

  /// No description provided for @compareAvailableFrom.
  ///
  /// In en, this message translates to:
  /// **'Compare Available From'**
  String get compareAvailableFrom;

  /// No description provided for @compareBathrooms.
  ///
  /// In en, this message translates to:
  /// **'Bathrooms'**
  String get compareBathrooms;

  /// No description provided for @compareBaths.
  ///
  /// In en, this message translates to:
  /// **'Bathrooms'**
  String get compareBaths;

  /// No description provided for @compareBedrooms.
  ///
  /// In en, this message translates to:
  /// **'Bedrooms'**
  String get compareBedrooms;

  /// No description provided for @compareBeds.
  ///
  /// In en, this message translates to:
  /// **'beds'**
  String get compareBeds;

  /// No description provided for @compareClear.
  ///
  /// In en, this message translates to:
  /// **'Compare Clear'**
  String get compareClear;

  /// No description provided for @compareClearConfirm.
  ///
  /// In en, this message translates to:
  /// **'Compare Clear Confirm'**
  String get compareClearConfirm;

  /// No description provided for @compareCounty.
  ///
  /// In en, this message translates to:
  /// **'County'**
  String get compareCounty;

  /// No description provided for @compareDeposit.
  ///
  /// In en, this message translates to:
  /// **'Compare Deposit'**
  String get compareDeposit;

  /// No description provided for @compareDifferencesOnly.
  ///
  /// In en, this message translates to:
  /// **'Compare Differences Only'**
  String get compareDifferencesOnly;

  /// No description provided for @compareEmptyDescription.
  ///
  /// In en, this message translates to:
  /// **'Tap the compare icon on any listing to add it here. You can compare up to 4 properties side by side.'**
  String get compareEmptyDescription;

  /// No description provided for @compareEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No properties compared yet'**
  String get compareEmptyTitle;

  /// No description provided for @compareFurnished.
  ///
  /// In en, this message translates to:
  /// **'Compare Furnished'**
  String get compareFurnished;

  /// No description provided for @compareFurnishing.
  ///
  /// In en, this message translates to:
  /// **'Compare Furnishing'**
  String get compareFurnishing;

  /// No description provided for @compareLocation.
  ///
  /// In en, this message translates to:
  /// **'Location'**
  String get compareLocation;

  /// No description provided for @compareNo.
  ///
  /// In en, this message translates to:
  /// **'Compare No'**
  String get compareNo;

  /// No description provided for @compareNotAllowed.
  ///
  /// In en, this message translates to:
  /// **'Compare Not Allowed'**
  String get compareNotAllowed;

  /// No description provided for @compareNotDisclosed.
  ///
  /// In en, this message translates to:
  /// **'Compare Not Disclosed'**
  String get compareNotDisclosed;

  /// No description provided for @compareOverview.
  ///
  /// In en, this message translates to:
  /// **'Compare Overview'**
  String get compareOverview;

  /// No description provided for @comparePetPolicy.
  ///
  /// In en, this message translates to:
  /// **'Compare Pet Policy'**
  String get comparePetPolicy;

  /// No description provided for @comparePrice.
  ///
  /// In en, this message translates to:
  /// **'Price'**
  String get comparePrice;

  /// No description provided for @comparePriceOnRequest.
  ///
  /// In en, this message translates to:
  /// **'Compare Price On Request'**
  String get comparePriceOnRequest;

  /// No description provided for @comparePricing.
  ///
  /// In en, this message translates to:
  /// **'Pricing'**
  String get comparePricing;

  /// No description provided for @compareSmoking.
  ///
  /// In en, this message translates to:
  /// **'Compare Smoking'**
  String get compareSmoking;

  /// No description provided for @compareSpecifications.
  ///
  /// In en, this message translates to:
  /// **'Compare Specifications'**
  String get compareSpecifications;

  /// No description provided for @compareTitle.
  ///
  /// In en, this message translates to:
  /// **'Compare Title'**
  String get compareTitle;

  /// No description provided for @compareTown.
  ///
  /// In en, this message translates to:
  /// **'Town'**
  String get compareTown;

  /// No description provided for @compareUnfurnished.
  ///
  /// In en, this message translates to:
  /// **'Compare Unfurnished'**
  String get compareUnfurnished;

  /// No description provided for @compareViewDetails.
  ///
  /// In en, this message translates to:
  /// **'Compare View Details'**
  String get compareViewDetails;

  /// No description provided for @compareYes.
  ///
  /// In en, this message translates to:
  /// **'Compare Yes'**
  String get compareYes;

  /// No description provided for @completePaymentInBrowser.
  ///
  /// In en, this message translates to:
  /// **'Complete Payment In Browser'**
  String get completePaymentInBrowser;

  /// No description provided for @configured.
  ///
  /// In en, this message translates to:
  /// **'Configured'**
  String get configured;

  /// No description provided for @couldNotDeleteSearch.
  ///
  /// In en, this message translates to:
  /// **'Could Not Delete Search'**
  String get couldNotDeleteSearch;

  /// No description provided for @couldNotLoadNotifications.
  ///
  /// In en, this message translates to:
  /// **'Could Not Load Notifications'**
  String get couldNotLoadNotifications;

  /// No description provided for @couldNotLoadProperty.
  ///
  /// In en, this message translates to:
  /// **'Could Not Load Property'**
  String get couldNotLoadProperty;

  /// No description provided for @couldNotLoadSavedHomes.
  ///
  /// In en, this message translates to:
  /// **'Could Not Load Saved Homes'**
  String get couldNotLoadSavedHomes;

  /// No description provided for @couldNotLoadSavedSearches.
  ///
  /// In en, this message translates to:
  /// **'Could Not Load Saved Searches'**
  String get couldNotLoadSavedSearches;

  /// No description provided for @couldNotRunSearch.
  ///
  /// In en, this message translates to:
  /// **'Could Not Run Search'**
  String get couldNotRunSearch;

  /// No description provided for @couldNotUpdateAlerts.
  ///
  /// In en, this message translates to:
  /// **'Could Not Update Alerts'**
  String get couldNotUpdateAlerts;

  /// No description provided for @couldNotUpdateSearch.
  ///
  /// In en, this message translates to:
  /// **'Could Not Update Search'**
  String get couldNotUpdateSearch;

  /// No description provided for @county.
  ///
  /// In en, this message translates to:
  /// **'County'**
  String get county;

  /// No description provided for @deleteSavedSearch.
  ///
  /// In en, this message translates to:
  /// **'Delete Saved Search'**
  String get deleteSavedSearch;

  /// No description provided for @deleteSearch.
  ///
  /// In en, this message translates to:
  /// **'Delete Search'**
  String get deleteSearch;

  /// No description provided for @deposit.
  ///
  /// In en, this message translates to:
  /// **'Deposit'**
  String get deposit;

  /// No description provided for @depositBalance.
  ///
  /// In en, this message translates to:
  /// **'Deposit Balance'**
  String get depositBalance;

  /// No description provided for @deposits.
  ///
  /// In en, this message translates to:
  /// **'Deposits'**
  String get deposits;

  /// No description provided for @discoverHomes.
  ///
  /// In en, this message translates to:
  /// **'Discover homes'**
  String get discoverHomes;

  /// No description provided for @downloadReceipt.
  ///
  /// In en, this message translates to:
  /// **'Download Receipt'**
  String get downloadReceipt;

  /// No description provided for @downloadReceipts.
  ///
  /// In en, this message translates to:
  /// **'Download Receipts'**
  String get downloadReceipts;

  /// No description provided for @dueDate.
  ///
  /// In en, this message translates to:
  /// **'Due Date'**
  String get dueDate;

  /// No description provided for @edit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get edit;

  /// No description provided for @editSavedSearch.
  ///
  /// In en, this message translates to:
  /// **'Edit Saved Search'**
  String get editSavedSearch;

  /// No description provided for @enquire.
  ///
  /// In en, this message translates to:
  /// **'Enquire'**
  String get enquire;

  /// No description provided for @failedToLoadDashboard.
  ///
  /// In en, this message translates to:
  /// **'Failed To Load Dashboard'**
  String get failedToLoadDashboard;

  /// No description provided for @failedToLoadInvoice.
  ///
  /// In en, this message translates to:
  /// **'Failed To Load Invoice'**
  String get failedToLoadInvoice;

  /// No description provided for @failedToLoadInvoices.
  ///
  /// In en, this message translates to:
  /// **'Failed To Load Invoices'**
  String get failedToLoadInvoices;

  /// No description provided for @failedToLoadPaymentHistory.
  ///
  /// In en, this message translates to:
  /// **'Failed To Load Payment History'**
  String get failedToLoadPaymentHistory;

  /// No description provided for @failedToLoadProviders.
  ///
  /// In en, this message translates to:
  /// **'Failed To Load Providers'**
  String get failedToLoadProviders;

  /// No description provided for @failedToLoadReceipts.
  ///
  /// In en, this message translates to:
  /// **'Failed To Load Receipts'**
  String get failedToLoadReceipts;

  /// No description provided for @featuredLoadError.
  ///
  /// In en, this message translates to:
  /// **'Featured Load Error'**
  String get featuredLoadError;

  /// No description provided for @filters.
  ///
  /// In en, this message translates to:
  /// **'Filters'**
  String get filters;

  /// No description provided for @financialStatement.
  ///
  /// In en, this message translates to:
  /// **'Financial Statement'**
  String get financialStatement;

  /// No description provided for @furnished.
  ///
  /// In en, this message translates to:
  /// **'Furnished'**
  String get furnished;

  /// No description provided for @furnishing.
  ///
  /// In en, this message translates to:
  /// **'Furnishing'**
  String get furnishing;

  /// No description provided for @gallery.
  ///
  /// In en, this message translates to:
  /// **'Gallery'**
  String get gallery;

  /// No description provided for @howOftenToAlert.
  ///
  /// In en, this message translates to:
  /// **'How Often To Alert'**
  String get howOftenToAlert;

  /// No description provided for @iHavePaid.
  ///
  /// In en, this message translates to:
  /// **'I Have Paid'**
  String get iHavePaid;

  /// No description provided for @initiating.
  ///
  /// In en, this message translates to:
  /// **'Initiating'**
  String get initiating;

  /// No description provided for @invoiceAlreadyPaid.
  ///
  /// In en, this message translates to:
  /// **'Invoice Already Paid'**
  String get invoiceAlreadyPaid;

  /// No description provided for @invoiceDescription.
  ///
  /// In en, this message translates to:
  /// **'Invoice Description'**
  String get invoiceDescription;

  /// No description provided for @invoiceItems.
  ///
  /// In en, this message translates to:
  /// **'Invoice Items'**
  String get invoiceItems;

  /// No description provided for @invoiceItemsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Invoice Items Subtitle'**
  String get invoiceItemsSubtitle;

  /// No description provided for @invoiceNotPayable.
  ///
  /// In en, this message translates to:
  /// **'Invoice Not Payable'**
  String get invoiceNotPayable;

  /// No description provided for @invoiceReference.
  ///
  /// In en, this message translates to:
  /// **'Invoice Reference'**
  String get invoiceReference;

  /// No description provided for @invoices.
  ///
  /// In en, this message translates to:
  /// **'Invoices'**
  String get invoices;

  /// No description provided for @issuedDate.
  ///
  /// In en, this message translates to:
  /// **'Issued Date'**
  String get issuedDate;

  /// No description provided for @keep.
  ///
  /// In en, this message translates to:
  /// **'Keep'**
  String get keep;

  /// No description provided for @listedBy.
  ///
  /// In en, this message translates to:
  /// **'Listed By'**
  String get listedBy;

  /// No description provided for @listingDetails.
  ///
  /// In en, this message translates to:
  /// **'Listing Details'**
  String get listingDetails;

  /// No description provided for @location.
  ///
  /// In en, this message translates to:
  /// **'Location'**
  String get location;

  /// No description provided for @locationNotSet.
  ///
  /// In en, this message translates to:
  /// **'Could not load your rental journey.'**
  String get locationNotSet;

  /// No description provided for @makePayment.
  ///
  /// In en, this message translates to:
  /// **'Make Payment'**
  String get makePayment;

  /// No description provided for @mapPreviewUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Map Preview Unavailable'**
  String get mapPreviewUnavailable;

  /// No description provided for @markAllRead.
  ///
  /// In en, this message translates to:
  /// **'Mark All Read'**
  String get markAllRead;

  /// No description provided for @markAsRead.
  ///
  /// In en, this message translates to:
  /// **'Mark As Read'**
  String get markAsRead;

  /// No description provided for @maxPrice.
  ///
  /// In en, this message translates to:
  /// **'Max Price'**
  String get maxPrice;

  /// No description provided for @message.
  ///
  /// In en, this message translates to:
  /// **'Message landlord'**
  String get message;

  /// No description provided for @minPrice.
  ///
  /// In en, this message translates to:
  /// **'Min Price'**
  String get minPrice;

  /// No description provided for @nameThisSearch.
  ///
  /// In en, this message translates to:
  /// **'Name This Search'**
  String get nameThisSearch;

  /// No description provided for @neighbourhood.
  ///
  /// In en, this message translates to:
  /// **'Neighbourhood'**
  String get neighbourhood;

  /// No description provided for @newest.
  ///
  /// In en, this message translates to:
  /// **'Newest'**
  String get newest;

  /// No description provided for @noHomesMatch.
  ///
  /// In en, this message translates to:
  /// **'No homes match your search'**
  String get noHomesMatch;

  /// No description provided for @noInvoices.
  ///
  /// In en, this message translates to:
  /// **'No Invoices'**
  String get noInvoices;

  /// No description provided for @noNotifications.
  ///
  /// In en, this message translates to:
  /// **'No Notifications'**
  String get noNotifications;

  /// No description provided for @noNotificationsDescription.
  ///
  /// In en, this message translates to:
  /// **'No Notifications Description'**
  String get noNotificationsDescription;

  /// No description provided for @noPaymentHistory.
  ///
  /// In en, this message translates to:
  /// **'No Payment History'**
  String get noPaymentHistory;

  /// No description provided for @noPaymentMethods.
  ///
  /// In en, this message translates to:
  /// **'No payment methods available'**
  String get noPaymentMethods;

  /// No description provided for @noReceipts.
  ///
  /// In en, this message translates to:
  /// **'No Receipts'**
  String get noReceipts;

  /// No description provided for @noSavedHomesYet.
  ///
  /// In en, this message translates to:
  /// **'No saved homes yet'**
  String get noSavedHomesYet;

  /// No description provided for @noSavedLocationDescription.
  ///
  /// In en, this message translates to:
  /// **'Saved homes'**
  String get noSavedLocationDescription;

  /// No description provided for @noSavedSearchesYet.
  ///
  /// In en, this message translates to:
  /// **'No saved searches yet'**
  String get noSavedSearchesYet;

  /// No description provided for @notificationsTitle.
  ///
  /// In en, this message translates to:
  /// **'Notifications Title'**
  String get notificationsTitle;

  /// No description provided for @notificationPreferences.
  ///
  /// In en, this message translates to:
  /// **'Notification preferences'**
  String get notificationPreferences;

  /// No description provided for @homeMaintenance.
  ///
  /// In en, this message translates to:
  /// **'Home maintenance'**
  String get homeMaintenance;

  /// No description provided for @homeMaintenanceEmpty.
  ///
  /// In en, this message translates to:
  /// **'No maintenance jobs yet'**
  String get homeMaintenanceEmpty;

  /// No description provided for @inspectionReport.
  ///
  /// In en, this message translates to:
  /// **'Inspection report'**
  String get inspectionReport;

  /// No description provided for @safetyConcerns.
  ///
  /// In en, this message translates to:
  /// **'Safety concerns'**
  String get safetyConcerns;

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

  /// No description provided for @confirmCompletion.
  ///
  /// In en, this message translates to:
  /// **'Confirm completion'**
  String get confirmCompletion;

  /// No description provided for @recordInspection.
  ///
  /// In en, this message translates to:
  /// **'Record inspection'**
  String get recordInspection;

  /// No description provided for @startWork.
  ///
  /// In en, this message translates to:
  /// **'Start work'**
  String get startWork;

  /// No description provided for @qualityCheck.
  ///
  /// In en, this message translates to:
  /// **'Quality check'**
  String get qualityCheck;

  /// No description provided for @cleaningOperations.
  ///
  /// In en, this message translates to:
  /// **'Cleaning & property care'**
  String get cleaningOperations;

  /// No description provided for @cleaningOperationsEmpty.
  ///
  /// In en, this message translates to:
  /// **'No cleaning jobs yet'**
  String get cleaningOperationsEmpty;

  /// No description provided for @assessmentReport.
  ///
  /// In en, this message translates to:
  /// **'Assessment report'**
  String get assessmentReport;

  /// No description provided for @recordAssessment.
  ///
  /// In en, this message translates to:
  /// **'Record assessment'**
  String get recordAssessment;

  /// No description provided for @checklist.
  ///
  /// In en, this message translates to:
  /// **'Checklist'**
  String get checklist;

  /// No description provided for @installationOperations.
  ///
  /// In en, this message translates to:
  /// **'Installation & technical services'**
  String get installationOperations;

  /// No description provided for @installationOperationsEmpty.
  ///
  /// In en, this message translates to:
  /// **'No installation jobs yet'**
  String get installationOperationsEmpty;

  /// No description provided for @installationPlan.
  ///
  /// In en, this message translates to:
  /// **'Installation plan'**
  String get installationPlan;

  /// No description provided for @deliverables.
  ///
  /// In en, this message translates to:
  /// **'Deliverables'**
  String get deliverables;

  /// No description provided for @equipment.
  ///
  /// In en, this message translates to:
  /// **'Equipment'**
  String get equipment;

  /// No description provided for @testingCommissioning.
  ///
  /// In en, this message translates to:
  /// **'Testing & commissioning'**
  String get testingCommissioning;

  /// No description provided for @addPlan.
  ///
  /// In en, this message translates to:
  /// **'Add plan'**
  String get addPlan;

  /// No description provided for @summary.
  ///
  /// In en, this message translates to:
  /// **'Summary'**
  String get summary;

  /// No description provided for @addEquipment.
  ///
  /// In en, this message translates to:
  /// **'Add equipment'**
  String get addEquipment;

  /// No description provided for @description.
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get description;

  /// No description provided for @quantity.
  ///
  /// In en, this message translates to:
  /// **'Quantity'**
  String get quantity;

  /// No description provided for @serialOrId.
  ///
  /// In en, this message translates to:
  /// **'Serial / ID'**
  String get serialOrId;

  /// No description provided for @recordTest.
  ///
  /// In en, this message translates to:
  /// **'Record test'**
  String get recordTest;

  /// No description provided for @testName.
  ///
  /// In en, this message translates to:
  /// **'Test name'**
  String get testName;

  /// No description provided for @outcome.
  ///
  /// In en, this message translates to:
  /// **'Outcome'**
  String get outcome;

  /// No description provided for @uploadEvidence.
  ///
  /// In en, this message translates to:
  /// **'Upload evidence'**
  String get uploadEvidence;

  /// No description provided for @documentId.
  ///
  /// In en, this message translates to:
  /// **'Document ID'**
  String get documentId;

  /// No description provided for @evidenceKind.
  ///
  /// In en, this message translates to:
  /// **'Evidence kind'**
  String get evidenceKind;

  /// No description provided for @assignStaff.
  ///
  /// In en, this message translates to:
  /// **'Assign staff'**
  String get assignStaff;

  /// No description provided for @staffUserId.
  ///
  /// In en, this message translates to:
  /// **'Staff user ID'**
  String get staffUserId;

  /// No description provided for @label.
  ///
  /// In en, this message translates to:
  /// **'Label'**
  String get label;

  /// No description provided for @staff.
  ///
  /// In en, this message translates to:
  /// **'Staff'**
  String get staff;

  /// No description provided for @startTesting.
  ///
  /// In en, this message translates to:
  /// **'Start testing'**
  String get startTesting;

  /// No description provided for @readyForHandover.
  ///
  /// In en, this message translates to:
  /// **'Ready for handover'**
  String get readyForHandover;

  /// No description provided for @messages.
  ///
  /// In en, this message translates to:
  /// **'Messages'**
  String get messages;

  /// No description provided for @contactProvider.
  ///
  /// In en, this message translates to:
  /// **'Contact provider'**
  String get contactProvider;

  /// No description provided for @noMessages.
  ///
  /// In en, this message translates to:
  /// **'No messages yet'**
  String get noMessages;

  /// No description provided for @typeMessage.
  ///
  /// In en, this message translates to:
  /// **'Type a message'**
  String get typeMessage;

  /// No description provided for @notificationCategories.
  ///
  /// In en, this message translates to:
  /// **'Categories'**
  String get notificationCategories;

  /// No description provided for @categorySecurity.
  ///
  /// In en, this message translates to:
  /// **'Account & security'**
  String get categorySecurity;

  /// No description provided for @categoryService.
  ///
  /// In en, this message translates to:
  /// **'Marketplace & service requests'**
  String get categoryService;

  /// No description provided for @categoryOperational.
  ///
  /// In en, this message translates to:
  /// **'Service progress & scheduling'**
  String get categoryOperational;

  /// No description provided for @categoryMarketing.
  ///
  /// In en, this message translates to:
  /// **'Marketing & promotions'**
  String get categoryMarketing;

  /// No description provided for @inAppNotifications.
  ///
  /// In en, this message translates to:
  /// **'In-app'**
  String get inAppNotifications;

  /// No description provided for @securityNotificationsAlwaysOn.
  ///
  /// In en, this message translates to:
  /// **'Essential security notifications are always delivered and cannot be turned off.'**
  String get securityNotificationsAlwaysOn;

  /// No description provided for @outstandingBalance.
  ///
  /// In en, this message translates to:
  /// **'Outstanding Balance'**
  String get outstandingBalance;

  /// No description provided for @pay.
  ///
  /// In en, this message translates to:
  /// **'Pay'**
  String get pay;

  /// No description provided for @payableFromYourTenancy.
  ///
  /// In en, this message translates to:
  /// **'Payable From Your Tenancy'**
  String get payableFromYourTenancy;

  /// No description provided for @payInvoice.
  ///
  /// In en, this message translates to:
  /// **'Pay Invoice'**
  String get payInvoice;

  /// No description provided for @paymentCompleted.
  ///
  /// In en, this message translates to:
  /// **'Payment Completed'**
  String get paymentCompleted;

  /// No description provided for @paymentConfirmed.
  ///
  /// In en, this message translates to:
  /// **'Payment Confirmed'**
  String get paymentConfirmed;

  /// No description provided for @paymentConfirmedByProvider.
  ///
  /// In en, this message translates to:
  /// **'Payment Confirmed By Provider'**
  String get paymentConfirmedByProvider;

  /// No description provided for @paymentDidNotComplete.
  ///
  /// In en, this message translates to:
  /// **'Payment Did Not Complete'**
  String get paymentDidNotComplete;

  /// No description provided for @paymentFailed.
  ///
  /// In en, this message translates to:
  /// **'Payment Failed'**
  String get paymentFailed;

  /// No description provided for @paymentHistory.
  ///
  /// In en, this message translates to:
  /// **'Payment History'**
  String get paymentHistory;

  /// No description provided for @paymentHistorySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Payment History Subtitle'**
  String get paymentHistorySubtitle;

  /// No description provided for @paymentNotConfirmed.
  ///
  /// In en, this message translates to:
  /// **'Payment Not Confirmed'**
  String get paymentNotConfirmed;

  /// No description provided for @paymentPending.
  ///
  /// In en, this message translates to:
  /// **'Payment Pending'**
  String get paymentPending;

  /// No description provided for @payNow.
  ///
  /// In en, this message translates to:
  /// **'Pay Now'**
  String get payNow;

  /// No description provided for @payOutstandingBalance.
  ///
  /// In en, this message translates to:
  /// **'Pay Outstanding Balance'**
  String get payOutstandingBalance;

  /// No description provided for @petPolicy.
  ///
  /// In en, this message translates to:
  /// **'Pet Policy'**
  String get petPolicy;

  /// No description provided for @phoneNumber.
  ///
  /// In en, this message translates to:
  /// **'Phone Number'**
  String get phoneNumber;

  /// No description provided for @priceHighToLow.
  ///
  /// In en, this message translates to:
  /// **'Price high to low'**
  String get priceHighToLow;

  /// No description provided for @priceLowToHigh.
  ///
  /// In en, this message translates to:
  /// **'Price Low To High'**
  String get priceLowToHigh;

  /// No description provided for @priceOnRequest.
  ///
  /// In en, this message translates to:
  /// **'Price on request'**
  String get priceOnRequest;

  /// No description provided for @priceRangeKes.
  ///
  /// In en, this message translates to:
  /// **'Price range (KES)'**
  String get priceRangeKes;

  /// No description provided for @property.
  ///
  /// In en, this message translates to:
  /// **'Property'**
  String get property;

  /// No description provided for @propertyDetails.
  ///
  /// In en, this message translates to:
  /// **'Property Details'**
  String get propertyDetails;

  /// No description provided for @propertyNotFound.
  ///
  /// In en, this message translates to:
  /// **'Property not found.'**
  String get propertyNotFound;

  /// No description provided for @propertyOwner.
  ///
  /// In en, this message translates to:
  /// **'Property owner'**
  String get propertyOwner;

  /// No description provided for @propertySaved.
  ///
  /// In en, this message translates to:
  /// **'Property Saved'**
  String get propertySaved;

  /// No description provided for @propertyType.
  ///
  /// In en, this message translates to:
  /// **'Property type'**
  String get propertyType;

  /// No description provided for @propertyUnavailable.
  ///
  /// In en, this message translates to:
  /// **'This property is no longer available.'**
  String get propertyUnavailable;

  /// No description provided for @propertyUnsaved.
  ///
  /// In en, this message translates to:
  /// **'Property Unsaved'**
  String get propertyUnsaved;

  /// No description provided for @providerAdd.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get providerAdd;

  /// No description provided for @providerAddLocation.
  ///
  /// In en, this message translates to:
  /// **'Add location'**
  String get providerAddLocation;

  /// No description provided for @providerAddService.
  ///
  /// In en, this message translates to:
  /// **'Add service'**
  String get providerAddService;

  /// No description provided for @providerAvailability.
  ///
  /// In en, this message translates to:
  /// **'Operating hours'**
  String get providerAvailability;

  /// No description provided for @providerBaseAmount.
  ///
  /// In en, this message translates to:
  /// **'Base amount (KES)'**
  String get providerBaseAmount;

  /// No description provided for @providerCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get providerCancel;

  /// No description provided for @providerCity.
  ///
  /// In en, this message translates to:
  /// **'City'**
  String get providerCity;

  /// No description provided for @providerClosed.
  ///
  /// In en, this message translates to:
  /// **'Closed'**
  String get providerClosed;

  /// No description provided for @providerCounty.
  ///
  /// In en, this message translates to:
  /// **'County'**
  String get providerCounty;

  /// No description provided for @providerDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get providerDelete;

  /// No description provided for @providerError.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong'**
  String get providerError;

  /// No description provided for @providerLatitude.
  ///
  /// In en, this message translates to:
  /// **'Latitude'**
  String get providerLatitude;

  /// No description provided for @providerLocations.
  ///
  /// In en, this message translates to:
  /// **'Locations'**
  String get providerLocations;

  /// No description provided for @providerLongitude.
  ///
  /// In en, this message translates to:
  /// **'Longitude'**
  String get providerLongitude;

  /// No description provided for @providerNoAreas.
  ///
  /// In en, this message translates to:
  /// **'No service areas yet'**
  String get providerNoAreas;

  /// No description provided for @providerNoLocations.
  ///
  /// In en, this message translates to:
  /// **'No locations yet'**
  String get providerNoLocations;

  /// No description provided for @providerNoServices.
  ///
  /// In en, this message translates to:
  /// **'No services yet'**
  String get providerNoServices;

  /// No description provided for @providerPublicLocation.
  ///
  /// In en, this message translates to:
  /// **'Public location'**
  String get providerPublicLocation;

  /// No description provided for @providerRequired.
  ///
  /// In en, this message translates to:
  /// **'Required'**
  String get providerRequired;

  /// No description provided for @providerSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get providerSave;

  /// No description provided for @providerSaved.
  ///
  /// In en, this message translates to:
  /// **'Saved'**
  String get providerSaved;

  /// No description provided for @providerServiceAreas.
  ///
  /// In en, this message translates to:
  /// **'Service areas'**
  String get providerServiceAreas;

  /// No description provided for @providerServiceCategory.
  ///
  /// In en, this message translates to:
  /// **'Category'**
  String get providerServiceCategory;

  /// No description provided for @providerServices.
  ///
  /// In en, this message translates to:
  /// **'Services'**
  String get providerServices;

  /// No description provided for @providerServiceTitle.
  ///
  /// In en, this message translates to:
  /// **'Service title'**
  String get providerServiceTitle;

  /// No description provided for @providerSetPrimary.
  ///
  /// In en, this message translates to:
  /// **'Set primary'**
  String get providerSetPrimary;

  /// No description provided for @providerStatus.
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get providerStatus;

  /// No description provided for @providerTemporaryClosure.
  ///
  /// In en, this message translates to:
  /// **'Temporary closure'**
  String get providerTemporaryClosure;

  /// No description provided for @quickActions.
  ///
  /// In en, this message translates to:
  /// **'Quick Actions'**
  String get quickActions;

  /// No description provided for @quickActionsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Quick Actions Subtitle'**
  String get quickActionsSubtitle;

  /// No description provided for @readLess.
  ///
  /// In en, this message translates to:
  /// **'Read Less'**
  String get readLess;

  /// No description provided for @readMore.
  ///
  /// In en, this message translates to:
  /// **'Read More'**
  String get readMore;

  /// No description provided for @receipts.
  ///
  /// In en, this message translates to:
  /// **'Receipts'**
  String get receipts;

  /// No description provided for @relatedProperties.
  ///
  /// In en, this message translates to:
  /// **'Related Properties'**
  String get relatedProperties;

  /// No description provided for @relevance.
  ///
  /// In en, this message translates to:
  /// **'Relevance'**
  String get relevance;

  /// No description provided for @remove.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get remove;

  /// No description provided for @removedFromSaved.
  ///
  /// In en, this message translates to:
  /// **'Removed from saved homes.'**
  String get removedFromSaved;

  /// No description provided for @rentalAppDocuments.
  ///
  /// In en, this message translates to:
  /// **'Rental App Documents'**
  String get rentalAppDocuments;

  /// No description provided for @rentalAppOnboarded.
  ///
  /// In en, this message translates to:
  /// **'Rental App Onboarded'**
  String get rentalAppOnboarded;

  /// No description provided for @rentalAppOnboardedDesc.
  ///
  /// In en, this message translates to:
  /// **'Rental App Onboarded Desc'**
  String get rentalAppOnboardedDesc;

  /// No description provided for @rentalAppOutcome.
  ///
  /// In en, this message translates to:
  /// **'Rental App Outcome'**
  String get rentalAppOutcome;

  /// No description provided for @rentalAppPreferredEnd.
  ///
  /// In en, this message translates to:
  /// **'Rental App Preferred End'**
  String get rentalAppPreferredEnd;

  /// No description provided for @rentalAppPreferredStart.
  ///
  /// In en, this message translates to:
  /// **'Rental App Preferred Start'**
  String get rentalAppPreferredStart;

  /// No description provided for @rentalAppProposedRent.
  ///
  /// In en, this message translates to:
  /// **'Rental App Proposed Rent'**
  String get rentalAppProposedRent;

  /// No description provided for @rentalAppRespond.
  ///
  /// In en, this message translates to:
  /// **'Rental App Respond'**
  String get rentalAppRespond;

  /// No description provided for @rentalAppTimeline.
  ///
  /// In en, this message translates to:
  /// **'Rental App Timeline'**
  String get rentalAppTimeline;

  /// No description provided for @rentalAppTitle.
  ///
  /// In en, this message translates to:
  /// **'Rental App Title'**
  String get rentalAppTitle;

  /// No description provided for @rentalAppUploadDocument.
  ///
  /// In en, this message translates to:
  /// **'Upload document'**
  String get rentalAppUploadDocument;

  /// No description provided for @rentalAppWithdraw.
  ///
  /// In en, this message translates to:
  /// **'Withdraw application'**
  String get rentalAppWithdraw;

  /// No description provided for @rentalListing.
  ///
  /// In en, this message translates to:
  /// **'Rental Listing'**
  String get rentalListing;

  /// No description provided for @reportListing.
  ///
  /// In en, this message translates to:
  /// **'Report Listing'**
  String get reportListing;

  /// No description provided for @requestVisit.
  ///
  /// In en, this message translates to:
  /// **'Request Visit'**
  String get requestVisit;

  /// No description provided for @reset.
  ///
  /// In en, this message translates to:
  /// **'Reset'**
  String get reset;

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// No description provided for @retryAction.
  ///
  /// In en, this message translates to:
  /// **'Retry Action'**
  String get retryAction;

  /// No description provided for @retryPayment.
  ///
  /// In en, this message translates to:
  /// **'Retry Payment'**
  String get retryPayment;

  /// No description provided for @runNow.
  ///
  /// In en, this message translates to:
  /// **'Run Now'**
  String get runNow;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @saveCurrentSearch.
  ///
  /// In en, this message translates to:
  /// **'Save Current Search'**
  String get saveCurrentSearch;

  /// No description provided for @savedHomes.
  ///
  /// In en, this message translates to:
  /// **'Saved Homes'**
  String get savedHomes;

  /// No description provided for @savedLocation.
  ///
  /// In en, this message translates to:
  /// **'Saved Location'**
  String get savedLocation;

  /// No description provided for @savedSearches.
  ///
  /// In en, this message translates to:
  /// **'Saved Searches'**
  String get savedSearches;

  /// No description provided for @searchHomes.
  ///
  /// In en, this message translates to:
  /// **'Search homes'**
  String get searchHomes;

  /// No description provided for @searchMatched.
  ///
  /// In en, this message translates to:
  /// **'Search Matched'**
  String get searchMatched;

  /// No description provided for @searchSaved.
  ///
  /// In en, this message translates to:
  /// **'Search Saved'**
  String get searchSaved;

  /// No description provided for @searchUpdated.
  ///
  /// In en, this message translates to:
  /// **'Search Updated'**
  String get searchUpdated;

  /// No description provided for @searchWillBeRemoved.
  ///
  /// In en, this message translates to:
  /// **'Search Will Be Removed'**
  String get searchWillBeRemoved;

  /// No description provided for @sendNotifications.
  ///
  /// In en, this message translates to:
  /// **'Send Notifications'**
  String get sendNotifications;

  /// No description provided for @setLocation.
  ///
  /// In en, this message translates to:
  /// **'Set Location'**
  String get setLocation;

  /// No description provided for @shareNotAvailable.
  ///
  /// In en, this message translates to:
  /// **'Share Not Available'**
  String get shareNotAvailable;

  /// No description provided for @shareProperty.
  ///
  /// In en, this message translates to:
  /// **'Share Property'**
  String get shareProperty;

  /// No description provided for @showAllAmenities.
  ///
  /// In en, this message translates to:
  /// **'Show All Amenities'**
  String get showAllAmenities;

  /// No description provided for @showHomes.
  ///
  /// In en, this message translates to:
  /// **'Show Homes'**
  String get showHomes;

  /// No description provided for @showLessAmenities.
  ///
  /// In en, this message translates to:
  /// **'Show Less Amenities'**
  String get showLessAmenities;

  /// No description provided for @siteVisit.
  ///
  /// In en, this message translates to:
  /// **'Site Visit'**
  String get siteVisit;

  /// No description provided for @siteVisitCancelConfirm.
  ///
  /// In en, this message translates to:
  /// **'Cancel visit'**
  String get siteVisitCancelConfirm;

  /// No description provided for @siteVisitCancelDesc.
  ///
  /// In en, this message translates to:
  /// **'Site visit cancel desc'**
  String get siteVisitCancelDesc;

  /// No description provided for @siteVisitCancelKeep.
  ///
  /// In en, this message translates to:
  /// **'Site Visit Cancel Keep'**
  String get siteVisitCancelKeep;

  /// No description provided for @siteVisitCancelled.
  ///
  /// In en, this message translates to:
  /// **'Site Visit Cancelled'**
  String get siteVisitCancelled;

  /// No description provided for @siteVisitCancelledSuccess.
  ///
  /// In en, this message translates to:
  /// **'Site Visit Cancelled Success'**
  String get siteVisitCancelledSuccess;

  /// No description provided for @siteVisitCancelTitle.
  ///
  /// In en, this message translates to:
  /// **'Cancel visit'**
  String get siteVisitCancelTitle;

  /// No description provided for @siteVisitCompleted.
  ///
  /// In en, this message translates to:
  /// **'Site Visit Completed'**
  String get siteVisitCompleted;

  /// No description provided for @siteVisitDeclined.
  ///
  /// In en, this message translates to:
  /// **'Site Visit Declined'**
  String get siteVisitDeclined;

  /// No description provided for @siteVisitDurationMin.
  ///
  /// In en, this message translates to:
  /// **'Site Visit Duration Min'**
  String get siteVisitDurationMin;

  /// No description provided for @siteVisitHostNotes.
  ///
  /// In en, this message translates to:
  /// **'Site Visit Host Notes'**
  String get siteVisitHostNotes;

  /// No description provided for @siteVisitMyVisits.
  ///
  /// In en, this message translates to:
  /// **'Site Visit My Visits'**
  String get siteVisitMyVisits;

  /// No description provided for @siteVisitNoShow.
  ///
  /// In en, this message translates to:
  /// **'Site Visit No Show'**
  String get siteVisitNoShow;

  /// No description provided for @siteVisitNoVisits.
  ///
  /// In en, this message translates to:
  /// **'Site Visit No Visits'**
  String get siteVisitNoVisits;

  /// No description provided for @siteVisitNoVisitsDesc.
  ///
  /// In en, this message translates to:
  /// **'No site visits yet'**
  String get siteVisitNoVisitsDesc;

  /// No description provided for @siteVisitOutcome.
  ///
  /// In en, this message translates to:
  /// **'Site Visit Outcome'**
  String get siteVisitOutcome;

  /// No description provided for @siteVisitPending.
  ///
  /// In en, this message translates to:
  /// **'Site Visit Pending'**
  String get siteVisitPending;

  /// No description provided for @siteVisitProperty.
  ///
  /// In en, this message translates to:
  /// **'Site Visit Property'**
  String get siteVisitProperty;

  /// No description provided for @siteVisitRequestError.
  ///
  /// In en, this message translates to:
  /// **'Site Visit Request Error'**
  String get siteVisitRequestError;

  /// No description provided for @siteVisitRequestVisit.
  ///
  /// In en, this message translates to:
  /// **'Site Visit Request Visit'**
  String get siteVisitRequestVisit;

  /// No description provided for @siteVisitRescheduled.
  ///
  /// In en, this message translates to:
  /// **'Site Visit Rescheduled'**
  String get siteVisitRescheduled;

  /// No description provided for @siteVisitRescheduledSuccess.
  ///
  /// In en, this message translates to:
  /// **'Site Visit Rescheduled Success'**
  String get siteVisitRescheduledSuccess;

  /// No description provided for @siteVisitRescheduleSubmit.
  ///
  /// In en, this message translates to:
  /// **'Site Visit Reschedule Submit'**
  String get siteVisitRescheduleSubmit;

  /// No description provided for @siteVisitSubmitted.
  ///
  /// In en, this message translates to:
  /// **'Site Visit Submitted'**
  String get siteVisitSubmitted;

  /// No description provided for @siteVisitTitle.
  ///
  /// In en, this message translates to:
  /// **'Site Visit Title'**
  String get siteVisitTitle;

  /// No description provided for @siteVisitUpcoming.
  ///
  /// In en, this message translates to:
  /// **'Upcoming'**
  String get siteVisitUpcoming;

  /// No description provided for @siteVisitVisitDetails.
  ///
  /// In en, this message translates to:
  /// **'Site Visit Visit Details'**
  String get siteVisitVisitDetails;

  /// No description provided for @siteVisitVisitorNotes.
  ///
  /// In en, this message translates to:
  /// **'Site Visit Visitor Notes'**
  String get siteVisitVisitorNotes;

  /// No description provided for @smoking.
  ///
  /// In en, this message translates to:
  /// **'Smoking'**
  String get smoking;

  /// No description provided for @statement.
  ///
  /// In en, this message translates to:
  /// **'Statement'**
  String get statement;

  /// No description provided for @status.
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get status;

  /// No description provided for @tapHeartSaveHome.
  ///
  /// In en, this message translates to:
  /// **'Tap the heart on any listing to save it here.'**
  String get tapHeartSaveHome;

  /// No description provided for @transactionReference.
  ///
  /// In en, this message translates to:
  /// **'Transaction Reference'**
  String get transactionReference;

  /// No description provided for @tryAgain.
  ///
  /// In en, this message translates to:
  /// **'Try Again'**
  String get tryAgain;

  /// No description provided for @tryDifferentMethod.
  ///
  /// In en, this message translates to:
  /// **'Try Different Method'**
  String get tryDifferentMethod;

  /// No description provided for @tryWideningFilters.
  ///
  /// In en, this message translates to:
  /// **'Try Widening Filters'**
  String get tryWideningFilters;

  /// No description provided for @turnOffAlerts.
  ///
  /// In en, this message translates to:
  /// **'Turn Off Alerts'**
  String get turnOffAlerts;

  /// No description provided for @turnOnAlerts.
  ///
  /// In en, this message translates to:
  /// **'Turn On Alerts'**
  String get turnOnAlerts;

  /// No description provided for @unfurnished.
  ///
  /// In en, this message translates to:
  /// **'Unfurnished'**
  String get unfurnished;

  /// No description provided for @unit.
  ///
  /// In en, this message translates to:
  /// **'Unit'**
  String get unit;

  /// No description provided for @unpaidInvoices.
  ///
  /// In en, this message translates to:
  /// **'Unpaid Invoices'**
  String get unpaidInvoices;

  /// No description provided for @viewAllPayments.
  ///
  /// In en, this message translates to:
  /// **'View All Payments'**
  String get viewAllPayments;

  /// No description provided for @viewAllPaymentsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'View All Payments Subtitle'**
  String get viewAllPaymentsSubtitle;

  /// No description provided for @viewAndPayInvoices.
  ///
  /// In en, this message translates to:
  /// **'View And Pay Invoices'**
  String get viewAndPayInvoices;

  /// No description provided for @viewInvoices.
  ///
  /// In en, this message translates to:
  /// **'View Invoices'**
  String get viewInvoices;

  /// No description provided for @viewOnMap.
  ///
  /// In en, this message translates to:
  /// **'View On Map'**
  String get viewOnMap;

  /// No description provided for @viewPaymentHistory.
  ///
  /// In en, this message translates to:
  /// **'View Payment History'**
  String get viewPaymentHistory;

  /// No description provided for @viewReceipt.
  ///
  /// In en, this message translates to:
  /// **'View Receipt'**
  String get viewReceipt;

  /// No description provided for @waitingForStkPush.
  ///
  /// In en, this message translates to:
  /// **'Waiting For Stk Push'**
  String get waitingForStkPush;

  /// No description provided for @welcomeGuest.
  ///
  /// In en, this message translates to:
  /// **'Welcome to GetKeja'**
  String get welcomeGuest;

  /// No description provided for @yourTenancy.
  ///
  /// In en, this message translates to:
  /// **'Your Tenancy'**
  String get yourTenancy;

  /// No description provided for @providerOpen.
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get providerOpen;

  /// No description provided for @providerClose.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get providerClose;

  /// No description provided for @providerDeleted.
  ///
  /// In en, this message translates to:
  /// **'Deleted'**
  String get providerDeleted;

  /// No description provided for @compareSelectedCount.
  ///
  /// In en, this message translates to:
  /// **'{count} of {max} properties selected'**
  String compareSelectedCount(int count, int max);

  /// No description provided for @compareSavedAll.
  ///
  /// In en, this message translates to:
  /// **'Saved {count} homes'**
  String compareSavedAll(int count);

  /// No description provided for @welcomeBack.
  ///
  /// In en, this message translates to:
  /// **'Welcome back, {name}'**
  String welcomeBack(String name);

  /// No description provided for @couldNotSaveSearch.
  ///
  /// In en, this message translates to:
  /// **'Could not save search: {error}'**
  String couldNotSaveSearch(String error);

  /// No description provided for @homesFoundCount.
  ///
  /// In en, this message translates to:
  /// **'{count} homes found'**
  String homesFoundCount(int count);
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
      <String>['en', 'sw'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'sw':
      return AppLocalizationsSw();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
