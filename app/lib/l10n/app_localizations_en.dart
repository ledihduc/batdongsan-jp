// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get loginAccountType => 'Account type';

  @override
  String get loginAccountTypeHint => 'Choose an account type to sign in';

  @override
  String get loginAccountTypeRequired => 'Please choose an account type';

  @override
  String get loginAccountTypeMismatch =>
      'This account does not have access to the selected role. Choose another account type or contact an administrator.';

  @override
  String get loginAccountPickerHelp =>
      'Choose the role you want to use. Your account must already have access to that role.';

  @override
  String get loginAccountPickerClose => 'Close account selection';

  @override
  String get loginRoleCustomer => 'Home seeker';

  @override
  String get loginRoleCustomerDescription =>
      'Find a home to buy or rent and track your appointments.';

  @override
  String get loginRoleSale => 'Sales / Agent';

  @override
  String get loginRoleSaleDescription =>
      'Manage customers, listings and transactions.';

  @override
  String get loginRoleOwner => 'Property owner';

  @override
  String get loginRoleOwnerDescription =>
      'Manage your properties, rooms and tenants.';

  @override
  String get loginRoleAdmin => 'Administrator';

  @override
  String get loginRoleAdminDescription =>
      'For accounts with system administration access.';

  @override
  String get loginGuestBrowse => 'Continue without signing in';

  @override
  String get appTitle => 'Vua Nhà';

  @override
  String get settingsTitle => 'Settings & privacy';

  @override
  String get settingsEyebrow => 'Account';

  @override
  String get sectionAccount => 'Account';

  @override
  String get editProfile => 'Edit profile';

  @override
  String get editProfileSub => 'Name, photo, phone number';

  @override
  String get changePassword => 'Change password';

  @override
  String get sectionPreferences => 'Preferences';

  @override
  String get language => 'Language';

  @override
  String get chooseLanguage => 'Choose language';

  @override
  String get notifications => 'Notifications';

  @override
  String get darkMode => 'Dark mode';

  @override
  String get comingSoon => 'Coming soon';

  @override
  String get logout => 'Log out';

  @override
  String get daTitle => 'Delete account';

  @override
  String get daSubtitle => 'Permanently delete your account and personal data';

  @override
  String get daDialogTitle => 'Delete account?';

  @override
  String get daDialogBody =>
      'This action CANNOT be undone. All your personal information will be deleted and you will no longer be able to sign in. Enter your password to confirm.';

  @override
  String get daPasswordHint => 'Current password';

  @override
  String get daPasswordRequired => 'Enter your password to confirm';

  @override
  String get daConfirm => 'Delete account';

  @override
  String get daSuccess => 'Your account has been deleted';

  @override
  String get daFailed => 'Failed to delete account';

  @override
  String get blockUser => 'Block this person';

  @override
  String get blockUserSub => 'You will no longer see their content';

  @override
  String get blockConfirmTitle => 'Block this person?';

  @override
  String get blockConfirmBody =>
      'You will no longer see their posts, videos and comments. You can unblock in Settings.';

  @override
  String get blockAction => 'Block';

  @override
  String get blockDone => 'User blocked';

  @override
  String get blockFailed => 'Could not block, try again later';

  @override
  String get unblock => 'Unblock';

  @override
  String get unblockDone => 'Unblocked';

  @override
  String get blockedUsersTitle => 'Blocked users';

  @override
  String get blockedUsersSub => 'Manage the people you have blocked';

  @override
  String get blockedEmpty => 'You haven\'t blocked anyone';

  @override
  String get reportComment => 'Report comment';

  @override
  String get actionsNounComment => 'comment';

  @override
  String get privacyPolicy => 'Privacy Policy';

  @override
  String get termsOfUse => 'Terms of Use';

  @override
  String get sectionLegal => 'Legal';

  @override
  String get logoutConfirm => 'Are you sure you want to log out?';

  @override
  String get loggedOut => 'Logged out';

  @override
  String get cancel => 'Cancel';

  @override
  String get vietnamese => 'Vietnamese';

  @override
  String get english => 'English';

  @override
  String get chinese => 'Chinese';

  @override
  String get loginEyebrow => 'FAST · TRANSPARENT RENTALS';

  @override
  String get loginTagline =>
      'Find, rent and list homes — simple and transparent.';

  @override
  String get loginEmail => 'Email';

  @override
  String get loginPassword => 'Password';

  @override
  String get loginForgot => 'Forgot password?';

  @override
  String get loginButton => 'Log in';

  @override
  String get loginFailed => 'Login failed';

  @override
  String get loginExitHome => 'Back to home';

  @override
  String get loginOr => 'or';

  @override
  String get loginNoAccount => 'No account yet? ';

  @override
  String get loginRegisterNow => 'Sign up now';

  @override
  String get loginDemoAccounts => 'Demo accounts';

  @override
  String get demoTenant => 'Tenant';

  @override
  String get demoHost => 'Host';

  @override
  String get demoAdmin => 'Admin';

  @override
  String get valEmailRequired => 'Enter your email';

  @override
  String get valEmailInvalid => 'Invalid email format';

  @override
  String get valPasswordRequired => 'Enter your password';

  @override
  String get loginContinueGoogle => 'Continue with Google';

  @override
  String get loginContinueFacebook => 'Continue with Facebook';

  @override
  String loginOauthMaintenance(String provider) {
    return '$provider login is under maintenance. Please try again later.';
  }

  @override
  String get demoDesigner => 'Design firm';

  @override
  String get demoBuilder => 'Builder';

  @override
  String get demoInterior => 'Interior firm';

  @override
  String get emailHint => 'you@example.com';

  @override
  String get passwordHint => 'At least 6 characters';

  @override
  String get registerEyebrow => 'Sign up';

  @override
  String get registerTitle => 'Create account';

  @override
  String get registerWelcome => 'Welcome to';

  @override
  String get registerSubtitle =>
      'Create a free account to start finding and listing homes.';

  @override
  String get registerName => 'Full name';

  @override
  String get registerPhoneOptional => 'Phone number (optional)';

  @override
  String get registerConfirmPassword => 'Confirm password';

  @override
  String get registerAgreeTerms => 'I agree to the Terms & Privacy Policy';

  @override
  String get registerNeedAgree => 'You must agree to the Terms of Service';

  @override
  String get registerFailed => 'Registration failed';

  @override
  String get registerHaveAccount => 'Already have an account? ';

  @override
  String get valRequired => 'Required';

  @override
  String get valPasswordMin => 'At least 6 characters';

  @override
  String get valPasswordMismatch => 'Passwords do not match';

  @override
  String get svcRealEstate => 'REAL ESTATE';

  @override
  String get svcRental => 'Rental homes';

  @override
  String get svcIndustrial => 'Industrial property';

  @override
  String get svcMap => 'Map';

  @override
  String get svcConstruction => 'CONSTRUCTION';

  @override
  String get svcNew => 'NEW';

  @override
  String get svcDesign => 'Design';

  @override
  String get svcBuild => 'Building';

  @override
  String get svcInterior => 'Interior';

  @override
  String get svcCommunityTitle => 'Real estate community';

  @override
  String get svcCommunitySubtitle => 'Q&A, area reviews, find roommates…';

  @override
  String get svcLeaderboardTitle => 'Partner leaderboard';

  @override
  String get svcLeaderboardSubtitle =>
      'Ranked by field: design, building, interior…';

  @override
  String get shellLoginToPostHouse => 'Sign in to list your property for rent.';

  @override
  String get shellBecomeHostTitle => 'Become a host';

  @override
  String get shellBecomeHostBody =>
      'You will post your first listing and be automatically upgraded to a host. Continue?';

  @override
  String get shellContinue => 'Continue';

  @override
  String get shellLoginToPostConstruction =>
      'Sign in to post a construction listing.';

  @override
  String get shellPostRequest => 'Post request';

  @override
  String get shellPostListing => 'Post listing';

  @override
  String get shellNavRealEstate => 'News';

  @override
  String get shellNavConstruction => 'Construction';

  @override
  String get shellNavWishlist => 'Wishlist';

  @override
  String get shellNavProfile => 'Profile';

  @override
  String get shellNavOverview => 'Overview';

  @override
  String get shellNavRooms => 'Rentals';

  @override
  String get shellNavRequests => 'Requests';

  @override
  String get shellHostBuildingsHeader => 'RENTALS · BUILDING LEDGER';

  @override
  String get drawerCommonSection => 'SHARED';

  @override
  String get hubCommonSection => 'GENERAL';

  @override
  String get drawerMessages => 'Messages';

  @override
  String get drawerSystemAdmin => 'System administration';

  @override
  String get drawerHelp => 'Help';

  @override
  String get drawerAbout => 'About';

  @override
  String get drawerRealEstateSection => 'REAL ESTATE';

  @override
  String get drawerMapPlanning => 'Property & planning map';

  @override
  String get drawerHousesForRent => 'Houses for rent';

  @override
  String get drawerIndustrialRealEstate => 'Industrial real estate';

  @override
  String get drawerPostBusinessSection => 'POST & BUSINESS';

  @override
  String get drawerConstructionBusinessSection => 'Requests & quotes';

  @override
  String get drawerPostRental => 'Post a rental listing';

  @override
  String get drawerBecomeHost => 'Become a host';

  @override
  String get drawerConstructionSection => 'CONSTRUCTION';

  @override
  String get drawerContractorDirectory => 'Contractor directory';

  @override
  String get drawerDesignLibrary => 'Design library';

  @override
  String get drawerPartnerLeaderboard => 'Partner leaderboard';

  @override
  String get drawerPostConstructionRequest => 'Post a construction request';

  @override
  String get drawerContractorChannel => 'Contractor channel';

  @override
  String get drawerTagline => 'Real estate & Construction';

  @override
  String get drawerViewProfile => 'View profile';

  @override
  String get drawerLoginPrompt =>
      'Log in to save listings, send messages and post.';

  @override
  String get drawerLoginRegister => 'Log in / Sign up';

  @override
  String get actionsNounHouse => 'listing';

  @override
  String get actionsNounPost => 'post';

  @override
  String get actionsUnsave => 'Unsave';

  @override
  String actionsSaveNoun(Object noun) {
    return 'Save $noun';
  }

  @override
  String get actionsSaveSub => 'Review later in your saved items';

  @override
  String actionsLoginToSave(Object noun) {
    return 'Sign in to save this $noun.';
  }

  @override
  String get actionsEdit => 'Edit';

  @override
  String get actionsDelete => 'Delete';

  @override
  String get actionsReportWrongInfo => 'Report incorrect info';

  @override
  String get actionsReportWrongInfoSub =>
      'Sent to the poster so they can fix it — not a complaint';

  @override
  String actionsReportNoun(Object noun) {
    return 'Report $noun';
  }

  @override
  String get actionsReportViolationSub => 'Sent to admins for review';

  @override
  String get actionsLoginToFeedback => 'Sign in to send feedback.';

  @override
  String get actionsFeedbackSent => 'Feedback sent to the poster. Thank you!';

  @override
  String get actionsReportSent => 'Report sent. Admins will review it.';

  @override
  String get actionsRateLimited =>
      'You are sending too many. Try again in a few minutes.';

  @override
  String get actionsSendFailed => 'Failed to send. Please try again.';

  @override
  String get actionsWrongInfoDesc =>
      'The poster will be notified to review it. Your identity stays private.';

  @override
  String get actionsWrongInfoHint =>
      'e.g. Price changed, already rented, wrong address…';

  @override
  String get actionsSend => 'Send';

  @override
  String get actionsChooseReason => 'Choose the most fitting reason';

  @override
  String get actionsReasonScam => 'Scam / fake listing';

  @override
  String get actionsReasonSpam => 'Spam, posted repeatedly';

  @override
  String get actionsReasonDuplicate => 'Duplicate of another listing';

  @override
  String get actionsReasonInappropriate => 'Inappropriate content';

  @override
  String get actionsReasonOther => 'Other reason';

  @override
  String get homeMenuTooltip => 'Menu';

  @override
  String get homeSearchTooltip => 'Search';

  @override
  String get worldRealEstateLabel => 'REAL ESTATE';

  @override
  String get worldConstructionLabel => 'BUILD · DESIGN';

  @override
  String get homeAdvancedFilterTooltip => 'Advanced filters';

  @override
  String get homeLoginPromptSaveContactPost =>
      'Log in to save listings, contact and post.';

  @override
  String get homeAll => 'All';

  @override
  String get homeRealEstateReels => 'Real estate reels';

  @override
  String get homeNoMoreRooms => '— No more rooms —';

  @override
  String get homeLoadListFailed => 'Couldn\'t load listings';

  @override
  String get homeNoMatchingListings => 'No matching listings yet';

  @override
  String get homeCheckNetworkRetry =>
      'Check your network connection and try again.';

  @override
  String get homeTryRemoveFilters =>
      'Try removing some filters to see more listings.';

  @override
  String get homeRetry => 'Retry';

  @override
  String get homeClearFilters => 'Clear filters';

  @override
  String get homeLoginToSaveFavorite => 'Log in to save favorite listings.';

  @override
  String get homeHost => 'Host';

  @override
  String get homeSave => 'Save';

  @override
  String get homeContact => 'Contact';

  @override
  String get homeDetails => 'Details';

  @override
  String get homeLoginToMessageHost => 'Log in to message the host.';

  @override
  String homeAreaM2(Object area) {
    return '$area m²';
  }

  @override
  String homeDistanceAway(Object distance) {
    return '$distance away';
  }

  @override
  String get homeFull => 'FULL';

  @override
  String homeAvailableUnits(Object available, Object total) {
    return '$available/$total LEFT';
  }

  @override
  String get homeTabRent => 'For rent';

  @override
  String get homeTabSale => 'For sale';

  @override
  String get homeFilterRent => 'Filter: For rent';

  @override
  String get homeFilterSale => 'Filter: For sale';

  @override
  String get filterTitle => 'Search & Filters';

  @override
  String get filterReset => 'Reset';

  @override
  String get filterSectionSearchArea => 'Search area';

  @override
  String get filterSectionPriceRange => 'Price range';

  @override
  String get filterMaxPriceLabel => 'Max price:';

  @override
  String filterPriceValueVnd(Object value) {
    return '${value}M VND';
  }

  @override
  String filterPriceValueShort(Object value) {
    return '${value}M';
  }

  @override
  String get filterSectionArea => 'Area (m²)';

  @override
  String get filterAreaFrom => 'From';

  @override
  String get filterAreaTo => 'To';

  @override
  String get filterSectionBedrooms => 'Bedrooms';

  @override
  String get filterAny => 'Any';

  @override
  String get filterSectionPropertyType => 'Property type';

  @override
  String get filterClearAll => 'Clear all';

  @override
  String get filterApply => 'Apply filters';

  @override
  String get filterModeAll => 'All';

  @override
  String get filterModeNearby => 'Nearby';

  @override
  String get filterModePlace => 'Place';

  @override
  String get filterPlaceHint => 'Enter a place: \"near Bach Khoa University\"…';

  @override
  String get filterLocationUpdate => 'Location set — tap to update';

  @override
  String get filterGetCurrentLocation => 'Get current location';

  @override
  String get filterRadiusLabel => 'Radius:';

  @override
  String filterRadiusKm(Object value) {
    return '$value km';
  }

  @override
  String get filterLocationAcquired => 'Your location has been captured ✓';

  @override
  String get filterLocServiceOff =>
      'Location is off on your device. Turn it on and try again.';

  @override
  String get filterLocDenied =>
      'Location permission is required. Try again and allow it.';

  @override
  String get filterLocDeniedForever =>
      'Location permission is blocked — open Settings to grant it.';

  @override
  String get filterLocOutOfVietnam => 'Location is outside the service area.';

  @override
  String get filterLocError => 'Couldn\'t get your location. Try again.';

  @override
  String get filterPrimingTitle => 'Find rooms near you';

  @override
  String get filterPrimingBody =>
      'Enable location to see the closest rooms with accurate distances. Vua Nhà only uses your location when you search nearby.';

  @override
  String get filterPrimingLater => 'Later';

  @override
  String get filterEnableLocation => 'Enable location';

  @override
  String get filterNeedLocationFirst =>
      'Please get your current location before applying.';

  @override
  String get addProjPdfUploadError => 'Couldn\'t upload the PDF file';

  @override
  String get addProjTitleRequired => 'Enter the project name';

  @override
  String get addProjWaitImages =>
      'Please wait for the images to finish uploading';

  @override
  String get addProjNeedImage => 'Add at least 1 photo for the project';

  @override
  String get addProjUpdated => 'Updated';

  @override
  String get addProjPosted =>
      'Posted. Your submission will be verified by admins.';

  @override
  String addProjError(Object error) {
    return 'Error: $error';
  }

  @override
  String get addProjEyebrow => 'Provider channel';

  @override
  String addProjEditTitle(Object type) {
    return 'Edit $type';
  }

  @override
  String get addProjTypeDesign => 'design';

  @override
  String get addProjTypeWork => 'project';

  @override
  String get addProjCreateDesign => 'Post a design';

  @override
  String get addProjCreateWork => 'Post a project';

  @override
  String addProjPhotoSection(Object type) {
    return '$type photos';
  }

  @override
  String get addProjPhotoHelper =>
      'The first photo is the cover. Long-press to set cover/delete. Up to 10 photos.';

  @override
  String get addProjBasicInfo => 'Basic information';

  @override
  String get addProjTitleLabel => 'Project name';

  @override
  String get addProjTitleHintDesign => 'E.g. Modern 3-storey villa 9x16m';

  @override
  String get addProjTitleHintWork =>
      'E.g. 3-storey townhouse for Mr. Nam - District 7';

  @override
  String get addProjDescLabel => 'Description';

  @override
  String get addProjDescHint => 'Scale, materials, highlights…';

  @override
  String get addProjFieldLabel => 'Field';

  @override
  String get addProjFieldBuild => 'Construction';

  @override
  String get addProjFieldInterior => 'Interior';

  @override
  String get addProjYearLabel => 'Year completed';

  @override
  String get addProjSpecsTitle => 'House model specifications';

  @override
  String get addProjSpecsHelper =>
      'Helps the model appear in the right Design Library filters.';

  @override
  String get addProjHouseTypeLabel => 'House type';

  @override
  String get addProjStyleLabel => 'Style';

  @override
  String get addProjFloorsLabel => 'Number of floors';

  @override
  String get addProjBedroomsLabel => 'Bedrooms';

  @override
  String get addProjWidthLabel => 'Land width (m)';

  @override
  String get addProjLengthLabel => 'Land length (m)';

  @override
  String get addProjAreaLabel => 'Built area (m²)';

  @override
  String get addProjCostLabel => 'Reference price (VND)';

  @override
  String get addProjCostHint => 'Leave blank if not available';

  @override
  String get addProjPdfSection => 'Design documents (PDF)';

  @override
  String get addProjPdfHelper =>
      'Drawings/documents — will be verified by admins. Up to 10 files.';

  @override
  String addProjPdfItem(Object number) {
    return 'Document $number';
  }

  @override
  String get addProjUploading => 'Uploading…';

  @override
  String get addProjAddPdf => 'Add PDF file';

  @override
  String get addProjSaveChanges => 'Save changes';

  @override
  String get addProjSubmit => 'Post';

  @override
  String get addProjSegWork => 'Completed projects';

  @override
  String get addProjSegDesign => 'Design template';

  @override
  String get bkDetEyebrow => 'Booking';

  @override
  String get bkDetTitle => 'Appointment details';

  @override
  String get bkDetCancelAppointment => 'Cancel appointment';

  @override
  String get bkDetCancelConfirm =>
      'Are you sure you want to cancel this viewing appointment?';

  @override
  String get bkDetClose => 'Close';

  @override
  String get bkDetCancelBooking => 'Cancel booking';

  @override
  String get bkDetCancelFailed => 'Cancellation failed — please try again.';

  @override
  String bkDetPhoneCopied(Object phone) {
    return 'Copied number $phone — open your phone app to call.';
  }

  @override
  String get bkDetHostNotFound => 'Host information not found.';

  @override
  String get bkDetHost => 'Host';

  @override
  String get bkDetApartment => 'Apartment';

  @override
  String get bkDetRoomImage => 'Room photo';

  @override
  String get bkDetScheduleTitle => 'Appointment';

  @override
  String get bkDetViewDate => 'Viewing date';

  @override
  String get bkDetTime => 'Time';

  @override
  String get bkDetSentAt => 'Sent at';

  @override
  String get bkDetYourMessage => 'Your message';

  @override
  String get bkDetNoMessage => 'No message.';

  @override
  String get bkDetHostInfo => 'Host information';

  @override
  String get bkDetMessage => 'Message';

  @override
  String get bkDetProgress => 'Progress';

  @override
  String get bkDetStepRequested => 'Request sent';

  @override
  String get bkDetStepApproved => 'Host approved';

  @override
  String get bkDetStepCompleted => 'Viewing completed';

  @override
  String get bkDetStepBooked => 'Room booked';

  @override
  String get bkDetStepRejected => 'Host declined';

  @override
  String get bkDetStepCancelled => 'You cancelled';

  @override
  String get bkDetStepLost => 'Booked by someone else';

  @override
  String get bkDetStepEnded => 'Ended';

  @override
  String get bkDetCall => 'Call';

  @override
  String get bkDetReviewed => 'Reviewed';

  @override
  String get bkDetWriteReview => 'Write a review';

  @override
  String get bkDetExploreOther => 'Browse other homes';

  @override
  String get bkHistEyebrow => 'Account';

  @override
  String get bkHistTitle => 'Booking history';

  @override
  String get bkHistRefresh => 'Refresh';

  @override
  String get bkHistTabPending => 'Pending';

  @override
  String get bkHistTabApproved => 'Approved';

  @override
  String get bkHistCompleted => 'Completed';

  @override
  String get bkHistFilterAll => 'All';

  @override
  String get bkHistStatusLocked => 'Room booked';

  @override
  String get bkHistStatusCancelled => 'Cancelled';

  @override
  String get bkHistStatusRejected => 'Rejected';

  @override
  String get bkHistStatusLost => 'Taken by someone else';

  @override
  String get bkHistSearchHint => 'Search by name / address...';

  @override
  String get bkHistClearSearch => 'Clear search';

  @override
  String get bkHistRoomPhoto => 'Room photo';

  @override
  String get bkHistDefaultHouseTitle => 'Premium apartment';

  @override
  String get bkHistCallHost => 'Call host';

  @override
  String get bkHistMessage => 'Message';

  @override
  String get bkHistReviewed => 'Reviewed';

  @override
  String get bkHistReview => 'Review';

  @override
  String get bkHistApartment => 'Apartment';

  @override
  String get bkHistViewOtherHouses => 'View other houses';

  @override
  String get bkHistCancelTitle => 'Cancel appointment';

  @override
  String get bkHistCancelConfirm =>
      'Are you sure you want to cancel this appointment?';

  @override
  String get bkHistClose => 'Close';

  @override
  String get bkHistCancelAppointment => 'Cancel appointment';

  @override
  String get bkHistCancelSuccess => 'Appointment cancelled';

  @override
  String get bkHistCancelFailed => 'Cancellation failed';

  @override
  String get bkHistNoHostPhone => 'Host phone number not available';

  @override
  String bkHistPhoneCopied(Object phone) {
    return 'Number copied: $phone';
  }

  @override
  String get bkHistHostNotFound => 'Host not found';

  @override
  String get bkHistHost => 'Host';

  @override
  String get bkHistNoRequests => 'No requests';

  @override
  String get bkHistNoResults => 'No results found';

  @override
  String get bkHistSearchEmpty =>
      'Try a different keyword or clear the search filter.';

  @override
  String get bkHistEmptyHint => 'Your booking requests will appear here.';

  @override
  String get bkSchedSuccessMessage =>
      'Your appointment request was sent successfully!';

  @override
  String get bkSchedSubmitFailed => 'Failed to send request';

  @override
  String get bkSchedEyebrow => 'Booking';

  @override
  String get bkSchedAppBarTitle => 'Schedule a viewing';

  @override
  String get bkSchedCardHeader => 'Book a house viewing appointment';

  @override
  String get bkSchedStep1 => '1. Choose a viewing date';

  @override
  String bkSchedDateLabel(Object date) {
    return 'Date: $date';
  }

  @override
  String get bkSchedStep2 => '2. Choose a time slot (1 hour each)';

  @override
  String get bkSchedStep3 => '3. Message to the host (Optional)';

  @override
  String get bkSchedMessageHint =>
      'E.g.: I\'d like to ask more about car parking, or I\'ll bring a friend along...';

  @override
  String get bkSchedSelectSlotPrompt => 'Please choose a time slot';

  @override
  String get bkSchedSubmit => 'Send booking request';

  @override
  String get bkSchedAfterSubmitTitle => 'After you send the request';

  @override
  String get bkSchedAfterSubmitDesc =>
      'The host will be notified and confirm your request within 2 business hours at most.';

  @override
  String get bkSchedCancelPolicyTitle => 'Cancellation policy';

  @override
  String get bkSchedCancelPolicyDesc =>
      'You can change or cancel your viewing for free up to 4 hours before the appointed time.';

  @override
  String get bkSchedRetry => 'Try again';

  @override
  String get bkSchedNoSlots =>
      'No available time slots for this date. Please choose another day.';

  @override
  String get ccompTitle => 'Post construction';

  @override
  String get ccompSend => 'Send';

  @override
  String get ccompPost => 'Post';

  @override
  String get ccompYou => 'You';

  @override
  String get ccompGuestName => 'Guest';

  @override
  String get ccompIntentShare => 'Share project';

  @override
  String get ccompIntentNeed => 'Need construction';

  @override
  String get ccompContentHintNeed =>
      'What do you need built? Describe your needs and current state…';

  @override
  String get ccompContentHintShare => 'Share a project you just completed…';

  @override
  String get ccompServiceBuild => 'Construction';

  @override
  String get ccompServiceDesign => 'Design';

  @override
  String get ccompServiceInterior => 'Interior';

  @override
  String get ccompServiceIndustrial => 'Industrial';

  @override
  String get ccompPhoneHint => 'Phone number *';

  @override
  String get ccompAreaHint => 'Area (e.g. 80m²)';

  @override
  String get ccompBudgetHint => 'Estimated budget';

  @override
  String get ccompLocationOptional => 'Location (optional)';

  @override
  String get ccompSelectProvince => 'Select province/city';

  @override
  String get ccompLoading => 'Loading…';

  @override
  String get ccompSelectWard => 'Select ward/commune';

  @override
  String get ccompMapHint =>
      'Tap the map to pin a location (address auto-fills).';

  @override
  String ccompPinnedWard(Object ward) {
    return 'Pinned: $ward';
  }

  @override
  String ccompPinnedCoords(Object lat, Object lng) {
    return 'Pinned: $lat, $lng';
  }

  @override
  String ccompPhotosCount(Object count, Object max) {
    return 'Photos ($count/$max)';
  }

  @override
  String get ccompLocation => 'Location';

  @override
  String get ccompImagePickFailed => 'Could not select images';

  @override
  String get ccompSubmitFailed => 'Failed to post, try again';

  @override
  String get cleadTitle => 'Partner leaderboard';

  @override
  String get cleadSubtitle => 'Ranked by reputation & reviews';

  @override
  String get cleadTradeDesign => 'Design';

  @override
  String get cleadTradeBuild => 'Construction';

  @override
  String get cleadTradeInterior => 'Interior';

  @override
  String get cleadTradeIndustrial => 'Industrial real estate';

  @override
  String get cleadLoadError => 'Could not load the partner list';

  @override
  String get cleadEmptyTitle => 'No partners in this trade yet';

  @override
  String get cleadEmptySubtitle => 'Try another trade or come back later.';

  @override
  String get cleadFallbackCompany => 'Partner';

  @override
  String get cleadNoRating => 'No reviews yet';

  @override
  String cleadRatingCount(Object rating, Object count) {
    return '⭐ $rating ($count reviews)';
  }

  @override
  String cleadRatingNew(Object rating, Object count) {
    return '⭐ $rating · $count reviews (new)';
  }

  @override
  String get cleadBadgeFeatured => 'Featured';

  @override
  String get cleadBadgePro => 'Pro';

  @override
  String get cleadBadgeVerified => 'Verified';

  @override
  String get compareTitle => 'Compare properties';

  @override
  String get compareEmpty => 'No properties to compare';

  @override
  String get compareCriteria => 'Criteria';

  @override
  String get compareHouseFallback => 'Property';

  @override
  String get compareLabelPrice => 'Price';

  @override
  String get compareLabelArea => 'Area';

  @override
  String get compareLabelPricePerSqm => 'Price/m²';

  @override
  String get compareLabelLegal => 'Legal status';

  @override
  String get compareLabelBedrooms => 'Bedrooms';

  @override
  String get compareLabelBathrooms => 'Bathrooms';

  @override
  String get compareLabelLocation => 'Location';

  @override
  String get ctrContractor => 'Contractor';

  @override
  String get ctrLoadFailed => 'Failed to load';

  @override
  String get ctrRequestQuote => 'Request a quote';

  @override
  String ctrContractorRatingSubtitle(Object rating, Object count) {
    return 'Contractor · ⭐ $rating ($count reviews)';
  }

  @override
  String get ctrTrustedUnit => 'Trusted unit';

  @override
  String get ctrVerified => 'Verified';

  @override
  String get ctrCertVerified => 'Professional certificate';

  @override
  String get ctrProjectsStat => 'Projects';

  @override
  String get ctrVerifiedLabel => 'Vetted';

  @override
  String get ctrDesignFilesStat => 'Design files';

  @override
  String get ctrReviewsStat => 'Reviews';

  @override
  String ctrYearsExperience(Object yrs) {
    return '$yrs years of experience';
  }

  @override
  String ctrEstablished(Object year) {
    return 'Established $year';
  }

  @override
  String ctrTeamSize(Object team) {
    return 'Team of $team people';
  }

  @override
  String get ctrWebsite => 'Website';

  @override
  String get ctrPortfolioTitle => 'COMPLETED PROJECTS';

  @override
  String get ctrNoProjects => 'No projects yet';

  @override
  String get ctrNoProjectsSubtitle =>
      'This unit hasn\'t posted any projects. Send a request for direct consultation.';

  @override
  String get ctrFilterAll => 'All';

  @override
  String get ctrFilterHasFiles => 'Has design files';

  @override
  String get ctrNoMatchFilter => 'No projects match the filter.';

  @override
  String get ctrProject => 'Project';

  @override
  String ctrFilesCount(Object count) {
    return '$count files';
  }

  @override
  String ctrReviewsTitle(Object count) {
    return 'REVIEWS ($count)';
  }

  @override
  String get ctrNoReviews => 'No reviews yet';

  @override
  String get ctrNoReviewsSubtitle =>
      'Be the first customer to review this unit.';

  @override
  String get ctrCriteriaQuality => 'Quality';

  @override
  String get ctrCriteriaTimeliness => 'Timeliness';

  @override
  String get ctrCriteriaCommunication => 'Communication';

  @override
  String get ctrCriteriaBudget => 'Budget';

  @override
  String get ctrCriteriaProfessionalism => 'Professionalism';

  @override
  String get ctrCriteriaBreakdownTitle => 'BREAKDOWN BY CRITERIA';

  @override
  String ctrReviewCount(Object count) {
    return '$count reviews';
  }

  @override
  String get ctrNotEnoughReviews => 'Not enough reviews for a detailed rating.';

  @override
  String get ctrUser => 'User';

  @override
  String get cwLoginToJoinCommunity =>
      'Log in to join the construction community.';

  @override
  String get cwConstructionReels => 'Construction Reels';

  @override
  String get cwPostDeleted => 'Post deleted';

  @override
  String get cwPostRemovedModeration => 'Post removed (moderation)';

  @override
  String cwErrorWithMsg(Object msg) {
    return 'Error: $msg';
  }

  @override
  String get cwProject => 'Project';

  @override
  String cwLocationPin(Object location) {
    return '📍 $location';
  }

  @override
  String get cwViewContractor => 'View contractor';

  @override
  String get cwShare => 'Share';

  @override
  String get cwCopyLinkFromBrowser => 'Copy the link from your browser';

  @override
  String get cwNeedConstruction => 'Need construction';

  @override
  String get cwQuote => 'Quote';

  @override
  String get cwNeedContractorProfile =>
      'You need a contractor profile to send quotes (Personal → Contractor channel).';

  @override
  String get cwQuoteSent => 'Quote sent to the customer';

  @override
  String get cwContractor => 'Contractor';

  @override
  String get cwCatAll => 'All';

  @override
  String get cwCatDesign => 'Design';

  @override
  String get cwCatBuild => 'Construction';

  @override
  String get cwCatInterior => 'Interior';

  @override
  String get cwCatIndustrial => 'Industrial';

  @override
  String get cwFeaturedContractors => 'Featured contractors';

  @override
  String get cwViewAllDesignsGrid => 'View all designs in a grid';

  @override
  String cwNoContentInCategory(Object category) {
    return 'No content in $category yet';
  }

  @override
  String get cwBeFirstToShare =>
      'Be the first to share a project or post a request.';

  @override
  String get cwSendQuote => 'Send quote';

  @override
  String get cwAmountVnd => 'Amount (VND) *';

  @override
  String get cwAmountHint => 'e.g. 1500000000';

  @override
  String get cwNoteOptional => 'Note (optional)';

  @override
  String get cwSend => 'Send';

  @override
  String get designAppBarEyebrow => 'CONSTRUCTION';

  @override
  String get designLibraryTitle => 'Design library';

  @override
  String get designPostDesign => 'Post design';

  @override
  String get designAll => 'All';

  @override
  String get designHouseType => 'House type';

  @override
  String get designStyle => 'Style';

  @override
  String get designFloors => 'Floors';

  @override
  String designFloorsValue(Object floors) {
    return '$floors floors';
  }

  @override
  String get designBedroomsLabel => 'Bedrooms';

  @override
  String get designBedroomsTitle => 'Number of bedrooms';

  @override
  String designBedroomsShort(Object bedrooms) {
    return '$bedrooms BR';
  }

  @override
  String designBedroomsValue(Object bedrooms) {
    return '$bedrooms bedrooms';
  }

  @override
  String designAreaValue(Object area) {
    return '${area}m²';
  }

  @override
  String get designVerified => 'Verified';

  @override
  String get designClearFilters => 'Clear filters';

  @override
  String get designLoadError => 'Couldn\'t load the library';

  @override
  String get designLoadErrorSubtitle => 'Check your connection and try again.';

  @override
  String get designRetry => 'Retry';

  @override
  String get designEmptyFilteredTitle => 'No matching designs';

  @override
  String get designEmptyTitle => 'No designs yet';

  @override
  String get designEmptyFilteredSubtitle =>
      'Try removing some filters to see more designs.';

  @override
  String get designEmptySubtitle =>
      'Design firms will post house designs here. Check back later.';

  @override
  String get designPostYourDesign => 'Post your design';

  @override
  String get designEndOfList => '— End —';

  @override
  String get designDefaultTitle => 'Design';

  @override
  String get designUnitFallback => 'Unit';

  @override
  String get designDesignUnitFallback => 'Design unit';

  @override
  String editProfUploadError(Object error) {
    return 'Upload error: $error';
  }

  @override
  String get editProfCoverChanged => 'Cover photo changed';

  @override
  String get editProfCoverChangeFailed => 'Failed to change cover photo';

  @override
  String get editProfPickBirthday => 'Select date of birth';

  @override
  String get editProfWaitUpload =>
      'Please wait for the image to finish uploading';

  @override
  String get editProfSaved => 'Profile updated';

  @override
  String get editProfUpdateFailed => 'Update failed';

  @override
  String get editProfEmailInUse => 'Email is already in use';

  @override
  String get editProfEyebrow => 'Account';

  @override
  String get editProfChangeCover => 'Change cover photo (host)';

  @override
  String get editProfSectionPersonal => 'Personal information';

  @override
  String get editProfFullName => 'Full name';

  @override
  String get editProfRequired => 'Required';

  @override
  String get editProfEmailHelper => 'Email used to sign in';

  @override
  String get editProfEmailInvalid => 'Invalid email';

  @override
  String get editProfPhone => 'Phone number';

  @override
  String get editProfSectionIntro => 'About';

  @override
  String get editProfBioLabel => 'About yourself';

  @override
  String get editProfBioHint =>
      'E.g.: I\'m a host in District 1 with 5 years renting apartments...';

  @override
  String get editProfSectionVerify => 'Verification (optional)';

  @override
  String get editProfIdNumber => 'ID card number';

  @override
  String get editProfIdHelper => 'Leave blank if you don\'t want to verify yet';

  @override
  String get editProfSave => 'Save changes';

  @override
  String get editProfNotSelected => 'Not selected';

  @override
  String get editProfBirthday => 'Date of birth';

  @override
  String editProfAge(Object age) {
    return 'Age: $age';
  }

  @override
  String get hdBack => 'Back';

  @override
  String get hdShare => 'Share';

  @override
  String get hdLinkCopied => 'Link copied';

  @override
  String hdImageLabel(Object title, Object n) {
    return '$title — photo $n';
  }

  @override
  String get hdPerMonth => '/month';

  @override
  String get hdLoanCalc => 'Calculate bank loan';

  @override
  String hdBedroomsShort(Object n) {
    return '$n bed';
  }

  @override
  String hdBathroomsShort(Object n) {
    return '$n bath';
  }

  @override
  String hdAreaSqm(Object area) {
    return '$area m²';
  }

  @override
  String get hdDescriptionTitle => 'DETAILED DESCRIPTION';

  @override
  String get hdHostInfoTitle => 'HOST INFORMATION';

  @override
  String get hdLoginToSave => 'Log in to save favorites.';

  @override
  String get hdFavUpdateFailed => 'Could not update favorites';

  @override
  String get hdApptApprovedTitle => 'Viewing approved';

  @override
  String hdApptApprovedSub(Object sched) {
    return '$sched · Please arrive on time';
  }

  @override
  String get hdApptRejectedTitle => 'Viewing declined';

  @override
  String get hdApptRejectedSub => 'You can choose another time slot';

  @override
  String get hdApptCancelledTitle => 'You cancelled the viewing';

  @override
  String get hdApptCancelledSub => 'Book again if you still want to view';

  @override
  String get hdApptCompletedTitle => 'You have viewed this home';

  @override
  String get hdApptLockedTitle => 'Room has been locked';

  @override
  String get hdApptPendingTitle => 'You booked a viewing';

  @override
  String hdApptPendingSub(Object sched) {
    return '$sched · Awaiting host approval';
  }

  @override
  String get hdLegalRedBook => 'Red book';

  @override
  String get hdLegalPinkBook => 'Pink book';

  @override
  String get hdLegalSaleContract => 'Sale contract';

  @override
  String get hdLegalPending => 'Awaiting certificate';

  @override
  String hdPricePerMonth(Object s) {
    return '$s million/month';
  }

  @override
  String get hdSpecPrice => 'Price';

  @override
  String get hdSpecArea => 'Area';

  @override
  String get hdSpecBedrooms => 'Bedrooms';

  @override
  String get hdSpecBathrooms => 'Bathrooms';

  @override
  String get hdSpecType => 'Type';

  @override
  String get hdSpecLegal => 'Legal status';

  @override
  String get hdSpecFurniture => 'Furnishing';

  @override
  String hdRoomsCount(Object n) {
    return '$n rooms';
  }

  @override
  String get hdPropertySpecsTitle => 'PROPERTY DETAILS';

  @override
  String get hdYourListing => 'Your listing';

  @override
  String get hdViewBooking => 'View booking';

  @override
  String get hdRebookViewing => 'Rebook viewing';

  @override
  String get hdBookViewing => 'Book a viewing';

  @override
  String get hdLoginToBook => 'Log in to book a viewing.';

  @override
  String hdAreaHa(Object area) {
    return '$area ha';
  }

  @override
  String get hdIndPower => 'Power capacity';

  @override
  String hdPowerMva(Object power) {
    return '$power MVA';
  }

  @override
  String get hdIndFireSafety => 'Fire safety';

  @override
  String get hdHas => 'Yes';

  @override
  String get hdHasNot => 'No';

  @override
  String get hdIndLegal => 'Industrial park legal';

  @override
  String get hdIndustrialSpecsTitle => 'INDUSTRIAL SPECS';

  @override
  String get hdForSale => 'For sale';

  @override
  String get hdFull => 'Full';

  @override
  String hdUnitsAvailable(Object available, Object total) {
    return '$available/$total rooms left';
  }

  @override
  String get hdAvailable => 'Available';

  @override
  String get hdHost => 'Host';

  @override
  String get hdHostVerifiedTooltip => 'Host identity verified';

  @override
  String get hdHostTrustedTooltip =>
      'Trusted host: highly rated, responds quickly';

  @override
  String hdResponseTime(Object h) {
    return 'Responds in ~${h}h';
  }

  @override
  String get hdHidden => '· hidden';

  @override
  String get hdMessageHost => 'Message the host';

  @override
  String get hdReviewsTitle => 'REVIEWS';

  @override
  String get hdNoReviews => 'No reviews yet.';

  @override
  String hdViewAllReviews(Object count) {
    return 'View all $count reviews';
  }

  @override
  String get hdUser => 'User';

  @override
  String get hubProviderChannel => 'Provider channel';

  @override
  String get hubEnterNameSelectService =>
      'Enter the unit name and select at least 1 service';

  @override
  String get hubProfileSubmitted =>
      'Profile submitted. Awaiting approval to appear in the directory.';

  @override
  String hubErrorWithMsg(Object error) {
    return 'Error: $error';
  }

  @override
  String get hubBecomeProvider => 'Become a provider';

  @override
  String get hubRegisterService => 'Register to provide services';

  @override
  String get hubRegisterIntro =>
      'Register to receive customer requests and promote your unit (design / construction / interior).';

  @override
  String get hubUnitName => 'Unit name *';

  @override
  String get hubUnitNameHint => 'e.g. Kien An Construction';

  @override
  String get hubField => 'Field *';

  @override
  String get hubOperatingArea => 'Operating area';

  @override
  String get hubSelectProvince => 'Select province/city';

  @override
  String get hubIntro => 'Introduction';

  @override
  String get hubIntroHint => 'Experience, strengths, scale...';

  @override
  String get hubContactPhone => 'Contact phone number';

  @override
  String get hubSubmitRegistration => 'Submit registration';

  @override
  String get hubOwnerContact => 'Owner contact';

  @override
  String hubNameLabel(Object name) {
    return 'Name: $name';
  }

  @override
  String hubPhoneLabel(Object phone) {
    return 'Phone: $phone';
  }

  @override
  String get hubClose => 'Close';

  @override
  String get hubOwnerNotShared =>
      'The owner hasn\'t shared their contact yet. Please wait.';

  @override
  String hubCantViewContact(Object msg) {
    return 'Can\'t view contact: $msg';
  }

  @override
  String get hubEditProfile => 'Edit unit profile';

  @override
  String get hubAddCover => 'Add cover image';

  @override
  String get hubChangeLogo => 'Change unit logo';

  @override
  String get hubPhone => 'Phone number';

  @override
  String get hubWebsite => 'Website (if any)';

  @override
  String get hubYearEstablished => 'Year established';

  @override
  String get hubTeamSize => 'Team size';

  @override
  String hubPeopleSuffix(Object size) {
    return '$size people';
  }

  @override
  String get hubCertNumber => 'Professional license number (if any)';

  @override
  String get hubCertHelper => 'Admins will verify and grant a badge';

  @override
  String get hubCancel => 'Cancel';

  @override
  String get hubSave => 'Save';

  @override
  String get hubNameRequired => 'Unit name cannot be empty';

  @override
  String get hubProfileUpdated => 'Profile updated';

  @override
  String get hubDeleteProjectTitle => 'Delete project?';

  @override
  String hubDeleteProjectConfirm(Object title) {
    return 'Remove \"$title\" from your profile? This cannot be undone.';
  }

  @override
  String get hubThisProject => 'this project';

  @override
  String get hubDelete => 'Delete';

  @override
  String get hubDeleted => 'Deleted';

  @override
  String hubImageUploadFailed(Object error) {
    return 'Couldn\'t upload image: $error';
  }

  @override
  String get hubQuoteSent => 'Quote sent to the customer';

  @override
  String get hubUnit => 'Unit';

  @override
  String get hubActive => 'Active';

  @override
  String get hubPendingApproval => 'Pending approval';

  @override
  String get hubCertificate => 'Certificate';

  @override
  String get hubPendingNote =>
      'Your profile is awaiting admin approval. You can still view requests and send quotes; your profile will appear in the directory after approval.';

  @override
  String get hubEditProfileShort => 'Edit profile';

  @override
  String get hubPostProject => 'Post project';

  @override
  String get hubMatchingNeeds => 'MATCHING NEEDS';

  @override
  String get hubNoMatchingNeeds => 'No matching needs yet. Check back later.';

  @override
  String get hubMyQuotes => 'MY QUOTES';

  @override
  String get hubProjectsDesigns => 'PROJECTS & DESIGN SAMPLES';

  @override
  String get hubNoProjects => 'No projects yet';

  @override
  String get hubNoProjectsSub =>
      'Post completed projects or design samples so customers can see your capability.';

  @override
  String get hubPostFirstProject => 'Post your first project';

  @override
  String get hubService => 'Service';

  @override
  String get hubContactsYou => 'Contacts you';

  @override
  String get hubSendQuote => 'Send quote';

  @override
  String get hubWon => 'Won';

  @override
  String get hubNotSelected => 'Not selected';

  @override
  String get hubWaiting => 'Waiting';

  @override
  String get hubRequest => 'Request';

  @override
  String hubQuoteAmount(Object amount) {
    return 'Quote: $amount';
  }

  @override
  String hubMilestoneLine(Object label, Object percent, Object amount) {
    return '• $label ($percent%): $amount';
  }

  @override
  String get hubViewContact => 'View contact';

  @override
  String get hubWaitOwnerShare => 'Waiting for the owner to share contact';

  @override
  String get hubBillion => 'billion';

  @override
  String get hubMillion => 'million';

  @override
  String get hubDong => 'VND';

  @override
  String get hubProject => 'Project';

  @override
  String get hubVerified => 'Verified';

  @override
  String get hubSelfPosted => 'Self-posted';

  @override
  String hubDesignFiles(Object count) {
    return '$count design files';
  }

  @override
  String get hubEdit => 'Edit';

  @override
  String get hubAmount => 'Amount (VND) *';

  @override
  String get hubAmountHint => 'e.g. 1500000000';

  @override
  String get hubNoteOptional => 'Note (optional)';

  @override
  String get hubSplitStages => 'Split by stages (30/20/20/30)';

  @override
  String get hubStagesSubtitle => 'Deposit · Concept · Technical · Handover';

  @override
  String get hubSend => 'Send';

  @override
  String get myReqTitle => 'My service requests';

  @override
  String get myReqEmpty => 'You haven\'t booked any service';

  @override
  String get myReqContactSharedToast =>
      'Phone number shared with the contractor';

  @override
  String myReqShareError(Object error) {
    return 'Could not share: $error';
  }

  @override
  String get myReqQuoteAccepted => 'Quote accepted';

  @override
  String myReqAcceptError(Object error) {
    return 'Cannot accept: $error';
  }

  @override
  String get myReqReviewThanks => 'Thanks for your review!';

  @override
  String myReqReviewError(Object error) {
    return 'Error: $error';
  }

  @override
  String get myReqServiceDesign => 'Design';

  @override
  String get myReqServiceBuild => 'Construction';

  @override
  String get myReqServiceInterior => 'Interior';

  @override
  String get myReqServiceDefault => 'Service';

  @override
  String get myReqStatusNew => 'Sent';

  @override
  String get myReqStatusAssigned => 'Contractor connected';

  @override
  String get myReqStatusQuoted => 'Quote received';

  @override
  String get myReqStatusWon => 'Closed deal';

  @override
  String get myReqStatusClosed => 'Closed';

  @override
  String get myReqNoQuotes => 'No quotes yet. Contractors will respond soon.';

  @override
  String get myReqContractorDefault => 'Contractor';

  @override
  String myReqQuoteAmount(Object amount) {
    return 'Quote: $amount';
  }

  @override
  String get myReqSelectedContractor => 'This contractor selected';

  @override
  String get myReqReview => 'Review';

  @override
  String get myReqContactSharedLabel => 'Contact shared with the contractor';

  @override
  String get myReqShareContactBtn => 'Share phone with contractor';

  @override
  String get myReqAccept => 'Accept';

  @override
  String get myReqReviewTitle => 'Review contractor';

  @override
  String get myReqCritQuality => 'Quality';

  @override
  String get myReqCritTimeliness => 'Timeliness';

  @override
  String get myReqCritCommunication => 'Communication';

  @override
  String get myReqCritBudget => 'Budget';

  @override
  String get myReqCritProfessionalism => 'Professionalism';

  @override
  String get myReqDetailedRating => 'Detailed rating (optional)';

  @override
  String get myReqCommentHint => 'Comment (optional)';

  @override
  String get myReqSend => 'Send';

  @override
  String get pgalFileOpenError => 'Could not open file';

  @override
  String get pgalVerifySuccess => 'Project verified';

  @override
  String pgalErrorWith(Object error) {
    return 'Error: $error';
  }

  @override
  String get pgalProjectFallback => 'Project';

  @override
  String get pgalVerified => 'Verified';

  @override
  String pgalDesignFilesCount(Object count) {
    return 'DESIGN FILES ($count)';
  }

  @override
  String get pgalDesignUnit => 'DESIGN FIRM';

  @override
  String get pgalConfirmReal => 'Confirm project is real';

  @override
  String get pgalViewFirmProfile => 'View firm profile';

  @override
  String get pgalRequestConsult => 'Request consultation';

  @override
  String get pgalSpecCode => 'Design code';

  @override
  String get pgalSpecHouseType => 'House type';

  @override
  String get pgalSpecStyle => 'Style';

  @override
  String get pgalSpecFloors => 'Floors';

  @override
  String pgalFloorsValue(Object count) {
    return '$count floors';
  }

  @override
  String get pgalSpecBedrooms => 'Bedrooms';

  @override
  String pgalRoomsValue(Object count) {
    return '$count rooms';
  }

  @override
  String get pgalSpecLandArea => 'Land area';

  @override
  String pgalLandAreaValue(Object width, Object length, Object total) {
    return '$width×${length}m ($total m²)';
  }

  @override
  String get pgalSpecBuildArea => 'Built area';

  @override
  String pgalSqmValue(Object area) {
    return '$area m²';
  }

  @override
  String get pgalSpecYear => 'Design year';

  @override
  String get pgalSpecRegion => 'Region';

  @override
  String get pgalSpecEstCost => 'Reference price';

  @override
  String get pgalSpecTitle => 'SPECIFICATIONS';

  @override
  String pgalCostBillion(Object value) {
    return '$value billion';
  }

  @override
  String pgalCostMillion(Object value) {
    return '$value million';
  }

  @override
  String pgalCostDong(Object value) {
    return '$value đ';
  }

  @override
  String get pgalDescTitle => 'DESIGN DESCRIPTION';

  @override
  String get pgalCollapse => 'Collapse';

  @override
  String get pgalExpand => 'See more';

  @override
  String get pgalRelatedTitle => 'SIMILAR DESIGNS';

  @override
  String get pgalDesignTemplate => 'Design template';

  @override
  String pgalBedroomsAbbr(Object count) {
    return '$count BR';
  }

  @override
  String pgalSqmValueCompact(Object area) {
    return '${area}m²';
  }

  @override
  String get pgalDesignFirmName => 'Design firm';

  @override
  String pgalRatingLine(Object rating, Object count) {
    return '⭐ $rating · $count reviews';
  }

  @override
  String get pgalViewAllFirm => 'See all designs by this firm →';

  @override
  String pgalDrawingIndex(Object index) {
    return 'Drawing/design $index';
  }

  @override
  String get postCardEdited => 'edited';

  @override
  String get postCmtErrorLoad => 'Failed to load comments';

  @override
  String get postCmtLoginRequired => 'Log in to comment.';

  @override
  String get postCmtSendFailed => 'Failed to send comment';

  @override
  String get postCmtDeleteFailed => 'Failed to delete comment';

  @override
  String get postCmtTitle => 'Comments';

  @override
  String get postCmtEmpty => 'No comments yet. Be the first!';

  @override
  String get postCmtEdited => 'edited';

  @override
  String postCmtMoreImages(Object count) {
    return '+$count photos';
  }

  @override
  String get postCmtDeleted => 'Comment deleted';

  @override
  String get postCmtReply => 'Reply';

  @override
  String get postCmtDelete => 'Delete';

  @override
  String postCmtReplyingTo(Object name) {
    return 'Replying to $name';
  }

  @override
  String get postCmtHint => 'Write a comment...';

  @override
  String postCmtReplyHint(Object name) {
    return 'Reply to $name...';
  }

  @override
  String postHouseImagePickError(Object error) {
    return 'Error picking image: $error';
  }

  @override
  String get postHouseSelectRoomType => 'Please select a room type';

  @override
  String get postHouseWaitUpload =>
      'Please wait for the images to finish uploading';

  @override
  String get postHouseNeedOneImage => 'At least 1 image is required';

  @override
  String get postHousePostSuccess => 'Listing posted successfully!';

  @override
  String get postHousePendingReviewTitle => 'Submitted — awaiting review';

  @override
  String get postHousePendingReviewBody =>
      'High-value sale listings need admin verification before they go public (usually within 24 hours). Track the status under Profile → My listings.';

  @override
  String get commonUnderstood => 'Got it';

  @override
  String get postHousePostFailed => 'Failed to post listing';

  @override
  String get postHouseUpdateSuccess => 'Listing updated';

  @override
  String get postHouseUpdateFailed => 'Update failed';

  @override
  String get postHouseEditTitle => 'Edit listing';

  @override
  String get postHouseNewTitle => 'Post new listing';

  @override
  String postHousePhotosLabel(Object label, Object current, Object max) {
    return '$label ($current/$max)';
  }

  @override
  String get postHousePropertyPhotos => 'Property photos';

  @override
  String get postHouseRoomPhotos => 'Room photos';

  @override
  String get postHouseListingCategory => 'Listing type';

  @override
  String get postHouseTitleLabel => 'Title';

  @override
  String get postHouseTitleHint => 'E.g. 2BR apartment with Saigon River view';

  @override
  String get postHouseRequired => 'Required';

  @override
  String get postHouseDescLabel => 'Description';

  @override
  String get postHouseDescHint => 'Detailed description of the room...';

  @override
  String get postHouseDraftFoundTitle => 'Continue your unfinished listing?';

  @override
  String get postHouseDraftFoundBody =>
      'You have a listing you did not finish last time. Restore it to keep going, or discard it to start fresh. (Photos need to be picked again.)';

  @override
  String get postHouseDraftRestore => 'Restore';

  @override
  String get postHouseDraftDiscard => 'Discard';

  @override
  String get postHouseDescLabelOptional => 'Description (optional)';

  @override
  String get postHouseDescTemplateBtn => 'Insert description template';

  @override
  String get postHouseDescTemplate =>
      '• Location: near market/school/bus station...\n• Amenities: air conditioning, water heater, parking...\n• Other costs: electricity, water, internet...\n• Contact for a viewing: ';

  @override
  String get postHousePropertyType => 'Property type';

  @override
  String get postHouseRoomType => 'Room type';

  @override
  String get postHouseSelectType => 'Select type';

  @override
  String get postHouseSalePrice => 'Sale price (₫)';

  @override
  String get postHouseRentPrice => 'Rent / month (₫)';

  @override
  String get postHousePerMonth => '/month';

  @override
  String get postHouseSalePriceHint => 'E.g. 2,500,000,000';

  @override
  String get postHouseRentPriceHint => 'E.g. 8,000,000';

  @override
  String get postHouseArea => 'Area (m²)';

  @override
  String get postHouseAreaHint => 'E.g. 65';

  @override
  String get postHouseAddress => 'Address';

  @override
  String get postHouseAddressHint => 'House number, street...';

  @override
  String get postHouseAddressNeedsDetail =>
      'The map could only resolve down to the ward — please add the house number and street name.';

  @override
  String get postHouseProvince => 'Province / City';

  @override
  String get postHouseSelectProvince => 'Select province/city';

  @override
  String get postHouseWard => 'Ward / Commune';

  @override
  String get postHouseLoading => 'Loading...';

  @override
  String get postHouseSelectWard => 'Select ward/commune';

  @override
  String get postHouseMapLocation => 'Location on map';

  @override
  String get postHouseMapHint =>
      'Tap the map to drop a pin at the exact location (address is auto-filled).';

  @override
  String postHousePinnedAt(Object lat, Object lng) {
    return 'Pinned: $lat, $lng';
  }

  @override
  String get postHouseBedrooms => 'Bedrooms';

  @override
  String get postHouseBathrooms => 'Bathrooms';

  @override
  String get postHouseLegal => 'Legal status';

  @override
  String get postHouseSaveChanges => 'Save changes';

  @override
  String get postHouseSell => 'Post for sale';

  @override
  String get postHouseRent => 'Post for rent';

  @override
  String get postHouseAddPhoto => 'Add photo';

  @override
  String get postHouseCoverPhoto => 'Cover photo';

  @override
  String get postHouseRetry => 'Retry';

  @override
  String get postHouseListingForm => 'Listing form';

  @override
  String get postHouseSemanticRent => 'Listing type: For rent';

  @override
  String get postHouseSemanticSale => 'Listing type: For sale';

  @override
  String get postHouseSingleTitle => '1 unit / 1 room';

  @override
  String get postHouseSingleSubtitle => 'Whole house, private apartment';

  @override
  String get postHouseMultiTitle => 'Multiple rooms';

  @override
  String get postHouseMultiSubtitle =>
      'Boarding house, mini apartments, hostel...';

  @override
  String get postHouseLegalRedBook => 'Land use certificate';

  @override
  String get postHouseLegalPinkBook => 'Ownership certificate';

  @override
  String get postHouseLegalSaleContract => 'Sale contract';

  @override
  String get postHouseLegalPending => 'Certificate pending';

  @override
  String get postHouseTotalUnits => 'Total rooms';

  @override
  String get postHouseTotalUnitsHint => 'E.g. 10';

  @override
  String get postHouseAvailableUnits => 'Available';

  @override
  String get postHouseAvailableUnitsHint => 'E.g. 7';

  @override
  String get postHousePriorityTenant => 'Preferred tenant';

  @override
  String get postHouseGenderAny => 'No preference';

  @override
  String get postHouseGenderMale => 'Male';

  @override
  String get postHouseGenderFemale => 'Female';

  @override
  String get profPersonal => 'Profile';

  @override
  String get profLoginPrompt =>
      'Log in to manage your profile, listings, appointments and settings.';

  @override
  String get profAccount => 'Account';

  @override
  String get profSettings => 'Settings';

  @override
  String get profYourPosts => 'YOUR POSTS';

  @override
  String get profSavedListings => 'Saved listings';

  @override
  String profAgeYears(Object count) {
    return '$count years old';
  }

  @override
  String get profListings => 'Listings';

  @override
  String get profAppointmentsStat => 'Appointments';

  @override
  String get profFavorites => 'Favorites';

  @override
  String get profMine => 'Mine';

  @override
  String get profPostedListings => 'Posted listings';

  @override
  String get profPostedListingsSubtitle => 'Manage the rooms you rent out';

  @override
  String get profViewingAppointments => 'Viewing appointments';

  @override
  String get profViewingAppointmentsSubtitle =>
      'Your house viewing appointments';

  @override
  String get profConstructionServices => 'Construction services';

  @override
  String get profMyServiceRequests => 'My service requests';

  @override
  String get profMyServiceRequestsSubtitle =>
      'Track quotes & pick a contractor';

  @override
  String get profProviderChannel => 'Provider channel';

  @override
  String get profProviderChannelSubtitle =>
      'Company profile, matching leads, my quotes';

  @override
  String get profBecomeProvider => 'Are you a construction or design firm?';

  @override
  String get profBecomeProviderSubtitle =>
      'Register a profile to receive quote requests';

  @override
  String get profRoleAdmin => 'Admin';

  @override
  String get profRoleMember => 'Member';

  @override
  String get profModeGuest => 'Renter';

  @override
  String get profModeHost => 'Host';

  @override
  String get profBecomeHost => 'BECOME A HOST';

  @override
  String get profBecomeHostSubtitle =>
      'List rooms, welcome guests, get paid — in just 2 minutes.';

  @override
  String get reelCmtLoadFailed => 'Couldn\'t load comments.';

  @override
  String get reelCmtLoginToComment => 'Log in to comment.';

  @override
  String get reelCmtRateLimited =>
      'You\'re commenting a bit too fast, try again in a few minutes.';

  @override
  String get reelCmtSendFailed => 'Failed to send comment.';

  @override
  String get reelCmtDeleteTitle => 'Delete comment?';

  @override
  String get reelCmtDelete => 'Delete';

  @override
  String get reelCmtDeleteFailed => 'Failed to delete comment.';

  @override
  String reelCmtCountLabel(Object count) {
    return '$count comments';
  }

  @override
  String reelCmtReplyingTo(Object name) {
    return 'Replying to $name';
  }

  @override
  String get reelCmtInputHint => 'Write a comment…';

  @override
  String get reelCmtEmpty => 'No comments yet.\nBe the first!';

  @override
  String get reelCmtDefaultUser => 'User';

  @override
  String get reelCmtDeletedComment => 'Comment deleted';

  @override
  String get reelCmtReply => 'Reply';

  @override
  String get reelCompTitle => 'Create reel';

  @override
  String get reelCompPost => 'Post';

  @override
  String get reelCompUploading => 'Uploading video…';

  @override
  String reelCompUploaded(Object name) {
    return 'Uploaded: $name';
  }

  @override
  String get reelCompPickVideo => 'Choose video from gallery';

  @override
  String get reelCompLimits => 'Up to 90 seconds · 120MB · any format';

  @override
  String get reelCompCaption => 'Caption';

  @override
  String get reelCompCaptionHint => 'A short description of your video…';

  @override
  String get reelCompShowIn => 'Show in section';

  @override
  String get reelCompCatAll => 'All sections';

  @override
  String get reelCompCatLease => 'For lease';

  @override
  String get reelCompCatIndustrial => 'Industrial';

  @override
  String get reelCompCatDesign => 'Design';

  @override
  String get reelCompCatBuild => 'Construction';

  @override
  String get reelCompCatInterior => 'Interior';

  @override
  String get reelCompErrVideoTooLarge =>
      'Video is too large (max 120MB). Please record a shorter one.';

  @override
  String get reelCompErrUploadFailed =>
      'Video upload failed. Please check your connection and try again.';

  @override
  String get reelCompErrNoVideo => 'Please choose a video first.';

  @override
  String get reelCompSentTitle => 'Submitted, pending review';

  @override
  String get reelCompSentBody =>
      'Your video is being processed (normalization + cover image), then an administrator will review it before it appears publicly. You can track its status under \"My reels\".';

  @override
  String get reelCompGotIt => 'Got it';

  @override
  String get reelCompErrRateLimit =>
      'You have posted the maximum of 5 reels today. Please try again later.';

  @override
  String get reelCompErrSubmitFailed =>
      'Failed to post reel. Please try again.';

  @override
  String get reelViewDataSaverOn => 'Data saver on — videos won\'t autoplay.';

  @override
  String get reelViewDataSaverOff => 'Data saver off.';

  @override
  String get reelViewLoginToLike => 'Log in to like this reel.';

  @override
  String get reelViewLoginToReport => 'Log in to report this reel.';

  @override
  String get reelViewReasonSpam => 'Spam / advertising';

  @override
  String get reelViewReasonInappropriate => 'Inappropriate content';

  @override
  String get reelViewReasonCopyright => 'Copyright infringement';

  @override
  String get reelViewReasonMisleading => 'Misleading / scam';

  @override
  String get reelViewReasonOther => 'Other reason';

  @override
  String get reelViewReportTitle => 'Report reel';

  @override
  String get reelViewReportSuccess =>
      'Report submitted. Thank you for helping keep the community safe.';

  @override
  String get reelViewReportFailed => 'Failed to submit report.';

  @override
  String get reelViewLinkCopied => 'Reel link copied.';

  @override
  String get reelViewDataSaverTooltipOn => 'Data saver: ON';

  @override
  String get reelViewDataSaverTooltipOff => 'Data saver: OFF';

  @override
  String get reelViewVideoError => 'Can\'t play this video';

  @override
  String reelViewViewCount(Object count) {
    return '$count views';
  }

  @override
  String get reelViewShare => 'Share';

  @override
  String get reelViewUnmute => 'Unmute';

  @override
  String get reelViewMute => 'Mute';

  @override
  String get reelViewReport => 'Report';

  @override
  String get roleWelcomeTitle => 'Welcome to Vua Nhà';

  @override
  String get roleLater => 'Later';

  @override
  String get roleQuestion => 'What brings you here?';

  @override
  String get roleSubtitle =>
      'Pick one so we can take you to the right place. You can change or add more later.';

  @override
  String get roleSeekerTitle => 'I\'m looking for a home / service';

  @override
  String get roleSeekerSubtitle =>
      'Browse rental and sale listings, find construction providers.';

  @override
  String get roleHostTitle => 'I\'m a property owner';

  @override
  String get roleHostSubtitle => 'Post your property for rent or sale.';

  @override
  String get roleProviderTitle => 'I\'m a construction / design provider';

  @override
  String get roleProviderSubtitle =>
      'Set up your provider profile and receive quote requests from customers.';

  @override
  String get socialLoginToInteract => 'Log in to interact with the community.';

  @override
  String get socialDeletePostTitle => 'Delete post';

  @override
  String get socialDeletePostConfirm =>
      'Are you sure you want to delete this post?';

  @override
  String get socialDelete => 'Delete';

  @override
  String get socialDeleteFailed => 'Failed to delete post';

  @override
  String get socialAll => 'All';

  @override
  String get socialWhatsOnMind => 'What\'s on your mind?';

  @override
  String get socialPostPhoto => 'Post a photo';

  @override
  String get socialNoPostsInCategory => 'No posts in this category yet';

  @override
  String get socialNoPosts => 'No posts yet';

  @override
  String get socialBeFirstToShare => 'Be the first to share!';

  @override
  String get socialEndOfFeed => '— End of feed —';

  @override
  String get socialErrorOccurred => 'Something went wrong';

  @override
  String get socialRetry => 'Retry';

  @override
  String get surveyEyebrow => 'Personal';

  @override
  String get surveyMyInterestsTitle => 'My interests';

  @override
  String get surveySkip => 'Skip';

  @override
  String get surveyGreeting => 'Hi there 👋';

  @override
  String get surveyIntro =>
      'Tell Vua Nhà what you\'re interested in to personalize your experience. You can pick multiple options.';

  @override
  String get surveyWhatDoYouWant => 'What do you want to do?';

  @override
  String get surveyRealEstateSection => 'Real estate';

  @override
  String get surveyConstructionSection => 'Construction';

  @override
  String get surveyConstructionInterest => 'Construction areas of interest';

  @override
  String get surveyAreaOptional => 'Area of interest (optional)';

  @override
  String get surveyYouAreTitle => 'Who are you?';

  @override
  String get surveyIAmProvider =>
      'I am a construction / design / interior firm';

  @override
  String get surveyIAmProviderHint =>
      'Opens the Construction section by default and lets you receive quote requests';

  @override
  String get surveyProvinceHint => 'Select a province/city';

  @override
  String get surveySave => 'Save';

  @override
  String get surveyStartExploring => 'Start exploring';

  @override
  String get surveyPrefsUpdated => 'Preferences updated';

  @override
  String get surveyInterestRent => 'Rent a home';

  @override
  String get surveyInterestBuy => 'Buy property';

  @override
  String get surveyInterestSellOrList => 'Lease / Post a listing';

  @override
  String get surveyInterestFindService => 'Find a construction provider';

  @override
  String get surveyInterestFollowConstruction =>
      'Follow construction industry news';

  @override
  String get surveyServiceDesign => 'Design';

  @override
  String get surveyServiceBuild => 'Construction';

  @override
  String get surveyServiceInterior => 'Interior';

  @override
  String get surveyServiceIndustrial => 'Industrial real estate';

  @override
  String get loanTitle => 'Loan calculator';

  @override
  String get loanHomePrice => 'Home price (VND)';

  @override
  String get loanHomePriceHint => 'e.g. 2000000000';

  @override
  String loanDownPayment(Object pct) {
    return 'Down payment: $pct%';
  }

  @override
  String get loanInterestRate => 'Interest rate (%/year)';

  @override
  String get loanInterestRateHint => 'e.g. 10';

  @override
  String loanTerm(Object years) {
    return 'Term: $years years';
  }

  @override
  String loanYearsShort(Object years) {
    return '$years years';
  }

  @override
  String get loanMethod => 'Repayment method';

  @override
  String get loanMethodReducing => 'Reducing balance';

  @override
  String get loanMethodAnnuity => 'Equal monthly payments';

  @override
  String get loanInvalidPrice => 'Enter a valid home price';

  @override
  String loanCalcFailed(Object error) {
    return 'Calculation failed: $error';
  }

  @override
  String get loanMonthlyPayment => 'Monthly payment';

  @override
  String get loanFirstMonthPayment => 'First month payment';

  @override
  String loanLastMonth(Object amount) {
    return 'Last month: $amount';
  }

  @override
  String get loanPrincipal => 'Loan amount';

  @override
  String get loanTotalInterest => 'Total interest';

  @override
  String get loanTotalPayment => 'Total payment';

  @override
  String get loanTermLabel => 'Term';

  @override
  String loanTermValue(Object months, Object years) {
    return '$months months ($years years)';
  }

  @override
  String get loanDisclaimer =>
      'Results are for reference only; the actual interest rate is set by the bank.';

  @override
  String get apptChipPending => 'Pending approval';

  @override
  String get apptChipApproved => 'Approved';

  @override
  String get apptChipCompleted => 'Completed';

  @override
  String get apptChipCancelled => 'Cancelled';

  @override
  String get apptChipRejected => 'Rejected';

  @override
  String get apptChipLocked => 'Room booked';

  @override
  String get apptChipLost => 'Already taken';

  @override
  String get blockLoginToInteract => 'Log in to interact with the community.';

  @override
  String get blockDeletePostTitle => 'Delete post';

  @override
  String get blockDeletePostConfirm =>
      'Are you sure you want to delete this post?';

  @override
  String get blockDelete => 'Delete';

  @override
  String get blockDeletePostFailed => 'Failed to delete post';

  @override
  String get blockCommunity => 'Community';

  @override
  String get blockCompose => 'Post';

  @override
  String blockReelsCategory(Object name) {
    return '$name Reels';
  }

  @override
  String get blockUnitList => 'Provider list';

  @override
  String get blockSearchByLocation => 'Search by location…';

  @override
  String get blockProvince => 'Province / City';

  @override
  String get blockWard => 'Ward / Commune';

  @override
  String get blockKeywordHint => 'Keyword (content / location)…';

  @override
  String get blockSearch => 'Search';

  @override
  String get blockClearFilter => 'Clear filters';

  @override
  String blockNoPostsIn(Object name) {
    return 'No posts in $name yet';
  }

  @override
  String get blockBeFirstToShare => 'Be the first to share!';

  @override
  String get blockNoMorePosts => '— No more posts —';

  @override
  String get chgpwdSuccess => 'Password changed successfully';

  @override
  String get chgpwdFailed => 'Failed to change password';

  @override
  String get chgpwdCurrentLabel => 'Current password';

  @override
  String get chgpwdNewLabel => 'New password';

  @override
  String get chgpwdConfirmLabel => 'Confirm new password';

  @override
  String get chgpwdRequired => 'Required';

  @override
  String get chgpwdMinLength => 'At least 6 characters';

  @override
  String get chgpwdMismatch => 'Passwords do not match';

  @override
  String get clandEyebrow => 'CONSTRUCTION';

  @override
  String clandDefaultDesc(Object serviceName) {
    return 'Connect with reputable $serviceName providers.';
  }

  @override
  String get clandDisclaimer =>
      'Vua Nhà is an intermediary connection platform — contracts & payments are made directly between the two parties.';

  @override
  String get clandRequestQuote => 'Request consultation / quote';

  @override
  String get clandViewContractors => 'View contractors';

  @override
  String get composerPickImageFailed => 'Could not pick images';

  @override
  String get composerSelectCategoryPrompt =>
      'Please select a category for the post';

  @override
  String get composerPostFailed => 'Failed to post, please try again';

  @override
  String get composerEditTitle => 'Edit post';

  @override
  String get composerCreateTitle => 'Create post';

  @override
  String get composerSave => 'Save';

  @override
  String get composerPost => 'Post';

  @override
  String get composerContentHint => 'What\'s on your mind?';

  @override
  String get composerSelectCategoryLabel => 'Select category *';

  @override
  String get composerLocationHint =>
      'Location (optional) — e.g. District 7, HCMC';

  @override
  String get composerPhotos => 'Photos';

  @override
  String get composerDiscardTitle => 'Discard this post?';

  @override
  String get composerDiscardBody => 'What you have written will not be saved.';

  @override
  String get composerKeepEditing => 'Keep editing';

  @override
  String get composerDiscard => 'Discard';

  @override
  String composerImagesCount(Object count, Object max) {
    return '$count/$max photos';
  }

  @override
  String ctrListTitle(Object name) {
    return 'Contractors · $name';
  }

  @override
  String get ctrListEmptyTitle => 'No contractors in your area yet';

  @override
  String get ctrListEmptyBody =>
      'Send a request — we\'ll connect you with a suitable provider.';

  @override
  String get ctrListRequestConsult => 'Request consultation';

  @override
  String get ctrListDefaultName => 'Contractor';

  @override
  String get ctrListBadgePromoted => 'Featured';

  @override
  String get ctrListBadgePro => 'Pro';

  @override
  String get myPostsLoadError => 'Couldn\'t load posts';

  @override
  String get myPostsLoadErrorHint => 'Check your connection and try again.';

  @override
  String get myPostsRetry => 'Try again';

  @override
  String get myPostsEmptyTitle => 'You don\'t have any posts yet';

  @override
  String get myPostsEmptyHint =>
      'Posts you share in the Community will appear here.';

  @override
  String get plistSearchHint => 'Search by name, description, address…';

  @override
  String get plistEmptyTitle => 'No matching listings found';

  @override
  String get plistEmptySubtitle =>
      'Try a different keyword or come back later.';

  @override
  String plistAreaSqm(Object area) {
    return '$area m²';
  }

  @override
  String get qualityTitle => 'Facility quality';

  @override
  String get qualityVerified => 'Verified';

  @override
  String get qualitySelfDeclared => 'Owner-declared';

  @override
  String get qualitySubtitle => 'Amenity rating — affects the price range.';

  @override
  String qualityStarRating(Object star) {
    return '$star/5';
  }

  @override
  String qualitySuggestedPrice(Object price) {
    return 'Suggested price by quality: $price/month';
  }

  @override
  String get qualityNotDeclared => 'Quality not declared yet.';

  @override
  String get qualityUpdateButton => 'Update quality';

  @override
  String get qualityDeclareButton => 'Declare property quality';

  @override
  String get qualityVerifRequested => 'Verification requested';

  @override
  String get qualityRequestVerification => 'Request on-site verification';

  @override
  String get qualityVerifSubmitted =>
      'Verification request sent. Our team will contact you to inspect.';

  @override
  String qualityRequestFailed(Object error) {
    return 'Could not send request: $error';
  }

  @override
  String get reviewTitle => 'Review';

  @override
  String get reviewRatePrompt => 'How many stars for this place?';

  @override
  String reviewStarTooltip(Object count) {
    return '$count stars';
  }

  @override
  String get reviewCommentLabel => 'Your thoughts';

  @override
  String get reviewCommentHint =>
      'E.g. Friendly host, clean place, matches the description...';

  @override
  String get reviewSubmitButton => 'Submit review';

  @override
  String get reviewSubmitSuccess => 'Review submitted, thank you!';

  @override
  String reviewSubmitError(Object error) {
    return 'Failed to submit review: $error';
  }

  @override
  String rfqTitle(Object serviceName) {
    return 'Request a consultation · $serviceName';
  }

  @override
  String get rfqSubtitle => 'Free · Your phone number is never shared publicly';

  @override
  String get rfqFieldName => 'Full name *';

  @override
  String get rfqFieldPhone => 'Phone number *';

  @override
  String get rfqFieldArea => 'Area (province/district)';

  @override
  String get rfqFieldBudget => 'Estimated budget (optional)';

  @override
  String get rfqFieldDesc => 'Describe your needs';

  @override
  String get rfqSubmit => 'Send request';

  @override
  String get rfqValidation => 'Please enter a valid name and phone number';

  @override
  String get rfqSendError =>
      'Failed to send your request. Please check your connection and try again.';

  @override
  String get rfqSuccessTitle => 'Request sent!';

  @override
  String rfqSuccessBody(Object serviceName) {
    return 'The $serviceName team will contact you as soon as possible.';
  }

  @override
  String get rfqClose => 'Close';

  @override
  String get searchHint => 'Search listings, contractors, community posts…';

  @override
  String get searchEmptyTitle => 'Search everything on Vua Nhà';

  @override
  String get searchEmptySubtitle =>
      'Rental listings, construction/design firms, community posts…';

  @override
  String get searchRecentTitle => 'RECENT SEARCHES';

  @override
  String get searchClearAll => 'Clear all';

  @override
  String searchNoResults(Object query) {
    return 'No results for “$query”';
  }

  @override
  String get searchNoResultsSubtitle =>
      'Try removing accents or using different keywords.';

  @override
  String get searchGroupHouses => 'LISTINGS';

  @override
  String get searchGroupContractors => 'FIRMS';

  @override
  String get searchGroupPosts => 'COMMUNITY POSTS';

  @override
  String get searchHouseFallback => 'Listing';

  @override
  String get searchContractorFallback => 'Firm';

  @override
  String searchRating(Object rating, Object count) {
    return '⭐ $rating · $count reviews';
  }

  @override
  String get settingsMyPreferences => 'My preferences';

  @override
  String get settingsMyPreferencesSub => 'Personalize by purpose & area';

  @override
  String get settingsLogoutConfirm => 'Are you sure you want to log out?';

  @override
  String get settingsLoggedOut => 'Logged out';

  @override
  String get wishEyebrow => 'Bookmarked';

  @override
  String get wishTitle => 'Favorites';

  @override
  String get wishCompareTooltip => 'Compare';

  @override
  String get wishRefreshTooltip => 'Refresh';

  @override
  String get wishEmptyTitle => 'No rooms yet';

  @override
  String get wishEmptySubtitle =>
      'Tap the heart on rooms you like to save them here.';

  @override
  String get wishUnfavoriteTooltip => 'Remove from favorites';

  @override
  String get wishUnfavoriteError => 'Could not remove from favorites';

  @override
  String get hApprovalInboxTitle => 'Approval inbox';

  @override
  String get hApprovalInboxEyebrow => 'HOST · APPROVALS';

  @override
  String get hApprovalEmptyTitle => 'No requests';

  @override
  String get hApprovalEmptySubtitle =>
      'When an operator needs approval, requests will appear here.';

  @override
  String hApprovalBiometricReason(Object amount) {
    return 'Authenticate to approve the $amount transaction';
  }

  @override
  String get hApprovalBiometricRequired =>
      'Biometric authentication is required to continue';

  @override
  String get hApprovalApproveSuccess => 'Approved successfully';

  @override
  String get hApprovalApproveFailed => 'Approval failed. Try again.';

  @override
  String get hApprovalRejectSuccess => 'Request rejected';

  @override
  String get hApprovalRejectReasonTitle => 'Rejection reason';

  @override
  String get hApprovalRejectReasonHint => 'Reason (optional)';

  @override
  String get hApprovalSkip => 'Skip';

  @override
  String get hApprovalReject => 'Reject';

  @override
  String get hApptTitle => 'VIEWING REQUESTS';

  @override
  String get hApptEmpty => 'No requests yet.';

  @override
  String hApptCompletedDeals(Object count) {
    return '$count completed deals';
  }

  @override
  String get hApptRateGuest => 'Rate guest';

  @override
  String hApptRateGuestTitle(Object name) {
    return 'Rate $name';
  }

  @override
  String get hApptGuestFallback => 'guest';

  @override
  String get hApptReviewHint => 'Comment (optional)';

  @override
  String get hApptCancel => 'Cancel';

  @override
  String get hApptSend => 'Send';

  @override
  String get hApptReviewSuccess => 'Guest reviewed';

  @override
  String hApptReviewFailed(Object error) {
    return 'Could not submit review: $error';
  }

  @override
  String get hApptEmptyHintPending =>
      'When guests send viewing requests, they will appear here.';

  @override
  String get hApptEmptyHintApproved => 'No approved appointments yet.';

  @override
  String get hApptEmptyHintPast => 'No closed or rejected requests yet.';

  @override
  String get hApptTabPending => 'PENDING';

  @override
  String get hApptTabApproved => 'APPROVED';

  @override
  String get hApptTabClosed => 'CLOSED';

  @override
  String get hAvailTitle => 'Viewing time slots';

  @override
  String get hAvailWeekdaysSection => 'Days of the week you receive guests';

  @override
  String get hAvailSlotsSection =>
      'Time slots for receiving guests (1 hour each)';

  @override
  String get hAvailSelectAll => 'Select all';

  @override
  String get hAvailDeselect => 'Deselect';

  @override
  String get hAvailSave => 'Save time slots';

  @override
  String get hAvailSavedToast => 'Viewing time slots saved.';

  @override
  String get hAvailSaveFailed => 'Save failed';

  @override
  String get hAvailIntroDefault =>
      'You are currently accepting viewings on all days and at all times. Narrow it down if you only want to receive guests at certain times.';

  @override
  String get hAvailIntroCustom =>
      'Guests can only book viewings on the days and time slots you select below.';

  @override
  String get hAvailEmptyWarning =>
      'No day or time slot selected — guests will not be able to book a viewing.';

  @override
  String get hAvailMon => 'Mon';

  @override
  String get hAvailTue => 'Tue';

  @override
  String get hAvailWed => 'Wed';

  @override
  String get hAvailThu => 'Thu';

  @override
  String get hAvailFri => 'Fri';

  @override
  String get hAvailSat => 'Sat';

  @override
  String get hAvailSun => 'Sun';

  @override
  String get hContractDetTitle => 'Contract';

  @override
  String get hContractDetNotFound => 'Contract not found';

  @override
  String get hContractDetStartDate => 'Start date';

  @override
  String get hContractDetEndDate => 'End date';

  @override
  String get hContractDetRent => 'Rent';

  @override
  String hContractDetRentPerMonth(Object amount) {
    return '$amount đ/month';
  }

  @override
  String get hContractDetDeposit => 'Deposit';

  @override
  String hContractDetAmountDong(Object amount) {
    return '$amount đ';
  }

  @override
  String get hContractDetTenants => 'Tenants';

  @override
  String get hContractDetRepresentative => 'Representative';

  @override
  String get hContractDetActivate => 'Activate contract';

  @override
  String get hContractDetCheckout => 'Check out (end)';

  @override
  String get hContractDetTransferRoom => 'Transfer room';

  @override
  String get hContractDetActualEndDate => 'Actual checkout date';

  @override
  String get hContractDetDepositRefund => 'Deposit refund';

  @override
  String get hContractDetDamage => 'Damage';

  @override
  String get hContractDetStatusDraft => 'Draft';

  @override
  String get hContractDetStatusActive => 'Active';

  @override
  String get hContractDetStatusExpired => 'Expired';

  @override
  String get hContractDetStatusTerminated => 'Terminated';

  @override
  String get hContractDetActivateEyebrow => 'Activate';

  @override
  String get hContractDetActivateConfirmMsg =>
      'Activating this contract will change the room status to \"Occupied\". Continue?';

  @override
  String get hContractDetActivateSuccess => 'Contract activated';

  @override
  String get hContractDetFailed => 'Failed';

  @override
  String get hContractFormTitle => 'New contract';

  @override
  String get hContractFormEyebrow => 'Form';

  @override
  String get hContractFormStartDate => 'Start date *';

  @override
  String get hContractFormEndDate => 'End date *';

  @override
  String get hContractFormMonthlyRent => 'Monthly rent (VND) *';

  @override
  String get hContractFormRentInvalid => 'Enter a valid amount';

  @override
  String get hContractFormDeposit => 'Deposit (VND)';

  @override
  String get hContractFormSubmit => 'Create contract';

  @override
  String get hContractFormSelectDates => 'Please select a start and end date';

  @override
  String get hContractFormEndAfterStart => 'End date must be after start date';

  @override
  String get hContractFormOnePrimary =>
      'There must be exactly 1 primary tenant (representative)';

  @override
  String get hContractFormTenantNameRequired =>
      'Tenant full name cannot be empty';

  @override
  String get hContractFormCreated => 'Contract created (status: draft)';

  @override
  String get hContractFormCreateFailed => 'Creation failed';

  @override
  String hContractFormPhotoUploadFailed(Object error) {
    return 'Photo upload failed: $error';
  }

  @override
  String hContractFormCccdUploadFailed(Object error) {
    return 'ID card photo upload failed: $error';
  }

  @override
  String hContractTermUploadFailed(Object error) {
    return 'Photo upload failed: $error';
  }

  @override
  String get hContractTermActionEnd => 'terminate the contract';

  @override
  String get hContractTermPickDateFirst =>
      'Please select the actual move-out date';

  @override
  String get hContractTermEnd => 'Terminate';

  @override
  String get hContractTermConfirmTitle => 'Confirm contract termination';

  @override
  String get hContractTermConfirmMessage =>
      'Are you sure you want to terminate this contract?\nThis action cannot be undone.';

  @override
  String get hContractTermDoneEnded => 'Contract terminated';

  @override
  String get hContractTermFailed => 'Failed';

  @override
  String get hContractTermMoveOut => 'Move-out';

  @override
  String get hContractTermIntro =>
      'Confirm the actual move-out date and deposit refund details.';

  @override
  String get hContractTermActualEndDate => 'Actual move-out date *';

  @override
  String get hContractTermPickDate => 'Select date';

  @override
  String get hContractTermRefundAmount => 'Deposit refund amount (VND)';

  @override
  String get hContractTermRefundHelper => 'Enter 0 if no refund';

  @override
  String get hContractTermDamageNote => 'Damage note';

  @override
  String get hContractTermDamageNoteHelper => 'Describe any damage';

  @override
  String get hContractTermDamagePhotos => 'Damage photos';

  @override
  String get hContractTermAddPhoto => 'Add photo';

  @override
  String get hContractTermConfirmMoveOut => 'Confirm move-out';

  @override
  String get hContractXferTransferRoom => 'Transfer room';

  @override
  String get hContractXferActionTransfer => 'transfer room';

  @override
  String get hContractXferContractEyebrow => 'Contract';

  @override
  String get hContractXferIntro =>
      'Select a building and a vacant room to transfer the contract to.';

  @override
  String get hContractXferBuildingLabel => 'Building *';

  @override
  String get hContractXferNoBuildings => 'No buildings';

  @override
  String get hContractXferSelectBuilding => 'Select building';

  @override
  String get hContractXferNoVacantRooms => 'No vacant rooms in this building.';

  @override
  String get hContractXferVacantRoomLabel => 'Vacant room *';

  @override
  String get hContractXferSelectRoom => 'Select room';

  @override
  String hContractXferRoomOption(Object code, Object price) {
    return '$code — $price đ/month';
  }

  @override
  String get hContractXferConfirmTitle => 'Confirm room transfer';

  @override
  String hContractXferConfirmMessage(Object roomName) {
    return 'Are you sure you want to transfer the contract to room $roomName?\nThe old room will become \"Vacant\".';
  }

  @override
  String hContractXferSuccess(Object roomName) {
    return 'Contract transferred to room $roomName';
  }

  @override
  String get hContractXferFailed => 'Failed';

  @override
  String get hContractXferLoadRoomsError => 'Unable to load rooms';

  @override
  String get hDelegDetNotFound => 'Not found';

  @override
  String get hDelegDetNotFoundDelegation => 'Delegation not found';

  @override
  String get hDelegDetOperator => 'Operator';

  @override
  String get hDelegDetEyebrow => 'OWNER · MANAGE DELEGATION';

  @override
  String get hDelegDetPausedToast => 'Delegation paused';

  @override
  String get hDelegDetResumedToast => 'Delegation resumed';

  @override
  String get hDelegDetTerminateTitle => 'Terminate delegation?';

  @override
  String get hDelegDetTerminateBody =>
      'The operator will lose access after 30 days. This action cannot be undone.';

  @override
  String get hDelegDetTerminate => 'Terminate';

  @override
  String get hDelegDetTerminatedToast => 'Delegation terminated';

  @override
  String get hDelegDetThresholdsUpdatedToast => 'Approval thresholds updated';

  @override
  String hDelegDetPermissionLabel(Object role) {
    return 'Permission: $role';
  }

  @override
  String hDelegDetStartLabel(Object date) {
    return 'Started: $date';
  }

  @override
  String hDelegDetPropertiesLabel(Object count) {
    return 'Properties: $count';
  }

  @override
  String get hDelegDetStatusActive => 'Active';

  @override
  String get hDelegDetStatusPaused => 'Paused';

  @override
  String get hDelegDetStatusTerminated => 'Terminated';

  @override
  String get hDelegDetRoleOperatorFull => 'Full operator';

  @override
  String get hDelegDetRoleAccountant => 'Accountant';

  @override
  String get hDelegDetRoleViewer => 'View only';

  @override
  String get hDelegDetRoleOwnerView => 'Owner (view)';

  @override
  String get hDelegDetPause => 'Pause';

  @override
  String get hDelegDetResume => 'Resume';

  @override
  String get hDelegDetThresholds => 'Approval thresholds';

  @override
  String get hDelegDetEdit => 'Edit';

  @override
  String get hDelegDetSaveThresholds => 'Save thresholds';

  @override
  String get hDelegInvTitle => 'Invite Operator';

  @override
  String get hDelegInvEyebrow => 'OWNER · DELEGATION';

  @override
  String get hDelegInvOperatorInfo => 'Operator Information';

  @override
  String get hDelegInvOperatorEmail => 'Operator Email';

  @override
  String get hDelegInvPermissions => 'Permissions';

  @override
  String get hDelegInvThresholds => 'Approval Threshold (VND)';

  @override
  String get hDelegInvSend => 'Send Invitation';

  @override
  String get hDelegInvRoleOperatorFull => 'Full Operations';

  @override
  String get hDelegInvRoleAccountant => 'Accountant';

  @override
  String get hDelegInvRoleViewer => 'Viewer';

  @override
  String get hDelegInvEmailRequired => 'Please enter an email';

  @override
  String get hDelegInvEmailInvalid => 'Invalid email';

  @override
  String get hDelegInvSendSuccess => 'Invitation sent successfully';

  @override
  String get hDelegInvSendFailed => 'Could not send invitation. Try again.';

  @override
  String get hFeeTitle => 'SERVICE FEES';

  @override
  String get hFeeCreateBuildingFirst => 'Please create a building first';

  @override
  String get hFeeEmptyTitle => 'No service fees yet';

  @override
  String get hFeeEmptySubtitle => 'Add a service fee to manage.';

  @override
  String get hFeeMonthly => 'Monthly';

  @override
  String get hFeeOneTime => 'One-time';

  @override
  String get hFeeActive => 'Active';

  @override
  String get hFeeInactive => 'Inactive';

  @override
  String get hFeeEnterNameBuilding => 'Please enter a name and building';

  @override
  String get hFeeSaveFailed => 'Save failed';

  @override
  String get hFeeCreateTitle => 'ADD SERVICE FEE';

  @override
  String get hFeeBuilding => 'Building';

  @override
  String get hFeeServiceName => 'Service name';

  @override
  String get hFeeUnitPrice => 'Unit price (VND)';

  @override
  String get hFeeCycle => 'Cycle';

  @override
  String get hFeeSave => 'Save';

  @override
  String get hHomeDlgActionDelete => 'delete listing';

  @override
  String get hHomeDlgDeleteTitle => 'Delete listing';

  @override
  String hHomeDlgDeleteBody(Object title) {
    return 'Are you sure you want to delete \"$title\"?';
  }

  @override
  String get hHomeDlgDeleteConfirm => 'Delete';

  @override
  String get hHomeDlgDeleteSuccess => 'Listing deleted';

  @override
  String get hHomeDlgDeleteFail => 'Delete failed';

  @override
  String get hHomeDlgActionCloseUnit => 'close a room';

  @override
  String get hHomeDlgCloseUnitTitle => 'Close one room';

  @override
  String hHomeDlgCloseUnitBody(Object title) {
    return 'Confirm that you have rented one room at \"$title\" to someone outside the app? The number of available rooms will decrease by 1, and pending viewing requests will automatically be notified as \"Already booked\".';
  }

  @override
  String get hHomeDlgCloseUnitConfirm => 'Close room';

  @override
  String get hHomeDlgCloseUnitSuccess => 'Closed one room';

  @override
  String get hHomeDlgCloseUnitFail => 'Operation failed';

  @override
  String get hHomeDlgLockTitle => 'Confirm booking';

  @override
  String hHomeDlgLockBody(Object house, Object guest) {
    return 'Confirm renting room \"$house\" to $guest? Other viewing requests for the same room will automatically close and the guests will be notified.';
  }

  @override
  String get hHomeDlgLockDefaultHouse => 'this one';

  @override
  String get hHomeDlgLockDefaultGuest => 'this guest';

  @override
  String get hHomeDlgLockConfirm => 'Confirm';

  @override
  String get hHomeDlgLockSuccess => 'Room confirmed for the guest';

  @override
  String get hHomeDlgLockFail => 'Booking failed';

  @override
  String get hHomeListingsTotalEyebrow => 'TOTAL LISTINGS';

  @override
  String get hHomeListingsTotalCaption => 'All listings posted to date';

  @override
  String get hHomeListingsPendingEyebrow => 'PENDING';

  @override
  String get hHomeListingsPendingCaption => 'Awaiting admin';

  @override
  String get hHomeListingsApprovedEyebrow => 'PUBLISHED';

  @override
  String get hHomeListingsApprovedCaption => 'Visible to the public';

  @override
  String get hHomeListingsSectionListings => 'Listings';

  @override
  String get hHomeListingsEmptyListingsLine => 'No listings yet.';

  @override
  String get hHomeListingsEmptyListingsHint =>
      'Tap \"Post new\" to create your first listing.';

  @override
  String get hHomeListingsSectionAppointments => 'Viewing requests';

  @override
  String get hHomeListingsEmptyAppointmentsLine =>
      'No pending viewing requests.';

  @override
  String get hHomeListingsEmptyAppointmentsHint =>
      'When a guest books, it will appear here.';

  @override
  String get hHomeListingsPostNew => 'POST NEW LISTING';

  @override
  String get hHomeRoomsKpiCollected => 'COLLECTED';

  @override
  String get hHomeRoomsKpiUnpaid => 'OUTSTANDING';

  @override
  String get hHomeRoomsKpiOccupancy => 'OCCUPANCY';

  @override
  String get hHomeRoomsQuickCreateInvoice => 'Create invoice';

  @override
  String get hHomeRoomsQuickMeter => 'Record meters';

  @override
  String get hHomeRoomsQuickReminder => 'Debt reminder';

  @override
  String get hHomeRoomsQuickReports => 'Reports';

  @override
  String get hHomeRoomsTodoHeader => 'TO DO TODAY';

  @override
  String get hHomeRoomsSectionBilling => 'BILLING';

  @override
  String get hHomeRoomsInvoicesTitle => 'Invoices';

  @override
  String get hHomeRoomsInvoicesSubtitle => 'List & issue invoices';

  @override
  String get hHomeRoomsDebtTitle => 'Receivables';

  @override
  String get hHomeRoomsDebtSubtitle => 'Track debt by room';

  @override
  String get hHomeRoomsServiceFeesTitle => 'Service fees';

  @override
  String get hHomeRoomsServiceFeesSubtitle =>
      'Configure electricity/water/service fees';

  @override
  String get hHomeRoomsSectionOps => 'OTHER OPERATIONS';

  @override
  String get hHomeRoomsLeadsTitle => 'Interested customers';

  @override
  String get hHomeRoomsLeadsSubtitle => 'Viewing appointments & saved listings';

  @override
  String get hHomeRoomsKhaiBaoTitle => 'Temporary residence registration';

  @override
  String get hHomeRoomsHomestayTitle => 'Homestay';

  @override
  String get hHomeRoomsSyncTitle => 'Sync to other marketplaces';

  @override
  String get hHomeRoomsAnalyticsTitle => 'REVENUE ANALYTICS';

  @override
  String get hHomeRoomsAnalyticsSubtitle => '5 KPIs • Revenue, occupancy, ADR';

  @override
  String get hIntroAppBarTitle => 'BECOME A HOST';

  @override
  String get hIntroEyebrow => 'ANCU365  ·  HOST EDITION';

  @override
  String get hIntroHeadline =>
      'Open rooms,\nwelcome guests,\ncollect payments.';

  @override
  String get hIntroSubtitle =>
      'Run your rentals and homestays with An Cu 365 right from your phone — from posting listings and screening guests to signing contracts and closing invoices.';

  @override
  String get hIntroBenefitsLabel => 'WHAT YOU GET';

  @override
  String get hIntroBenefit1Title => 'Manage buildings & rooms';

  @override
  String get hIntroBenefit1Body =>
      'Track room status, contracts, and meters in a single digital ledger.';

  @override
  String get hIntroBenefit2Title => 'Receive viewing requests directly';

  @override
  String get hIntroBenefit2Body =>
      'Guests book a time — you approve or decline right in the app, no scattered messages.';

  @override
  String get hIntroBenefit3Title => 'Issue invoices & close rentals';

  @override
  String get hIntroBenefit3Body =>
      'Automatically calculate utility bills from meters; sign contracts + store them centrally.';

  @override
  String get hIntroBenefit4Title => 'Multi-channel visibility';

  @override
  String get hIntroBenefit4Body =>
      'Listings appear on Explore + the listings map, reaching thousands of guests.';

  @override
  String get hIntroCta => 'START REGISTRATION';

  @override
  String get hIntroCtaNote =>
      'Takes 2–3 minutes. Requires your ID card + payout account details.';

  @override
  String get hInvBatchTitle => 'GENERATE INVOICE BATCH';

  @override
  String get hInvBatchBuildingLabel => 'Building *';

  @override
  String get hInvBatchSelectBuilding => 'Select building';

  @override
  String get hInvBatchMonthLabel => 'Month (YYYY-MM) *';

  @override
  String get hInvBatchSelectMonth => 'Select month';

  @override
  String get hInvBatchElecPriceLabel => 'Electricity unit price (VND/kWh)';

  @override
  String get hInvBatchWaterPriceLabel => 'Water unit price (VND/m³)';

  @override
  String get hInvBatchGenerateButton => 'Generate invoices';

  @override
  String get hInvBatchHelpText =>
      'The system generates invoices (draft status) for each active contract in the building. If an invoice for this period already exists, the system skips it (idempotent).';

  @override
  String get hInvBatchSelectRequired => 'Please select a building and month';

  @override
  String get hInvBatchCreateFailed => 'Creation failed';

  @override
  String get hInvDetSentSuccess => 'Invoice sent — public link is ready';

  @override
  String hInvDetCannotOpen(Object url) {
    return 'Could not open: $url';
  }

  @override
  String get hInvDetTitle => 'INVOICE DETAILS';

  @override
  String hInvDetPeriod(Object start, Object end) {
    return 'Period $start → $end';
  }

  @override
  String hInvDetDue(Object date) {
    return 'Due $date';
  }

  @override
  String get hInvDetDetails => 'DETAILS';

  @override
  String get hInvDetTotal => 'Total';

  @override
  String get hInvDetCollected => 'Collected';

  @override
  String get hInvDetRemaining => 'Remaining';

  @override
  String get hInvDetSendInvoice => 'Send invoice';

  @override
  String get hInvDetRecordPayment => 'Record payment';

  @override
  String get hInvDetOpenPublicLink => 'Open public link';

  @override
  String get hInvDetRemindZalo => 'Remind via Zalo';

  @override
  String get hInvDetCreditNote => 'Create credit note (adjustment)';

  @override
  String get hKhaibaoTitle => 'DECLARATION DETAILS';

  @override
  String get hKhaibaoShareSubject => 'Temporary residence declaration form';

  @override
  String get hKhaibaoDeclaredRecorded => 'Declaration recorded';

  @override
  String get hKhaibaoSaveFailed => 'Save failed';

  @override
  String get hKhaibaoSkipped => 'Skipped';

  @override
  String get hKhaibaoPhone => 'Phone number';

  @override
  String get hKhaibaoRoom => 'Room';

  @override
  String get hKhaibaoBuilding => 'Building';

  @override
  String get hKhaibaoCheckInDate => 'Check-in date';

  @override
  String get hKhaibaoLinkExpires => 'Link expires';

  @override
  String get hKhaibaoDeclaredAt => 'Declared at';

  @override
  String get hKhaibaoSkipReason => 'Skip reason';

  @override
  String get hKhaibaoViewForm => 'View declaration form (TK1)';

  @override
  String get hKhaibaoMarkDeclared => 'Declared';

  @override
  String get hKhaibaoSkipEarlyLeave => 'Skip (guest left early)';

  @override
  String get hKhaibaoSkipHint => 'E.g. Guest left early';

  @override
  String get hKhaibaoSkip => 'Skip';

  @override
  String get hLeadsTitle => 'Interested clients';

  @override
  String hLeadsTabTarget(Object count) {
    return 'Target ($count)';
  }

  @override
  String hLeadsTabPotential(Object count) {
    return 'Potential ($count)';
  }

  @override
  String hLeadsLoadError(Object error) {
    return 'Could not load: $error';
  }

  @override
  String get hLeadsEmptyTarget =>
      'No clients have booked a viewing of your listings yet.';

  @override
  String get hLeadsEmptyPotential =>
      'No clients have saved your listings to their wishlist yet.';

  @override
  String get hLeadsBadgeBooked => 'Booked';

  @override
  String get hLeadsBadgeBookViewing => 'Book a viewing';

  @override
  String get hLeadsBadgeSaved => 'Saved listing';

  @override
  String get hLeadsDefaultName => 'Guest';

  @override
  String get hLeadsDefaultHouse => 'Property';

  @override
  String get hListingsTitle => 'My listings';

  @override
  String get hListingsRefresh => 'Refresh';

  @override
  String get hListingsPostRoom => 'Post a room';

  @override
  String get hListingsEmptyTitle => 'You haven\'t posted any listings yet';

  @override
  String get hListingsEmptyHint =>
      'Tap \"Post a room\" to create your first listing.';

  @override
  String get hListingsEdit => 'Edit listing';

  @override
  String get hListingsDelete => 'Delete listing';

  @override
  String get hListingsDeleteTitle => 'Delete listing';

  @override
  String hListingsDeleteConfirm(Object title) {
    return 'Are you sure you want to delete \"$title\"?';
  }

  @override
  String get hListingsDeleteAction => 'Delete';

  @override
  String get hListingsDeleteSuccess => 'Listing deleted';

  @override
  String get hListingsDeleteFailed => 'Delete failed';

  @override
  String get hListingsStatusApproved => 'Published';

  @override
  String get hListingsStatusPending => 'Pending review';

  @override
  String get hListingsStatusRejected => 'Rejected';

  @override
  String get hListingsStatusHidden => 'Hidden';

  @override
  String get hProfileSavedInfo => 'Information saved';

  @override
  String get hProfileSaveFailed => 'Save failed';

  @override
  String get hProfileEyebrow => 'Account';

  @override
  String get hProfileTitle => 'Host profile';

  @override
  String get hProfileEdit => 'Edit';

  @override
  String get hProfileEmptyTitle => 'No profile yet';

  @override
  String get hProfileEmptySubtitle =>
      'Complete onboarding to create your host profile.';

  @override
  String get hProfileSaveChanges => 'Save changes';

  @override
  String get hProfileVerified => 'Account verified';

  @override
  String get hProfilePending => 'Pending verification';

  @override
  String get hProfileVerifiedDesc => 'You can list rooms and receive payments.';

  @override
  String get hProfilePendingDesc =>
      'Upload your ID card to complete verification.';

  @override
  String get hProfileIdentitySection => 'Identity verification';

  @override
  String get hProfileCccdFront => 'ID card front';

  @override
  String get hProfileCccdBack => 'ID card back';

  @override
  String get hProfileUploaded => 'Uploaded';

  @override
  String get hProfileNotUploaded => 'Not uploaded';

  @override
  String get hProfilePaymentSection => 'Payment information';

  @override
  String get hProfileBank => 'Bank';

  @override
  String get hProfileBankHint => 'e.g. Vietcombank';

  @override
  String get hProfileAccountNumber => 'Account number';

  @override
  String get hProfileAccountHolder => 'Account holder';

  @override
  String get hProfileAccountHolderHint => 'Name on card';

  @override
  String get hProfileTaxId => 'Tax ID';

  @override
  String get hProfilePerformanceSection => 'Performance';

  @override
  String get hProfileRating => 'Rating';

  @override
  String get hProfileAvgResponse => 'Avg. response';

  @override
  String get hProfileHours => 'hours';

  @override
  String get hResvDetTitle => 'Reservation details';

  @override
  String get hResvDetNotFound => 'Reservation not found';

  @override
  String get hResvDetError => 'Error';

  @override
  String get hResvDetReasonHint => 'Reason…';

  @override
  String get hResvDetConfirm => 'Confirm';

  @override
  String get hResvDetCheckIn => 'Check-in';

  @override
  String get hResvDetCheckOut => 'Check-out';

  @override
  String get hResvDetNights => 'Nights';

  @override
  String get hResvDetPhone => 'Phone';

  @override
  String get hResvDetEmail => 'Email';

  @override
  String get hResvDetTotal => 'Total';

  @override
  String get hResvDetRefund => 'Refund';

  @override
  String get hResvDetCancelledAt => 'Cancelled at';

  @override
  String get hResvDetReason => 'Reason';

  @override
  String get hResvDetApprove => 'Approve';

  @override
  String get hResvDetApproved => 'Approved';

  @override
  String get hResvDetReject => 'Reject';

  @override
  String get hResvDetRejectReason => 'Rejection reason';

  @override
  String get hResvDetRejected => 'Rejected';

  @override
  String get hResvDetCheckedIn => 'Checked in';

  @override
  String get hResvDetCheckedOut => 'Checked out';

  @override
  String get hResvDetCancel => 'Cancel reservation';

  @override
  String get hResvDetCancelReason => 'Cancellation reason';

  @override
  String get hResvDetCancelled => 'Reservation cancelled';

  @override
  String get hResvListTitle => 'Reservations';

  @override
  String get hResvListFilterAll => 'All';

  @override
  String get hResvListFilterPending => 'Pending';

  @override
  String get hResvListFilterApproved => 'Approved';

  @override
  String get hResvListFilterCheckedIn => 'Checked in';

  @override
  String get hResvListFilterCheckedOut => 'Checked out';

  @override
  String get hResvListFilterCancelled => 'Cancelled';

  @override
  String get hResvListEmptyTitle => 'No reservations';

  @override
  String get hResvListEmptySubtitle => 'No reservations match this filter yet.';

  @override
  String hResvListNights(Object count) {
    return '$count nights';
  }

  @override
  String get hRoomDetMaintEyebrow => 'MAINTENANCE FORM';

  @override
  String get hRoomDetMaintTitle => 'Put room into maintenance';

  @override
  String get hRoomDetConfirm => 'CONFIRM';

  @override
  String hRoomDetMaintSetFrom(Object start) {
    return 'Maintenance set from $start';
  }

  @override
  String get hRoomDetFailed => 'Failed';

  @override
  String get hRoomDetEndMaintEyebrow => 'END MAINTENANCE';

  @override
  String get hRoomDetEndMaintTitle => 'Confirm ending?';

  @override
  String get hRoomDetEndMaintBody => 'The room will return to vacant status.';

  @override
  String get hRoomDetEnd => 'END';

  @override
  String get hRoomDetMaintEnded => 'Maintenance ended';

  @override
  String hRoomDetDuplicated(Object code) {
    return 'Created copy $code';
  }

  @override
  String get hRoomDetHeader => 'ROOM DOSSIER';

  @override
  String get hRoomDetNotFound => 'Room not found';

  @override
  String get hRoomDetDuplicate => 'Duplicate room';

  @override
  String get hRoomDetSetMaint => 'Set maintenance';

  @override
  String get hRoomDetEndMaint => 'End maintenance';

  @override
  String get hStep1Eyebrow => 'Step 1 / 3';

  @override
  String get hStep1Title => 'Register as a host';

  @override
  String get hStep1SectionTitle => 'Personal information';

  @override
  String get hStep1Subtitle =>
      'Please fill in all information to verify your host account.';

  @override
  String get hStep1NameLabel => 'Full name';

  @override
  String get hStep1NameHint => 'Nguyen Van A';

  @override
  String get hStep1NameError => 'Please enter your full name';

  @override
  String get hStep1PhoneLabel => 'Phone number';

  @override
  String get hStep1PhoneError => 'Invalid phone number';

  @override
  String get hStep1DobLabel => 'Date of birth';

  @override
  String get hStep1AddressLabel => 'Permanent address';

  @override
  String get hStep1AddressHint =>
      'House number, street, ward, district, province/city';

  @override
  String get hStep1AddressError => 'Please enter your address';

  @override
  String get hStep1Next => 'Next';

  @override
  String get hStep1InitError => 'Failed to initialize profile';

  @override
  String get hStep2WarnAtLeastOne =>
      'Please upload at least one side of your ID card';

  @override
  String get hStep2UploadFailed => 'Upload failed';

  @override
  String get hStep2Eyebrow => 'Step 2 / 3';

  @override
  String get hStep2Title => 'Verify ID card';

  @override
  String get hStep2Heading => 'Upload ID card';

  @override
  String get hStep2Subtitle =>
      'Upload photos of the front and back of your ID card to verify your identity.';

  @override
  String get hStep2FrontLabel => 'ID card front';

  @override
  String get hStep2BackLabel => 'ID card back';

  @override
  String get hStep2SecurityNote =>
      'Your ID card photos are encrypted and stored securely. We do not share this information with third parties.';

  @override
  String get hStep2Next => 'Next';

  @override
  String get hStep3Eyebrow => 'Step 3 / 3';

  @override
  String get hStep3Title => 'Payment information';

  @override
  String get hStep3ReceivingAccount => 'Receiving account';

  @override
  String get hStep3Subtitle =>
      'Enter your bank account to receive payments from renters.';

  @override
  String get hStep3BankLabel => 'Bank *';

  @override
  String get hStep3BankHint => 'Select a bank';

  @override
  String get hStep3BankRequired => 'Please select a bank';

  @override
  String get hStep3AccountNumber => 'Account number';

  @override
  String get hStep3AccountNumberRequired => 'Please enter the account number';

  @override
  String get hStep3AccountNumberInvalid => 'Invalid account number';

  @override
  String get hStep3AccountHolder => 'Account holder name';

  @override
  String get hStep3AccountHolderRequired =>
      'Please enter the account holder name';

  @override
  String get hStep3TaxId => 'Tax ID (optional)';

  @override
  String get hStep3SubmitButton => 'Complete registration';

  @override
  String get hStep3SaveFailed => 'Failed to save';

  @override
  String get adminCtrTitle => 'Approve contractors';

  @override
  String get adminCtrApproved => 'Profile approved';

  @override
  String get adminCtrCertVerified => 'Certificate verified';

  @override
  String adminCtrError(Object error) {
    return 'Error: $error';
  }

  @override
  String get adminCtrRejectTitle => 'Reject this profile?';

  @override
  String get adminCtrRejectBody =>
      'The profile will not appear in the directory.';

  @override
  String get adminCtrCancel => 'Cancel';

  @override
  String get adminCtrReject => 'Reject';

  @override
  String get adminCtrRejected => 'Rejected';

  @override
  String get adminCtrLoadFailed => 'Couldn\'t load';

  @override
  String get adminCtrLoadFailedHint => 'Check your connection and try again.';

  @override
  String get adminCtrRetry => 'Retry';

  @override
  String get adminCtrEmptyTitle => 'No profiles awaiting approval';

  @override
  String get adminCtrEmptyHint => 'New profiles will appear here.';

  @override
  String get adminCtrCompanyFallback => 'Contractor';

  @override
  String adminCtrCertNumber(Object number) {
    return 'License: $number';
  }

  @override
  String get adminCtrCertVerifiedLabel => 'verified';

  @override
  String get adminCtrVerify => 'Verify';

  @override
  String get adminCtrApprove => 'Approve';

  @override
  String get adminHomeTitle => 'Admin Dashboard';

  @override
  String get adminHomePending => 'Pending';

  @override
  String get adminHomeApproved => 'Approved';

  @override
  String get adminHomeRejected => 'Rejected';

  @override
  String get adminHomePublished => 'Published';

  @override
  String get adminHomeUsers => 'Users';

  @override
  String get adminHomeToolModerateReel => 'Moderate\nReels';

  @override
  String get adminHomeToolVerifyQueue => 'Verification\nqueue';

  @override
  String get adminHomeToolPlanningRisk => 'Planning\nrisk';

  @override
  String get adminHomeToolTrustedMark => 'Trusted\nmark';

  @override
  String get adminHomeToolApproveContractor => 'Approve\ncontractors';

  @override
  String get adminHomeToolMarketResearch => 'Market\nresearch';

  @override
  String get adminHomeEmptyPending => 'No listings pending review';

  @override
  String get adminHomeEmptyApproved => 'No approved listings yet';

  @override
  String get adminHomeEmptyRejected => 'No rejected listings yet';

  @override
  String adminHomeHost(Object name) {
    return 'Host: $name';
  }

  @override
  String get adminHomeReject => 'Reject';

  @override
  String get adminHomeApprove => 'Approve';

  @override
  String get adminHomeReapprove => 'Re-approve';

  @override
  String get adminHomeUnpublish => 'Unpublish';

  @override
  String get adminHomeRejectReasonTitle => 'Rejection reason';

  @override
  String get adminHomeRejectReasonHint =>
      'Enter a reason so the host knows how to fix it...';

  @override
  String get adminHomeMsgApproved => 'Listing approved';

  @override
  String get adminHomeMsgRejected => 'Listing rejected';

  @override
  String get adminHomeMsgUpdated => 'Listing updated';

  @override
  String get adminHomeMsgFailed => 'Action failed';

  @override
  String get adminReelEyebrow => 'Moderation';

  @override
  String get adminReelTitle => 'Reels';

  @override
  String get adminReelTabPending => 'Pending';

  @override
  String get adminReelTabHidden => 'Hidden';

  @override
  String get adminReelTabPublished => 'Published';

  @override
  String get adminReelEmpty => 'No reels';

  @override
  String get adminReelStatsTitle => 'Operational metrics (30 days)';

  @override
  String get adminReelStatReels => 'reels';

  @override
  String get adminReelStatPending => 'pending';

  @override
  String get adminReelStatViews => 'views';

  @override
  String get adminReelStatLikes => 'likes';

  @override
  String get adminReelStatComments => 'comments';

  @override
  String get adminReelStatStorage => 'storage';

  @override
  String get adminReelStatFailures => 'processing errors';

  @override
  String get adminReelNoCaption => '(no caption)';

  @override
  String adminReelReportCount(Object count) {
    return '$count reports';
  }

  @override
  String adminReelRejectReason(Object reason) {
    return 'Reason: $reason';
  }

  @override
  String get adminReelApprove => 'Approve';

  @override
  String get adminReelHide => 'Hide';

  @override
  String get adminReelReject => 'Reject';

  @override
  String get adminReelRejectTitle => 'Reject reel';

  @override
  String get adminReelReasonLabel => 'Reason *';

  @override
  String get adminReelReasonHint => 'E.g. irrelevant content';

  @override
  String get adminReelApproved => 'Approved — reel is now public';

  @override
  String get adminReelRejected => 'Reel rejected';

  @override
  String get adminReelHidden => 'Reel hidden';

  @override
  String adminReelActionFailed(Object error) {
    return 'Action failed: $error';
  }

  @override
  String get adminVerifTitle => 'Verification queue';

  @override
  String get adminVerifEmpty => 'No requests';

  @override
  String adminVerifLoadError(Object error) {
    return 'Could not load: $error';
  }

  @override
  String adminVerifRateDialogTitle(Object title) {
    return 'Assign verification star — $title';
  }

  @override
  String get adminVerifProperty => 'Property';

  @override
  String adminVerifStarsLabel(Object count) {
    return '$count stars';
  }

  @override
  String get adminVerifConfirm => 'Confirm';

  @override
  String get adminVerifRatedToast => 'Verification star assigned.';

  @override
  String adminVerifError(Object error) {
    return 'Error: $error';
  }

  @override
  String adminVerifSubtitle(Object status, Object date) {
    return 'Status: $status · Requested: $date';
  }

  @override
  String get adminVerifVerifyButton => 'Verify';

  @override
  String get hActionItemsHeader => 'ACTION NEEDED';

  @override
  String get hActionItemsOverdueInvoices => 'Overdue invoices';

  @override
  String get hActionItemsExpiringContracts => 'Expiring contracts';

  @override
  String get hActionItemsOverdueKhaiBao =>
      'Overdue temporary residence declarations';

  @override
  String get hActionItemsMaintenanceRooms => 'Rooms under maintenance';

  @override
  String get hActionItemsZaloFailed => 'Could not create Zalo reminder';

  @override
  String hActionItemsInvoiceDue(Object dueDate, Object amount) {
    return 'Due $dueDate · $amount VND remaining';
  }

  @override
  String get hActionItemsRemindZalo => 'Remind via Zalo';

  @override
  String hActionItemsContractRoom(Object contractId, Object roomId) {
    return 'Contract #$contractId · Room $roomId';
  }

  @override
  String hActionItemsContractExpiry(Object endDate, Object rent) {
    return 'Expires $endDate · $rent VND/mo';
  }

  @override
  String hActionItemsTenant(Object tenantId) {
    return 'Tenant #$tenantId';
  }

  @override
  String hActionItemsCheckIn(Object checkInAt) {
    return 'Check-in $checkInAt';
  }

  @override
  String hActionItemsMaintenanceSince(Object startDate) {
    return 'Since $startDate';
  }

  @override
  String get hActionItemsMaintenanceActive => 'Under maintenance';

  @override
  String get hAnalyticsFilterSelectPeriod => 'Select period';

  @override
  String get hAnalyticsFilterTitle => 'Filter';

  @override
  String get hAnalyticsFilterActive => 'Filtering';

  @override
  String get hAnalyticsFilterBuilding => 'Building';

  @override
  String get hAnalyticsFilterSource => 'Revenue source';

  @override
  String get hAnalyticsFilterRoomType => 'Room type';

  @override
  String get hAnalyticsFilterPeriod => 'Period';

  @override
  String get hAnalyticsFilterClearPeriod => 'Clear period';

  @override
  String get hAnalyticsFilterManageSources => 'Manage sources';

  @override
  String get hAnalyticsFilterReset => 'Reset';

  @override
  String get hAnalyticsFilterApply => 'Apply';

  @override
  String get hCreateContractTitle => 'Create draft contract';

  @override
  String get hCreateContractViewRequestEyebrow => 'VIEWING REQUEST';

  @override
  String get hCreateContractGuest => 'Guest';

  @override
  String get hCreateContractRequestCode => 'Request code';

  @override
  String get hCreateContractWhatHappens => 'WHAT HAPPENS';

  @override
  String get hCreateContractWhatHappensBody =>
      '• Viewing request → status \"Approved\".\n• A temporary Tenant is created (or an existing Tenant with the same phone number is reused).\n• A draft Contract (source = marketplace) links the Tenant and the source room.\n• You keep editing the contract (start date, deposit…) before activating it.';

  @override
  String get hCreateContractConfirm => 'Confirm creating draft contract';

  @override
  String get hCreateContractCreating => 'Creating…';

  @override
  String get hCreateContractError => 'Error';

  @override
  String hCreateContractCreatedDraft(Object id, Object suffix) {
    return 'Draft contract #$id created $suffix';
  }

  @override
  String get hCreateContractPlaceholderTenant => '(temporary tenant)';

  @override
  String get hPublishTitle => 'Publish to marketplace';

  @override
  String get hPublishListingType => 'LISTING TYPE';

  @override
  String get hPublishTitleLabel => 'TITLE (OPTIONAL)';

  @override
  String get hPublishDescLabel => 'DESCRIPTION (OPTIONAL)';

  @override
  String get hPublishDescHint => 'Amenities, location, notes…';

  @override
  String get hPublishPriceLabel =>
      'DISPLAY PRICE (VND, leave blank to use base_price)';

  @override
  String get hPublishPriceHint => 'e.g. 3500000';

  @override
  String get hPublishSubmitting => 'Publishing…';

  @override
  String get hPublishSubmit => 'Confirm listing';

  @override
  String get hPublishHelp =>
      'Listings need admin approval before appearing publicly. You can hide them again at any time from the Sync screen.';

  @override
  String get hPublishSyncSuccess => 'Listing synced to marketplace';

  @override
  String get hPublishError => 'Error';

  @override
  String get hPublishTypeBoardingHouse => 'Boarding house';

  @override
  String get hPublishTypeHomestay => 'Homestay';

  @override
  String get hPublishTypeApartment => 'Apartment';

  @override
  String get hSyncTitle => 'Marketplace sync';

  @override
  String get hSyncHideListingTitle => 'Hide listing';

  @override
  String hSyncHideConfirm(Object roomCode) {
    return 'Hide room $roomCode from the marketplace? The listing will switch to \"hidden\" status and will not be deleted. You can republish it later.';
  }

  @override
  String get hSyncHideAction => 'Hide listing';

  @override
  String get hSyncHidden => 'Listing hidden';

  @override
  String get hSyncError => 'Error';

  @override
  String get hSyncEmptyTitle => 'No rooms to sync yet';

  @override
  String get hSyncEmptySubtitle =>
      'Add rooms to start syncing with the marketplace.';

  @override
  String hSyncMarketplaceStatus(Object status) {
    return 'Marketplace status: $status';
  }

  @override
  String hSyncLastSynced(Object time) {
    return 'Last synced: $time';
  }

  @override
  String get hSyncPublish => 'Publish to marketplace';

  @override
  String get hSyncResync => 'Resync';

  @override
  String get hSyncHide => 'Hide';

  @override
  String get opDiscloseTitle => 'Shared account notice';

  @override
  String get opDiscloseBody =>
      'You are using a shared business account. Please note:';

  @override
  String get opDisclosePointAudit =>
      'All actions are recorded in the audit log under the shared account identity.';

  @override
  String get opDisclosePointPassword =>
      'Changing the password is your company\'s responsibility. The system will not alert you to unusual logins.';

  @override
  String get opDisclosePointRbac =>
      'Individual permissions within the business (RBAC v2) will be available in an upcoming release.';

  @override
  String get opDiscloseAcknowledge => 'I understand';

  @override
  String opDiscloseAckError(Object error) {
    return 'Error while recording: $error';
  }

  @override
  String get opInviteTitle => 'Delegation invitations';

  @override
  String get opInviteEyebrow => 'OPERATOR · INVITATIONS';

  @override
  String get opInviteEmptyTitle => 'No invitations';

  @override
  String get opInviteEmptySubtitle =>
      'When an owner invites you, the invitation will appear here.';

  @override
  String get opInviteOwnerFallback => 'Owner';

  @override
  String opInviteSentDate(Object date) {
    return 'Sent: $date';
  }

  @override
  String get opInviteStatusPending => 'Pending confirmation';

  @override
  String get opInviteReject => 'Decline';

  @override
  String get opInviteAccept => 'Accept';

  @override
  String get opInviteAcceptSuccess => 'Delegation accepted successfully';

  @override
  String get opInviteAcceptError => 'Unable to accept. Please try again.';

  @override
  String get opInviteRejectSuccess => 'Invitation declined';

  @override
  String get opInviteRoleFull => 'Permission: Full operation';

  @override
  String get opInviteRoleAccountant => 'Permission: Accountant';

  @override
  String get opInviteRoleViewer => 'Permission: View only';

  @override
  String opInviteRoleOther(Object preset) {
    return 'Permission: $preset';
  }

  @override
  String get opInviteRoleUnknown => 'Unknown';

  @override
  String get tenantReportSubmittedTitle => 'Report submitted';

  @override
  String get tenantReportSubmittedHeadline => 'Your report has been received';

  @override
  String get tenantReportSubmittedSubtitle =>
      'We will review it and contact you within 24 hours.';

  @override
  String get tenantReportBackHome => 'Back to home';

  @override
  String get tenantReportTitle => 'Report a representative';

  @override
  String get tenantReportEyebrow => 'TENANT · REPORT';

  @override
  String get tenantReportDisclosure =>
      'If you do not recognize the person claiming to be the landlord\'s representative, report it right away. Your information will be kept confidential.';

  @override
  String get tenantReportReasonLabel => 'Reason';

  @override
  String get tenantReportReasonUnknownPerson =>
      'This is not a representative I know';

  @override
  String get tenantReportReasonDifferentInfo =>
      'The information does not match the person collecting payment';

  @override
  String get tenantReportReasonNoNotice => 'The landlord has not notified me';

  @override
  String get tenantReportReasonOther => 'Other reason';

  @override
  String get tenantReportDetailLabel => 'Additional details (optional)';

  @override
  String get tenantReportDetailHint =>
      'Describe the incident in more detail...';

  @override
  String get tenantReportSubmitButton => 'Submit report';

  @override
  String tenantReportSubmitFailed(Object error) {
    return 'Failed to submit report: $error';
  }

  @override
  String get auditTitle => 'Activity log';

  @override
  String auditRepresentative(Object name) {
    return 'On behalf of · $name';
  }

  @override
  String get auditOwnerFallback => 'Owner';

  @override
  String get auditPeriodToday => 'Today';

  @override
  String get auditPeriodWeek => 'This week';

  @override
  String get auditPeriodMonth => 'This month';

  @override
  String get auditLoadError => 'Could not load data';

  @override
  String get auditRetry => 'Retry';

  @override
  String get auditEmptyTitle => 'No activity yet';

  @override
  String get auditEmptySubtitle => 'Operator actions will appear here.';

  @override
  String get auditTlOperator => 'Operator';

  @override
  String get auditTlOwner => 'Owner';

  @override
  String get auditTlAction => 'Action';

  @override
  String get auditTlJustNow => 'Just now';

  @override
  String auditTlMinutesAgo(Object minutes) {
    return '${minutes}m ago';
  }

  @override
  String auditTlHoursAgo(Object hours) {
    return '${hours}h ago';
  }

  @override
  String auditTlDaysAgo(Object days) {
    return '${days}d ago';
  }

  @override
  String get forgotValidateEmail => 'Please enter your email';

  @override
  String get forgotDialogEyebrow => 'Recovery';

  @override
  String get forgotDialogTitle => 'Temporary password';

  @override
  String get forgotDialogBody =>
      'Your account password has been reset. Use the temporary password below to sign in, then change it right away:';

  @override
  String get forgotCopied => 'Copied';

  @override
  String get forgotGotIt => 'Got it';

  @override
  String forgotError(Object error) {
    return 'Error: $error';
  }

  @override
  String get forgotAppBarEyebrow => 'Support';

  @override
  String get forgotTitle => 'Forgot password';

  @override
  String get forgotIntro =>
      'Enter your account email — the system will create a temporary password so you can sign in and then change it right away.';

  @override
  String get forgotEmailHint => 'you@example.com';

  @override
  String get forgotSubmit => 'Create temporary password';

  @override
  String get guestGateTitle => 'Log in to continue';

  @override
  String get guestGateBody =>
      'You need to log in to save listings, contact hosts, book viewings, post listings, or join the community.';

  @override
  String get guestGateLoginRegister => 'Log in / Sign up';

  @override
  String get guestGateLater => 'Later';

  @override
  String get guestGateAccount => 'Account';

  @override
  String get hBatchRemindTitle => 'Batch debt reminders';

  @override
  String hBatchRemindSummary(Object count, Object total) {
    return '$count rooms to remind · total $total';
  }

  @override
  String get hBatchRemindHint =>
      'Tap \"Remind\" to open Zalo and send a reminder for each room.';

  @override
  String get hBatchRemindEmpty => 'No rooms need a reminder 🎉';

  @override
  String hBatchRemindOverdue(Object amount, Object days) {
    return 'Owes $amount · $days days overdue';
  }

  @override
  String get hBatchRemindDone => 'Reminded';

  @override
  String get hBatchRemindRemind => 'Remind';

  @override
  String get hBatchRemindReminding => 'Reminding...';

  @override
  String hBatchRemindRemindAll(Object count) {
    return 'Remind all via Zalo ($count)';
  }

  @override
  String get hCreditNoteInvalidAmount => 'Invalid amount';

  @override
  String get hCreditNoteCreated => 'Credit note created';

  @override
  String get hCreditNoteFailed => 'Creation failed';

  @override
  String get hCreditNoteTitle => 'CREATE CREDIT NOTE';

  @override
  String get hCreditNoteDescription =>
      'A credit note is a valid adjustment on a paid invoice. The original invoice is not changed.';

  @override
  String get hCreditNoteAmountLabel => 'Adjustment amount (VND) *';

  @override
  String get hCreditNoteIssuedDateLabel => 'Issue date';

  @override
  String get hCreditNoteReasonLabel => 'Reason';

  @override
  String get hCreditNoteSubmit => 'Create credit note';

  @override
  String get hInvListTitle => 'INVOICES';

  @override
  String get hInvListBatchCreate => 'Batch create';

  @override
  String get hInvListFilterAll => 'All';

  @override
  String get hInvListStatusDraft => 'Draft';

  @override
  String get hInvListStatusSent => 'Sent';

  @override
  String get hInvListStatusPaid => 'Paid';

  @override
  String get hInvListAllMonths => 'All months';

  @override
  String get hInvListEmpty => 'No invoices yet';

  @override
  String hInvListCreatedCount(Object count) {
    return 'Created $count invoices';
  }

  @override
  String hInvListPeriod(Object start, Object end) {
    return 'Period $start → $end';
  }

  @override
  String get hInvPayTitle => 'RECORD PAYMENT';

  @override
  String get hInvPayRemaining => 'Remaining: ';

  @override
  String get hInvPayAmountLabel => 'Amount (VND) *';

  @override
  String get hInvPayMethodLabel => 'Method';

  @override
  String get hInvPayMethodCash => 'Cash';

  @override
  String get hInvPayMethodBank => 'Bank transfer';

  @override
  String get hInvPayMethodOther => 'Other';

  @override
  String get hInvPayNoteLabel => 'Note';

  @override
  String get hInvPaySubmit => 'Record';

  @override
  String get hInvPayInvalidAmount => 'Invalid amount';

  @override
  String get hInvPayRecordFailed => 'Failed to record payment';

  @override
  String get hMeterOpenFromRoomHint =>
      'Please open from a room\'s detail to enter readings';

  @override
  String hMeterTitleRoom(Object code) {
    return 'READINGS • $code';
  }

  @override
  String get hMeterTitle => 'ELECTRICITY & WATER READINGS';

  @override
  String get hMeterAddTooltip => 'Add';

  @override
  String get hMeterEmpty => 'No readings yet';

  @override
  String hMeterUsageLine(Object kwh, Object water) {
    return 'Electricity: $kwh kWh • Water: $water m³';
  }

  @override
  String get hMeterFormTitle => 'ENTER READING';

  @override
  String get hMeterReadingDate => 'Reading date';

  @override
  String get hMeterElectricity => 'Electricity (kWh)';

  @override
  String get hMeterWater => 'Water (m³)';

  @override
  String get hMeterSave => 'Save reading';

  @override
  String get hMeterSaveFailed => 'Failed to save';

  @override
  String get hOccReportOccupancyRate => 'Occupancy rate';

  @override
  String hOccReportRoomsCount(Object count) {
    return '$count rooms';
  }

  @override
  String get hOccReportByRoom => 'BY ROOM';

  @override
  String get hOccReportNoData => 'No data yet';

  @override
  String get hRevReportExportFailed => 'CSV export failed';

  @override
  String hRevReportInvoiceSubject(Object month) {
    return 'Invoices $month';
  }

  @override
  String get hRevReportTotalRevenue => 'Total revenue';

  @override
  String get hRevReportGrossRevenue => 'Gross revenue';

  @override
  String get hRevReportNetRevenue => 'Net revenue';

  @override
  String get hRevReportNoData => 'No data yet';

  @override
  String get hRevReportViewNewStats => 'View new revenue analytics';

  @override
  String get hRevReportExporting => 'Exporting...';

  @override
  String get hRevReportExportCsv => 'Export this month\'s invoices CSV';

  @override
  String get notifInbox => 'Inbox';

  @override
  String get notifMarkAllRead => 'Mark all read';

  @override
  String get notifEmpty => 'No notifications yet';

  @override
  String get notifContentGone => 'Content no longer exists';

  @override
  String get notifJustNow => 'Just now';

  @override
  String notifMinutesAgo(Object count) {
    return '$count minutes ago';
  }

  @override
  String notifHoursAgo(Object count) {
    return '$count hours ago';
  }

  @override
  String notifDaysAgo(Object count) {
    return '$count days ago';
  }

  @override
  String get planErrTitle => 'Report incorrect data';

  @override
  String get planErrReasonLabel => 'Reason (≥10 characters)';

  @override
  String get planErrReasonHint =>
      'E.g.: This zone is actually residential, not greenery';

  @override
  String get planErrAttachImage => 'Attach photo (optional)';

  @override
  String get planErrImageAttached => 'Photo attached';

  @override
  String get planErrSubmit => 'Submit report';

  @override
  String get planErrSuccessMsg => 'Report submitted. Thank you!';

  @override
  String get planErrMinLength => 'Reason must be at least 10 characters';

  @override
  String get planErrUploading => 'Uploading photo...';

  @override
  String get planErrImageTooLarge => 'Photo too large (max 5 MB)';

  @override
  String get planErrRemoveImage => 'Remove photo';

  @override
  String planErrParcelId(Object id) {
    return 'Parcel ID: $id';
  }

  @override
  String planErrUploadFailed(Object error) {
    return 'Photo upload failed: $error';
  }

  @override
  String planErrSubmitFailed(Object error) {
    return 'Submission failed: $error';
  }

  @override
  String get planProvSelectHint => 'Select province / address';

  @override
  String get planProvTitle => 'Select province / Find address';

  @override
  String get planProvSearchHint => 'Province, address, street, place...';

  @override
  String get planProvNoResults => 'No results found';

  @override
  String get planProvEmptyPrompt => 'Enter a province name or address';

  @override
  String get planProvSectionProvince => 'Provinces / Cities';

  @override
  String get planProvSectionAddress => 'Addresses';

  @override
  String get planProvHasOverlay => 'Has 2030 planning overlay';

  @override
  String get planProvNoOverlay => 'Address only — no overlay yet';

  @override
  String get planWarnTitle => 'Info & planning';

  @override
  String get planWarnReport => 'Report if information is wrong';

  @override
  String get planWarnOk => 'Got it';

  @override
  String planWarnLoadError(Object error) {
    return 'Could not load: $error';
  }

  @override
  String get planWarnNotFound =>
      'No planning information found at this location.';

  @override
  String planWarnRisky(Object zone) {
    return 'This area may be affected by land-use plans ($zone). You can still post a listing but should consider carefully.';
  }

  @override
  String get planWarnSuitable => 'This area is suitable for posting a listing.';

  @override
  String get planWarnZoneLabel => 'Zone';

  @override
  String get planWarnAreaLabel => 'Area';

  @override
  String get planWarnDistrictLabel => 'District';

  @override
  String get hDebtAgingTitle => 'Debts';

  @override
  String get hDebtAgingEmptyTitle => 'No debt data yet';

  @override
  String get hDebtAgingTotal => 'TOTAL DEBT';

  @override
  String get hDebtAgingByBucket => 'BY AGE BUCKET';

  @override
  String hDebtAgingNeedsReminder(Object count) {
    return 'NEEDS REMINDER ($count)';
  }

  @override
  String hDebtAgingBucketDays(Object days) {
    return 'Bucket $days days';
  }

  @override
  String hDebtAgingInvoiceCount(Object count) {
    return '$count invoices';
  }

  @override
  String hDebtAgingOverdue(Object days, Object phone) {
    return '$days days overdue • $phone';
  }

  @override
  String get ctrFilterTitle => 'Filter contractors';

  @override
  String get ctrFilterService => 'Trade';

  @override
  String get ctrFilterProvince => 'Area';

  @override
  String get ctrFilterSort => 'Sort';

  @override
  String get ctrFilterSortHelper =>
      '\"Recommended\" is the system order: featured · Pro plan · verified · rating.';

  @override
  String get ctrFilterAllServices => 'All trades';

  @override
  String get ctrFilterAllProvinces => 'Nationwide';

  @override
  String get ctrFilterProvinceUnavailable =>
      'Could not load the province list — try again later.';

  @override
  String get ctrFilterSortRecommend => 'Recommended';

  @override
  String get ctrFilterSortRating => 'Highest rated';

  @override
  String get ctrFilterSortReviews => 'Most reviewed';

  @override
  String get ctrFilterApply => 'Apply';

  @override
  String get ctrFilterReset => 'Clear';

  @override
  String get ctrListTitleAll => 'Contractors';

  @override
  String get ctrListFilterTooltip => 'Filter contractors';

  @override
  String ctrListResultCount(int count) {
    return '$count contractors';
  }

  @override
  String get ctrListEmptyWidenFilter => 'Widen filter';

  @override
  String get homeConstructionFilterTooltip => 'Filter contractors';

  @override
  String get onboardingSkip => 'Skip';

  @override
  String get onboardingNext => 'Next';

  @override
  String get onboardingStart => 'Get started';

  @override
  String get onboardingHeroTitle => 'Welcome to Vua Nhà';

  @override
  String get onboardingHeroSubtitle =>
      'One app, two worlds — Real estate and Construction.';

  @override
  String get onboardingHeroCardReTitle => 'Real estate';

  @override
  String get onboardingHeroCardReDesc => 'Rent, list, manage rentals';

  @override
  String get onboardingHeroCardBuildTitle => 'Construction';

  @override
  String get onboardingHeroCardBuildDesc => 'Design, build, interior, quotes';

  @override
  String get onboardingReTitle => 'Real estate at your fingertips';

  @override
  String get onboardingReSubtitle =>
      'Find a home, list and manage — all in one place.';

  @override
  String get onboardingReSearch => 'Find a home';

  @override
  String get onboardingReListings => 'Browse rentals';

  @override
  String get onboardingRePost => 'List for rent';

  @override
  String get onboardingReBooking => 'Book a viewing';

  @override
  String get onboardingReRooms => 'Rooms & boarding houses';

  @override
  String get onboardingReManage => 'Manage rentals';

  @override
  String get onboardingBuildTitle => 'Build from idea to finish';

  @override
  String get onboardingBuildSubtitle =>
      'Ideas, contractors and quotes — connected fast.';

  @override
  String get onboardingBuildDesign => 'Design';

  @override
  String get onboardingBuildInterior => 'Interior';

  @override
  String get onboardingBuildConstruct => 'Construction';

  @override
  String get onboardingBuildGallery => 'House designs';

  @override
  String get onboardingBuildKnowledge => 'Building tips';

  @override
  String get onboardingBuildRfq => 'Request a quote';

  @override
  String get onboardingBuildCaption => 'Plus contractor directory & rankings';

  @override
  String get leadSheetTitle => 'Leave your info, we\'ll call you back';

  @override
  String get leadSheetSubtitle => 'Just your name and phone — no login needed.';

  @override
  String get leadFieldName => 'Full name';

  @override
  String get leadFieldPhone => 'Phone number';

  @override
  String get leadFieldNote => 'Note (optional)';

  @override
  String get leadSubmit => 'Send';

  @override
  String get leadValidation => 'Please enter a name and a valid phone number.';

  @override
  String get leadSendError => 'Could not send, please try again.';

  @override
  String get leadSuccessTitle => 'Got it!';

  @override
  String get leadSuccessBody => 'We\'ll contact you soon.';

  @override
  String get leadClose => 'Close';

  @override
  String get guestGateLeaveContact => 'Leave your phone, we call back';

  @override
  String get adminLeadsTitle => 'Callback leads';

  @override
  String get adminLeadsEmpty => 'No leads yet.';

  @override
  String get hubGuest => 'Guest';

  @override
  String get hubSearchHint => 'Enter a keyword...';

  @override
  String get hubBannerTitle => 'Vua Nhà — Find homes fast, build with ease';

  @override
  String get hubBannerSubtitle =>
      'Real estate · Design · Construction · Interior';

  @override
  String get hubNeedTitle => 'What I need';

  @override
  String get hubNeedSubtitle => 'Rent · buy · post for sale';

  @override
  String get hubHaveTitle => 'I have a place to lease';

  @override
  String get hubHaveSubtitle => 'Post it, pick a tenant today';

  @override
  String get demandChooserTitle => 'What do you want to post?';

  @override
  String get demandChooserHave => 'I HAVE A PROPERTY';

  @override
  String get demandChooserNeed => 'I AM LOOKING FOR';

  @override
  String get demandChooserPostRent => 'Post for lease';

  @override
  String get demandChooserPostSale => 'Post for sale';

  @override
  String get demandChooserNeedRent => 'I need to rent';

  @override
  String get demandChooserNeedBuy => 'I need to buy';

  @override
  String get demandChooserHaveHint =>
      'Post a real property: address, photos, price.';

  @override
  String get demandChooserNeedHint =>
      'Say what you are looking for — no photos, done in 30 seconds.';

  @override
  String get demandFormTitleRent => 'I need to rent';

  @override
  String get demandFormTitleBuy => 'I need to buy';

  @override
  String get demandSecArea => 'Preferred area';

  @override
  String get demandSecType => 'Property types';

  @override
  String get demandSecBudget => 'Budget';

  @override
  String get demandSecMore => 'A few more details (optional)';

  @override
  String get demandProvinceHint => 'Select a province';

  @override
  String get demandBudgetFrom => 'From';

  @override
  String get demandBudgetTo => 'To';

  @override
  String get demandBudgetUnitRent => 'million/month';

  @override
  String get demandBudgetUnitBuy => 'billion';

  @override
  String get demandAreaMin => 'Minimum area (m²)';

  @override
  String get demandBedroomsMin => 'Minimum bedrooms';

  @override
  String get demandMoveIn => 'Move-in date';

  @override
  String get demandDuration => 'Rent for (months)';

  @override
  String get demandOccupants => 'Number of occupants';

  @override
  String get demandPayment => 'Payment';

  @override
  String get demandPaymentCash => 'Cash';

  @override
  String get demandPaymentLoan => 'Need a loan';

  @override
  String get demandPurpose => 'Purpose';

  @override
  String get demandPurposeLive => 'To live in';

  @override
  String get demandPurposeInvest => 'Investment';

  @override
  String get demandNeeds => 'Must-haves';

  @override
  String get demandNeedParking => 'Parking';

  @override
  String get demandNeedFreeHours => 'No curfew';

  @override
  String get demandNeedAircon => 'Air conditioning';

  @override
  String get demandNeedPrivate => 'No shared landlord';

  @override
  String get demandNeedPet => 'Pets allowed';

  @override
  String get demandNeedBalcony => 'Balcony';

  @override
  String get demandNote => 'Anything else';

  @override
  String get demandNoteHint => 'E.g. near a school, prefer a low floor…';

  @override
  String get demandSubmit => 'Post request';

  @override
  String get demandSubmitted => 'Posted. Valid for 30 days.';

  @override
  String get demandListTitle => 'Requests';

  @override
  String get demandTabAll => 'All';

  @override
  String get demandTabRent => 'Looking to rent';

  @override
  String get demandTabBuy => 'Looking to buy';

  @override
  String get demandTabMine => 'My requests';

  @override
  String get demandEmpty => 'No requests yet.';

  @override
  String get demandEmptyMine => 'You have not posted any request.';

  @override
  String get demandExpired => 'Expired';

  @override
  String get demandClosed => 'Closed';

  @override
  String get demandActionClose => 'Close';

  @override
  String get demandActionExtend => 'Extend 30 days';

  @override
  String get demandContact => 'Message';

  @override
  String demandDaysLeft(int days) {
    return '$days days left';
  }

  @override
  String get demandNeedLogin => 'Sign in to post a request';

  @override
  String get demandPickTypeFirst => 'Pick at least one property type';

  @override
  String get svcCatalogTitle => 'Home services';

  @override
  String get svcGroupQuick => 'Handyman & quick services';

  @override
  String get svcGroupBuild => 'Design & construction';

  @override
  String get svcQuickHint =>
      'Send a request, we will call back and arrange a worker.';

  @override
  String svcBookNow(String serviceName) {
    return 'Book service · $serviceName';
  }

  @override
  String get svcBookedBody =>
      'We will call you back to confirm and schedule a worker.';

  @override
  String get svcReqTitle => 'Service requests';

  @override
  String get svcReqEmpty => 'No requests yet.';

  @override
  String get svcReqFilterAll => 'All';

  @override
  String get svcReqFilterNew => 'New';

  @override
  String get svcReqFilterDoing => 'In progress';

  @override
  String get svcReqFilterDone => 'Done';

  @override
  String get svcReqSearchHint => 'Search by phone or name';

  @override
  String get svcReqCall => 'Call';

  @override
  String get svcReqSchedule => 'Schedule';

  @override
  String get svcReqNote => 'Admin note';

  @override
  String get svcReqSave => 'Save';

  @override
  String get svcReqSaved => 'Saved';

  @override
  String get svcStatusNew => 'New';

  @override
  String get svcStatusContacted => 'Contacted';

  @override
  String get svcStatusScheduled => 'Scheduled';

  @override
  String get svcStatusDone => 'Done';

  @override
  String get svcStatusCancelled => 'Cancelled';

  @override
  String get svcStatusSpam => 'Spam';

  @override
  String get hubActionTrade => 'Buy · Sell · Rent';

  @override
  String get hubActionPost => 'Post a request';

  @override
  String get hubActionPlanning => 'Info & planning';

  @override
  String get hubActionServices => 'Services';

  @override
  String get hubRowBrokers => 'Top brokers';

  @override
  String get hubRowOwners => 'Owners posting directly';

  @override
  String get hubActionLease => 'For lease';

  @override
  String get hubActionRent => 'Looking to rent';

  @override
  String get hubActionSell => 'For sale';

  @override
  String get hubActionBuy => 'Looking to buy';

  @override
  String get hubFeaturedUnits => 'Featured partners';

  @override
  String get hubServiceUnits => 'Service providers';

  @override
  String get hubHighlights => 'Highlights';

  @override
  String get hubViewAll => 'View all';

  @override
  String get hubNotifications => 'Notifications';

  @override
  String get shellNavHome => 'Home';

  @override
  String get hubFeaturedBrokers => 'Featured agents';

  @override
  String get brokerProfileTitle => 'Agent profile';

  @override
  String get brokerNotFound => 'Profile not found.';

  @override
  String get brokerListings => 'Active listings';

  @override
  String get brokerNoListings => 'No active listings yet.';

  @override
  String brokerListingCount(int count) {
    return '$count active listings';
  }

  @override
  String brokerReviewCount(int count) {
    return '$count reviews';
  }

  @override
  String get brokerStatListings => 'Listings';

  @override
  String get brokerStatAreas => 'Areas';

  @override
  String get brokerStatReviews => 'Reviews';

  @override
  String get brokerStatYears => 'Years';

  @override
  String get brokerMapTitle => 'Deal map';

  @override
  String get brokerReviewsTitle => 'Customer reviews';

  @override
  String get mapLegendTitle => 'Legend';

  @override
  String get mapLegendSale => 'For sale';

  @override
  String get mapLegendStayLong => 'Rent · long stay';

  @override
  String get mapLegendStayShort => 'Rent · short stay';

  @override
  String get mapLegendBusiness => 'Rent · business';

  @override
  String get postGroupStep => 'Property group';

  @override
  String get postTypeStep => 'Property type';

  @override
  String get postGroupStayLong => 'Long-term stay';

  @override
  String get postGroupStayShort => 'Short-term stay';

  @override
  String get postGroupBusiness => 'Business';

  @override
  String get postPickGroupFirst => 'Pick a group first';

  @override
  String get brokerShare => 'Share profile';

  @override
  String get brokerShareCopied => 'Profile link copied';

  @override
  String get pfBasicInfo => 'Basic info';

  @override
  String get pfBasicHelper => 'The name and description customers see first.';

  @override
  String get pfContact => 'Contact';

  @override
  String get pfContactHelper =>
      'Customers call you straight from your profile.';

  @override
  String get pfCapacity => 'Capacity';

  @override
  String get pfCapacityHelper =>
      'Customers judge whether you can handle the job from this.';

  @override
  String get pfDocs => 'Documents & verification';

  @override
  String get pfDocsHelper =>
      'Profiles with approved documents get a badge and rank higher.';

  @override
  String get pfNameHint => 'e.g. Minh Phat Construction';

  @override
  String get pfIntroHint => 'What you do, where, and what you are best at?';

  @override
  String get pfPhoneHint => '09xx xxx xxx';

  @override
  String get pfPhoneInvalid => 'Invalid phone number';

  @override
  String get pfWebHint => 'facebook.com/... or website';

  @override
  String get pfCertHint => 'Fill in if you hold a practice certificate';

  @override
  String get pfUnitScale => 'Company size';

  @override
  String get pfChangeCover => 'Change cover';

  @override
  String pfPickPrefix(String field) {
    return 'Select $field';
  }

  @override
  String pfEstablishedYear(String year) {
    return 'Founded: $year';
  }

  @override
  String get pfEstVerified => 'Verified by documents';

  @override
  String get pfEstPending => 'Awaiting review';

  @override
  String get pfEstPendingHint => 'An admin is checking your documents';

  @override
  String get pfEstRejected => 'Not approved';

  @override
  String get pfEstRejectedHint => 'Tap to see why and resubmit';

  @override
  String get pfEstNone => 'Founding year not verified';

  @override
  String get pfEstNoneHint => 'Tap to submit your business licence';

  @override
  String get pfDiscardTitle => 'Discard changes?';

  @override
  String get pfDiscardBody =>
      'You edited this profile but have not saved. Leaving now loses those changes.';

  @override
  String get pfKeepEditing => 'Keep editing';

  @override
  String get pfDiscard => 'Discard';

  @override
  String get pfScaleCorporation => 'Large corporation';

  @override
  String get pfScaleMedium => 'Mid-size company';

  @override
  String get pfScaleSmall => 'Small company';

  @override
  String get pfScaleCrew => 'Construction crew';

  @override
  String get pfScaleIndividual => 'Individual contractor';

  @override
  String get pfScaleArchitect => 'Architect / studio';

  @override
  String get pfScaleSpecialist => 'Specialist contractor';

  @override
  String get sellerStep => 'What is your role in this listing?';

  @override
  String get sellerStepHelper =>
      'Buyers care about this. Self-declared — Vua Nhà has not verified any documents.';

  @override
  String get sellerOwner => 'Owner posting';

  @override
  String get sellerOwnerDesc => 'It is your own property';

  @override
  String get sellerBroker => 'Posting on behalf / agent';

  @override
  String get sellerBrokerDesc => 'You post for the owner';

  @override
  String get sellerRequired => 'Please pick a role';

  @override
  String get sellerBadgeOwner => 'Owner (self-declared)';

  @override
  String get sellerBadgeBroker => 'Agent (self-declared)';

  @override
  String get hubFeaturedSellers => 'Featured sellers';

  @override
  String get brokerMapExpand => 'Expand';

  @override
  String get brokerMapHint =>
      'Tap a pin to open the listing · drag and pinch to zoom';

  @override
  String get brokerMapHintShort =>
      'Pinch or use +/− to zoom · tap a pin to open the listing';

  @override
  String get planningScreenTitle => 'Info & planning';

  @override
  String get planningCheckAction => 'Info & planning';

  @override
  String get planningTabShort => 'Planning';

  @override
  String get planningLayerToggle => 'Land-use plan 2030 layer';

  @override
  String get planningOpacityLabel => 'Opacity';

  @override
  String get planningZoneLegendTitle => 'Planning legend';

  @override
  String get planningZoneLegendEmpty =>
      'Zoom in to see land types in this area';

  @override
  String get planningZoneLegendRasterNote =>
      'Legend follows the province source · tap a parcel for details';

  @override
  String get planningZoneLegendOther => 'Other types';

  @override
  String get mapClusterTooltip => 'Tap to expand cluster';

  @override
  String get mapSearchHint => 'Search places';

  @override
  String get mapZoomIn => 'Zoom in';

  @override
  String get mapZoomOut => 'Zoom out';

  @override
  String get mapMyLocation => 'My location';

  @override
  String get mapLocationOff => 'Location services are off on this device';

  @override
  String get mapLocationDenied => 'Location permission not granted';

  @override
  String get mapLocationOutside => 'Your location is outside Vietnam';

  @override
  String get mapLocationError => 'Could not get your location, try again later';

  @override
  String get mapSearchEmpty => 'No places found';

  @override
  String get mapLegendHelp => 'What this means';

  @override
  String get mapLegendStayShortDesc =>
      'Rented by the day or a few nights — for holidays, business trips and travel.';

  @override
  String get mapLegendStayLongDesc =>
      'Rented by the month or longer — for settled, everyday living.';

  @override
  String get mapLegendBusinessDesc =>
      'Premises rented for trading, retail, an office or a shop.';

  @override
  String get mapLegendSaleDesc =>
      'Buying or selling property to own and use long term.';

  @override
  String get tradeTabBuy => 'Find a place';

  @override
  String get tradeTabSell => 'Find a client';

  @override
  String get tradeBuyHint => 'Places up for sale and for rent';

  @override
  String get tradeSellHint =>
      'People looking to buy or rent — post so they find you';

  @override
  String get tradeChipAll => 'All';

  @override
  String get tradeChipSale => 'For sale';

  @override
  String get tradeChipShort => 'Short stay';

  @override
  String get tradeShortStaySearchTitle => 'Find a free room by the hour';

  @override
  String get tradeShortStaySearchSub =>
      'Hourly · overnight · daily — see prices and book now';

  @override
  String get tradeChipLong => 'Long stay';

  @override
  String get tradeChipBusiness => 'Business';

  @override
  String get tradeChipNeedBuy => 'Wants to buy';

  @override
  String get tradeChipNeedRent => 'Wants to rent';

  @override
  String get tradeSearchHint => 'Search by title or area';

  @override
  String get tradeFilter => 'Filters';

  @override
  String get tradeFilterTitle => 'Filter results';

  @override
  String get tradePriceRange => 'Price range';

  @override
  String get tradeAreaFrom => 'Area from (m²)';

  @override
  String get tradeBedrooms => 'Bedrooms';

  @override
  String get tradeApply => 'Apply';

  @override
  String get tradeClear => 'Clear';

  @override
  String get tradeEmptyBuy => 'Nothing matches yet';

  @override
  String get tradeEmptySell => 'No matching demand yet';

  @override
  String get tradeEmptyHint =>
      'Try removing a filter or changing your keywords.';

  @override
  String tradeResultCount(int n) {
    return '$n results';
  }

  @override
  String get tfTitle => 'Filter results';

  @override
  String get tfPrice => 'Price range';

  @override
  String get tfArea => 'Floor area';

  @override
  String get tfBedrooms => 'Bedrooms';

  @override
  String get tfSort => 'Sort by';

  @override
  String get tfAny => 'Any';

  @override
  String get tfAreaUnder => 'Under 30 m²';

  @override
  String get tfArea3050 => '30 – 50 m²';

  @override
  String get tfArea5080 => '50 – 80 m²';

  @override
  String get tfAreaOver => 'Over 80 m²';

  @override
  String get tfSortNewest => 'Newest';

  @override
  String get tfSortPriceAsc => 'Price low → high';

  @override
  String get tfSortPriceDesc => 'Price high → low';

  @override
  String get tfReset => 'Reset';

  @override
  String tfSeeCount(int n) {
    return 'See $n listings';
  }

  @override
  String get tfSeeNone => 'Nothing matches';

  @override
  String get tfCounting => 'Counting…';

  @override
  String get tfBillion => 'bn';

  @override
  String get tfMillion => 'm';

  @override
  String get tfNoLimit => 'no limit';

  @override
  String get tfAdvanced => 'Advanced filters';

  @override
  String get tfPropertyType => 'Property type';

  @override
  String get tfDirection => 'Facing (feng shui)';

  @override
  String get tfTrust => 'Trust & quality';

  @override
  String get tfTrustedOnly => 'Trusted listings only';

  @override
  String get tfMinRating => 'Minimum rating';

  @override
  String get tfMinQuality => 'Minimum quality stars';

  @override
  String tfQualityStar(int n) {
    return '$n stars';
  }

  @override
  String get tfSortTrust => 'Trust';

  @override
  String get tfSortRating => 'Top rated';

  @override
  String get tfDirN => 'North';

  @override
  String get tfDirNE => 'Northeast';

  @override
  String get tfDirE => 'East';

  @override
  String get tfDirSE => 'Southeast';

  @override
  String get tfDirS => 'South';

  @override
  String get tfDirSW => 'Southwest';

  @override
  String get tfDirW => 'West';

  @override
  String get tfDirNW => 'Northwest';

  @override
  String get reelSectionTitle => 'Featured reels';

  @override
  String get reelSeeAll => 'See all';

  @override
  String get exploreTradeTitlePlain => 'Explore ';

  @override
  String get exploreTradeTitleAccent => 'Buy · Sell · Rent';

  @override
  String get exploreTradeSubtitle =>
      'All listings for sale and rent,\nwith quick filters';

  @override
  String get exploreTradeCta => 'See all listings';

  @override
  String get homeNewsSection => 'Latest listings';

  @override
  String get homeNewsEmpty => 'No listings yet';

  @override
  String get tfArea2 => 'Search area';

  @override
  String get tfAreaAll => 'Everywhere';

  @override
  String get tfAreaNear => 'Near me';

  @override
  String get tfAreaPlace => 'Place';

  @override
  String get tfPlaceHint => 'Enter a place: \"near Hong Duc University\"…';

  @override
  String get tfRadius => 'Radius';

  @override
  String get tfLocating => 'Getting location…';

  @override
  String get tfLocated => 'Location ready ✓';

  @override
  String get tfGeoOnlyBasic =>
      'When filtering by area, results are sorted by distance.';

  @override
  String get tfNoMatchPlace => 'Place not found';

  @override
  String get filterLocInsecureContext =>
      'The page is served over HTTP, so the browser blocks location.';

  @override
  String get profHostSection => 'Rental management';

  @override
  String get profHostBuildings => 'Buildings & rooms';

  @override
  String get profHostBuildingsSub => 'Buildings, rooms, current tenants';

  @override
  String get profHostContracts => 'Contracts';

  @override
  String get profHostContractsSub => 'Lease contracts and end dates';

  @override
  String get profHostInvoices => 'Invoices';

  @override
  String get profHostInvoicesSub => 'Rent, utilities, cash flow';

  @override
  String get profHostAppointments => 'Viewing requests';

  @override
  String get profHostAppointmentsSub => 'Approve and schedule viewings';

  @override
  String get profHostKyc => 'Host profile';

  @override
  String get profHostKycSub => 'Documents, payout account, verification';

  @override
  String get myReqSubtitle => 'Services you have booked';

  @override
  String get myReqEmptyHint =>
      'Need an electrician, plumber or cleaner? Book once and we\'ll call you back.';

  @override
  String get myReqEmptyCta => 'Browse services';

  @override
  String get myReqStatusContacted => 'Contacted';

  @override
  String get myReqStatusScheduled => 'Scheduled';

  @override
  String get myReqStatusDone => 'Done';

  @override
  String get myReqStatusCancelled => 'Cancelled';

  @override
  String myReqSentAt(String d) {
    return 'Sent $d';
  }

  @override
  String myReqScheduledAt(String d) {
    return 'Scheduled $d';
  }

  @override
  String get profMessages => 'Messages';

  @override
  String get profMessagesSub => 'Chat with hosts and sellers';

  @override
  String get profNextViewing => 'Next viewing';

  @override
  String profNextViewingAt(String d, String t) {
    return '$d · $t';
  }

  @override
  String get saleCall => 'Message';

  @override
  String saleCallNamed(String ten) {
    return 'Message $ten';
  }

  @override
  String get saleShareBtn => 'Share';

  @override
  String get saleQrTitle => 'Scan to open';

  @override
  String get saleQrHint => 'Let your client scan this code';

  @override
  String get saleAreaCover => 'Where the listings are';

  @override
  String get saleReviewsShort => 'What clients say';

  @override
  String get albumSection => 'Projects';

  @override
  String albumUnits(int n) {
    return '$n units';
  }

  @override
  String get albumEmpty => 'This project has no listings yet';

  @override
  String get albumTitle => 'Project';

  @override
  String get albumHidden => 'Hidden';

  @override
  String get albumMine => 'My projects';

  @override
  String get albumMineSub => 'Group listings by building or project';

  @override
  String get albumNew => 'New project';

  @override
  String get albumNameLabel => 'Project name';

  @override
  String get albumNameHint => 'Vinhomes Grand Park — S1';

  @override
  String get albumDescLabel => 'Description (optional)';

  @override
  String get albumPublicLabel => 'Show on my public page';

  @override
  String get albumPublicHint =>
      'Turn off while still collecting — clients won\'t see it';

  @override
  String get albumSave => 'Save';

  @override
  String get albumDelete => 'Delete project';

  @override
  String get albumDeleteAsk => 'Delete this project?';

  @override
  String get albumDeleteNote =>
      'The listings STAY — they just won\'t belong to any project.';

  @override
  String get albumNoneYet => 'No projects yet';

  @override
  String get albumNoneHint =>
      'Group units of the same building so clients can browse them at once.';

  @override
  String get albumAddListings => 'Add listings';

  @override
  String get albumPickTitle => 'Pick listings';

  @override
  String get albumPickEmpty => 'You have no listings yet';

  @override
  String albumPickSave(int n) {
    return 'Add $n listings';
  }

  @override
  String get albumUnitLabel => 'Unit label';

  @override
  String get albumUnitHint => 'Unit 1201';

  @override
  String get albumRemove => 'Remove from project';

  @override
  String get albumSaved => 'Saved';

  @override
  String get albumNeedName => 'Enter a project name';

  @override
  String tfActiveCount(int n) {
    return '$n filters';
  }

  @override
  String get homeMapPreviewTitle => 'Listings near you';

  @override
  String get homeMapPreviewOpen => 'Open map';

  @override
  String get homeMapPreviewEmpty => 'No listings with coordinates yet';

  @override
  String get homeMapLocate => 'Go to my location';

  @override
  String get mapLocationInsecure =>
      'Browsers only allow location over HTTPS. Open this site with an https:// address.';

  @override
  String get mapLocationBlocked =>
      'Location is blocked for this site. Tap the padlock next to the address bar → allow Location → reload.';

  @override
  String get homeMapExpand => 'Expand';

  @override
  String get hubMapSection => 'Where deals are happening';

  @override
  String get shellNavServices => 'Services';

  @override
  String get cardOnMap => 'View on map';

  @override
  String get tradeOpenMap => 'Map';

  @override
  String get hubGreeting => 'Hello,';

  @override
  String get svcGroupDeal => 'Buying, selling & legal';

  @override
  String get svcGroupDealHint => 'Valuation, title transfer, loans, inspection';

  @override
  String get svcGroupDesignBuild => 'Design & Build';

  @override
  String get svcGroupDesignBuildHint =>
      'From drawings to handover, turnkey available';

  @override
  String get svcGroupRepair => 'Quick repairs';

  @override
  String get svcGroupRepairHint => 'A technician the same day';

  @override
  String get svcGroupHomeCare => 'Cleaning & Moving';

  @override
  String get svcGroupHomeCareHint => 'Cleaning, moving, hourly help';

  @override
  String get svcGroupOther => 'Other services';

  @override
  String svcCount(int n) {
    return '$n services';
  }

  @override
  String get svcHeroTitle => 'Whatever you need, there\'s someone';

  @override
  String get svcHeroSubtitle =>
      'Send a request — Vua Nhà calls back and arranges the worker';

  @override
  String get svcSearchHint => 'What do you need today?';

  @override
  String svcStat(int n, int g) {
    return '$n services · $g groups';
  }

  @override
  String get svcNoMatch => 'No service matches';

  @override
  String get svcNoMatchHint => 'Try a shorter word, e.g. “điện” or “sơn”.';

  @override
  String svcGroupCount(int n) {
    return '$n groups';
  }

  @override
  String get loginIdentifier => 'Email or phone number';

  @override
  String get identifierHint => '0912345678 or you@example.com';

  @override
  String get valIdentifierRequired => 'Enter your email or phone number';

  @override
  String get registerEmailOptional => 'Email (optional)';

  @override
  String get registerNeedEmailOrPhone =>
      'Enter at least an email or a phone number';

  @override
  String get registerNoEmailWarning =>
      'Without an email you will need support to recover a forgotten password — reset links are sent by email only.';

  @override
  String get valPhoneInvalid => 'Phone number is not valid (e.g. 0912345678)';

  @override
  String get primingBtnEnable => 'Enable now';

  @override
  String get primingBtnDefer => 'Later';

  @override
  String get primingBtnContinue => 'Continue';

  @override
  String get primingBtnCancel => 'Cancel';

  @override
  String get primingBtnClose => 'Close';

  @override
  String get primingTrustCanDisable => 'Turn off any time';

  @override
  String get primingTrustNoSpam => 'No spam — only useful updates';

  @override
  String get primingSoftReaskNotif =>
      'You have disabled notifications. Enable in Settings to stay in the loop.';

  @override
  String get primingSoftReaskCamera =>
      'You have disabled camera access. Enable in Settings to take photos.';

  @override
  String get primingSoftReaskOpenSettings => 'Open Settings';

  @override
  String get primingSoftReaskDismiss => 'Dismiss';

  @override
  String get primingSettingsNotifTitle => 'Notifications';

  @override
  String get primingSettingsCameraTitle => 'Camera';

  @override
  String get primingSettingsStatusEnabled => 'Enabled';

  @override
  String get primingSettingsStatusDisabled => 'Disabled';

  @override
  String get primingSettingsActionEnable => 'Enable → Go to Settings';

  @override
  String get jp_shikikin => 'Security deposit (敷金)';

  @override
  String get jp_reikin => 'Key money (礼金)';

  @override
  String get jp_koushinryo => 'Renewal fee (更新料)';

  @override
  String get jp_hoshou => 'Guarantee deposit (保証金)';

  @override
  String get jp_brokerage => 'Brokerage fee (仲介手数料)';

  @override
  String get jp_management_fee => 'Management fee (管理費)';

  @override
  String get jp_monthly_rent => 'Monthly rent (月額家賃)';

  @override
  String get jp_shouhizei => 'Consumption tax (消費税)';

  @override
  String get jp_kyouekihi => 'Common service charge (共益費)';

  @override
  String get jp_layout => 'Floor plan (間取り)';

  @override
  String get jp_floor_area => 'Floor area (専有面積)';

  @override
  String get jp_building_year => 'Year built (築年数)';

  @override
  String get jp_structure_rc => 'Reinforced concrete (RC)';

  @override
  String get jp_structure_wood => 'Wooden (木造)';

  @override
  String get jp_structure_steel => 'Steel (鉄骨)';

  @override
  String get jp_structure_src => 'Steel reinforced concrete (SRC)';

  @override
  String get jp_orientation_n => 'North (北)';

  @override
  String get jp_orientation_ne => 'North-east (北東)';

  @override
  String get jp_orientation_e => 'East (東)';

  @override
  String get jp_orientation_se => 'South-east (南東)';

  @override
  String get jp_orientation_s => 'South (南)';

  @override
  String get jp_orientation_sw => 'South-west (南西)';

  @override
  String get jp_orientation_w => 'West (西)';

  @override
  String get jp_orientation_nw => 'North-west (北西)';

  @override
  String get jp_available_from => 'Available from (入居可能日)';

  @override
  String get jp_floor => 'Floor (階数)';

  @override
  String get jp_nearest_station => 'Nearest station (最寄り駅)';

  @override
  String get jp_walk_min_from_station => 'Walk from station (徒歩分)';

  @override
  String get jp_train_line => 'Train line (路線)';

  @override
  String get jp_viewing_request => 'Viewing request (内見リクエスト)';

  @override
  String get jp_select_slots => 'Select time slots';

  @override
  String get jp_slot_confirmed => 'Slot confirmed';

  @override
  String get jp_viewing_status_pending => 'Pending confirmation';

  @override
  String get jp_viewing_status_confirmed => 'Confirmed';

  @override
  String get jp_viewing_status_rejected => 'Rejected';

  @override
  String get jp_viewing_status_cancelled => 'Cancelled';

  @override
  String get jp_viewing_status_completed => 'Completed';

  @override
  String jp_slot_label(int n) {
    return 'Slot $n';
  }

  @override
  String get jp_slots_hint => 'Select up to 3 time slots';

  @override
  String get jp_slots_max_warning => 'You can select up to 3 time slots only';

  @override
  String get jp_apply => 'Apply to rent (入居申込)';

  @override
  String get jp_employer => 'Employer (勤務先)';

  @override
  String get jp_annual_income => 'Annual income (年収)';

  @override
  String get jp_guarantor => 'Guarantor (連帯保証人)';

  @override
  String get jp_emergency_contact => 'Emergency contact (緊急連絡先)';

  @override
  String get jp_upload_documents => 'Upload documents (書類アップロード)';

  @override
  String get jp_application_status_draft => 'Draft';

  @override
  String get jp_application_status_submitted => 'Submitted';

  @override
  String get jp_application_status_under_review => 'Under review';

  @override
  String get jp_application_status_approved => 'Approved';

  @override
  String get jp_application_status_rejected => 'Rejected';

  @override
  String get jp_application_status_withdrawn => 'Withdrawn';

  @override
  String get jp_chat_greeting_formal => 'Hello, how may I assist you?';

  @override
  String get jp_chat_viewing_confirm => 'I confirm the viewing appointment.';

  @override
  String get jp_chat_apology => 'I apologise for any inconvenience.';

  @override
  String get jp_chat_available => 'I am available for a viewing at this time.';

  @override
  String get jp_submit => 'Submit';

  @override
  String get jp_cancel_viewing => 'Cancel viewing';

  @override
  String get jp_reschedule => 'Reschedule';

  @override
  String get jp_step_basic_info => 'Basic information';

  @override
  String get jp_step_employer => 'Employment';

  @override
  String get jp_step_guarantor => 'Guarantor';

  @override
  String get jp_step_documents => 'Documents';

  @override
  String get jp_step_confirm => 'Confirm';

  @override
  String get jp_search_facets_title => 'Filter search';

  @override
  String get jp_layout_filter => 'Room type';

  @override
  String get jp_rent_range => 'Rent range';

  @override
  String get jp_area_range => 'Floor area';

  @override
  String get jp_building_age_max => 'Max building age';

  @override
  String get jp_walk_min_max => 'Max walk from station';

  @override
  String get jp_flag_pets_ok => 'Pets allowed (ペット可)';

  @override
  String get jp_flag_no_guarantor => 'No guarantor required (保証会社不要)';

  @override
  String get jp_flag_instruments_ok => 'Instruments allowed (楽器可)';

  @override
  String get jp_flag_corporate_ok => 'Corporate contract (法人契約可)';

  @override
  String get jp_sales_dashboard_title => 'Agent dashboard';

  @override
  String get jp_assigned_listings => 'Assigned listings';

  @override
  String get jp_pending_viewings => 'Pending viewings';

  @override
  String get jp_pending_applications => 'Pending applications';

  @override
  String get jp_viewing_inbox_title => 'Viewing requests';

  @override
  String get jp_application_queue_title => 'Application queue';

  @override
  String get jp_confirm_slot => 'Confirm slot';

  @override
  String get jp_reject_viewing => 'Reject request';

  @override
  String get jp_application_decision => 'Application decision';

  @override
  String get jp_approve_application => 'Approve';

  @override
  String get jp_reject_application => 'Reject';

  @override
  String get jp_honorific_toggle => 'Use formal language (丁寧語)';

  @override
  String get jp_honorific_on => 'On';

  @override
  String get jp_honorific_off => 'Off';

  @override
  String get appi_consent_title => 'Personal Information Handling';

  @override
  String get appi_purpose_service_use =>
      'Service provision — property search and contract processing';

  @override
  String get appi_purpose_marketing =>
      'Marketing — property recommendations and promotions';

  @override
  String get appi_purpose_analytics =>
      'Analytics — service improvement and usage analysis';

  @override
  String get appi_purpose_data_sharing_broker =>
      'Data sharing with licensed brokers for transaction processing';

  @override
  String get appi_purpose_data_sharing_hoshou =>
      'Data sharing with guarantee companies (保証会社) for screening';

  @override
  String get appi_consent_required_notice =>
      'The purposes marked as required are necessary to provide the service. You must agree to these to continue.';

  @override
  String get appi_privacy_policy_link => 'Privacy Policy (個人情報保護方針)';

  @override
  String get appi_i_agree => 'I agree (同意する)';

  @override
  String get appi_revoke_consent => 'Revoke';

  @override
  String get appi_consent_revoked => 'Consent revoked';

  @override
  String get appi_consent_granted_on => 'Agreed on';

  @override
  String get appi_privacy_settings_title => 'Personal Information (個人情報の取扱い)';

  @override
  String get appi_consent_list_title => 'Consent history';

  @override
  String get appi_no_consents => 'No consents recorded';

  @override
  String get data_export_request => 'Request data export';

  @override
  String get data_export_processing =>
      'Your export is being prepared. This may take a few minutes.';

  @override
  String get data_export_ready => 'Your export is ready. Tap to download.';

  @override
  String get data_export_submit => 'Request export';

  @override
  String get data_export_title => 'Export personal data';

  @override
  String get data_export_description =>
      'We will compile all personal data associated with your account and send you a download link.';

  @override
  String get data_delete_title => 'Delete personal data';

  @override
  String get data_delete_warning =>
      'This will permanently delete all personal data associated with your account. This action cannot be undone.';

  @override
  String get data_delete_cool_off =>
      'A 30-day cooling-off period applies. You may cancel within this period by contacting support.';

  @override
  String get data_delete_confirm => 'Type DELETE to confirm';

  @override
  String get data_delete_submit => 'Request deletion';

  @override
  String get data_delete_type_hint => 'Type DELETE';

  @override
  String get data_delete_type_error => 'Please type DELETE to confirm';

  @override
  String get checkout_title => 'Payment';

  @override
  String get checkout_invoice_summary => 'Invoice summary';

  @override
  String get checkout_total => 'Total';

  @override
  String get payment_method_card => 'Credit / Debit card';

  @override
  String get payment_method_konbini => 'Convenience store (コンビニ)';

  @override
  String get payment_method_bank_transfer => 'Bank transfer (振込)';

  @override
  String get payment_card_placeholder => 'Card payment embed coming soon';

  @override
  String get payment_bank_placeholder =>
      'Bank transfer instructions will be provided after confirmation';

  @override
  String get konbini_voucher_title => 'Payment voucher';

  @override
  String get konbini_voucher_number => 'Voucher number';

  @override
  String get konbini_voucher_deadline => 'Pay by';

  @override
  String get konbini_voucher_instructions =>
      'Take this voucher number to any participating convenience store and pay at the cashier or multi-function terminal.';

  @override
  String get konbini_copy_number => 'Copy number';

  @override
  String get konbini_number_copied => 'Voucher number copied';

  @override
  String get konbini_stores => 'Participating stores';

  @override
  String get payment_status_pending => 'Awaiting payment';

  @override
  String get payment_status_processing => 'Processing';

  @override
  String get payment_status_succeeded => 'Payment complete';

  @override
  String get payment_status_failed => 'Payment failed';

  @override
  String get payment_status_expired => 'Payment expired';

  @override
  String get payment_status_title => 'Payment status';

  @override
  String get payment_status_checking => 'Checking payment status…';

  @override
  String get payment_retry => 'Retry payment';

  @override
  String get payment_contact_support => 'Contact support';

  @override
  String get review_decision => 'Review decision';

  @override
  String get review_approve => 'Approve';

  @override
  String get review_reject => 'Reject';

  @override
  String get review_needs_info => 'Request more information';

  @override
  String get review_reason => 'Reason (optional)';

  @override
  String get review_reason_hint => 'Provide a reason for this decision';

  @override
  String get review_submit => 'Submit decision';

  @override
  String get review_submitting => 'Submitting…';

  @override
  String get review_submitted => 'Decision submitted';

  @override
  String get review_applicant_info => 'Applicant information';

  @override
  String get review_employer_info => 'Employment information';

  @override
  String get review_guarantor_info => 'Guarantor information';

  @override
  String get review_documents => 'Documents';

  @override
  String get review_no_documents => 'No documents uploaded';

  @override
  String get it_session_title => 'IT重説 — Online Explanation';

  @override
  String get it_session_takken_shi_info => 'Licensed Real Estate Agent (宅建士)';

  @override
  String get it_session_license_number => 'License number';

  @override
  String get it_session_consent_notice =>
      'This session will be recorded for legal compliance. The recording will be retained for 5 years in accordance with the Real Estate Brokerage Act.';

  @override
  String get it_session_i_consent =>
      'I consent to recording and the explanation of the important items';

  @override
  String get it_session_join_zoom => 'Join via Zoom';

  @override
  String get it_session_recording_notice => 'Recording notice';

  @override
  String get it_session_consent_required =>
      'You must consent to the recording before joining';

  @override
  String get econtract_title => 'Electronic contract (電子契約)';

  @override
  String get econtract_status_pending => 'Awaiting signature';

  @override
  String get econtract_status_signed => 'Signed';

  @override
  String get econtract_status_expired => 'Expired';

  @override
  String get econtract_status_cancelled => 'Cancelled';

  @override
  String get econtract_sign_button => 'Sign contract';

  @override
  String get econtract_download_signed => 'Download signed contract';

  @override
  String get econtract_open_external => 'Open in browser';

  @override
  String get econtract_signing_note =>
      'You will be redirected to the signing service. Return here after signing.';

  @override
  String get econtract_status_label => 'Contract status';

  @override
  String get jp_renewal_eyebrow => 'Renewal';

  @override
  String get jp_renewal_title => 'Lease Renewal';

  @override
  String get jp_renewal_contract_summary => 'Contract Summary';

  @override
  String get jp_renewal_property => 'Property';

  @override
  String get jp_renewal_room => 'Room';

  @override
  String get jp_renewal_current_term_end => 'Current Term End';

  @override
  String get jp_renewal_new_term_end => 'New Term End';

  @override
  String get jp_renewal_total_fee => 'Total Renewal Fee';

  @override
  String get jp_renewal_confirm_cta => 'Confirm Renewal';

  @override
  String get jp_renewal_decline_cta => 'Request Renegotiation';

  @override
  String get jp_renewal_confirm_title => 'Confirm Renewal';

  @override
  String get jp_renewal_confirm_notice =>
      'A renewal fee invoice will be issued after confirmation.';

  @override
  String get jp_renewal_confirm_submit => 'Confirm & Renew';

  @override
  String get jp_renewal_status_confirmed => 'Renewal confirmed.';

  @override
  String get jp_renewal_status_declined => 'Renegotiation request received.';

  @override
  String get jp_settlement_eyebrow => 'Deposit Settlement';

  @override
  String get jp_settlement_owner_title => 'Itemize Deductions';

  @override
  String get jp_settlement_tenant_title => 'Review Settlement';

  @override
  String get jp_settlement_deposit_summary => 'Deposit Summary';

  @override
  String get jp_settlement_property => 'Property';

  @override
  String get jp_settlement_room => 'Room';

  @override
  String get jp_settlement_tenant => 'Tenant';

  @override
  String get jp_settlement_deductions => 'Deduction Items';

  @override
  String get jp_settlement_no_deductions => 'No deduction items';

  @override
  String get jp_settlement_add_deduction => 'Add Item';

  @override
  String get jp_settlement_remove_deduction => 'Remove';

  @override
  String get jp_settlement_deduction_item => 'Item';

  @override
  String get jp_settlement_deduction_title => 'Item Name';

  @override
  String get jp_settlement_deduction_amount => 'Amount (¥)';

  @override
  String get jp_settlement_deduction_photos => 'Photos (optional, max 3)';

  @override
  String get jp_settlement_net_refund => 'Net Refund';

  @override
  String get jp_settlement_submit_to_tenant => 'Send to Tenant';

  @override
  String get jp_settlement_accept_cta => 'Accept Settlement';

  @override
  String get jp_settlement_dispute_cta => 'Dispute';

  @override
  String get jp_settlement_dispute_title => 'Dispute';

  @override
  String get jp_settlement_dispute_description =>
      'Please describe your reason for disputing.';

  @override
  String get jp_settlement_dispute_reason_label => 'Reason for Dispute';

  @override
  String get jp_settlement_dispute_submit => 'Submit Dispute';

  @override
  String get jp_settlement_status_accepted =>
      'Settlement accepted. Refund process started.';

  @override
  String get jp_settlement_status_disputed => 'Dispute submitted.';

  @override
  String get jp_kpi_eyebrow => 'Admin';

  @override
  String get jp_kpi_dashboard_title => 'KPI Dashboard';

  @override
  String get jp_kpi_prefecture_label => 'Prefecture';

  @override
  String get jp_kpi_all_japan => 'All Japan';

  @override
  String get jp_kpi_active_listings => 'Active Listings';

  @override
  String get jp_kpi_pending_applications => 'Pending Applications';

  @override
  String get jp_kpi_active_contracts => 'Active Contracts';

  @override
  String get jp_kpi_avg_days_to_sign => 'Avg Days to Sign';

  @override
  String get jp_kpi_monthly_revenue => 'Monthly Revenue';

  @override
  String get jp_deletion_eyebrow => 'Account';

  @override
  String get jp_deletion_title => 'Delete Account';

  @override
  String get jp_deletion_settings_subtitle =>
      'Account and all data will be deleted in 30 days';

  @override
  String get jp_deletion_warning =>
      'Deleting your account will permanently remove all data listed below. This action cannot be undone.';

  @override
  String get jp_deletion_bullet_data => 'Personal information & profile';

  @override
  String get jp_deletion_bullet_contracts => 'Contracts & transaction history';

  @override
  String get jp_deletion_bullet_irreversible => 'This action cannot be undone';

  @override
  String get jp_deletion_cooloff_notice =>
      'A 30-day cooling-off period applies from the date of your deletion request. Contact support to cancel within this period.';

  @override
  String get jp_deletion_schedule_cta => 'Schedule Deletion';

  @override
  String get jp_deletion_days_remaining => 'days until deletion';

  @override
  String get jp_deletion_scheduled_notice =>
      'Your account deletion is scheduled. You can cancel within the cooling-off period.';

  @override
  String get jp_deletion_support_contact =>
      'To cancel, contact support@ancu365.jp.';

  @override
  String get jp_deletion_cancel_cta => 'Cancel Deletion Request';

  @override
  String get jp_deletion_cancel_confirm_title => 'Cancel Deletion Request';

  @override
  String get jp_deletion_cancel_confirm_body =>
      'Are you sure you want to cancel the deletion request?';

  @override
  String get jp_deletion_cancel_no => 'Go Back';

  @override
  String get jp_deletion_cancel_yes => 'Yes, Cancel';

  @override
  String get jp_deletion_confirm_sheet_title => 'Final Confirmation';

  @override
  String get jp_deletion_confirm_sheet_body =>
      'Please type your registered email address to continue.';

  @override
  String get jp_deletion_confirm_email_label => 'Email Address';

  @override
  String get jp_deletion_confirm_email_hint => 'Enter your registered email';

  @override
  String get jp_deletion_confirm_email_error => 'Email address does not match';

  @override
  String get jp_deletion_confirm_submit => 'Schedule Deletion';

  @override
  String get jp_facet_pets_ok_label => 'Pets OK';

  @override
  String get jp_facet_walk_min_label => 'Walk (min)';

  @override
  String jp_facet_walk_min_value(int min) {
    return 'Within $min min walk';
  }

  @override
  String get jp_facet_layout_label => 'Floor Plan';

  @override
  String get helpCenterTitle => 'Help Center';

  @override
  String get helpCenterSearchHint => 'Search questions...';

  @override
  String get helpCenterNoResults => 'No results found';

  @override
  String get helpCenterArticleNotFound => 'Article not found';

  @override
  String get helpCenterLoadError => 'Failed to load article. Please try again.';

  @override
  String get helpCenterComingSoon =>
      'Content is being prepared. Please check back later.';

  @override
  String get legalFooterTokusho => 'Specified Commercial Transactions Act';

  @override
  String get legalFooterTerms => 'Terms of Service';

  @override
  String get legalFooterPrivacy => 'Privacy Policy';

  @override
  String get legalFooterAppiRequest => 'APPI Disclosure Request';

  @override
  String get legalFooterOperator => 'Operator Information';

  @override
  String get legalFooterCopyright => '© 2026 Synora K.K. All rights reserved.';
}
