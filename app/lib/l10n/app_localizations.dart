import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_ja.dart';
import 'app_localizations_vi.dart';
import 'app_localizations_zh.dart';

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
    Locale('vi'),
    Locale('en'),
    Locale('zh'),
    Locale('ja'),
  ];

  /// No description provided for @loginAccountType.
  ///
  /// In vi, this message translates to:
  /// **'Loại tài khoản'**
  String get loginAccountType;

  /// No description provided for @loginAccountTypeHint.
  ///
  /// In vi, this message translates to:
  /// **'Chọn loại tài khoản đăng nhập'**
  String get loginAccountTypeHint;

  /// No description provided for @loginAccountTypeRequired.
  ///
  /// In vi, this message translates to:
  /// **'Vui lòng chọn loại tài khoản đăng nhập'**
  String get loginAccountTypeRequired;

  /// No description provided for @loginAccountTypeMismatch.
  ///
  /// In vi, this message translates to:
  /// **'Tài khoản chưa có quyền sử dụng vai trò này. Vui lòng chọn lại loại tài khoản hoặc liên hệ quản trị viên.'**
  String get loginAccountTypeMismatch;

  /// No description provided for @loginAccountPickerHelp.
  ///
  /// In vi, this message translates to:
  /// **'Chọn vai trò bạn muốn sử dụng. Tài khoản cần được cấp quyền tương ứng để đăng nhập.'**
  String get loginAccountPickerHelp;

  /// No description provided for @loginAccountPickerClose.
  ///
  /// In vi, this message translates to:
  /// **'Đóng lựa chọn tài khoản'**
  String get loginAccountPickerClose;

  /// No description provided for @loginRoleCustomer.
  ///
  /// In vi, this message translates to:
  /// **'Người tìm nhà'**
  String get loginRoleCustomer;

  /// No description provided for @loginRoleCustomerDescription.
  ///
  /// In vi, this message translates to:
  /// **'Tìm mua, thuê nhà và theo dõi lịch hẹn của bạn.'**
  String get loginRoleCustomerDescription;

  /// No description provided for @loginRoleSale.
  ///
  /// In vi, this message translates to:
  /// **'Sale / Môi giới'**
  String get loginRoleSale;

  /// No description provided for @loginRoleSaleDescription.
  ///
  /// In vi, this message translates to:
  /// **'Quản lý khách hàng, tin đăng và giao dịch.'**
  String get loginRoleSaleDescription;

  /// No description provided for @loginRoleOwner.
  ///
  /// In vi, this message translates to:
  /// **'Chủ nhà'**
  String get loginRoleOwner;

  /// No description provided for @loginRoleOwnerDescription.
  ///
  /// In vi, this message translates to:
  /// **'Quản lý tài sản, phòng và khách thuê.'**
  String get loginRoleOwnerDescription;

  /// No description provided for @loginRoleAdmin.
  ///
  /// In vi, this message translates to:
  /// **'Quản trị viên'**
  String get loginRoleAdmin;

  /// No description provided for @loginRoleAdminDescription.
  ///
  /// In vi, this message translates to:
  /// **'Dành cho tài khoản được cấp quyền quản trị hệ thống.'**
  String get loginRoleAdminDescription;

  /// No description provided for @loginGuestBrowse.
  ///
  /// In vi, this message translates to:
  /// **'Tiếp tục không đăng nhập'**
  String get loginGuestBrowse;

  /// No description provided for @appTitle.
  ///
  /// In vi, this message translates to:
  /// **'Vua Nhà'**
  String get appTitle;

  /// No description provided for @settingsTitle.
  ///
  /// In vi, this message translates to:
  /// **'Cài đặt & quyền riêng tư'**
  String get settingsTitle;

  /// No description provided for @settingsEyebrow.
  ///
  /// In vi, this message translates to:
  /// **'Tài khoản'**
  String get settingsEyebrow;

  /// No description provided for @sectionAccount.
  ///
  /// In vi, this message translates to:
  /// **'Tài khoản'**
  String get sectionAccount;

  /// No description provided for @editProfile.
  ///
  /// In vi, this message translates to:
  /// **'Chỉnh sửa hồ sơ'**
  String get editProfile;

  /// No description provided for @editProfileSub.
  ///
  /// In vi, this message translates to:
  /// **'Tên, ảnh, số điện thoại'**
  String get editProfileSub;

  /// No description provided for @changePassword.
  ///
  /// In vi, this message translates to:
  /// **'Đổi mật khẩu'**
  String get changePassword;

  /// No description provided for @sectionPreferences.
  ///
  /// In vi, this message translates to:
  /// **'Tuỳ chọn'**
  String get sectionPreferences;

  /// No description provided for @language.
  ///
  /// In vi, this message translates to:
  /// **'Ngôn ngữ'**
  String get language;

  /// No description provided for @chooseLanguage.
  ///
  /// In vi, this message translates to:
  /// **'Chọn ngôn ngữ'**
  String get chooseLanguage;

  /// No description provided for @notifications.
  ///
  /// In vi, this message translates to:
  /// **'Thông báo'**
  String get notifications;

  /// No description provided for @darkMode.
  ///
  /// In vi, this message translates to:
  /// **'Chế độ tối'**
  String get darkMode;

  /// No description provided for @comingSoon.
  ///
  /// In vi, this message translates to:
  /// **'Sắp ra mắt'**
  String get comingSoon;

  /// No description provided for @logout.
  ///
  /// In vi, this message translates to:
  /// **'Đăng xuất'**
  String get logout;

  /// No description provided for @daTitle.
  ///
  /// In vi, this message translates to:
  /// **'Xoá tài khoản'**
  String get daTitle;

  /// No description provided for @daSubtitle.
  ///
  /// In vi, this message translates to:
  /// **'Xoá vĩnh viễn tài khoản và dữ liệu cá nhân'**
  String get daSubtitle;

  /// No description provided for @daDialogTitle.
  ///
  /// In vi, this message translates to:
  /// **'Xoá tài khoản?'**
  String get daDialogTitle;

  /// No description provided for @daDialogBody.
  ///
  /// In vi, this message translates to:
  /// **'Hành động này KHÔNG thể hoàn tác. Toàn bộ thông tin cá nhân của bạn sẽ bị xoá và bạn sẽ không thể đăng nhập lại. Nhập mật khẩu để xác nhận.'**
  String get daDialogBody;

  /// No description provided for @daPasswordHint.
  ///
  /// In vi, this message translates to:
  /// **'Mật khẩu hiện tại'**
  String get daPasswordHint;

  /// No description provided for @daPasswordRequired.
  ///
  /// In vi, this message translates to:
  /// **'Nhập mật khẩu để xác nhận'**
  String get daPasswordRequired;

  /// No description provided for @daConfirm.
  ///
  /// In vi, this message translates to:
  /// **'Xoá tài khoản'**
  String get daConfirm;

  /// No description provided for @daSuccess.
  ///
  /// In vi, this message translates to:
  /// **'Tài khoản đã được xoá'**
  String get daSuccess;

  /// No description provided for @daFailed.
  ///
  /// In vi, this message translates to:
  /// **'Xoá tài khoản thất bại'**
  String get daFailed;

  /// No description provided for @blockUser.
  ///
  /// In vi, this message translates to:
  /// **'Chặn người này'**
  String get blockUser;

  /// No description provided for @blockUserSub.
  ///
  /// In vi, this message translates to:
  /// **'Bạn sẽ không còn thấy nội dung của họ'**
  String get blockUserSub;

  /// No description provided for @blockConfirmTitle.
  ///
  /// In vi, this message translates to:
  /// **'Chặn người này?'**
  String get blockConfirmTitle;

  /// No description provided for @blockConfirmBody.
  ///
  /// In vi, this message translates to:
  /// **'Bạn sẽ không còn thấy bài đăng, video và bình luận của họ. Có thể bỏ chặn trong Cài đặt.'**
  String get blockConfirmBody;

  /// No description provided for @blockAction.
  ///
  /// In vi, this message translates to:
  /// **'Chặn'**
  String get blockAction;

  /// No description provided for @blockDone.
  ///
  /// In vi, this message translates to:
  /// **'Đã chặn người dùng'**
  String get blockDone;

  /// No description provided for @blockFailed.
  ///
  /// In vi, this message translates to:
  /// **'Không chặn được, thử lại sau'**
  String get blockFailed;

  /// No description provided for @unblock.
  ///
  /// In vi, this message translates to:
  /// **'Bỏ chặn'**
  String get unblock;

  /// No description provided for @unblockDone.
  ///
  /// In vi, this message translates to:
  /// **'Đã bỏ chặn'**
  String get unblockDone;

  /// No description provided for @blockedUsersTitle.
  ///
  /// In vi, this message translates to:
  /// **'Người đã chặn'**
  String get blockedUsersTitle;

  /// No description provided for @blockedUsersSub.
  ///
  /// In vi, this message translates to:
  /// **'Quản lý danh sách người bạn đã chặn'**
  String get blockedUsersSub;

  /// No description provided for @blockedEmpty.
  ///
  /// In vi, this message translates to:
  /// **'Bạn chưa chặn ai'**
  String get blockedEmpty;

  /// No description provided for @reportComment.
  ///
  /// In vi, this message translates to:
  /// **'Báo cáo bình luận'**
  String get reportComment;

  /// No description provided for @actionsNounComment.
  ///
  /// In vi, this message translates to:
  /// **'bình luận'**
  String get actionsNounComment;

  /// No description provided for @privacyPolicy.
  ///
  /// In vi, this message translates to:
  /// **'Chính sách quyền riêng tư'**
  String get privacyPolicy;

  /// No description provided for @termsOfUse.
  ///
  /// In vi, this message translates to:
  /// **'Điều khoản sử dụng'**
  String get termsOfUse;

  /// No description provided for @sectionLegal.
  ///
  /// In vi, this message translates to:
  /// **'Pháp lý'**
  String get sectionLegal;

  /// No description provided for @logoutConfirm.
  ///
  /// In vi, this message translates to:
  /// **'Bạn chắc chắn muốn đăng xuất?'**
  String get logoutConfirm;

  /// No description provided for @loggedOut.
  ///
  /// In vi, this message translates to:
  /// **'Đã đăng xuất'**
  String get loggedOut;

  /// No description provided for @cancel.
  ///
  /// In vi, this message translates to:
  /// **'Hủy'**
  String get cancel;

  /// No description provided for @vietnamese.
  ///
  /// In vi, this message translates to:
  /// **'Tiếng Việt'**
  String get vietnamese;

  /// No description provided for @english.
  ///
  /// In vi, this message translates to:
  /// **'Tiếng Anh'**
  String get english;

  /// No description provided for @chinese.
  ///
  /// In vi, this message translates to:
  /// **'Tiếng Trung'**
  String get chinese;

  /// No description provided for @loginEyebrow.
  ///
  /// In vi, this message translates to:
  /// **'THUÊ NHÀ NHANH · MINH BẠCH'**
  String get loginEyebrow;

  /// No description provided for @loginTagline.
  ///
  /// In vi, this message translates to:
  /// **'Tìm, thuê và cho thuê nhà — dễ dàng, minh bạch.'**
  String get loginTagline;

  /// No description provided for @loginEmail.
  ///
  /// In vi, this message translates to:
  /// **'Email'**
  String get loginEmail;

  /// No description provided for @loginPassword.
  ///
  /// In vi, this message translates to:
  /// **'Mật khẩu'**
  String get loginPassword;

  /// No description provided for @loginForgot.
  ///
  /// In vi, this message translates to:
  /// **'Quên mật khẩu?'**
  String get loginForgot;

  /// No description provided for @loginButton.
  ///
  /// In vi, this message translates to:
  /// **'Đăng nhập'**
  String get loginButton;

  /// No description provided for @loginFailed.
  ///
  /// In vi, this message translates to:
  /// **'Đăng nhập thất bại'**
  String get loginFailed;

  /// No description provided for @loginExitHome.
  ///
  /// In vi, this message translates to:
  /// **'Về trang chủ'**
  String get loginExitHome;

  /// No description provided for @loginOr.
  ///
  /// In vi, this message translates to:
  /// **'hoặc'**
  String get loginOr;

  /// No description provided for @loginNoAccount.
  ///
  /// In vi, this message translates to:
  /// **'Chưa có tài khoản? '**
  String get loginNoAccount;

  /// No description provided for @loginRegisterNow.
  ///
  /// In vi, this message translates to:
  /// **'Đăng ký ngay'**
  String get loginRegisterNow;

  /// No description provided for @loginDemoAccounts.
  ///
  /// In vi, this message translates to:
  /// **'Tài khoản demo'**
  String get loginDemoAccounts;

  /// No description provided for @demoTenant.
  ///
  /// In vi, this message translates to:
  /// **'Khách thuê'**
  String get demoTenant;

  /// No description provided for @demoHost.
  ///
  /// In vi, this message translates to:
  /// **'Chủ nhà'**
  String get demoHost;

  /// No description provided for @demoAdmin.
  ///
  /// In vi, this message translates to:
  /// **'Quản trị'**
  String get demoAdmin;

  /// No description provided for @valEmailRequired.
  ///
  /// In vi, this message translates to:
  /// **'Nhập email của bạn'**
  String get valEmailRequired;

  /// No description provided for @valEmailInvalid.
  ///
  /// In vi, this message translates to:
  /// **'Email chưa đúng định dạng'**
  String get valEmailInvalid;

  /// No description provided for @valPasswordRequired.
  ///
  /// In vi, this message translates to:
  /// **'Nhập mật khẩu'**
  String get valPasswordRequired;

  /// No description provided for @loginContinueGoogle.
  ///
  /// In vi, this message translates to:
  /// **'Tiếp tục với Google'**
  String get loginContinueGoogle;

  /// No description provided for @loginContinueFacebook.
  ///
  /// In vi, this message translates to:
  /// **'Tiếp tục với Facebook'**
  String get loginContinueFacebook;

  /// No description provided for @loginOauthMaintenance.
  ///
  /// In vi, this message translates to:
  /// **'Đăng nhập {provider} đang bảo trì. Vui lòng thử lại sau.'**
  String loginOauthMaintenance(String provider);

  /// No description provided for @demoDesigner.
  ///
  /// In vi, this message translates to:
  /// **'ĐV Thiết kế'**
  String get demoDesigner;

  /// No description provided for @demoBuilder.
  ///
  /// In vi, this message translates to:
  /// **'ĐV Xây dựng'**
  String get demoBuilder;

  /// No description provided for @demoInterior.
  ///
  /// In vi, this message translates to:
  /// **'ĐV Nội thất'**
  String get demoInterior;

  /// No description provided for @emailHint.
  ///
  /// In vi, this message translates to:
  /// **'ban@vidu.com'**
  String get emailHint;

  /// No description provided for @passwordHint.
  ///
  /// In vi, this message translates to:
  /// **'Ít nhất 6 ký tự'**
  String get passwordHint;

  /// No description provided for @registerEyebrow.
  ///
  /// In vi, this message translates to:
  /// **'Đăng ký'**
  String get registerEyebrow;

  /// No description provided for @registerTitle.
  ///
  /// In vi, this message translates to:
  /// **'Tạo tài khoản'**
  String get registerTitle;

  /// No description provided for @registerWelcome.
  ///
  /// In vi, this message translates to:
  /// **'Chào mừng đến với'**
  String get registerWelcome;

  /// No description provided for @registerSubtitle.
  ///
  /// In vi, this message translates to:
  /// **'Tạo tài khoản miễn phí để bắt đầu tìm và đăng phòng.'**
  String get registerSubtitle;

  /// No description provided for @registerName.
  ///
  /// In vi, this message translates to:
  /// **'Họ và tên'**
  String get registerName;

  /// No description provided for @registerPhoneOptional.
  ///
  /// In vi, this message translates to:
  /// **'Số điện thoại (tuỳ chọn)'**
  String get registerPhoneOptional;

  /// No description provided for @registerConfirmPassword.
  ///
  /// In vi, this message translates to:
  /// **'Xác nhận mật khẩu'**
  String get registerConfirmPassword;

  /// No description provided for @registerAgreeTerms.
  ///
  /// In vi, this message translates to:
  /// **'Tôi đồng ý với Điều khoản & Chính sách bảo mật'**
  String get registerAgreeTerms;

  /// No description provided for @registerNeedAgree.
  ///
  /// In vi, this message translates to:
  /// **'Bạn cần đồng ý với Điều khoản sử dụng'**
  String get registerNeedAgree;

  /// No description provided for @registerFailed.
  ///
  /// In vi, this message translates to:
  /// **'Đăng ký thất bại'**
  String get registerFailed;

  /// No description provided for @registerHaveAccount.
  ///
  /// In vi, this message translates to:
  /// **'Đã có tài khoản? '**
  String get registerHaveAccount;

  /// No description provided for @valRequired.
  ///
  /// In vi, this message translates to:
  /// **'Bắt buộc'**
  String get valRequired;

  /// No description provided for @valPasswordMin.
  ///
  /// In vi, this message translates to:
  /// **'Tối thiểu 6 ký tự'**
  String get valPasswordMin;

  /// No description provided for @valPasswordMismatch.
  ///
  /// In vi, this message translates to:
  /// **'Mật khẩu không khớp'**
  String get valPasswordMismatch;

  /// No description provided for @svcRealEstate.
  ///
  /// In vi, this message translates to:
  /// **'BẤT ĐỘNG SẢN'**
  String get svcRealEstate;

  /// No description provided for @svcRental.
  ///
  /// In vi, this message translates to:
  /// **'Nhà cho thuê'**
  String get svcRental;

  /// No description provided for @svcIndustrial.
  ///
  /// In vi, this message translates to:
  /// **'BĐS công nghiệp'**
  String get svcIndustrial;

  /// No description provided for @svcMap.
  ///
  /// In vi, this message translates to:
  /// **'Bản đồ'**
  String get svcMap;

  /// No description provided for @svcConstruction.
  ///
  /// In vi, this message translates to:
  /// **'XÂY DỰNG'**
  String get svcConstruction;

  /// No description provided for @svcNew.
  ///
  /// In vi, this message translates to:
  /// **'MỚI'**
  String get svcNew;

  /// No description provided for @svcDesign.
  ///
  /// In vi, this message translates to:
  /// **'Thiết kế'**
  String get svcDesign;

  /// No description provided for @svcBuild.
  ///
  /// In vi, this message translates to:
  /// **'Xây dựng'**
  String get svcBuild;

  /// No description provided for @svcInterior.
  ///
  /// In vi, this message translates to:
  /// **'Nội thất'**
  String get svcInterior;

  /// No description provided for @svcCommunityTitle.
  ///
  /// In vi, this message translates to:
  /// **'Cộng đồng bất động sản'**
  String get svcCommunityTitle;

  /// No description provided for @svcCommunitySubtitle.
  ///
  /// In vi, this message translates to:
  /// **'Hỏi đáp, review khu vực, tìm bạn ở ghép…'**
  String get svcCommunitySubtitle;

  /// No description provided for @svcLeaderboardTitle.
  ///
  /// In vi, this message translates to:
  /// **'Bảng xếp hạng đối tác'**
  String get svcLeaderboardTitle;

  /// No description provided for @svcLeaderboardSubtitle.
  ///
  /// In vi, this message translates to:
  /// **'Xếp hạng theo ngành: thiết kế, xây dựng, nội thất…'**
  String get svcLeaderboardSubtitle;

  /// No description provided for @shellLoginToPostHouse.
  ///
  /// In vi, this message translates to:
  /// **'Đăng nhập để đăng tin cho thuê nhà của bạn.'**
  String get shellLoginToPostHouse;

  /// No description provided for @shellBecomeHostTitle.
  ///
  /// In vi, this message translates to:
  /// **'Trở thành chủ nhà'**
  String get shellBecomeHostTitle;

  /// No description provided for @shellBecomeHostBody.
  ///
  /// In vi, this message translates to:
  /// **'Bạn sẽ đăng tin đầu tiên và tự động nâng cấp lên chủ nhà. Tiếp tục?'**
  String get shellBecomeHostBody;

  /// No description provided for @shellContinue.
  ///
  /// In vi, this message translates to:
  /// **'Tiếp tục'**
  String get shellContinue;

  /// No description provided for @shellLoginToPostConstruction.
  ///
  /// In vi, this message translates to:
  /// **'Đăng nhập để đăng bài xây dựng.'**
  String get shellLoginToPostConstruction;

  /// No description provided for @shellPostRequest.
  ///
  /// In vi, this message translates to:
  /// **'Đăng yêu cầu'**
  String get shellPostRequest;

  /// No description provided for @shellPostListing.
  ///
  /// In vi, this message translates to:
  /// **'Đăng tin'**
  String get shellPostListing;

  /// No description provided for @shellNavRealEstate.
  ///
  /// In vi, this message translates to:
  /// **'Tin tức'**
  String get shellNavRealEstate;

  /// No description provided for @shellNavConstruction.
  ///
  /// In vi, this message translates to:
  /// **'Xây dựng'**
  String get shellNavConstruction;

  /// No description provided for @shellNavWishlist.
  ///
  /// In vi, this message translates to:
  /// **'Yêu thích'**
  String get shellNavWishlist;

  /// No description provided for @shellNavProfile.
  ///
  /// In vi, this message translates to:
  /// **'Cá nhân'**
  String get shellNavProfile;

  /// No description provided for @shellNavOverview.
  ///
  /// In vi, this message translates to:
  /// **'Tổng quan'**
  String get shellNavOverview;

  /// No description provided for @shellNavRooms.
  ///
  /// In vi, this message translates to:
  /// **'Nhà trọ'**
  String get shellNavRooms;

  /// No description provided for @shellNavRequests.
  ///
  /// In vi, this message translates to:
  /// **'Yêu cầu'**
  String get shellNavRequests;

  /// No description provided for @shellHostBuildingsHeader.
  ///
  /// In vi, this message translates to:
  /// **'NHÀ TRỌ · SỔ TÒA'**
  String get shellHostBuildingsHeader;

  /// No description provided for @drawerCommonSection.
  ///
  /// In vi, this message translates to:
  /// **'DÙNG CHUNG'**
  String get drawerCommonSection;

  /// No description provided for @hubCommonSection.
  ///
  /// In vi, this message translates to:
  /// **'CHUNG'**
  String get hubCommonSection;

  /// No description provided for @drawerMessages.
  ///
  /// In vi, this message translates to:
  /// **'Tin nhắn'**
  String get drawerMessages;

  /// No description provided for @drawerSystemAdmin.
  ///
  /// In vi, this message translates to:
  /// **'Quản trị hệ thống'**
  String get drawerSystemAdmin;

  /// No description provided for @drawerHelp.
  ///
  /// In vi, this message translates to:
  /// **'Trợ giúp'**
  String get drawerHelp;

  /// No description provided for @drawerAbout.
  ///
  /// In vi, this message translates to:
  /// **'Về ứng dụng'**
  String get drawerAbout;

  /// No description provided for @drawerRealEstateSection.
  ///
  /// In vi, this message translates to:
  /// **'BẤT ĐỘNG SẢN'**
  String get drawerRealEstateSection;

  /// No description provided for @drawerMapPlanning.
  ///
  /// In vi, this message translates to:
  /// **'Bản đồ nhà & quy hoạch'**
  String get drawerMapPlanning;

  /// No description provided for @drawerHousesForRent.
  ///
  /// In vi, this message translates to:
  /// **'Nhà cho thuê'**
  String get drawerHousesForRent;

  /// No description provided for @drawerIndustrialRealEstate.
  ///
  /// In vi, this message translates to:
  /// **'BĐS công nghiệp'**
  String get drawerIndustrialRealEstate;

  /// No description provided for @drawerPostBusinessSection.
  ///
  /// In vi, this message translates to:
  /// **'ĐĂNG & KINH DOANH'**
  String get drawerPostBusinessSection;

  /// No description provided for @drawerConstructionBusinessSection.
  ///
  /// In vi, this message translates to:
  /// **'Đăng yêu cầu & báo giá'**
  String get drawerConstructionBusinessSection;

  /// No description provided for @drawerPostRental.
  ///
  /// In vi, this message translates to:
  /// **'Đăng tin cho thuê'**
  String get drawerPostRental;

  /// No description provided for @drawerBecomeHost.
  ///
  /// In vi, this message translates to:
  /// **'Trở thành chủ nhà'**
  String get drawerBecomeHost;

  /// No description provided for @drawerConstructionSection.
  ///
  /// In vi, this message translates to:
  /// **'XÂY DỰNG'**
  String get drawerConstructionSection;

  /// No description provided for @drawerContractorDirectory.
  ///
  /// In vi, this message translates to:
  /// **'Danh bạ nhà thầu'**
  String get drawerContractorDirectory;

  /// No description provided for @drawerDesignLibrary.
  ///
  /// In vi, this message translates to:
  /// **'Thư viện thiết kế'**
  String get drawerDesignLibrary;

  /// No description provided for @drawerPartnerLeaderboard.
  ///
  /// In vi, this message translates to:
  /// **'Bảng xếp hạng đối tác'**
  String get drawerPartnerLeaderboard;

  /// No description provided for @drawerPostConstructionRequest.
  ///
  /// In vi, this message translates to:
  /// **'Đăng yêu cầu xây dựng'**
  String get drawerPostConstructionRequest;

  /// No description provided for @drawerContractorChannel.
  ///
  /// In vi, this message translates to:
  /// **'Kênh đơn vị xây dựng'**
  String get drawerContractorChannel;

  /// No description provided for @drawerTagline.
  ///
  /// In vi, this message translates to:
  /// **'Bất động sản & Xây dựng'**
  String get drawerTagline;

  /// No description provided for @drawerViewProfile.
  ///
  /// In vi, this message translates to:
  /// **'Xem hồ sơ'**
  String get drawerViewProfile;

  /// No description provided for @drawerLoginPrompt.
  ///
  /// In vi, this message translates to:
  /// **'Đăng nhập để lưu tin, nhắn tin và đăng bài.'**
  String get drawerLoginPrompt;

  /// No description provided for @drawerLoginRegister.
  ///
  /// In vi, this message translates to:
  /// **'Đăng nhập / Đăng ký'**
  String get drawerLoginRegister;

  /// No description provided for @actionsNounHouse.
  ///
  /// In vi, this message translates to:
  /// **'tin đăng'**
  String get actionsNounHouse;

  /// No description provided for @actionsNounPost.
  ///
  /// In vi, this message translates to:
  /// **'bài viết'**
  String get actionsNounPost;

  /// No description provided for @actionsUnsave.
  ///
  /// In vi, this message translates to:
  /// **'Bỏ lưu'**
  String get actionsUnsave;

  /// No description provided for @actionsSaveNoun.
  ///
  /// In vi, this message translates to:
  /// **'Lưu {noun}'**
  String actionsSaveNoun(Object noun);

  /// No description provided for @actionsSaveSub.
  ///
  /// In vi, this message translates to:
  /// **'Xem lại sau trong mục đã lưu'**
  String get actionsSaveSub;

  /// No description provided for @actionsLoginToSave.
  ///
  /// In vi, this message translates to:
  /// **'Đăng nhập để lưu {noun}.'**
  String actionsLoginToSave(Object noun);

  /// No description provided for @actionsEdit.
  ///
  /// In vi, this message translates to:
  /// **'Chỉnh sửa'**
  String get actionsEdit;

  /// No description provided for @actionsDelete.
  ///
  /// In vi, this message translates to:
  /// **'Xoá'**
  String get actionsDelete;

  /// No description provided for @actionsReportWrongInfo.
  ///
  /// In vi, this message translates to:
  /// **'Báo sai thông tin'**
  String get actionsReportWrongInfo;

  /// No description provided for @actionsReportWrongInfoSub.
  ///
  /// In vi, this message translates to:
  /// **'Gửi cho người đăng để họ sửa — không phải tố cáo'**
  String get actionsReportWrongInfoSub;

  /// No description provided for @actionsReportNoun.
  ///
  /// In vi, this message translates to:
  /// **'Báo cáo {noun}'**
  String actionsReportNoun(Object noun);

  /// No description provided for @actionsReportViolationSub.
  ///
  /// In vi, this message translates to:
  /// **'Gửi quản trị viên xem xét'**
  String get actionsReportViolationSub;

  /// No description provided for @actionsLoginToFeedback.
  ///
  /// In vi, this message translates to:
  /// **'Đăng nhập để gửi phản hồi.'**
  String get actionsLoginToFeedback;

  /// No description provided for @actionsFeedbackSent.
  ///
  /// In vi, this message translates to:
  /// **'Đã gửi phản hồi tới người đăng. Cảm ơn bạn!'**
  String get actionsFeedbackSent;

  /// No description provided for @actionsReportSent.
  ///
  /// In vi, this message translates to:
  /// **'Đã gửi báo cáo. Quản trị viên sẽ xem xét.'**
  String get actionsReportSent;

  /// No description provided for @actionsRateLimited.
  ///
  /// In vi, this message translates to:
  /// **'Bạn gửi hơi nhiều, thử lại sau ít phút.'**
  String get actionsRateLimited;

  /// No description provided for @actionsSendFailed.
  ///
  /// In vi, this message translates to:
  /// **'Gửi thất bại. Vui lòng thử lại.'**
  String get actionsSendFailed;

  /// No description provided for @actionsWrongInfoDesc.
  ///
  /// In vi, this message translates to:
  /// **'Người đăng sẽ nhận được thông báo để kiểm tra lại. Danh tính của bạn được giữ kín.'**
  String get actionsWrongInfoDesc;

  /// No description provided for @actionsWrongInfoHint.
  ///
  /// In vi, this message translates to:
  /// **'VD: Giá đã thay đổi, nhà đã cho thuê, sai địa chỉ…'**
  String get actionsWrongInfoHint;

  /// No description provided for @actionsSend.
  ///
  /// In vi, this message translates to:
  /// **'Gửi'**
  String get actionsSend;

  /// No description provided for @actionsChooseReason.
  ///
  /// In vi, this message translates to:
  /// **'Chọn lý do phù hợp nhất'**
  String get actionsChooseReason;

  /// No description provided for @actionsReasonScam.
  ///
  /// In vi, this message translates to:
  /// **'Lừa đảo / tin giả'**
  String get actionsReasonScam;

  /// No description provided for @actionsReasonSpam.
  ///
  /// In vi, this message translates to:
  /// **'Spam, đăng trùng lặp nhiều lần'**
  String get actionsReasonSpam;

  /// No description provided for @actionsReasonDuplicate.
  ///
  /// In vi, this message translates to:
  /// **'Trùng với tin khác'**
  String get actionsReasonDuplicate;

  /// No description provided for @actionsReasonInappropriate.
  ///
  /// In vi, this message translates to:
  /// **'Nội dung không phù hợp'**
  String get actionsReasonInappropriate;

  /// No description provided for @actionsReasonOther.
  ///
  /// In vi, this message translates to:
  /// **'Lý do khác'**
  String get actionsReasonOther;

  /// No description provided for @homeMenuTooltip.
  ///
  /// In vi, this message translates to:
  /// **'Menu'**
  String get homeMenuTooltip;

  /// No description provided for @homeSearchTooltip.
  ///
  /// In vi, this message translates to:
  /// **'Tìm kiếm'**
  String get homeSearchTooltip;

  /// No description provided for @worldRealEstateLabel.
  ///
  /// In vi, this message translates to:
  /// **'BẤT ĐỘNG SẢN'**
  String get worldRealEstateLabel;

  /// No description provided for @worldConstructionLabel.
  ///
  /// In vi, this message translates to:
  /// **'XÂY DỰNG · THIẾT KẾ'**
  String get worldConstructionLabel;

  /// No description provided for @homeAdvancedFilterTooltip.
  ///
  /// In vi, this message translates to:
  /// **'Bộ lọc nâng cao'**
  String get homeAdvancedFilterTooltip;

  /// No description provided for @homeLoginPromptSaveContactPost.
  ///
  /// In vi, this message translates to:
  /// **'Đăng nhập để lưu tin, liên hệ và đăng bài.'**
  String get homeLoginPromptSaveContactPost;

  /// No description provided for @homeAll.
  ///
  /// In vi, this message translates to:
  /// **'Tất cả'**
  String get homeAll;

  /// No description provided for @homeRealEstateReels.
  ///
  /// In vi, this message translates to:
  /// **'Reels bất động sản'**
  String get homeRealEstateReels;

  /// No description provided for @homeNoMoreRooms.
  ///
  /// In vi, this message translates to:
  /// **'— Đã hết phòng —'**
  String get homeNoMoreRooms;

  /// No description provided for @homeLoadListFailed.
  ///
  /// In vi, this message translates to:
  /// **'Không tải được danh sách'**
  String get homeLoadListFailed;

  /// No description provided for @homeNoMatchingListings.
  ///
  /// In vi, this message translates to:
  /// **'Chưa có tin phù hợp'**
  String get homeNoMatchingListings;

  /// No description provided for @homeCheckNetworkRetry.
  ///
  /// In vi, this message translates to:
  /// **'Kiểm tra kết nối mạng rồi thử lại.'**
  String get homeCheckNetworkRetry;

  /// No description provided for @homeTryRemoveFilters.
  ///
  /// In vi, this message translates to:
  /// **'Thử bỏ bớt bộ lọc để xem nhiều tin hơn.'**
  String get homeTryRemoveFilters;

  /// No description provided for @homeRetry.
  ///
  /// In vi, this message translates to:
  /// **'Thử lại'**
  String get homeRetry;

  /// No description provided for @homeClearFilters.
  ///
  /// In vi, this message translates to:
  /// **'Xoá bộ lọc'**
  String get homeClearFilters;

  /// No description provided for @homeLoginToSaveFavorite.
  ///
  /// In vi, this message translates to:
  /// **'Đăng nhập để lưu tin yêu thích.'**
  String get homeLoginToSaveFavorite;

  /// No description provided for @homeHost.
  ///
  /// In vi, this message translates to:
  /// **'Chủ nhà'**
  String get homeHost;

  /// No description provided for @homeSave.
  ///
  /// In vi, this message translates to:
  /// **'Lưu'**
  String get homeSave;

  /// No description provided for @homeContact.
  ///
  /// In vi, this message translates to:
  /// **'Liên hệ'**
  String get homeContact;

  /// No description provided for @homeDetails.
  ///
  /// In vi, this message translates to:
  /// **'Chi tiết'**
  String get homeDetails;

  /// No description provided for @homeLoginToMessageHost.
  ///
  /// In vi, this message translates to:
  /// **'Đăng nhập để nhắn tin với chủ nhà.'**
  String get homeLoginToMessageHost;

  /// No description provided for @homeAreaM2.
  ///
  /// In vi, this message translates to:
  /// **'{area} m²'**
  String homeAreaM2(Object area);

  /// No description provided for @homeDistanceAway.
  ///
  /// In vi, this message translates to:
  /// **'cách {distance}'**
  String homeDistanceAway(Object distance);

  /// No description provided for @homeFull.
  ///
  /// In vi, this message translates to:
  /// **'ĐÃ ĐỦ'**
  String get homeFull;

  /// No description provided for @homeAvailableUnits.
  ///
  /// In vi, this message translates to:
  /// **'CÒN {available}/{total}'**
  String homeAvailableUnits(Object available, Object total);

  /// No description provided for @homeTabRent.
  ///
  /// In vi, this message translates to:
  /// **'Cho thuê'**
  String get homeTabRent;

  /// No description provided for @homeTabSale.
  ///
  /// In vi, this message translates to:
  /// **'Mua bán'**
  String get homeTabSale;

  /// No description provided for @homeFilterRent.
  ///
  /// In vi, this message translates to:
  /// **'Bộ lọc: Cho thuê'**
  String get homeFilterRent;

  /// No description provided for @homeFilterSale.
  ///
  /// In vi, this message translates to:
  /// **'Bộ lọc: Mua bán'**
  String get homeFilterSale;

  /// No description provided for @filterTitle.
  ///
  /// In vi, this message translates to:
  /// **'Tìm kiếm & Bộ lọc'**
  String get filterTitle;

  /// No description provided for @filterReset.
  ///
  /// In vi, this message translates to:
  /// **'Đặt lại'**
  String get filterReset;

  /// No description provided for @filterSectionSearchArea.
  ///
  /// In vi, this message translates to:
  /// **'Khu vực tìm kiếm'**
  String get filterSectionSearchArea;

  /// No description provided for @filterSectionPriceRange.
  ///
  /// In vi, this message translates to:
  /// **'Khoảng giá'**
  String get filterSectionPriceRange;

  /// No description provided for @filterMaxPriceLabel.
  ///
  /// In vi, this message translates to:
  /// **'Giá tối đa:'**
  String get filterMaxPriceLabel;

  /// No description provided for @filterPriceValueVnd.
  ///
  /// In vi, this message translates to:
  /// **'{value}tr VNĐ'**
  String filterPriceValueVnd(Object value);

  /// No description provided for @filterPriceValueShort.
  ///
  /// In vi, this message translates to:
  /// **'{value}tr'**
  String filterPriceValueShort(Object value);

  /// No description provided for @filterSectionArea.
  ///
  /// In vi, this message translates to:
  /// **'Diện tích (m²)'**
  String get filterSectionArea;

  /// No description provided for @filterAreaFrom.
  ///
  /// In vi, this message translates to:
  /// **'Từ'**
  String get filterAreaFrom;

  /// No description provided for @filterAreaTo.
  ///
  /// In vi, this message translates to:
  /// **'Đến'**
  String get filterAreaTo;

  /// No description provided for @filterSectionBedrooms.
  ///
  /// In vi, this message translates to:
  /// **'Số phòng ngủ'**
  String get filterSectionBedrooms;

  /// No description provided for @filterAny.
  ///
  /// In vi, this message translates to:
  /// **'Bất kỳ'**
  String get filterAny;

  /// No description provided for @filterSectionPropertyType.
  ///
  /// In vi, this message translates to:
  /// **'Loại hình cư trú'**
  String get filterSectionPropertyType;

  /// No description provided for @filterClearAll.
  ///
  /// In vi, this message translates to:
  /// **'Xóa tất cả'**
  String get filterClearAll;

  /// No description provided for @filterApply.
  ///
  /// In vi, this message translates to:
  /// **'Áp dụng bộ lọc'**
  String get filterApply;

  /// No description provided for @filterModeAll.
  ///
  /// In vi, this message translates to:
  /// **'Toàn bộ'**
  String get filterModeAll;

  /// No description provided for @filterModeNearby.
  ///
  /// In vi, this message translates to:
  /// **'Quanh đây'**
  String get filterModeNearby;

  /// No description provided for @filterModePlace.
  ///
  /// In vi, this message translates to:
  /// **'Địa danh'**
  String get filterModePlace;

  /// No description provided for @filterPlaceHint.
  ///
  /// In vi, this message translates to:
  /// **'Nhập địa danh: \"gần Đại học Bách Khoa\"…'**
  String get filterPlaceHint;

  /// No description provided for @filterLocationUpdate.
  ///
  /// In vi, this message translates to:
  /// **'Đã có vị trí — chạm để cập nhật'**
  String get filterLocationUpdate;

  /// No description provided for @filterGetCurrentLocation.
  ///
  /// In vi, this message translates to:
  /// **'Lấy vị trí hiện tại'**
  String get filterGetCurrentLocation;

  /// No description provided for @filterRadiusLabel.
  ///
  /// In vi, this message translates to:
  /// **'Bán kính:'**
  String get filterRadiusLabel;

  /// No description provided for @filterRadiusKm.
  ///
  /// In vi, this message translates to:
  /// **'{value} km'**
  String filterRadiusKm(Object value);

  /// No description provided for @filterLocationAcquired.
  ///
  /// In vi, this message translates to:
  /// **'Đã lấy vị trí của bạn ✓'**
  String get filterLocationAcquired;

  /// No description provided for @filterLocServiceOff.
  ///
  /// In vi, this message translates to:
  /// **'Định vị trên thiết bị đang tắt. Bật rồi thử lại.'**
  String get filterLocServiceOff;

  /// No description provided for @filterLocDenied.
  ///
  /// In vi, this message translates to:
  /// **'Cần quyền vị trí. Hãy thử lại và cho phép.'**
  String get filterLocDenied;

  /// No description provided for @filterLocDeniedForever.
  ///
  /// In vi, this message translates to:
  /// **'Quyền vị trí bị chặn — mở Cài đặt để cấp.'**
  String get filterLocDeniedForever;

  /// No description provided for @filterLocOutOfVietnam.
  ///
  /// In vi, this message translates to:
  /// **'Vị trí ngoài phạm vi phục vụ.'**
  String get filterLocOutOfVietnam;

  /// No description provided for @filterLocError.
  ///
  /// In vi, this message translates to:
  /// **'Không lấy được vị trí. Thử lại.'**
  String get filterLocError;

  /// No description provided for @filterPrimingTitle.
  ///
  /// In vi, this message translates to:
  /// **'Tìm phòng quanh bạn'**
  String get filterPrimingTitle;

  /// No description provided for @filterPrimingBody.
  ///
  /// In vi, this message translates to:
  /// **'Bật vị trí để xem phòng gần bạn nhất kèm khoảng cách chính xác. Vua Nhà chỉ dùng vị trí khi bạn tìm quanh đây.'**
  String get filterPrimingBody;

  /// No description provided for @filterPrimingLater.
  ///
  /// In vi, this message translates to:
  /// **'Để sau'**
  String get filterPrimingLater;

  /// No description provided for @filterEnableLocation.
  ///
  /// In vi, this message translates to:
  /// **'Bật vị trí'**
  String get filterEnableLocation;

  /// No description provided for @filterNeedLocationFirst.
  ///
  /// In vi, this message translates to:
  /// **'Hãy lấy vị trí hiện tại trước khi áp dụng.'**
  String get filterNeedLocationFirst;

  /// No description provided for @addProjPdfUploadError.
  ///
  /// In vi, this message translates to:
  /// **'Không tải được file PDF'**
  String get addProjPdfUploadError;

  /// No description provided for @addProjTitleRequired.
  ///
  /// In vi, this message translates to:
  /// **'Nhập tên công trình'**
  String get addProjTitleRequired;

  /// No description provided for @addProjWaitImages.
  ///
  /// In vi, this message translates to:
  /// **'Đợi ảnh tải xong đã nhé'**
  String get addProjWaitImages;

  /// No description provided for @addProjNeedImage.
  ///
  /// In vi, this message translates to:
  /// **'Thêm ít nhất 1 ảnh cho công trình'**
  String get addProjNeedImage;

  /// No description provided for @addProjUpdated.
  ///
  /// In vi, this message translates to:
  /// **'Đã cập nhật'**
  String get addProjUpdated;

  /// No description provided for @addProjPosted.
  ///
  /// In vi, this message translates to:
  /// **'Đã đăng. Hồ sơ sẽ được quản trị xác nhận.'**
  String get addProjPosted;

  /// No description provided for @addProjError.
  ///
  /// In vi, this message translates to:
  /// **'Lỗi: {error}'**
  String addProjError(Object error);

  /// No description provided for @addProjEyebrow.
  ///
  /// In vi, this message translates to:
  /// **'Kênh đơn vị'**
  String get addProjEyebrow;

  /// No description provided for @addProjEditTitle.
  ///
  /// In vi, this message translates to:
  /// **'Sửa {type}'**
  String addProjEditTitle(Object type);

  /// No description provided for @addProjTypeDesign.
  ///
  /// In vi, this message translates to:
  /// **'mẫu thiết kế'**
  String get addProjTypeDesign;

  /// No description provided for @addProjTypeWork.
  ///
  /// In vi, this message translates to:
  /// **'công trình'**
  String get addProjTypeWork;

  /// No description provided for @addProjCreateDesign.
  ///
  /// In vi, this message translates to:
  /// **'Đăng mẫu thiết kế'**
  String get addProjCreateDesign;

  /// No description provided for @addProjCreateWork.
  ///
  /// In vi, this message translates to:
  /// **'Đăng công trình'**
  String get addProjCreateWork;

  /// No description provided for @addProjPhotoSection.
  ///
  /// In vi, this message translates to:
  /// **'Ảnh {type}'**
  String addProjPhotoSection(Object type);

  /// No description provided for @addProjPhotoHelper.
  ///
  /// In vi, this message translates to:
  /// **'Ảnh đầu tiên là ảnh bìa. Nhấn giữ để đặt bìa/xoá. Tối đa 10 ảnh.'**
  String get addProjPhotoHelper;

  /// No description provided for @addProjBasicInfo.
  ///
  /// In vi, this message translates to:
  /// **'Thông tin cơ bản'**
  String get addProjBasicInfo;

  /// No description provided for @addProjTitleLabel.
  ///
  /// In vi, this message translates to:
  /// **'Tên công trình'**
  String get addProjTitleLabel;

  /// No description provided for @addProjTitleHintDesign.
  ///
  /// In vi, this message translates to:
  /// **'VD: Biệt thự hiện đại 3 tầng 9x16m'**
  String get addProjTitleHintDesign;

  /// No description provided for @addProjTitleHintWork.
  ///
  /// In vi, this message translates to:
  /// **'VD: Nhà phố 3 tầng anh Nam - Q7'**
  String get addProjTitleHintWork;

  /// No description provided for @addProjDescLabel.
  ///
  /// In vi, this message translates to:
  /// **'Mô tả'**
  String get addProjDescLabel;

  /// No description provided for @addProjDescHint.
  ///
  /// In vi, this message translates to:
  /// **'Quy mô, vật liệu, điểm nhấn…'**
  String get addProjDescHint;

  /// No description provided for @addProjFieldLabel.
  ///
  /// In vi, this message translates to:
  /// **'Lĩnh vực'**
  String get addProjFieldLabel;

  /// No description provided for @addProjFieldBuild.
  ///
  /// In vi, this message translates to:
  /// **'Xây dựng'**
  String get addProjFieldBuild;

  /// No description provided for @addProjFieldInterior.
  ///
  /// In vi, this message translates to:
  /// **'Nội thất'**
  String get addProjFieldInterior;

  /// No description provided for @addProjYearLabel.
  ///
  /// In vi, this message translates to:
  /// **'Năm hoàn thành'**
  String get addProjYearLabel;

  /// No description provided for @addProjSpecsTitle.
  ///
  /// In vi, this message translates to:
  /// **'Thông số mẫu nhà'**
  String get addProjSpecsTitle;

  /// No description provided for @addProjSpecsHelper.
  ///
  /// In vi, this message translates to:
  /// **'Giúp mẫu lên đúng bộ lọc Thư viện thiết kế.'**
  String get addProjSpecsHelper;

  /// No description provided for @addProjHouseTypeLabel.
  ///
  /// In vi, this message translates to:
  /// **'Loại nhà'**
  String get addProjHouseTypeLabel;

  /// No description provided for @addProjStyleLabel.
  ///
  /// In vi, this message translates to:
  /// **'Phong cách'**
  String get addProjStyleLabel;

  /// No description provided for @addProjFloorsLabel.
  ///
  /// In vi, this message translates to:
  /// **'Số tầng'**
  String get addProjFloorsLabel;

  /// No description provided for @addProjBedroomsLabel.
  ///
  /// In vi, this message translates to:
  /// **'Phòng ngủ'**
  String get addProjBedroomsLabel;

  /// No description provided for @addProjWidthLabel.
  ///
  /// In vi, this message translates to:
  /// **'Chiều rộng đất (m)'**
  String get addProjWidthLabel;

  /// No description provided for @addProjLengthLabel.
  ///
  /// In vi, this message translates to:
  /// **'Chiều dài đất (m)'**
  String get addProjLengthLabel;

  /// No description provided for @addProjAreaLabel.
  ///
  /// In vi, this message translates to:
  /// **'Diện tích XD (m²)'**
  String get addProjAreaLabel;

  /// No description provided for @addProjCostLabel.
  ///
  /// In vi, this message translates to:
  /// **'Giá tham khảo (VND)'**
  String get addProjCostLabel;

  /// No description provided for @addProjCostHint.
  ///
  /// In vi, this message translates to:
  /// **'Để trống nếu chưa có'**
  String get addProjCostHint;

  /// No description provided for @addProjPdfSection.
  ///
  /// In vi, this message translates to:
  /// **'Hồ sơ thiết kế (PDF)'**
  String get addProjPdfSection;

  /// No description provided for @addProjPdfHelper.
  ///
  /// In vi, this message translates to:
  /// **'Bản vẽ/hồ sơ — quản trị sẽ xác nhận. Tối đa 10 file.'**
  String get addProjPdfHelper;

  /// No description provided for @addProjPdfItem.
  ///
  /// In vi, this message translates to:
  /// **'Hồ sơ {number}'**
  String addProjPdfItem(Object number);

  /// No description provided for @addProjUploading.
  ///
  /// In vi, this message translates to:
  /// **'Đang tải…'**
  String get addProjUploading;

  /// No description provided for @addProjAddPdf.
  ///
  /// In vi, this message translates to:
  /// **'Thêm file PDF'**
  String get addProjAddPdf;

  /// No description provided for @addProjSaveChanges.
  ///
  /// In vi, this message translates to:
  /// **'Lưu thay đổi'**
  String get addProjSaveChanges;

  /// No description provided for @addProjSubmit.
  ///
  /// In vi, this message translates to:
  /// **'Đăng'**
  String get addProjSubmit;

  /// No description provided for @addProjSegWork.
  ///
  /// In vi, this message translates to:
  /// **'Công trình đã làm'**
  String get addProjSegWork;

  /// No description provided for @addProjSegDesign.
  ///
  /// In vi, this message translates to:
  /// **'Mẫu thiết kế'**
  String get addProjSegDesign;

  /// No description provided for @bkDetEyebrow.
  ///
  /// In vi, this message translates to:
  /// **'Đặt lịch'**
  String get bkDetEyebrow;

  /// No description provided for @bkDetTitle.
  ///
  /// In vi, this message translates to:
  /// **'Chi tiết lịch hẹn'**
  String get bkDetTitle;

  /// No description provided for @bkDetCancelAppointment.
  ///
  /// In vi, this message translates to:
  /// **'Hủy lịch hẹn'**
  String get bkDetCancelAppointment;

  /// No description provided for @bkDetCancelConfirm.
  ///
  /// In vi, this message translates to:
  /// **'Bạn chắc chắn muốn hủy lịch hẹn xem nhà này?'**
  String get bkDetCancelConfirm;

  /// No description provided for @bkDetClose.
  ///
  /// In vi, this message translates to:
  /// **'Đóng'**
  String get bkDetClose;

  /// No description provided for @bkDetCancelBooking.
  ///
  /// In vi, this message translates to:
  /// **'Hủy lịch'**
  String get bkDetCancelBooking;

  /// No description provided for @bkDetCancelFailed.
  ///
  /// In vi, this message translates to:
  /// **'Hủy thất bại — thử lại.'**
  String get bkDetCancelFailed;

  /// No description provided for @bkDetPhoneCopied.
  ///
  /// In vi, this message translates to:
  /// **'Đã copy số {phone} — mở app gọi điện để gọi.'**
  String bkDetPhoneCopied(Object phone);

  /// No description provided for @bkDetHostNotFound.
  ///
  /// In vi, this message translates to:
  /// **'Không tìm thấy thông tin chủ nhà.'**
  String get bkDetHostNotFound;

  /// No description provided for @bkDetHost.
  ///
  /// In vi, this message translates to:
  /// **'Chủ nhà'**
  String get bkDetHost;

  /// No description provided for @bkDetApartment.
  ///
  /// In vi, this message translates to:
  /// **'Căn hộ'**
  String get bkDetApartment;

  /// No description provided for @bkDetRoomImage.
  ///
  /// In vi, this message translates to:
  /// **'Ảnh phòng'**
  String get bkDetRoomImage;

  /// No description provided for @bkDetScheduleTitle.
  ///
  /// In vi, this message translates to:
  /// **'Lịch hẹn'**
  String get bkDetScheduleTitle;

  /// No description provided for @bkDetViewDate.
  ///
  /// In vi, this message translates to:
  /// **'Ngày xem'**
  String get bkDetViewDate;

  /// No description provided for @bkDetTime.
  ///
  /// In vi, this message translates to:
  /// **'Giờ'**
  String get bkDetTime;

  /// No description provided for @bkDetSentAt.
  ///
  /// In vi, this message translates to:
  /// **'Thời điểm gửi'**
  String get bkDetSentAt;

  /// No description provided for @bkDetYourMessage.
  ///
  /// In vi, this message translates to:
  /// **'Lời nhắn của bạn'**
  String get bkDetYourMessage;

  /// No description provided for @bkDetNoMessage.
  ///
  /// In vi, this message translates to:
  /// **'Không có lời nhắn.'**
  String get bkDetNoMessage;

  /// No description provided for @bkDetHostInfo.
  ///
  /// In vi, this message translates to:
  /// **'Thông tin chủ nhà'**
  String get bkDetHostInfo;

  /// No description provided for @bkDetMessage.
  ///
  /// In vi, this message translates to:
  /// **'Nhắn tin'**
  String get bkDetMessage;

  /// No description provided for @bkDetProgress.
  ///
  /// In vi, this message translates to:
  /// **'Tiến trình'**
  String get bkDetProgress;

  /// No description provided for @bkDetStepRequested.
  ///
  /// In vi, this message translates to:
  /// **'Yêu cầu đã gửi'**
  String get bkDetStepRequested;

  /// No description provided for @bkDetStepApproved.
  ///
  /// In vi, this message translates to:
  /// **'Host duyệt lịch'**
  String get bkDetStepApproved;

  /// No description provided for @bkDetStepCompleted.
  ///
  /// In vi, this message translates to:
  /// **'Hoàn thành xem nhà'**
  String get bkDetStepCompleted;

  /// No description provided for @bkDetStepBooked.
  ///
  /// In vi, this message translates to:
  /// **'Chốt phòng'**
  String get bkDetStepBooked;

  /// No description provided for @bkDetStepRejected.
  ///
  /// In vi, this message translates to:
  /// **'Host từ chối'**
  String get bkDetStepRejected;

  /// No description provided for @bkDetStepCancelled.
  ///
  /// In vi, this message translates to:
  /// **'Bạn đã hủy'**
  String get bkDetStepCancelled;

  /// No description provided for @bkDetStepLost.
  ///
  /// In vi, this message translates to:
  /// **'Người khác chốt trước'**
  String get bkDetStepLost;

  /// No description provided for @bkDetStepEnded.
  ///
  /// In vi, this message translates to:
  /// **'Kết thúc'**
  String get bkDetStepEnded;

  /// No description provided for @bkDetCall.
  ///
  /// In vi, this message translates to:
  /// **'Gọi điện'**
  String get bkDetCall;

  /// No description provided for @bkDetReviewed.
  ///
  /// In vi, this message translates to:
  /// **'Đã đánh giá'**
  String get bkDetReviewed;

  /// No description provided for @bkDetWriteReview.
  ///
  /// In vi, this message translates to:
  /// **'Viết đánh giá'**
  String get bkDetWriteReview;

  /// No description provided for @bkDetExploreOther.
  ///
  /// In vi, this message translates to:
  /// **'Xem nhà khác'**
  String get bkDetExploreOther;

  /// No description provided for @bkHistEyebrow.
  ///
  /// In vi, this message translates to:
  /// **'Tài khoản'**
  String get bkHistEyebrow;

  /// No description provided for @bkHistTitle.
  ///
  /// In vi, this message translates to:
  /// **'Lịch sử đặt lịch'**
  String get bkHistTitle;

  /// No description provided for @bkHistRefresh.
  ///
  /// In vi, this message translates to:
  /// **'Làm mới'**
  String get bkHistRefresh;

  /// No description provided for @bkHistTabPending.
  ///
  /// In vi, this message translates to:
  /// **'Chờ duyệt'**
  String get bkHistTabPending;

  /// No description provided for @bkHistTabApproved.
  ///
  /// In vi, this message translates to:
  /// **'Đã duyệt'**
  String get bkHistTabApproved;

  /// No description provided for @bkHistCompleted.
  ///
  /// In vi, this message translates to:
  /// **'Hoàn thành'**
  String get bkHistCompleted;

  /// No description provided for @bkHistFilterAll.
  ///
  /// In vi, this message translates to:
  /// **'Tất cả'**
  String get bkHistFilterAll;

  /// No description provided for @bkHistStatusLocked.
  ///
  /// In vi, this message translates to:
  /// **'Đã chốt phòng'**
  String get bkHistStatusLocked;

  /// No description provided for @bkHistStatusCancelled.
  ///
  /// In vi, this message translates to:
  /// **'Đã hủy'**
  String get bkHistStatusCancelled;

  /// No description provided for @bkHistStatusRejected.
  ///
  /// In vi, this message translates to:
  /// **'Bị từ chối'**
  String get bkHistStatusRejected;

  /// No description provided for @bkHistStatusLost.
  ///
  /// In vi, this message translates to:
  /// **'Đã có người chốt'**
  String get bkHistStatusLost;

  /// No description provided for @bkHistSearchHint.
  ///
  /// In vi, this message translates to:
  /// **'Tìm theo tên / địa chỉ nhà...'**
  String get bkHistSearchHint;

  /// No description provided for @bkHistClearSearch.
  ///
  /// In vi, this message translates to:
  /// **'Xóa tìm kiếm'**
  String get bkHistClearSearch;

  /// No description provided for @bkHistRoomPhoto.
  ///
  /// In vi, this message translates to:
  /// **'Ảnh phòng'**
  String get bkHistRoomPhoto;

  /// No description provided for @bkHistDefaultHouseTitle.
  ///
  /// In vi, this message translates to:
  /// **'Căn hộ cao cấp'**
  String get bkHistDefaultHouseTitle;

  /// No description provided for @bkHistCallHost.
  ///
  /// In vi, this message translates to:
  /// **'Gọi host'**
  String get bkHistCallHost;

  /// No description provided for @bkHistMessage.
  ///
  /// In vi, this message translates to:
  /// **'Nhắn tin'**
  String get bkHistMessage;

  /// No description provided for @bkHistReviewed.
  ///
  /// In vi, this message translates to:
  /// **'Đã đánh giá'**
  String get bkHistReviewed;

  /// No description provided for @bkHistReview.
  ///
  /// In vi, this message translates to:
  /// **'Đánh giá'**
  String get bkHistReview;

  /// No description provided for @bkHistApartment.
  ///
  /// In vi, this message translates to:
  /// **'Căn hộ'**
  String get bkHistApartment;

  /// No description provided for @bkHistViewOtherHouses.
  ///
  /// In vi, this message translates to:
  /// **'Xem nhà khác'**
  String get bkHistViewOtherHouses;

  /// No description provided for @bkHistCancelTitle.
  ///
  /// In vi, this message translates to:
  /// **'Hủy lịch hẹn'**
  String get bkHistCancelTitle;

  /// No description provided for @bkHistCancelConfirm.
  ///
  /// In vi, this message translates to:
  /// **'Bạn có chắc chắn muốn hủy lịch hẹn này?'**
  String get bkHistCancelConfirm;

  /// No description provided for @bkHistClose.
  ///
  /// In vi, this message translates to:
  /// **'Đóng'**
  String get bkHistClose;

  /// No description provided for @bkHistCancelAppointment.
  ///
  /// In vi, this message translates to:
  /// **'Hủy lịch'**
  String get bkHistCancelAppointment;

  /// No description provided for @bkHistCancelSuccess.
  ///
  /// In vi, this message translates to:
  /// **'Đã hủy lịch hẹn'**
  String get bkHistCancelSuccess;

  /// No description provided for @bkHistCancelFailed.
  ///
  /// In vi, this message translates to:
  /// **'Hủy thất bại'**
  String get bkHistCancelFailed;

  /// No description provided for @bkHistNoHostPhone.
  ///
  /// In vi, this message translates to:
  /// **'Chưa có số điện thoại host'**
  String get bkHistNoHostPhone;

  /// No description provided for @bkHistPhoneCopied.
  ///
  /// In vi, this message translates to:
  /// **'Đã copy số: {phone}'**
  String bkHistPhoneCopied(Object phone);

  /// No description provided for @bkHistHostNotFound.
  ///
  /// In vi, this message translates to:
  /// **'Không tìm thấy host'**
  String get bkHistHostNotFound;

  /// No description provided for @bkHistHost.
  ///
  /// In vi, this message translates to:
  /// **'Host'**
  String get bkHistHost;

  /// No description provided for @bkHistNoRequests.
  ///
  /// In vi, this message translates to:
  /// **'Không có yêu cầu nào'**
  String get bkHistNoRequests;

  /// No description provided for @bkHistNoResults.
  ///
  /// In vi, this message translates to:
  /// **'Không tìm thấy kết quả'**
  String get bkHistNoResults;

  /// No description provided for @bkHistSearchEmpty.
  ///
  /// In vi, this message translates to:
  /// **'Thử từ khoá khác hoặc xoá bộ lọc tìm kiếm.'**
  String get bkHistSearchEmpty;

  /// No description provided for @bkHistEmptyHint.
  ///
  /// In vi, this message translates to:
  /// **'Các yêu cầu đặt lịch hẹn của bạn sẽ hiển thị tại đây.'**
  String get bkHistEmptyHint;

  /// No description provided for @bkSchedSuccessMessage.
  ///
  /// In vi, this message translates to:
  /// **'Gửi yêu cầu đặt lịch hẹn thành công!'**
  String get bkSchedSuccessMessage;

  /// No description provided for @bkSchedSubmitFailed.
  ///
  /// In vi, this message translates to:
  /// **'Gửi yêu cầu thất bại'**
  String get bkSchedSubmitFailed;

  /// No description provided for @bkSchedEyebrow.
  ///
  /// In vi, this message translates to:
  /// **'Đặt lịch'**
  String get bkSchedEyebrow;

  /// No description provided for @bkSchedAppBarTitle.
  ///
  /// In vi, this message translates to:
  /// **'Đặt lịch xem nhà'**
  String get bkSchedAppBarTitle;

  /// No description provided for @bkSchedCardHeader.
  ///
  /// In vi, this message translates to:
  /// **'Đặt lịch hẹn xem nhà'**
  String get bkSchedCardHeader;

  /// No description provided for @bkSchedStep1.
  ///
  /// In vi, this message translates to:
  /// **'1. Chọn ngày xem nhà'**
  String get bkSchedStep1;

  /// No description provided for @bkSchedDateLabel.
  ///
  /// In vi, this message translates to:
  /// **'Ngày: {date}'**
  String bkSchedDateLabel(Object date);

  /// No description provided for @bkSchedStep2.
  ///
  /// In vi, this message translates to:
  /// **'2. Chọn khung giờ (mỗi khung 1 tiếng)'**
  String get bkSchedStep2;

  /// No description provided for @bkSchedStep3.
  ///
  /// In vi, this message translates to:
  /// **'3. Lời nhắn cho chủ nhà (Tùy chọn)'**
  String get bkSchedStep3;

  /// No description provided for @bkSchedMessageHint.
  ///
  /// In vi, this message translates to:
  /// **'Ví dụ: Tôi muốn hỏi thêm về chỗ để xe ô tô, hoặc tôi sẽ đi cùng bạn...'**
  String get bkSchedMessageHint;

  /// No description provided for @bkSchedSelectSlotPrompt.
  ///
  /// In vi, this message translates to:
  /// **'Vui lòng chọn khung giờ'**
  String get bkSchedSelectSlotPrompt;

  /// No description provided for @bkSchedSubmit.
  ///
  /// In vi, this message translates to:
  /// **'Gửi yêu cầu đặt lịch'**
  String get bkSchedSubmit;

  /// No description provided for @bkSchedAfterSubmitTitle.
  ///
  /// In vi, this message translates to:
  /// **'Sau khi gửi yêu cầu'**
  String get bkSchedAfterSubmitTitle;

  /// No description provided for @bkSchedAfterSubmitDesc.
  ///
  /// In vi, this message translates to:
  /// **'Chủ nhà sẽ nhận được thông báo và phản hồi xác nhận cho bạn trong vòng tối đa 2 giờ làm việc.'**
  String get bkSchedAfterSubmitDesc;

  /// No description provided for @bkSchedCancelPolicyTitle.
  ///
  /// In vi, this message translates to:
  /// **'Chính sách hủy lịch'**
  String get bkSchedCancelPolicyTitle;

  /// No description provided for @bkSchedCancelPolicyDesc.
  ///
  /// In vi, this message translates to:
  /// **'Bạn có thể thay đổi hoặc hủy lịch xem nhà miễn phí trước 4 giờ so với thời gian đã hẹn.'**
  String get bkSchedCancelPolicyDesc;

  /// No description provided for @bkSchedRetry.
  ///
  /// In vi, this message translates to:
  /// **'Thử lại'**
  String get bkSchedRetry;

  /// No description provided for @bkSchedNoSlots.
  ///
  /// In vi, this message translates to:
  /// **'Không có khung giờ trống cho ngày này. Vui lòng chọn ngày khác.'**
  String get bkSchedNoSlots;

  /// No description provided for @ccompTitle.
  ///
  /// In vi, this message translates to:
  /// **'Đăng bài xây dựng'**
  String get ccompTitle;

  /// No description provided for @ccompSend.
  ///
  /// In vi, this message translates to:
  /// **'Gửi'**
  String get ccompSend;

  /// No description provided for @ccompPost.
  ///
  /// In vi, this message translates to:
  /// **'Đăng'**
  String get ccompPost;

  /// No description provided for @ccompYou.
  ///
  /// In vi, this message translates to:
  /// **'Bạn'**
  String get ccompYou;

  /// No description provided for @ccompGuestName.
  ///
  /// In vi, this message translates to:
  /// **'Khách'**
  String get ccompGuestName;

  /// No description provided for @ccompIntentShare.
  ///
  /// In vi, this message translates to:
  /// **'Chia sẻ công trình'**
  String get ccompIntentShare;

  /// No description provided for @ccompIntentNeed.
  ///
  /// In vi, this message translates to:
  /// **'Cần xây dựng'**
  String get ccompIntentNeed;

  /// No description provided for @ccompContentHintNeed.
  ///
  /// In vi, this message translates to:
  /// **'Bạn cần xây dựng gì? Mô tả nhu cầu, hiện trạng…'**
  String get ccompContentHintNeed;

  /// No description provided for @ccompContentHintShare.
  ///
  /// In vi, this message translates to:
  /// **'Chia sẻ công trình bạn vừa hoàn thành…'**
  String get ccompContentHintShare;

  /// No description provided for @ccompServiceBuild.
  ///
  /// In vi, this message translates to:
  /// **'Xây dựng'**
  String get ccompServiceBuild;

  /// No description provided for @ccompServiceDesign.
  ///
  /// In vi, this message translates to:
  /// **'Thiết kế'**
  String get ccompServiceDesign;

  /// No description provided for @ccompServiceInterior.
  ///
  /// In vi, this message translates to:
  /// **'Nội thất'**
  String get ccompServiceInterior;

  /// No description provided for @ccompServiceIndustrial.
  ///
  /// In vi, this message translates to:
  /// **'Công nghiệp'**
  String get ccompServiceIndustrial;

  /// No description provided for @ccompPhoneHint.
  ///
  /// In vi, this message translates to:
  /// **'Số điện thoại *'**
  String get ccompPhoneHint;

  /// No description provided for @ccompAreaHint.
  ///
  /// In vi, this message translates to:
  /// **'Diện tích (vd. 80m²)'**
  String get ccompAreaHint;

  /// No description provided for @ccompBudgetHint.
  ///
  /// In vi, this message translates to:
  /// **'Ngân sách dự kiến'**
  String get ccompBudgetHint;

  /// No description provided for @ccompLocationOptional.
  ///
  /// In vi, this message translates to:
  /// **'Vị trí (tuỳ chọn)'**
  String get ccompLocationOptional;

  /// No description provided for @ccompSelectProvince.
  ///
  /// In vi, this message translates to:
  /// **'Chọn tỉnh/thành'**
  String get ccompSelectProvince;

  /// No description provided for @ccompLoading.
  ///
  /// In vi, this message translates to:
  /// **'Đang tải…'**
  String get ccompLoading;

  /// No description provided for @ccompSelectWard.
  ///
  /// In vi, this message translates to:
  /// **'Chọn phường/xã'**
  String get ccompSelectWard;

  /// No description provided for @ccompMapHint.
  ///
  /// In vi, this message translates to:
  /// **'Chạm vào bản đồ để ghim vị trí (địa chỉ tự điền).'**
  String get ccompMapHint;

  /// No description provided for @ccompPinnedWard.
  ///
  /// In vi, this message translates to:
  /// **'Đã ghim: {ward}'**
  String ccompPinnedWard(Object ward);

  /// No description provided for @ccompPinnedCoords.
  ///
  /// In vi, this message translates to:
  /// **'Đã ghim: {lat}, {lng}'**
  String ccompPinnedCoords(Object lat, Object lng);

  /// No description provided for @ccompPhotosCount.
  ///
  /// In vi, this message translates to:
  /// **'Ảnh ({count}/{max})'**
  String ccompPhotosCount(Object count, Object max);

  /// No description provided for @ccompLocation.
  ///
  /// In vi, this message translates to:
  /// **'Vị trí'**
  String get ccompLocation;

  /// No description provided for @ccompImagePickFailed.
  ///
  /// In vi, this message translates to:
  /// **'Không chọn được ảnh'**
  String get ccompImagePickFailed;

  /// No description provided for @ccompSubmitFailed.
  ///
  /// In vi, this message translates to:
  /// **'Đăng bài thất bại, thử lại'**
  String get ccompSubmitFailed;

  /// No description provided for @cleadTitle.
  ///
  /// In vi, this message translates to:
  /// **'Bảng xếp hạng đối tác'**
  String get cleadTitle;

  /// No description provided for @cleadSubtitle.
  ///
  /// In vi, this message translates to:
  /// **'Xếp hạng theo mức độ uy tín & đánh giá'**
  String get cleadSubtitle;

  /// No description provided for @cleadTradeDesign.
  ///
  /// In vi, this message translates to:
  /// **'Thiết kế'**
  String get cleadTradeDesign;

  /// No description provided for @cleadTradeBuild.
  ///
  /// In vi, this message translates to:
  /// **'Xây dựng'**
  String get cleadTradeBuild;

  /// No description provided for @cleadTradeInterior.
  ///
  /// In vi, this message translates to:
  /// **'Nội thất'**
  String get cleadTradeInterior;

  /// No description provided for @cleadTradeIndustrial.
  ///
  /// In vi, this message translates to:
  /// **'BĐS công nghiệp'**
  String get cleadTradeIndustrial;

  /// No description provided for @cleadLoadError.
  ///
  /// In vi, this message translates to:
  /// **'Không tải được danh sách đối tác'**
  String get cleadLoadError;

  /// No description provided for @cleadEmptyTitle.
  ///
  /// In vi, this message translates to:
  /// **'Chưa có đối tác trong ngành này'**
  String get cleadEmptyTitle;

  /// No description provided for @cleadEmptySubtitle.
  ///
  /// In vi, this message translates to:
  /// **'Hãy thử chọn ngành khác hoặc quay lại sau.'**
  String get cleadEmptySubtitle;

  /// No description provided for @cleadFallbackCompany.
  ///
  /// In vi, this message translates to:
  /// **'Đối tác'**
  String get cleadFallbackCompany;

  /// No description provided for @cleadNoRating.
  ///
  /// In vi, this message translates to:
  /// **'Chưa có đánh giá'**
  String get cleadNoRating;

  /// No description provided for @cleadRatingCount.
  ///
  /// In vi, this message translates to:
  /// **'⭐ {rating} ({count} đánh giá)'**
  String cleadRatingCount(Object rating, Object count);

  /// No description provided for @cleadRatingNew.
  ///
  /// In vi, this message translates to:
  /// **'⭐ {rating} · {count} đánh giá (mới)'**
  String cleadRatingNew(Object rating, Object count);

  /// No description provided for @cleadBadgeFeatured.
  ///
  /// In vi, this message translates to:
  /// **'Nổi bật'**
  String get cleadBadgeFeatured;

  /// No description provided for @cleadBadgePro.
  ///
  /// In vi, this message translates to:
  /// **'Pro'**
  String get cleadBadgePro;

  /// No description provided for @cleadBadgeVerified.
  ///
  /// In vi, this message translates to:
  /// **'Đã thẩm định'**
  String get cleadBadgeVerified;

  /// No description provided for @compareTitle.
  ///
  /// In vi, this message translates to:
  /// **'So sánh BĐS'**
  String get compareTitle;

  /// No description provided for @compareEmpty.
  ///
  /// In vi, this message translates to:
  /// **'Không có BĐS để so sánh'**
  String get compareEmpty;

  /// No description provided for @compareCriteria.
  ///
  /// In vi, this message translates to:
  /// **'Tiêu chí'**
  String get compareCriteria;

  /// No description provided for @compareHouseFallback.
  ///
  /// In vi, this message translates to:
  /// **'BĐS'**
  String get compareHouseFallback;

  /// No description provided for @compareLabelPrice.
  ///
  /// In vi, this message translates to:
  /// **'Giá'**
  String get compareLabelPrice;

  /// No description provided for @compareLabelArea.
  ///
  /// In vi, this message translates to:
  /// **'Diện tích'**
  String get compareLabelArea;

  /// No description provided for @compareLabelPricePerSqm.
  ///
  /// In vi, this message translates to:
  /// **'Giá/m²'**
  String get compareLabelPricePerSqm;

  /// No description provided for @compareLabelLegal.
  ///
  /// In vi, this message translates to:
  /// **'Pháp lý'**
  String get compareLabelLegal;

  /// No description provided for @compareLabelBedrooms.
  ///
  /// In vi, this message translates to:
  /// **'Phòng ngủ'**
  String get compareLabelBedrooms;

  /// No description provided for @compareLabelBathrooms.
  ///
  /// In vi, this message translates to:
  /// **'Phòng tắm'**
  String get compareLabelBathrooms;

  /// No description provided for @compareLabelLocation.
  ///
  /// In vi, this message translates to:
  /// **'Khu vực'**
  String get compareLabelLocation;

  /// No description provided for @ctrContractor.
  ///
  /// In vi, this message translates to:
  /// **'Nhà thầu'**
  String get ctrContractor;

  /// No description provided for @ctrLoadFailed.
  ///
  /// In vi, this message translates to:
  /// **'Không tải được'**
  String get ctrLoadFailed;

  /// No description provided for @ctrRequestQuote.
  ///
  /// In vi, this message translates to:
  /// **'Yêu cầu báo giá'**
  String get ctrRequestQuote;

  /// No description provided for @ctrContractorRatingSubtitle.
  ///
  /// In vi, this message translates to:
  /// **'Nhà thầu · ⭐ {rating} ({count} đánh giá)'**
  String ctrContractorRatingSubtitle(Object rating, Object count);

  /// No description provided for @ctrTrustedUnit.
  ///
  /// In vi, this message translates to:
  /// **'Đơn vị tin cậy'**
  String get ctrTrustedUnit;

  /// No description provided for @ctrVerified.
  ///
  /// In vi, this message translates to:
  /// **'Đã xác minh'**
  String get ctrVerified;

  /// No description provided for @ctrCertVerified.
  ///
  /// In vi, this message translates to:
  /// **'Chứng chỉ hành nghề'**
  String get ctrCertVerified;

  /// No description provided for @ctrProjectsStat.
  ///
  /// In vi, this message translates to:
  /// **'Dự án'**
  String get ctrProjectsStat;

  /// No description provided for @ctrVerifiedLabel.
  ///
  /// In vi, this message translates to:
  /// **'Đã kiểm chứng'**
  String get ctrVerifiedLabel;

  /// No description provided for @ctrDesignFilesStat.
  ///
  /// In vi, this message translates to:
  /// **'File thiết kế'**
  String get ctrDesignFilesStat;

  /// No description provided for @ctrReviewsStat.
  ///
  /// In vi, this message translates to:
  /// **'Đánh giá'**
  String get ctrReviewsStat;

  /// No description provided for @ctrYearsExperience.
  ///
  /// In vi, this message translates to:
  /// **'{yrs} năm kinh nghiệm'**
  String ctrYearsExperience(Object yrs);

  /// No description provided for @ctrEstablished.
  ///
  /// In vi, this message translates to:
  /// **'Thành lập {year}'**
  String ctrEstablished(Object year);

  /// No description provided for @ctrTeamSize.
  ///
  /// In vi, this message translates to:
  /// **'Đội {team} người'**
  String ctrTeamSize(Object team);

  /// No description provided for @ctrWebsite.
  ///
  /// In vi, this message translates to:
  /// **'Website'**
  String get ctrWebsite;

  /// No description provided for @ctrPortfolioTitle.
  ///
  /// In vi, this message translates to:
  /// **'DỰ ÁN ĐÃ THỰC HIỆN'**
  String get ctrPortfolioTitle;

  /// No description provided for @ctrNoProjects.
  ///
  /// In vi, this message translates to:
  /// **'Chưa có dự án'**
  String get ctrNoProjects;

  /// No description provided for @ctrNoProjectsSubtitle.
  ///
  /// In vi, this message translates to:
  /// **'Đơn vị chưa đăng công trình nào. Gửi yêu cầu để được tư vấn trực tiếp.'**
  String get ctrNoProjectsSubtitle;

  /// No description provided for @ctrFilterAll.
  ///
  /// In vi, this message translates to:
  /// **'Tất cả'**
  String get ctrFilterAll;

  /// No description provided for @ctrFilterHasFiles.
  ///
  /// In vi, this message translates to:
  /// **'Có file thiết kế'**
  String get ctrFilterHasFiles;

  /// No description provided for @ctrNoMatchFilter.
  ///
  /// In vi, this message translates to:
  /// **'Không có dự án khớp bộ lọc.'**
  String get ctrNoMatchFilter;

  /// No description provided for @ctrProject.
  ///
  /// In vi, this message translates to:
  /// **'Dự án'**
  String get ctrProject;

  /// No description provided for @ctrFilesCount.
  ///
  /// In vi, this message translates to:
  /// **'{count} file'**
  String ctrFilesCount(Object count);

  /// No description provided for @ctrReviewsTitle.
  ///
  /// In vi, this message translates to:
  /// **'ĐÁNH GIÁ ({count})'**
  String ctrReviewsTitle(Object count);

  /// No description provided for @ctrNoReviews.
  ///
  /// In vi, this message translates to:
  /// **'Chưa có đánh giá'**
  String get ctrNoReviews;

  /// No description provided for @ctrNoReviewsSubtitle.
  ///
  /// In vi, this message translates to:
  /// **'Hãy là khách hàng đầu tiên đánh giá đơn vị này.'**
  String get ctrNoReviewsSubtitle;

  /// No description provided for @ctrCriteriaQuality.
  ///
  /// In vi, this message translates to:
  /// **'Chất lượng'**
  String get ctrCriteriaQuality;

  /// No description provided for @ctrCriteriaTimeliness.
  ///
  /// In vi, this message translates to:
  /// **'Tiến độ'**
  String get ctrCriteriaTimeliness;

  /// No description provided for @ctrCriteriaCommunication.
  ///
  /// In vi, this message translates to:
  /// **'Giao tiếp'**
  String get ctrCriteriaCommunication;

  /// No description provided for @ctrCriteriaBudget.
  ///
  /// In vi, this message translates to:
  /// **'Ngân sách'**
  String get ctrCriteriaBudget;

  /// No description provided for @ctrCriteriaProfessionalism.
  ///
  /// In vi, this message translates to:
  /// **'Chuyên nghiệp'**
  String get ctrCriteriaProfessionalism;

  /// No description provided for @ctrCriteriaBreakdownTitle.
  ///
  /// In vi, this message translates to:
  /// **'CHI TIẾT THEO TIÊU CHÍ'**
  String get ctrCriteriaBreakdownTitle;

  /// No description provided for @ctrReviewCount.
  ///
  /// In vi, this message translates to:
  /// **'{count} đánh giá'**
  String ctrReviewCount(Object count);

  /// No description provided for @ctrNotEnoughReviews.
  ///
  /// In vi, this message translates to:
  /// **'Chưa đủ đánh giá để xếp hạng chi tiết.'**
  String get ctrNotEnoughReviews;

  /// No description provided for @ctrUser.
  ///
  /// In vi, this message translates to:
  /// **'Người dùng'**
  String get ctrUser;

  /// No description provided for @cwLoginToJoinCommunity.
  ///
  /// In vi, this message translates to:
  /// **'Đăng nhập để tham gia cộng đồng xây dựng.'**
  String get cwLoginToJoinCommunity;

  /// No description provided for @cwConstructionReels.
  ///
  /// In vi, this message translates to:
  /// **'Reels xây dựng'**
  String get cwConstructionReels;

  /// No description provided for @cwPostDeleted.
  ///
  /// In vi, this message translates to:
  /// **'Đã xoá bài'**
  String get cwPostDeleted;

  /// No description provided for @cwPostRemovedModeration.
  ///
  /// In vi, this message translates to:
  /// **'Đã gỡ bài (kiểm duyệt)'**
  String get cwPostRemovedModeration;

  /// No description provided for @cwErrorWithMsg.
  ///
  /// In vi, this message translates to:
  /// **'Lỗi: {msg}'**
  String cwErrorWithMsg(Object msg);

  /// No description provided for @cwProject.
  ///
  /// In vi, this message translates to:
  /// **'Công trình'**
  String get cwProject;

  /// No description provided for @cwLocationPin.
  ///
  /// In vi, this message translates to:
  /// **'📍 {location}'**
  String cwLocationPin(Object location);

  /// No description provided for @cwViewContractor.
  ///
  /// In vi, this message translates to:
  /// **'Xem đơn vị'**
  String get cwViewContractor;

  /// No description provided for @cwShare.
  ///
  /// In vi, this message translates to:
  /// **'Chia sẻ'**
  String get cwShare;

  /// No description provided for @cwCopyLinkFromBrowser.
  ///
  /// In vi, this message translates to:
  /// **'Sao chép liên kết từ trình duyệt'**
  String get cwCopyLinkFromBrowser;

  /// No description provided for @cwNeedConstruction.
  ///
  /// In vi, this message translates to:
  /// **'Cần xây dựng'**
  String get cwNeedConstruction;

  /// No description provided for @cwQuote.
  ///
  /// In vi, this message translates to:
  /// **'Báo giá'**
  String get cwQuote;

  /// No description provided for @cwNeedContractorProfile.
  ///
  /// In vi, this message translates to:
  /// **'Bạn cần có hồ sơ đơn vị để báo giá (mục Cá nhân → Kênh đơn vị).'**
  String get cwNeedContractorProfile;

  /// No description provided for @cwQuoteSent.
  ///
  /// In vi, this message translates to:
  /// **'Đã gửi báo giá cho khách'**
  String get cwQuoteSent;

  /// No description provided for @cwContractor.
  ///
  /// In vi, this message translates to:
  /// **'Đơn vị'**
  String get cwContractor;

  /// No description provided for @cwCatAll.
  ///
  /// In vi, this message translates to:
  /// **'Tất cả'**
  String get cwCatAll;

  /// No description provided for @cwCatDesign.
  ///
  /// In vi, this message translates to:
  /// **'Thiết kế'**
  String get cwCatDesign;

  /// No description provided for @cwCatBuild.
  ///
  /// In vi, this message translates to:
  /// **'Xây dựng'**
  String get cwCatBuild;

  /// No description provided for @cwCatInterior.
  ///
  /// In vi, this message translates to:
  /// **'Nội thất'**
  String get cwCatInterior;

  /// No description provided for @cwCatIndustrial.
  ///
  /// In vi, this message translates to:
  /// **'Công nghiệp'**
  String get cwCatIndustrial;

  /// No description provided for @cwFeaturedContractors.
  ///
  /// In vi, this message translates to:
  /// **'Đơn vị nổi bật'**
  String get cwFeaturedContractors;

  /// No description provided for @cwViewAllDesignsGrid.
  ///
  /// In vi, this message translates to:
  /// **'Xem tất cả thiết kế theo lưới'**
  String get cwViewAllDesignsGrid;

  /// No description provided for @cwNoContentInCategory.
  ///
  /// In vi, this message translates to:
  /// **'Chưa có nội dung ở mục {category}'**
  String cwNoContentInCategory(Object category);

  /// No description provided for @cwBeFirstToShare.
  ///
  /// In vi, this message translates to:
  /// **'Hãy là người đầu tiên chia sẻ dự án hoặc đăng yêu cầu.'**
  String get cwBeFirstToShare;

  /// No description provided for @cwSendQuote.
  ///
  /// In vi, this message translates to:
  /// **'Gửi báo giá'**
  String get cwSendQuote;

  /// No description provided for @cwAmountVnd.
  ///
  /// In vi, this message translates to:
  /// **'Số tiền (VND) *'**
  String get cwAmountVnd;

  /// No description provided for @cwAmountHint.
  ///
  /// In vi, this message translates to:
  /// **'VD: 1500000000'**
  String get cwAmountHint;

  /// No description provided for @cwNoteOptional.
  ///
  /// In vi, this message translates to:
  /// **'Ghi chú (tùy chọn)'**
  String get cwNoteOptional;

  /// No description provided for @cwSend.
  ///
  /// In vi, this message translates to:
  /// **'Gửi'**
  String get cwSend;

  /// No description provided for @designAppBarEyebrow.
  ///
  /// In vi, this message translates to:
  /// **'XÂY DỰNG'**
  String get designAppBarEyebrow;

  /// No description provided for @designLibraryTitle.
  ///
  /// In vi, this message translates to:
  /// **'Thư viện thiết kế'**
  String get designLibraryTitle;

  /// No description provided for @designPostDesign.
  ///
  /// In vi, this message translates to:
  /// **'Đăng thiết kế'**
  String get designPostDesign;

  /// No description provided for @designAll.
  ///
  /// In vi, this message translates to:
  /// **'Tất cả'**
  String get designAll;

  /// No description provided for @designHouseType.
  ///
  /// In vi, this message translates to:
  /// **'Loại nhà'**
  String get designHouseType;

  /// No description provided for @designStyle.
  ///
  /// In vi, this message translates to:
  /// **'Phong cách'**
  String get designStyle;

  /// No description provided for @designFloors.
  ///
  /// In vi, this message translates to:
  /// **'Số tầng'**
  String get designFloors;

  /// No description provided for @designFloorsValue.
  ///
  /// In vi, this message translates to:
  /// **'{floors} tầng'**
  String designFloorsValue(Object floors);

  /// No description provided for @designBedroomsLabel.
  ///
  /// In vi, this message translates to:
  /// **'Phòng ngủ'**
  String get designBedroomsLabel;

  /// No description provided for @designBedroomsTitle.
  ///
  /// In vi, this message translates to:
  /// **'Số phòng ngủ'**
  String get designBedroomsTitle;

  /// No description provided for @designBedroomsShort.
  ///
  /// In vi, this message translates to:
  /// **'{bedrooms} PN'**
  String designBedroomsShort(Object bedrooms);

  /// No description provided for @designBedroomsValue.
  ///
  /// In vi, this message translates to:
  /// **'{bedrooms} phòng ngủ'**
  String designBedroomsValue(Object bedrooms);

  /// No description provided for @designAreaValue.
  ///
  /// In vi, this message translates to:
  /// **'{area}m²'**
  String designAreaValue(Object area);

  /// No description provided for @designVerified.
  ///
  /// In vi, this message translates to:
  /// **'Đã kiểm chứng'**
  String get designVerified;

  /// No description provided for @designClearFilters.
  ///
  /// In vi, this message translates to:
  /// **'Xoá lọc'**
  String get designClearFilters;

  /// No description provided for @designLoadError.
  ///
  /// In vi, this message translates to:
  /// **'Không tải được thư viện'**
  String get designLoadError;

  /// No description provided for @designLoadErrorSubtitle.
  ///
  /// In vi, this message translates to:
  /// **'Kiểm tra kết nối rồi thử lại.'**
  String get designLoadErrorSubtitle;

  /// No description provided for @designRetry.
  ///
  /// In vi, this message translates to:
  /// **'Thử lại'**
  String get designRetry;

  /// No description provided for @designEmptyFilteredTitle.
  ///
  /// In vi, this message translates to:
  /// **'Không có mẫu phù hợp'**
  String get designEmptyFilteredTitle;

  /// No description provided for @designEmptyTitle.
  ///
  /// In vi, this message translates to:
  /// **'Chưa có thiết kế nào'**
  String get designEmptyTitle;

  /// No description provided for @designEmptyFilteredSubtitle.
  ///
  /// In vi, this message translates to:
  /// **'Thử bỏ bớt bộ lọc để xem nhiều mẫu hơn.'**
  String get designEmptyFilteredSubtitle;

  /// No description provided for @designEmptySubtitle.
  ///
  /// In vi, this message translates to:
  /// **'Các đơn vị thiết kế sẽ đăng mẫu nhà tại đây. Quay lại sau nhé.'**
  String get designEmptySubtitle;

  /// No description provided for @designPostYourDesign.
  ///
  /// In vi, this message translates to:
  /// **'Đăng thiết kế của bạn'**
  String get designPostYourDesign;

  /// No description provided for @designEndOfList.
  ///
  /// In vi, this message translates to:
  /// **'— Đã hết —'**
  String get designEndOfList;

  /// No description provided for @designDefaultTitle.
  ///
  /// In vi, this message translates to:
  /// **'Mẫu thiết kế'**
  String get designDefaultTitle;

  /// No description provided for @designUnitFallback.
  ///
  /// In vi, this message translates to:
  /// **'Đơn vị'**
  String get designUnitFallback;

  /// No description provided for @designDesignUnitFallback.
  ///
  /// In vi, this message translates to:
  /// **'Đơn vị thiết kế'**
  String get designDesignUnitFallback;

  /// No description provided for @editProfUploadError.
  ///
  /// In vi, this message translates to:
  /// **'Lỗi upload: {error}'**
  String editProfUploadError(Object error);

  /// No description provided for @editProfCoverChanged.
  ///
  /// In vi, this message translates to:
  /// **'Đã đổi ảnh bìa'**
  String get editProfCoverChanged;

  /// No description provided for @editProfCoverChangeFailed.
  ///
  /// In vi, this message translates to:
  /// **'Đổi ảnh bìa thất bại'**
  String get editProfCoverChangeFailed;

  /// No description provided for @editProfPickBirthday.
  ///
  /// In vi, this message translates to:
  /// **'Chọn ngày sinh'**
  String get editProfPickBirthday;

  /// No description provided for @editProfWaitUpload.
  ///
  /// In vi, this message translates to:
  /// **'Đợi upload ảnh xong'**
  String get editProfWaitUpload;

  /// No description provided for @editProfSaved.
  ///
  /// In vi, this message translates to:
  /// **'Đã cập nhật hồ sơ'**
  String get editProfSaved;

  /// No description provided for @editProfUpdateFailed.
  ///
  /// In vi, this message translates to:
  /// **'Cập nhật thất bại'**
  String get editProfUpdateFailed;

  /// No description provided for @editProfEmailInUse.
  ///
  /// In vi, this message translates to:
  /// **'Email đã được sử dụng'**
  String get editProfEmailInUse;

  /// No description provided for @editProfEyebrow.
  ///
  /// In vi, this message translates to:
  /// **'Tài khoản'**
  String get editProfEyebrow;

  /// No description provided for @editProfChangeCover.
  ///
  /// In vi, this message translates to:
  /// **'Đổi ảnh bìa (chủ nhà)'**
  String get editProfChangeCover;

  /// No description provided for @editProfSectionPersonal.
  ///
  /// In vi, this message translates to:
  /// **'Thông tin cá nhân'**
  String get editProfSectionPersonal;

  /// No description provided for @editProfFullName.
  ///
  /// In vi, this message translates to:
  /// **'Họ và tên'**
  String get editProfFullName;

  /// No description provided for @editProfRequired.
  ///
  /// In vi, this message translates to:
  /// **'Bắt buộc'**
  String get editProfRequired;

  /// No description provided for @editProfEmailHelper.
  ///
  /// In vi, this message translates to:
  /// **'Email dùng để đăng nhập'**
  String get editProfEmailHelper;

  /// No description provided for @editProfEmailInvalid.
  ///
  /// In vi, this message translates to:
  /// **'Email không hợp lệ'**
  String get editProfEmailInvalid;

  /// No description provided for @editProfPhone.
  ///
  /// In vi, this message translates to:
  /// **'Số điện thoại'**
  String get editProfPhone;

  /// No description provided for @editProfSectionIntro.
  ///
  /// In vi, this message translates to:
  /// **'Giới thiệu'**
  String get editProfSectionIntro;

  /// No description provided for @editProfBioLabel.
  ///
  /// In vi, this message translates to:
  /// **'Giới thiệu bản thân'**
  String get editProfBioLabel;

  /// No description provided for @editProfBioHint.
  ///
  /// In vi, this message translates to:
  /// **'VD: Tôi là chủ nhà tại Quận 1, 5 năm cho thuê căn hộ...'**
  String get editProfBioHint;

  /// No description provided for @editProfSectionVerify.
  ///
  /// In vi, this message translates to:
  /// **'Xác thực (tuỳ chọn)'**
  String get editProfSectionVerify;

  /// No description provided for @editProfIdNumber.
  ///
  /// In vi, this message translates to:
  /// **'CMND / CCCD'**
  String get editProfIdNumber;

  /// No description provided for @editProfIdHelper.
  ///
  /// In vi, this message translates to:
  /// **'Để trống nếu chưa muốn xác thực'**
  String get editProfIdHelper;

  /// No description provided for @editProfSave.
  ///
  /// In vi, this message translates to:
  /// **'Lưu thay đổi'**
  String get editProfSave;

  /// No description provided for @editProfNotSelected.
  ///
  /// In vi, this message translates to:
  /// **'Chưa chọn'**
  String get editProfNotSelected;

  /// No description provided for @editProfBirthday.
  ///
  /// In vi, this message translates to:
  /// **'Ngày sinh'**
  String get editProfBirthday;

  /// No description provided for @editProfAge.
  ///
  /// In vi, this message translates to:
  /// **'Tuổi: {age}'**
  String editProfAge(Object age);

  /// No description provided for @hdBack.
  ///
  /// In vi, this message translates to:
  /// **'Quay lại'**
  String get hdBack;

  /// No description provided for @hdShare.
  ///
  /// In vi, this message translates to:
  /// **'Chia sẻ'**
  String get hdShare;

  /// No description provided for @hdLinkCopied.
  ///
  /// In vi, this message translates to:
  /// **'Đã sao chép link'**
  String get hdLinkCopied;

  /// No description provided for @hdImageLabel.
  ///
  /// In vi, this message translates to:
  /// **'{title} — ảnh {n}'**
  String hdImageLabel(Object title, Object n);

  /// No description provided for @hdPerMonth.
  ///
  /// In vi, this message translates to:
  /// **'/tháng'**
  String get hdPerMonth;

  /// No description provided for @hdLoanCalc.
  ///
  /// In vi, this message translates to:
  /// **'Tính khoản vay ngân hàng'**
  String get hdLoanCalc;

  /// No description provided for @hdBedroomsShort.
  ///
  /// In vi, this message translates to:
  /// **'{n} PN'**
  String hdBedroomsShort(Object n);

  /// No description provided for @hdBathroomsShort.
  ///
  /// In vi, this message translates to:
  /// **'{n} PT'**
  String hdBathroomsShort(Object n);

  /// No description provided for @hdAreaSqm.
  ///
  /// In vi, this message translates to:
  /// **'{area} m²'**
  String hdAreaSqm(Object area);

  /// No description provided for @hdDescriptionTitle.
  ///
  /// In vi, this message translates to:
  /// **'MÔ TẢ CHI TIẾT'**
  String get hdDescriptionTitle;

  /// No description provided for @hdHostInfoTitle.
  ///
  /// In vi, this message translates to:
  /// **'THÔNG TIN CHỦ NHÀ'**
  String get hdHostInfoTitle;

  /// No description provided for @hdLoginToSave.
  ///
  /// In vi, this message translates to:
  /// **'Đăng nhập để lưu tin yêu thích.'**
  String get hdLoginToSave;

  /// No description provided for @hdFavUpdateFailed.
  ///
  /// In vi, this message translates to:
  /// **'Không thể cập nhật yêu thích'**
  String get hdFavUpdateFailed;

  /// No description provided for @hdApptApprovedTitle.
  ///
  /// In vi, this message translates to:
  /// **'Lịch xem đã được duyệt'**
  String get hdApptApprovedTitle;

  /// No description provided for @hdApptApprovedSub.
  ///
  /// In vi, this message translates to:
  /// **'{sched} · Vui lòng đến đúng giờ'**
  String hdApptApprovedSub(Object sched);

  /// No description provided for @hdApptRejectedTitle.
  ///
  /// In vi, this message translates to:
  /// **'Lịch xem bị từ chối'**
  String get hdApptRejectedTitle;

  /// No description provided for @hdApptRejectedSub.
  ///
  /// In vi, this message translates to:
  /// **'Bạn có thể chọn khung giờ khác'**
  String get hdApptRejectedSub;

  /// No description provided for @hdApptCancelledTitle.
  ///
  /// In vi, this message translates to:
  /// **'Bạn đã hủy lịch xem'**
  String get hdApptCancelledTitle;

  /// No description provided for @hdApptCancelledSub.
  ///
  /// In vi, this message translates to:
  /// **'Đặt lại nếu vẫn muốn xem nhà'**
  String get hdApptCancelledSub;

  /// No description provided for @hdApptCompletedTitle.
  ///
  /// In vi, this message translates to:
  /// **'Bạn đã xem nhà này'**
  String get hdApptCompletedTitle;

  /// No description provided for @hdApptLockedTitle.
  ///
  /// In vi, this message translates to:
  /// **'Phòng đã được chốt'**
  String get hdApptLockedTitle;

  /// No description provided for @hdApptPendingTitle.
  ///
  /// In vi, this message translates to:
  /// **'Bạn đã đặt lịch xem'**
  String get hdApptPendingTitle;

  /// No description provided for @hdApptPendingSub.
  ///
  /// In vi, this message translates to:
  /// **'{sched} · Đang chờ chủ nhà duyệt'**
  String hdApptPendingSub(Object sched);

  /// No description provided for @hdLegalRedBook.
  ///
  /// In vi, this message translates to:
  /// **'Sổ đỏ'**
  String get hdLegalRedBook;

  /// No description provided for @hdLegalPinkBook.
  ///
  /// In vi, this message translates to:
  /// **'Sổ hồng'**
  String get hdLegalPinkBook;

  /// No description provided for @hdLegalSaleContract.
  ///
  /// In vi, this message translates to:
  /// **'HĐ mua bán'**
  String get hdLegalSaleContract;

  /// No description provided for @hdLegalPending.
  ///
  /// In vi, this message translates to:
  /// **'Đang chờ sổ'**
  String get hdLegalPending;

  /// No description provided for @hdPricePerMonth.
  ///
  /// In vi, this message translates to:
  /// **'{s} triệu/tháng'**
  String hdPricePerMonth(Object s);

  /// No description provided for @hdSpecPrice.
  ///
  /// In vi, this message translates to:
  /// **'Mức giá'**
  String get hdSpecPrice;

  /// No description provided for @hdSpecArea.
  ///
  /// In vi, this message translates to:
  /// **'Diện tích'**
  String get hdSpecArea;

  /// No description provided for @hdSpecBedrooms.
  ///
  /// In vi, this message translates to:
  /// **'Số phòng ngủ'**
  String get hdSpecBedrooms;

  /// No description provided for @hdSpecBathrooms.
  ///
  /// In vi, this message translates to:
  /// **'Số phòng tắm, vệ sinh'**
  String get hdSpecBathrooms;

  /// No description provided for @hdSpecType.
  ///
  /// In vi, this message translates to:
  /// **'Loại hình'**
  String get hdSpecType;

  /// No description provided for @hdSpecLegal.
  ///
  /// In vi, this message translates to:
  /// **'Pháp lý'**
  String get hdSpecLegal;

  /// No description provided for @hdSpecFurniture.
  ///
  /// In vi, this message translates to:
  /// **'Nội thất'**
  String get hdSpecFurniture;

  /// No description provided for @hdRoomsCount.
  ///
  /// In vi, this message translates to:
  /// **'{n} phòng'**
  String hdRoomsCount(Object n);

  /// No description provided for @hdPropertySpecsTitle.
  ///
  /// In vi, this message translates to:
  /// **'ĐẶC ĐIỂM BẤT ĐỘNG SẢN'**
  String get hdPropertySpecsTitle;

  /// No description provided for @hdYourListing.
  ///
  /// In vi, this message translates to:
  /// **'Tin đăng của bạn'**
  String get hdYourListing;

  /// No description provided for @hdViewBooking.
  ///
  /// In vi, this message translates to:
  /// **'Xem lịch đã đặt'**
  String get hdViewBooking;

  /// No description provided for @hdRebookViewing.
  ///
  /// In vi, this message translates to:
  /// **'Đặt lại lịch xem'**
  String get hdRebookViewing;

  /// No description provided for @hdBookViewing.
  ///
  /// In vi, this message translates to:
  /// **'Đặt lịch xem nhà'**
  String get hdBookViewing;

  /// No description provided for @hdLoginToBook.
  ///
  /// In vi, this message translates to:
  /// **'Đăng nhập để đặt lịch xem nhà.'**
  String get hdLoginToBook;

  /// No description provided for @hdAreaHa.
  ///
  /// In vi, this message translates to:
  /// **'{area} ha'**
  String hdAreaHa(Object area);

  /// No description provided for @hdIndPower.
  ///
  /// In vi, this message translates to:
  /// **'Tải điện'**
  String get hdIndPower;

  /// No description provided for @hdPowerMva.
  ///
  /// In vi, this message translates to:
  /// **'{power} MVA'**
  String hdPowerMva(Object power);

  /// No description provided for @hdIndFireSafety.
  ///
  /// In vi, this message translates to:
  /// **'PCCC'**
  String get hdIndFireSafety;

  /// No description provided for @hdHas.
  ///
  /// In vi, this message translates to:
  /// **'Đã có'**
  String get hdHas;

  /// No description provided for @hdHasNot.
  ///
  /// In vi, this message translates to:
  /// **'Chưa có'**
  String get hdHasNot;

  /// No description provided for @hdIndLegal.
  ///
  /// In vi, this message translates to:
  /// **'Pháp lý KCN'**
  String get hdIndLegal;

  /// No description provided for @hdIndustrialSpecsTitle.
  ///
  /// In vi, this message translates to:
  /// **'THÔNG SỐ CÔNG NGHIỆP'**
  String get hdIndustrialSpecsTitle;

  /// No description provided for @hdForSale.
  ///
  /// In vi, this message translates to:
  /// **'Đang bán'**
  String get hdForSale;

  /// No description provided for @hdFull.
  ///
  /// In vi, this message translates to:
  /// **'Đã đủ'**
  String get hdFull;

  /// No description provided for @hdUnitsAvailable.
  ///
  /// In vi, this message translates to:
  /// **'Còn {available}/{total} phòng'**
  String hdUnitsAvailable(Object available, Object total);

  /// No description provided for @hdAvailable.
  ///
  /// In vi, this message translates to:
  /// **'Sẵn sàng'**
  String get hdAvailable;

  /// No description provided for @hdHost.
  ///
  /// In vi, this message translates to:
  /// **'Chủ nhà'**
  String get hdHost;

  /// No description provided for @hdHostVerifiedTooltip.
  ///
  /// In vi, this message translates to:
  /// **'Chủ nhà đã xác minh danh tính'**
  String get hdHostVerifiedTooltip;

  /// No description provided for @hdHostTrustedTooltip.
  ///
  /// In vi, this message translates to:
  /// **'Chủ nhà tin cậy: đánh giá cao, phản hồi nhanh'**
  String get hdHostTrustedTooltip;

  /// No description provided for @hdResponseTime.
  ///
  /// In vi, this message translates to:
  /// **'Phản hồi ~{h}h'**
  String hdResponseTime(Object h);

  /// No description provided for @hdHidden.
  ///
  /// In vi, this message translates to:
  /// **'· đã ẩn'**
  String get hdHidden;

  /// No description provided for @hdMessageHost.
  ///
  /// In vi, this message translates to:
  /// **'Nhắn tin với chủ nhà'**
  String get hdMessageHost;

  /// No description provided for @hdReviewsTitle.
  ///
  /// In vi, this message translates to:
  /// **'ĐÁNH GIÁ'**
  String get hdReviewsTitle;

  /// No description provided for @hdNoReviews.
  ///
  /// In vi, this message translates to:
  /// **'Chưa có đánh giá nào.'**
  String get hdNoReviews;

  /// No description provided for @hdViewAllReviews.
  ///
  /// In vi, this message translates to:
  /// **'Xem tất cả {count} đánh giá'**
  String hdViewAllReviews(Object count);

  /// No description provided for @hdUser.
  ///
  /// In vi, this message translates to:
  /// **'Người dùng'**
  String get hdUser;

  /// No description provided for @hubProviderChannel.
  ///
  /// In vi, this message translates to:
  /// **'Kênh đơn vị'**
  String get hubProviderChannel;

  /// No description provided for @hubEnterNameSelectService.
  ///
  /// In vi, this message translates to:
  /// **'Nhập tên đơn vị và chọn ít nhất 1 dịch vụ'**
  String get hubEnterNameSelectService;

  /// No description provided for @hubProfileSubmitted.
  ///
  /// In vi, this message translates to:
  /// **'Đã gửi hồ sơ. Chờ duyệt để hiển thị trong danh bạ.'**
  String get hubProfileSubmitted;

  /// No description provided for @hubErrorWithMsg.
  ///
  /// In vi, this message translates to:
  /// **'Lỗi: {error}'**
  String hubErrorWithMsg(Object error);

  /// No description provided for @hubBecomeProvider.
  ///
  /// In vi, this message translates to:
  /// **'Trở thành đơn vị'**
  String get hubBecomeProvider;

  /// No description provided for @hubRegisterService.
  ///
  /// In vi, this message translates to:
  /// **'Đăng ký cung cấp dịch vụ'**
  String get hubRegisterService;

  /// No description provided for @hubRegisterIntro.
  ///
  /// In vi, this message translates to:
  /// **'Đăng ký để nhận nhu cầu khách hàng và quảng bá đơn vị của bạn (thiết kế / xây dựng / nội thất).'**
  String get hubRegisterIntro;

  /// No description provided for @hubUnitName.
  ///
  /// In vi, this message translates to:
  /// **'Tên đơn vị *'**
  String get hubUnitName;

  /// No description provided for @hubUnitNameHint.
  ///
  /// In vi, this message translates to:
  /// **'VD: Kiến An Xây Dựng'**
  String get hubUnitNameHint;

  /// No description provided for @hubField.
  ///
  /// In vi, this message translates to:
  /// **'Lĩnh vực *'**
  String get hubField;

  /// No description provided for @hubOperatingArea.
  ///
  /// In vi, this message translates to:
  /// **'Khu vực hoạt động'**
  String get hubOperatingArea;

  /// No description provided for @hubSelectProvince.
  ///
  /// In vi, this message translates to:
  /// **'Chọn tỉnh/thành'**
  String get hubSelectProvince;

  /// No description provided for @hubIntro.
  ///
  /// In vi, this message translates to:
  /// **'Giới thiệu'**
  String get hubIntro;

  /// No description provided for @hubIntroHint.
  ///
  /// In vi, this message translates to:
  /// **'Kinh nghiệm, thế mạnh, quy mô...'**
  String get hubIntroHint;

  /// No description provided for @hubContactPhone.
  ///
  /// In vi, this message translates to:
  /// **'Số điện thoại liên hệ'**
  String get hubContactPhone;

  /// No description provided for @hubSubmitRegistration.
  ///
  /// In vi, this message translates to:
  /// **'Gửi hồ sơ đăng ký'**
  String get hubSubmitRegistration;

  /// No description provided for @hubOwnerContact.
  ///
  /// In vi, this message translates to:
  /// **'Liên hệ chủ nhà'**
  String get hubOwnerContact;

  /// No description provided for @hubNameLabel.
  ///
  /// In vi, this message translates to:
  /// **'Tên: {name}'**
  String hubNameLabel(Object name);

  /// No description provided for @hubPhoneLabel.
  ///
  /// In vi, this message translates to:
  /// **'SĐT: {phone}'**
  String hubPhoneLabel(Object phone);

  /// No description provided for @hubClose.
  ///
  /// In vi, this message translates to:
  /// **'Đóng'**
  String get hubClose;

  /// No description provided for @hubOwnerNotShared.
  ///
  /// In vi, this message translates to:
  /// **'Chủ nhà chưa chia sẻ liên hệ. Vui lòng chờ.'**
  String get hubOwnerNotShared;

  /// No description provided for @hubCantViewContact.
  ///
  /// In vi, this message translates to:
  /// **'Không xem được liên hệ: {msg}'**
  String hubCantViewContact(Object msg);

  /// No description provided for @hubEditProfile.
  ///
  /// In vi, this message translates to:
  /// **'Sửa hồ sơ đơn vị'**
  String get hubEditProfile;

  /// No description provided for @hubAddCover.
  ///
  /// In vi, this message translates to:
  /// **'Thêm ảnh bìa'**
  String get hubAddCover;

  /// No description provided for @hubChangeLogo.
  ///
  /// In vi, this message translates to:
  /// **'Đổi logo đơn vị'**
  String get hubChangeLogo;

  /// No description provided for @hubPhone.
  ///
  /// In vi, this message translates to:
  /// **'Số điện thoại'**
  String get hubPhone;

  /// No description provided for @hubWebsite.
  ///
  /// In vi, this message translates to:
  /// **'Website (nếu có)'**
  String get hubWebsite;

  /// No description provided for @hubYearEstablished.
  ///
  /// In vi, this message translates to:
  /// **'Năm thành lập'**
  String get hubYearEstablished;

  /// No description provided for @hubTeamSize.
  ///
  /// In vi, this message translates to:
  /// **'Quy mô đội'**
  String get hubTeamSize;

  /// No description provided for @hubPeopleSuffix.
  ///
  /// In vi, this message translates to:
  /// **'{size} người'**
  String hubPeopleSuffix(Object size);

  /// No description provided for @hubCertNumber.
  ///
  /// In vi, this message translates to:
  /// **'Số chứng chỉ hành nghề (nếu có)'**
  String get hubCertNumber;

  /// No description provided for @hubCertHelper.
  ///
  /// In vi, this message translates to:
  /// **'Quản trị sẽ đối chiếu rồi cấp huy hiệu'**
  String get hubCertHelper;

  /// No description provided for @hubCancel.
  ///
  /// In vi, this message translates to:
  /// **'Huỷ'**
  String get hubCancel;

  /// No description provided for @hubSave.
  ///
  /// In vi, this message translates to:
  /// **'Lưu'**
  String get hubSave;

  /// No description provided for @hubNameRequired.
  ///
  /// In vi, this message translates to:
  /// **'Tên đơn vị không được trống'**
  String get hubNameRequired;

  /// No description provided for @hubProfileUpdated.
  ///
  /// In vi, this message translates to:
  /// **'Đã cập nhật hồ sơ'**
  String get hubProfileUpdated;

  /// No description provided for @hubDeleteProjectTitle.
  ///
  /// In vi, this message translates to:
  /// **'Xoá công trình?'**
  String get hubDeleteProjectTitle;

  /// No description provided for @hubDeleteProjectConfirm.
  ///
  /// In vi, this message translates to:
  /// **'Xoá \"{title}\" khỏi hồ sơ? Không hoàn tác được.'**
  String hubDeleteProjectConfirm(Object title);

  /// No description provided for @hubThisProject.
  ///
  /// In vi, this message translates to:
  /// **'công trình này'**
  String get hubThisProject;

  /// No description provided for @hubDelete.
  ///
  /// In vi, this message translates to:
  /// **'Xoá'**
  String get hubDelete;

  /// No description provided for @hubDeleted.
  ///
  /// In vi, this message translates to:
  /// **'Đã xoá'**
  String get hubDeleted;

  /// No description provided for @hubImageUploadFailed.
  ///
  /// In vi, this message translates to:
  /// **'Không tải được ảnh: {error}'**
  String hubImageUploadFailed(Object error);

  /// No description provided for @hubQuoteSent.
  ///
  /// In vi, this message translates to:
  /// **'Đã gửi báo giá cho khách'**
  String get hubQuoteSent;

  /// No description provided for @hubUnit.
  ///
  /// In vi, this message translates to:
  /// **'Đơn vị'**
  String get hubUnit;

  /// No description provided for @hubActive.
  ///
  /// In vi, this message translates to:
  /// **'Đang hoạt động'**
  String get hubActive;

  /// No description provided for @hubPendingApproval.
  ///
  /// In vi, this message translates to:
  /// **'Chờ duyệt'**
  String get hubPendingApproval;

  /// No description provided for @hubCertificate.
  ///
  /// In vi, this message translates to:
  /// **'Chứng chỉ'**
  String get hubCertificate;

  /// No description provided for @hubPendingNote.
  ///
  /// In vi, this message translates to:
  /// **'Hồ sơ đang chờ quản trị duyệt. Bạn vẫn xem được nhu cầu và gửi báo giá; hồ sơ sẽ hiển thị trong danh bạ sau khi duyệt.'**
  String get hubPendingNote;

  /// No description provided for @hubEditProfileShort.
  ///
  /// In vi, this message translates to:
  /// **'Sửa hồ sơ'**
  String get hubEditProfileShort;

  /// No description provided for @hubPostProject.
  ///
  /// In vi, this message translates to:
  /// **'Đăng công trình'**
  String get hubPostProject;

  /// No description provided for @hubMatchingNeeds.
  ///
  /// In vi, this message translates to:
  /// **'NHU CẦU PHÙ HỢP'**
  String get hubMatchingNeeds;

  /// No description provided for @hubNoMatchingNeeds.
  ///
  /// In vi, this message translates to:
  /// **'Chưa có nhu cầu phù hợp. Quay lại sau nhé.'**
  String get hubNoMatchingNeeds;

  /// No description provided for @hubMyQuotes.
  ///
  /// In vi, this message translates to:
  /// **'BÁO GIÁ CỦA TÔI'**
  String get hubMyQuotes;

  /// No description provided for @hubProjectsDesigns.
  ///
  /// In vi, this message translates to:
  /// **'CÔNG TRÌNH & MẪU THIẾT KẾ'**
  String get hubProjectsDesigns;

  /// No description provided for @hubNoProjects.
  ///
  /// In vi, this message translates to:
  /// **'Chưa có công trình nào'**
  String get hubNoProjects;

  /// No description provided for @hubNoProjectsSub.
  ///
  /// In vi, this message translates to:
  /// **'Đăng công trình đã làm hoặc mẫu thiết kế để khách thấy năng lực của bạn.'**
  String get hubNoProjectsSub;

  /// No description provided for @hubPostFirstProject.
  ///
  /// In vi, this message translates to:
  /// **'Đăng công trình đầu tiên'**
  String get hubPostFirstProject;

  /// No description provided for @hubService.
  ///
  /// In vi, this message translates to:
  /// **'Dịch vụ'**
  String get hubService;

  /// No description provided for @hubContactsYou.
  ///
  /// In vi, this message translates to:
  /// **'Liên hệ bạn'**
  String get hubContactsYou;

  /// No description provided for @hubSendQuote.
  ///
  /// In vi, this message translates to:
  /// **'Gửi báo giá'**
  String get hubSendQuote;

  /// No description provided for @hubWon.
  ///
  /// In vi, this message translates to:
  /// **'Đã thắng'**
  String get hubWon;

  /// No description provided for @hubNotSelected.
  ///
  /// In vi, this message translates to:
  /// **'Không được chọn'**
  String get hubNotSelected;

  /// No description provided for @hubWaiting.
  ///
  /// In vi, this message translates to:
  /// **'Đang chờ'**
  String get hubWaiting;

  /// No description provided for @hubRequest.
  ///
  /// In vi, this message translates to:
  /// **'Yêu cầu'**
  String get hubRequest;

  /// No description provided for @hubQuoteAmount.
  ///
  /// In vi, this message translates to:
  /// **'Báo giá: {amount}'**
  String hubQuoteAmount(Object amount);

  /// No description provided for @hubMilestoneLine.
  ///
  /// In vi, this message translates to:
  /// **'• {label} ({percent}%): {amount}'**
  String hubMilestoneLine(Object label, Object percent, Object amount);

  /// No description provided for @hubViewContact.
  ///
  /// In vi, this message translates to:
  /// **'Xem liên hệ'**
  String get hubViewContact;

  /// No description provided for @hubWaitOwnerShare.
  ///
  /// In vi, this message translates to:
  /// **'Chờ chủ nhà chia sẻ liên hệ'**
  String get hubWaitOwnerShare;

  /// No description provided for @hubBillion.
  ///
  /// In vi, this message translates to:
  /// **'tỷ'**
  String get hubBillion;

  /// No description provided for @hubMillion.
  ///
  /// In vi, this message translates to:
  /// **'triệu'**
  String get hubMillion;

  /// No description provided for @hubDong.
  ///
  /// In vi, this message translates to:
  /// **'đ'**
  String get hubDong;

  /// No description provided for @hubProject.
  ///
  /// In vi, this message translates to:
  /// **'Công trình'**
  String get hubProject;

  /// No description provided for @hubVerified.
  ///
  /// In vi, this message translates to:
  /// **'Đã kiểm chứng'**
  String get hubVerified;

  /// No description provided for @hubSelfPosted.
  ///
  /// In vi, this message translates to:
  /// **'Tự đăng'**
  String get hubSelfPosted;

  /// No description provided for @hubDesignFiles.
  ///
  /// In vi, this message translates to:
  /// **'{count} file thiết kế'**
  String hubDesignFiles(Object count);

  /// No description provided for @hubEdit.
  ///
  /// In vi, this message translates to:
  /// **'Sửa'**
  String get hubEdit;

  /// No description provided for @hubAmount.
  ///
  /// In vi, this message translates to:
  /// **'Số tiền (VND) *'**
  String get hubAmount;

  /// No description provided for @hubAmountHint.
  ///
  /// In vi, this message translates to:
  /// **'VD: 1500000000'**
  String get hubAmountHint;

  /// No description provided for @hubNoteOptional.
  ///
  /// In vi, this message translates to:
  /// **'Ghi chú (tùy chọn)'**
  String get hubNoteOptional;

  /// No description provided for @hubSplitStages.
  ///
  /// In vi, this message translates to:
  /// **'Chia theo giai đoạn (30/20/20/30)'**
  String get hubSplitStages;

  /// No description provided for @hubStagesSubtitle.
  ///
  /// In vi, this message translates to:
  /// **'Đặt cọc · Concept · Kỹ thuật · Bàn giao'**
  String get hubStagesSubtitle;

  /// No description provided for @hubSend.
  ///
  /// In vi, this message translates to:
  /// **'Gửi'**
  String get hubSend;

  /// No description provided for @myReqTitle.
  ///
  /// In vi, this message translates to:
  /// **'Yêu cầu dịch vụ của tôi'**
  String get myReqTitle;

  /// No description provided for @myReqEmpty.
  ///
  /// In vi, this message translates to:
  /// **'Bạn chưa đặt dịch vụ nào'**
  String get myReqEmpty;

  /// No description provided for @myReqContactSharedToast.
  ///
  /// In vi, this message translates to:
  /// **'Đã chia sẻ số điện thoại cho đơn vị'**
  String get myReqContactSharedToast;

  /// No description provided for @myReqShareError.
  ///
  /// In vi, this message translates to:
  /// **'Không chia sẻ được: {error}'**
  String myReqShareError(Object error);

  /// No description provided for @myReqQuoteAccepted.
  ///
  /// In vi, this message translates to:
  /// **'Đã chấp nhận báo giá'**
  String get myReqQuoteAccepted;

  /// No description provided for @myReqAcceptError.
  ///
  /// In vi, this message translates to:
  /// **'Không thể chấp nhận: {error}'**
  String myReqAcceptError(Object error);

  /// No description provided for @myReqReviewThanks.
  ///
  /// In vi, this message translates to:
  /// **'Cảm ơn đánh giá của bạn!'**
  String get myReqReviewThanks;

  /// No description provided for @myReqReviewError.
  ///
  /// In vi, this message translates to:
  /// **'Lỗi: {error}'**
  String myReqReviewError(Object error);

  /// No description provided for @myReqServiceDesign.
  ///
  /// In vi, this message translates to:
  /// **'Thiết kế'**
  String get myReqServiceDesign;

  /// No description provided for @myReqServiceBuild.
  ///
  /// In vi, this message translates to:
  /// **'Xây dựng'**
  String get myReqServiceBuild;

  /// No description provided for @myReqServiceInterior.
  ///
  /// In vi, this message translates to:
  /// **'Nội thất'**
  String get myReqServiceInterior;

  /// No description provided for @myReqServiceDefault.
  ///
  /// In vi, this message translates to:
  /// **'Dịch vụ'**
  String get myReqServiceDefault;

  /// No description provided for @myReqStatusNew.
  ///
  /// In vi, this message translates to:
  /// **'Đã gửi'**
  String get myReqStatusNew;

  /// No description provided for @myReqStatusAssigned.
  ///
  /// In vi, this message translates to:
  /// **'Đã kết nối đơn vị'**
  String get myReqStatusAssigned;

  /// No description provided for @myReqStatusQuoted.
  ///
  /// In vi, this message translates to:
  /// **'Đã có báo giá'**
  String get myReqStatusQuoted;

  /// No description provided for @myReqStatusWon.
  ///
  /// In vi, this message translates to:
  /// **'Đã chốt'**
  String get myReqStatusWon;

  /// No description provided for @myReqStatusClosed.
  ///
  /// In vi, this message translates to:
  /// **'Đã đóng'**
  String get myReqStatusClosed;

  /// No description provided for @myReqNoQuotes.
  ///
  /// In vi, this message translates to:
  /// **'Chưa có báo giá. Đơn vị sẽ phản hồi sớm.'**
  String get myReqNoQuotes;

  /// No description provided for @myReqContractorDefault.
  ///
  /// In vi, this message translates to:
  /// **'Đơn vị'**
  String get myReqContractorDefault;

  /// No description provided for @myReqQuoteAmount.
  ///
  /// In vi, this message translates to:
  /// **'Báo giá: {amount}'**
  String myReqQuoteAmount(Object amount);

  /// No description provided for @myReqSelectedContractor.
  ///
  /// In vi, this message translates to:
  /// **'Đã chọn đơn vị này'**
  String get myReqSelectedContractor;

  /// No description provided for @myReqReview.
  ///
  /// In vi, this message translates to:
  /// **'Đánh giá'**
  String get myReqReview;

  /// No description provided for @myReqContactSharedLabel.
  ///
  /// In vi, this message translates to:
  /// **'Đã chia sẻ liên hệ cho đơn vị'**
  String get myReqContactSharedLabel;

  /// No description provided for @myReqShareContactBtn.
  ///
  /// In vi, this message translates to:
  /// **'Chia sẻ SĐT với đơn vị'**
  String get myReqShareContactBtn;

  /// No description provided for @myReqAccept.
  ///
  /// In vi, this message translates to:
  /// **'Chấp nhận'**
  String get myReqAccept;

  /// No description provided for @myReqReviewTitle.
  ///
  /// In vi, this message translates to:
  /// **'Đánh giá đơn vị'**
  String get myReqReviewTitle;

  /// No description provided for @myReqCritQuality.
  ///
  /// In vi, this message translates to:
  /// **'Chất lượng'**
  String get myReqCritQuality;

  /// No description provided for @myReqCritTimeliness.
  ///
  /// In vi, this message translates to:
  /// **'Tiến độ'**
  String get myReqCritTimeliness;

  /// No description provided for @myReqCritCommunication.
  ///
  /// In vi, this message translates to:
  /// **'Giao tiếp'**
  String get myReqCritCommunication;

  /// No description provided for @myReqCritBudget.
  ///
  /// In vi, this message translates to:
  /// **'Ngân sách'**
  String get myReqCritBudget;

  /// No description provided for @myReqCritProfessionalism.
  ///
  /// In vi, this message translates to:
  /// **'Chuyên nghiệp'**
  String get myReqCritProfessionalism;

  /// No description provided for @myReqDetailedRating.
  ///
  /// In vi, this message translates to:
  /// **'Chấm chi tiết (tuỳ chọn)'**
  String get myReqDetailedRating;

  /// No description provided for @myReqCommentHint.
  ///
  /// In vi, this message translates to:
  /// **'Nhận xét (tùy chọn)'**
  String get myReqCommentHint;

  /// No description provided for @myReqSend.
  ///
  /// In vi, this message translates to:
  /// **'Gửi'**
  String get myReqSend;

  /// No description provided for @pgalFileOpenError.
  ///
  /// In vi, this message translates to:
  /// **'Không mở được file'**
  String get pgalFileOpenError;

  /// No description provided for @pgalVerifySuccess.
  ///
  /// In vi, this message translates to:
  /// **'Đã xác nhận dự án'**
  String get pgalVerifySuccess;

  /// No description provided for @pgalErrorWith.
  ///
  /// In vi, this message translates to:
  /// **'Lỗi: {error}'**
  String pgalErrorWith(Object error);

  /// No description provided for @pgalProjectFallback.
  ///
  /// In vi, this message translates to:
  /// **'Dự án'**
  String get pgalProjectFallback;

  /// No description provided for @pgalVerified.
  ///
  /// In vi, this message translates to:
  /// **'Đã kiểm chứng'**
  String get pgalVerified;

  /// No description provided for @pgalDesignFilesCount.
  ///
  /// In vi, this message translates to:
  /// **'FILE THIẾT KẾ ({count})'**
  String pgalDesignFilesCount(Object count);

  /// No description provided for @pgalDesignUnit.
  ///
  /// In vi, this message translates to:
  /// **'ĐƠN VỊ THIẾT KẾ'**
  String get pgalDesignUnit;

  /// No description provided for @pgalConfirmReal.
  ///
  /// In vi, this message translates to:
  /// **'Xác nhận dự án có thật'**
  String get pgalConfirmReal;

  /// No description provided for @pgalViewFirmProfile.
  ///
  /// In vi, this message translates to:
  /// **'Xem hồ sơ đơn vị'**
  String get pgalViewFirmProfile;

  /// No description provided for @pgalRequestConsult.
  ///
  /// In vi, this message translates to:
  /// **'Yêu cầu tư vấn'**
  String get pgalRequestConsult;

  /// No description provided for @pgalSpecCode.
  ///
  /// In vi, this message translates to:
  /// **'Mã thiết kế'**
  String get pgalSpecCode;

  /// No description provided for @pgalSpecHouseType.
  ///
  /// In vi, this message translates to:
  /// **'Loại nhà'**
  String get pgalSpecHouseType;

  /// No description provided for @pgalSpecStyle.
  ///
  /// In vi, this message translates to:
  /// **'Phong cách'**
  String get pgalSpecStyle;

  /// No description provided for @pgalSpecFloors.
  ///
  /// In vi, this message translates to:
  /// **'Số tầng'**
  String get pgalSpecFloors;

  /// No description provided for @pgalFloorsValue.
  ///
  /// In vi, this message translates to:
  /// **'{count} tầng'**
  String pgalFloorsValue(Object count);

  /// No description provided for @pgalSpecBedrooms.
  ///
  /// In vi, this message translates to:
  /// **'Phòng ngủ'**
  String get pgalSpecBedrooms;

  /// No description provided for @pgalRoomsValue.
  ///
  /// In vi, this message translates to:
  /// **'{count} phòng'**
  String pgalRoomsValue(Object count);

  /// No description provided for @pgalSpecLandArea.
  ///
  /// In vi, this message translates to:
  /// **'Diện tích đất'**
  String get pgalSpecLandArea;

  /// No description provided for @pgalLandAreaValue.
  ///
  /// In vi, this message translates to:
  /// **'{width}×{length}m ({total} m²)'**
  String pgalLandAreaValue(Object width, Object length, Object total);

  /// No description provided for @pgalSpecBuildArea.
  ///
  /// In vi, this message translates to:
  /// **'DT xây dựng'**
  String get pgalSpecBuildArea;

  /// No description provided for @pgalSqmValue.
  ///
  /// In vi, this message translates to:
  /// **'{area} m²'**
  String pgalSqmValue(Object area);

  /// No description provided for @pgalSpecYear.
  ///
  /// In vi, this message translates to:
  /// **'Năm thiết kế'**
  String get pgalSpecYear;

  /// No description provided for @pgalSpecRegion.
  ///
  /// In vi, this message translates to:
  /// **'Khu vực'**
  String get pgalSpecRegion;

  /// No description provided for @pgalSpecEstCost.
  ///
  /// In vi, this message translates to:
  /// **'Giá tham khảo'**
  String get pgalSpecEstCost;

  /// No description provided for @pgalSpecTitle.
  ///
  /// In vi, this message translates to:
  /// **'THÔNG SỐ KỸ THUẬT'**
  String get pgalSpecTitle;

  /// No description provided for @pgalCostBillion.
  ///
  /// In vi, this message translates to:
  /// **'{value} tỷ'**
  String pgalCostBillion(Object value);

  /// No description provided for @pgalCostMillion.
  ///
  /// In vi, this message translates to:
  /// **'{value} triệu'**
  String pgalCostMillion(Object value);

  /// No description provided for @pgalCostDong.
  ///
  /// In vi, this message translates to:
  /// **'{value} đ'**
  String pgalCostDong(Object value);

  /// No description provided for @pgalDescTitle.
  ///
  /// In vi, this message translates to:
  /// **'MÔ TẢ THIẾT KẾ'**
  String get pgalDescTitle;

  /// No description provided for @pgalCollapse.
  ///
  /// In vi, this message translates to:
  /// **'Thu gọn'**
  String get pgalCollapse;

  /// No description provided for @pgalExpand.
  ///
  /// In vi, this message translates to:
  /// **'Xem thêm'**
  String get pgalExpand;

  /// No description provided for @pgalRelatedTitle.
  ///
  /// In vi, this message translates to:
  /// **'MẪU TƯƠNG TỰ'**
  String get pgalRelatedTitle;

  /// No description provided for @pgalDesignTemplate.
  ///
  /// In vi, this message translates to:
  /// **'Mẫu thiết kế'**
  String get pgalDesignTemplate;

  /// No description provided for @pgalBedroomsAbbr.
  ///
  /// In vi, this message translates to:
  /// **'{count} PN'**
  String pgalBedroomsAbbr(Object count);

  /// No description provided for @pgalSqmValueCompact.
  ///
  /// In vi, this message translates to:
  /// **'{area}m²'**
  String pgalSqmValueCompact(Object area);

  /// No description provided for @pgalDesignFirmName.
  ///
  /// In vi, this message translates to:
  /// **'Đơn vị thiết kế'**
  String get pgalDesignFirmName;

  /// No description provided for @pgalRatingLine.
  ///
  /// In vi, this message translates to:
  /// **'⭐ {rating} · {count} đánh giá'**
  String pgalRatingLine(Object rating, Object count);

  /// No description provided for @pgalViewAllFirm.
  ///
  /// In vi, this message translates to:
  /// **'Xem tất cả mẫu của đơn vị →'**
  String get pgalViewAllFirm;

  /// No description provided for @pgalDrawingIndex.
  ///
  /// In vi, this message translates to:
  /// **'Bản vẽ/thiết kế {index}'**
  String pgalDrawingIndex(Object index);

  /// No description provided for @postCardEdited.
  ///
  /// In vi, this message translates to:
  /// **'đã chỉnh sửa'**
  String get postCardEdited;

  /// No description provided for @postCmtErrorLoad.
  ///
  /// In vi, this message translates to:
  /// **'Không tải được bình luận'**
  String get postCmtErrorLoad;

  /// No description provided for @postCmtLoginRequired.
  ///
  /// In vi, this message translates to:
  /// **'Đăng nhập để bình luận.'**
  String get postCmtLoginRequired;

  /// No description provided for @postCmtSendFailed.
  ///
  /// In vi, this message translates to:
  /// **'Gửi bình luận thất bại'**
  String get postCmtSendFailed;

  /// No description provided for @postCmtDeleteFailed.
  ///
  /// In vi, this message translates to:
  /// **'Xoá bình luận thất bại'**
  String get postCmtDeleteFailed;

  /// No description provided for @postCmtTitle.
  ///
  /// In vi, this message translates to:
  /// **'Bình luận'**
  String get postCmtTitle;

  /// No description provided for @postCmtEmpty.
  ///
  /// In vi, this message translates to:
  /// **'Chưa có bình luận. Hãy là người đầu tiên!'**
  String get postCmtEmpty;

  /// No description provided for @postCmtEdited.
  ///
  /// In vi, this message translates to:
  /// **'đã chỉnh sửa'**
  String get postCmtEdited;

  /// No description provided for @postCmtMoreImages.
  ///
  /// In vi, this message translates to:
  /// **'+{count} ảnh'**
  String postCmtMoreImages(Object count);

  /// No description provided for @postCmtDeleted.
  ///
  /// In vi, this message translates to:
  /// **'Bình luận đã bị xoá'**
  String get postCmtDeleted;

  /// No description provided for @postCmtReply.
  ///
  /// In vi, this message translates to:
  /// **'Trả lời'**
  String get postCmtReply;

  /// No description provided for @postCmtDelete.
  ///
  /// In vi, this message translates to:
  /// **'Xoá'**
  String get postCmtDelete;

  /// No description provided for @postCmtReplyingTo.
  ///
  /// In vi, this message translates to:
  /// **'Đang trả lời {name}'**
  String postCmtReplyingTo(Object name);

  /// No description provided for @postCmtHint.
  ///
  /// In vi, this message translates to:
  /// **'Viết bình luận...'**
  String get postCmtHint;

  /// No description provided for @postCmtReplyHint.
  ///
  /// In vi, this message translates to:
  /// **'Trả lời {name}...'**
  String postCmtReplyHint(Object name);

  /// No description provided for @postHouseImagePickError.
  ///
  /// In vi, this message translates to:
  /// **'Lỗi chọn ảnh: {error}'**
  String postHouseImagePickError(Object error);

  /// No description provided for @postHouseSelectRoomType.
  ///
  /// In vi, this message translates to:
  /// **'Vui lòng chọn loại phòng'**
  String get postHouseSelectRoomType;

  /// No description provided for @postHouseWaitUpload.
  ///
  /// In vi, this message translates to:
  /// **'Vui lòng đợi upload ảnh xong'**
  String get postHouseWaitUpload;

  /// No description provided for @postHouseNeedOneImage.
  ///
  /// In vi, this message translates to:
  /// **'Cần ít nhất 1 ảnh'**
  String get postHouseNeedOneImage;

  /// No description provided for @postHousePostSuccess.
  ///
  /// In vi, this message translates to:
  /// **'Đã đăng tin thành công!'**
  String get postHousePostSuccess;

  /// No description provided for @postHousePendingReviewTitle.
  ///
  /// In vi, this message translates to:
  /// **'Tin đã gửi — đang chờ duyệt'**
  String get postHousePendingReviewTitle;

  /// No description provided for @postHousePendingReviewBody.
  ///
  /// In vi, this message translates to:
  /// **'Tin bán giá trị lớn cần quản trị viên xác minh trước khi hiển thị công khai (thường trong vòng 24 giờ). Bạn theo dõi trạng thái tại Cá nhân → Tin đã đăng.'**
  String get postHousePendingReviewBody;

  /// No description provided for @commonUnderstood.
  ///
  /// In vi, this message translates to:
  /// **'Đã hiểu'**
  String get commonUnderstood;

  /// No description provided for @postHousePostFailed.
  ///
  /// In vi, this message translates to:
  /// **'Đăng phòng thất bại'**
  String get postHousePostFailed;

  /// No description provided for @postHouseUpdateSuccess.
  ///
  /// In vi, this message translates to:
  /// **'Đã cập nhật tin'**
  String get postHouseUpdateSuccess;

  /// No description provided for @postHouseUpdateFailed.
  ///
  /// In vi, this message translates to:
  /// **'Cập nhật thất bại'**
  String get postHouseUpdateFailed;

  /// No description provided for @postHouseEditTitle.
  ///
  /// In vi, this message translates to:
  /// **'Chỉnh sửa tin đăng'**
  String get postHouseEditTitle;

  /// No description provided for @postHouseNewTitle.
  ///
  /// In vi, this message translates to:
  /// **'Đăng phòng mới'**
  String get postHouseNewTitle;

  /// No description provided for @postHousePhotosLabel.
  ///
  /// In vi, this message translates to:
  /// **'{label} ({current}/{max})'**
  String postHousePhotosLabel(Object label, Object current, Object max);

  /// No description provided for @postHousePropertyPhotos.
  ///
  /// In vi, this message translates to:
  /// **'Ảnh bất động sản'**
  String get postHousePropertyPhotos;

  /// No description provided for @postHouseRoomPhotos.
  ///
  /// In vi, this message translates to:
  /// **'Ảnh phòng'**
  String get postHouseRoomPhotos;

  /// No description provided for @postHouseListingCategory.
  ///
  /// In vi, this message translates to:
  /// **'Loại tin'**
  String get postHouseListingCategory;

  /// No description provided for @postHouseTitleLabel.
  ///
  /// In vi, this message translates to:
  /// **'Tiêu đề'**
  String get postHouseTitleLabel;

  /// No description provided for @postHouseTitleHint.
  ///
  /// In vi, this message translates to:
  /// **'VD: Căn hộ 2PN view sông Sài Gòn'**
  String get postHouseTitleHint;

  /// No description provided for @postHouseRequired.
  ///
  /// In vi, this message translates to:
  /// **'Bắt buộc'**
  String get postHouseRequired;

  /// No description provided for @postHouseDescLabel.
  ///
  /// In vi, this message translates to:
  /// **'Mô tả'**
  String get postHouseDescLabel;

  /// No description provided for @postHouseDescHint.
  ///
  /// In vi, this message translates to:
  /// **'Mô tả chi tiết về phòng...'**
  String get postHouseDescHint;

  /// No description provided for @postHouseDraftFoundTitle.
  ///
  /// In vi, this message translates to:
  /// **'Tiếp tục tin đang soạn dở?'**
  String get postHouseDraftFoundTitle;

  /// No description provided for @postHouseDraftFoundBody.
  ///
  /// In vi, this message translates to:
  /// **'Bạn có một tin chưa đăng xong lần trước. Khôi phục để điền tiếp, hoặc bỏ để bắt đầu tin mới. (Ảnh cần chọn lại.)'**
  String get postHouseDraftFoundBody;

  /// No description provided for @postHouseDraftRestore.
  ///
  /// In vi, this message translates to:
  /// **'Khôi phục'**
  String get postHouseDraftRestore;

  /// No description provided for @postHouseDraftDiscard.
  ///
  /// In vi, this message translates to:
  /// **'Bỏ nháp'**
  String get postHouseDraftDiscard;

  /// No description provided for @postHouseDescLabelOptional.
  ///
  /// In vi, this message translates to:
  /// **'Mô tả (không bắt buộc)'**
  String get postHouseDescLabelOptional;

  /// No description provided for @postHouseDescTemplateBtn.
  ///
  /// In vi, this message translates to:
  /// **'Chèn khung mô tả mẫu'**
  String get postHouseDescTemplateBtn;

  /// No description provided for @postHouseDescTemplate.
  ///
  /// In vi, this message translates to:
  /// **'• Vị trí: gần chợ/trường/bến xe...\n• Tiện nghi: điều hoà, nóng lạnh, chỗ để xe...\n• Chi phí khác: điện, nước, internet...\n• Liên hệ xem nhà: '**
  String get postHouseDescTemplate;

  /// No description provided for @postHousePropertyType.
  ///
  /// In vi, this message translates to:
  /// **'Loại bất động sản'**
  String get postHousePropertyType;

  /// No description provided for @postHouseRoomType.
  ///
  /// In vi, this message translates to:
  /// **'Loại phòng'**
  String get postHouseRoomType;

  /// No description provided for @postHouseSelectType.
  ///
  /// In vi, this message translates to:
  /// **'Chọn loại'**
  String get postHouseSelectType;

  /// No description provided for @postHouseSalePrice.
  ///
  /// In vi, this message translates to:
  /// **'Giá bán (₫)'**
  String get postHouseSalePrice;

  /// No description provided for @postHouseRentPrice.
  ///
  /// In vi, this message translates to:
  /// **'Giá thuê / tháng (₫)'**
  String get postHouseRentPrice;

  /// No description provided for @postHousePerMonth.
  ///
  /// In vi, this message translates to:
  /// **'/tháng'**
  String get postHousePerMonth;

  /// No description provided for @postHouseSalePriceHint.
  ///
  /// In vi, this message translates to:
  /// **'VD: 2.500.000.000'**
  String get postHouseSalePriceHint;

  /// No description provided for @postHouseRentPriceHint.
  ///
  /// In vi, this message translates to:
  /// **'VD: 8.000.000'**
  String get postHouseRentPriceHint;

  /// No description provided for @postHouseArea.
  ///
  /// In vi, this message translates to:
  /// **'Diện tích (m²)'**
  String get postHouseArea;

  /// No description provided for @postHouseAreaHint.
  ///
  /// In vi, this message translates to:
  /// **'VD: 65'**
  String get postHouseAreaHint;

  /// No description provided for @postHouseAddress.
  ///
  /// In vi, this message translates to:
  /// **'Địa chỉ'**
  String get postHouseAddress;

  /// No description provided for @postHouseAddressHint.
  ///
  /// In vi, this message translates to:
  /// **'Số nhà, đường...'**
  String get postHouseAddressHint;

  /// No description provided for @postHouseAddressNeedsDetail.
  ///
  /// In vi, this message translates to:
  /// **'Bản đồ chỉ xác định được tới phường/xã — vui lòng bổ sung số nhà và tên đường.'**
  String get postHouseAddressNeedsDetail;

  /// No description provided for @postHouseProvince.
  ///
  /// In vi, this message translates to:
  /// **'Tỉnh / Thành phố'**
  String get postHouseProvince;

  /// No description provided for @postHouseSelectProvince.
  ///
  /// In vi, this message translates to:
  /// **'Chọn tỉnh/thành'**
  String get postHouseSelectProvince;

  /// No description provided for @postHouseWard.
  ///
  /// In vi, this message translates to:
  /// **'Phường / Xã'**
  String get postHouseWard;

  /// No description provided for @postHouseLoading.
  ///
  /// In vi, this message translates to:
  /// **'Đang tải...'**
  String get postHouseLoading;

  /// No description provided for @postHouseSelectWard.
  ///
  /// In vi, this message translates to:
  /// **'Chọn phường/xã'**
  String get postHouseSelectWard;

  /// No description provided for @postHouseMapLocation.
  ///
  /// In vi, this message translates to:
  /// **'Vị trí trên bản đồ'**
  String get postHouseMapLocation;

  /// No description provided for @postHouseMapHint.
  ///
  /// In vi, this message translates to:
  /// **'Chạm vào bản đồ để đặt ghim vị trí chính xác (địa chỉ tự điền).'**
  String get postHouseMapHint;

  /// No description provided for @postHousePinnedAt.
  ///
  /// In vi, this message translates to:
  /// **'Đã ghim: {lat}, {lng}'**
  String postHousePinnedAt(Object lat, Object lng);

  /// No description provided for @postHouseBedrooms.
  ///
  /// In vi, this message translates to:
  /// **'Phòng ngủ'**
  String get postHouseBedrooms;

  /// No description provided for @postHouseBathrooms.
  ///
  /// In vi, this message translates to:
  /// **'Phòng tắm'**
  String get postHouseBathrooms;

  /// No description provided for @postHouseLegal.
  ///
  /// In vi, this message translates to:
  /// **'Pháp lý'**
  String get postHouseLegal;

  /// No description provided for @postHouseSaveChanges.
  ///
  /// In vi, this message translates to:
  /// **'Lưu thay đổi'**
  String get postHouseSaveChanges;

  /// No description provided for @postHouseSell.
  ///
  /// In vi, this message translates to:
  /// **'Đăng bán'**
  String get postHouseSell;

  /// No description provided for @postHouseRent.
  ///
  /// In vi, this message translates to:
  /// **'Đăng cho thuê'**
  String get postHouseRent;

  /// No description provided for @postHouseAddPhoto.
  ///
  /// In vi, this message translates to:
  /// **'Thêm ảnh'**
  String get postHouseAddPhoto;

  /// No description provided for @postHouseCoverPhoto.
  ///
  /// In vi, this message translates to:
  /// **'Ảnh bìa'**
  String get postHouseCoverPhoto;

  /// No description provided for @postHouseRetry.
  ///
  /// In vi, this message translates to:
  /// **'Thử lại'**
  String get postHouseRetry;

  /// No description provided for @postHouseListingForm.
  ///
  /// In vi, this message translates to:
  /// **'Hình thức đăng tin'**
  String get postHouseListingForm;

  /// No description provided for @postHouseSemanticRent.
  ///
  /// In vi, this message translates to:
  /// **'Loại tin: Cho thuê'**
  String get postHouseSemanticRent;

  /// No description provided for @postHouseSemanticSale.
  ///
  /// In vi, this message translates to:
  /// **'Loại tin: Rao bán'**
  String get postHouseSemanticSale;

  /// No description provided for @postHouseSingleTitle.
  ///
  /// In vi, this message translates to:
  /// **'1 căn / 1 phòng'**
  String get postHouseSingleTitle;

  /// No description provided for @postHouseSingleSubtitle.
  ///
  /// In vi, this message translates to:
  /// **'Nhà nguyên căn, căn hộ riêng'**
  String get postHouseSingleSubtitle;

  /// No description provided for @postHouseMultiTitle.
  ///
  /// In vi, this message translates to:
  /// **'Nhiều phòng'**
  String get postHouseMultiTitle;

  /// No description provided for @postHouseMultiSubtitle.
  ///
  /// In vi, this message translates to:
  /// **'Dãy trọ, CCMN, hostel...'**
  String get postHouseMultiSubtitle;

  /// No description provided for @postHouseLegalRedBook.
  ///
  /// In vi, this message translates to:
  /// **'Sổ đỏ'**
  String get postHouseLegalRedBook;

  /// No description provided for @postHouseLegalPinkBook.
  ///
  /// In vi, this message translates to:
  /// **'Sổ hồng'**
  String get postHouseLegalPinkBook;

  /// No description provided for @postHouseLegalSaleContract.
  ///
  /// In vi, this message translates to:
  /// **'HĐ mua bán'**
  String get postHouseLegalSaleContract;

  /// No description provided for @postHouseLegalPending.
  ///
  /// In vi, this message translates to:
  /// **'Chờ sổ'**
  String get postHouseLegalPending;

  /// No description provided for @postHouseTotalUnits.
  ///
  /// In vi, this message translates to:
  /// **'Tổng số phòng'**
  String get postHouseTotalUnits;

  /// No description provided for @postHouseTotalUnitsHint.
  ///
  /// In vi, this message translates to:
  /// **'VD: 10'**
  String get postHouseTotalUnitsHint;

  /// No description provided for @postHouseAvailableUnits.
  ///
  /// In vi, this message translates to:
  /// **'Còn trống'**
  String get postHouseAvailableUnits;

  /// No description provided for @postHouseAvailableUnitsHint.
  ///
  /// In vi, this message translates to:
  /// **'VD: 7'**
  String get postHouseAvailableUnitsHint;

  /// No description provided for @postHousePriorityTenant.
  ///
  /// In vi, this message translates to:
  /// **'Đối tượng ưu tiên'**
  String get postHousePriorityTenant;

  /// No description provided for @postHouseGenderAny.
  ///
  /// In vi, this message translates to:
  /// **'Không yêu cầu'**
  String get postHouseGenderAny;

  /// No description provided for @postHouseGenderMale.
  ///
  /// In vi, this message translates to:
  /// **'Nam'**
  String get postHouseGenderMale;

  /// No description provided for @postHouseGenderFemale.
  ///
  /// In vi, this message translates to:
  /// **'Nữ'**
  String get postHouseGenderFemale;

  /// No description provided for @profPersonal.
  ///
  /// In vi, this message translates to:
  /// **'Cá nhân'**
  String get profPersonal;

  /// No description provided for @profLoginPrompt.
  ///
  /// In vi, this message translates to:
  /// **'Đăng nhập để quản lý hồ sơ, tin đã đăng, lịch hẹn và cài đặt.'**
  String get profLoginPrompt;

  /// No description provided for @profAccount.
  ///
  /// In vi, this message translates to:
  /// **'Tài khoản'**
  String get profAccount;

  /// No description provided for @profSettings.
  ///
  /// In vi, this message translates to:
  /// **'Cài đặt'**
  String get profSettings;

  /// No description provided for @profYourPosts.
  ///
  /// In vi, this message translates to:
  /// **'BÀI VIẾT CỦA BẠN'**
  String get profYourPosts;

  /// No description provided for @profSavedListings.
  ///
  /// In vi, this message translates to:
  /// **'Tin đã lưu'**
  String get profSavedListings;

  /// No description provided for @profAgeYears.
  ///
  /// In vi, this message translates to:
  /// **'{count} tuổi'**
  String profAgeYears(Object count);

  /// No description provided for @profListings.
  ///
  /// In vi, this message translates to:
  /// **'Tin đăng'**
  String get profListings;

  /// No description provided for @profAppointmentsStat.
  ///
  /// In vi, this message translates to:
  /// **'Đặt lịch'**
  String get profAppointmentsStat;

  /// No description provided for @profFavorites.
  ///
  /// In vi, this message translates to:
  /// **'Yêu thích'**
  String get profFavorites;

  /// No description provided for @profMine.
  ///
  /// In vi, this message translates to:
  /// **'Của tôi'**
  String get profMine;

  /// No description provided for @profPostedListings.
  ///
  /// In vi, this message translates to:
  /// **'Tin đã đăng'**
  String get profPostedListings;

  /// No description provided for @profPostedListingsSubtitle.
  ///
  /// In vi, this message translates to:
  /// **'Quản lý phòng bạn cho thuê'**
  String get profPostedListingsSubtitle;

  /// No description provided for @profViewingAppointments.
  ///
  /// In vi, this message translates to:
  /// **'Lịch hẹn xem nhà'**
  String get profViewingAppointments;

  /// No description provided for @profViewingAppointmentsSubtitle.
  ///
  /// In vi, this message translates to:
  /// **'Các lịch đặt xem nhà của bạn'**
  String get profViewingAppointmentsSubtitle;

  /// No description provided for @profConstructionServices.
  ///
  /// In vi, this message translates to:
  /// **'Dịch vụ xây dựng'**
  String get profConstructionServices;

  /// No description provided for @profMyServiceRequests.
  ///
  /// In vi, this message translates to:
  /// **'Yêu cầu dịch vụ của tôi'**
  String get profMyServiceRequests;

  /// No description provided for @profMyServiceRequestsSubtitle.
  ///
  /// In vi, this message translates to:
  /// **'Theo dõi báo giá & chọn đơn vị'**
  String get profMyServiceRequestsSubtitle;

  /// No description provided for @profProviderChannel.
  ///
  /// In vi, this message translates to:
  /// **'Kênh đơn vị'**
  String get profProviderChannel;

  /// No description provided for @profProviderChannelSubtitle.
  ///
  /// In vi, this message translates to:
  /// **'Hồ sơ năng lực, nhu cầu phù hợp, báo giá của tôi'**
  String get profProviderChannelSubtitle;

  /// No description provided for @profBecomeProvider.
  ///
  /// In vi, this message translates to:
  /// **'Bạn là đơn vị xây dựng/thiết kế?'**
  String get profBecomeProvider;

  /// No description provided for @profBecomeProviderSubtitle.
  ///
  /// In vi, this message translates to:
  /// **'Đăng ký hồ sơ để nhận yêu cầu báo giá từ khách'**
  String get profBecomeProviderSubtitle;

  /// No description provided for @profRoleAdmin.
  ///
  /// In vi, this message translates to:
  /// **'Quản trị'**
  String get profRoleAdmin;

  /// No description provided for @profRoleMember.
  ///
  /// In vi, this message translates to:
  /// **'Thành viên'**
  String get profRoleMember;

  /// No description provided for @profModeGuest.
  ///
  /// In vi, this message translates to:
  /// **'Khách thuê'**
  String get profModeGuest;

  /// No description provided for @profModeHost.
  ///
  /// In vi, this message translates to:
  /// **'Chủ nhà'**
  String get profModeHost;

  /// No description provided for @profBecomeHost.
  ///
  /// In vi, this message translates to:
  /// **'TRỞ THÀNH CHỦ NHÀ'**
  String get profBecomeHost;

  /// No description provided for @profBecomeHostSubtitle.
  ///
  /// In vi, this message translates to:
  /// **'Mở phòng, đón khách, thu tiền — chỉ trong 2 phút.'**
  String get profBecomeHostSubtitle;

  /// No description provided for @reelCmtLoadFailed.
  ///
  /// In vi, this message translates to:
  /// **'Không tải được bình luận.'**
  String get reelCmtLoadFailed;

  /// No description provided for @reelCmtLoginToComment.
  ///
  /// In vi, this message translates to:
  /// **'Đăng nhập để bình luận.'**
  String get reelCmtLoginToComment;

  /// No description provided for @reelCmtRateLimited.
  ///
  /// In vi, this message translates to:
  /// **'Bạn bình luận hơi nhanh, thử lại sau ít phút.'**
  String get reelCmtRateLimited;

  /// No description provided for @reelCmtSendFailed.
  ///
  /// In vi, this message translates to:
  /// **'Gửi bình luận thất bại.'**
  String get reelCmtSendFailed;

  /// No description provided for @reelCmtDeleteTitle.
  ///
  /// In vi, this message translates to:
  /// **'Xoá bình luận?'**
  String get reelCmtDeleteTitle;

  /// No description provided for @reelCmtDelete.
  ///
  /// In vi, this message translates to:
  /// **'Xoá'**
  String get reelCmtDelete;

  /// No description provided for @reelCmtDeleteFailed.
  ///
  /// In vi, this message translates to:
  /// **'Xoá bình luận thất bại.'**
  String get reelCmtDeleteFailed;

  /// No description provided for @reelCmtCountLabel.
  ///
  /// In vi, this message translates to:
  /// **'{count} bình luận'**
  String reelCmtCountLabel(Object count);

  /// No description provided for @reelCmtReplyingTo.
  ///
  /// In vi, this message translates to:
  /// **'Đang trả lời {name}'**
  String reelCmtReplyingTo(Object name);

  /// No description provided for @reelCmtInputHint.
  ///
  /// In vi, this message translates to:
  /// **'Viết bình luận…'**
  String get reelCmtInputHint;

  /// No description provided for @reelCmtEmpty.
  ///
  /// In vi, this message translates to:
  /// **'Chưa có bình luận nào.\nHãy là người đầu tiên!'**
  String get reelCmtEmpty;

  /// No description provided for @reelCmtDefaultUser.
  ///
  /// In vi, this message translates to:
  /// **'Người dùng'**
  String get reelCmtDefaultUser;

  /// No description provided for @reelCmtDeletedComment.
  ///
  /// In vi, this message translates to:
  /// **'Bình luận đã bị xoá'**
  String get reelCmtDeletedComment;

  /// No description provided for @reelCmtReply.
  ///
  /// In vi, this message translates to:
  /// **'Trả lời'**
  String get reelCmtReply;

  /// No description provided for @reelCompTitle.
  ///
  /// In vi, this message translates to:
  /// **'Tạo reel'**
  String get reelCompTitle;

  /// No description provided for @reelCompPost.
  ///
  /// In vi, this message translates to:
  /// **'Đăng'**
  String get reelCompPost;

  /// No description provided for @reelCompUploading.
  ///
  /// In vi, this message translates to:
  /// **'Đang tải video lên…'**
  String get reelCompUploading;

  /// No description provided for @reelCompUploaded.
  ///
  /// In vi, this message translates to:
  /// **'Đã tải lên: {name}'**
  String reelCompUploaded(Object name);

  /// No description provided for @reelCompPickVideo.
  ///
  /// In vi, this message translates to:
  /// **'Chọn video từ thư viện'**
  String get reelCompPickVideo;

  /// No description provided for @reelCompLimits.
  ///
  /// In vi, this message translates to:
  /// **'Tối đa 90 giây · 120MB · mọi định dạng'**
  String get reelCompLimits;

  /// No description provided for @reelCompCaption.
  ///
  /// In vi, this message translates to:
  /// **'Chú thích'**
  String get reelCompCaption;

  /// No description provided for @reelCompCaptionHint.
  ///
  /// In vi, this message translates to:
  /// **'Mô tả ngắn về video của bạn…'**
  String get reelCompCaptionHint;

  /// No description provided for @reelCompShowIn.
  ///
  /// In vi, this message translates to:
  /// **'Hiển thị ở phần'**
  String get reelCompShowIn;

  /// No description provided for @reelCompCatAll.
  ///
  /// In vi, this message translates to:
  /// **'Mọi phần'**
  String get reelCompCatAll;

  /// No description provided for @reelCompCatLease.
  ///
  /// In vi, this message translates to:
  /// **'Cho thuê'**
  String get reelCompCatLease;

  /// No description provided for @reelCompCatIndustrial.
  ///
  /// In vi, this message translates to:
  /// **'Công nghiệp'**
  String get reelCompCatIndustrial;

  /// No description provided for @reelCompCatDesign.
  ///
  /// In vi, this message translates to:
  /// **'Thiết kế'**
  String get reelCompCatDesign;

  /// No description provided for @reelCompCatBuild.
  ///
  /// In vi, this message translates to:
  /// **'Xây dựng'**
  String get reelCompCatBuild;

  /// No description provided for @reelCompCatInterior.
  ///
  /// In vi, this message translates to:
  /// **'Nội thất'**
  String get reelCompCatInterior;

  /// No description provided for @reelCompErrVideoTooLarge.
  ///
  /// In vi, this message translates to:
  /// **'Video quá lớn (tối đa 120MB). Hãy quay ngắn hơn.'**
  String get reelCompErrVideoTooLarge;

  /// No description provided for @reelCompErrUploadFailed.
  ///
  /// In vi, this message translates to:
  /// **'Tải video thất bại. Vui lòng kiểm tra kết nối và thử lại.'**
  String get reelCompErrUploadFailed;

  /// No description provided for @reelCompErrNoVideo.
  ///
  /// In vi, this message translates to:
  /// **'Vui lòng chọn video trước.'**
  String get reelCompErrNoVideo;

  /// No description provided for @reelCompSentTitle.
  ///
  /// In vi, this message translates to:
  /// **'Đã gửi, chờ duyệt'**
  String get reelCompSentTitle;

  /// No description provided for @reelCompSentBody.
  ///
  /// In vi, this message translates to:
  /// **'Video đang được xử lý (chuẩn hoá + tạo ảnh bìa), sau đó quản trị viên sẽ duyệt trước khi hiển thị công khai. Bạn có thể theo dõi trạng thái ở mục \"Reel của tôi\".'**
  String get reelCompSentBody;

  /// No description provided for @reelCompGotIt.
  ///
  /// In vi, this message translates to:
  /// **'Đã hiểu'**
  String get reelCompGotIt;

  /// No description provided for @reelCompErrRateLimit.
  ///
  /// In vi, this message translates to:
  /// **'Bạn đã đăng tối đa 5 reel hôm nay. Vui lòng thử lại sau.'**
  String get reelCompErrRateLimit;

  /// No description provided for @reelCompErrSubmitFailed.
  ///
  /// In vi, this message translates to:
  /// **'Đăng reel thất bại. Vui lòng thử lại.'**
  String get reelCompErrSubmitFailed;

  /// No description provided for @reelViewDataSaverOn.
  ///
  /// In vi, this message translates to:
  /// **'Đã bật tiết kiệm dữ liệu — video không tự phát.'**
  String get reelViewDataSaverOn;

  /// No description provided for @reelViewDataSaverOff.
  ///
  /// In vi, this message translates to:
  /// **'Đã tắt tiết kiệm dữ liệu.'**
  String get reelViewDataSaverOff;

  /// No description provided for @reelViewLoginToLike.
  ///
  /// In vi, this message translates to:
  /// **'Đăng nhập để thích reel.'**
  String get reelViewLoginToLike;

  /// No description provided for @reelViewLoginToReport.
  ///
  /// In vi, this message translates to:
  /// **'Đăng nhập để báo cáo reel.'**
  String get reelViewLoginToReport;

  /// No description provided for @reelViewReasonSpam.
  ///
  /// In vi, this message translates to:
  /// **'Spam / quảng cáo'**
  String get reelViewReasonSpam;

  /// No description provided for @reelViewReasonInappropriate.
  ///
  /// In vi, this message translates to:
  /// **'Nội dung không phù hợp'**
  String get reelViewReasonInappropriate;

  /// No description provided for @reelViewReasonCopyright.
  ///
  /// In vi, this message translates to:
  /// **'Vi phạm bản quyền'**
  String get reelViewReasonCopyright;

  /// No description provided for @reelViewReasonMisleading.
  ///
  /// In vi, this message translates to:
  /// **'Sai sự thật / lừa đảo'**
  String get reelViewReasonMisleading;

  /// No description provided for @reelViewReasonOther.
  ///
  /// In vi, this message translates to:
  /// **'Lý do khác'**
  String get reelViewReasonOther;

  /// No description provided for @reelViewReportTitle.
  ///
  /// In vi, this message translates to:
  /// **'Báo cáo reel'**
  String get reelViewReportTitle;

  /// No description provided for @reelViewReportSuccess.
  ///
  /// In vi, this message translates to:
  /// **'Đã gửi báo cáo. Cảm ơn bạn đã giúp giữ cộng đồng an toàn.'**
  String get reelViewReportSuccess;

  /// No description provided for @reelViewReportFailed.
  ///
  /// In vi, this message translates to:
  /// **'Gửi báo cáo thất bại.'**
  String get reelViewReportFailed;

  /// No description provided for @reelViewLinkCopied.
  ///
  /// In vi, this message translates to:
  /// **'Đã chép liên kết reel.'**
  String get reelViewLinkCopied;

  /// No description provided for @reelViewDataSaverTooltipOn.
  ///
  /// In vi, this message translates to:
  /// **'Tiết kiệm dữ liệu: BẬT'**
  String get reelViewDataSaverTooltipOn;

  /// No description provided for @reelViewDataSaverTooltipOff.
  ///
  /// In vi, this message translates to:
  /// **'Tiết kiệm dữ liệu: TẮT'**
  String get reelViewDataSaverTooltipOff;

  /// No description provided for @reelViewVideoError.
  ///
  /// In vi, this message translates to:
  /// **'Không phát được video này'**
  String get reelViewVideoError;

  /// No description provided for @reelViewViewCount.
  ///
  /// In vi, this message translates to:
  /// **'{count} lượt xem'**
  String reelViewViewCount(Object count);

  /// No description provided for @reelViewShare.
  ///
  /// In vi, this message translates to:
  /// **'Chia sẻ'**
  String get reelViewShare;

  /// No description provided for @reelViewUnmute.
  ///
  /// In vi, this message translates to:
  /// **'Bật tiếng'**
  String get reelViewUnmute;

  /// No description provided for @reelViewMute.
  ///
  /// In vi, this message translates to:
  /// **'Tắt tiếng'**
  String get reelViewMute;

  /// No description provided for @reelViewReport.
  ///
  /// In vi, this message translates to:
  /// **'Báo cáo'**
  String get reelViewReport;

  /// No description provided for @roleWelcomeTitle.
  ///
  /// In vi, this message translates to:
  /// **'Chào mừng đến Vua Nhà'**
  String get roleWelcomeTitle;

  /// No description provided for @roleLater.
  ///
  /// In vi, this message translates to:
  /// **'Để sau'**
  String get roleLater;

  /// No description provided for @roleQuestion.
  ///
  /// In vi, this message translates to:
  /// **'Bạn đến với vai trò nào?'**
  String get roleQuestion;

  /// No description provided for @roleSubtitle.
  ///
  /// In vi, this message translates to:
  /// **'Chọn để chúng tôi đưa bạn tới đúng nơi. Bạn có thể đổi/bổ sung sau.'**
  String get roleSubtitle;

  /// No description provided for @roleSeekerTitle.
  ///
  /// In vi, this message translates to:
  /// **'Tôi tìm nhà / dịch vụ'**
  String get roleSeekerTitle;

  /// No description provided for @roleSeekerSubtitle.
  ///
  /// In vi, this message translates to:
  /// **'Xem tin cho thuê, mua bán, tìm đơn vị xây dựng.'**
  String get roleSeekerSubtitle;

  /// No description provided for @roleHostTitle.
  ///
  /// In vi, this message translates to:
  /// **'Tôi là chủ nhà'**
  String get roleHostTitle;

  /// No description provided for @roleHostSubtitle.
  ///
  /// In vi, this message translates to:
  /// **'Đăng tin cho thuê / bán bất động sản của bạn.'**
  String get roleHostSubtitle;

  /// No description provided for @roleProviderTitle.
  ///
  /// In vi, this message translates to:
  /// **'Tôi là đơn vị xây dựng / thiết kế'**
  String get roleProviderTitle;

  /// No description provided for @roleProviderSubtitle.
  ///
  /// In vi, this message translates to:
  /// **'Lập hồ sơ đơn vị, nhận yêu cầu báo giá từ khách.'**
  String get roleProviderSubtitle;

  /// No description provided for @socialLoginToInteract.
  ///
  /// In vi, this message translates to:
  /// **'Đăng nhập để tương tác với cộng đồng.'**
  String get socialLoginToInteract;

  /// No description provided for @socialDeletePostTitle.
  ///
  /// In vi, this message translates to:
  /// **'Xoá bài đăng'**
  String get socialDeletePostTitle;

  /// No description provided for @socialDeletePostConfirm.
  ///
  /// In vi, this message translates to:
  /// **'Bạn chắc chắn muốn xoá bài này?'**
  String get socialDeletePostConfirm;

  /// No description provided for @socialDelete.
  ///
  /// In vi, this message translates to:
  /// **'Xoá'**
  String get socialDelete;

  /// No description provided for @socialDeleteFailed.
  ///
  /// In vi, this message translates to:
  /// **'Xoá bài thất bại'**
  String get socialDeleteFailed;

  /// No description provided for @socialAll.
  ///
  /// In vi, this message translates to:
  /// **'Tất cả'**
  String get socialAll;

  /// No description provided for @socialWhatsOnMind.
  ///
  /// In vi, this message translates to:
  /// **'Bạn đang nghĩ gì?'**
  String get socialWhatsOnMind;

  /// No description provided for @socialPostPhoto.
  ///
  /// In vi, this message translates to:
  /// **'Đăng ảnh'**
  String get socialPostPhoto;

  /// No description provided for @socialNoPostsInCategory.
  ///
  /// In vi, this message translates to:
  /// **'Chưa có bài trong chuyên mục này'**
  String get socialNoPostsInCategory;

  /// No description provided for @socialNoPosts.
  ///
  /// In vi, this message translates to:
  /// **'Chưa có bài đăng nào'**
  String get socialNoPosts;

  /// No description provided for @socialBeFirstToShare.
  ///
  /// In vi, this message translates to:
  /// **'Hãy là người đầu tiên chia sẻ!'**
  String get socialBeFirstToShare;

  /// No description provided for @socialEndOfFeed.
  ///
  /// In vi, this message translates to:
  /// **'— Hết bài đăng —'**
  String get socialEndOfFeed;

  /// No description provided for @socialErrorOccurred.
  ///
  /// In vi, this message translates to:
  /// **'Có lỗi xảy ra'**
  String get socialErrorOccurred;

  /// No description provided for @socialRetry.
  ///
  /// In vi, this message translates to:
  /// **'Thử lại'**
  String get socialRetry;

  /// No description provided for @surveyEyebrow.
  ///
  /// In vi, this message translates to:
  /// **'Cá nhân'**
  String get surveyEyebrow;

  /// No description provided for @surveyMyInterestsTitle.
  ///
  /// In vi, this message translates to:
  /// **'Sở thích của tôi'**
  String get surveyMyInterestsTitle;

  /// No description provided for @surveySkip.
  ///
  /// In vi, this message translates to:
  /// **'Bỏ qua'**
  String get surveySkip;

  /// No description provided for @surveyGreeting.
  ///
  /// In vi, this message translates to:
  /// **'Chào bạn 👋'**
  String get surveyGreeting;

  /// No description provided for @surveyIntro.
  ///
  /// In vi, this message translates to:
  /// **'Cho Vua Nhà biết bạn quan tâm gì để cá nhân hoá trải nghiệm. Có thể chọn nhiều mục.'**
  String get surveyIntro;

  /// No description provided for @surveyWhatDoYouWant.
  ///
  /// In vi, this message translates to:
  /// **'Bạn muốn làm gì?'**
  String get surveyWhatDoYouWant;

  /// No description provided for @surveyRealEstateSection.
  ///
  /// In vi, this message translates to:
  /// **'Bất động sản'**
  String get surveyRealEstateSection;

  /// No description provided for @surveyConstructionSection.
  ///
  /// In vi, this message translates to:
  /// **'Xây dựng'**
  String get surveyConstructionSection;

  /// No description provided for @surveyConstructionInterest.
  ///
  /// In vi, this message translates to:
  /// **'Xây dựng'**
  String get surveyConstructionInterest;

  /// No description provided for @surveyAreaOptional.
  ///
  /// In vi, this message translates to:
  /// **'Khu vực quan tâm (tuỳ chọn)'**
  String get surveyAreaOptional;

  /// No description provided for @surveyYouAreTitle.
  ///
  /// In vi, this message translates to:
  /// **'Bạn là ai?'**
  String get surveyYouAreTitle;

  /// No description provided for @surveyIAmProvider.
  ///
  /// In vi, this message translates to:
  /// **'Tôi là đơn vị xây dựng / thiết kế / nội thất'**
  String get surveyIAmProvider;

  /// No description provided for @surveyIAmProviderHint.
  ///
  /// In vi, this message translates to:
  /// **'Chọn để mở thẳng vào mục Xây dựng và nhận yêu cầu báo giá từ khách'**
  String get surveyIAmProviderHint;

  /// No description provided for @surveyProvinceHint.
  ///
  /// In vi, this message translates to:
  /// **'Chọn tỉnh/thành'**
  String get surveyProvinceHint;

  /// No description provided for @surveySave.
  ///
  /// In vi, this message translates to:
  /// **'Lưu'**
  String get surveySave;

  /// No description provided for @surveyStartExploring.
  ///
  /// In vi, this message translates to:
  /// **'Bắt đầu khám phá'**
  String get surveyStartExploring;

  /// No description provided for @surveyPrefsUpdated.
  ///
  /// In vi, this message translates to:
  /// **'Đã cập nhật sở thích'**
  String get surveyPrefsUpdated;

  /// No description provided for @surveyInterestRent.
  ///
  /// In vi, this message translates to:
  /// **'Thuê nhà'**
  String get surveyInterestRent;

  /// No description provided for @surveyInterestBuy.
  ///
  /// In vi, this message translates to:
  /// **'Mua nhà đất'**
  String get surveyInterestBuy;

  /// No description provided for @surveyInterestSellOrList.
  ///
  /// In vi, this message translates to:
  /// **'Cho thuê / Đăng tin'**
  String get surveyInterestSellOrList;

  /// No description provided for @surveyInterestFindService.
  ///
  /// In vi, this message translates to:
  /// **'Tìm đơn vị xây dựng'**
  String get surveyInterestFindService;

  /// No description provided for @surveyInterestFollowConstruction.
  ///
  /// In vi, this message translates to:
  /// **'Xem tin ngành xây dựng'**
  String get surveyInterestFollowConstruction;

  /// No description provided for @surveyServiceDesign.
  ///
  /// In vi, this message translates to:
  /// **'Thiết kế'**
  String get surveyServiceDesign;

  /// No description provided for @surveyServiceBuild.
  ///
  /// In vi, this message translates to:
  /// **'Xây dựng'**
  String get surveyServiceBuild;

  /// No description provided for @surveyServiceInterior.
  ///
  /// In vi, this message translates to:
  /// **'Nội thất'**
  String get surveyServiceInterior;

  /// No description provided for @surveyServiceIndustrial.
  ///
  /// In vi, this message translates to:
  /// **'Công nghiệp'**
  String get surveyServiceIndustrial;

  /// No description provided for @loanTitle.
  ///
  /// In vi, this message translates to:
  /// **'Tính khoản vay'**
  String get loanTitle;

  /// No description provided for @loanHomePrice.
  ///
  /// In vi, this message translates to:
  /// **'Giá nhà (VND)'**
  String get loanHomePrice;

  /// No description provided for @loanHomePriceHint.
  ///
  /// In vi, this message translates to:
  /// **'Ví dụ: 2000000000'**
  String get loanHomePriceHint;

  /// No description provided for @loanDownPayment.
  ///
  /// In vi, this message translates to:
  /// **'Trả trước: {pct}%'**
  String loanDownPayment(Object pct);

  /// No description provided for @loanInterestRate.
  ///
  /// In vi, this message translates to:
  /// **'Lãi suất (%/năm)'**
  String get loanInterestRate;

  /// No description provided for @loanInterestRateHint.
  ///
  /// In vi, this message translates to:
  /// **'Ví dụ: 10'**
  String get loanInterestRateHint;

  /// No description provided for @loanTerm.
  ///
  /// In vi, this message translates to:
  /// **'Kỳ hạn: {years} năm'**
  String loanTerm(Object years);

  /// No description provided for @loanYearsShort.
  ///
  /// In vi, this message translates to:
  /// **'{years} năm'**
  String loanYearsShort(Object years);

  /// No description provided for @loanMethod.
  ///
  /// In vi, this message translates to:
  /// **'Phương thức trả'**
  String get loanMethod;

  /// No description provided for @loanMethodReducing.
  ///
  /// In vi, this message translates to:
  /// **'Dư nợ giảm dần'**
  String get loanMethodReducing;

  /// No description provided for @loanMethodAnnuity.
  ///
  /// In vi, this message translates to:
  /// **'Trả đều hàng tháng'**
  String get loanMethodAnnuity;

  /// No description provided for @loanInvalidPrice.
  ///
  /// In vi, this message translates to:
  /// **'Nhập giá nhà hợp lệ'**
  String get loanInvalidPrice;

  /// No description provided for @loanCalcFailed.
  ///
  /// In vi, this message translates to:
  /// **'Không tính được: {error}'**
  String loanCalcFailed(Object error);

  /// No description provided for @loanMonthlyPayment.
  ///
  /// In vi, this message translates to:
  /// **'Trả hàng tháng'**
  String get loanMonthlyPayment;

  /// No description provided for @loanFirstMonthPayment.
  ///
  /// In vi, this message translates to:
  /// **'Trả tháng đầu'**
  String get loanFirstMonthPayment;

  /// No description provided for @loanLastMonth.
  ///
  /// In vi, this message translates to:
  /// **'Tháng cuối: {amount}'**
  String loanLastMonth(Object amount);

  /// No description provided for @loanPrincipal.
  ///
  /// In vi, this message translates to:
  /// **'Số tiền vay'**
  String get loanPrincipal;

  /// No description provided for @loanTotalInterest.
  ///
  /// In vi, this message translates to:
  /// **'Tổng lãi'**
  String get loanTotalInterest;

  /// No description provided for @loanTotalPayment.
  ///
  /// In vi, this message translates to:
  /// **'Tổng phải trả'**
  String get loanTotalPayment;

  /// No description provided for @loanTermLabel.
  ///
  /// In vi, this message translates to:
  /// **'Kỳ hạn'**
  String get loanTermLabel;

  /// No description provided for @loanTermValue.
  ///
  /// In vi, this message translates to:
  /// **'{months} tháng ({years} năm)'**
  String loanTermValue(Object months, Object years);

  /// No description provided for @loanDisclaimer.
  ///
  /// In vi, this message translates to:
  /// **'Kết quả chỉ mang tính tham khảo; lãi suất thực tế do ngân hàng quyết định.'**
  String get loanDisclaimer;

  /// No description provided for @apptChipPending.
  ///
  /// In vi, this message translates to:
  /// **'Chờ duyệt'**
  String get apptChipPending;

  /// No description provided for @apptChipApproved.
  ///
  /// In vi, this message translates to:
  /// **'Đã duyệt'**
  String get apptChipApproved;

  /// No description provided for @apptChipCompleted.
  ///
  /// In vi, this message translates to:
  /// **'Hoàn thành'**
  String get apptChipCompleted;

  /// No description provided for @apptChipCancelled.
  ///
  /// In vi, this message translates to:
  /// **'Đã hủy'**
  String get apptChipCancelled;

  /// No description provided for @apptChipRejected.
  ///
  /// In vi, this message translates to:
  /// **'Bị từ chối'**
  String get apptChipRejected;

  /// No description provided for @apptChipLocked.
  ///
  /// In vi, this message translates to:
  /// **'Đã chốt phòng'**
  String get apptChipLocked;

  /// No description provided for @apptChipLost.
  ///
  /// In vi, this message translates to:
  /// **'Đã có người chốt'**
  String get apptChipLost;

  /// No description provided for @blockLoginToInteract.
  ///
  /// In vi, this message translates to:
  /// **'Đăng nhập để tương tác với cộng đồng.'**
  String get blockLoginToInteract;

  /// No description provided for @blockDeletePostTitle.
  ///
  /// In vi, this message translates to:
  /// **'Xoá bài đăng'**
  String get blockDeletePostTitle;

  /// No description provided for @blockDeletePostConfirm.
  ///
  /// In vi, this message translates to:
  /// **'Bạn chắc chắn muốn xoá bài này?'**
  String get blockDeletePostConfirm;

  /// No description provided for @blockDelete.
  ///
  /// In vi, this message translates to:
  /// **'Xoá'**
  String get blockDelete;

  /// No description provided for @blockDeletePostFailed.
  ///
  /// In vi, this message translates to:
  /// **'Xoá bài thất bại'**
  String get blockDeletePostFailed;

  /// No description provided for @blockCommunity.
  ///
  /// In vi, this message translates to:
  /// **'Cộng đồng'**
  String get blockCommunity;

  /// No description provided for @blockCompose.
  ///
  /// In vi, this message translates to:
  /// **'Đăng bài'**
  String get blockCompose;

  /// No description provided for @blockReelsCategory.
  ///
  /// In vi, this message translates to:
  /// **'Reels {name}'**
  String blockReelsCategory(Object name);

  /// No description provided for @blockUnitList.
  ///
  /// In vi, this message translates to:
  /// **'Danh sách đơn vị'**
  String get blockUnitList;

  /// No description provided for @blockSearchByLocation.
  ///
  /// In vi, this message translates to:
  /// **'Tìm theo địa danh…'**
  String get blockSearchByLocation;

  /// No description provided for @blockProvince.
  ///
  /// In vi, this message translates to:
  /// **'Tỉnh / Thành'**
  String get blockProvince;

  /// No description provided for @blockWard.
  ///
  /// In vi, this message translates to:
  /// **'Phường / Xã'**
  String get blockWard;

  /// No description provided for @blockKeywordHint.
  ///
  /// In vi, this message translates to:
  /// **'Từ khoá (nội dung / địa danh)…'**
  String get blockKeywordHint;

  /// No description provided for @blockSearch.
  ///
  /// In vi, this message translates to:
  /// **'Tìm'**
  String get blockSearch;

  /// No description provided for @blockClearFilter.
  ///
  /// In vi, this message translates to:
  /// **'Xoá lọc'**
  String get blockClearFilter;

  /// No description provided for @blockNoPostsIn.
  ///
  /// In vi, this message translates to:
  /// **'Chưa có bài đăng trong {name}'**
  String blockNoPostsIn(Object name);

  /// No description provided for @blockBeFirstToShare.
  ///
  /// In vi, this message translates to:
  /// **'Hãy là người đầu tiên chia sẻ!'**
  String get blockBeFirstToShare;

  /// No description provided for @blockNoMorePosts.
  ///
  /// In vi, this message translates to:
  /// **'— Hết bài đăng —'**
  String get blockNoMorePosts;

  /// No description provided for @chgpwdSuccess.
  ///
  /// In vi, this message translates to:
  /// **'Đã đổi mật khẩu thành công'**
  String get chgpwdSuccess;

  /// No description provided for @chgpwdFailed.
  ///
  /// In vi, this message translates to:
  /// **'Đổi mật khẩu thất bại'**
  String get chgpwdFailed;

  /// No description provided for @chgpwdCurrentLabel.
  ///
  /// In vi, this message translates to:
  /// **'Mật khẩu hiện tại'**
  String get chgpwdCurrentLabel;

  /// No description provided for @chgpwdNewLabel.
  ///
  /// In vi, this message translates to:
  /// **'Mật khẩu mới'**
  String get chgpwdNewLabel;

  /// No description provided for @chgpwdConfirmLabel.
  ///
  /// In vi, this message translates to:
  /// **'Xác nhận mật khẩu mới'**
  String get chgpwdConfirmLabel;

  /// No description provided for @chgpwdRequired.
  ///
  /// In vi, this message translates to:
  /// **'Bắt buộc'**
  String get chgpwdRequired;

  /// No description provided for @chgpwdMinLength.
  ///
  /// In vi, this message translates to:
  /// **'Tối thiểu 6 ký tự'**
  String get chgpwdMinLength;

  /// No description provided for @chgpwdMismatch.
  ///
  /// In vi, this message translates to:
  /// **'Mật khẩu không khớp'**
  String get chgpwdMismatch;

  /// No description provided for @clandEyebrow.
  ///
  /// In vi, this message translates to:
  /// **'XÂY DỰNG'**
  String get clandEyebrow;

  /// No description provided for @clandDefaultDesc.
  ///
  /// In vi, this message translates to:
  /// **'Kết nối đơn vị {serviceName} uy tín.'**
  String clandDefaultDesc(Object serviceName);

  /// No description provided for @clandDisclaimer.
  ///
  /// In vi, this message translates to:
  /// **'Vua Nhà là nền tảng trung gian kết nối — hợp đồng & thanh toán thực hiện trực tiếp giữa hai bên.'**
  String get clandDisclaimer;

  /// No description provided for @clandRequestQuote.
  ///
  /// In vi, this message translates to:
  /// **'Yêu cầu tư vấn / báo giá'**
  String get clandRequestQuote;

  /// No description provided for @clandViewContractors.
  ///
  /// In vi, this message translates to:
  /// **'Xem nhà thầu'**
  String get clandViewContractors;

  /// No description provided for @composerPickImageFailed.
  ///
  /// In vi, this message translates to:
  /// **'Không chọn được ảnh'**
  String get composerPickImageFailed;

  /// No description provided for @composerSelectCategoryPrompt.
  ///
  /// In vi, this message translates to:
  /// **'Vui lòng chọn chuyên mục cho bài viết'**
  String get composerSelectCategoryPrompt;

  /// No description provided for @composerPostFailed.
  ///
  /// In vi, this message translates to:
  /// **'Đăng bài thất bại, thử lại'**
  String get composerPostFailed;

  /// No description provided for @composerEditTitle.
  ///
  /// In vi, this message translates to:
  /// **'Chỉnh sửa bài viết'**
  String get composerEditTitle;

  /// No description provided for @composerCreateTitle.
  ///
  /// In vi, this message translates to:
  /// **'Tạo bài viết'**
  String get composerCreateTitle;

  /// No description provided for @composerSave.
  ///
  /// In vi, this message translates to:
  /// **'Lưu'**
  String get composerSave;

  /// No description provided for @composerPost.
  ///
  /// In vi, this message translates to:
  /// **'Đăng'**
  String get composerPost;

  /// No description provided for @composerContentHint.
  ///
  /// In vi, this message translates to:
  /// **'Bạn đang nghĩ gì?'**
  String get composerContentHint;

  /// No description provided for @composerSelectCategoryLabel.
  ///
  /// In vi, this message translates to:
  /// **'Chọn chuyên mục *'**
  String get composerSelectCategoryLabel;

  /// No description provided for @composerLocationHint.
  ///
  /// In vi, this message translates to:
  /// **'Địa danh (không bắt buộc) — vd. Quận 7, TP.HCM'**
  String get composerLocationHint;

  /// No description provided for @composerPhotos.
  ///
  /// In vi, this message translates to:
  /// **'Ảnh'**
  String get composerPhotos;

  /// No description provided for @composerDiscardTitle.
  ///
  /// In vi, this message translates to:
  /// **'Bỏ bài viết này?'**
  String get composerDiscardTitle;

  /// No description provided for @composerDiscardBody.
  ///
  /// In vi, this message translates to:
  /// **'Nội dung bạn đang soạn sẽ không được lưu.'**
  String get composerDiscardBody;

  /// No description provided for @composerKeepEditing.
  ///
  /// In vi, this message translates to:
  /// **'Tiếp tục soạn'**
  String get composerKeepEditing;

  /// No description provided for @composerDiscard.
  ///
  /// In vi, this message translates to:
  /// **'Bỏ'**
  String get composerDiscard;

  /// No description provided for @composerImagesCount.
  ///
  /// In vi, this message translates to:
  /// **'{count}/{max} ảnh'**
  String composerImagesCount(Object count, Object max);

  /// No description provided for @ctrListTitle.
  ///
  /// In vi, this message translates to:
  /// **'Nhà thầu · {name}'**
  String ctrListTitle(Object name);

  /// No description provided for @ctrListEmptyTitle.
  ///
  /// In vi, this message translates to:
  /// **'Chưa có nhà thầu trong khu vực'**
  String get ctrListEmptyTitle;

  /// No description provided for @ctrListEmptyBody.
  ///
  /// In vi, this message translates to:
  /// **'Gửi yêu cầu — chúng tôi sẽ kết nối đơn vị phù hợp cho bạn.'**
  String get ctrListEmptyBody;

  /// No description provided for @ctrListRequestConsult.
  ///
  /// In vi, this message translates to:
  /// **'Yêu cầu tư vấn'**
  String get ctrListRequestConsult;

  /// No description provided for @ctrListDefaultName.
  ///
  /// In vi, this message translates to:
  /// **'Nhà thầu'**
  String get ctrListDefaultName;

  /// No description provided for @ctrListBadgePromoted.
  ///
  /// In vi, this message translates to:
  /// **'Nổi bật'**
  String get ctrListBadgePromoted;

  /// No description provided for @ctrListBadgePro.
  ///
  /// In vi, this message translates to:
  /// **'Pro'**
  String get ctrListBadgePro;

  /// No description provided for @myPostsLoadError.
  ///
  /// In vi, this message translates to:
  /// **'Không tải được bài viết'**
  String get myPostsLoadError;

  /// No description provided for @myPostsLoadErrorHint.
  ///
  /// In vi, this message translates to:
  /// **'Kiểm tra kết nối rồi thử lại.'**
  String get myPostsLoadErrorHint;

  /// No description provided for @myPostsRetry.
  ///
  /// In vi, this message translates to:
  /// **'Thử lại'**
  String get myPostsRetry;

  /// No description provided for @myPostsEmptyTitle.
  ///
  /// In vi, this message translates to:
  /// **'Bạn chưa có bài viết nào'**
  String get myPostsEmptyTitle;

  /// No description provided for @myPostsEmptyHint.
  ///
  /// In vi, this message translates to:
  /// **'Bài bạn đăng ở Cộng đồng sẽ hiện tại đây.'**
  String get myPostsEmptyHint;

  /// No description provided for @plistSearchHint.
  ///
  /// In vi, this message translates to:
  /// **'Tìm theo tên, mô tả, địa chỉ…'**
  String get plistSearchHint;

  /// No description provided for @plistEmptyTitle.
  ///
  /// In vi, this message translates to:
  /// **'Không tìm thấy tin đăng phù hợp'**
  String get plistEmptyTitle;

  /// No description provided for @plistEmptySubtitle.
  ///
  /// In vi, this message translates to:
  /// **'Thử từ khoá khác hoặc quay lại sau.'**
  String get plistEmptySubtitle;

  /// No description provided for @plistAreaSqm.
  ///
  /// In vi, this message translates to:
  /// **'{area} m²'**
  String plistAreaSqm(Object area);

  /// No description provided for @qualityTitle.
  ///
  /// In vi, this message translates to:
  /// **'Chất lượng cơ sở'**
  String get qualityTitle;

  /// No description provided for @qualityVerified.
  ///
  /// In vi, this message translates to:
  /// **'Đã thẩm định'**
  String get qualityVerified;

  /// No description provided for @qualitySelfDeclared.
  ///
  /// In vi, this message translates to:
  /// **'Chủ tự khai'**
  String get qualitySelfDeclared;

  /// No description provided for @qualitySubtitle.
  ///
  /// In vi, this message translates to:
  /// **'Đánh giá tiện nghi — ảnh hưởng khung giá.'**
  String get qualitySubtitle;

  /// No description provided for @qualityStarRating.
  ///
  /// In vi, this message translates to:
  /// **'{star}/5'**
  String qualityStarRating(Object star);

  /// No description provided for @qualitySuggestedPrice.
  ///
  /// In vi, this message translates to:
  /// **'Giá gợi ý theo chất lượng: {price}/tháng'**
  String qualitySuggestedPrice(Object price);

  /// No description provided for @qualityNotDeclared.
  ///
  /// In vi, this message translates to:
  /// **'Chưa khai chất lượng.'**
  String get qualityNotDeclared;

  /// No description provided for @qualityUpdateButton.
  ///
  /// In vi, this message translates to:
  /// **'Cập nhật chất lượng'**
  String get qualityUpdateButton;

  /// No description provided for @qualityDeclareButton.
  ///
  /// In vi, this message translates to:
  /// **'Khai chất lượng nhà'**
  String get qualityDeclareButton;

  /// No description provided for @qualityVerifRequested.
  ///
  /// In vi, this message translates to:
  /// **'Đã gửi yêu cầu thẩm định'**
  String get qualityVerifRequested;

  /// No description provided for @qualityRequestVerification.
  ///
  /// In vi, this message translates to:
  /// **'Yêu cầu thẩm định thực tế'**
  String get qualityRequestVerification;

  /// No description provided for @qualityVerifSubmitted.
  ///
  /// In vi, this message translates to:
  /// **'Đã gửi yêu cầu thẩm định. Đội ngũ sẽ liên hệ kiểm tra.'**
  String get qualityVerifSubmitted;

  /// No description provided for @qualityRequestFailed.
  ///
  /// In vi, this message translates to:
  /// **'Không gửi được yêu cầu: {error}'**
  String qualityRequestFailed(Object error);

  /// No description provided for @reviewTitle.
  ///
  /// In vi, this message translates to:
  /// **'Đánh giá'**
  String get reviewTitle;

  /// No description provided for @reviewRatePrompt.
  ///
  /// In vi, this message translates to:
  /// **'Cho nhà này mấy sao?'**
  String get reviewRatePrompt;

  /// No description provided for @reviewStarTooltip.
  ///
  /// In vi, this message translates to:
  /// **'{count} sao'**
  String reviewStarTooltip(Object count);

  /// No description provided for @reviewCommentLabel.
  ///
  /// In vi, this message translates to:
  /// **'Cảm nhận của bạn'**
  String get reviewCommentLabel;

  /// No description provided for @reviewCommentHint.
  ///
  /// In vi, this message translates to:
  /// **'VD: Chủ nhà thân thiện, nhà sạch sẽ, đúng mô tả...'**
  String get reviewCommentHint;

  /// No description provided for @reviewSubmitButton.
  ///
  /// In vi, this message translates to:
  /// **'Gửi đánh giá'**
  String get reviewSubmitButton;

  /// No description provided for @reviewSubmitSuccess.
  ///
  /// In vi, this message translates to:
  /// **'Đã gửi đánh giá, cảm ơn bạn!'**
  String get reviewSubmitSuccess;

  /// No description provided for @reviewSubmitError.
  ///
  /// In vi, this message translates to:
  /// **'Gửi đánh giá thất bại: {error}'**
  String reviewSubmitError(Object error);

  /// No description provided for @rfqTitle.
  ///
  /// In vi, this message translates to:
  /// **'Yêu cầu tư vấn · {serviceName}'**
  String rfqTitle(Object serviceName);

  /// No description provided for @rfqSubtitle.
  ///
  /// In vi, this message translates to:
  /// **'Miễn phí · Không chia sẻ SĐT công khai'**
  String get rfqSubtitle;

  /// No description provided for @rfqFieldName.
  ///
  /// In vi, this message translates to:
  /// **'Họ tên *'**
  String get rfqFieldName;

  /// No description provided for @rfqFieldPhone.
  ///
  /// In vi, this message translates to:
  /// **'Số điện thoại *'**
  String get rfqFieldPhone;

  /// No description provided for @rfqFieldArea.
  ///
  /// In vi, this message translates to:
  /// **'Khu vực (tỉnh/quận)'**
  String get rfqFieldArea;

  /// No description provided for @rfqFieldBudget.
  ///
  /// In vi, this message translates to:
  /// **'Ngân sách dự kiến (tuỳ chọn)'**
  String get rfqFieldBudget;

  /// No description provided for @rfqFieldDesc.
  ///
  /// In vi, this message translates to:
  /// **'Mô tả nhu cầu'**
  String get rfqFieldDesc;

  /// No description provided for @rfqSubmit.
  ///
  /// In vi, this message translates to:
  /// **'Gửi yêu cầu'**
  String get rfqSubmit;

  /// No description provided for @rfqValidation.
  ///
  /// In vi, this message translates to:
  /// **'Vui lòng nhập tên và số điện thoại hợp lệ'**
  String get rfqValidation;

  /// No description provided for @rfqSendError.
  ///
  /// In vi, this message translates to:
  /// **'Gửi yêu cầu chưa thành công. Vui lòng kiểm tra kết nối và thử lại.'**
  String get rfqSendError;

  /// No description provided for @rfqSuccessTitle.
  ///
  /// In vi, this message translates to:
  /// **'Đã gửi yêu cầu!'**
  String get rfqSuccessTitle;

  /// No description provided for @rfqSuccessBody.
  ///
  /// In vi, this message translates to:
  /// **'Đội ngũ {serviceName} sẽ liên hệ bạn trong thời gian sớm nhất.'**
  String rfqSuccessBody(Object serviceName);

  /// No description provided for @rfqClose.
  ///
  /// In vi, this message translates to:
  /// **'Đóng'**
  String get rfqClose;

  /// No description provided for @searchHint.
  ///
  /// In vi, this message translates to:
  /// **'Tìm tin đăng, đơn vị, bài cộng đồng…'**
  String get searchHint;

  /// No description provided for @searchEmptyTitle.
  ///
  /// In vi, this message translates to:
  /// **'Tìm mọi thứ trên Vua Nhà'**
  String get searchEmptyTitle;

  /// No description provided for @searchEmptySubtitle.
  ///
  /// In vi, this message translates to:
  /// **'Tin cho thuê, đơn vị xây dựng/thiết kế, bài cộng đồng…'**
  String get searchEmptySubtitle;

  /// No description provided for @searchRecentTitle.
  ///
  /// In vi, this message translates to:
  /// **'TÌM KIẾM GẦN ĐÂY'**
  String get searchRecentTitle;

  /// No description provided for @searchClearAll.
  ///
  /// In vi, this message translates to:
  /// **'Xoá tất cả'**
  String get searchClearAll;

  /// No description provided for @searchNoResults.
  ///
  /// In vi, this message translates to:
  /// **'Không tìm thấy “{query}”'**
  String searchNoResults(Object query);

  /// No description provided for @searchNoResultsSubtitle.
  ///
  /// In vi, this message translates to:
  /// **'Thử bỏ dấu hoặc dùng từ khoá khác.'**
  String get searchNoResultsSubtitle;

  /// No description provided for @searchGroupHouses.
  ///
  /// In vi, this message translates to:
  /// **'TIN ĐĂNG'**
  String get searchGroupHouses;

  /// No description provided for @searchGroupContractors.
  ///
  /// In vi, this message translates to:
  /// **'ĐƠN VỊ'**
  String get searchGroupContractors;

  /// No description provided for @searchGroupPosts.
  ///
  /// In vi, this message translates to:
  /// **'BÀI CỘNG ĐỒNG'**
  String get searchGroupPosts;

  /// No description provided for @searchHouseFallback.
  ///
  /// In vi, this message translates to:
  /// **'Tin đăng'**
  String get searchHouseFallback;

  /// No description provided for @searchContractorFallback.
  ///
  /// In vi, this message translates to:
  /// **'Đơn vị'**
  String get searchContractorFallback;

  /// No description provided for @searchRating.
  ///
  /// In vi, this message translates to:
  /// **'⭐ {rating} · {count} đánh giá'**
  String searchRating(Object rating, Object count);

  /// No description provided for @settingsMyPreferences.
  ///
  /// In vi, this message translates to:
  /// **'Sở thích của tôi'**
  String get settingsMyPreferences;

  /// No description provided for @settingsMyPreferencesSub.
  ///
  /// In vi, this message translates to:
  /// **'Cá nhân hoá theo mục đích & khu vực'**
  String get settingsMyPreferencesSub;

  /// No description provided for @settingsLogoutConfirm.
  ///
  /// In vi, this message translates to:
  /// **'Bạn chắc chắn muốn đăng xuất?'**
  String get settingsLogoutConfirm;

  /// No description provided for @settingsLoggedOut.
  ///
  /// In vi, this message translates to:
  /// **'Đã đăng xuất'**
  String get settingsLoggedOut;

  /// No description provided for @wishEyebrow.
  ///
  /// In vi, this message translates to:
  /// **'Đã đánh dấu'**
  String get wishEyebrow;

  /// No description provided for @wishTitle.
  ///
  /// In vi, this message translates to:
  /// **'Yêu thích'**
  String get wishTitle;

  /// No description provided for @wishCompareTooltip.
  ///
  /// In vi, this message translates to:
  /// **'So sánh'**
  String get wishCompareTooltip;

  /// No description provided for @wishRefreshTooltip.
  ///
  /// In vi, this message translates to:
  /// **'Làm mới'**
  String get wishRefreshTooltip;

  /// No description provided for @wishEmptyTitle.
  ///
  /// In vi, this message translates to:
  /// **'Chưa có phòng nào'**
  String get wishEmptyTitle;

  /// No description provided for @wishEmptySubtitle.
  ///
  /// In vi, this message translates to:
  /// **'Bấm trái tim trên phòng bạn thích để lưu vào đây.'**
  String get wishEmptySubtitle;

  /// No description provided for @wishUnfavoriteTooltip.
  ///
  /// In vi, this message translates to:
  /// **'Bỏ yêu thích'**
  String get wishUnfavoriteTooltip;

  /// No description provided for @wishUnfavoriteError.
  ///
  /// In vi, this message translates to:
  /// **'Không thể bỏ yêu thích'**
  String get wishUnfavoriteError;

  /// No description provided for @hApprovalInboxTitle.
  ///
  /// In vi, this message translates to:
  /// **'Hộp phê duyệt'**
  String get hApprovalInboxTitle;

  /// No description provided for @hApprovalInboxEyebrow.
  ///
  /// In vi, this message translates to:
  /// **'CHỦ NHÀ · PHÊ DUYỆT'**
  String get hApprovalInboxEyebrow;

  /// No description provided for @hApprovalEmptyTitle.
  ///
  /// In vi, this message translates to:
  /// **'Không có yêu cầu nào'**
  String get hApprovalEmptyTitle;

  /// No description provided for @hApprovalEmptySubtitle.
  ///
  /// In vi, this message translates to:
  /// **'Khi Operator cần phê duyệt, yêu cầu sẽ xuất hiện ở đây.'**
  String get hApprovalEmptySubtitle;

  /// No description provided for @hApprovalBiometricReason.
  ///
  /// In vi, this message translates to:
  /// **'Xác thực để phê duyệt giao dịch {amount}'**
  String hApprovalBiometricReason(Object amount);

  /// No description provided for @hApprovalBiometricRequired.
  ///
  /// In vi, this message translates to:
  /// **'Cần xác thực sinh trắc học để tiếp tục'**
  String get hApprovalBiometricRequired;

  /// No description provided for @hApprovalApproveSuccess.
  ///
  /// In vi, this message translates to:
  /// **'Đã phê duyệt thành công'**
  String get hApprovalApproveSuccess;

  /// No description provided for @hApprovalApproveFailed.
  ///
  /// In vi, this message translates to:
  /// **'Phê duyệt thất bại. Thử lại.'**
  String get hApprovalApproveFailed;

  /// No description provided for @hApprovalRejectSuccess.
  ///
  /// In vi, this message translates to:
  /// **'Đã từ chối yêu cầu'**
  String get hApprovalRejectSuccess;

  /// No description provided for @hApprovalRejectReasonTitle.
  ///
  /// In vi, this message translates to:
  /// **'Lý do từ chối'**
  String get hApprovalRejectReasonTitle;

  /// No description provided for @hApprovalRejectReasonHint.
  ///
  /// In vi, this message translates to:
  /// **'Lý do (không bắt buộc)'**
  String get hApprovalRejectReasonHint;

  /// No description provided for @hApprovalSkip.
  ///
  /// In vi, this message translates to:
  /// **'Bỏ qua'**
  String get hApprovalSkip;

  /// No description provided for @hApprovalReject.
  ///
  /// In vi, this message translates to:
  /// **'Từ chối'**
  String get hApprovalReject;

  /// No description provided for @hApptTitle.
  ///
  /// In vi, this message translates to:
  /// **'YÊU CẦU XEM PHÒNG'**
  String get hApptTitle;

  /// No description provided for @hApptEmpty.
  ///
  /// In vi, this message translates to:
  /// **'Không có yêu cầu nào.'**
  String get hApptEmpty;

  /// No description provided for @hApptCompletedDeals.
  ///
  /// In vi, this message translates to:
  /// **'{count} giao dịch đã hoàn tất'**
  String hApptCompletedDeals(Object count);

  /// No description provided for @hApptRateGuest.
  ///
  /// In vi, this message translates to:
  /// **'Đánh giá khách'**
  String get hApptRateGuest;

  /// No description provided for @hApptRateGuestTitle.
  ///
  /// In vi, this message translates to:
  /// **'Đánh giá {name}'**
  String hApptRateGuestTitle(Object name);

  /// No description provided for @hApptGuestFallback.
  ///
  /// In vi, this message translates to:
  /// **'khách'**
  String get hApptGuestFallback;

  /// No description provided for @hApptReviewHint.
  ///
  /// In vi, this message translates to:
  /// **'Nhận xét (tuỳ chọn)'**
  String get hApptReviewHint;

  /// No description provided for @hApptCancel.
  ///
  /// In vi, this message translates to:
  /// **'Huỷ'**
  String get hApptCancel;

  /// No description provided for @hApptSend.
  ///
  /// In vi, this message translates to:
  /// **'Gửi'**
  String get hApptSend;

  /// No description provided for @hApptReviewSuccess.
  ///
  /// In vi, this message translates to:
  /// **'Đã đánh giá khách'**
  String get hApptReviewSuccess;

  /// No description provided for @hApptReviewFailed.
  ///
  /// In vi, this message translates to:
  /// **'Không đánh giá được: {error}'**
  String hApptReviewFailed(Object error);

  /// No description provided for @hApptEmptyHintPending.
  ///
  /// In vi, this message translates to:
  /// **'Khi khách gửi yêu cầu xem, sẽ hiện tại đây.'**
  String get hApptEmptyHintPending;

  /// No description provided for @hApptEmptyHintApproved.
  ///
  /// In vi, this message translates to:
  /// **'Chưa có lịch hẹn nào đã duyệt.'**
  String get hApptEmptyHintApproved;

  /// No description provided for @hApptEmptyHintPast.
  ///
  /// In vi, this message translates to:
  /// **'Chưa có yêu cầu nào đã đóng hoặc bị từ chối.'**
  String get hApptEmptyHintPast;

  /// No description provided for @hApptTabPending.
  ///
  /// In vi, this message translates to:
  /// **'CHỜ DUYỆT'**
  String get hApptTabPending;

  /// No description provided for @hApptTabApproved.
  ///
  /// In vi, this message translates to:
  /// **'ĐÃ DUYỆT'**
  String get hApptTabApproved;

  /// No description provided for @hApptTabClosed.
  ///
  /// In vi, this message translates to:
  /// **'ĐÃ ĐÓNG'**
  String get hApptTabClosed;

  /// No description provided for @hAvailTitle.
  ///
  /// In vi, this message translates to:
  /// **'Khung giờ nhận xem nhà'**
  String get hAvailTitle;

  /// No description provided for @hAvailWeekdaysSection.
  ///
  /// In vi, this message translates to:
  /// **'Ngày trong tuần nhận khách'**
  String get hAvailWeekdaysSection;

  /// No description provided for @hAvailSlotsSection.
  ///
  /// In vi, this message translates to:
  /// **'Khung giờ tiếp khách (mỗi khung 1 tiếng)'**
  String get hAvailSlotsSection;

  /// No description provided for @hAvailSelectAll.
  ///
  /// In vi, this message translates to:
  /// **'Chọn tất cả'**
  String get hAvailSelectAll;

  /// No description provided for @hAvailDeselect.
  ///
  /// In vi, this message translates to:
  /// **'Bỏ chọn'**
  String get hAvailDeselect;

  /// No description provided for @hAvailSave.
  ///
  /// In vi, this message translates to:
  /// **'Lưu khung giờ'**
  String get hAvailSave;

  /// No description provided for @hAvailSavedToast.
  ///
  /// In vi, this message translates to:
  /// **'Đã lưu khung giờ nhận xem nhà.'**
  String get hAvailSavedToast;

  /// No description provided for @hAvailSaveFailed.
  ///
  /// In vi, this message translates to:
  /// **'Lưu thất bại'**
  String get hAvailSaveFailed;

  /// No description provided for @hAvailIntroDefault.
  ///
  /// In vi, this message translates to:
  /// **'Bạn đang nhận khách xem nhà tất cả các ngày, mọi khung giờ. Thu hẹp lại nếu chỉ muốn tiếp khách vào một số thời điểm.'**
  String get hAvailIntroDefault;

  /// No description provided for @hAvailIntroCustom.
  ///
  /// In vi, this message translates to:
  /// **'Khách chỉ có thể đặt lịch xem nhà trong các ngày và khung giờ bạn chọn dưới đây.'**
  String get hAvailIntroCustom;

  /// No description provided for @hAvailEmptyWarning.
  ///
  /// In vi, this message translates to:
  /// **'Chưa chọn ngày hoặc khung giờ nào — khách sẽ không thể đặt lịch xem nhà.'**
  String get hAvailEmptyWarning;

  /// No description provided for @hAvailMon.
  ///
  /// In vi, this message translates to:
  /// **'T2'**
  String get hAvailMon;

  /// No description provided for @hAvailTue.
  ///
  /// In vi, this message translates to:
  /// **'T3'**
  String get hAvailTue;

  /// No description provided for @hAvailWed.
  ///
  /// In vi, this message translates to:
  /// **'T4'**
  String get hAvailWed;

  /// No description provided for @hAvailThu.
  ///
  /// In vi, this message translates to:
  /// **'T5'**
  String get hAvailThu;

  /// No description provided for @hAvailFri.
  ///
  /// In vi, this message translates to:
  /// **'T6'**
  String get hAvailFri;

  /// No description provided for @hAvailSat.
  ///
  /// In vi, this message translates to:
  /// **'T7'**
  String get hAvailSat;

  /// No description provided for @hAvailSun.
  ///
  /// In vi, this message translates to:
  /// **'CN'**
  String get hAvailSun;

  /// No description provided for @hContractDetTitle.
  ///
  /// In vi, this message translates to:
  /// **'Hợp đồng'**
  String get hContractDetTitle;

  /// No description provided for @hContractDetNotFound.
  ///
  /// In vi, this message translates to:
  /// **'Không tìm thấy hợp đồng'**
  String get hContractDetNotFound;

  /// No description provided for @hContractDetStartDate.
  ///
  /// In vi, this message translates to:
  /// **'Ngày bắt đầu'**
  String get hContractDetStartDate;

  /// No description provided for @hContractDetEndDate.
  ///
  /// In vi, this message translates to:
  /// **'Ngày kết thúc'**
  String get hContractDetEndDate;

  /// No description provided for @hContractDetRent.
  ///
  /// In vi, this message translates to:
  /// **'Tiền thuê'**
  String get hContractDetRent;

  /// No description provided for @hContractDetRentPerMonth.
  ///
  /// In vi, this message translates to:
  /// **'{amount} đ/tháng'**
  String hContractDetRentPerMonth(Object amount);

  /// No description provided for @hContractDetDeposit.
  ///
  /// In vi, this message translates to:
  /// **'Đặt cọc'**
  String get hContractDetDeposit;

  /// No description provided for @hContractDetAmountDong.
  ///
  /// In vi, this message translates to:
  /// **'{amount} đ'**
  String hContractDetAmountDong(Object amount);

  /// No description provided for @hContractDetTenants.
  ///
  /// In vi, this message translates to:
  /// **'Người thuê'**
  String get hContractDetTenants;

  /// No description provided for @hContractDetRepresentative.
  ///
  /// In vi, this message translates to:
  /// **'Đại diện'**
  String get hContractDetRepresentative;

  /// No description provided for @hContractDetActivate.
  ///
  /// In vi, this message translates to:
  /// **'Kích hoạt hợp đồng'**
  String get hContractDetActivate;

  /// No description provided for @hContractDetCheckout.
  ///
  /// In vi, this message translates to:
  /// **'Trả phòng (kết thúc)'**
  String get hContractDetCheckout;

  /// No description provided for @hContractDetTransferRoom.
  ///
  /// In vi, this message translates to:
  /// **'Chuyển phòng'**
  String get hContractDetTransferRoom;

  /// No description provided for @hContractDetActualEndDate.
  ///
  /// In vi, this message translates to:
  /// **'Ngày trả thực tế'**
  String get hContractDetActualEndDate;

  /// No description provided for @hContractDetDepositRefund.
  ///
  /// In vi, this message translates to:
  /// **'Hoàn cọc'**
  String get hContractDetDepositRefund;

  /// No description provided for @hContractDetDamage.
  ///
  /// In vi, this message translates to:
  /// **'Hư hại'**
  String get hContractDetDamage;

  /// No description provided for @hContractDetStatusDraft.
  ///
  /// In vi, this message translates to:
  /// **'Bản thảo'**
  String get hContractDetStatusDraft;

  /// No description provided for @hContractDetStatusActive.
  ///
  /// In vi, this message translates to:
  /// **'Đang hoạt động'**
  String get hContractDetStatusActive;

  /// No description provided for @hContractDetStatusExpired.
  ///
  /// In vi, this message translates to:
  /// **'Hết hạn'**
  String get hContractDetStatusExpired;

  /// No description provided for @hContractDetStatusTerminated.
  ///
  /// In vi, this message translates to:
  /// **'Đã kết thúc'**
  String get hContractDetStatusTerminated;

  /// No description provided for @hContractDetActivateEyebrow.
  ///
  /// In vi, this message translates to:
  /// **'Kích hoạt'**
  String get hContractDetActivateEyebrow;

  /// No description provided for @hContractDetActivateConfirmMsg.
  ///
  /// In vi, this message translates to:
  /// **'Kích hoạt hợp đồng sẽ chuyển phòng sang trạng thái \"Đang thuê\". Tiếp tục?'**
  String get hContractDetActivateConfirmMsg;

  /// No description provided for @hContractDetActivateSuccess.
  ///
  /// In vi, this message translates to:
  /// **'Đã kích hoạt hợp đồng'**
  String get hContractDetActivateSuccess;

  /// No description provided for @hContractDetFailed.
  ///
  /// In vi, this message translates to:
  /// **'Thất bại'**
  String get hContractDetFailed;

  /// No description provided for @hContractFormTitle.
  ///
  /// In vi, this message translates to:
  /// **'Hợp đồng mới'**
  String get hContractFormTitle;

  /// No description provided for @hContractFormEyebrow.
  ///
  /// In vi, this message translates to:
  /// **'Tờ khai'**
  String get hContractFormEyebrow;

  /// No description provided for @hContractFormStartDate.
  ///
  /// In vi, this message translates to:
  /// **'Ngày bắt đầu *'**
  String get hContractFormStartDate;

  /// No description provided for @hContractFormEndDate.
  ///
  /// In vi, this message translates to:
  /// **'Ngày kết thúc *'**
  String get hContractFormEndDate;

  /// No description provided for @hContractFormMonthlyRent.
  ///
  /// In vi, this message translates to:
  /// **'Tiền thuê/tháng (VNĐ) *'**
  String get hContractFormMonthlyRent;

  /// No description provided for @hContractFormRentInvalid.
  ///
  /// In vi, this message translates to:
  /// **'Nhập số tiền hợp lệ'**
  String get hContractFormRentInvalid;

  /// No description provided for @hContractFormDeposit.
  ///
  /// In vi, this message translates to:
  /// **'Tiền đặt cọc (VNĐ)'**
  String get hContractFormDeposit;

  /// No description provided for @hContractFormSubmit.
  ///
  /// In vi, this message translates to:
  /// **'Tạo hợp đồng'**
  String get hContractFormSubmit;

  /// No description provided for @hContractFormSelectDates.
  ///
  /// In vi, this message translates to:
  /// **'Vui lòng chọn ngày bắt đầu và kết thúc'**
  String get hContractFormSelectDates;

  /// No description provided for @hContractFormEndAfterStart.
  ///
  /// In vi, this message translates to:
  /// **'Ngày kết thúc phải sau ngày bắt đầu'**
  String get hContractFormEndAfterStart;

  /// No description provided for @hContractFormOnePrimary.
  ///
  /// In vi, this message translates to:
  /// **'Phải có đúng 1 người thuê chính (đại diện)'**
  String get hContractFormOnePrimary;

  /// No description provided for @hContractFormTenantNameRequired.
  ///
  /// In vi, this message translates to:
  /// **'Họ tên người thuê không được để trống'**
  String get hContractFormTenantNameRequired;

  /// No description provided for @hContractFormCreated.
  ///
  /// In vi, this message translates to:
  /// **'Đã tạo hợp đồng (trạng thái: bản thảo)'**
  String get hContractFormCreated;

  /// No description provided for @hContractFormCreateFailed.
  ///
  /// In vi, this message translates to:
  /// **'Tạo thất bại'**
  String get hContractFormCreateFailed;

  /// No description provided for @hContractFormPhotoUploadFailed.
  ///
  /// In vi, this message translates to:
  /// **'Tải ảnh thất bại: {error}'**
  String hContractFormPhotoUploadFailed(Object error);

  /// No description provided for @hContractFormCccdUploadFailed.
  ///
  /// In vi, this message translates to:
  /// **'Tải ảnh CCCD thất bại: {error}'**
  String hContractFormCccdUploadFailed(Object error);

  /// No description provided for @hContractTermUploadFailed.
  ///
  /// In vi, this message translates to:
  /// **'Tải ảnh thất bại: {error}'**
  String hContractTermUploadFailed(Object error);

  /// No description provided for @hContractTermActionEnd.
  ///
  /// In vi, this message translates to:
  /// **'kết thúc hợp đồng'**
  String get hContractTermActionEnd;

  /// No description provided for @hContractTermPickDateFirst.
  ///
  /// In vi, this message translates to:
  /// **'Vui lòng chọn ngày trả phòng thực tế'**
  String get hContractTermPickDateFirst;

  /// No description provided for @hContractTermEnd.
  ///
  /// In vi, this message translates to:
  /// **'Kết thúc'**
  String get hContractTermEnd;

  /// No description provided for @hContractTermConfirmTitle.
  ///
  /// In vi, this message translates to:
  /// **'Xác nhận kết thúc hợp đồng'**
  String get hContractTermConfirmTitle;

  /// No description provided for @hContractTermConfirmMessage.
  ///
  /// In vi, this message translates to:
  /// **'Bạn có chắc muốn kết thúc hợp đồng này?\nThao tác không thể hoàn tác.'**
  String get hContractTermConfirmMessage;

  /// No description provided for @hContractTermDoneEnded.
  ///
  /// In vi, this message translates to:
  /// **'Đã kết thúc hợp đồng'**
  String get hContractTermDoneEnded;

  /// No description provided for @hContractTermFailed.
  ///
  /// In vi, this message translates to:
  /// **'Thất bại'**
  String get hContractTermFailed;

  /// No description provided for @hContractTermMoveOut.
  ///
  /// In vi, this message translates to:
  /// **'Trả phòng'**
  String get hContractTermMoveOut;

  /// No description provided for @hContractTermIntro.
  ///
  /// In vi, this message translates to:
  /// **'Xác nhận ngày trả phòng thực tế và thông tin hoàn cọc.'**
  String get hContractTermIntro;

  /// No description provided for @hContractTermActualEndDate.
  ///
  /// In vi, this message translates to:
  /// **'Ngày trả phòng thực tế *'**
  String get hContractTermActualEndDate;

  /// No description provided for @hContractTermPickDate.
  ///
  /// In vi, this message translates to:
  /// **'Chọn ngày'**
  String get hContractTermPickDate;

  /// No description provided for @hContractTermRefundAmount.
  ///
  /// In vi, this message translates to:
  /// **'Số tiền hoàn cọc (VNĐ)'**
  String get hContractTermRefundAmount;

  /// No description provided for @hContractTermRefundHelper.
  ///
  /// In vi, this message translates to:
  /// **'Nhập 0 nếu không hoàn'**
  String get hContractTermRefundHelper;

  /// No description provided for @hContractTermDamageNote.
  ///
  /// In vi, this message translates to:
  /// **'Ghi chú hư hại'**
  String get hContractTermDamageNote;

  /// No description provided for @hContractTermDamageNoteHelper.
  ///
  /// In vi, this message translates to:
  /// **'Mô tả thiệt hại nếu có'**
  String get hContractTermDamageNoteHelper;

  /// No description provided for @hContractTermDamagePhotos.
  ///
  /// In vi, this message translates to:
  /// **'Ảnh hư hại'**
  String get hContractTermDamagePhotos;

  /// No description provided for @hContractTermAddPhoto.
  ///
  /// In vi, this message translates to:
  /// **'Thêm ảnh'**
  String get hContractTermAddPhoto;

  /// No description provided for @hContractTermConfirmMoveOut.
  ///
  /// In vi, this message translates to:
  /// **'Xác nhận trả phòng'**
  String get hContractTermConfirmMoveOut;

  /// No description provided for @hContractXferTransferRoom.
  ///
  /// In vi, this message translates to:
  /// **'Chuyển phòng'**
  String get hContractXferTransferRoom;

  /// No description provided for @hContractXferActionTransfer.
  ///
  /// In vi, this message translates to:
  /// **'chuyển phòng'**
  String get hContractXferActionTransfer;

  /// No description provided for @hContractXferContractEyebrow.
  ///
  /// In vi, this message translates to:
  /// **'Hợp đồng'**
  String get hContractXferContractEyebrow;

  /// No description provided for @hContractXferIntro.
  ///
  /// In vi, this message translates to:
  /// **'Chọn tòa nhà và phòng trống để chuyển hợp đồng sang.'**
  String get hContractXferIntro;

  /// No description provided for @hContractXferBuildingLabel.
  ///
  /// In vi, this message translates to:
  /// **'Tòa nhà *'**
  String get hContractXferBuildingLabel;

  /// No description provided for @hContractXferNoBuildings.
  ///
  /// In vi, this message translates to:
  /// **'Không có tòa nhà'**
  String get hContractXferNoBuildings;

  /// No description provided for @hContractXferSelectBuilding.
  ///
  /// In vi, this message translates to:
  /// **'Chọn tòa nhà'**
  String get hContractXferSelectBuilding;

  /// No description provided for @hContractXferNoVacantRooms.
  ///
  /// In vi, this message translates to:
  /// **'Không có phòng trống trong tòa nhà này.'**
  String get hContractXferNoVacantRooms;

  /// No description provided for @hContractXferVacantRoomLabel.
  ///
  /// In vi, this message translates to:
  /// **'Phòng trống *'**
  String get hContractXferVacantRoomLabel;

  /// No description provided for @hContractXferSelectRoom.
  ///
  /// In vi, this message translates to:
  /// **'Chọn phòng'**
  String get hContractXferSelectRoom;

  /// No description provided for @hContractXferRoomOption.
  ///
  /// In vi, this message translates to:
  /// **'{code} — {price} đ/tháng'**
  String hContractXferRoomOption(Object code, Object price);

  /// No description provided for @hContractXferConfirmTitle.
  ///
  /// In vi, this message translates to:
  /// **'Xác nhận chuyển phòng'**
  String get hContractXferConfirmTitle;

  /// No description provided for @hContractXferConfirmMessage.
  ///
  /// In vi, this message translates to:
  /// **'Bạn có chắc muốn chuyển hợp đồng sang phòng {roomName}?\nPhòng cũ sẽ trở thành \"Trống\".'**
  String hContractXferConfirmMessage(Object roomName);

  /// No description provided for @hContractXferSuccess.
  ///
  /// In vi, this message translates to:
  /// **'Đã chuyển hợp đồng sang phòng {roomName}'**
  String hContractXferSuccess(Object roomName);

  /// No description provided for @hContractXferFailed.
  ///
  /// In vi, this message translates to:
  /// **'Thất bại'**
  String get hContractXferFailed;

  /// No description provided for @hContractXferLoadRoomsError.
  ///
  /// In vi, this message translates to:
  /// **'Không thể tải phòng'**
  String get hContractXferLoadRoomsError;

  /// No description provided for @hDelegDetNotFound.
  ///
  /// In vi, this message translates to:
  /// **'Không tìm thấy'**
  String get hDelegDetNotFound;

  /// No description provided for @hDelegDetNotFoundDelegation.
  ///
  /// In vi, this message translates to:
  /// **'Không tìm thấy ủy thác'**
  String get hDelegDetNotFoundDelegation;

  /// No description provided for @hDelegDetOperator.
  ///
  /// In vi, this message translates to:
  /// **'Operator'**
  String get hDelegDetOperator;

  /// No description provided for @hDelegDetEyebrow.
  ///
  /// In vi, this message translates to:
  /// **'CHỦ NHÀ · QUẢN LÝ ỦY THÁC'**
  String get hDelegDetEyebrow;

  /// No description provided for @hDelegDetPausedToast.
  ///
  /// In vi, this message translates to:
  /// **'Đã tạm dừng ủy thác'**
  String get hDelegDetPausedToast;

  /// No description provided for @hDelegDetResumedToast.
  ///
  /// In vi, this message translates to:
  /// **'Đã tiếp tục ủy thác'**
  String get hDelegDetResumedToast;

  /// No description provided for @hDelegDetTerminateTitle.
  ///
  /// In vi, this message translates to:
  /// **'Chấm dứt ủy thác?'**
  String get hDelegDetTerminateTitle;

  /// No description provided for @hDelegDetTerminateBody.
  ///
  /// In vi, this message translates to:
  /// **'Operator sẽ mất quyền truy cập sau 30 ngày. Hành động này không thể hoàn tác.'**
  String get hDelegDetTerminateBody;

  /// No description provided for @hDelegDetTerminate.
  ///
  /// In vi, this message translates to:
  /// **'Chấm dứt'**
  String get hDelegDetTerminate;

  /// No description provided for @hDelegDetTerminatedToast.
  ///
  /// In vi, this message translates to:
  /// **'Đã chấm dứt ủy thác'**
  String get hDelegDetTerminatedToast;

  /// No description provided for @hDelegDetThresholdsUpdatedToast.
  ///
  /// In vi, this message translates to:
  /// **'Đã cập nhật ngưỡng phê duyệt'**
  String get hDelegDetThresholdsUpdatedToast;

  /// No description provided for @hDelegDetPermissionLabel.
  ///
  /// In vi, this message translates to:
  /// **'Quyền: {role}'**
  String hDelegDetPermissionLabel(Object role);

  /// No description provided for @hDelegDetStartLabel.
  ///
  /// In vi, this message translates to:
  /// **'Bắt đầu: {date}'**
  String hDelegDetStartLabel(Object date);

  /// No description provided for @hDelegDetPropertiesLabel.
  ///
  /// In vi, this message translates to:
  /// **'Tài sản: {count}'**
  String hDelegDetPropertiesLabel(Object count);

  /// No description provided for @hDelegDetStatusActive.
  ///
  /// In vi, this message translates to:
  /// **'Đang hoạt động'**
  String get hDelegDetStatusActive;

  /// No description provided for @hDelegDetStatusPaused.
  ///
  /// In vi, this message translates to:
  /// **'Tạm dừng'**
  String get hDelegDetStatusPaused;

  /// No description provided for @hDelegDetStatusTerminated.
  ///
  /// In vi, this message translates to:
  /// **'Đã chấm dứt'**
  String get hDelegDetStatusTerminated;

  /// No description provided for @hDelegDetRoleOperatorFull.
  ///
  /// In vi, this message translates to:
  /// **'Vận hành đầy đủ'**
  String get hDelegDetRoleOperatorFull;

  /// No description provided for @hDelegDetRoleAccountant.
  ///
  /// In vi, this message translates to:
  /// **'Kế toán'**
  String get hDelegDetRoleAccountant;

  /// No description provided for @hDelegDetRoleViewer.
  ///
  /// In vi, this message translates to:
  /// **'Chỉ xem'**
  String get hDelegDetRoleViewer;

  /// No description provided for @hDelegDetRoleOwnerView.
  ///
  /// In vi, this message translates to:
  /// **'Chủ nhà (xem)'**
  String get hDelegDetRoleOwnerView;

  /// No description provided for @hDelegDetPause.
  ///
  /// In vi, this message translates to:
  /// **'Tạm dừng'**
  String get hDelegDetPause;

  /// No description provided for @hDelegDetResume.
  ///
  /// In vi, this message translates to:
  /// **'Tiếp tục'**
  String get hDelegDetResume;

  /// No description provided for @hDelegDetThresholds.
  ///
  /// In vi, this message translates to:
  /// **'Ngưỡng phê duyệt'**
  String get hDelegDetThresholds;

  /// No description provided for @hDelegDetEdit.
  ///
  /// In vi, this message translates to:
  /// **'Chỉnh sửa'**
  String get hDelegDetEdit;

  /// No description provided for @hDelegDetSaveThresholds.
  ///
  /// In vi, this message translates to:
  /// **'Lưu ngưỡng'**
  String get hDelegDetSaveThresholds;

  /// No description provided for @hDelegInvTitle.
  ///
  /// In vi, this message translates to:
  /// **'Mời Operator'**
  String get hDelegInvTitle;

  /// No description provided for @hDelegInvEyebrow.
  ///
  /// In vi, this message translates to:
  /// **'CHỦ NHÀ · ỦY THÁC'**
  String get hDelegInvEyebrow;

  /// No description provided for @hDelegInvOperatorInfo.
  ///
  /// In vi, this message translates to:
  /// **'Thông tin Operator'**
  String get hDelegInvOperatorInfo;

  /// No description provided for @hDelegInvOperatorEmail.
  ///
  /// In vi, this message translates to:
  /// **'Email Operator'**
  String get hDelegInvOperatorEmail;

  /// No description provided for @hDelegInvPermissions.
  ///
  /// In vi, this message translates to:
  /// **'Quyền hạn'**
  String get hDelegInvPermissions;

  /// No description provided for @hDelegInvThresholds.
  ///
  /// In vi, this message translates to:
  /// **'Ngưỡng phê duyệt (VND)'**
  String get hDelegInvThresholds;

  /// No description provided for @hDelegInvSend.
  ///
  /// In vi, this message translates to:
  /// **'Gửi lời mời'**
  String get hDelegInvSend;

  /// No description provided for @hDelegInvRoleOperatorFull.
  ///
  /// In vi, this message translates to:
  /// **'Vận hành đầy đủ'**
  String get hDelegInvRoleOperatorFull;

  /// No description provided for @hDelegInvRoleAccountant.
  ///
  /// In vi, this message translates to:
  /// **'Kế toán'**
  String get hDelegInvRoleAccountant;

  /// No description provided for @hDelegInvRoleViewer.
  ///
  /// In vi, this message translates to:
  /// **'Chỉ xem'**
  String get hDelegInvRoleViewer;

  /// No description provided for @hDelegInvEmailRequired.
  ///
  /// In vi, this message translates to:
  /// **'Vui lòng nhập email'**
  String get hDelegInvEmailRequired;

  /// No description provided for @hDelegInvEmailInvalid.
  ///
  /// In vi, this message translates to:
  /// **'Email không hợp lệ'**
  String get hDelegInvEmailInvalid;

  /// No description provided for @hDelegInvSendSuccess.
  ///
  /// In vi, this message translates to:
  /// **'Đã gửi lời mời thành công'**
  String get hDelegInvSendSuccess;

  /// No description provided for @hDelegInvSendFailed.
  ///
  /// In vi, this message translates to:
  /// **'Không thể gửi lời mời. Thử lại.'**
  String get hDelegInvSendFailed;

  /// No description provided for @hFeeTitle.
  ///
  /// In vi, this message translates to:
  /// **'PHÍ DỊCH VỤ'**
  String get hFeeTitle;

  /// No description provided for @hFeeCreateBuildingFirst.
  ///
  /// In vi, this message translates to:
  /// **'Vui lòng tạo toà nhà trước'**
  String get hFeeCreateBuildingFirst;

  /// No description provided for @hFeeEmptyTitle.
  ///
  /// In vi, this message translates to:
  /// **'Chưa có phí dịch vụ'**
  String get hFeeEmptyTitle;

  /// No description provided for @hFeeEmptySubtitle.
  ///
  /// In vi, this message translates to:
  /// **'Thêm phí dịch vụ để quản lý.'**
  String get hFeeEmptySubtitle;

  /// No description provided for @hFeeMonthly.
  ///
  /// In vi, this message translates to:
  /// **'Hàng tháng'**
  String get hFeeMonthly;

  /// No description provided for @hFeeOneTime.
  ///
  /// In vi, this message translates to:
  /// **'Một lần'**
  String get hFeeOneTime;

  /// No description provided for @hFeeActive.
  ///
  /// In vi, this message translates to:
  /// **'Hoạt động'**
  String get hFeeActive;

  /// No description provided for @hFeeInactive.
  ///
  /// In vi, this message translates to:
  /// **'Ngừng'**
  String get hFeeInactive;

  /// No description provided for @hFeeEnterNameBuilding.
  ///
  /// In vi, this message translates to:
  /// **'Vui lòng nhập tên và toà nhà'**
  String get hFeeEnterNameBuilding;

  /// No description provided for @hFeeSaveFailed.
  ///
  /// In vi, this message translates to:
  /// **'Lưu thất bại'**
  String get hFeeSaveFailed;

  /// No description provided for @hFeeCreateTitle.
  ///
  /// In vi, this message translates to:
  /// **'THÊM PHÍ DỊCH VỤ'**
  String get hFeeCreateTitle;

  /// No description provided for @hFeeBuilding.
  ///
  /// In vi, this message translates to:
  /// **'Toà nhà'**
  String get hFeeBuilding;

  /// No description provided for @hFeeServiceName.
  ///
  /// In vi, this message translates to:
  /// **'Tên dịch vụ'**
  String get hFeeServiceName;

  /// No description provided for @hFeeUnitPrice.
  ///
  /// In vi, this message translates to:
  /// **'Đơn giá (VND)'**
  String get hFeeUnitPrice;

  /// No description provided for @hFeeCycle.
  ///
  /// In vi, this message translates to:
  /// **'Chu kỳ'**
  String get hFeeCycle;

  /// No description provided for @hFeeSave.
  ///
  /// In vi, this message translates to:
  /// **'Lưu'**
  String get hFeeSave;

  /// No description provided for @hHomeDlgActionDelete.
  ///
  /// In vi, this message translates to:
  /// **'xoá tin'**
  String get hHomeDlgActionDelete;

  /// No description provided for @hHomeDlgDeleteTitle.
  ///
  /// In vi, this message translates to:
  /// **'Xoá tin đăng'**
  String get hHomeDlgDeleteTitle;

  /// No description provided for @hHomeDlgDeleteBody.
  ///
  /// In vi, this message translates to:
  /// **'Bạn có chắc muốn xoá \"{title}\"?'**
  String hHomeDlgDeleteBody(Object title);

  /// No description provided for @hHomeDlgDeleteConfirm.
  ///
  /// In vi, this message translates to:
  /// **'Xoá'**
  String get hHomeDlgDeleteConfirm;

  /// No description provided for @hHomeDlgDeleteSuccess.
  ///
  /// In vi, this message translates to:
  /// **'Đã xoá tin'**
  String get hHomeDlgDeleteSuccess;

  /// No description provided for @hHomeDlgDeleteFail.
  ///
  /// In vi, this message translates to:
  /// **'Xoá thất bại'**
  String get hHomeDlgDeleteFail;

  /// No description provided for @hHomeDlgActionCloseUnit.
  ///
  /// In vi, this message translates to:
  /// **'đóng phòng'**
  String get hHomeDlgActionCloseUnit;

  /// No description provided for @hHomeDlgCloseUnitTitle.
  ///
  /// In vi, this message translates to:
  /// **'Đóng 1 phòng'**
  String get hHomeDlgCloseUnitTitle;

  /// No description provided for @hHomeDlgCloseUnitBody.
  ///
  /// In vi, this message translates to:
  /// **'Xác nhận đã cho thuê 1 phòng tại \"{title}\" cho người ngoài app? Số phòng còn trống sẽ giảm 1, các yêu cầu đặt lịch xem đang chờ sẽ tự được báo \"Đã có người chốt\".'**
  String hHomeDlgCloseUnitBody(Object title);

  /// No description provided for @hHomeDlgCloseUnitConfirm.
  ///
  /// In vi, this message translates to:
  /// **'Đóng phòng'**
  String get hHomeDlgCloseUnitConfirm;

  /// No description provided for @hHomeDlgCloseUnitSuccess.
  ///
  /// In vi, this message translates to:
  /// **'Đã đóng 1 phòng'**
  String get hHomeDlgCloseUnitSuccess;

  /// No description provided for @hHomeDlgCloseUnitFail.
  ///
  /// In vi, this message translates to:
  /// **'Thao tác thất bại'**
  String get hHomeDlgCloseUnitFail;

  /// No description provided for @hHomeDlgLockTitle.
  ///
  /// In vi, this message translates to:
  /// **'Chốt phòng'**
  String get hHomeDlgLockTitle;

  /// No description provided for @hHomeDlgLockBody.
  ///
  /// In vi, this message translates to:
  /// **'Xác nhận chốt thuê phòng \"{house}\" với {guest}? Các yêu cầu xem khác cùng phòng sẽ tự đóng và guest được báo.'**
  String hHomeDlgLockBody(Object house, Object guest);

  /// No description provided for @hHomeDlgLockDefaultHouse.
  ///
  /// In vi, this message translates to:
  /// **'này'**
  String get hHomeDlgLockDefaultHouse;

  /// No description provided for @hHomeDlgLockDefaultGuest.
  ///
  /// In vi, this message translates to:
  /// **'khách này'**
  String get hHomeDlgLockDefaultGuest;

  /// No description provided for @hHomeDlgLockConfirm.
  ///
  /// In vi, this message translates to:
  /// **'Chốt'**
  String get hHomeDlgLockConfirm;

  /// No description provided for @hHomeDlgLockSuccess.
  ///
  /// In vi, this message translates to:
  /// **'Đã chốt phòng cho khách'**
  String get hHomeDlgLockSuccess;

  /// No description provided for @hHomeDlgLockFail.
  ///
  /// In vi, this message translates to:
  /// **'Chốt thất bại'**
  String get hHomeDlgLockFail;

  /// No description provided for @hHomeListingsTotalEyebrow.
  ///
  /// In vi, this message translates to:
  /// **'TỔNG TIN ĐĂNG'**
  String get hHomeListingsTotalEyebrow;

  /// No description provided for @hHomeListingsTotalCaption.
  ///
  /// In vi, this message translates to:
  /// **'Tin đã đăng từ trước tới nay'**
  String get hHomeListingsTotalCaption;

  /// No description provided for @hHomeListingsPendingEyebrow.
  ///
  /// In vi, this message translates to:
  /// **'CHỜ DUYỆT'**
  String get hHomeListingsPendingEyebrow;

  /// No description provided for @hHomeListingsPendingCaption.
  ///
  /// In vi, this message translates to:
  /// **'Đang chờ admin'**
  String get hHomeListingsPendingCaption;

  /// No description provided for @hHomeListingsApprovedEyebrow.
  ///
  /// In vi, this message translates to:
  /// **'ĐANG ĐĂNG'**
  String get hHomeListingsApprovedEyebrow;

  /// No description provided for @hHomeListingsApprovedCaption.
  ///
  /// In vi, this message translates to:
  /// **'Hiển thị công khai'**
  String get hHomeListingsApprovedCaption;

  /// No description provided for @hHomeListingsSectionListings.
  ///
  /// In vi, this message translates to:
  /// **'Danh sách tin'**
  String get hHomeListingsSectionListings;

  /// No description provided for @hHomeListingsEmptyListingsLine.
  ///
  /// In vi, this message translates to:
  /// **'Chưa có tin đăng nào.'**
  String get hHomeListingsEmptyListingsLine;

  /// No description provided for @hHomeListingsEmptyListingsHint.
  ///
  /// In vi, this message translates to:
  /// **'Bấm \"Đăng mới\" để tạo tin đầu tiên.'**
  String get hHomeListingsEmptyListingsHint;

  /// No description provided for @hHomeListingsSectionAppointments.
  ///
  /// In vi, this message translates to:
  /// **'Yêu cầu hẹn xem'**
  String get hHomeListingsSectionAppointments;

  /// No description provided for @hHomeListingsEmptyAppointmentsLine.
  ///
  /// In vi, this message translates to:
  /// **'Không có yêu cầu xem nhà đang chờ.'**
  String get hHomeListingsEmptyAppointmentsLine;

  /// No description provided for @hHomeListingsEmptyAppointmentsHint.
  ///
  /// In vi, this message translates to:
  /// **'Khi có khách hẹn, sẽ hiện tại đây.'**
  String get hHomeListingsEmptyAppointmentsHint;

  /// No description provided for @hHomeListingsPostNew.
  ///
  /// In vi, this message translates to:
  /// **'ĐĂNG TIN MỚI'**
  String get hHomeListingsPostNew;

  /// No description provided for @hHomeRoomsKpiCollected.
  ///
  /// In vi, this message translates to:
  /// **'ĐÃ THU'**
  String get hHomeRoomsKpiCollected;

  /// No description provided for @hHomeRoomsKpiUnpaid.
  ///
  /// In vi, this message translates to:
  /// **'CÒN NỢ'**
  String get hHomeRoomsKpiUnpaid;

  /// No description provided for @hHomeRoomsKpiOccupancy.
  ///
  /// In vi, this message translates to:
  /// **'LẤP ĐẦY'**
  String get hHomeRoomsKpiOccupancy;

  /// No description provided for @hHomeRoomsQuickCreateInvoice.
  ///
  /// In vi, this message translates to:
  /// **'Tạo hoá đơn'**
  String get hHomeRoomsQuickCreateInvoice;

  /// No description provided for @hHomeRoomsQuickMeter.
  ///
  /// In vi, this message translates to:
  /// **'Ghi điện nước'**
  String get hHomeRoomsQuickMeter;

  /// No description provided for @hHomeRoomsQuickReminder.
  ///
  /// In vi, this message translates to:
  /// **'Nhắc nợ'**
  String get hHomeRoomsQuickReminder;

  /// No description provided for @hHomeRoomsQuickReports.
  ///
  /// In vi, this message translates to:
  /// **'Báo cáo'**
  String get hHomeRoomsQuickReports;

  /// No description provided for @hHomeRoomsTodoHeader.
  ///
  /// In vi, this message translates to:
  /// **'VIỆC CẦN LÀM HÔM NAY'**
  String get hHomeRoomsTodoHeader;

  /// No description provided for @hHomeRoomsSectionBilling.
  ///
  /// In vi, this message translates to:
  /// **'THU CHI'**
  String get hHomeRoomsSectionBilling;

  /// No description provided for @hHomeRoomsInvoicesTitle.
  ///
  /// In vi, this message translates to:
  /// **'Hoá đơn'**
  String get hHomeRoomsInvoicesTitle;

  /// No description provided for @hHomeRoomsInvoicesSubtitle.
  ///
  /// In vi, this message translates to:
  /// **'Danh sách & phát hành hoá đơn'**
  String get hHomeRoomsInvoicesSubtitle;

  /// No description provided for @hHomeRoomsDebtTitle.
  ///
  /// In vi, this message translates to:
  /// **'Công nợ'**
  String get hHomeRoomsDebtTitle;

  /// No description provided for @hHomeRoomsDebtSubtitle.
  ///
  /// In vi, this message translates to:
  /// **'Theo dõi nợ theo phòng'**
  String get hHomeRoomsDebtSubtitle;

  /// No description provided for @hHomeRoomsServiceFeesTitle.
  ///
  /// In vi, this message translates to:
  /// **'Phí dịch vụ'**
  String get hHomeRoomsServiceFeesTitle;

  /// No description provided for @hHomeRoomsServiceFeesSubtitle.
  ///
  /// In vi, this message translates to:
  /// **'Cấu hình phí điện/nước/dịch vụ'**
  String get hHomeRoomsServiceFeesSubtitle;

  /// No description provided for @hHomeRoomsSectionOps.
  ///
  /// In vi, this message translates to:
  /// **'VẬN HÀNH KHÁC'**
  String get hHomeRoomsSectionOps;

  /// No description provided for @hHomeRoomsLeadsTitle.
  ///
  /// In vi, this message translates to:
  /// **'Khách quan tâm'**
  String get hHomeRoomsLeadsTitle;

  /// No description provided for @hHomeRoomsLeadsSubtitle.
  ///
  /// In vi, this message translates to:
  /// **'Đặt lịch xem & lưu tin'**
  String get hHomeRoomsLeadsSubtitle;

  /// No description provided for @hHomeRoomsKhaiBaoTitle.
  ///
  /// In vi, this message translates to:
  /// **'Khai báo tạm trú'**
  String get hHomeRoomsKhaiBaoTitle;

  /// No description provided for @hHomeRoomsHomestayTitle.
  ///
  /// In vi, this message translates to:
  /// **'Homestay'**
  String get hHomeRoomsHomestayTitle;

  /// No description provided for @hHomeRoomsSyncTitle.
  ///
  /// In vi, this message translates to:
  /// **'Đồng bộ sang chợ khác'**
  String get hHomeRoomsSyncTitle;

  /// No description provided for @hHomeRoomsAnalyticsTitle.
  ///
  /// In vi, this message translates to:
  /// **'THỐNG KÊ DOANH THU'**
  String get hHomeRoomsAnalyticsTitle;

  /// No description provided for @hHomeRoomsAnalyticsSubtitle.
  ///
  /// In vi, this message translates to:
  /// **'5 KPI • Doanh thu, lấp đầy, ADR'**
  String get hHomeRoomsAnalyticsSubtitle;

  /// No description provided for @hIntroAppBarTitle.
  ///
  /// In vi, this message translates to:
  /// **'TRỞ THÀNH CHỦ NHÀ'**
  String get hIntroAppBarTitle;

  /// No description provided for @hIntroEyebrow.
  ///
  /// In vi, this message translates to:
  /// **'ANCU365  ·  BẢN HOST'**
  String get hIntroEyebrow;

  /// No description provided for @hIntroHeadline.
  ///
  /// In vi, this message translates to:
  /// **'Mở phòng,\nđón khách,\nthu tiền.'**
  String get hIntroHeadline;

  /// No description provided for @hIntroSubtitle.
  ///
  /// In vi, this message translates to:
  /// **'Cùng An Cư 365 vận hành nhà trọ và homestay của bạn ngay trên điện thoại — từ đăng tin, duyệt khách, ký hợp đồng đến chốt hoá đơn.'**
  String get hIntroSubtitle;

  /// No description provided for @hIntroBenefitsLabel.
  ///
  /// In vi, this message translates to:
  /// **'BẠN ĐƯỢC GÌ'**
  String get hIntroBenefitsLabel;

  /// No description provided for @hIntroBenefit1Title.
  ///
  /// In vi, this message translates to:
  /// **'Quản lý toà nhà & phòng'**
  String get hIntroBenefit1Title;

  /// No description provided for @hIntroBenefit1Body.
  ///
  /// In vi, this message translates to:
  /// **'Theo dõi trạng thái phòng, hợp đồng, công tơ trong một sổ tay điện tử.'**
  String get hIntroBenefit1Body;

  /// No description provided for @hIntroBenefit2Title.
  ///
  /// In vi, this message translates to:
  /// **'Nhận yêu cầu xem trực tiếp'**
  String get hIntroBenefit2Title;

  /// No description provided for @hIntroBenefit2Body.
  ///
  /// In vi, this message translates to:
  /// **'Khách hẹn lịch — bạn duyệt hoặc từ chối ngay trong app, không phải tin nhắn rời.'**
  String get hIntroBenefit2Body;

  /// No description provided for @hIntroBenefit3Title.
  ///
  /// In vi, this message translates to:
  /// **'Xuất hoá đơn & chốt thuê'**
  String get hIntroBenefit3Title;

  /// No description provided for @hIntroBenefit3Body.
  ///
  /// In vi, this message translates to:
  /// **'Tự động tính tiền điện nước theo công tơ; ký hợp đồng + lưu trữ tập trung.'**
  String get hIntroBenefit3Body;

  /// No description provided for @hIntroBenefit4Title.
  ///
  /// In vi, this message translates to:
  /// **'Hiển thị đa kênh'**
  String get hIntroBenefit4Title;

  /// No description provided for @hIntroBenefit4Body.
  ///
  /// In vi, this message translates to:
  /// **'Tin đăng xuất hiện trên Khám phá + bản đồ tin đăng, tiếp cận hàng nghìn khách.'**
  String get hIntroBenefit4Body;

  /// No description provided for @hIntroCta.
  ///
  /// In vi, this message translates to:
  /// **'BẮT ĐẦU ĐĂNG KÝ'**
  String get hIntroCta;

  /// No description provided for @hIntroCtaNote.
  ///
  /// In vi, this message translates to:
  /// **'Mất 2–3 phút. Cần CCCD + thông tin tài khoản nhận tiền.'**
  String get hIntroCtaNote;

  /// No description provided for @hInvBatchTitle.
  ///
  /// In vi, this message translates to:
  /// **'TẠO HOÁ ĐƠN HÀNG LOẠT'**
  String get hInvBatchTitle;

  /// No description provided for @hInvBatchBuildingLabel.
  ///
  /// In vi, this message translates to:
  /// **'Toà nhà *'**
  String get hInvBatchBuildingLabel;

  /// No description provided for @hInvBatchSelectBuilding.
  ///
  /// In vi, this message translates to:
  /// **'Chọn toà nhà'**
  String get hInvBatchSelectBuilding;

  /// No description provided for @hInvBatchMonthLabel.
  ///
  /// In vi, this message translates to:
  /// **'Tháng (YYYY-MM) *'**
  String get hInvBatchMonthLabel;

  /// No description provided for @hInvBatchSelectMonth.
  ///
  /// In vi, this message translates to:
  /// **'Chọn tháng'**
  String get hInvBatchSelectMonth;

  /// No description provided for @hInvBatchElecPriceLabel.
  ///
  /// In vi, this message translates to:
  /// **'Đơn giá điện (VND/kWh)'**
  String get hInvBatchElecPriceLabel;

  /// No description provided for @hInvBatchWaterPriceLabel.
  ///
  /// In vi, this message translates to:
  /// **'Đơn giá nước (VND/m³)'**
  String get hInvBatchWaterPriceLabel;

  /// No description provided for @hInvBatchGenerateButton.
  ///
  /// In vi, this message translates to:
  /// **'Tạo hoá đơn'**
  String get hInvBatchGenerateButton;

  /// No description provided for @hInvBatchHelpText.
  ///
  /// In vi, this message translates to:
  /// **'Hệ thống tạo hoá đơn (trạng thái nháp) cho từng hợp đồng đang hoạt động trong toà nhà. Nếu đã có hoá đơn cho kỳ này, hệ thống bỏ qua (idempotent).'**
  String get hInvBatchHelpText;

  /// No description provided for @hInvBatchSelectRequired.
  ///
  /// In vi, this message translates to:
  /// **'Vui lòng chọn toà nhà và tháng'**
  String get hInvBatchSelectRequired;

  /// No description provided for @hInvBatchCreateFailed.
  ///
  /// In vi, this message translates to:
  /// **'Tạo thất bại'**
  String get hInvBatchCreateFailed;

  /// No description provided for @hInvDetSentSuccess.
  ///
  /// In vi, this message translates to:
  /// **'Đã gửi hoá đơn — link công khai sẵn sàng'**
  String get hInvDetSentSuccess;

  /// No description provided for @hInvDetCannotOpen.
  ///
  /// In vi, this message translates to:
  /// **'Không mở được: {url}'**
  String hInvDetCannotOpen(Object url);

  /// No description provided for @hInvDetTitle.
  ///
  /// In vi, this message translates to:
  /// **'CHI TIẾT HOÁ ĐƠN'**
  String get hInvDetTitle;

  /// No description provided for @hInvDetPeriod.
  ///
  /// In vi, this message translates to:
  /// **'Kỳ {start} → {end}'**
  String hInvDetPeriod(Object start, Object end);

  /// No description provided for @hInvDetDue.
  ///
  /// In vi, this message translates to:
  /// **'Hạn {date}'**
  String hInvDetDue(Object date);

  /// No description provided for @hInvDetDetails.
  ///
  /// In vi, this message translates to:
  /// **'CHI TIẾT'**
  String get hInvDetDetails;

  /// No description provided for @hInvDetTotal.
  ///
  /// In vi, this message translates to:
  /// **'Tổng'**
  String get hInvDetTotal;

  /// No description provided for @hInvDetCollected.
  ///
  /// In vi, this message translates to:
  /// **'Đã thu'**
  String get hInvDetCollected;

  /// No description provided for @hInvDetRemaining.
  ///
  /// In vi, this message translates to:
  /// **'Còn lại'**
  String get hInvDetRemaining;

  /// No description provided for @hInvDetSendInvoice.
  ///
  /// In vi, this message translates to:
  /// **'Gửi hoá đơn'**
  String get hInvDetSendInvoice;

  /// No description provided for @hInvDetRecordPayment.
  ///
  /// In vi, this message translates to:
  /// **'Ghi nhận thanh toán'**
  String get hInvDetRecordPayment;

  /// No description provided for @hInvDetOpenPublicLink.
  ///
  /// In vi, this message translates to:
  /// **'Mở link công khai'**
  String get hInvDetOpenPublicLink;

  /// No description provided for @hInvDetRemindZalo.
  ///
  /// In vi, this message translates to:
  /// **'Nhắc qua Zalo'**
  String get hInvDetRemindZalo;

  /// No description provided for @hInvDetCreditNote.
  ///
  /// In vi, this message translates to:
  /// **'Lập credit note (điều chỉnh)'**
  String get hInvDetCreditNote;

  /// No description provided for @hKhaibaoTitle.
  ///
  /// In vi, this message translates to:
  /// **'CHI TIẾT KHAI BÁO'**
  String get hKhaibaoTitle;

  /// No description provided for @hKhaibaoShareSubject.
  ///
  /// In vi, this message translates to:
  /// **'Phiếu khai báo tạm trú'**
  String get hKhaibaoShareSubject;

  /// No description provided for @hKhaibaoDeclaredRecorded.
  ///
  /// In vi, this message translates to:
  /// **'Đã ghi nhận khai báo'**
  String get hKhaibaoDeclaredRecorded;

  /// No description provided for @hKhaibaoSaveFailed.
  ///
  /// In vi, this message translates to:
  /// **'Lưu thất bại'**
  String get hKhaibaoSaveFailed;

  /// No description provided for @hKhaibaoSkipped.
  ///
  /// In vi, this message translates to:
  /// **'Đã bỏ qua'**
  String get hKhaibaoSkipped;

  /// No description provided for @hKhaibaoPhone.
  ///
  /// In vi, this message translates to:
  /// **'Số điện thoại'**
  String get hKhaibaoPhone;

  /// No description provided for @hKhaibaoRoom.
  ///
  /// In vi, this message translates to:
  /// **'Phòng'**
  String get hKhaibaoRoom;

  /// No description provided for @hKhaibaoBuilding.
  ///
  /// In vi, this message translates to:
  /// **'Toà nhà'**
  String get hKhaibaoBuilding;

  /// No description provided for @hKhaibaoCheckInDate.
  ///
  /// In vi, this message translates to:
  /// **'Ngày check-in'**
  String get hKhaibaoCheckInDate;

  /// No description provided for @hKhaibaoLinkExpires.
  ///
  /// In vi, this message translates to:
  /// **'Liên kết hết hạn'**
  String get hKhaibaoLinkExpires;

  /// No description provided for @hKhaibaoDeclaredAt.
  ///
  /// In vi, this message translates to:
  /// **'Đã khai lúc'**
  String get hKhaibaoDeclaredAt;

  /// No description provided for @hKhaibaoSkipReason.
  ///
  /// In vi, this message translates to:
  /// **'Lý do bỏ qua'**
  String get hKhaibaoSkipReason;

  /// No description provided for @hKhaibaoViewForm.
  ///
  /// In vi, this message translates to:
  /// **'Xem phiếu khai báo (TK1)'**
  String get hKhaibaoViewForm;

  /// No description provided for @hKhaibaoMarkDeclared.
  ///
  /// In vi, this message translates to:
  /// **'Đã khai báo'**
  String get hKhaibaoMarkDeclared;

  /// No description provided for @hKhaibaoSkipEarlyLeave.
  ///
  /// In vi, this message translates to:
  /// **'Bỏ qua (khách rời sớm)'**
  String get hKhaibaoSkipEarlyLeave;

  /// No description provided for @hKhaibaoSkipHint.
  ///
  /// In vi, this message translates to:
  /// **'Ví dụ: Khách rời sớm'**
  String get hKhaibaoSkipHint;

  /// No description provided for @hKhaibaoSkip.
  ///
  /// In vi, this message translates to:
  /// **'Bỏ qua'**
  String get hKhaibaoSkip;

  /// No description provided for @hLeadsTitle.
  ///
  /// In vi, this message translates to:
  /// **'Khách quan tâm'**
  String get hLeadsTitle;

  /// No description provided for @hLeadsTabTarget.
  ///
  /// In vi, this message translates to:
  /// **'Mục tiêu ({count})'**
  String hLeadsTabTarget(Object count);

  /// No description provided for @hLeadsTabPotential.
  ///
  /// In vi, this message translates to:
  /// **'Tiềm năng ({count})'**
  String hLeadsTabPotential(Object count);

  /// No description provided for @hLeadsLoadError.
  ///
  /// In vi, this message translates to:
  /// **'Không tải được: {error}'**
  String hLeadsLoadError(Object error);

  /// No description provided for @hLeadsEmptyTarget.
  ///
  /// In vi, this message translates to:
  /// **'Chưa có khách đặt lịch xem tin của bạn.'**
  String get hLeadsEmptyTarget;

  /// No description provided for @hLeadsEmptyPotential.
  ///
  /// In vi, this message translates to:
  /// **'Chưa có khách lưu tin của bạn vào wishlist.'**
  String get hLeadsEmptyPotential;

  /// No description provided for @hLeadsBadgeBooked.
  ///
  /// In vi, this message translates to:
  /// **'Đã đặt lịch'**
  String get hLeadsBadgeBooked;

  /// No description provided for @hLeadsBadgeBookViewing.
  ///
  /// In vi, this message translates to:
  /// **'Đặt lịch xem'**
  String get hLeadsBadgeBookViewing;

  /// No description provided for @hLeadsBadgeSaved.
  ///
  /// In vi, this message translates to:
  /// **'Lưu tin'**
  String get hLeadsBadgeSaved;

  /// No description provided for @hLeadsDefaultName.
  ///
  /// In vi, this message translates to:
  /// **'Khách'**
  String get hLeadsDefaultName;

  /// No description provided for @hLeadsDefaultHouse.
  ///
  /// In vi, this message translates to:
  /// **'BĐS'**
  String get hLeadsDefaultHouse;

  /// No description provided for @hListingsTitle.
  ///
  /// In vi, this message translates to:
  /// **'Tin đã đăng'**
  String get hListingsTitle;

  /// No description provided for @hListingsRefresh.
  ///
  /// In vi, this message translates to:
  /// **'Làm mới'**
  String get hListingsRefresh;

  /// No description provided for @hListingsPostRoom.
  ///
  /// In vi, this message translates to:
  /// **'Đăng phòng'**
  String get hListingsPostRoom;

  /// No description provided for @hListingsEmptyTitle.
  ///
  /// In vi, this message translates to:
  /// **'Bạn chưa đăng tin nào'**
  String get hListingsEmptyTitle;

  /// No description provided for @hListingsEmptyHint.
  ///
  /// In vi, this message translates to:
  /// **'Nhấn nút \"Đăng phòng\" để tạo tin đầu tiên.'**
  String get hListingsEmptyHint;

  /// No description provided for @hListingsEdit.
  ///
  /// In vi, this message translates to:
  /// **'Sửa tin'**
  String get hListingsEdit;

  /// No description provided for @hListingsDelete.
  ///
  /// In vi, this message translates to:
  /// **'Xóa tin'**
  String get hListingsDelete;

  /// No description provided for @hListingsDeleteTitle.
  ///
  /// In vi, this message translates to:
  /// **'Xoá tin đăng'**
  String get hListingsDeleteTitle;

  /// No description provided for @hListingsDeleteConfirm.
  ///
  /// In vi, this message translates to:
  /// **'Bạn có chắc muốn xoá \"{title}\"?'**
  String hListingsDeleteConfirm(Object title);

  /// No description provided for @hListingsDeleteAction.
  ///
  /// In vi, this message translates to:
  /// **'Xoá'**
  String get hListingsDeleteAction;

  /// No description provided for @hListingsDeleteSuccess.
  ///
  /// In vi, this message translates to:
  /// **'Đã xoá tin'**
  String get hListingsDeleteSuccess;

  /// No description provided for @hListingsDeleteFailed.
  ///
  /// In vi, this message translates to:
  /// **'Xoá thất bại'**
  String get hListingsDeleteFailed;

  /// No description provided for @hListingsStatusApproved.
  ///
  /// In vi, this message translates to:
  /// **'Đang đăng'**
  String get hListingsStatusApproved;

  /// No description provided for @hListingsStatusPending.
  ///
  /// In vi, this message translates to:
  /// **'Chờ duyệt'**
  String get hListingsStatusPending;

  /// No description provided for @hListingsStatusRejected.
  ///
  /// In vi, this message translates to:
  /// **'Từ chối'**
  String get hListingsStatusRejected;

  /// No description provided for @hListingsStatusHidden.
  ///
  /// In vi, this message translates to:
  /// **'Đã ẩn'**
  String get hListingsStatusHidden;

  /// No description provided for @hProfileSavedInfo.
  ///
  /// In vi, this message translates to:
  /// **'Đã lưu thông tin'**
  String get hProfileSavedInfo;

  /// No description provided for @hProfileSaveFailed.
  ///
  /// In vi, this message translates to:
  /// **'Lưu thất bại'**
  String get hProfileSaveFailed;

  /// No description provided for @hProfileEyebrow.
  ///
  /// In vi, this message translates to:
  /// **'Tài khoản'**
  String get hProfileEyebrow;

  /// No description provided for @hProfileTitle.
  ///
  /// In vi, this message translates to:
  /// **'Hồ sơ chủ nhà'**
  String get hProfileTitle;

  /// No description provided for @hProfileEdit.
  ///
  /// In vi, this message translates to:
  /// **'Chỉnh sửa'**
  String get hProfileEdit;

  /// No description provided for @hProfileEmptyTitle.
  ///
  /// In vi, this message translates to:
  /// **'Chưa có hồ sơ'**
  String get hProfileEmptyTitle;

  /// No description provided for @hProfileEmptySubtitle.
  ///
  /// In vi, this message translates to:
  /// **'Hãy hoàn tất onboarding để tạo hồ sơ chủ nhà.'**
  String get hProfileEmptySubtitle;

  /// No description provided for @hProfileSaveChanges.
  ///
  /// In vi, this message translates to:
  /// **'Lưu thay đổi'**
  String get hProfileSaveChanges;

  /// No description provided for @hProfileVerified.
  ///
  /// In vi, this message translates to:
  /// **'Tài khoản đã xác minh'**
  String get hProfileVerified;

  /// No description provided for @hProfilePending.
  ///
  /// In vi, this message translates to:
  /// **'Đang chờ xác minh'**
  String get hProfilePending;

  /// No description provided for @hProfileVerifiedDesc.
  ///
  /// In vi, this message translates to:
  /// **'Bạn có thể đăng phòng và nhận thanh toán.'**
  String get hProfileVerifiedDesc;

  /// No description provided for @hProfilePendingDesc.
  ///
  /// In vi, this message translates to:
  /// **'Tải lên CCCD để hoàn tất xác minh.'**
  String get hProfilePendingDesc;

  /// No description provided for @hProfileIdentitySection.
  ///
  /// In vi, this message translates to:
  /// **'Xác minh danh tính'**
  String get hProfileIdentitySection;

  /// No description provided for @hProfileCccdFront.
  ///
  /// In vi, this message translates to:
  /// **'CCCD mặt trước'**
  String get hProfileCccdFront;

  /// No description provided for @hProfileCccdBack.
  ///
  /// In vi, this message translates to:
  /// **'CCCD mặt sau'**
  String get hProfileCccdBack;

  /// No description provided for @hProfileUploaded.
  ///
  /// In vi, this message translates to:
  /// **'Đã tải'**
  String get hProfileUploaded;

  /// No description provided for @hProfileNotUploaded.
  ///
  /// In vi, this message translates to:
  /// **'Chưa tải'**
  String get hProfileNotUploaded;

  /// No description provided for @hProfilePaymentSection.
  ///
  /// In vi, this message translates to:
  /// **'Thông tin thanh toán'**
  String get hProfilePaymentSection;

  /// No description provided for @hProfileBank.
  ///
  /// In vi, this message translates to:
  /// **'Ngân hàng'**
  String get hProfileBank;

  /// No description provided for @hProfileBankHint.
  ///
  /// In vi, this message translates to:
  /// **'VD: Vietcombank'**
  String get hProfileBankHint;

  /// No description provided for @hProfileAccountNumber.
  ///
  /// In vi, this message translates to:
  /// **'Số tài khoản'**
  String get hProfileAccountNumber;

  /// No description provided for @hProfileAccountHolder.
  ///
  /// In vi, this message translates to:
  /// **'Chủ tài khoản'**
  String get hProfileAccountHolder;

  /// No description provided for @hProfileAccountHolderHint.
  ///
  /// In vi, this message translates to:
  /// **'Họ tên trên thẻ'**
  String get hProfileAccountHolderHint;

  /// No description provided for @hProfileTaxId.
  ///
  /// In vi, this message translates to:
  /// **'Mã số thuế'**
  String get hProfileTaxId;

  /// No description provided for @hProfilePerformanceSection.
  ///
  /// In vi, this message translates to:
  /// **'Hiệu suất'**
  String get hProfilePerformanceSection;

  /// No description provided for @hProfileRating.
  ///
  /// In vi, this message translates to:
  /// **'Đánh giá'**
  String get hProfileRating;

  /// No description provided for @hProfileAvgResponse.
  ///
  /// In vi, this message translates to:
  /// **'Phản hồi TB'**
  String get hProfileAvgResponse;

  /// No description provided for @hProfileHours.
  ///
  /// In vi, this message translates to:
  /// **'giờ'**
  String get hProfileHours;

  /// No description provided for @hResvDetTitle.
  ///
  /// In vi, this message translates to:
  /// **'Chi tiết đặt phòng'**
  String get hResvDetTitle;

  /// No description provided for @hResvDetNotFound.
  ///
  /// In vi, this message translates to:
  /// **'Không tìm thấy đơn'**
  String get hResvDetNotFound;

  /// No description provided for @hResvDetError.
  ///
  /// In vi, this message translates to:
  /// **'Lỗi'**
  String get hResvDetError;

  /// No description provided for @hResvDetReasonHint.
  ///
  /// In vi, this message translates to:
  /// **'Lý do…'**
  String get hResvDetReasonHint;

  /// No description provided for @hResvDetConfirm.
  ///
  /// In vi, this message translates to:
  /// **'Xác nhận'**
  String get hResvDetConfirm;

  /// No description provided for @hResvDetCheckIn.
  ///
  /// In vi, this message translates to:
  /// **'Check-in'**
  String get hResvDetCheckIn;

  /// No description provided for @hResvDetCheckOut.
  ///
  /// In vi, this message translates to:
  /// **'Check-out'**
  String get hResvDetCheckOut;

  /// No description provided for @hResvDetNights.
  ///
  /// In vi, this message translates to:
  /// **'Số đêm'**
  String get hResvDetNights;

  /// No description provided for @hResvDetPhone.
  ///
  /// In vi, this message translates to:
  /// **'SĐT'**
  String get hResvDetPhone;

  /// No description provided for @hResvDetEmail.
  ///
  /// In vi, this message translates to:
  /// **'Email'**
  String get hResvDetEmail;

  /// No description provided for @hResvDetTotal.
  ///
  /// In vi, this message translates to:
  /// **'Tổng tiền'**
  String get hResvDetTotal;

  /// No description provided for @hResvDetRefund.
  ///
  /// In vi, this message translates to:
  /// **'Hoàn trả'**
  String get hResvDetRefund;

  /// No description provided for @hResvDetCancelledAt.
  ///
  /// In vi, this message translates to:
  /// **'Hủy lúc'**
  String get hResvDetCancelledAt;

  /// No description provided for @hResvDetReason.
  ///
  /// In vi, this message translates to:
  /// **'Lý do'**
  String get hResvDetReason;

  /// No description provided for @hResvDetApprove.
  ///
  /// In vi, this message translates to:
  /// **'Duyệt đơn'**
  String get hResvDetApprove;

  /// No description provided for @hResvDetApproved.
  ///
  /// In vi, this message translates to:
  /// **'Đã duyệt'**
  String get hResvDetApproved;

  /// No description provided for @hResvDetReject.
  ///
  /// In vi, this message translates to:
  /// **'Từ chối'**
  String get hResvDetReject;

  /// No description provided for @hResvDetRejectReason.
  ///
  /// In vi, this message translates to:
  /// **'Lý do từ chối'**
  String get hResvDetRejectReason;

  /// No description provided for @hResvDetRejected.
  ///
  /// In vi, this message translates to:
  /// **'Đã từ chối'**
  String get hResvDetRejected;

  /// No description provided for @hResvDetCheckedIn.
  ///
  /// In vi, this message translates to:
  /// **'Đã check-in'**
  String get hResvDetCheckedIn;

  /// No description provided for @hResvDetCheckedOut.
  ///
  /// In vi, this message translates to:
  /// **'Đã check-out'**
  String get hResvDetCheckedOut;

  /// No description provided for @hResvDetCancel.
  ///
  /// In vi, this message translates to:
  /// **'Hủy đơn'**
  String get hResvDetCancel;

  /// No description provided for @hResvDetCancelReason.
  ///
  /// In vi, this message translates to:
  /// **'Lý do hủy'**
  String get hResvDetCancelReason;

  /// No description provided for @hResvDetCancelled.
  ///
  /// In vi, this message translates to:
  /// **'Đã hủy đơn'**
  String get hResvDetCancelled;

  /// No description provided for @hResvListTitle.
  ///
  /// In vi, this message translates to:
  /// **'Đặt phòng'**
  String get hResvListTitle;

  /// No description provided for @hResvListFilterAll.
  ///
  /// In vi, this message translates to:
  /// **'Tất cả'**
  String get hResvListFilterAll;

  /// No description provided for @hResvListFilterPending.
  ///
  /// In vi, this message translates to:
  /// **'Chờ duyệt'**
  String get hResvListFilterPending;

  /// No description provided for @hResvListFilterApproved.
  ///
  /// In vi, this message translates to:
  /// **'Đã duyệt'**
  String get hResvListFilterApproved;

  /// No description provided for @hResvListFilterCheckedIn.
  ///
  /// In vi, this message translates to:
  /// **'Đang ở'**
  String get hResvListFilterCheckedIn;

  /// No description provided for @hResvListFilterCheckedOut.
  ///
  /// In vi, this message translates to:
  /// **'Đã trả'**
  String get hResvListFilterCheckedOut;

  /// No description provided for @hResvListFilterCancelled.
  ///
  /// In vi, this message translates to:
  /// **'Đã hủy'**
  String get hResvListFilterCancelled;

  /// No description provided for @hResvListEmptyTitle.
  ///
  /// In vi, this message translates to:
  /// **'Không có đơn nào'**
  String get hResvListEmptyTitle;

  /// No description provided for @hResvListEmptySubtitle.
  ///
  /// In vi, this message translates to:
  /// **'Chưa có đặt phòng theo bộ lọc này.'**
  String get hResvListEmptySubtitle;

  /// No description provided for @hResvListNights.
  ///
  /// In vi, this message translates to:
  /// **'{count} đêm'**
  String hResvListNights(Object count);

  /// No description provided for @hRoomDetMaintEyebrow.
  ///
  /// In vi, this message translates to:
  /// **'TỜ KHAI BẢO TRÌ'**
  String get hRoomDetMaintEyebrow;

  /// No description provided for @hRoomDetMaintTitle.
  ///
  /// In vi, this message translates to:
  /// **'Đặt phòng vào bảo trì'**
  String get hRoomDetMaintTitle;

  /// No description provided for @hRoomDetConfirm.
  ///
  /// In vi, this message translates to:
  /// **'XÁC NHẬN'**
  String get hRoomDetConfirm;

  /// No description provided for @hRoomDetMaintSetFrom.
  ///
  /// In vi, this message translates to:
  /// **'Đã đặt bảo trì từ {start}'**
  String hRoomDetMaintSetFrom(Object start);

  /// No description provided for @hRoomDetFailed.
  ///
  /// In vi, this message translates to:
  /// **'Thất bại'**
  String get hRoomDetFailed;

  /// No description provided for @hRoomDetEndMaintEyebrow.
  ///
  /// In vi, this message translates to:
  /// **'KẾT THÚC BẢO TRÌ'**
  String get hRoomDetEndMaintEyebrow;

  /// No description provided for @hRoomDetEndMaintTitle.
  ///
  /// In vi, this message translates to:
  /// **'Xác nhận kết thúc?'**
  String get hRoomDetEndMaintTitle;

  /// No description provided for @hRoomDetEndMaintBody.
  ///
  /// In vi, this message translates to:
  /// **'Phòng sẽ chuyển về trạng thái trống.'**
  String get hRoomDetEndMaintBody;

  /// No description provided for @hRoomDetEnd.
  ///
  /// In vi, this message translates to:
  /// **'KẾT THÚC'**
  String get hRoomDetEnd;

  /// No description provided for @hRoomDetMaintEnded.
  ///
  /// In vi, this message translates to:
  /// **'Đã kết thúc bảo trì'**
  String get hRoomDetMaintEnded;

  /// No description provided for @hRoomDetDuplicated.
  ///
  /// In vi, this message translates to:
  /// **'Đã tạo bản sao {code}'**
  String hRoomDetDuplicated(Object code);

  /// No description provided for @hRoomDetHeader.
  ///
  /// In vi, this message translates to:
  /// **'HỒ SƠ PHÒNG'**
  String get hRoomDetHeader;

  /// No description provided for @hRoomDetNotFound.
  ///
  /// In vi, this message translates to:
  /// **'Không tìm thấy phòng'**
  String get hRoomDetNotFound;

  /// No description provided for @hRoomDetDuplicate.
  ///
  /// In vi, this message translates to:
  /// **'Nhân bản phòng'**
  String get hRoomDetDuplicate;

  /// No description provided for @hRoomDetSetMaint.
  ///
  /// In vi, this message translates to:
  /// **'Đặt bảo trì'**
  String get hRoomDetSetMaint;

  /// No description provided for @hRoomDetEndMaint.
  ///
  /// In vi, this message translates to:
  /// **'Kết thúc bảo trì'**
  String get hRoomDetEndMaint;

  /// No description provided for @hStep1Eyebrow.
  ///
  /// In vi, this message translates to:
  /// **'Bước 1 / 3'**
  String get hStep1Eyebrow;

  /// No description provided for @hStep1Title.
  ///
  /// In vi, this message translates to:
  /// **'Đăng ký làm chủ nhà'**
  String get hStep1Title;

  /// No description provided for @hStep1SectionTitle.
  ///
  /// In vi, this message translates to:
  /// **'Thông tin cá nhân'**
  String get hStep1SectionTitle;

  /// No description provided for @hStep1Subtitle.
  ///
  /// In vi, this message translates to:
  /// **'Vui lòng điền đầy đủ thông tin để xác thực tài khoản chủ nhà.'**
  String get hStep1Subtitle;

  /// No description provided for @hStep1NameLabel.
  ///
  /// In vi, this message translates to:
  /// **'Họ và tên'**
  String get hStep1NameLabel;

  /// No description provided for @hStep1NameHint.
  ///
  /// In vi, this message translates to:
  /// **'Nguyễn Văn A'**
  String get hStep1NameHint;

  /// No description provided for @hStep1NameError.
  ///
  /// In vi, this message translates to:
  /// **'Vui lòng nhập họ tên'**
  String get hStep1NameError;

  /// No description provided for @hStep1PhoneLabel.
  ///
  /// In vi, this message translates to:
  /// **'Số điện thoại'**
  String get hStep1PhoneLabel;

  /// No description provided for @hStep1PhoneError.
  ///
  /// In vi, this message translates to:
  /// **'Số điện thoại không hợp lệ'**
  String get hStep1PhoneError;

  /// No description provided for @hStep1DobLabel.
  ///
  /// In vi, this message translates to:
  /// **'Ngày sinh'**
  String get hStep1DobLabel;

  /// No description provided for @hStep1AddressLabel.
  ///
  /// In vi, this message translates to:
  /// **'Địa chỉ thường trú'**
  String get hStep1AddressLabel;

  /// No description provided for @hStep1AddressHint.
  ///
  /// In vi, this message translates to:
  /// **'Số nhà, đường, phường/xã, quận/huyện, tỉnh/TP'**
  String get hStep1AddressHint;

  /// No description provided for @hStep1AddressError.
  ///
  /// In vi, this message translates to:
  /// **'Vui lòng nhập địa chỉ'**
  String get hStep1AddressError;

  /// No description provided for @hStep1Next.
  ///
  /// In vi, this message translates to:
  /// **'Tiếp theo'**
  String get hStep1Next;

  /// No description provided for @hStep1InitError.
  ///
  /// In vi, this message translates to:
  /// **'Khởi tạo hồ sơ thất bại'**
  String get hStep1InitError;

  /// No description provided for @hStep2WarnAtLeastOne.
  ///
  /// In vi, this message translates to:
  /// **'Vui lòng tải lên ít nhất 1 mặt CCCD'**
  String get hStep2WarnAtLeastOne;

  /// No description provided for @hStep2UploadFailed.
  ///
  /// In vi, this message translates to:
  /// **'Tải lên thất bại'**
  String get hStep2UploadFailed;

  /// No description provided for @hStep2Eyebrow.
  ///
  /// In vi, this message translates to:
  /// **'Bước 2 / 3'**
  String get hStep2Eyebrow;

  /// No description provided for @hStep2Title.
  ///
  /// In vi, this message translates to:
  /// **'Xác minh CCCD'**
  String get hStep2Title;

  /// No description provided for @hStep2Heading.
  ///
  /// In vi, this message translates to:
  /// **'Tải CCCD'**
  String get hStep2Heading;

  /// No description provided for @hStep2Subtitle.
  ///
  /// In vi, this message translates to:
  /// **'Tải lên ảnh CCCD/CMND mặt trước và mặt sau để xác thực danh tính.'**
  String get hStep2Subtitle;

  /// No description provided for @hStep2FrontLabel.
  ///
  /// In vi, this message translates to:
  /// **'Mặt trước CCCD'**
  String get hStep2FrontLabel;

  /// No description provided for @hStep2BackLabel.
  ///
  /// In vi, this message translates to:
  /// **'Mặt sau CCCD'**
  String get hStep2BackLabel;

  /// No description provided for @hStep2SecurityNote.
  ///
  /// In vi, this message translates to:
  /// **'Ảnh CCCD được mã hoá và lưu trữ an toàn. Chúng tôi không chia sẻ thông tin này với bên thứ ba.'**
  String get hStep2SecurityNote;

  /// No description provided for @hStep2Next.
  ///
  /// In vi, this message translates to:
  /// **'Tiếp theo'**
  String get hStep2Next;

  /// No description provided for @hStep3Eyebrow.
  ///
  /// In vi, this message translates to:
  /// **'Bước 3 / 3'**
  String get hStep3Eyebrow;

  /// No description provided for @hStep3Title.
  ///
  /// In vi, this message translates to:
  /// **'Thông tin thanh toán'**
  String get hStep3Title;

  /// No description provided for @hStep3ReceivingAccount.
  ///
  /// In vi, this message translates to:
  /// **'Tài khoản nhận tiền'**
  String get hStep3ReceivingAccount;

  /// No description provided for @hStep3Subtitle.
  ///
  /// In vi, this message translates to:
  /// **'Nhập tài khoản ngân hàng để nhận tiền từ người thuê.'**
  String get hStep3Subtitle;

  /// No description provided for @hStep3BankLabel.
  ///
  /// In vi, this message translates to:
  /// **'Ngân hàng *'**
  String get hStep3BankLabel;

  /// No description provided for @hStep3BankHint.
  ///
  /// In vi, this message translates to:
  /// **'Chọn ngân hàng'**
  String get hStep3BankHint;

  /// No description provided for @hStep3BankRequired.
  ///
  /// In vi, this message translates to:
  /// **'Vui lòng chọn ngân hàng'**
  String get hStep3BankRequired;

  /// No description provided for @hStep3AccountNumber.
  ///
  /// In vi, this message translates to:
  /// **'Số tài khoản'**
  String get hStep3AccountNumber;

  /// No description provided for @hStep3AccountNumberRequired.
  ///
  /// In vi, this message translates to:
  /// **'Vui lòng nhập số tài khoản'**
  String get hStep3AccountNumberRequired;

  /// No description provided for @hStep3AccountNumberInvalid.
  ///
  /// In vi, this message translates to:
  /// **'Số tài khoản không hợp lệ'**
  String get hStep3AccountNumberInvalid;

  /// No description provided for @hStep3AccountHolder.
  ///
  /// In vi, this message translates to:
  /// **'Tên chủ tài khoản'**
  String get hStep3AccountHolder;

  /// No description provided for @hStep3AccountHolderRequired.
  ///
  /// In vi, this message translates to:
  /// **'Vui lòng nhập tên chủ tài khoản'**
  String get hStep3AccountHolderRequired;

  /// No description provided for @hStep3TaxId.
  ///
  /// In vi, this message translates to:
  /// **'Mã số thuế (tùy chọn)'**
  String get hStep3TaxId;

  /// No description provided for @hStep3SubmitButton.
  ///
  /// In vi, this message translates to:
  /// **'Hoàn tất đăng ký'**
  String get hStep3SubmitButton;

  /// No description provided for @hStep3SaveFailed.
  ///
  /// In vi, this message translates to:
  /// **'Lưu thất bại'**
  String get hStep3SaveFailed;

  /// No description provided for @adminCtrTitle.
  ///
  /// In vi, this message translates to:
  /// **'Duyệt đơn vị'**
  String get adminCtrTitle;

  /// No description provided for @adminCtrApproved.
  ///
  /// In vi, this message translates to:
  /// **'Đã duyệt hồ sơ'**
  String get adminCtrApproved;

  /// No description provided for @adminCtrCertVerified.
  ///
  /// In vi, this message translates to:
  /// **'Đã xác minh chứng chỉ'**
  String get adminCtrCertVerified;

  /// No description provided for @adminCtrError.
  ///
  /// In vi, this message translates to:
  /// **'Lỗi: {error}'**
  String adminCtrError(Object error);

  /// No description provided for @adminCtrRejectTitle.
  ///
  /// In vi, this message translates to:
  /// **'Từ chối hồ sơ?'**
  String get adminCtrRejectTitle;

  /// No description provided for @adminCtrRejectBody.
  ///
  /// In vi, this message translates to:
  /// **'Hồ sơ sẽ không hiển thị trong danh bạ.'**
  String get adminCtrRejectBody;

  /// No description provided for @adminCtrCancel.
  ///
  /// In vi, this message translates to:
  /// **'Huỷ'**
  String get adminCtrCancel;

  /// No description provided for @adminCtrReject.
  ///
  /// In vi, this message translates to:
  /// **'Từ chối'**
  String get adminCtrReject;

  /// No description provided for @adminCtrRejected.
  ///
  /// In vi, this message translates to:
  /// **'Đã từ chối'**
  String get adminCtrRejected;

  /// No description provided for @adminCtrLoadFailed.
  ///
  /// In vi, this message translates to:
  /// **'Không tải được'**
  String get adminCtrLoadFailed;

  /// No description provided for @adminCtrLoadFailedHint.
  ///
  /// In vi, this message translates to:
  /// **'Kiểm tra kết nối rồi thử lại.'**
  String get adminCtrLoadFailedHint;

  /// No description provided for @adminCtrRetry.
  ///
  /// In vi, this message translates to:
  /// **'Thử lại'**
  String get adminCtrRetry;

  /// No description provided for @adminCtrEmptyTitle.
  ///
  /// In vi, this message translates to:
  /// **'Không có hồ sơ chờ duyệt'**
  String get adminCtrEmptyTitle;

  /// No description provided for @adminCtrEmptyHint.
  ///
  /// In vi, this message translates to:
  /// **'Hồ sơ mới sẽ hiện ở đây.'**
  String get adminCtrEmptyHint;

  /// No description provided for @adminCtrCompanyFallback.
  ///
  /// In vi, this message translates to:
  /// **'Đơn vị'**
  String get adminCtrCompanyFallback;

  /// No description provided for @adminCtrCertNumber.
  ///
  /// In vi, this message translates to:
  /// **'CCHN: {number}'**
  String adminCtrCertNumber(Object number);

  /// No description provided for @adminCtrCertVerifiedLabel.
  ///
  /// In vi, this message translates to:
  /// **'đã xác minh'**
  String get adminCtrCertVerifiedLabel;

  /// No description provided for @adminCtrVerify.
  ///
  /// In vi, this message translates to:
  /// **'Xác minh'**
  String get adminCtrVerify;

  /// No description provided for @adminCtrApprove.
  ///
  /// In vi, this message translates to:
  /// **'Duyệt'**
  String get adminCtrApprove;

  /// No description provided for @adminHomeTitle.
  ///
  /// In vi, this message translates to:
  /// **'Bảng điều khiển Admin'**
  String get adminHomeTitle;

  /// No description provided for @adminHomePending.
  ///
  /// In vi, this message translates to:
  /// **'Chờ duyệt'**
  String get adminHomePending;

  /// No description provided for @adminHomeApproved.
  ///
  /// In vi, this message translates to:
  /// **'Đã duyệt'**
  String get adminHomeApproved;

  /// No description provided for @adminHomeRejected.
  ///
  /// In vi, this message translates to:
  /// **'Đã từ chối'**
  String get adminHomeRejected;

  /// No description provided for @adminHomePublished.
  ///
  /// In vi, this message translates to:
  /// **'Đã đăng'**
  String get adminHomePublished;

  /// No description provided for @adminHomeUsers.
  ///
  /// In vi, this message translates to:
  /// **'Người dùng'**
  String get adminHomeUsers;

  /// No description provided for @adminHomeToolModerateReel.
  ///
  /// In vi, this message translates to:
  /// **'Kiểm duyệt\nReel'**
  String get adminHomeToolModerateReel;

  /// No description provided for @adminHomeToolVerifyQueue.
  ///
  /// In vi, this message translates to:
  /// **'Hàng đợi\nthẩm định'**
  String get adminHomeToolVerifyQueue;

  /// No description provided for @adminHomeToolPlanningRisk.
  ///
  /// In vi, this message translates to:
  /// **'Rủi ro\nquy hoạch'**
  String get adminHomeToolPlanningRisk;

  /// No description provided for @adminHomeToolTrustedMark.
  ///
  /// In vi, this message translates to:
  /// **'Đánh dấu\nuy tín'**
  String get adminHomeToolTrustedMark;

  /// No description provided for @adminHomeToolApproveContractor.
  ///
  /// In vi, this message translates to:
  /// **'Duyệt\nđơn vị'**
  String get adminHomeToolApproveContractor;

  /// No description provided for @adminHomeToolMarketResearch.
  ///
  /// In vi, this message translates to:
  /// **'Điều tra\nthị trường'**
  String get adminHomeToolMarketResearch;

  /// No description provided for @adminHomeEmptyPending.
  ///
  /// In vi, this message translates to:
  /// **'Không có tin nào chờ duyệt'**
  String get adminHomeEmptyPending;

  /// No description provided for @adminHomeEmptyApproved.
  ///
  /// In vi, this message translates to:
  /// **'Chưa có tin đã duyệt'**
  String get adminHomeEmptyApproved;

  /// No description provided for @adminHomeEmptyRejected.
  ///
  /// In vi, this message translates to:
  /// **'Chưa có tin bị từ chối'**
  String get adminHomeEmptyRejected;

  /// No description provided for @adminHomeHost.
  ///
  /// In vi, this message translates to:
  /// **'Chủ: {name}'**
  String adminHomeHost(Object name);

  /// No description provided for @adminHomeReject.
  ///
  /// In vi, this message translates to:
  /// **'Từ chối'**
  String get adminHomeReject;

  /// No description provided for @adminHomeApprove.
  ///
  /// In vi, this message translates to:
  /// **'Duyệt'**
  String get adminHomeApprove;

  /// No description provided for @adminHomeReapprove.
  ///
  /// In vi, this message translates to:
  /// **'Duyệt lại'**
  String get adminHomeReapprove;

  /// No description provided for @adminHomeUnpublish.
  ///
  /// In vi, this message translates to:
  /// **'Gỡ tin'**
  String get adminHomeUnpublish;

  /// No description provided for @adminHomeRejectReasonTitle.
  ///
  /// In vi, this message translates to:
  /// **'Lý do từ chối'**
  String get adminHomeRejectReasonTitle;

  /// No description provided for @adminHomeRejectReasonHint.
  ///
  /// In vi, this message translates to:
  /// **'Nhập lý do để host biết cách sửa...'**
  String get adminHomeRejectReasonHint;

  /// No description provided for @adminHomeMsgApproved.
  ///
  /// In vi, this message translates to:
  /// **'Đã duyệt tin'**
  String get adminHomeMsgApproved;

  /// No description provided for @adminHomeMsgRejected.
  ///
  /// In vi, this message translates to:
  /// **'Đã từ chối tin'**
  String get adminHomeMsgRejected;

  /// No description provided for @adminHomeMsgUpdated.
  ///
  /// In vi, this message translates to:
  /// **'Đã cập nhật tin'**
  String get adminHomeMsgUpdated;

  /// No description provided for @adminHomeMsgFailed.
  ///
  /// In vi, this message translates to:
  /// **'Thao tác thất bại'**
  String get adminHomeMsgFailed;

  /// No description provided for @adminReelEyebrow.
  ///
  /// In vi, this message translates to:
  /// **'Kiểm duyệt'**
  String get adminReelEyebrow;

  /// No description provided for @adminReelTitle.
  ///
  /// In vi, this message translates to:
  /// **'Video Reel'**
  String get adminReelTitle;

  /// No description provided for @adminReelTabPending.
  ///
  /// In vi, this message translates to:
  /// **'Chờ duyệt'**
  String get adminReelTabPending;

  /// No description provided for @adminReelTabHidden.
  ///
  /// In vi, this message translates to:
  /// **'Bị ẩn'**
  String get adminReelTabHidden;

  /// No description provided for @adminReelTabPublished.
  ///
  /// In vi, this message translates to:
  /// **'Đã đăng'**
  String get adminReelTabPublished;

  /// No description provided for @adminReelEmpty.
  ///
  /// In vi, this message translates to:
  /// **'Không có reel nào'**
  String get adminReelEmpty;

  /// No description provided for @adminReelStatsTitle.
  ///
  /// In vi, this message translates to:
  /// **'Số liệu vận hành (30 ngày)'**
  String get adminReelStatsTitle;

  /// No description provided for @adminReelStatReels.
  ///
  /// In vi, this message translates to:
  /// **'reel'**
  String get adminReelStatReels;

  /// No description provided for @adminReelStatPending.
  ///
  /// In vi, this message translates to:
  /// **'chờ duyệt'**
  String get adminReelStatPending;

  /// No description provided for @adminReelStatViews.
  ///
  /// In vi, this message translates to:
  /// **'lượt xem'**
  String get adminReelStatViews;

  /// No description provided for @adminReelStatLikes.
  ///
  /// In vi, this message translates to:
  /// **'thích'**
  String get adminReelStatLikes;

  /// No description provided for @adminReelStatComments.
  ///
  /// In vi, this message translates to:
  /// **'bình luận'**
  String get adminReelStatComments;

  /// No description provided for @adminReelStatStorage.
  ///
  /// In vi, this message translates to:
  /// **'dung lượng'**
  String get adminReelStatStorage;

  /// No description provided for @adminReelStatFailures.
  ///
  /// In vi, this message translates to:
  /// **'lỗi xử lý'**
  String get adminReelStatFailures;

  /// No description provided for @adminReelNoCaption.
  ///
  /// In vi, this message translates to:
  /// **'(không có chú thích)'**
  String get adminReelNoCaption;

  /// No description provided for @adminReelReportCount.
  ///
  /// In vi, this message translates to:
  /// **'{count} báo cáo'**
  String adminReelReportCount(Object count);

  /// No description provided for @adminReelRejectReason.
  ///
  /// In vi, this message translates to:
  /// **'Lý do: {reason}'**
  String adminReelRejectReason(Object reason);

  /// No description provided for @adminReelApprove.
  ///
  /// In vi, this message translates to:
  /// **'Duyệt'**
  String get adminReelApprove;

  /// No description provided for @adminReelHide.
  ///
  /// In vi, this message translates to:
  /// **'Ẩn'**
  String get adminReelHide;

  /// No description provided for @adminReelReject.
  ///
  /// In vi, this message translates to:
  /// **'Từ chối'**
  String get adminReelReject;

  /// No description provided for @adminReelRejectTitle.
  ///
  /// In vi, this message translates to:
  /// **'Từ chối reel'**
  String get adminReelRejectTitle;

  /// No description provided for @adminReelReasonLabel.
  ///
  /// In vi, this message translates to:
  /// **'Lý do *'**
  String get adminReelReasonLabel;

  /// No description provided for @adminReelReasonHint.
  ///
  /// In vi, this message translates to:
  /// **'VD: nội dung không liên quan'**
  String get adminReelReasonHint;

  /// No description provided for @adminReelApproved.
  ///
  /// In vi, this message translates to:
  /// **'Đã duyệt — reel hiển thị công khai'**
  String get adminReelApproved;

  /// No description provided for @adminReelRejected.
  ///
  /// In vi, this message translates to:
  /// **'Đã từ chối reel'**
  String get adminReelRejected;

  /// No description provided for @adminReelHidden.
  ///
  /// In vi, this message translates to:
  /// **'Đã ẩn reel'**
  String get adminReelHidden;

  /// No description provided for @adminReelActionFailed.
  ///
  /// In vi, this message translates to:
  /// **'Thao tác thất bại: {error}'**
  String adminReelActionFailed(Object error);

  /// No description provided for @adminVerifTitle.
  ///
  /// In vi, this message translates to:
  /// **'Hàng đợi thẩm định'**
  String get adminVerifTitle;

  /// No description provided for @adminVerifEmpty.
  ///
  /// In vi, this message translates to:
  /// **'Không có yêu cầu nào'**
  String get adminVerifEmpty;

  /// No description provided for @adminVerifLoadError.
  ///
  /// In vi, this message translates to:
  /// **'Không tải được: {error}'**
  String adminVerifLoadError(Object error);

  /// No description provided for @adminVerifRateDialogTitle.
  ///
  /// In vi, this message translates to:
  /// **'Gắn sao thẩm định — {title}'**
  String adminVerifRateDialogTitle(Object title);

  /// No description provided for @adminVerifProperty.
  ///
  /// In vi, this message translates to:
  /// **'BĐS'**
  String get adminVerifProperty;

  /// No description provided for @adminVerifStarsLabel.
  ///
  /// In vi, this message translates to:
  /// **'{count} sao'**
  String adminVerifStarsLabel(Object count);

  /// No description provided for @adminVerifConfirm.
  ///
  /// In vi, this message translates to:
  /// **'Xác nhận'**
  String get adminVerifConfirm;

  /// No description provided for @adminVerifRatedToast.
  ///
  /// In vi, this message translates to:
  /// **'Đã gắn sao thẩm định.'**
  String get adminVerifRatedToast;

  /// No description provided for @adminVerifError.
  ///
  /// In vi, this message translates to:
  /// **'Lỗi: {error}'**
  String adminVerifError(Object error);

  /// No description provided for @adminVerifSubtitle.
  ///
  /// In vi, this message translates to:
  /// **'Trạng thái: {status} · Yêu cầu: {date}'**
  String adminVerifSubtitle(Object status, Object date);

  /// No description provided for @adminVerifVerifyButton.
  ///
  /// In vi, this message translates to:
  /// **'Thẩm định'**
  String get adminVerifVerifyButton;

  /// No description provided for @hActionItemsHeader.
  ///
  /// In vi, this message translates to:
  /// **'CẦN ACTION'**
  String get hActionItemsHeader;

  /// No description provided for @hActionItemsOverdueInvoices.
  ///
  /// In vi, this message translates to:
  /// **'Hoá đơn quá hạn'**
  String get hActionItemsOverdueInvoices;

  /// No description provided for @hActionItemsExpiringContracts.
  ///
  /// In vi, this message translates to:
  /// **'Hợp đồng sắp hết hạn'**
  String get hActionItemsExpiringContracts;

  /// No description provided for @hActionItemsOverdueKhaiBao.
  ///
  /// In vi, this message translates to:
  /// **'Khai báo tạm trú quá hạn'**
  String get hActionItemsOverdueKhaiBao;

  /// No description provided for @hActionItemsMaintenanceRooms.
  ///
  /// In vi, this message translates to:
  /// **'Phòng đang bảo trì'**
  String get hActionItemsMaintenanceRooms;

  /// No description provided for @hActionItemsZaloFailed.
  ///
  /// In vi, this message translates to:
  /// **'Không tạo được nhắc Zalo'**
  String get hActionItemsZaloFailed;

  /// No description provided for @hActionItemsInvoiceDue.
  ///
  /// In vi, this message translates to:
  /// **'Hạn {dueDate} · còn {amount} VND'**
  String hActionItemsInvoiceDue(Object dueDate, Object amount);

  /// No description provided for @hActionItemsRemindZalo.
  ///
  /// In vi, this message translates to:
  /// **'Nhắc qua Zalo'**
  String get hActionItemsRemindZalo;

  /// No description provided for @hActionItemsContractRoom.
  ///
  /// In vi, this message translates to:
  /// **'HĐ #{contractId} · Phòng {roomId}'**
  String hActionItemsContractRoom(Object contractId, Object roomId);

  /// No description provided for @hActionItemsContractExpiry.
  ///
  /// In vi, this message translates to:
  /// **'Hết hạn {endDate} · {rent} VND/th'**
  String hActionItemsContractExpiry(Object endDate, Object rent);

  /// No description provided for @hActionItemsTenant.
  ///
  /// In vi, this message translates to:
  /// **'Tenant #{tenantId}'**
  String hActionItemsTenant(Object tenantId);

  /// No description provided for @hActionItemsCheckIn.
  ///
  /// In vi, this message translates to:
  /// **'Check-in {checkInAt}'**
  String hActionItemsCheckIn(Object checkInAt);

  /// No description provided for @hActionItemsMaintenanceSince.
  ///
  /// In vi, this message translates to:
  /// **'Từ {startDate}'**
  String hActionItemsMaintenanceSince(Object startDate);

  /// No description provided for @hActionItemsMaintenanceActive.
  ///
  /// In vi, this message translates to:
  /// **'Đang bảo trì'**
  String get hActionItemsMaintenanceActive;

  /// No description provided for @hAnalyticsFilterSelectPeriod.
  ///
  /// In vi, this message translates to:
  /// **'Chọn kỳ'**
  String get hAnalyticsFilterSelectPeriod;

  /// No description provided for @hAnalyticsFilterTitle.
  ///
  /// In vi, this message translates to:
  /// **'Lọc'**
  String get hAnalyticsFilterTitle;

  /// No description provided for @hAnalyticsFilterActive.
  ///
  /// In vi, this message translates to:
  /// **'Đang lọc'**
  String get hAnalyticsFilterActive;

  /// No description provided for @hAnalyticsFilterBuilding.
  ///
  /// In vi, this message translates to:
  /// **'Tòa nhà'**
  String get hAnalyticsFilterBuilding;

  /// No description provided for @hAnalyticsFilterSource.
  ///
  /// In vi, this message translates to:
  /// **'Nguồn thu'**
  String get hAnalyticsFilterSource;

  /// No description provided for @hAnalyticsFilterRoomType.
  ///
  /// In vi, this message translates to:
  /// **'Loại phòng'**
  String get hAnalyticsFilterRoomType;

  /// No description provided for @hAnalyticsFilterPeriod.
  ///
  /// In vi, this message translates to:
  /// **'Kỳ'**
  String get hAnalyticsFilterPeriod;

  /// No description provided for @hAnalyticsFilterClearPeriod.
  ///
  /// In vi, this message translates to:
  /// **'Xoá kỳ'**
  String get hAnalyticsFilterClearPeriod;

  /// No description provided for @hAnalyticsFilterManageSources.
  ///
  /// In vi, this message translates to:
  /// **'Quản lý nguồn'**
  String get hAnalyticsFilterManageSources;

  /// No description provided for @hAnalyticsFilterReset.
  ///
  /// In vi, this message translates to:
  /// **'Reset'**
  String get hAnalyticsFilterReset;

  /// No description provided for @hAnalyticsFilterApply.
  ///
  /// In vi, this message translates to:
  /// **'Áp dụng'**
  String get hAnalyticsFilterApply;

  /// No description provided for @hCreateContractTitle.
  ///
  /// In vi, this message translates to:
  /// **'Tạo hợp đồng nháp'**
  String get hCreateContractTitle;

  /// No description provided for @hCreateContractViewRequestEyebrow.
  ///
  /// In vi, this message translates to:
  /// **'YÊU CẦU XEM NHÀ'**
  String get hCreateContractViewRequestEyebrow;

  /// No description provided for @hCreateContractGuest.
  ///
  /// In vi, this message translates to:
  /// **'Khách'**
  String get hCreateContractGuest;

  /// No description provided for @hCreateContractRequestCode.
  ///
  /// In vi, this message translates to:
  /// **'Mã yêu cầu'**
  String get hCreateContractRequestCode;

  /// No description provided for @hCreateContractWhatHappens.
  ///
  /// In vi, this message translates to:
  /// **'SẼ XẢY RA'**
  String get hCreateContractWhatHappens;

  /// No description provided for @hCreateContractWhatHappensBody.
  ///
  /// In vi, this message translates to:
  /// **'• Yêu cầu xem nhà → trạng thái \"Đã duyệt\".\n• Một Tenant tạm được tạo (hoặc dùng lại Tenant trùng SĐT).\n• Một Contract nháp (source = marketplace) liên kết Tenant và phòng nguồn.\n• Bạn tiếp tục chỉnh sửa HĐ (ngày bắt đầu, cọc…) trước khi kích hoạt.'**
  String get hCreateContractWhatHappensBody;

  /// No description provided for @hCreateContractConfirm.
  ///
  /// In vi, this message translates to:
  /// **'Xác nhận tạo HĐ nháp'**
  String get hCreateContractConfirm;

  /// No description provided for @hCreateContractCreating.
  ///
  /// In vi, this message translates to:
  /// **'Đang tạo…'**
  String get hCreateContractCreating;

  /// No description provided for @hCreateContractError.
  ///
  /// In vi, this message translates to:
  /// **'Lỗi'**
  String get hCreateContractError;

  /// No description provided for @hCreateContractCreatedDraft.
  ///
  /// In vi, this message translates to:
  /// **'Đã tạo HĐ nháp #{id} {suffix}'**
  String hCreateContractCreatedDraft(Object id, Object suffix);

  /// No description provided for @hCreateContractPlaceholderTenant.
  ///
  /// In vi, this message translates to:
  /// **'(tenant tạm)'**
  String get hCreateContractPlaceholderTenant;

  /// No description provided for @hPublishTitle.
  ///
  /// In vi, this message translates to:
  /// **'Đăng lên marketplace'**
  String get hPublishTitle;

  /// No description provided for @hPublishListingType.
  ///
  /// In vi, this message translates to:
  /// **'LOẠI TIN ĐĂNG'**
  String get hPublishListingType;

  /// No description provided for @hPublishTitleLabel.
  ///
  /// In vi, this message translates to:
  /// **'TIÊU ĐỀ (TUỲ CHỌN)'**
  String get hPublishTitleLabel;

  /// No description provided for @hPublishDescLabel.
  ///
  /// In vi, this message translates to:
  /// **'MÔ TẢ (TUỲ CHỌN)'**
  String get hPublishDescLabel;

  /// No description provided for @hPublishDescHint.
  ///
  /// In vi, this message translates to:
  /// **'Tiện nghi, vị trí, lưu ý…'**
  String get hPublishDescHint;

  /// No description provided for @hPublishPriceLabel.
  ///
  /// In vi, this message translates to:
  /// **'GIÁ HIỂN THỊ (VND, để trống dùng base_price)'**
  String get hPublishPriceLabel;

  /// No description provided for @hPublishPriceHint.
  ///
  /// In vi, this message translates to:
  /// **'VD: 3500000'**
  String get hPublishPriceHint;

  /// No description provided for @hPublishSubmitting.
  ///
  /// In vi, this message translates to:
  /// **'Đang đăng…'**
  String get hPublishSubmitting;

  /// No description provided for @hPublishSubmit.
  ///
  /// In vi, this message translates to:
  /// **'Xác nhận đăng tin'**
  String get hPublishSubmit;

  /// No description provided for @hPublishHelp.
  ///
  /// In vi, this message translates to:
  /// **'Tin đăng cần admin duyệt trước khi hiển thị công khai. Có thể ẩn lại bất cứ lúc nào từ màn hình Đồng bộ.'**
  String get hPublishHelp;

  /// No description provided for @hPublishSyncSuccess.
  ///
  /// In vi, this message translates to:
  /// **'Đã đồng bộ tin lên marketplace'**
  String get hPublishSyncSuccess;

  /// No description provided for @hPublishError.
  ///
  /// In vi, this message translates to:
  /// **'Lỗi'**
  String get hPublishError;

  /// No description provided for @hPublishTypeBoardingHouse.
  ///
  /// In vi, this message translates to:
  /// **'Nhà trọ'**
  String get hPublishTypeBoardingHouse;

  /// No description provided for @hPublishTypeHomestay.
  ///
  /// In vi, this message translates to:
  /// **'Homestay'**
  String get hPublishTypeHomestay;

  /// No description provided for @hPublishTypeApartment.
  ///
  /// In vi, this message translates to:
  /// **'Căn hộ'**
  String get hPublishTypeApartment;

  /// No description provided for @hSyncTitle.
  ///
  /// In vi, this message translates to:
  /// **'Đồng bộ marketplace'**
  String get hSyncTitle;

  /// No description provided for @hSyncHideListingTitle.
  ///
  /// In vi, this message translates to:
  /// **'Ẩn tin đăng'**
  String get hSyncHideListingTitle;

  /// No description provided for @hSyncHideConfirm.
  ///
  /// In vi, this message translates to:
  /// **'Ẩn phòng {roomCode} khỏi marketplace? Tin sẽ chuyển trạng thái \"hidden\", không bị xoá. Có thể đăng lại sau.'**
  String hSyncHideConfirm(Object roomCode);

  /// No description provided for @hSyncHideAction.
  ///
  /// In vi, this message translates to:
  /// **'Ẩn tin'**
  String get hSyncHideAction;

  /// No description provided for @hSyncHidden.
  ///
  /// In vi, this message translates to:
  /// **'Đã ẩn tin'**
  String get hSyncHidden;

  /// No description provided for @hSyncError.
  ///
  /// In vi, this message translates to:
  /// **'Lỗi'**
  String get hSyncError;

  /// No description provided for @hSyncEmptyTitle.
  ///
  /// In vi, this message translates to:
  /// **'Chưa có phòng nào để đồng bộ'**
  String get hSyncEmptyTitle;

  /// No description provided for @hSyncEmptySubtitle.
  ///
  /// In vi, this message translates to:
  /// **'Thêm phòng để bắt đầu đồng bộ với marketplace.'**
  String get hSyncEmptySubtitle;

  /// No description provided for @hSyncMarketplaceStatus.
  ///
  /// In vi, this message translates to:
  /// **'Trạng thái marketplace: {status}'**
  String hSyncMarketplaceStatus(Object status);

  /// No description provided for @hSyncLastSynced.
  ///
  /// In vi, this message translates to:
  /// **'Đồng bộ lần cuối: {time}'**
  String hSyncLastSynced(Object time);

  /// No description provided for @hSyncPublish.
  ///
  /// In vi, this message translates to:
  /// **'Đăng lên marketplace'**
  String get hSyncPublish;

  /// No description provided for @hSyncResync.
  ///
  /// In vi, this message translates to:
  /// **'Đồng bộ lại'**
  String get hSyncResync;

  /// No description provided for @hSyncHide.
  ///
  /// In vi, this message translates to:
  /// **'Ẩn'**
  String get hSyncHide;

  /// No description provided for @opDiscloseTitle.
  ///
  /// In vi, this message translates to:
  /// **'Thông báo tài khoản chung'**
  String get opDiscloseTitle;

  /// No description provided for @opDiscloseBody.
  ///
  /// In vi, this message translates to:
  /// **'Bạn đang sử dụng tài khoản doanh nghiệp chung. Vui lòng lưu ý:'**
  String get opDiscloseBody;

  /// No description provided for @opDisclosePointAudit.
  ///
  /// In vi, this message translates to:
  /// **'Mọi hành động được ghi lại trong nhật ký kiểm toán dưới danh tính tài khoản chung.'**
  String get opDisclosePointAudit;

  /// No description provided for @opDisclosePointPassword.
  ///
  /// In vi, this message translates to:
  /// **'Việc thay đổi mật khẩu là trách nhiệm của công ty bạn. Hệ thống sẽ không cảnh báo khi có đăng nhập bất thường.'**
  String get opDisclosePointPassword;

  /// No description provided for @opDisclosePointRbac.
  ///
  /// In vi, this message translates to:
  /// **'Phân quyền cá nhân trong doanh nghiệp (RBAC v2) sẽ ra mắt trong phiên bản tới.'**
  String get opDisclosePointRbac;

  /// No description provided for @opDiscloseAcknowledge.
  ///
  /// In vi, this message translates to:
  /// **'Tôi hiểu'**
  String get opDiscloseAcknowledge;

  /// No description provided for @opDiscloseAckError.
  ///
  /// In vi, this message translates to:
  /// **'Lỗi khi ghi nhận: {error}'**
  String opDiscloseAckError(Object error);

  /// No description provided for @opInviteTitle.
  ///
  /// In vi, this message translates to:
  /// **'Lời mời ủy thác'**
  String get opInviteTitle;

  /// No description provided for @opInviteEyebrow.
  ///
  /// In vi, this message translates to:
  /// **'OPERATOR · LỜI MỜI'**
  String get opInviteEyebrow;

  /// No description provided for @opInviteEmptyTitle.
  ///
  /// In vi, this message translates to:
  /// **'Không có lời mời nào'**
  String get opInviteEmptyTitle;

  /// No description provided for @opInviteEmptySubtitle.
  ///
  /// In vi, this message translates to:
  /// **'Khi chủ nhà mời bạn, lời mời sẽ xuất hiện ở đây.'**
  String get opInviteEmptySubtitle;

  /// No description provided for @opInviteOwnerFallback.
  ///
  /// In vi, this message translates to:
  /// **'Chủ nhà'**
  String get opInviteOwnerFallback;

  /// No description provided for @opInviteSentDate.
  ///
  /// In vi, this message translates to:
  /// **'Gửi: {date}'**
  String opInviteSentDate(Object date);

  /// No description provided for @opInviteStatusPending.
  ///
  /// In vi, this message translates to:
  /// **'Chờ xác nhận'**
  String get opInviteStatusPending;

  /// No description provided for @opInviteReject.
  ///
  /// In vi, this message translates to:
  /// **'Từ chối'**
  String get opInviteReject;

  /// No description provided for @opInviteAccept.
  ///
  /// In vi, this message translates to:
  /// **'Chấp nhận'**
  String get opInviteAccept;

  /// No description provided for @opInviteAcceptSuccess.
  ///
  /// In vi, this message translates to:
  /// **'Đã chấp nhận ủy thác thành công'**
  String get opInviteAcceptSuccess;

  /// No description provided for @opInviteAcceptError.
  ///
  /// In vi, this message translates to:
  /// **'Không thể chấp nhận. Thử lại.'**
  String get opInviteAcceptError;

  /// No description provided for @opInviteRejectSuccess.
  ///
  /// In vi, this message translates to:
  /// **'Đã từ chối lời mời'**
  String get opInviteRejectSuccess;

  /// No description provided for @opInviteRoleFull.
  ///
  /// In vi, this message translates to:
  /// **'Quyền: Vận hành đầy đủ'**
  String get opInviteRoleFull;

  /// No description provided for @opInviteRoleAccountant.
  ///
  /// In vi, this message translates to:
  /// **'Quyền: Kế toán'**
  String get opInviteRoleAccountant;

  /// No description provided for @opInviteRoleViewer.
  ///
  /// In vi, this message translates to:
  /// **'Quyền: Chỉ xem'**
  String get opInviteRoleViewer;

  /// No description provided for @opInviteRoleOther.
  ///
  /// In vi, this message translates to:
  /// **'Quyền: {preset}'**
  String opInviteRoleOther(Object preset);

  /// No description provided for @opInviteRoleUnknown.
  ///
  /// In vi, this message translates to:
  /// **'Không rõ'**
  String get opInviteRoleUnknown;

  /// No description provided for @tenantReportSubmittedTitle.
  ///
  /// In vi, this message translates to:
  /// **'Đã gửi báo cáo'**
  String get tenantReportSubmittedTitle;

  /// No description provided for @tenantReportSubmittedHeadline.
  ///
  /// In vi, this message translates to:
  /// **'Báo cáo đã được ghi nhận'**
  String get tenantReportSubmittedHeadline;

  /// No description provided for @tenantReportSubmittedSubtitle.
  ///
  /// In vi, this message translates to:
  /// **'Chúng tôi sẽ xem xét và liên hệ với bạn trong vòng 24 giờ.'**
  String get tenantReportSubmittedSubtitle;

  /// No description provided for @tenantReportBackHome.
  ///
  /// In vi, this message translates to:
  /// **'Về trang chủ'**
  String get tenantReportBackHome;

  /// No description provided for @tenantReportTitle.
  ///
  /// In vi, this message translates to:
  /// **'Báo cáo đại diện'**
  String get tenantReportTitle;

  /// No description provided for @tenantReportEyebrow.
  ///
  /// In vi, this message translates to:
  /// **'KHÁCH THUÊ · BÁO CÁO'**
  String get tenantReportEyebrow;

  /// No description provided for @tenantReportDisclosure.
  ///
  /// In vi, this message translates to:
  /// **'Nếu bạn không nhận ra người tự xưng là đại diện của chủ nhà, hãy báo cáo ngay. Thông tin của bạn sẽ được bảo mật.'**
  String get tenantReportDisclosure;

  /// No description provided for @tenantReportReasonLabel.
  ///
  /// In vi, this message translates to:
  /// **'Lý do'**
  String get tenantReportReasonLabel;

  /// No description provided for @tenantReportReasonUnknownPerson.
  ///
  /// In vi, this message translates to:
  /// **'Người này không phải đại diện tôi biết'**
  String get tenantReportReasonUnknownPerson;

  /// No description provided for @tenantReportReasonDifferentInfo.
  ///
  /// In vi, this message translates to:
  /// **'Thông tin không khớp với người đến thu tiền'**
  String get tenantReportReasonDifferentInfo;

  /// No description provided for @tenantReportReasonNoNotice.
  ///
  /// In vi, this message translates to:
  /// **'Chủ nhà chưa thông báo cho tôi'**
  String get tenantReportReasonNoNotice;

  /// No description provided for @tenantReportReasonOther.
  ///
  /// In vi, this message translates to:
  /// **'Lý do khác'**
  String get tenantReportReasonOther;

  /// No description provided for @tenantReportDetailLabel.
  ///
  /// In vi, this message translates to:
  /// **'Chi tiết thêm (không bắt buộc)'**
  String get tenantReportDetailLabel;

  /// No description provided for @tenantReportDetailHint.
  ///
  /// In vi, this message translates to:
  /// **'Mô tả thêm về sự việc...'**
  String get tenantReportDetailHint;

  /// No description provided for @tenantReportSubmitButton.
  ///
  /// In vi, this message translates to:
  /// **'Gửi báo cáo'**
  String get tenantReportSubmitButton;

  /// No description provided for @tenantReportSubmitFailed.
  ///
  /// In vi, this message translates to:
  /// **'Gửi báo cáo thất bại: {error}'**
  String tenantReportSubmitFailed(Object error);

  /// No description provided for @auditTitle.
  ///
  /// In vi, this message translates to:
  /// **'Nhật ký hoạt động'**
  String get auditTitle;

  /// No description provided for @auditRepresentative.
  ///
  /// In vi, this message translates to:
  /// **'ĐẠI DIỆN · {name}'**
  String auditRepresentative(Object name);

  /// No description provided for @auditOwnerFallback.
  ///
  /// In vi, this message translates to:
  /// **'Chủ nhà'**
  String get auditOwnerFallback;

  /// No description provided for @auditPeriodToday.
  ///
  /// In vi, this message translates to:
  /// **'Hôm nay'**
  String get auditPeriodToday;

  /// No description provided for @auditPeriodWeek.
  ///
  /// In vi, this message translates to:
  /// **'Tuần này'**
  String get auditPeriodWeek;

  /// No description provided for @auditPeriodMonth.
  ///
  /// In vi, this message translates to:
  /// **'Tháng này'**
  String get auditPeriodMonth;

  /// No description provided for @auditLoadError.
  ///
  /// In vi, this message translates to:
  /// **'Không tải được dữ liệu'**
  String get auditLoadError;

  /// No description provided for @auditRetry.
  ///
  /// In vi, this message translates to:
  /// **'Thử lại'**
  String get auditRetry;

  /// No description provided for @auditEmptyTitle.
  ///
  /// In vi, this message translates to:
  /// **'Chưa có hoạt động nào'**
  String get auditEmptyTitle;

  /// No description provided for @auditEmptySubtitle.
  ///
  /// In vi, this message translates to:
  /// **'Các hành động của Operator sẽ xuất hiện ở đây.'**
  String get auditEmptySubtitle;

  /// No description provided for @auditTlOperator.
  ///
  /// In vi, this message translates to:
  /// **'Người thao tác'**
  String get auditTlOperator;

  /// No description provided for @auditTlOwner.
  ///
  /// In vi, this message translates to:
  /// **'Chủ nhà'**
  String get auditTlOwner;

  /// No description provided for @auditTlAction.
  ///
  /// In vi, this message translates to:
  /// **'Hành động'**
  String get auditTlAction;

  /// No description provided for @auditTlJustNow.
  ///
  /// In vi, this message translates to:
  /// **'Vừa xong'**
  String get auditTlJustNow;

  /// No description provided for @auditTlMinutesAgo.
  ///
  /// In vi, this message translates to:
  /// **'{minutes}p trước'**
  String auditTlMinutesAgo(Object minutes);

  /// No description provided for @auditTlHoursAgo.
  ///
  /// In vi, this message translates to:
  /// **'{hours}h trước'**
  String auditTlHoursAgo(Object hours);

  /// No description provided for @auditTlDaysAgo.
  ///
  /// In vi, this message translates to:
  /// **'{days}d trước'**
  String auditTlDaysAgo(Object days);

  /// No description provided for @forgotValidateEmail.
  ///
  /// In vi, this message translates to:
  /// **'Vui lòng nhập email'**
  String get forgotValidateEmail;

  /// No description provided for @forgotDialogEyebrow.
  ///
  /// In vi, this message translates to:
  /// **'Khôi phục'**
  String get forgotDialogEyebrow;

  /// No description provided for @forgotDialogTitle.
  ///
  /// In vi, this message translates to:
  /// **'Mật khẩu tạm'**
  String get forgotDialogTitle;

  /// No description provided for @forgotDialogBody.
  ///
  /// In vi, this message translates to:
  /// **'Mật khẩu tài khoản đã được đặt lại. Hãy dùng mật khẩu tạm dưới đây để đăng nhập, rồi đổi ngay:'**
  String get forgotDialogBody;

  /// No description provided for @forgotCopied.
  ///
  /// In vi, this message translates to:
  /// **'Đã sao chép'**
  String get forgotCopied;

  /// No description provided for @forgotGotIt.
  ///
  /// In vi, this message translates to:
  /// **'Đã hiểu'**
  String get forgotGotIt;

  /// No description provided for @forgotError.
  ///
  /// In vi, this message translates to:
  /// **'Lỗi: {error}'**
  String forgotError(Object error);

  /// No description provided for @forgotAppBarEyebrow.
  ///
  /// In vi, this message translates to:
  /// **'Hỗ trợ'**
  String get forgotAppBarEyebrow;

  /// No description provided for @forgotTitle.
  ///
  /// In vi, this message translates to:
  /// **'Quên mật khẩu'**
  String get forgotTitle;

  /// No description provided for @forgotIntro.
  ///
  /// In vi, this message translates to:
  /// **'Nhập email tài khoản của bạn — hệ thống sẽ tạo một mật khẩu tạm để bạn đăng nhập rồi đổi lại ngay.'**
  String get forgotIntro;

  /// No description provided for @forgotEmailHint.
  ///
  /// In vi, this message translates to:
  /// **'ban@vidu.com'**
  String get forgotEmailHint;

  /// No description provided for @forgotSubmit.
  ///
  /// In vi, this message translates to:
  /// **'Tạo mật khẩu tạm'**
  String get forgotSubmit;

  /// No description provided for @guestGateTitle.
  ///
  /// In vi, this message translates to:
  /// **'Đăng nhập để tiếp tục'**
  String get guestGateTitle;

  /// No description provided for @guestGateBody.
  ///
  /// In vi, this message translates to:
  /// **'Bạn cần đăng nhập để lưu tin, liên hệ chủ nhà, đặt lịch xem, đăng tin hoặc tham gia cộng đồng.'**
  String get guestGateBody;

  /// No description provided for @guestGateLoginRegister.
  ///
  /// In vi, this message translates to:
  /// **'Đăng nhập / Đăng ký'**
  String get guestGateLoginRegister;

  /// No description provided for @guestGateLater.
  ///
  /// In vi, this message translates to:
  /// **'Để sau'**
  String get guestGateLater;

  /// No description provided for @guestGateAccount.
  ///
  /// In vi, this message translates to:
  /// **'Tài khoản'**
  String get guestGateAccount;

  /// No description provided for @hBatchRemindTitle.
  ///
  /// In vi, this message translates to:
  /// **'Nhắc nợ hàng loạt'**
  String get hBatchRemindTitle;

  /// No description provided for @hBatchRemindSummary.
  ///
  /// In vi, this message translates to:
  /// **'{count} phòng cần nhắc · tổng {total}'**
  String hBatchRemindSummary(Object count, Object total);

  /// No description provided for @hBatchRemindHint.
  ///
  /// In vi, this message translates to:
  /// **'Bấm \"Nhắc\" để mở Zalo gửi nhắc từng phòng.'**
  String get hBatchRemindHint;

  /// No description provided for @hBatchRemindEmpty.
  ///
  /// In vi, this message translates to:
  /// **'Không có phòng nào cần nhắc 🎉'**
  String get hBatchRemindEmpty;

  /// No description provided for @hBatchRemindOverdue.
  ///
  /// In vi, this message translates to:
  /// **'Nợ {amount} · quá hạn {days} ngày'**
  String hBatchRemindOverdue(Object amount, Object days);

  /// No description provided for @hBatchRemindDone.
  ///
  /// In vi, this message translates to:
  /// **'Đã nhắc'**
  String get hBatchRemindDone;

  /// No description provided for @hBatchRemindRemind.
  ///
  /// In vi, this message translates to:
  /// **'Nhắc'**
  String get hBatchRemindRemind;

  /// No description provided for @hBatchRemindReminding.
  ///
  /// In vi, this message translates to:
  /// **'Đang nhắc...'**
  String get hBatchRemindReminding;

  /// No description provided for @hBatchRemindRemindAll.
  ///
  /// In vi, this message translates to:
  /// **'Nhắc tất cả qua Zalo ({count})'**
  String hBatchRemindRemindAll(Object count);

  /// No description provided for @hCreditNoteInvalidAmount.
  ///
  /// In vi, this message translates to:
  /// **'Số tiền không hợp lệ'**
  String get hCreditNoteInvalidAmount;

  /// No description provided for @hCreditNoteCreated.
  ///
  /// In vi, this message translates to:
  /// **'Đã lập credit note'**
  String get hCreditNoteCreated;

  /// No description provided for @hCreditNoteFailed.
  ///
  /// In vi, this message translates to:
  /// **'Lập thất bại'**
  String get hCreditNoteFailed;

  /// No description provided for @hCreditNoteTitle.
  ///
  /// In vi, this message translates to:
  /// **'LẬP CREDIT NOTE'**
  String get hCreditNoteTitle;

  /// No description provided for @hCreditNoteDescription.
  ///
  /// In vi, this message translates to:
  /// **'Credit note là điều chỉnh hợp lệ trên hoá đơn đã thu. Hoá đơn gốc không bị thay đổi.'**
  String get hCreditNoteDescription;

  /// No description provided for @hCreditNoteAmountLabel.
  ///
  /// In vi, this message translates to:
  /// **'Số tiền điều chỉnh (VND) *'**
  String get hCreditNoteAmountLabel;

  /// No description provided for @hCreditNoteIssuedDateLabel.
  ///
  /// In vi, this message translates to:
  /// **'Ngày phát hành'**
  String get hCreditNoteIssuedDateLabel;

  /// No description provided for @hCreditNoteReasonLabel.
  ///
  /// In vi, this message translates to:
  /// **'Lý do'**
  String get hCreditNoteReasonLabel;

  /// No description provided for @hCreditNoteSubmit.
  ///
  /// In vi, this message translates to:
  /// **'Lập credit note'**
  String get hCreditNoteSubmit;

  /// No description provided for @hInvListTitle.
  ///
  /// In vi, this message translates to:
  /// **'HOÁ ĐƠN'**
  String get hInvListTitle;

  /// No description provided for @hInvListBatchCreate.
  ///
  /// In vi, this message translates to:
  /// **'Tạo hàng loạt'**
  String get hInvListBatchCreate;

  /// No description provided for @hInvListFilterAll.
  ///
  /// In vi, this message translates to:
  /// **'Tất cả'**
  String get hInvListFilterAll;

  /// No description provided for @hInvListStatusDraft.
  ///
  /// In vi, this message translates to:
  /// **'Nháp'**
  String get hInvListStatusDraft;

  /// No description provided for @hInvListStatusSent.
  ///
  /// In vi, this message translates to:
  /// **'Đã gửi'**
  String get hInvListStatusSent;

  /// No description provided for @hInvListStatusPaid.
  ///
  /// In vi, this message translates to:
  /// **'Đã thu'**
  String get hInvListStatusPaid;

  /// No description provided for @hInvListAllMonths.
  ///
  /// In vi, this message translates to:
  /// **'Mọi tháng'**
  String get hInvListAllMonths;

  /// No description provided for @hInvListEmpty.
  ///
  /// In vi, this message translates to:
  /// **'Chưa có hoá đơn'**
  String get hInvListEmpty;

  /// No description provided for @hInvListCreatedCount.
  ///
  /// In vi, this message translates to:
  /// **'Đã tạo {count} hoá đơn'**
  String hInvListCreatedCount(Object count);

  /// No description provided for @hInvListPeriod.
  ///
  /// In vi, this message translates to:
  /// **'Kỳ {start} → {end}'**
  String hInvListPeriod(Object start, Object end);

  /// No description provided for @hInvPayTitle.
  ///
  /// In vi, this message translates to:
  /// **'GHI NHẬN THANH TOÁN'**
  String get hInvPayTitle;

  /// No description provided for @hInvPayRemaining.
  ///
  /// In vi, this message translates to:
  /// **'Còn lại: '**
  String get hInvPayRemaining;

  /// No description provided for @hInvPayAmountLabel.
  ///
  /// In vi, this message translates to:
  /// **'Số tiền (VND) *'**
  String get hInvPayAmountLabel;

  /// No description provided for @hInvPayMethodLabel.
  ///
  /// In vi, this message translates to:
  /// **'Phương thức'**
  String get hInvPayMethodLabel;

  /// No description provided for @hInvPayMethodCash.
  ///
  /// In vi, this message translates to:
  /// **'Tiền mặt'**
  String get hInvPayMethodCash;

  /// No description provided for @hInvPayMethodBank.
  ///
  /// In vi, this message translates to:
  /// **'Chuyển khoản'**
  String get hInvPayMethodBank;

  /// No description provided for @hInvPayMethodOther.
  ///
  /// In vi, this message translates to:
  /// **'Khác'**
  String get hInvPayMethodOther;

  /// No description provided for @hInvPayNoteLabel.
  ///
  /// In vi, this message translates to:
  /// **'Ghi chú'**
  String get hInvPayNoteLabel;

  /// No description provided for @hInvPaySubmit.
  ///
  /// In vi, this message translates to:
  /// **'Ghi nhận'**
  String get hInvPaySubmit;

  /// No description provided for @hInvPayInvalidAmount.
  ///
  /// In vi, this message translates to:
  /// **'Số tiền không hợp lệ'**
  String get hInvPayInvalidAmount;

  /// No description provided for @hInvPayRecordFailed.
  ///
  /// In vi, this message translates to:
  /// **'Ghi nhận thất bại'**
  String get hInvPayRecordFailed;

  /// No description provided for @hMeterOpenFromRoomHint.
  ///
  /// In vi, this message translates to:
  /// **'Vui lòng vào từ chi tiết phòng để nhập chỉ số'**
  String get hMeterOpenFromRoomHint;

  /// No description provided for @hMeterTitleRoom.
  ///
  /// In vi, this message translates to:
  /// **'CHỈ SỐ • {code}'**
  String hMeterTitleRoom(Object code);

  /// No description provided for @hMeterTitle.
  ///
  /// In vi, this message translates to:
  /// **'CHỈ SỐ ĐIỆN NƯỚC'**
  String get hMeterTitle;

  /// No description provided for @hMeterAddTooltip.
  ///
  /// In vi, this message translates to:
  /// **'Thêm'**
  String get hMeterAddTooltip;

  /// No description provided for @hMeterEmpty.
  ///
  /// In vi, this message translates to:
  /// **'Chưa có chỉ số'**
  String get hMeterEmpty;

  /// No description provided for @hMeterUsageLine.
  ///
  /// In vi, this message translates to:
  /// **'Điện: {kwh} kWh • Nước: {water} m³'**
  String hMeterUsageLine(Object kwh, Object water);

  /// No description provided for @hMeterFormTitle.
  ///
  /// In vi, this message translates to:
  /// **'NHẬP CHỈ SỐ'**
  String get hMeterFormTitle;

  /// No description provided for @hMeterReadingDate.
  ///
  /// In vi, this message translates to:
  /// **'Ngày đọc'**
  String get hMeterReadingDate;

  /// No description provided for @hMeterElectricity.
  ///
  /// In vi, this message translates to:
  /// **'Điện (kWh)'**
  String get hMeterElectricity;

  /// No description provided for @hMeterWater.
  ///
  /// In vi, this message translates to:
  /// **'Nước (m³)'**
  String get hMeterWater;

  /// No description provided for @hMeterSave.
  ///
  /// In vi, this message translates to:
  /// **'Lưu chỉ số'**
  String get hMeterSave;

  /// No description provided for @hMeterSaveFailed.
  ///
  /// In vi, this message translates to:
  /// **'Lưu thất bại'**
  String get hMeterSaveFailed;

  /// No description provided for @hOccReportOccupancyRate.
  ///
  /// In vi, this message translates to:
  /// **'Tỷ lệ lấp đầy'**
  String get hOccReportOccupancyRate;

  /// No description provided for @hOccReportRoomsCount.
  ///
  /// In vi, this message translates to:
  /// **'{count} phòng'**
  String hOccReportRoomsCount(Object count);

  /// No description provided for @hOccReportByRoom.
  ///
  /// In vi, this message translates to:
  /// **'THEO PHÒNG'**
  String get hOccReportByRoom;

  /// No description provided for @hOccReportNoData.
  ///
  /// In vi, this message translates to:
  /// **'Chưa có dữ liệu'**
  String get hOccReportNoData;

  /// No description provided for @hRevReportExportFailed.
  ///
  /// In vi, this message translates to:
  /// **'Xuất CSV thất bại'**
  String get hRevReportExportFailed;

  /// No description provided for @hRevReportInvoiceSubject.
  ///
  /// In vi, this message translates to:
  /// **'Hoá đơn {month}'**
  String hRevReportInvoiceSubject(Object month);

  /// No description provided for @hRevReportTotalRevenue.
  ///
  /// In vi, this message translates to:
  /// **'Tổng doanh thu'**
  String get hRevReportTotalRevenue;

  /// No description provided for @hRevReportGrossRevenue.
  ///
  /// In vi, this message translates to:
  /// **'Doanh thu gộp'**
  String get hRevReportGrossRevenue;

  /// No description provided for @hRevReportNetRevenue.
  ///
  /// In vi, this message translates to:
  /// **'Doanh thu thực'**
  String get hRevReportNetRevenue;

  /// No description provided for @hRevReportNoData.
  ///
  /// In vi, this message translates to:
  /// **'Chưa có dữ liệu'**
  String get hRevReportNoData;

  /// No description provided for @hRevReportViewNewStats.
  ///
  /// In vi, this message translates to:
  /// **'Xem thống kê doanh thu mới'**
  String get hRevReportViewNewStats;

  /// No description provided for @hRevReportExporting.
  ///
  /// In vi, this message translates to:
  /// **'Đang xuất...'**
  String get hRevReportExporting;

  /// No description provided for @hRevReportExportCsv.
  ///
  /// In vi, this message translates to:
  /// **'Xuất CSV hoá đơn tháng này'**
  String get hRevReportExportCsv;

  /// No description provided for @notifInbox.
  ///
  /// In vi, this message translates to:
  /// **'Hộp thư'**
  String get notifInbox;

  /// No description provided for @notifMarkAllRead.
  ///
  /// In vi, this message translates to:
  /// **'Đọc tất cả'**
  String get notifMarkAllRead;

  /// No description provided for @notifEmpty.
  ///
  /// In vi, this message translates to:
  /// **'Chưa có thông báo nào'**
  String get notifEmpty;

  /// No description provided for @notifContentGone.
  ///
  /// In vi, this message translates to:
  /// **'Nội dung không còn'**
  String get notifContentGone;

  /// No description provided for @notifJustNow.
  ///
  /// In vi, this message translates to:
  /// **'Vừa xong'**
  String get notifJustNow;

  /// No description provided for @notifMinutesAgo.
  ///
  /// In vi, this message translates to:
  /// **'{count} phút trước'**
  String notifMinutesAgo(Object count);

  /// No description provided for @notifHoursAgo.
  ///
  /// In vi, this message translates to:
  /// **'{count} giờ trước'**
  String notifHoursAgo(Object count);

  /// No description provided for @notifDaysAgo.
  ///
  /// In vi, this message translates to:
  /// **'{count} ngày trước'**
  String notifDaysAgo(Object count);

  /// No description provided for @planErrTitle.
  ///
  /// In vi, this message translates to:
  /// **'Báo cáo dữ liệu sai'**
  String get planErrTitle;

  /// No description provided for @planErrReasonLabel.
  ///
  /// In vi, this message translates to:
  /// **'Lý do (≥10 ký tự)'**
  String get planErrReasonLabel;

  /// No description provided for @planErrReasonHint.
  ///
  /// In vi, this message translates to:
  /// **'VD: Thực tế zone đây là dân cư, không phải cây xanh'**
  String get planErrReasonHint;

  /// No description provided for @planErrAttachImage.
  ///
  /// In vi, this message translates to:
  /// **'Đính kèm ảnh (tuỳ chọn)'**
  String get planErrAttachImage;

  /// No description provided for @planErrImageAttached.
  ///
  /// In vi, this message translates to:
  /// **'Đã đính kèm ảnh'**
  String get planErrImageAttached;

  /// No description provided for @planErrSubmit.
  ///
  /// In vi, this message translates to:
  /// **'Gửi báo cáo'**
  String get planErrSubmit;

  /// No description provided for @planErrSuccessMsg.
  ///
  /// In vi, this message translates to:
  /// **'Đã gửi báo cáo. Cảm ơn bạn!'**
  String get planErrSuccessMsg;

  /// No description provided for @planErrMinLength.
  ///
  /// In vi, this message translates to:
  /// **'Lý do tối thiểu 10 ký tự'**
  String get planErrMinLength;

  /// No description provided for @planErrUploading.
  ///
  /// In vi, this message translates to:
  /// **'Đang tải ảnh lên...'**
  String get planErrUploading;

  /// No description provided for @planErrImageTooLarge.
  ///
  /// In vi, this message translates to:
  /// **'Ảnh quá lớn (tối đa 5 MB)'**
  String get planErrImageTooLarge;

  /// No description provided for @planErrRemoveImage.
  ///
  /// In vi, this message translates to:
  /// **'Xoá ảnh'**
  String get planErrRemoveImage;

  /// No description provided for @planErrParcelId.
  ///
  /// In vi, this message translates to:
  /// **'Parcel ID: {id}'**
  String planErrParcelId(Object id);

  /// No description provided for @planErrUploadFailed.
  ///
  /// In vi, this message translates to:
  /// **'Tải ảnh thất bại: {error}'**
  String planErrUploadFailed(Object error);

  /// No description provided for @planErrSubmitFailed.
  ///
  /// In vi, this message translates to:
  /// **'Gửi thất bại: {error}'**
  String planErrSubmitFailed(Object error);

  /// No description provided for @planProvSelectHint.
  ///
  /// In vi, this message translates to:
  /// **'Chọn tỉnh / địa chỉ'**
  String get planProvSelectHint;

  /// No description provided for @planProvTitle.
  ///
  /// In vi, this message translates to:
  /// **'Chọn tỉnh / Tìm địa chỉ'**
  String get planProvTitle;

  /// No description provided for @planProvSearchHint.
  ///
  /// In vi, this message translates to:
  /// **'Tỉnh, địa chỉ, đường, địa điểm...'**
  String get planProvSearchHint;

  /// No description provided for @planProvNoResults.
  ///
  /// In vi, this message translates to:
  /// **'Không tìm thấy kết quả'**
  String get planProvNoResults;

  /// No description provided for @planProvEmptyPrompt.
  ///
  /// In vi, this message translates to:
  /// **'Nhập tên tỉnh hoặc địa chỉ'**
  String get planProvEmptyPrompt;

  /// No description provided for @planProvSectionProvince.
  ///
  /// In vi, this message translates to:
  /// **'Tỉnh / Thành'**
  String get planProvSectionProvince;

  /// No description provided for @planProvSectionAddress.
  ///
  /// In vi, this message translates to:
  /// **'Địa chỉ'**
  String get planProvSectionAddress;

  /// No description provided for @planProvHasOverlay.
  ///
  /// In vi, this message translates to:
  /// **'Có overlay quy hoạch 2030'**
  String get planProvHasOverlay;

  /// No description provided for @planProvNoOverlay.
  ///
  /// In vi, this message translates to:
  /// **'Chỉ địa chỉ — chưa có overlay'**
  String get planProvNoOverlay;

  /// No description provided for @planWarnTitle.
  ///
  /// In vi, this message translates to:
  /// **'Thông tin và quy hoạch'**
  String get planWarnTitle;

  /// No description provided for @planWarnReport.
  ///
  /// In vi, this message translates to:
  /// **'Báo cáo nếu thông tin sai'**
  String get planWarnReport;

  /// No description provided for @planWarnOk.
  ///
  /// In vi, this message translates to:
  /// **'Đã hiểu'**
  String get planWarnOk;

  /// No description provided for @planWarnLoadError.
  ///
  /// In vi, this message translates to:
  /// **'Không tải được: {error}'**
  String planWarnLoadError(Object error);

  /// No description provided for @planWarnNotFound.
  ///
  /// In vi, this message translates to:
  /// **'Không tìm thấy thông tin quy hoạch tại vị trí này.'**
  String get planWarnNotFound;

  /// No description provided for @planWarnRisky.
  ///
  /// In vi, this message translates to:
  /// **'Khu vực này có thể ảnh hưởng kế hoạch sử dụng đất ({zone}). Bạn vẫn có thể đăng tin nhưng nên cân nhắc.'**
  String planWarnRisky(Object zone);

  /// No description provided for @planWarnSuitable.
  ///
  /// In vi, this message translates to:
  /// **'Khu vực này phù hợp đăng tin.'**
  String get planWarnSuitable;

  /// No description provided for @planWarnZoneLabel.
  ///
  /// In vi, this message translates to:
  /// **'Zone'**
  String get planWarnZoneLabel;

  /// No description provided for @planWarnAreaLabel.
  ///
  /// In vi, this message translates to:
  /// **'Diện tích'**
  String get planWarnAreaLabel;

  /// No description provided for @planWarnDistrictLabel.
  ///
  /// In vi, this message translates to:
  /// **'Quận'**
  String get planWarnDistrictLabel;

  /// No description provided for @hDebtAgingTitle.
  ///
  /// In vi, this message translates to:
  /// **'CÔNG NỢ'**
  String get hDebtAgingTitle;

  /// No description provided for @hDebtAgingEmptyTitle.
  ///
  /// In vi, this message translates to:
  /// **'Chưa có dữ liệu công nợ'**
  String get hDebtAgingEmptyTitle;

  /// No description provided for @hDebtAgingTotal.
  ///
  /// In vi, this message translates to:
  /// **'TỔNG CÔNG NỢ'**
  String get hDebtAgingTotal;

  /// No description provided for @hDebtAgingByBucket.
  ///
  /// In vi, this message translates to:
  /// **'PHÂN BUCKET'**
  String get hDebtAgingByBucket;

  /// No description provided for @hDebtAgingNeedsReminder.
  ///
  /// In vi, this message translates to:
  /// **'CẦN NHẮC THUÊ ({count})'**
  String hDebtAgingNeedsReminder(Object count);

  /// No description provided for @hDebtAgingBucketDays.
  ///
  /// In vi, this message translates to:
  /// **'Bucket {days} ngày'**
  String hDebtAgingBucketDays(Object days);

  /// No description provided for @hDebtAgingInvoiceCount.
  ///
  /// In vi, this message translates to:
  /// **'{count} hoá đơn'**
  String hDebtAgingInvoiceCount(Object count);

  /// No description provided for @hDebtAgingOverdue.
  ///
  /// In vi, this message translates to:
  /// **'Trễ {days} ngày • {phone}'**
  String hDebtAgingOverdue(Object days, Object phone);

  /// No description provided for @ctrFilterTitle.
  ///
  /// In vi, this message translates to:
  /// **'Lọc đơn vị xây dựng'**
  String get ctrFilterTitle;

  /// No description provided for @ctrFilterService.
  ///
  /// In vi, this message translates to:
  /// **'Ngành'**
  String get ctrFilterService;

  /// No description provided for @ctrFilterProvince.
  ///
  /// In vi, this message translates to:
  /// **'Khu vực'**
  String get ctrFilterProvince;

  /// No description provided for @ctrFilterSort.
  ///
  /// In vi, this message translates to:
  /// **'Sắp xếp'**
  String get ctrFilterSort;

  /// No description provided for @ctrFilterSortHelper.
  ///
  /// In vi, this message translates to:
  /// **'\"Đề xuất\" là thứ tự hệ thống: đơn vị nổi bật · gói Pro · đã thẩm định · điểm đánh giá.'**
  String get ctrFilterSortHelper;

  /// No description provided for @ctrFilterAllServices.
  ///
  /// In vi, this message translates to:
  /// **'Tất cả ngành'**
  String get ctrFilterAllServices;

  /// No description provided for @ctrFilterAllProvinces.
  ///
  /// In vi, this message translates to:
  /// **'Toàn quốc'**
  String get ctrFilterAllProvinces;

  /// No description provided for @ctrFilterProvinceUnavailable.
  ///
  /// In vi, this message translates to:
  /// **'Chưa tải được danh sách tỉnh/thành — thử lại sau.'**
  String get ctrFilterProvinceUnavailable;

  /// No description provided for @ctrFilterSortRecommend.
  ///
  /// In vi, this message translates to:
  /// **'Đề xuất'**
  String get ctrFilterSortRecommend;

  /// No description provided for @ctrFilterSortRating.
  ///
  /// In vi, this message translates to:
  /// **'Điểm cao nhất'**
  String get ctrFilterSortRating;

  /// No description provided for @ctrFilterSortReviews.
  ///
  /// In vi, this message translates to:
  /// **'Nhiều đánh giá nhất'**
  String get ctrFilterSortReviews;

  /// No description provided for @ctrFilterApply.
  ///
  /// In vi, this message translates to:
  /// **'Áp dụng'**
  String get ctrFilterApply;

  /// No description provided for @ctrFilterReset.
  ///
  /// In vi, this message translates to:
  /// **'Xoá lọc'**
  String get ctrFilterReset;

  /// No description provided for @ctrListTitleAll.
  ///
  /// In vi, this message translates to:
  /// **'Đơn vị xây dựng'**
  String get ctrListTitleAll;

  /// No description provided for @ctrListFilterTooltip.
  ///
  /// In vi, this message translates to:
  /// **'Bộ lọc đơn vị'**
  String get ctrListFilterTooltip;

  /// No description provided for @ctrListResultCount.
  ///
  /// In vi, this message translates to:
  /// **'{count} đơn vị'**
  String ctrListResultCount(int count);

  /// No description provided for @ctrListEmptyWidenFilter.
  ///
  /// In vi, this message translates to:
  /// **'Nới bộ lọc'**
  String get ctrListEmptyWidenFilter;

  /// No description provided for @homeConstructionFilterTooltip.
  ///
  /// In vi, this message translates to:
  /// **'Lọc đơn vị xây dựng'**
  String get homeConstructionFilterTooltip;

  /// No description provided for @onboardingSkip.
  ///
  /// In vi, this message translates to:
  /// **'Bỏ qua'**
  String get onboardingSkip;

  /// No description provided for @onboardingNext.
  ///
  /// In vi, this message translates to:
  /// **'Tiếp theo'**
  String get onboardingNext;

  /// No description provided for @onboardingStart.
  ///
  /// In vi, this message translates to:
  /// **'Bắt đầu'**
  String get onboardingStart;

  /// No description provided for @onboardingHeroTitle.
  ///
  /// In vi, this message translates to:
  /// **'Chào mừng đến Vua Nhà'**
  String get onboardingHeroTitle;

  /// No description provided for @onboardingHeroSubtitle.
  ///
  /// In vi, this message translates to:
  /// **'Một ứng dụng, hai thế giới — Bất động sản và Xây dựng.'**
  String get onboardingHeroSubtitle;

  /// No description provided for @onboardingHeroCardReTitle.
  ///
  /// In vi, this message translates to:
  /// **'Bất động sản'**
  String get onboardingHeroCardReTitle;

  /// No description provided for @onboardingHeroCardReDesc.
  ///
  /// In vi, this message translates to:
  /// **'Tìm thuê, cho thuê, quản lý nhà trọ'**
  String get onboardingHeroCardReDesc;

  /// No description provided for @onboardingHeroCardBuildTitle.
  ///
  /// In vi, this message translates to:
  /// **'Xây dựng'**
  String get onboardingHeroCardBuildTitle;

  /// No description provided for @onboardingHeroCardBuildDesc.
  ///
  /// In vi, this message translates to:
  /// **'Thiết kế, thi công, nội thất, báo giá'**
  String get onboardingHeroCardBuildDesc;

  /// No description provided for @onboardingReTitle.
  ///
  /// In vi, this message translates to:
  /// **'Bất động sản trong tầm tay'**
  String get onboardingReTitle;

  /// No description provided for @onboardingReSubtitle.
  ///
  /// In vi, this message translates to:
  /// **'Tìm chỗ ở, cho thuê và quản lý — tất cả một nơi.'**
  String get onboardingReSubtitle;

  /// No description provided for @onboardingReSearch.
  ///
  /// In vi, this message translates to:
  /// **'Tìm nhà'**
  String get onboardingReSearch;

  /// No description provided for @onboardingReListings.
  ///
  /// In vi, this message translates to:
  /// **'Xem tin thuê'**
  String get onboardingReListings;

  /// No description provided for @onboardingRePost.
  ///
  /// In vi, this message translates to:
  /// **'Đăng cho thuê'**
  String get onboardingRePost;

  /// No description provided for @onboardingReBooking.
  ///
  /// In vi, this message translates to:
  /// **'Đặt lịch xem'**
  String get onboardingReBooking;

  /// No description provided for @onboardingReRooms.
  ///
  /// In vi, this message translates to:
  /// **'Nhà trọ, phòng trọ'**
  String get onboardingReRooms;

  /// No description provided for @onboardingReManage.
  ///
  /// In vi, this message translates to:
  /// **'Quản lý nhà trọ'**
  String get onboardingReManage;

  /// No description provided for @onboardingBuildTitle.
  ///
  /// In vi, this message translates to:
  /// **'Xây dựng từ ý tưởng đến hoàn thiện'**
  String get onboardingBuildTitle;

  /// No description provided for @onboardingBuildSubtitle.
  ///
  /// In vi, this message translates to:
  /// **'Ý tưởng, đơn vị thi công và báo giá — kết nối nhanh.'**
  String get onboardingBuildSubtitle;

  /// No description provided for @onboardingBuildDesign.
  ///
  /// In vi, this message translates to:
  /// **'Thiết kế'**
  String get onboardingBuildDesign;

  /// No description provided for @onboardingBuildInterior.
  ///
  /// In vi, this message translates to:
  /// **'Nội thất'**
  String get onboardingBuildInterior;

  /// No description provided for @onboardingBuildConstruct.
  ///
  /// In vi, this message translates to:
  /// **'Thi công'**
  String get onboardingBuildConstruct;

  /// No description provided for @onboardingBuildGallery.
  ///
  /// In vi, this message translates to:
  /// **'Mẫu nhà đẹp'**
  String get onboardingBuildGallery;

  /// No description provided for @onboardingBuildKnowledge.
  ///
  /// In vi, this message translates to:
  /// **'Kinh nghiệm xây dựng'**
  String get onboardingBuildKnowledge;

  /// No description provided for @onboardingBuildRfq.
  ///
  /// In vi, this message translates to:
  /// **'Đăng yêu cầu báo giá'**
  String get onboardingBuildRfq;

  /// No description provided for @onboardingBuildCaption.
  ///
  /// In vi, this message translates to:
  /// **'Kèm danh bạ đơn vị & bảng xếp hạng'**
  String get onboardingBuildCaption;

  /// No description provided for @leadSheetTitle.
  ///
  /// In vi, this message translates to:
  /// **'Để lại thông tin, chúng tôi gọi lại'**
  String get leadSheetTitle;

  /// No description provided for @leadSheetSubtitle.
  ///
  /// In vi, this message translates to:
  /// **'Chỉ cần Tên và số điện thoại — không cần đăng nhập.'**
  String get leadSheetSubtitle;

  /// No description provided for @leadFieldName.
  ///
  /// In vi, this message translates to:
  /// **'Họ tên'**
  String get leadFieldName;

  /// No description provided for @leadFieldPhone.
  ///
  /// In vi, this message translates to:
  /// **'Số điện thoại'**
  String get leadFieldPhone;

  /// No description provided for @leadFieldNote.
  ///
  /// In vi, this message translates to:
  /// **'Ghi chú (tuỳ chọn)'**
  String get leadFieldNote;

  /// No description provided for @leadSubmit.
  ///
  /// In vi, this message translates to:
  /// **'Gửi'**
  String get leadSubmit;

  /// No description provided for @leadValidation.
  ///
  /// In vi, this message translates to:
  /// **'Vui lòng nhập tên và số điện thoại hợp lệ.'**
  String get leadValidation;

  /// No description provided for @leadSendError.
  ///
  /// In vi, this message translates to:
  /// **'Gửi không thành công, bạn thử lại giúp mình nhé.'**
  String get leadSendError;

  /// No description provided for @leadSuccessTitle.
  ///
  /// In vi, this message translates to:
  /// **'Đã nhận thông tin!'**
  String get leadSuccessTitle;

  /// No description provided for @leadSuccessBody.
  ///
  /// In vi, this message translates to:
  /// **'Chúng tôi sẽ liên hệ với bạn sớm.'**
  String get leadSuccessBody;

  /// No description provided for @leadClose.
  ///
  /// In vi, this message translates to:
  /// **'Đóng'**
  String get leadClose;

  /// No description provided for @guestGateLeaveContact.
  ///
  /// In vi, this message translates to:
  /// **'Để lại SĐT, chúng tôi gọi lại'**
  String get guestGateLeaveContact;

  /// No description provided for @adminLeadsTitle.
  ///
  /// In vi, this message translates to:
  /// **'Lead gọi lại'**
  String get adminLeadsTitle;

  /// No description provided for @adminLeadsEmpty.
  ///
  /// In vi, this message translates to:
  /// **'Chưa có lead nào.'**
  String get adminLeadsEmpty;

  /// No description provided for @hubGuest.
  ///
  /// In vi, this message translates to:
  /// **'Khách'**
  String get hubGuest;

  /// No description provided for @hubSearchHint.
  ///
  /// In vi, this message translates to:
  /// **'Nhập từ khoá, khu vực, dự án...'**
  String get hubSearchHint;

  /// No description provided for @hubBannerTitle.
  ///
  /// In vi, this message translates to:
  /// **'Vua Nhà — Tìm đúng nhà, sống đúng chất'**
  String get hubBannerTitle;

  /// No description provided for @hubBannerSubtitle.
  ///
  /// In vi, this message translates to:
  /// **'Mua bán, cho thuê, đăng tin dễ dàng với hàng ngàn bất động sản mới mỗi ngày'**
  String get hubBannerSubtitle;

  /// No description provided for @hubNeedTitle.
  ///
  /// In vi, this message translates to:
  /// **'Tôi đang cần'**
  String get hubNeedTitle;

  /// No description provided for @hubNeedSubtitle.
  ///
  /// In vi, this message translates to:
  /// **'Tìm nhà thuê · mua · đăng tin bán'**
  String get hubNeedSubtitle;

  /// No description provided for @hubHaveTitle.
  ///
  /// In vi, this message translates to:
  /// **'Tôi có nhà cho thuê'**
  String get hubHaveTitle;

  /// No description provided for @hubHaveSubtitle.
  ///
  /// In vi, this message translates to:
  /// **'Đăng tin, chọn khách trong ngày'**
  String get hubHaveSubtitle;

  /// No description provided for @demandChooserTitle.
  ///
  /// In vi, this message translates to:
  /// **'Bạn muốn đăng gì?'**
  String get demandChooserTitle;

  /// No description provided for @demandChooserHave.
  ///
  /// In vi, this message translates to:
  /// **'TÔI CÓ BẤT ĐỘNG SẢN'**
  String get demandChooserHave;

  /// No description provided for @demandChooserNeed.
  ///
  /// In vi, this message translates to:
  /// **'TÔI ĐANG TÌM'**
  String get demandChooserNeed;

  /// No description provided for @demandChooserPostRent.
  ///
  /// In vi, this message translates to:
  /// **'Đăng tin cho thuê'**
  String get demandChooserPostRent;

  /// No description provided for @demandChooserPostSale.
  ///
  /// In vi, this message translates to:
  /// **'Đăng tin bán'**
  String get demandChooserPostSale;

  /// No description provided for @demandChooserNeedRent.
  ///
  /// In vi, this message translates to:
  /// **'Tôi cần thuê'**
  String get demandChooserNeedRent;

  /// No description provided for @demandChooserNeedBuy.
  ///
  /// In vi, this message translates to:
  /// **'Tôi cần mua'**
  String get demandChooserNeedBuy;

  /// No description provided for @demandChooserHaveHint.
  ///
  /// In vi, this message translates to:
  /// **'Đăng một bất động sản có thật: địa chỉ, ảnh, giá.'**
  String get demandChooserHaveHint;

  /// No description provided for @demandChooserNeedHint.
  ///
  /// In vi, this message translates to:
  /// **'Nói bạn đang tìm gì — không cần ảnh, xong trong 30 giây.'**
  String get demandChooserNeedHint;

  /// No description provided for @demandFormTitleRent.
  ///
  /// In vi, this message translates to:
  /// **'Tôi cần thuê'**
  String get demandFormTitleRent;

  /// No description provided for @demandFormTitleBuy.
  ///
  /// In vi, this message translates to:
  /// **'Tôi cần mua'**
  String get demandFormTitleBuy;

  /// No description provided for @demandSecArea.
  ///
  /// In vi, this message translates to:
  /// **'Khu vực mong muốn'**
  String get demandSecArea;

  /// No description provided for @demandSecType.
  ///
  /// In vi, this message translates to:
  /// **'Loại hình mong muốn'**
  String get demandSecType;

  /// No description provided for @demandSecBudget.
  ///
  /// In vi, this message translates to:
  /// **'Ngân sách'**
  String get demandSecBudget;

  /// No description provided for @demandSecMore.
  ///
  /// In vi, this message translates to:
  /// **'Thêm vài chi tiết (tuỳ chọn)'**
  String get demandSecMore;

  /// No description provided for @demandProvinceHint.
  ///
  /// In vi, this message translates to:
  /// **'Chọn tỉnh/thành'**
  String get demandProvinceHint;

  /// No description provided for @demandBudgetFrom.
  ///
  /// In vi, this message translates to:
  /// **'Từ'**
  String get demandBudgetFrom;

  /// No description provided for @demandBudgetTo.
  ///
  /// In vi, this message translates to:
  /// **'Đến'**
  String get demandBudgetTo;

  /// No description provided for @demandBudgetUnitRent.
  ///
  /// In vi, this message translates to:
  /// **'triệu/tháng'**
  String get demandBudgetUnitRent;

  /// No description provided for @demandBudgetUnitBuy.
  ///
  /// In vi, this message translates to:
  /// **'tỷ'**
  String get demandBudgetUnitBuy;

  /// No description provided for @demandAreaMin.
  ///
  /// In vi, this message translates to:
  /// **'Diện tích tối thiểu (m²)'**
  String get demandAreaMin;

  /// No description provided for @demandBedroomsMin.
  ///
  /// In vi, this message translates to:
  /// **'Số phòng ngủ tối thiểu'**
  String get demandBedroomsMin;

  /// No description provided for @demandMoveIn.
  ///
  /// In vi, this message translates to:
  /// **'Thời điểm dọn vào'**
  String get demandMoveIn;

  /// No description provided for @demandDuration.
  ///
  /// In vi, this message translates to:
  /// **'Thuê trong (tháng)'**
  String get demandDuration;

  /// No description provided for @demandOccupants.
  ///
  /// In vi, this message translates to:
  /// **'Số người ở'**
  String get demandOccupants;

  /// No description provided for @demandPayment.
  ///
  /// In vi, this message translates to:
  /// **'Thanh toán'**
  String get demandPayment;

  /// No description provided for @demandPaymentCash.
  ///
  /// In vi, this message translates to:
  /// **'Tiền mặt'**
  String get demandPaymentCash;

  /// No description provided for @demandPaymentLoan.
  ///
  /// In vi, this message translates to:
  /// **'Cần vay'**
  String get demandPaymentLoan;

  /// No description provided for @demandPurpose.
  ///
  /// In vi, this message translates to:
  /// **'Mục đích'**
  String get demandPurpose;

  /// No description provided for @demandPurposeLive.
  ///
  /// In vi, this message translates to:
  /// **'Để ở'**
  String get demandPurposeLive;

  /// No description provided for @demandPurposeInvest.
  ///
  /// In vi, this message translates to:
  /// **'Đầu tư'**
  String get demandPurposeInvest;

  /// No description provided for @demandNeeds.
  ///
  /// In vi, this message translates to:
  /// **'Yêu cầu bắt buộc'**
  String get demandNeeds;

  /// No description provided for @demandNeedParking.
  ///
  /// In vi, this message translates to:
  /// **'Chỗ để xe'**
  String get demandNeedParking;

  /// No description provided for @demandNeedFreeHours.
  ///
  /// In vi, this message translates to:
  /// **'Giờ tự do'**
  String get demandNeedFreeHours;

  /// No description provided for @demandNeedAircon.
  ///
  /// In vi, this message translates to:
  /// **'Máy lạnh'**
  String get demandNeedAircon;

  /// No description provided for @demandNeedPrivate.
  ///
  /// In vi, this message translates to:
  /// **'Không chung chủ'**
  String get demandNeedPrivate;

  /// No description provided for @demandNeedPet.
  ///
  /// In vi, this message translates to:
  /// **'Nuôi thú cưng'**
  String get demandNeedPet;

  /// No description provided for @demandNeedBalcony.
  ///
  /// In vi, this message translates to:
  /// **'Ban công'**
  String get demandNeedBalcony;

  /// No description provided for @demandNote.
  ///
  /// In vi, this message translates to:
  /// **'Mô tả thêm'**
  String get demandNote;

  /// No description provided for @demandNoteHint.
  ///
  /// In vi, this message translates to:
  /// **'Ví dụ: cần gần trường học, ưu tiên tầng thấp…'**
  String get demandNoteHint;

  /// No description provided for @demandSubmit.
  ///
  /// In vi, this message translates to:
  /// **'Đăng tin nhu cầu'**
  String get demandSubmit;

  /// No description provided for @demandSubmitted.
  ///
  /// In vi, this message translates to:
  /// **'Đã đăng. Tin có hiệu lực 30 ngày.'**
  String get demandSubmitted;

  /// No description provided for @demandListTitle.
  ///
  /// In vi, this message translates to:
  /// **'Tin nhu cầu'**
  String get demandListTitle;

  /// No description provided for @demandTabAll.
  ///
  /// In vi, this message translates to:
  /// **'Tất cả'**
  String get demandTabAll;

  /// No description provided for @demandTabRent.
  ///
  /// In vi, this message translates to:
  /// **'Cần thuê'**
  String get demandTabRent;

  /// No description provided for @demandTabBuy.
  ///
  /// In vi, this message translates to:
  /// **'Cần mua'**
  String get demandTabBuy;

  /// No description provided for @demandTabMine.
  ///
  /// In vi, this message translates to:
  /// **'Tin của tôi'**
  String get demandTabMine;

  /// No description provided for @demandEmpty.
  ///
  /// In vi, this message translates to:
  /// **'Chưa có tin nhu cầu nào.'**
  String get demandEmpty;

  /// No description provided for @demandEmptyMine.
  ///
  /// In vi, this message translates to:
  /// **'Bạn chưa đăng tin nhu cầu nào.'**
  String get demandEmptyMine;

  /// No description provided for @demandExpired.
  ///
  /// In vi, this message translates to:
  /// **'Đã hết hạn'**
  String get demandExpired;

  /// No description provided for @demandClosed.
  ///
  /// In vi, this message translates to:
  /// **'Đã đóng'**
  String get demandClosed;

  /// No description provided for @demandActionClose.
  ///
  /// In vi, this message translates to:
  /// **'Đóng tin'**
  String get demandActionClose;

  /// No description provided for @demandActionExtend.
  ///
  /// In vi, this message translates to:
  /// **'Gia hạn 30 ngày'**
  String get demandActionExtend;

  /// No description provided for @demandContact.
  ///
  /// In vi, this message translates to:
  /// **'Nhắn tin'**
  String get demandContact;

  /// No description provided for @demandDaysLeft.
  ///
  /// In vi, this message translates to:
  /// **'Còn {days} ngày'**
  String demandDaysLeft(int days);

  /// No description provided for @demandNeedLogin.
  ///
  /// In vi, this message translates to:
  /// **'Đăng nhập để đăng tin nhu cầu'**
  String get demandNeedLogin;

  /// No description provided for @demandPickTypeFirst.
  ///
  /// In vi, this message translates to:
  /// **'Hãy chọn ít nhất một loại hình'**
  String get demandPickTypeFirst;

  /// No description provided for @svcCatalogTitle.
  ///
  /// In vi, this message translates to:
  /// **'Dịch vụ nhà cửa'**
  String get svcCatalogTitle;

  /// No description provided for @svcGroupQuick.
  ///
  /// In vi, this message translates to:
  /// **'Thợ & dịch vụ nhanh'**
  String get svcGroupQuick;

  /// No description provided for @svcGroupBuild.
  ///
  /// In vi, this message translates to:
  /// **'Thiết kế · Xây dựng'**
  String get svcGroupBuild;

  /// No description provided for @svcQuickHint.
  ///
  /// In vi, this message translates to:
  /// **'Gửi yêu cầu, Vua Nhà gọi lại và xếp thợ giúp bạn.'**
  String get svcQuickHint;

  /// No description provided for @svcBookNow.
  ///
  /// In vi, this message translates to:
  /// **'Đặt dịch vụ · {serviceName}'**
  String svcBookNow(String serviceName);

  /// No description provided for @svcBookedBody.
  ///
  /// In vi, this message translates to:
  /// **'Chúng tôi sẽ gọi lại để xác nhận và xếp lịch thợ.'**
  String get svcBookedBody;

  /// No description provided for @svcReqTitle.
  ///
  /// In vi, this message translates to:
  /// **'Yêu cầu dịch vụ'**
  String get svcReqTitle;

  /// No description provided for @svcReqEmpty.
  ///
  /// In vi, this message translates to:
  /// **'Chưa có yêu cầu nào.'**
  String get svcReqEmpty;

  /// No description provided for @svcReqFilterAll.
  ///
  /// In vi, this message translates to:
  /// **'Tất cả'**
  String get svcReqFilterAll;

  /// No description provided for @svcReqFilterNew.
  ///
  /// In vi, this message translates to:
  /// **'Mới'**
  String get svcReqFilterNew;

  /// No description provided for @svcReqFilterDoing.
  ///
  /// In vi, this message translates to:
  /// **'Đang xử lý'**
  String get svcReqFilterDoing;

  /// No description provided for @svcReqFilterDone.
  ///
  /// In vi, this message translates to:
  /// **'Xong'**
  String get svcReqFilterDone;

  /// No description provided for @svcReqSearchHint.
  ///
  /// In vi, this message translates to:
  /// **'Tìm theo SĐT hoặc tên'**
  String get svcReqSearchHint;

  /// No description provided for @svcReqCall.
  ///
  /// In vi, this message translates to:
  /// **'Gọi'**
  String get svcReqCall;

  /// No description provided for @svcReqSchedule.
  ///
  /// In vi, this message translates to:
  /// **'Xếp lịch'**
  String get svcReqSchedule;

  /// No description provided for @svcReqNote.
  ///
  /// In vi, this message translates to:
  /// **'Ghi chú của admin'**
  String get svcReqNote;

  /// No description provided for @svcReqSave.
  ///
  /// In vi, this message translates to:
  /// **'Lưu'**
  String get svcReqSave;

  /// No description provided for @svcReqSaved.
  ///
  /// In vi, this message translates to:
  /// **'Đã lưu'**
  String get svcReqSaved;

  /// No description provided for @svcStatusNew.
  ///
  /// In vi, this message translates to:
  /// **'Mới'**
  String get svcStatusNew;

  /// No description provided for @svcStatusContacted.
  ///
  /// In vi, this message translates to:
  /// **'Đã liên hệ'**
  String get svcStatusContacted;

  /// No description provided for @svcStatusScheduled.
  ///
  /// In vi, this message translates to:
  /// **'Đã xếp lịch'**
  String get svcStatusScheduled;

  /// No description provided for @svcStatusDone.
  ///
  /// In vi, this message translates to:
  /// **'Hoàn thành'**
  String get svcStatusDone;

  /// No description provided for @svcStatusCancelled.
  ///
  /// In vi, this message translates to:
  /// **'Đã huỷ'**
  String get svcStatusCancelled;

  /// No description provided for @svcStatusSpam.
  ///
  /// In vi, this message translates to:
  /// **'Rác'**
  String get svcStatusSpam;

  /// No description provided for @hubActionTrade.
  ///
  /// In vi, this message translates to:
  /// **'Mua bán · Cho thuê'**
  String get hubActionTrade;

  /// No description provided for @hubActionPost.
  ///
  /// In vi, this message translates to:
  /// **'Đăng tin nhu cầu'**
  String get hubActionPost;

  /// No description provided for @hubActionPlanning.
  ///
  /// In vi, this message translates to:
  /// **'Thông tin và quy hoạch'**
  String get hubActionPlanning;

  /// No description provided for @hubActionServices.
  ///
  /// In vi, this message translates to:
  /// **'Dịch vụ'**
  String get hubActionServices;

  /// No description provided for @hubRowBrokers.
  ///
  /// In vi, this message translates to:
  /// **'Môi giới giỏi'**
  String get hubRowBrokers;

  /// No description provided for @hubRowOwners.
  ///
  /// In vi, this message translates to:
  /// **'Chủ nhà tự đăng'**
  String get hubRowOwners;

  /// No description provided for @hubActionLease.
  ///
  /// In vi, this message translates to:
  /// **'Cho thuê'**
  String get hubActionLease;

  /// No description provided for @hubActionRent.
  ///
  /// In vi, this message translates to:
  /// **'Cần thuê'**
  String get hubActionRent;

  /// No description provided for @hubActionSell.
  ///
  /// In vi, this message translates to:
  /// **'Cần bán'**
  String get hubActionSell;

  /// No description provided for @hubActionBuy.
  ///
  /// In vi, this message translates to:
  /// **'Cần mua'**
  String get hubActionBuy;

  /// No description provided for @hubFeaturedUnits.
  ///
  /// In vi, this message translates to:
  /// **'Đơn vị tiêu biểu'**
  String get hubFeaturedUnits;

  /// No description provided for @hubServiceUnits.
  ///
  /// In vi, this message translates to:
  /// **'Đơn vị dịch vụ'**
  String get hubServiceUnits;

  /// No description provided for @hubHighlights.
  ///
  /// In vi, this message translates to:
  /// **'Tin nổi bật'**
  String get hubHighlights;

  /// No description provided for @hubViewAll.
  ///
  /// In vi, this message translates to:
  /// **'Xem tất cả'**
  String get hubViewAll;

  /// No description provided for @hubNotifications.
  ///
  /// In vi, this message translates to:
  /// **'Thông báo'**
  String get hubNotifications;

  /// No description provided for @shellNavHome.
  ///
  /// In vi, this message translates to:
  /// **'Trang chủ'**
  String get shellNavHome;

  /// No description provided for @hubFeaturedBrokers.
  ///
  /// In vi, this message translates to:
  /// **'Môi giới tiêu biểu'**
  String get hubFeaturedBrokers;

  /// No description provided for @brokerProfileTitle.
  ///
  /// In vi, this message translates to:
  /// **'Hồ sơ môi giới'**
  String get brokerProfileTitle;

  /// No description provided for @brokerNotFound.
  ///
  /// In vi, this message translates to:
  /// **'Không tìm thấy hồ sơ này.'**
  String get brokerNotFound;

  /// No description provided for @brokerListings.
  ///
  /// In vi, this message translates to:
  /// **'Tin đang đăng'**
  String get brokerListings;

  /// No description provided for @brokerNoListings.
  ///
  /// In vi, this message translates to:
  /// **'Chưa có tin nào đang hiển thị.'**
  String get brokerNoListings;

  /// No description provided for @brokerListingCount.
  ///
  /// In vi, this message translates to:
  /// **'{count} tin đang đăng'**
  String brokerListingCount(int count);

  /// No description provided for @brokerReviewCount.
  ///
  /// In vi, this message translates to:
  /// **'{count} đánh giá'**
  String brokerReviewCount(int count);

  /// No description provided for @brokerStatListings.
  ///
  /// In vi, this message translates to:
  /// **'Tin đăng'**
  String get brokerStatListings;

  /// No description provided for @brokerStatAreas.
  ///
  /// In vi, this message translates to:
  /// **'Khu vực'**
  String get brokerStatAreas;

  /// No description provided for @brokerStatReviews.
  ///
  /// In vi, this message translates to:
  /// **'Đánh giá'**
  String get brokerStatReviews;

  /// No description provided for @brokerStatYears.
  ///
  /// In vi, this message translates to:
  /// **'Năm'**
  String get brokerStatYears;

  /// No description provided for @brokerMapTitle.
  ///
  /// In vi, this message translates to:
  /// **'Bản đồ điểm chốt'**
  String get brokerMapTitle;

  /// No description provided for @brokerReviewsTitle.
  ///
  /// In vi, this message translates to:
  /// **'Nhận xét khách hàng'**
  String get brokerReviewsTitle;

  /// No description provided for @mapLegendTitle.
  ///
  /// In vi, this message translates to:
  /// **'Chú giải'**
  String get mapLegendTitle;

  /// No description provided for @mapLegendSale.
  ///
  /// In vi, this message translates to:
  /// **'Tin bán'**
  String get mapLegendSale;

  /// No description provided for @mapLegendStayLong.
  ///
  /// In vi, this message translates to:
  /// **'Cho thuê · dài hạn'**
  String get mapLegendStayLong;

  /// No description provided for @mapLegendStayShort.
  ///
  /// In vi, this message translates to:
  /// **'Cho thuê · ngắn hạn'**
  String get mapLegendStayShort;

  /// No description provided for @mapLegendBusiness.
  ///
  /// In vi, this message translates to:
  /// **'Cho thuê · kinh doanh'**
  String get mapLegendBusiness;

  /// No description provided for @postGroupStep.
  ///
  /// In vi, this message translates to:
  /// **'Nhóm bất động sản'**
  String get postGroupStep;

  /// No description provided for @postTypeStep.
  ///
  /// In vi, this message translates to:
  /// **'Loại hình'**
  String get postTypeStep;

  /// No description provided for @postGroupStayLong.
  ///
  /// In vi, this message translates to:
  /// **'Lưu trú dài hạn'**
  String get postGroupStayLong;

  /// No description provided for @postGroupStayShort.
  ///
  /// In vi, this message translates to:
  /// **'Lưu trú ngắn hạn'**
  String get postGroupStayShort;

  /// No description provided for @postGroupBusiness.
  ///
  /// In vi, this message translates to:
  /// **'Kinh doanh'**
  String get postGroupBusiness;

  /// No description provided for @postPickGroupFirst.
  ///
  /// In vi, this message translates to:
  /// **'Chọn nhóm trước'**
  String get postPickGroupFirst;

  /// No description provided for @brokerShare.
  ///
  /// In vi, this message translates to:
  /// **'Chia sẻ hồ sơ'**
  String get brokerShare;

  /// No description provided for @brokerShareCopied.
  ///
  /// In vi, this message translates to:
  /// **'Đã sao chép liên kết hồ sơ'**
  String get brokerShareCopied;

  /// No description provided for @pfBasicInfo.
  ///
  /// In vi, this message translates to:
  /// **'Thông tin cơ bản'**
  String get pfBasicInfo;

  /// No description provided for @pfBasicHelper.
  ///
  /// In vi, this message translates to:
  /// **'Đây là tên và mô tả khách nhìn thấy đầu tiên.'**
  String get pfBasicHelper;

  /// No description provided for @pfContact.
  ///
  /// In vi, this message translates to:
  /// **'Liên hệ'**
  String get pfContact;

  /// No description provided for @pfContactHelper.
  ///
  /// In vi, this message translates to:
  /// **'Khách bấm gọi trực tiếp từ hồ sơ của bạn.'**
  String get pfContactHelper;

  /// No description provided for @pfCapacity.
  ///
  /// In vi, this message translates to:
  /// **'Năng lực'**
  String get pfCapacity;

  /// No description provided for @pfCapacityHelper.
  ///
  /// In vi, this message translates to:
  /// **'Khách nhìn phần này để đánh giá bạn có làm nổi việc không.'**
  String get pfCapacityHelper;

  /// No description provided for @pfDocs.
  ///
  /// In vi, this message translates to:
  /// **'Giấy tờ & xác minh'**
  String get pfDocs;

  /// No description provided for @pfDocsHelper.
  ///
  /// In vi, this message translates to:
  /// **'Hồ sơ có giấy tờ được duyệt sẽ hiện huy hiệu và xếp trên trong danh bạ.'**
  String get pfDocsHelper;

  /// No description provided for @pfNameHint.
  ///
  /// In vi, this message translates to:
  /// **'VD: Nhà thầu Minh Phát'**
  String get pfNameHint;

  /// No description provided for @pfIntroHint.
  ///
  /// In vi, this message translates to:
  /// **'Bạn làm gì, ở khu vực nào, thế mạnh là gì?'**
  String get pfIntroHint;

  /// No description provided for @pfPhoneHint.
  ///
  /// In vi, this message translates to:
  /// **'09xx xxx xxx'**
  String get pfPhoneHint;

  /// No description provided for @pfPhoneInvalid.
  ///
  /// In vi, this message translates to:
  /// **'Số điện thoại không hợp lệ'**
  String get pfPhoneInvalid;

  /// No description provided for @pfWebHint.
  ///
  /// In vi, this message translates to:
  /// **'facebook.com/... hoặc website'**
  String get pfWebHint;

  /// No description provided for @pfCertHint.
  ///
  /// In vi, this message translates to:
  /// **'Nhập nếu bạn có chứng chỉ hành nghề'**
  String get pfCertHint;

  /// No description provided for @pfUnitScale.
  ///
  /// In vi, this message translates to:
  /// **'Quy mô đơn vị'**
  String get pfUnitScale;

  /// No description provided for @pfChangeCover.
  ///
  /// In vi, this message translates to:
  /// **'Đổi ảnh bìa'**
  String get pfChangeCover;

  /// No description provided for @pfPickPrefix.
  ///
  /// In vi, this message translates to:
  /// **'Chọn {field}'**
  String pfPickPrefix(String field);

  /// No description provided for @pfEstablishedYear.
  ///
  /// In vi, this message translates to:
  /// **'Năm thành lập: {year}'**
  String pfEstablishedYear(String year);

  /// No description provided for @pfEstVerified.
  ///
  /// In vi, this message translates to:
  /// **'Đã xác minh bằng giấy tờ'**
  String get pfEstVerified;

  /// No description provided for @pfEstPending.
  ///
  /// In vi, this message translates to:
  /// **'Đang chờ duyệt'**
  String get pfEstPending;

  /// No description provided for @pfEstPendingHint.
  ///
  /// In vi, this message translates to:
  /// **'Quản trị viên đang đối chiếu giấy tờ'**
  String get pfEstPendingHint;

  /// No description provided for @pfEstRejected.
  ///
  /// In vi, this message translates to:
  /// **'Chưa đạt'**
  String get pfEstRejected;

  /// No description provided for @pfEstRejectedHint.
  ///
  /// In vi, this message translates to:
  /// **'Chạm để xem lý do và nộp lại'**
  String get pfEstRejectedHint;

  /// No description provided for @pfEstNone.
  ///
  /// In vi, this message translates to:
  /// **'Chưa xác minh năm thành lập'**
  String get pfEstNone;

  /// No description provided for @pfEstNoneHint.
  ///
  /// In vi, this message translates to:
  /// **'Chạm để nộp giấy chứng nhận ĐKDN'**
  String get pfEstNoneHint;

  /// No description provided for @pfDiscardTitle.
  ///
  /// In vi, this message translates to:
  /// **'Bỏ thay đổi?'**
  String get pfDiscardTitle;

  /// No description provided for @pfDiscardBody.
  ///
  /// In vi, this message translates to:
  /// **'Bạn đã sửa hồ sơ nhưng chưa lưu. Thoát bây giờ sẽ mất các thay đổi đó.'**
  String get pfDiscardBody;

  /// No description provided for @pfKeepEditing.
  ///
  /// In vi, this message translates to:
  /// **'Tiếp tục sửa'**
  String get pfKeepEditing;

  /// No description provided for @pfDiscard.
  ///
  /// In vi, this message translates to:
  /// **'Bỏ thay đổi'**
  String get pfDiscard;

  /// No description provided for @pfScaleCorporation.
  ///
  /// In vi, this message translates to:
  /// **'Tập đoàn lớn'**
  String get pfScaleCorporation;

  /// No description provided for @pfScaleMedium.
  ///
  /// In vi, this message translates to:
  /// **'Công ty vừa'**
  String get pfScaleMedium;

  /// No description provided for @pfScaleSmall.
  ///
  /// In vi, this message translates to:
  /// **'Công ty nhỏ'**
  String get pfScaleSmall;

  /// No description provided for @pfScaleCrew.
  ///
  /// In vi, this message translates to:
  /// **'Đội thi công'**
  String get pfScaleCrew;

  /// No description provided for @pfScaleIndividual.
  ///
  /// In vi, this message translates to:
  /// **'Cá nhân nhận thầu'**
  String get pfScaleIndividual;

  /// No description provided for @pfScaleArchitect.
  ///
  /// In vi, this message translates to:
  /// **'KTS / nhóm KTS'**
  String get pfScaleArchitect;

  /// No description provided for @pfScaleSpecialist.
  ///
  /// In vi, this message translates to:
  /// **'Nhà thầu chuyên biệt'**
  String get pfScaleSpecialist;

  /// No description provided for @sellerStep.
  ///
  /// In vi, this message translates to:
  /// **'Bạn đăng tin này với vai trò gì?'**
  String get sellerStep;

  /// No description provided for @sellerStepHelper.
  ///
  /// In vi, this message translates to:
  /// **'Khách rất quan tâm điều này. Thông tin do bạn tự khai, Vua Nhà chưa xác minh giấy tờ.'**
  String get sellerStepHelper;

  /// No description provided for @sellerOwner.
  ///
  /// In vi, this message translates to:
  /// **'Chủ nhà tự đăng'**
  String get sellerOwner;

  /// No description provided for @sellerOwnerDesc.
  ///
  /// In vi, this message translates to:
  /// **'Nhà của chính bạn'**
  String get sellerOwnerDesc;

  /// No description provided for @sellerBroker.
  ///
  /// In vi, this message translates to:
  /// **'Đăng hộ / môi giới'**
  String get sellerBroker;

  /// No description provided for @sellerBrokerDesc.
  ///
  /// In vi, this message translates to:
  /// **'Bạn đăng giúp chủ nhà'**
  String get sellerBrokerDesc;

  /// No description provided for @sellerRequired.
  ///
  /// In vi, this message translates to:
  /// **'Vui lòng chọn vai trò'**
  String get sellerRequired;

  /// No description provided for @sellerBadgeOwner.
  ///
  /// In vi, this message translates to:
  /// **'Chủ nhà tự đăng (tự khai)'**
  String get sellerBadgeOwner;

  /// No description provided for @sellerBadgeBroker.
  ///
  /// In vi, this message translates to:
  /// **'Môi giới (tự khai)'**
  String get sellerBadgeBroker;

  /// No description provided for @hubFeaturedSellers.
  ///
  /// In vi, this message translates to:
  /// **'Người bán tiêu biểu'**
  String get hubFeaturedSellers;

  /// No description provided for @brokerMapExpand.
  ///
  /// In vi, this message translates to:
  /// **'Mở rộng'**
  String get brokerMapExpand;

  /// No description provided for @brokerMapHint.
  ///
  /// In vi, this message translates to:
  /// **'Chạm ghim để mở tin · kéo và chụm 2 ngón để phóng to'**
  String get brokerMapHint;

  /// No description provided for @brokerMapHintShort.
  ///
  /// In vi, this message translates to:
  /// **'Chụm 2 ngón hoặc bấm +/− để phóng to · chạm ghim để mở tin'**
  String get brokerMapHintShort;

  /// No description provided for @planningScreenTitle.
  ///
  /// In vi, this message translates to:
  /// **'Thông tin và quy hoạch'**
  String get planningScreenTitle;

  /// No description provided for @planningCheckAction.
  ///
  /// In vi, this message translates to:
  /// **'Thông tin và quy hoạch'**
  String get planningCheckAction;

  /// No description provided for @planningTabShort.
  ///
  /// In vi, this message translates to:
  /// **'Quy hoạch'**
  String get planningTabShort;

  /// No description provided for @planningLayerToggle.
  ///
  /// In vi, this message translates to:
  /// **'Lớp quy hoạch SDĐ 2030'**
  String get planningLayerToggle;

  /// No description provided for @planningOpacityLabel.
  ///
  /// In vi, this message translates to:
  /// **'Độ trong suốt'**
  String get planningOpacityLabel;

  /// No description provided for @planningZoneLegendTitle.
  ///
  /// In vi, this message translates to:
  /// **'Chú giải quy hoạch'**
  String get planningZoneLegendTitle;

  /// No description provided for @planningZoneLegendEmpty.
  ///
  /// In vi, this message translates to:
  /// **'Phóng to để xem loại đất trong khu vực'**
  String get planningZoneLegendEmpty;

  /// No description provided for @planningZoneLegendRasterNote.
  ///
  /// In vi, this message translates to:
  /// **'Chú giải theo nguồn của tỉnh · chạm vào thửa để xem chi tiết'**
  String get planningZoneLegendRasterNote;

  /// No description provided for @planningZoneLegendOther.
  ///
  /// In vi, this message translates to:
  /// **'Loại khác'**
  String get planningZoneLegendOther;

  /// No description provided for @mapClusterTooltip.
  ///
  /// In vi, this message translates to:
  /// **'Chạm để tách cụm'**
  String get mapClusterTooltip;

  /// No description provided for @mapSearchHint.
  ///
  /// In vi, this message translates to:
  /// **'Tìm địa điểm'**
  String get mapSearchHint;

  /// No description provided for @mapZoomIn.
  ///
  /// In vi, this message translates to:
  /// **'Phóng to'**
  String get mapZoomIn;

  /// No description provided for @mapZoomOut.
  ///
  /// In vi, this message translates to:
  /// **'Thu nhỏ'**
  String get mapZoomOut;

  /// No description provided for @mapMyLocation.
  ///
  /// In vi, this message translates to:
  /// **'Vị trí của tôi'**
  String get mapMyLocation;

  /// No description provided for @mapLocationOff.
  ///
  /// In vi, this message translates to:
  /// **'Định vị đang tắt trên thiết bị'**
  String get mapLocationOff;

  /// No description provided for @mapLocationDenied.
  ///
  /// In vi, this message translates to:
  /// **'Chưa được cấp quyền vị trí'**
  String get mapLocationDenied;

  /// No description provided for @mapLocationOutside.
  ///
  /// In vi, this message translates to:
  /// **'Vị trí của bạn nằm ngoài Việt Nam'**
  String get mapLocationOutside;

  /// No description provided for @mapLocationError.
  ///
  /// In vi, this message translates to:
  /// **'Không lấy được vị trí, thử lại sau'**
  String get mapLocationError;

  /// No description provided for @mapSearchEmpty.
  ///
  /// In vi, this message translates to:
  /// **'Không tìm thấy địa điểm nào'**
  String get mapSearchEmpty;

  /// No description provided for @mapLegendHelp.
  ///
  /// In vi, this message translates to:
  /// **'Giải thích'**
  String get mapLegendHelp;

  /// No description provided for @mapLegendStayShortDesc.
  ///
  /// In vi, this message translates to:
  /// **'Thuê theo ngày hoặc vài hôm, phù hợp nghỉ ngơi, công tác, du lịch.'**
  String get mapLegendStayShortDesc;

  /// No description provided for @mapLegendStayLongDesc.
  ///
  /// In vi, this message translates to:
  /// **'Thuê theo tháng hoặc lâu dài, phù hợp để ở và sinh hoạt ổn định.'**
  String get mapLegendStayLongDesc;

  /// No description provided for @mapLegendBusinessDesc.
  ///
  /// In vi, this message translates to:
  /// **'Mặt bằng cho thuê để kinh doanh, buôn bán, làm văn phòng hoặc cửa hàng.'**
  String get mapLegendBusinessDesc;

  /// No description provided for @mapLegendSaleDesc.
  ///
  /// In vi, this message translates to:
  /// **'Mua hoặc bán bất động sản để sở hữu và sử dụng lâu dài.'**
  String get mapLegendSaleDesc;

  /// No description provided for @tradeTabBuy.
  ///
  /// In vi, this message translates to:
  /// **'Tìm nhà'**
  String get tradeTabBuy;

  /// No description provided for @tradeTabSell.
  ///
  /// In vi, this message translates to:
  /// **'Tìm khách'**
  String get tradeTabSell;

  /// No description provided for @tradeBuyHint.
  ///
  /// In vi, this message translates to:
  /// **'Nhà đang rao bán và cho thuê'**
  String get tradeBuyHint;

  /// No description provided for @tradeSellHint.
  ///
  /// In vi, this message translates to:
  /// **'Người đang cần mua, cần thuê — đăng tin để họ tìm thấy bạn'**
  String get tradeSellHint;

  /// No description provided for @tradeChipAll.
  ///
  /// In vi, this message translates to:
  /// **'Tất cả'**
  String get tradeChipAll;

  /// No description provided for @tradeChipSale.
  ///
  /// In vi, this message translates to:
  /// **'Bán'**
  String get tradeChipSale;

  /// No description provided for @tradeChipShort.
  ///
  /// In vi, this message translates to:
  /// **'Ngắn hạn'**
  String get tradeChipShort;

  /// No description provided for @tradeShortStaySearchTitle.
  ///
  /// In vi, this message translates to:
  /// **'Tìm phòng trống theo giờ'**
  String get tradeShortStaySearchTitle;

  /// No description provided for @tradeShortStaySearchSub.
  ///
  /// In vi, this message translates to:
  /// **'Theo giờ · qua đêm · theo ngày — xem giá và đặt ngay'**
  String get tradeShortStaySearchSub;

  /// No description provided for @tradeChipLong.
  ///
  /// In vi, this message translates to:
  /// **'Dài hạn'**
  String get tradeChipLong;

  /// No description provided for @tradeChipBusiness.
  ///
  /// In vi, this message translates to:
  /// **'Kinh doanh'**
  String get tradeChipBusiness;

  /// No description provided for @tradeChipNeedBuy.
  ///
  /// In vi, this message translates to:
  /// **'Cần mua'**
  String get tradeChipNeedBuy;

  /// No description provided for @tradeChipNeedRent.
  ///
  /// In vi, this message translates to:
  /// **'Cần thuê'**
  String get tradeChipNeedRent;

  /// No description provided for @tradeSearchHint.
  ///
  /// In vi, this message translates to:
  /// **'Tìm theo tiêu đề, khu vực'**
  String get tradeSearchHint;

  /// No description provided for @tradeFilter.
  ///
  /// In vi, this message translates to:
  /// **'Bộ lọc'**
  String get tradeFilter;

  /// No description provided for @tradeFilterTitle.
  ///
  /// In vi, this message translates to:
  /// **'Lọc kết quả'**
  String get tradeFilterTitle;

  /// No description provided for @tradePriceRange.
  ///
  /// In vi, this message translates to:
  /// **'Khoảng giá'**
  String get tradePriceRange;

  /// No description provided for @tradeAreaFrom.
  ///
  /// In vi, this message translates to:
  /// **'Diện tích từ (m²)'**
  String get tradeAreaFrom;

  /// No description provided for @tradeBedrooms.
  ///
  /// In vi, this message translates to:
  /// **'Phòng ngủ'**
  String get tradeBedrooms;

  /// No description provided for @tradeApply.
  ///
  /// In vi, this message translates to:
  /// **'Áp dụng'**
  String get tradeApply;

  /// No description provided for @tradeClear.
  ///
  /// In vi, this message translates to:
  /// **'Xoá lọc'**
  String get tradeClear;

  /// No description provided for @tradeEmptyBuy.
  ///
  /// In vi, this message translates to:
  /// **'Chưa có tin nào khớp'**
  String get tradeEmptyBuy;

  /// No description provided for @tradeEmptySell.
  ///
  /// In vi, this message translates to:
  /// **'Chưa có nhu cầu nào khớp'**
  String get tradeEmptySell;

  /// No description provided for @tradeEmptyHint.
  ///
  /// In vi, this message translates to:
  /// **'Thử bỏ bớt bộ lọc hoặc đổi từ khoá.'**
  String get tradeEmptyHint;

  /// No description provided for @tradeResultCount.
  ///
  /// In vi, this message translates to:
  /// **'{n} kết quả'**
  String tradeResultCount(int n);

  /// No description provided for @tfTitle.
  ///
  /// In vi, this message translates to:
  /// **'Lọc kết quả'**
  String get tfTitle;

  /// No description provided for @tfPrice.
  ///
  /// In vi, this message translates to:
  /// **'Khoảng giá'**
  String get tfPrice;

  /// No description provided for @tfArea.
  ///
  /// In vi, this message translates to:
  /// **'Diện tích'**
  String get tfArea;

  /// No description provided for @tfBedrooms.
  ///
  /// In vi, this message translates to:
  /// **'Phòng ngủ'**
  String get tfBedrooms;

  /// No description provided for @tfSort.
  ///
  /// In vi, this message translates to:
  /// **'Sắp xếp'**
  String get tfSort;

  /// No description provided for @tfAny.
  ///
  /// In vi, this message translates to:
  /// **'Tất cả'**
  String get tfAny;

  /// No description provided for @tfAreaUnder.
  ///
  /// In vi, this message translates to:
  /// **'Dưới 30 m²'**
  String get tfAreaUnder;

  /// No description provided for @tfArea3050.
  ///
  /// In vi, this message translates to:
  /// **'30 – 50 m²'**
  String get tfArea3050;

  /// No description provided for @tfArea5080.
  ///
  /// In vi, this message translates to:
  /// **'50 – 80 m²'**
  String get tfArea5080;

  /// No description provided for @tfAreaOver.
  ///
  /// In vi, this message translates to:
  /// **'Trên 80 m²'**
  String get tfAreaOver;

  /// No description provided for @tfSortNewest.
  ///
  /// In vi, this message translates to:
  /// **'Mới nhất'**
  String get tfSortNewest;

  /// No description provided for @tfSortPriceAsc.
  ///
  /// In vi, this message translates to:
  /// **'Giá thấp → cao'**
  String get tfSortPriceAsc;

  /// No description provided for @tfSortPriceDesc.
  ///
  /// In vi, this message translates to:
  /// **'Giá cao → thấp'**
  String get tfSortPriceDesc;

  /// No description provided for @tfReset.
  ///
  /// In vi, this message translates to:
  /// **'Đặt lại'**
  String get tfReset;

  /// No description provided for @tfSeeCount.
  ///
  /// In vi, this message translates to:
  /// **'Xem {n} tin'**
  String tfSeeCount(int n);

  /// No description provided for @tfSeeNone.
  ///
  /// In vi, this message translates to:
  /// **'Không có tin nào khớp'**
  String get tfSeeNone;

  /// No description provided for @tfCounting.
  ///
  /// In vi, this message translates to:
  /// **'Đang đếm…'**
  String get tfCounting;

  /// No description provided for @tfBillion.
  ///
  /// In vi, this message translates to:
  /// **'tỷ'**
  String get tfBillion;

  /// No description provided for @tfMillion.
  ///
  /// In vi, this message translates to:
  /// **'triệu'**
  String get tfMillion;

  /// No description provided for @tfNoLimit.
  ///
  /// In vi, this message translates to:
  /// **'không giới hạn'**
  String get tfNoLimit;

  /// No description provided for @tfAdvanced.
  ///
  /// In vi, this message translates to:
  /// **'Lọc nâng cao'**
  String get tfAdvanced;

  /// No description provided for @tfPropertyType.
  ///
  /// In vi, this message translates to:
  /// **'Loại hình'**
  String get tfPropertyType;

  /// No description provided for @tfDirection.
  ///
  /// In vi, this message translates to:
  /// **'Hướng nhà (phong thuỷ)'**
  String get tfDirection;

  /// No description provided for @tfTrust.
  ///
  /// In vi, this message translates to:
  /// **'Uy tín & Chất lượng'**
  String get tfTrust;

  /// No description provided for @tfTrustedOnly.
  ///
  /// In vi, this message translates to:
  /// **'Chỉ hiện nhà uy tín'**
  String get tfTrustedOnly;

  /// No description provided for @tfMinRating.
  ///
  /// In vi, this message translates to:
  /// **'Điểm đánh giá tối thiểu'**
  String get tfMinRating;

  /// No description provided for @tfMinQuality.
  ///
  /// In vi, this message translates to:
  /// **'Sao chất lượng tối thiểu'**
  String get tfMinQuality;

  /// No description provided for @tfQualityStar.
  ///
  /// In vi, this message translates to:
  /// **'{n} sao'**
  String tfQualityStar(int n);

  /// No description provided for @tfSortTrust.
  ///
  /// In vi, this message translates to:
  /// **'Uy tín'**
  String get tfSortTrust;

  /// No description provided for @tfSortRating.
  ///
  /// In vi, this message translates to:
  /// **'Đánh giá cao'**
  String get tfSortRating;

  /// No description provided for @tfDirN.
  ///
  /// In vi, this message translates to:
  /// **'Bắc'**
  String get tfDirN;

  /// No description provided for @tfDirNE.
  ///
  /// In vi, this message translates to:
  /// **'Đông Bắc'**
  String get tfDirNE;

  /// No description provided for @tfDirE.
  ///
  /// In vi, this message translates to:
  /// **'Đông'**
  String get tfDirE;

  /// No description provided for @tfDirSE.
  ///
  /// In vi, this message translates to:
  /// **'Đông Nam'**
  String get tfDirSE;

  /// No description provided for @tfDirS.
  ///
  /// In vi, this message translates to:
  /// **'Nam'**
  String get tfDirS;

  /// No description provided for @tfDirSW.
  ///
  /// In vi, this message translates to:
  /// **'Tây Nam'**
  String get tfDirSW;

  /// No description provided for @tfDirW.
  ///
  /// In vi, this message translates to:
  /// **'Tây'**
  String get tfDirW;

  /// No description provided for @tfDirNW.
  ///
  /// In vi, this message translates to:
  /// **'Tây Bắc'**
  String get tfDirNW;

  /// No description provided for @reelSectionTitle.
  ///
  /// In vi, this message translates to:
  /// **'Reel nổi bật'**
  String get reelSectionTitle;

  /// No description provided for @reelSeeAll.
  ///
  /// In vi, this message translates to:
  /// **'Xem tất cả'**
  String get reelSeeAll;

  /// No description provided for @exploreTradeTitlePlain.
  ///
  /// In vi, this message translates to:
  /// **'Khám phá '**
  String get exploreTradeTitlePlain;

  /// No description provided for @exploreTradeTitleAccent.
  ///
  /// In vi, this message translates to:
  /// **'Mua bán · Cho thuê'**
  String get exploreTradeTitleAccent;

  /// No description provided for @exploreTradeSubtitle.
  ///
  /// In vi, this message translates to:
  /// **'Tổng hợp tin nhà đất, cho thuê,\nmua bán và bộ lọc nhanh'**
  String get exploreTradeSubtitle;

  /// No description provided for @exploreTradeCta.
  ///
  /// In vi, this message translates to:
  /// **'Xem tổng hợp'**
  String get exploreTradeCta;

  /// No description provided for @homeNewsSection.
  ///
  /// In vi, this message translates to:
  /// **'Tin tức'**
  String get homeNewsSection;

  /// No description provided for @homeNewsEmpty.
  ///
  /// In vi, this message translates to:
  /// **'Chưa có tin nào'**
  String get homeNewsEmpty;

  /// No description provided for @tfArea2.
  ///
  /// In vi, this message translates to:
  /// **'Khu vực tìm kiếm'**
  String get tfArea2;

  /// No description provided for @tfAreaAll.
  ///
  /// In vi, this message translates to:
  /// **'Toàn bộ'**
  String get tfAreaAll;

  /// No description provided for @tfAreaNear.
  ///
  /// In vi, this message translates to:
  /// **'Quanh đây'**
  String get tfAreaNear;

  /// No description provided for @tfAreaPlace.
  ///
  /// In vi, this message translates to:
  /// **'Địa danh'**
  String get tfAreaPlace;

  /// No description provided for @tfPlaceHint.
  ///
  /// In vi, this message translates to:
  /// **'Nhập địa danh: \"gần Đại học Hồng Đức\"…'**
  String get tfPlaceHint;

  /// No description provided for @tfRadius.
  ///
  /// In vi, this message translates to:
  /// **'Bán kính'**
  String get tfRadius;

  /// No description provided for @tfLocating.
  ///
  /// In vi, this message translates to:
  /// **'Đang lấy vị trí…'**
  String get tfLocating;

  /// No description provided for @tfLocated.
  ///
  /// In vi, this message translates to:
  /// **'Đã có vị trí ✓'**
  String get tfLocated;

  /// No description provided for @tfGeoOnlyBasic.
  ///
  /// In vi, this message translates to:
  /// **'Khi lọc theo khu vực, kết quả sắp theo khoảng cách.'**
  String get tfGeoOnlyBasic;

  /// No description provided for @tfNoMatchPlace.
  ///
  /// In vi, this message translates to:
  /// **'Không tìm thấy địa danh này'**
  String get tfNoMatchPlace;

  /// No description provided for @filterLocInsecureContext.
  ///
  /// In vi, this message translates to:
  /// **'Trang đang mở qua HTTP nên trình duyệt chặn định vị.'**
  String get filterLocInsecureContext;

  /// No description provided for @profHostSection.
  ///
  /// In vi, this message translates to:
  /// **'Quản lý cho thuê'**
  String get profHostSection;

  /// No description provided for @profHostBuildings.
  ///
  /// In vi, this message translates to:
  /// **'Nhà trọ & phòng'**
  String get profHostBuildings;

  /// No description provided for @profHostBuildingsSub.
  ///
  /// In vi, this message translates to:
  /// **'Toà nhà, phòng, khách đang thuê'**
  String get profHostBuildingsSub;

  /// No description provided for @profHostContracts.
  ///
  /// In vi, this message translates to:
  /// **'Hợp đồng'**
  String get profHostContracts;

  /// No description provided for @profHostContractsSub.
  ///
  /// In vi, this message translates to:
  /// **'Hợp đồng thuê và hạn kết thúc'**
  String get profHostContractsSub;

  /// No description provided for @profHostInvoices.
  ///
  /// In vi, this message translates to:
  /// **'Hoá đơn'**
  String get profHostInvoices;

  /// No description provided for @profHostInvoicesSub.
  ///
  /// In vi, this message translates to:
  /// **'Tiền phòng, điện nước, thu chi'**
  String get profHostInvoicesSub;

  /// No description provided for @profHostAppointments.
  ///
  /// In vi, this message translates to:
  /// **'Lịch khách xem nhà'**
  String get profHostAppointments;

  /// No description provided for @profHostAppointmentsSub.
  ///
  /// In vi, this message translates to:
  /// **'Duyệt và xếp lịch dẫn xem'**
  String get profHostAppointmentsSub;

  /// No description provided for @profHostKyc.
  ///
  /// In vi, this message translates to:
  /// **'Hồ sơ chủ nhà'**
  String get profHostKyc;

  /// No description provided for @profHostKycSub.
  ///
  /// In vi, this message translates to:
  /// **'Giấy tờ, tài khoản nhận tiền, xác minh'**
  String get profHostKycSub;

  /// No description provided for @myReqSubtitle.
  ///
  /// In vi, this message translates to:
  /// **'Thợ và dịch vụ bạn đã đặt'**
  String get myReqSubtitle;

  /// No description provided for @myReqEmptyHint.
  ///
  /// In vi, this message translates to:
  /// **'Cần thợ điện, thợ nước hay dọn nhà? Đặt một lần, chúng tôi gọi lại xếp thợ.'**
  String get myReqEmptyHint;

  /// No description provided for @myReqEmptyCta.
  ///
  /// In vi, this message translates to:
  /// **'Xem các dịch vụ'**
  String get myReqEmptyCta;

  /// No description provided for @myReqStatusContacted.
  ///
  /// In vi, this message translates to:
  /// **'Đã liên hệ'**
  String get myReqStatusContacted;

  /// No description provided for @myReqStatusScheduled.
  ///
  /// In vi, this message translates to:
  /// **'Đã hẹn lịch'**
  String get myReqStatusScheduled;

  /// No description provided for @myReqStatusDone.
  ///
  /// In vi, this message translates to:
  /// **'Hoàn thành'**
  String get myReqStatusDone;

  /// No description provided for @myReqStatusCancelled.
  ///
  /// In vi, this message translates to:
  /// **'Đã huỷ'**
  String get myReqStatusCancelled;

  /// No description provided for @myReqSentAt.
  ///
  /// In vi, this message translates to:
  /// **'Gửi {d}'**
  String myReqSentAt(String d);

  /// No description provided for @myReqScheduledAt.
  ///
  /// In vi, this message translates to:
  /// **'Hẹn {d}'**
  String myReqScheduledAt(String d);

  /// No description provided for @profMessages.
  ///
  /// In vi, this message translates to:
  /// **'Tin nhắn'**
  String get profMessages;

  /// No description provided for @profMessagesSub.
  ///
  /// In vi, this message translates to:
  /// **'Trao đổi với chủ nhà và người bán'**
  String get profMessagesSub;

  /// No description provided for @profNextViewing.
  ///
  /// In vi, this message translates to:
  /// **'Lịch hẹn sắp tới'**
  String get profNextViewing;

  /// No description provided for @profNextViewingAt.
  ///
  /// In vi, this message translates to:
  /// **'{d} · {t}'**
  String profNextViewingAt(String d, String t);

  /// No description provided for @saleCall.
  ///
  /// In vi, this message translates to:
  /// **'Nhắn tin'**
  String get saleCall;

  /// No description provided for @saleCallNamed.
  ///
  /// In vi, this message translates to:
  /// **'Nhắn cho {ten}'**
  String saleCallNamed(String ten);

  /// No description provided for @saleShareBtn.
  ///
  /// In vi, this message translates to:
  /// **'Chia sẻ'**
  String get saleShareBtn;

  /// No description provided for @saleQrTitle.
  ///
  /// In vi, this message translates to:
  /// **'Quét để mở trang'**
  String get saleQrTitle;

  /// No description provided for @saleQrHint.
  ///
  /// In vi, this message translates to:
  /// **'Đưa khách quét mã này'**
  String get saleQrHint;

  /// No description provided for @saleAreaCover.
  ///
  /// In vi, this message translates to:
  /// **'Khu vực đang có tin'**
  String get saleAreaCover;

  /// No description provided for @saleReviewsShort.
  ///
  /// In vi, this message translates to:
  /// **'Khách nói gì'**
  String get saleReviewsShort;

  /// No description provided for @albumSection.
  ///
  /// In vi, this message translates to:
  /// **'Dự án'**
  String get albumSection;

  /// No description provided for @albumUnits.
  ///
  /// In vi, this message translates to:
  /// **'{n} căn'**
  String albumUnits(int n);

  /// No description provided for @albumEmpty.
  ///
  /// In vi, this message translates to:
  /// **'Dự án chưa có tin nào'**
  String get albumEmpty;

  /// No description provided for @albumTitle.
  ///
  /// In vi, this message translates to:
  /// **'Dự án'**
  String get albumTitle;

  /// No description provided for @albumHidden.
  ///
  /// In vi, this message translates to:
  /// **'Đang ẩn'**
  String get albumHidden;

  /// No description provided for @albumMine.
  ///
  /// In vi, this message translates to:
  /// **'Dự án của tôi'**
  String get albumMine;

  /// No description provided for @albumMineSub.
  ///
  /// In vi, this message translates to:
  /// **'Gom tin theo toà, theo khu'**
  String get albumMineSub;

  /// No description provided for @albumNew.
  ///
  /// In vi, this message translates to:
  /// **'Tạo dự án'**
  String get albumNew;

  /// No description provided for @albumNameLabel.
  ///
  /// In vi, this message translates to:
  /// **'Tên dự án'**
  String get albumNameLabel;

  /// No description provided for @albumNameHint.
  ///
  /// In vi, this message translates to:
  /// **'Vinhomes Grand Park — toà S1'**
  String get albumNameHint;

  /// No description provided for @albumDescLabel.
  ///
  /// In vi, this message translates to:
  /// **'Mô tả (tuỳ chọn)'**
  String get albumDescLabel;

  /// No description provided for @albumPublicLabel.
  ///
  /// In vi, this message translates to:
  /// **'Công khai trên trang cá nhân'**
  String get albumPublicLabel;

  /// No description provided for @albumPublicHint.
  ///
  /// In vi, this message translates to:
  /// **'Tắt khi đang gom dở, khách sẽ không thấy'**
  String get albumPublicHint;

  /// No description provided for @albumSave.
  ///
  /// In vi, this message translates to:
  /// **'Lưu'**
  String get albumSave;

  /// No description provided for @albumDelete.
  ///
  /// In vi, this message translates to:
  /// **'Xoá dự án'**
  String get albumDelete;

  /// No description provided for @albumDeleteAsk.
  ///
  /// In vi, this message translates to:
  /// **'Xoá dự án này?'**
  String get albumDeleteAsk;

  /// No description provided for @albumDeleteNote.
  ///
  /// In vi, this message translates to:
  /// **'Tin bên trong VẪN CÒN, chỉ không còn thuộc dự án nào.'**
  String get albumDeleteNote;

  /// No description provided for @albumNoneYet.
  ///
  /// In vi, this message translates to:
  /// **'Chưa có dự án nào'**
  String get albumNoneYet;

  /// No description provided for @albumNoneHint.
  ///
  /// In vi, this message translates to:
  /// **'Gom các căn cùng một toà vào một dự án để khách xem một lượt.'**
  String get albumNoneHint;

  /// No description provided for @albumAddListings.
  ///
  /// In vi, this message translates to:
  /// **'Thêm tin vào dự án'**
  String get albumAddListings;

  /// No description provided for @albumPickTitle.
  ///
  /// In vi, this message translates to:
  /// **'Chọn tin'**
  String get albumPickTitle;

  /// No description provided for @albumPickEmpty.
  ///
  /// In vi, this message translates to:
  /// **'Bạn chưa có tin đăng nào'**
  String get albumPickEmpty;

  /// No description provided for @albumPickSave.
  ///
  /// In vi, this message translates to:
  /// **'Thêm {n} tin'**
  String albumPickSave(int n);

  /// No description provided for @albumUnitLabel.
  ///
  /// In vi, this message translates to:
  /// **'Nhãn căn'**
  String get albumUnitLabel;

  /// No description provided for @albumUnitHint.
  ///
  /// In vi, this message translates to:
  /// **'Căn 1201'**
  String get albumUnitHint;

  /// No description provided for @albumRemove.
  ///
  /// In vi, this message translates to:
  /// **'Gỡ khỏi dự án'**
  String get albumRemove;

  /// No description provided for @albumSaved.
  ///
  /// In vi, this message translates to:
  /// **'Đã lưu'**
  String get albumSaved;

  /// No description provided for @albumNeedName.
  ///
  /// In vi, this message translates to:
  /// **'Nhập tên dự án'**
  String get albumNeedName;

  /// No description provided for @tfActiveCount.
  ///
  /// In vi, this message translates to:
  /// **'{n} bộ lọc'**
  String tfActiveCount(int n);

  /// No description provided for @homeMapPreviewTitle.
  ///
  /// In vi, this message translates to:
  /// **'Nhà đăng quanh bạn'**
  String get homeMapPreviewTitle;

  /// No description provided for @homeMapPreviewOpen.
  ///
  /// In vi, this message translates to:
  /// **'Mở bản đồ'**
  String get homeMapPreviewOpen;

  /// No description provided for @homeMapPreviewEmpty.
  ///
  /// In vi, this message translates to:
  /// **'Chưa có tin nào có toạ độ'**
  String get homeMapPreviewEmpty;

  /// No description provided for @homeMapLocate.
  ///
  /// In vi, this message translates to:
  /// **'Về vị trí của tôi'**
  String get homeMapLocate;

  /// No description provided for @mapLocationInsecure.
  ///
  /// In vi, this message translates to:
  /// **'Trình duyệt chỉ cho lấy vị trí trên HTTPS. Hãy mở trang bằng địa chỉ https://'**
  String get mapLocationInsecure;

  /// No description provided for @mapLocationBlocked.
  ///
  /// In vi, this message translates to:
  /// **'Trang này đang bị chặn quyền vị trí. Bấm biểu tượng ổ khoá cạnh thanh địa chỉ → cho phép Vị trí → tải lại trang.'**
  String get mapLocationBlocked;

  /// No description provided for @homeMapExpand.
  ///
  /// In vi, this message translates to:
  /// **'Mở rộng'**
  String get homeMapExpand;

  /// No description provided for @hubMapSection.
  ///
  /// In vi, this message translates to:
  /// **'Khu vực mua bán'**
  String get hubMapSection;

  /// No description provided for @shellNavServices.
  ///
  /// In vi, this message translates to:
  /// **'Dịch vụ'**
  String get shellNavServices;

  /// No description provided for @cardOnMap.
  ///
  /// In vi, this message translates to:
  /// **'Xem trên bản đồ'**
  String get cardOnMap;

  /// No description provided for @tradeOpenMap.
  ///
  /// In vi, this message translates to:
  /// **'Bản đồ'**
  String get tradeOpenMap;

  /// No description provided for @hubGreeting.
  ///
  /// In vi, this message translates to:
  /// **'Xin chào,'**
  String get hubGreeting;

  /// No description provided for @svcGroupDeal.
  ///
  /// In vi, this message translates to:
  /// **'Mua bán & pháp lý'**
  String get svcGroupDeal;

  /// No description provided for @svcGroupDealHint.
  ///
  /// In vi, this message translates to:
  /// **'Định giá, sang tên, vay vốn, kiểm định'**
  String get svcGroupDealHint;

  /// No description provided for @svcGroupDesignBuild.
  ///
  /// In vi, this message translates to:
  /// **'Thiết kế & Thi công'**
  String get svcGroupDesignBuild;

  /// No description provided for @svcGroupDesignBuildHint.
  ///
  /// In vi, this message translates to:
  /// **'Từ bản vẽ tới bàn giao, có gói trọn gói'**
  String get svcGroupDesignBuildHint;

  /// No description provided for @svcGroupRepair.
  ///
  /// In vi, this message translates to:
  /// **'Sửa chữa nhanh'**
  String get svcGroupRepair;

  /// No description provided for @svcGroupRepairHint.
  ///
  /// In vi, this message translates to:
  /// **'Thợ tới trong ngày'**
  String get svcGroupRepairHint;

  /// No description provided for @svcGroupHomeCare.
  ///
  /// In vi, this message translates to:
  /// **'Dọn dẹp & Chuyển nhà'**
  String get svcGroupHomeCare;

  /// No description provided for @svcGroupHomeCareHint.
  ///
  /// In vi, this message translates to:
  /// **'Vệ sinh, chuyển nhà, giúp việc'**
  String get svcGroupHomeCareHint;

  /// No description provided for @svcGroupOther.
  ///
  /// In vi, this message translates to:
  /// **'Dịch vụ khác'**
  String get svcGroupOther;

  /// No description provided for @svcCount.
  ///
  /// In vi, this message translates to:
  /// **'{n} dịch vụ'**
  String svcCount(int n);

  /// No description provided for @svcHeroTitle.
  ///
  /// In vi, this message translates to:
  /// **'Cần gì cũng có thợ'**
  String get svcHeroTitle;

  /// No description provided for @svcHeroSubtitle.
  ///
  /// In vi, this message translates to:
  /// **'Gửi yêu cầu, Vua Nhà gọi lại và xếp thợ giúp bạn'**
  String get svcHeroSubtitle;

  /// No description provided for @svcSearchHint.
  ///
  /// In vi, this message translates to:
  /// **'Bạn cần làm gì hôm nay?'**
  String get svcSearchHint;

  /// No description provided for @svcStat.
  ///
  /// In vi, this message translates to:
  /// **'{n} dịch vụ · {g} nhóm'**
  String svcStat(int n, int g);

  /// No description provided for @svcNoMatch.
  ///
  /// In vi, this message translates to:
  /// **'Không có dịch vụ nào khớp'**
  String get svcNoMatch;

  /// No description provided for @svcNoMatchHint.
  ///
  /// In vi, this message translates to:
  /// **'Thử từ khoá ngắn hơn, ví dụ “điện” hoặc “sơn”.'**
  String get svcNoMatchHint;

  /// No description provided for @svcGroupCount.
  ///
  /// In vi, this message translates to:
  /// **'{n} nhóm'**
  String svcGroupCount(int n);

  /// No description provided for @loginIdentifier.
  ///
  /// In vi, this message translates to:
  /// **'Email hoặc số điện thoại'**
  String get loginIdentifier;

  /// No description provided for @identifierHint.
  ///
  /// In vi, this message translates to:
  /// **'0912345678 hoặc ban@vidu.com'**
  String get identifierHint;

  /// No description provided for @valIdentifierRequired.
  ///
  /// In vi, this message translates to:
  /// **'Nhập email hoặc số điện thoại'**
  String get valIdentifierRequired;

  /// No description provided for @registerEmailOptional.
  ///
  /// In vi, this message translates to:
  /// **'Email (nếu có)'**
  String get registerEmailOptional;

  /// No description provided for @registerNeedEmailOrPhone.
  ///
  /// In vi, this message translates to:
  /// **'Cần ít nhất email hoặc số điện thoại'**
  String get registerNeedEmailOrPhone;

  /// No description provided for @registerNoEmailWarning.
  ///
  /// In vi, this message translates to:
  /// **'Không có email thì khi quên mật khẩu bạn phải nhờ hỗ trợ — liên kết đặt lại chỉ gửi qua email.'**
  String get registerNoEmailWarning;

  /// No description provided for @valPhoneInvalid.
  ///
  /// In vi, this message translates to:
  /// **'Số điện thoại chưa đúng (VD: 0912345678)'**
  String get valPhoneInvalid;

  /// No description provided for @primingBtnEnable.
  ///
  /// In vi, this message translates to:
  /// **'Bật ngay'**
  String get primingBtnEnable;

  /// No description provided for @primingBtnDefer.
  ///
  /// In vi, this message translates to:
  /// **'Để sau'**
  String get primingBtnDefer;

  /// No description provided for @primingBtnContinue.
  ///
  /// In vi, this message translates to:
  /// **'Tiếp tục'**
  String get primingBtnContinue;

  /// No description provided for @primingBtnCancel.
  ///
  /// In vi, this message translates to:
  /// **'Hủy'**
  String get primingBtnCancel;

  /// No description provided for @primingBtnClose.
  ///
  /// In vi, this message translates to:
  /// **'Đóng'**
  String get primingBtnClose;

  /// No description provided for @primingTrustCanDisable.
  ///
  /// In vi, this message translates to:
  /// **'Tắt bất kỳ lúc nào'**
  String get primingTrustCanDisable;

  /// No description provided for @primingTrustNoSpam.
  ///
  /// In vi, this message translates to:
  /// **'Không spam — chỉ thông tin hữu ích'**
  String get primingTrustNoSpam;

  /// No description provided for @primingSoftReaskNotif.
  ///
  /// In vi, this message translates to:
  /// **'Bạn đã tắt thông báo. Bật trong Cài đặt để không bỏ lỡ tin nhắn.'**
  String get primingSoftReaskNotif;

  /// No description provided for @primingSoftReaskCamera.
  ///
  /// In vi, this message translates to:
  /// **'Bạn đã tắt camera. Bật trong Cài đặt để chụp ảnh phòng.'**
  String get primingSoftReaskCamera;

  /// No description provided for @primingSoftReaskOpenSettings.
  ///
  /// In vi, this message translates to:
  /// **'Mở Cài đặt'**
  String get primingSoftReaskOpenSettings;

  /// No description provided for @primingSoftReaskDismiss.
  ///
  /// In vi, this message translates to:
  /// **'Bỏ qua'**
  String get primingSoftReaskDismiss;

  /// No description provided for @primingSettingsNotifTitle.
  ///
  /// In vi, this message translates to:
  /// **'Thông báo'**
  String get primingSettingsNotifTitle;

  /// No description provided for @primingSettingsCameraTitle.
  ///
  /// In vi, this message translates to:
  /// **'Camera'**
  String get primingSettingsCameraTitle;

  /// No description provided for @primingSettingsStatusEnabled.
  ///
  /// In vi, this message translates to:
  /// **'Đã bật'**
  String get primingSettingsStatusEnabled;

  /// No description provided for @primingSettingsStatusDisabled.
  ///
  /// In vi, this message translates to:
  /// **'Đã tắt'**
  String get primingSettingsStatusDisabled;

  /// No description provided for @primingSettingsActionEnable.
  ///
  /// In vi, this message translates to:
  /// **'Bật → Đi tới Cài đặt'**
  String get primingSettingsActionEnable;

  /// No description provided for @jp_shikikin.
  ///
  /// In vi, this message translates to:
  /// **'Tiền đặt cọc (敷金)'**
  String get jp_shikikin;

  /// No description provided for @jp_reikin.
  ///
  /// In vi, this message translates to:
  /// **'Tiền lễ (礼金)'**
  String get jp_reikin;

  /// No description provided for @jp_koushinryo.
  ///
  /// In vi, this message translates to:
  /// **'Phí gia hạn (更新料)'**
  String get jp_koushinryo;

  /// No description provided for @jp_hoshou.
  ///
  /// In vi, this message translates to:
  /// **'Tiền bảo đảm (保証金)'**
  String get jp_hoshou;

  /// No description provided for @jp_brokerage.
  ///
  /// In vi, this message translates to:
  /// **'Phí môi giới (仲介手数料)'**
  String get jp_brokerage;

  /// No description provided for @jp_management_fee.
  ///
  /// In vi, this message translates to:
  /// **'Phí quản lý (管理費)'**
  String get jp_management_fee;

  /// No description provided for @jp_monthly_rent.
  ///
  /// In vi, this message translates to:
  /// **'Tiền thuê hàng tháng (月額家賃)'**
  String get jp_monthly_rent;

  /// No description provided for @jp_shouhizei.
  ///
  /// In vi, this message translates to:
  /// **'Thuế tiêu thụ (消費税)'**
  String get jp_shouhizei;

  /// No description provided for @jp_kyouekihi.
  ///
  /// In vi, this message translates to:
  /// **'Chi phí chung (共益費)'**
  String get jp_kyouekihi;

  /// No description provided for @jp_layout.
  ///
  /// In vi, this message translates to:
  /// **'Sơ đồ phòng (間取り)'**
  String get jp_layout;

  /// No description provided for @jp_floor_area.
  ///
  /// In vi, this message translates to:
  /// **'Diện tích (専有面積)'**
  String get jp_floor_area;

  /// No description provided for @jp_building_year.
  ///
  /// In vi, this message translates to:
  /// **'Năm xây dựng (築年数)'**
  String get jp_building_year;

  /// No description provided for @jp_structure_rc.
  ///
  /// In vi, this message translates to:
  /// **'Bê tông cốt thép (RC)'**
  String get jp_structure_rc;

  /// No description provided for @jp_structure_wood.
  ///
  /// In vi, this message translates to:
  /// **'Gỗ (木造)'**
  String get jp_structure_wood;

  /// No description provided for @jp_structure_steel.
  ///
  /// In vi, this message translates to:
  /// **'Thép (鉄骨)'**
  String get jp_structure_steel;

  /// No description provided for @jp_structure_src.
  ///
  /// In vi, this message translates to:
  /// **'Thép + Bê tông (SRC)'**
  String get jp_structure_src;

  /// No description provided for @jp_orientation_n.
  ///
  /// In vi, this message translates to:
  /// **'Hướng Bắc (北)'**
  String get jp_orientation_n;

  /// No description provided for @jp_orientation_ne.
  ///
  /// In vi, this message translates to:
  /// **'Hướng Đông Bắc (北東)'**
  String get jp_orientation_ne;

  /// No description provided for @jp_orientation_e.
  ///
  /// In vi, this message translates to:
  /// **'Hướng Đông (東)'**
  String get jp_orientation_e;

  /// No description provided for @jp_orientation_se.
  ///
  /// In vi, this message translates to:
  /// **'Hướng Đông Nam (南東)'**
  String get jp_orientation_se;

  /// No description provided for @jp_orientation_s.
  ///
  /// In vi, this message translates to:
  /// **'Hướng Nam (南)'**
  String get jp_orientation_s;

  /// No description provided for @jp_orientation_sw.
  ///
  /// In vi, this message translates to:
  /// **'Hướng Tây Nam (南西)'**
  String get jp_orientation_sw;

  /// No description provided for @jp_orientation_w.
  ///
  /// In vi, this message translates to:
  /// **'Hướng Tây (西)'**
  String get jp_orientation_w;

  /// No description provided for @jp_orientation_nw.
  ///
  /// In vi, this message translates to:
  /// **'Hướng Tây Bắc (北西)'**
  String get jp_orientation_nw;

  /// No description provided for @jp_available_from.
  ///
  /// In vi, this message translates to:
  /// **'Ngày có thể vào ở (入居可能日)'**
  String get jp_available_from;

  /// No description provided for @jp_floor.
  ///
  /// In vi, this message translates to:
  /// **'Tầng (階数)'**
  String get jp_floor;

  /// No description provided for @jp_nearest_station.
  ///
  /// In vi, this message translates to:
  /// **'Ga gần nhất (最寄り駅)'**
  String get jp_nearest_station;

  /// No description provided for @jp_walk_min_from_station.
  ///
  /// In vi, this message translates to:
  /// **'Đi bộ từ ga (徒歩分)'**
  String get jp_walk_min_from_station;

  /// No description provided for @jp_train_line.
  ///
  /// In vi, this message translates to:
  /// **'Tuyến tàu (路線)'**
  String get jp_train_line;

  /// No description provided for @jp_viewing_request.
  ///
  /// In vi, this message translates to:
  /// **'Yêu cầu xem nhà (内見リクエスト)'**
  String get jp_viewing_request;

  /// No description provided for @jp_select_slots.
  ///
  /// In vi, this message translates to:
  /// **'Chọn khung giờ'**
  String get jp_select_slots;

  /// No description provided for @jp_slot_confirmed.
  ///
  /// In vi, this message translates to:
  /// **'Khung giờ đã xác nhận'**
  String get jp_slot_confirmed;

  /// No description provided for @jp_viewing_status_pending.
  ///
  /// In vi, this message translates to:
  /// **'Đang chờ xác nhận'**
  String get jp_viewing_status_pending;

  /// No description provided for @jp_viewing_status_confirmed.
  ///
  /// In vi, this message translates to:
  /// **'Đã xác nhận'**
  String get jp_viewing_status_confirmed;

  /// No description provided for @jp_viewing_status_rejected.
  ///
  /// In vi, this message translates to:
  /// **'Đã từ chối'**
  String get jp_viewing_status_rejected;

  /// No description provided for @jp_viewing_status_cancelled.
  ///
  /// In vi, this message translates to:
  /// **'Đã huỷ'**
  String get jp_viewing_status_cancelled;

  /// No description provided for @jp_viewing_status_completed.
  ///
  /// In vi, this message translates to:
  /// **'Đã hoàn thành'**
  String get jp_viewing_status_completed;

  /// No description provided for @jp_slot_label.
  ///
  /// In vi, this message translates to:
  /// **'Khung giờ {n}'**
  String jp_slot_label(int n);

  /// No description provided for @jp_slots_hint.
  ///
  /// In vi, this message translates to:
  /// **'Chọn tối đa 3 khung giờ'**
  String get jp_slots_hint;

  /// No description provided for @jp_slots_max_warning.
  ///
  /// In vi, this message translates to:
  /// **'Chỉ có thể chọn tối đa 3 khung giờ'**
  String get jp_slots_max_warning;

  /// No description provided for @jp_apply.
  ///
  /// In vi, this message translates to:
  /// **'Nộp đơn thuê nhà (入居申込)'**
  String get jp_apply;

  /// No description provided for @jp_employer.
  ///
  /// In vi, this message translates to:
  /// **'Nơi làm việc (勤務先)'**
  String get jp_employer;

  /// No description provided for @jp_annual_income.
  ///
  /// In vi, this message translates to:
  /// **'Thu nhập hàng năm (年収)'**
  String get jp_annual_income;

  /// No description provided for @jp_guarantor.
  ///
  /// In vi, this message translates to:
  /// **'Người bảo lãnh (連帯保証人)'**
  String get jp_guarantor;

  /// No description provided for @jp_emergency_contact.
  ///
  /// In vi, this message translates to:
  /// **'Liên lạc khẩn cấp (緊急連絡先)'**
  String get jp_emergency_contact;

  /// No description provided for @jp_upload_documents.
  ///
  /// In vi, this message translates to:
  /// **'Tải lên hồ sơ (書類アップロード)'**
  String get jp_upload_documents;

  /// No description provided for @jp_application_status_draft.
  ///
  /// In vi, this message translates to:
  /// **'Bản nháp'**
  String get jp_application_status_draft;

  /// No description provided for @jp_application_status_submitted.
  ///
  /// In vi, this message translates to:
  /// **'Đã nộp'**
  String get jp_application_status_submitted;

  /// No description provided for @jp_application_status_under_review.
  ///
  /// In vi, this message translates to:
  /// **'Đang xem xét'**
  String get jp_application_status_under_review;

  /// No description provided for @jp_application_status_approved.
  ///
  /// In vi, this message translates to:
  /// **'Đã duyệt'**
  String get jp_application_status_approved;

  /// No description provided for @jp_application_status_rejected.
  ///
  /// In vi, this message translates to:
  /// **'Đã từ chối'**
  String get jp_application_status_rejected;

  /// No description provided for @jp_application_status_withdrawn.
  ///
  /// In vi, this message translates to:
  /// **'Đã rút'**
  String get jp_application_status_withdrawn;

  /// No description provided for @jp_chat_greeting_formal.
  ///
  /// In vi, this message translates to:
  /// **'Xin chào, tôi có thể giúp gì cho bạn?'**
  String get jp_chat_greeting_formal;

  /// No description provided for @jp_chat_viewing_confirm.
  ///
  /// In vi, this message translates to:
  /// **'Tôi xác nhận lịch xem nhà.'**
  String get jp_chat_viewing_confirm;

  /// No description provided for @jp_chat_apology.
  ///
  /// In vi, this message translates to:
  /// **'Xin lỗi vì sự bất tiện này.'**
  String get jp_chat_apology;

  /// No description provided for @jp_chat_available.
  ///
  /// In vi, this message translates to:
  /// **'Tôi có thể xem nhà vào thời điểm này.'**
  String get jp_chat_available;

  /// No description provided for @jp_submit.
  ///
  /// In vi, this message translates to:
  /// **'Gửi'**
  String get jp_submit;

  /// No description provided for @jp_cancel_viewing.
  ///
  /// In vi, this message translates to:
  /// **'Huỷ lịch xem'**
  String get jp_cancel_viewing;

  /// No description provided for @jp_reschedule.
  ///
  /// In vi, this message translates to:
  /// **'Đổi lịch'**
  String get jp_reschedule;

  /// No description provided for @jp_step_basic_info.
  ///
  /// In vi, this message translates to:
  /// **'Thông tin cơ bản'**
  String get jp_step_basic_info;

  /// No description provided for @jp_step_employer.
  ///
  /// In vi, this message translates to:
  /// **'Thông tin công việc'**
  String get jp_step_employer;

  /// No description provided for @jp_step_guarantor.
  ///
  /// In vi, this message translates to:
  /// **'Người bảo lãnh'**
  String get jp_step_guarantor;

  /// No description provided for @jp_step_documents.
  ///
  /// In vi, this message translates to:
  /// **'Hồ sơ giấy tờ'**
  String get jp_step_documents;

  /// No description provided for @jp_step_confirm.
  ///
  /// In vi, this message translates to:
  /// **'Xác nhận'**
  String get jp_step_confirm;

  /// No description provided for @jp_search_facets_title.
  ///
  /// In vi, this message translates to:
  /// **'Lọc tìm kiếm'**
  String get jp_search_facets_title;

  /// No description provided for @jp_layout_filter.
  ///
  /// In vi, this message translates to:
  /// **'Loại phòng'**
  String get jp_layout_filter;

  /// No description provided for @jp_rent_range.
  ///
  /// In vi, this message translates to:
  /// **'Khoảng giá thuê'**
  String get jp_rent_range;

  /// No description provided for @jp_area_range.
  ///
  /// In vi, this message translates to:
  /// **'Diện tích'**
  String get jp_area_range;

  /// No description provided for @jp_building_age_max.
  ///
  /// In vi, this message translates to:
  /// **'Niên đại tối đa (築年数)'**
  String get jp_building_age_max;

  /// No description provided for @jp_walk_min_max.
  ///
  /// In vi, this message translates to:
  /// **'Đi bộ tối đa từ ga'**
  String get jp_walk_min_max;

  /// No description provided for @jp_flag_pets_ok.
  ///
  /// In vi, this message translates to:
  /// **'Cho phép thú cưng (ペット可)'**
  String get jp_flag_pets_ok;

  /// No description provided for @jp_flag_no_guarantor.
  ///
  /// In vi, this message translates to:
  /// **'Không cần bảo lãnh (保証会社不要)'**
  String get jp_flag_no_guarantor;

  /// No description provided for @jp_flag_instruments_ok.
  ///
  /// In vi, this message translates to:
  /// **'Cho phép nhạc cụ (楽器可)'**
  String get jp_flag_instruments_ok;

  /// No description provided for @jp_flag_corporate_ok.
  ///
  /// In vi, this message translates to:
  /// **'Hợp đồng doanh nghiệp (法人契約可)'**
  String get jp_flag_corporate_ok;

  /// No description provided for @jp_sales_dashboard_title.
  ///
  /// In vi, this message translates to:
  /// **'Bảng điều khiển (担当)'**
  String get jp_sales_dashboard_title;

  /// No description provided for @jp_assigned_listings.
  ///
  /// In vi, this message translates to:
  /// **'Tin đăng phụ trách'**
  String get jp_assigned_listings;

  /// No description provided for @jp_pending_viewings.
  ///
  /// In vi, this message translates to:
  /// **'Lịch xem chờ duyệt'**
  String get jp_pending_viewings;

  /// No description provided for @jp_pending_applications.
  ///
  /// In vi, this message translates to:
  /// **'Đơn thuê chờ xử lý'**
  String get jp_pending_applications;

  /// No description provided for @jp_viewing_inbox_title.
  ///
  /// In vi, this message translates to:
  /// **'Yêu cầu xem nhà'**
  String get jp_viewing_inbox_title;

  /// No description provided for @jp_application_queue_title.
  ///
  /// In vi, this message translates to:
  /// **'Hàng đợi đơn thuê'**
  String get jp_application_queue_title;

  /// No description provided for @jp_confirm_slot.
  ///
  /// In vi, this message translates to:
  /// **'Xác nhận khung giờ'**
  String get jp_confirm_slot;

  /// No description provided for @jp_reject_viewing.
  ///
  /// In vi, this message translates to:
  /// **'Từ chối yêu cầu'**
  String get jp_reject_viewing;

  /// No description provided for @jp_application_decision.
  ///
  /// In vi, this message translates to:
  /// **'Quyết định đơn thuê'**
  String get jp_application_decision;

  /// No description provided for @jp_approve_application.
  ///
  /// In vi, this message translates to:
  /// **'Phê duyệt'**
  String get jp_approve_application;

  /// No description provided for @jp_reject_application.
  ///
  /// In vi, this message translates to:
  /// **'Từ chối'**
  String get jp_reject_application;

  /// No description provided for @jp_honorific_toggle.
  ///
  /// In vi, this message translates to:
  /// **'Dùng kính ngữ (丁寧語)'**
  String get jp_honorific_toggle;

  /// No description provided for @jp_honorific_on.
  ///
  /// In vi, this message translates to:
  /// **'Bật'**
  String get jp_honorific_on;

  /// No description provided for @jp_honorific_off.
  ///
  /// In vi, this message translates to:
  /// **'Tắt'**
  String get jp_honorific_off;

  /// No description provided for @appi_consent_title.
  ///
  /// In vi, this message translates to:
  /// **'Xử lý thông tin cá nhân'**
  String get appi_consent_title;

  /// No description provided for @appi_purpose_service_use.
  ///
  /// In vi, this message translates to:
  /// **'Cung cấp dịch vụ — tìm kiếm bất động sản và xử lý hợp đồng'**
  String get appi_purpose_service_use;

  /// No description provided for @appi_purpose_marketing.
  ///
  /// In vi, this message translates to:
  /// **'Tiếp thị — đề xuất bất động sản và khuyến mãi'**
  String get appi_purpose_marketing;

  /// No description provided for @appi_purpose_analytics.
  ///
  /// In vi, this message translates to:
  /// **'Phân tích — cải thiện dịch vụ và phân tích sử dụng'**
  String get appi_purpose_analytics;

  /// No description provided for @appi_purpose_data_sharing_broker.
  ///
  /// In vi, this message translates to:
  /// **'Chia sẻ dữ liệu với môi giới được cấp phép để xử lý giao dịch'**
  String get appi_purpose_data_sharing_broker;

  /// No description provided for @appi_purpose_data_sharing_hoshou.
  ///
  /// In vi, this message translates to:
  /// **'Chia sẻ dữ liệu với công ty bảo lãnh (保証会社) để thẩm định'**
  String get appi_purpose_data_sharing_hoshou;

  /// No description provided for @appi_consent_required_notice.
  ///
  /// In vi, this message translates to:
  /// **'Các mục đích được đánh dấu bắt buộc là cần thiết để cung cấp dịch vụ. Bạn phải đồng ý để tiếp tục.'**
  String get appi_consent_required_notice;

  /// No description provided for @appi_privacy_policy_link.
  ///
  /// In vi, this message translates to:
  /// **'Chính sách bảo mật (個人情報保護方針)'**
  String get appi_privacy_policy_link;

  /// No description provided for @appi_i_agree.
  ///
  /// In vi, this message translates to:
  /// **'Tôi đồng ý (同意する)'**
  String get appi_i_agree;

  /// No description provided for @appi_revoke_consent.
  ///
  /// In vi, this message translates to:
  /// **'Thu hồi'**
  String get appi_revoke_consent;

  /// No description provided for @appi_consent_revoked.
  ///
  /// In vi, this message translates to:
  /// **'Đã thu hồi đồng ý'**
  String get appi_consent_revoked;

  /// No description provided for @appi_consent_granted_on.
  ///
  /// In vi, this message translates to:
  /// **'Ngày đồng ý'**
  String get appi_consent_granted_on;

  /// No description provided for @appi_privacy_settings_title.
  ///
  /// In vi, this message translates to:
  /// **'Thông tin cá nhân (個人情報の取扱い)'**
  String get appi_privacy_settings_title;

  /// No description provided for @appi_consent_list_title.
  ///
  /// In vi, this message translates to:
  /// **'Lịch sử đồng ý'**
  String get appi_consent_list_title;

  /// No description provided for @appi_no_consents.
  ///
  /// In vi, this message translates to:
  /// **'Chưa có lịch sử đồng ý'**
  String get appi_no_consents;

  /// No description provided for @data_export_request.
  ///
  /// In vi, this message translates to:
  /// **'Yêu cầu xuất dữ liệu'**
  String get data_export_request;

  /// No description provided for @data_export_processing.
  ///
  /// In vi, this message translates to:
  /// **'Dữ liệu của bạn đang được chuẩn bị. Vui lòng chờ trong giây lát.'**
  String get data_export_processing;

  /// No description provided for @data_export_ready.
  ///
  /// In vi, this message translates to:
  /// **'Dữ liệu đã sẵn sàng. Nhấn để tải xuống.'**
  String get data_export_ready;

  /// No description provided for @data_export_submit.
  ///
  /// In vi, this message translates to:
  /// **'Gửi yêu cầu'**
  String get data_export_submit;

  /// No description provided for @data_export_title.
  ///
  /// In vi, this message translates to:
  /// **'Xuất dữ liệu cá nhân'**
  String get data_export_title;

  /// No description provided for @data_export_description.
  ///
  /// In vi, this message translates to:
  /// **'Chúng tôi sẽ tổng hợp toàn bộ dữ liệu cá nhân liên kết với tài khoản của bạn và gửi đường dẫn tải xuống.'**
  String get data_export_description;

  /// No description provided for @data_delete_title.
  ///
  /// In vi, this message translates to:
  /// **'Xóa dữ liệu cá nhân'**
  String get data_delete_title;

  /// No description provided for @data_delete_warning.
  ///
  /// In vi, this message translates to:
  /// **'Thao tác này sẽ xóa vĩnh viễn toàn bộ dữ liệu cá nhân liên kết với tài khoản của bạn. Không thể hoàn tác.'**
  String get data_delete_warning;

  /// No description provided for @data_delete_cool_off.
  ///
  /// In vi, this message translates to:
  /// **'Thời gian hủy 30 ngày được áp dụng. Bạn có thể hủy yêu cầu trong thời gian này bằng cách liên hệ hỗ trợ.'**
  String get data_delete_cool_off;

  /// No description provided for @data_delete_confirm.
  ///
  /// In vi, this message translates to:
  /// **'Nhập DELETE để xác nhận'**
  String get data_delete_confirm;

  /// No description provided for @data_delete_submit.
  ///
  /// In vi, this message translates to:
  /// **'Gửi yêu cầu xóa'**
  String get data_delete_submit;

  /// No description provided for @data_delete_type_hint.
  ///
  /// In vi, this message translates to:
  /// **'Nhập DELETE'**
  String get data_delete_type_hint;

  /// No description provided for @data_delete_type_error.
  ///
  /// In vi, this message translates to:
  /// **'Vui lòng nhập DELETE để xác nhận'**
  String get data_delete_type_error;

  /// No description provided for @checkout_title.
  ///
  /// In vi, this message translates to:
  /// **'Thanh toán'**
  String get checkout_title;

  /// No description provided for @checkout_invoice_summary.
  ///
  /// In vi, this message translates to:
  /// **'Tóm tắt hóa đơn'**
  String get checkout_invoice_summary;

  /// No description provided for @checkout_total.
  ///
  /// In vi, this message translates to:
  /// **'Tổng cộng'**
  String get checkout_total;

  /// No description provided for @payment_method_card.
  ///
  /// In vi, this message translates to:
  /// **'Thẻ tín dụng / thẻ ghi nợ'**
  String get payment_method_card;

  /// No description provided for @payment_method_konbini.
  ///
  /// In vi, this message translates to:
  /// **'Cửa hàng tiện lợi (コンビニ)'**
  String get payment_method_konbini;

  /// No description provided for @payment_method_bank_transfer.
  ///
  /// In vi, this message translates to:
  /// **'Chuyển khoản ngân hàng (振込)'**
  String get payment_method_bank_transfer;

  /// No description provided for @payment_card_placeholder.
  ///
  /// In vi, this message translates to:
  /// **'Thanh toán bằng thẻ sắp ra mắt'**
  String get payment_card_placeholder;

  /// No description provided for @payment_bank_placeholder.
  ///
  /// In vi, this message translates to:
  /// **'Thông tin chuyển khoản sẽ được cung cấp sau khi xác nhận'**
  String get payment_bank_placeholder;

  /// No description provided for @konbini_voucher_title.
  ///
  /// In vi, this message translates to:
  /// **'Phiếu thanh toán'**
  String get konbini_voucher_title;

  /// No description provided for @konbini_voucher_number.
  ///
  /// In vi, this message translates to:
  /// **'Mã phiếu'**
  String get konbini_voucher_number;

  /// No description provided for @konbini_voucher_deadline.
  ///
  /// In vi, this message translates to:
  /// **'Hạn thanh toán'**
  String get konbini_voucher_deadline;

  /// No description provided for @konbini_voucher_instructions.
  ///
  /// In vi, this message translates to:
  /// **'Mang mã phiếu này đến bất kỳ cửa hàng tiện lợi nào để thanh toán tại quầy hoặc máy đa năng.'**
  String get konbini_voucher_instructions;

  /// No description provided for @konbini_copy_number.
  ///
  /// In vi, this message translates to:
  /// **'Sao chép mã'**
  String get konbini_copy_number;

  /// No description provided for @konbini_number_copied.
  ///
  /// In vi, this message translates to:
  /// **'Đã sao chép mã phiếu'**
  String get konbini_number_copied;

  /// No description provided for @konbini_stores.
  ///
  /// In vi, this message translates to:
  /// **'Cửa hàng chấp nhận'**
  String get konbini_stores;

  /// No description provided for @payment_status_pending.
  ///
  /// In vi, this message translates to:
  /// **'Chờ thanh toán'**
  String get payment_status_pending;

  /// No description provided for @payment_status_processing.
  ///
  /// In vi, this message translates to:
  /// **'Đang xử lý'**
  String get payment_status_processing;

  /// No description provided for @payment_status_succeeded.
  ///
  /// In vi, this message translates to:
  /// **'Thanh toán thành công'**
  String get payment_status_succeeded;

  /// No description provided for @payment_status_failed.
  ///
  /// In vi, this message translates to:
  /// **'Thanh toán thất bại'**
  String get payment_status_failed;

  /// No description provided for @payment_status_expired.
  ///
  /// In vi, this message translates to:
  /// **'Hết hạn thanh toán'**
  String get payment_status_expired;

  /// No description provided for @payment_status_title.
  ///
  /// In vi, this message translates to:
  /// **'Trạng thái thanh toán'**
  String get payment_status_title;

  /// No description provided for @payment_status_checking.
  ///
  /// In vi, this message translates to:
  /// **'Đang kiểm tra trạng thái…'**
  String get payment_status_checking;

  /// No description provided for @payment_retry.
  ///
  /// In vi, this message translates to:
  /// **'Thử lại'**
  String get payment_retry;

  /// No description provided for @payment_contact_support.
  ///
  /// In vi, this message translates to:
  /// **'Liên hệ hỗ trợ'**
  String get payment_contact_support;

  /// No description provided for @review_decision.
  ///
  /// In vi, this message translates to:
  /// **'Quyết định xét duyệt'**
  String get review_decision;

  /// No description provided for @review_approve.
  ///
  /// In vi, this message translates to:
  /// **'Phê duyệt'**
  String get review_approve;

  /// No description provided for @review_reject.
  ///
  /// In vi, this message translates to:
  /// **'Từ chối'**
  String get review_reject;

  /// No description provided for @review_needs_info.
  ///
  /// In vi, this message translates to:
  /// **'Yêu cầu thêm thông tin'**
  String get review_needs_info;

  /// No description provided for @review_reason.
  ///
  /// In vi, this message translates to:
  /// **'Lý do (tùy chọn)'**
  String get review_reason;

  /// No description provided for @review_reason_hint.
  ///
  /// In vi, this message translates to:
  /// **'Cung cấp lý do cho quyết định này'**
  String get review_reason_hint;

  /// No description provided for @review_submit.
  ///
  /// In vi, this message translates to:
  /// **'Gửi quyết định'**
  String get review_submit;

  /// No description provided for @review_submitting.
  ///
  /// In vi, this message translates to:
  /// **'Đang gửi…'**
  String get review_submitting;

  /// No description provided for @review_submitted.
  ///
  /// In vi, this message translates to:
  /// **'Đã gửi quyết định'**
  String get review_submitted;

  /// No description provided for @review_applicant_info.
  ///
  /// In vi, this message translates to:
  /// **'Thông tin người nộp đơn'**
  String get review_applicant_info;

  /// No description provided for @review_employer_info.
  ///
  /// In vi, this message translates to:
  /// **'Thông tin việc làm'**
  String get review_employer_info;

  /// No description provided for @review_guarantor_info.
  ///
  /// In vi, this message translates to:
  /// **'Thông tin người bảo lãnh'**
  String get review_guarantor_info;

  /// No description provided for @review_documents.
  ///
  /// In vi, this message translates to:
  /// **'Tài liệu'**
  String get review_documents;

  /// No description provided for @review_no_documents.
  ///
  /// In vi, this message translates to:
  /// **'Chưa có tài liệu'**
  String get review_no_documents;

  /// No description provided for @it_session_title.
  ///
  /// In vi, this message translates to:
  /// **'IT重説 — Giải thích trực tuyến'**
  String get it_session_title;

  /// No description provided for @it_session_takken_shi_info.
  ///
  /// In vi, this message translates to:
  /// **'Đại lý bất động sản có giấy phép (宅建士)'**
  String get it_session_takken_shi_info;

  /// No description provided for @it_session_license_number.
  ///
  /// In vi, this message translates to:
  /// **'Số giấy phép'**
  String get it_session_license_number;

  /// No description provided for @it_session_consent_notice.
  ///
  /// In vi, this message translates to:
  /// **'Phiên này sẽ được ghi lại để tuân thủ pháp lý. Bản ghi sẽ được lưu giữ trong 5 năm theo Luật Môi giới Bất động sản.'**
  String get it_session_consent_notice;

  /// No description provided for @it_session_i_consent.
  ///
  /// In vi, this message translates to:
  /// **'Tôi đồng ý với việc ghi âm và giải thích các điều khoản quan trọng'**
  String get it_session_i_consent;

  /// No description provided for @it_session_join_zoom.
  ///
  /// In vi, this message translates to:
  /// **'Tham gia qua Zoom'**
  String get it_session_join_zoom;

  /// No description provided for @it_session_recording_notice.
  ///
  /// In vi, this message translates to:
  /// **'Thông báo ghi âm'**
  String get it_session_recording_notice;

  /// No description provided for @it_session_consent_required.
  ///
  /// In vi, this message translates to:
  /// **'Bạn phải đồng ý với việc ghi âm trước khi tham gia'**
  String get it_session_consent_required;

  /// No description provided for @econtract_title.
  ///
  /// In vi, this message translates to:
  /// **'Hợp đồng điện tử (電子契約)'**
  String get econtract_title;

  /// No description provided for @econtract_status_pending.
  ///
  /// In vi, this message translates to:
  /// **'Chờ ký'**
  String get econtract_status_pending;

  /// No description provided for @econtract_status_signed.
  ///
  /// In vi, this message translates to:
  /// **'Đã ký'**
  String get econtract_status_signed;

  /// No description provided for @econtract_status_expired.
  ///
  /// In vi, this message translates to:
  /// **'Hết hạn'**
  String get econtract_status_expired;

  /// No description provided for @econtract_status_cancelled.
  ///
  /// In vi, this message translates to:
  /// **'Đã hủy'**
  String get econtract_status_cancelled;

  /// No description provided for @econtract_sign_button.
  ///
  /// In vi, this message translates to:
  /// **'Ký hợp đồng'**
  String get econtract_sign_button;

  /// No description provided for @econtract_download_signed.
  ///
  /// In vi, this message translates to:
  /// **'Tải hợp đồng đã ký'**
  String get econtract_download_signed;

  /// No description provided for @econtract_open_external.
  ///
  /// In vi, this message translates to:
  /// **'Mở trong trình duyệt'**
  String get econtract_open_external;

  /// No description provided for @econtract_signing_note.
  ///
  /// In vi, this message translates to:
  /// **'Bạn sẽ được chuyển hướng đến dịch vụ ký. Vui lòng quay lại sau khi ký xong.'**
  String get econtract_signing_note;

  /// No description provided for @econtract_status_label.
  ///
  /// In vi, this message translates to:
  /// **'Trạng thái hợp đồng'**
  String get econtract_status_label;

  /// No description provided for @jp_renewal_eyebrow.
  ///
  /// In vi, this message translates to:
  /// **'Gia hạn'**
  String get jp_renewal_eyebrow;

  /// No description provided for @jp_renewal_title.
  ///
  /// In vi, this message translates to:
  /// **'Gia hạn hợp đồng'**
  String get jp_renewal_title;

  /// No description provided for @jp_renewal_contract_summary.
  ///
  /// In vi, this message translates to:
  /// **'Tóm tắt hợp đồng'**
  String get jp_renewal_contract_summary;

  /// No description provided for @jp_renewal_property.
  ///
  /// In vi, this message translates to:
  /// **'Bất động sản'**
  String get jp_renewal_property;

  /// No description provided for @jp_renewal_room.
  ///
  /// In vi, this message translates to:
  /// **'Số phòng'**
  String get jp_renewal_room;

  /// No description provided for @jp_renewal_current_term_end.
  ///
  /// In vi, this message translates to:
  /// **'Ngày kết thúc hiện tại'**
  String get jp_renewal_current_term_end;

  /// No description provided for @jp_renewal_new_term_end.
  ///
  /// In vi, this message translates to:
  /// **'Ngày kết thúc sau gia hạn'**
  String get jp_renewal_new_term_end;

  /// No description provided for @jp_renewal_total_fee.
  ///
  /// In vi, this message translates to:
  /// **'Tổng phí gia hạn'**
  String get jp_renewal_total_fee;

  /// No description provided for @jp_renewal_confirm_cta.
  ///
  /// In vi, this message translates to:
  /// **'Xác nhận gia hạn'**
  String get jp_renewal_confirm_cta;

  /// No description provided for @jp_renewal_decline_cta.
  ///
  /// In vi, this message translates to:
  /// **'Yêu cầu đàm phán lại'**
  String get jp_renewal_decline_cta;

  /// No description provided for @jp_renewal_confirm_title.
  ///
  /// In vi, this message translates to:
  /// **'Xác nhận gia hạn'**
  String get jp_renewal_confirm_title;

  /// No description provided for @jp_renewal_confirm_notice.
  ///
  /// In vi, this message translates to:
  /// **'Hóa đơn phí gia hạn sẽ được phát hành sau khi xác nhận.'**
  String get jp_renewal_confirm_notice;

  /// No description provided for @jp_renewal_confirm_submit.
  ///
  /// In vi, this message translates to:
  /// **'Xác nhận & Gia hạn'**
  String get jp_renewal_confirm_submit;

  /// No description provided for @jp_renewal_status_confirmed.
  ///
  /// In vi, this message translates to:
  /// **'Đã xác nhận gia hạn.'**
  String get jp_renewal_status_confirmed;

  /// No description provided for @jp_renewal_status_declined.
  ///
  /// In vi, this message translates to:
  /// **'Đã nhận yêu cầu đàm phán lại.'**
  String get jp_renewal_status_declined;

  /// No description provided for @jp_settlement_eyebrow.
  ///
  /// In vi, this message translates to:
  /// **'Hoàn trả tiền đặt cọc'**
  String get jp_settlement_eyebrow;

  /// No description provided for @jp_settlement_owner_title.
  ///
  /// In vi, this message translates to:
  /// **'Nhập các khoản khấu trừ'**
  String get jp_settlement_owner_title;

  /// No description provided for @jp_settlement_tenant_title.
  ///
  /// In vi, this message translates to:
  /// **'Xem xét kết toán'**
  String get jp_settlement_tenant_title;

  /// No description provided for @jp_settlement_deposit_summary.
  ///
  /// In vi, this message translates to:
  /// **'Tóm tắt tiền đặt cọc'**
  String get jp_settlement_deposit_summary;

  /// No description provided for @jp_settlement_property.
  ///
  /// In vi, this message translates to:
  /// **'Bất động sản'**
  String get jp_settlement_property;

  /// No description provided for @jp_settlement_room.
  ///
  /// In vi, this message translates to:
  /// **'Số phòng'**
  String get jp_settlement_room;

  /// No description provided for @jp_settlement_tenant.
  ///
  /// In vi, this message translates to:
  /// **'Người thuê'**
  String get jp_settlement_tenant;

  /// No description provided for @jp_settlement_deductions.
  ///
  /// In vi, this message translates to:
  /// **'Các khoản khấu trừ'**
  String get jp_settlement_deductions;

  /// No description provided for @jp_settlement_no_deductions.
  ///
  /// In vi, this message translates to:
  /// **'Không có khoản khấu trừ'**
  String get jp_settlement_no_deductions;

  /// No description provided for @jp_settlement_add_deduction.
  ///
  /// In vi, this message translates to:
  /// **'Thêm khoản mục'**
  String get jp_settlement_add_deduction;

  /// No description provided for @jp_settlement_remove_deduction.
  ///
  /// In vi, this message translates to:
  /// **'Xóa'**
  String get jp_settlement_remove_deduction;

  /// No description provided for @jp_settlement_deduction_item.
  ///
  /// In vi, this message translates to:
  /// **'Khoản mục'**
  String get jp_settlement_deduction_item;

  /// No description provided for @jp_settlement_deduction_title.
  ///
  /// In vi, this message translates to:
  /// **'Tên khoản mục'**
  String get jp_settlement_deduction_title;

  /// No description provided for @jp_settlement_deduction_amount.
  ///
  /// In vi, this message translates to:
  /// **'Số tiền (¥)'**
  String get jp_settlement_deduction_amount;

  /// No description provided for @jp_settlement_deduction_photos.
  ///
  /// In vi, this message translates to:
  /// **'Ảnh (tùy chọn, tối đa 3 ảnh)'**
  String get jp_settlement_deduction_photos;

  /// No description provided for @jp_settlement_net_refund.
  ///
  /// In vi, this message translates to:
  /// **'Số tiền hoàn trả'**
  String get jp_settlement_net_refund;

  /// No description provided for @jp_settlement_submit_to_tenant.
  ///
  /// In vi, this message translates to:
  /// **'Gửi cho người thuê'**
  String get jp_settlement_submit_to_tenant;

  /// No description provided for @jp_settlement_accept_cta.
  ///
  /// In vi, this message translates to:
  /// **'Đồng ý kết toán'**
  String get jp_settlement_accept_cta;

  /// No description provided for @jp_settlement_dispute_cta.
  ///
  /// In vi, this message translates to:
  /// **'Khiếu nại'**
  String get jp_settlement_dispute_cta;

  /// No description provided for @jp_settlement_dispute_title.
  ///
  /// In vi, this message translates to:
  /// **'Khiếu nại'**
  String get jp_settlement_dispute_title;

  /// No description provided for @jp_settlement_dispute_description.
  ///
  /// In vi, this message translates to:
  /// **'Vui lòng mô tả lý do khiếu nại.'**
  String get jp_settlement_dispute_description;

  /// No description provided for @jp_settlement_dispute_reason_label.
  ///
  /// In vi, this message translates to:
  /// **'Lý do khiếu nại'**
  String get jp_settlement_dispute_reason_label;

  /// No description provided for @jp_settlement_dispute_submit.
  ///
  /// In vi, this message translates to:
  /// **'Nộp khiếu nại'**
  String get jp_settlement_dispute_submit;

  /// No description provided for @jp_settlement_status_accepted.
  ///
  /// In vi, this message translates to:
  /// **'Đã đồng ý kết toán. Bắt đầu quy trình hoàn tiền.'**
  String get jp_settlement_status_accepted;

  /// No description provided for @jp_settlement_status_disputed.
  ///
  /// In vi, this message translates to:
  /// **'Đã nộp khiếu nại.'**
  String get jp_settlement_status_disputed;

  /// No description provided for @jp_kpi_eyebrow.
  ///
  /// In vi, this message translates to:
  /// **'Quản trị'**
  String get jp_kpi_eyebrow;

  /// No description provided for @jp_kpi_dashboard_title.
  ///
  /// In vi, this message translates to:
  /// **'Bảng KPI'**
  String get jp_kpi_dashboard_title;

  /// No description provided for @jp_kpi_prefecture_label.
  ///
  /// In vi, this message translates to:
  /// **'Tỉnh/thành'**
  String get jp_kpi_prefecture_label;

  /// No description provided for @jp_kpi_all_japan.
  ///
  /// In vi, this message translates to:
  /// **'Toàn Nhật Bản'**
  String get jp_kpi_all_japan;

  /// No description provided for @jp_kpi_active_listings.
  ///
  /// In vi, this message translates to:
  /// **'Tin đang đăng'**
  String get jp_kpi_active_listings;

  /// No description provided for @jp_kpi_pending_applications.
  ///
  /// In vi, this message translates to:
  /// **'Đơn đang xét duyệt'**
  String get jp_kpi_pending_applications;

  /// No description provided for @jp_kpi_active_contracts.
  ///
  /// In vi, this message translates to:
  /// **'Hợp đồng đang hoạt động'**
  String get jp_kpi_active_contracts;

  /// No description provided for @jp_kpi_avg_days_to_sign.
  ///
  /// In vi, this message translates to:
  /// **'Số ngày ký TB'**
  String get jp_kpi_avg_days_to_sign;

  /// No description provided for @jp_kpi_monthly_revenue.
  ///
  /// In vi, this message translates to:
  /// **'Doanh thu tháng'**
  String get jp_kpi_monthly_revenue;

  /// No description provided for @jp_deletion_eyebrow.
  ///
  /// In vi, this message translates to:
  /// **'Tài khoản'**
  String get jp_deletion_eyebrow;

  /// No description provided for @jp_deletion_title.
  ///
  /// In vi, this message translates to:
  /// **'Xóa tài khoản'**
  String get jp_deletion_title;

  /// No description provided for @jp_deletion_settings_subtitle.
  ///
  /// In vi, this message translates to:
  /// **'Tài khoản và toàn bộ dữ liệu sẽ bị xóa sau 30 ngày'**
  String get jp_deletion_settings_subtitle;

  /// No description provided for @jp_deletion_warning.
  ///
  /// In vi, this message translates to:
  /// **'Xóa tài khoản sẽ xóa vĩnh viễn tất cả dữ liệu bên dưới. Thao tác này không thể hoàn tác.'**
  String get jp_deletion_warning;

  /// No description provided for @jp_deletion_bullet_data.
  ///
  /// In vi, this message translates to:
  /// **'Thông tin cá nhân & hồ sơ'**
  String get jp_deletion_bullet_data;

  /// No description provided for @jp_deletion_bullet_contracts.
  ///
  /// In vi, this message translates to:
  /// **'Hợp đồng & lịch sử giao dịch'**
  String get jp_deletion_bullet_contracts;

  /// No description provided for @jp_deletion_bullet_irreversible.
  ///
  /// In vi, this message translates to:
  /// **'Thao tác này không thể hoàn tác'**
  String get jp_deletion_bullet_irreversible;

  /// No description provided for @jp_deletion_cooloff_notice.
  ///
  /// In vi, this message translates to:
  /// **'Thời gian ngâm 30 ngày áp dụng kể từ ngày yêu cầu xóa. Liên hệ hỗ trợ để hủy trong thời gian này.'**
  String get jp_deletion_cooloff_notice;

  /// No description provided for @jp_deletion_schedule_cta.
  ///
  /// In vi, this message translates to:
  /// **'Lên lịch xóa'**
  String get jp_deletion_schedule_cta;

  /// No description provided for @jp_deletion_days_remaining.
  ///
  /// In vi, this message translates to:
  /// **'ngày còn lại đến khi xóa'**
  String get jp_deletion_days_remaining;

  /// No description provided for @jp_deletion_scheduled_notice.
  ///
  /// In vi, this message translates to:
  /// **'Tài khoản của bạn đã được lên lịch xóa. Bạn có thể hủy trong thời gian ngâm.'**
  String get jp_deletion_scheduled_notice;

  /// No description provided for @jp_deletion_support_contact.
  ///
  /// In vi, this message translates to:
  /// **'Để hủy, liên hệ support@ancu365.jp.'**
  String get jp_deletion_support_contact;

  /// No description provided for @jp_deletion_cancel_cta.
  ///
  /// In vi, this message translates to:
  /// **'Hủy yêu cầu xóa'**
  String get jp_deletion_cancel_cta;

  /// No description provided for @jp_deletion_cancel_confirm_title.
  ///
  /// In vi, this message translates to:
  /// **'Hủy yêu cầu xóa'**
  String get jp_deletion_cancel_confirm_title;

  /// No description provided for @jp_deletion_cancel_confirm_body.
  ///
  /// In vi, this message translates to:
  /// **'Bạn có chắc muốn hủy yêu cầu xóa không?'**
  String get jp_deletion_cancel_confirm_body;

  /// No description provided for @jp_deletion_cancel_no.
  ///
  /// In vi, this message translates to:
  /// **'Quay lại'**
  String get jp_deletion_cancel_no;

  /// No description provided for @jp_deletion_cancel_yes.
  ///
  /// In vi, this message translates to:
  /// **'Có, Hủy'**
  String get jp_deletion_cancel_yes;

  /// No description provided for @jp_deletion_confirm_sheet_title.
  ///
  /// In vi, this message translates to:
  /// **'Xác nhận cuối cùng'**
  String get jp_deletion_confirm_sheet_title;

  /// No description provided for @jp_deletion_confirm_sheet_body.
  ///
  /// In vi, this message translates to:
  /// **'Vui lòng nhập địa chỉ email đã đăng ký để tiếp tục.'**
  String get jp_deletion_confirm_sheet_body;

  /// No description provided for @jp_deletion_confirm_email_label.
  ///
  /// In vi, this message translates to:
  /// **'Địa chỉ email'**
  String get jp_deletion_confirm_email_label;

  /// No description provided for @jp_deletion_confirm_email_hint.
  ///
  /// In vi, this message translates to:
  /// **'Nhập email đã đăng ký'**
  String get jp_deletion_confirm_email_hint;

  /// No description provided for @jp_deletion_confirm_email_error.
  ///
  /// In vi, this message translates to:
  /// **'Địa chỉ email không khớp'**
  String get jp_deletion_confirm_email_error;

  /// No description provided for @jp_deletion_confirm_submit.
  ///
  /// In vi, this message translates to:
  /// **'Lên lịch xóa'**
  String get jp_deletion_confirm_submit;

  /// No description provided for @jp_facet_pets_ok_label.
  ///
  /// In vi, this message translates to:
  /// **'Cho phép thú cưng'**
  String get jp_facet_pets_ok_label;

  /// No description provided for @jp_facet_walk_min_label.
  ///
  /// In vi, this message translates to:
  /// **'Đi bộ từ ga (phút)'**
  String get jp_facet_walk_min_label;

  /// No description provided for @jp_facet_walk_min_value.
  ///
  /// In vi, this message translates to:
  /// **'Trong vòng {min} phút đi bộ'**
  String jp_facet_walk_min_value(int min);

  /// No description provided for @jp_facet_layout_label.
  ///
  /// In vi, this message translates to:
  /// **'Kiểu phòng'**
  String get jp_facet_layout_label;

  /// No description provided for @helpCenterTitle.
  ///
  /// In vi, this message translates to:
  /// **'Trung tâm hỗ trợ'**
  String get helpCenterTitle;

  /// No description provided for @helpCenterSearchHint.
  ///
  /// In vi, this message translates to:
  /// **'Tìm kiếm câu hỏi...'**
  String get helpCenterSearchHint;

  /// No description provided for @helpCenterNoResults.
  ///
  /// In vi, this message translates to:
  /// **'Không tìm thấy kết quả nào'**
  String get helpCenterNoResults;

  /// No description provided for @helpCenterArticleNotFound.
  ///
  /// In vi, this message translates to:
  /// **'Bài viết không tìm thấy'**
  String get helpCenterArticleNotFound;

  /// No description provided for @helpCenterLoadError.
  ///
  /// In vi, this message translates to:
  /// **'Không thể tải bài viết. Vui lòng thử lại.'**
  String get helpCenterLoadError;

  /// No description provided for @helpCenterComingSoon.
  ///
  /// In vi, this message translates to:
  /// **'Nội dung đang được chuẩn bị. Vui lòng quay lại sau.'**
  String get helpCenterComingSoon;

  /// No description provided for @legalFooterTokusho.
  ///
  /// In vi, this message translates to:
  /// **'特定商取引法に基づく表記'**
  String get legalFooterTokusho;

  /// No description provided for @legalFooterTerms.
  ///
  /// In vi, this message translates to:
  /// **'Điều khoản sử dụng'**
  String get legalFooterTerms;

  /// No description provided for @legalFooterPrivacy.
  ///
  /// In vi, this message translates to:
  /// **'Chính sách bảo mật'**
  String get legalFooterPrivacy;

  /// No description provided for @legalFooterAppiRequest.
  ///
  /// In vi, this message translates to:
  /// **'Yêu cầu công khai APPI'**
  String get legalFooterAppiRequest;

  /// No description provided for @legalFooterOperator.
  ///
  /// In vi, this message translates to:
  /// **'Thông tin công ty'**
  String get legalFooterOperator;

  /// No description provided for @legalFooterCopyright.
  ///
  /// In vi, this message translates to:
  /// **'© 2026 Synora K.K. All rights reserved.'**
  String get legalFooterCopyright;
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
      <String>['en', 'ja', 'vi', 'zh'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'ja':
      return AppLocalizationsJa();
    case 'vi':
      return AppLocalizationsVi();
    case 'zh':
      return AppLocalizationsZh();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
