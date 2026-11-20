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
  /// **'Notification channels'**
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
  /// **'Name, email, phone number'**
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
  /// **'English (US) - 1,234.56'**
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
