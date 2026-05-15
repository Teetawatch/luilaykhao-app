import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_th.dart';

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

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
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
    Locale('th'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In th, this message translates to:
  /// **'ลุยเลเขา'**
  String get appTitle;

  /// No description provided for @tabHome.
  ///
  /// In th, this message translates to:
  /// **'หน้าหลัก'**
  String get tabHome;

  /// No description provided for @tabTrips.
  ///
  /// In th, this message translates to:
  /// **'ทริป'**
  String get tabTrips;

  /// No description provided for @tabBookings.
  ///
  /// In th, this message translates to:
  /// **'การจอง'**
  String get tabBookings;

  /// No description provided for @tabProfile.
  ///
  /// In th, this message translates to:
  /// **'โปรไฟล์'**
  String get tabProfile;

  /// No description provided for @tabStaffCheckIn.
  ///
  /// In th, this message translates to:
  /// **'เช็คอิน'**
  String get tabStaffCheckIn;

  /// No description provided for @commonCancel.
  ///
  /// In th, this message translates to:
  /// **'ยกเลิก'**
  String get commonCancel;

  /// No description provided for @commonConfirm.
  ///
  /// In th, this message translates to:
  /// **'ยืนยัน'**
  String get commonConfirm;

  /// No description provided for @commonClose.
  ///
  /// In th, this message translates to:
  /// **'ปิด'**
  String get commonClose;

  /// No description provided for @commonContinue.
  ///
  /// In th, this message translates to:
  /// **'ต่อไป'**
  String get commonContinue;

  /// No description provided for @commonRetry.
  ///
  /// In th, this message translates to:
  /// **'ลองอีกครั้ง'**
  String get commonRetry;

  /// No description provided for @commonSave.
  ///
  /// In th, this message translates to:
  /// **'บันทึก'**
  String get commonSave;

  /// No description provided for @commonShare.
  ///
  /// In th, this message translates to:
  /// **'แชร์'**
  String get commonShare;

  /// No description provided for @commonSearch.
  ///
  /// In th, this message translates to:
  /// **'ค้นหา'**
  String get commonSearch;

  /// No description provided for @commonLoading.
  ///
  /// In th, this message translates to:
  /// **'กำลังโหลด…'**
  String get commonLoading;

  /// No description provided for @authLogin.
  ///
  /// In th, this message translates to:
  /// **'เข้าสู่ระบบ'**
  String get authLogin;

  /// No description provided for @authRegister.
  ///
  /// In th, this message translates to:
  /// **'สมัครสมาชิก'**
  String get authRegister;

  /// No description provided for @authLogout.
  ///
  /// In th, this message translates to:
  /// **'ออกจากระบบ'**
  String get authLogout;

  /// No description provided for @sessionExpired.
  ///
  /// In th, this message translates to:
  /// **'เซสชันหมดอายุ กรุณาเข้าสู่ระบบใหม่'**
  String get sessionExpired;

  /// No description provided for @offlineBanner.
  ///
  /// In th, this message translates to:
  /// **'ออฟไลน์อยู่ ข้อมูลบางส่วนอาจไม่อัปเดต'**
  String get offlineBanner;

  /// No description provided for @biometricUnlockTitle.
  ///
  /// In th, this message translates to:
  /// **'ปลดล็อกแอป'**
  String get biometricUnlockTitle;

  /// No description provided for @biometricUnlockHint.
  ///
  /// In th, this message translates to:
  /// **'ใช้ลายนิ้วมือหรือใบหน้าของคุณเพื่อเข้าใช้งาน'**
  String get biometricUnlockHint;

  /// No description provided for @biometricUnlockButton.
  ///
  /// In th, this message translates to:
  /// **'ยืนยันตัวตน'**
  String get biometricUnlockButton;

  /// No description provided for @biometricUseOtherAccount.
  ///
  /// In th, this message translates to:
  /// **'ใช้บัญชีอื่น'**
  String get biometricUseOtherAccount;

  /// No description provided for @forceUpdateTitle.
  ///
  /// In th, this message translates to:
  /// **'มีเวอร์ชันใหม่'**
  String get forceUpdateTitle;

  /// No description provided for @forceUpdateButton.
  ///
  /// In th, this message translates to:
  /// **'อัปเดตทันที'**
  String get forceUpdateButton;

  /// No description provided for @wishlistTitle.
  ///
  /// In th, this message translates to:
  /// **'ทริปที่ชอบ'**
  String get wishlistTitle;

  /// No description provided for @wishlistEmpty.
  ///
  /// In th, this message translates to:
  /// **'ยังไม่มีทริปที่บันทึกไว้'**
  String get wishlistEmpty;

  /// No description provided for @wishlistEmptyHint.
  ///
  /// In th, this message translates to:
  /// **'เมื่อเจอทริปที่สนใจ กดรูปหัวใจเพื่อบันทึกไว้ดูอีกครั้งภายหลัง'**
  String get wishlistEmptyHint;

  /// No description provided for @refundStatusTitle.
  ///
  /// In th, this message translates to:
  /// **'สถานะการคืนเงิน'**
  String get refundStatusTitle;

  /// No description provided for @refundStatusCompleted.
  ///
  /// In th, this message translates to:
  /// **'คืนเงินสำเร็จ'**
  String get refundStatusCompleted;

  /// No description provided for @refundStatusProcessing.
  ///
  /// In th, this message translates to:
  /// **'กำลังดำเนินการ'**
  String get refundStatusProcessing;

  /// No description provided for @refundStatusRejected.
  ///
  /// In th, this message translates to:
  /// **'ไม่อนุมัติ'**
  String get refundStatusRejected;

  /// No description provided for @refundStatusPending.
  ///
  /// In th, this message translates to:
  /// **'รอดำเนินการ'**
  String get refundStatusPending;

  /// No description provided for @reviewDialogTitle.
  ///
  /// In th, this message translates to:
  /// **'รีวิวทริปนี้'**
  String get reviewDialogTitle;

  /// No description provided for @reviewDialogHint.
  ///
  /// In th, this message translates to:
  /// **'เล่าประสบการณ์ของคุณ…'**
  String get reviewDialogHint;

  /// No description provided for @reviewDialogSubmit.
  ///
  /// In th, this message translates to:
  /// **'ส่งรีวิว'**
  String get reviewDialogSubmit;

  /// No description provided for @supportShortcutsTitle.
  ///
  /// In th, this message translates to:
  /// **'ติดต่อด่วน'**
  String get supportShortcutsTitle;

  /// No description provided for @supportShortcutsSubtitle.
  ///
  /// In th, this message translates to:
  /// **'เลือกช่องทางที่สะดวกที่สุด ทีมงานพร้อมตอบทุกวัน 08:00–22:00'**
  String get supportShortcutsSubtitle;

  /// No description provided for @supportShortcutLine.
  ///
  /// In th, this message translates to:
  /// **'LINE Official'**
  String get supportShortcutLine;

  /// No description provided for @supportShortcutCall.
  ///
  /// In th, this message translates to:
  /// **'โทรหาเรา'**
  String get supportShortcutCall;

  /// No description provided for @supportShortcutEmail.
  ///
  /// In th, this message translates to:
  /// **'อีเมล'**
  String get supportShortcutEmail;

  /// No description provided for @notificationPrefsTitle.
  ///
  /// In th, this message translates to:
  /// **'การแจ้งเตือน'**
  String get notificationPrefsTitle;

  /// No description provided for @notificationPrefsBooking.
  ///
  /// In th, this message translates to:
  /// **'การจอง'**
  String get notificationPrefsBooking;

  /// No description provided for @notificationPrefsPayment.
  ///
  /// In th, this message translates to:
  /// **'การชำระเงิน'**
  String get notificationPrefsPayment;

  /// No description provided for @notificationPrefsPromotion.
  ///
  /// In th, this message translates to:
  /// **'โปรโมชั่นและข่าวสาร'**
  String get notificationPrefsPromotion;

  /// No description provided for @notificationPrefsReminder.
  ///
  /// In th, this message translates to:
  /// **'เตือนก่อนเดินทาง'**
  String get notificationPrefsReminder;

  /// No description provided for @notificationPrefsTracking.
  ///
  /// In th, this message translates to:
  /// **'ติดตามรถ'**
  String get notificationPrefsTracking;

  /// No description provided for @onboardingNext.
  ///
  /// In th, this message translates to:
  /// **'ถัดไป'**
  String get onboardingNext;

  /// No description provided for @onboardingSkip.
  ///
  /// In th, this message translates to:
  /// **'ข้าม'**
  String get onboardingSkip;

  /// No description provided for @onboardingStart.
  ///
  /// In th, this message translates to:
  /// **'เริ่มใช้งาน'**
  String get onboardingStart;

  /// No description provided for @settingsLanguage.
  ///
  /// In th, this message translates to:
  /// **'ภาษา'**
  String get settingsLanguage;

  /// No description provided for @settingsTheme.
  ///
  /// In th, this message translates to:
  /// **'ธีมมืด'**
  String get settingsTheme;

  /// No description provided for @settingsBiometric.
  ///
  /// In th, this message translates to:
  /// **'ปลดล็อกด้วยลายนิ้วมือ'**
  String get settingsBiometric;

  /// No description provided for @languageThai.
  ///
  /// In th, this message translates to:
  /// **'ภาษาไทย'**
  String get languageThai;

  /// No description provided for @languageEnglish.
  ///
  /// In th, this message translates to:
  /// **'English'**
  String get languageEnglish;
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
      <String>['en', 'th'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'th':
      return AppLocalizationsTh();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
