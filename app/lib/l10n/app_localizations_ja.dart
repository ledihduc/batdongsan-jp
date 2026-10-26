// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Japanese (`ja`).
class AppLocalizationsJa extends AppLocalizations {
  AppLocalizationsJa([String locale = 'ja']) : super(locale);

  @override
  String get loginAccountType => 'アカウント種別';

  @override
  String get loginAccountTypeHint => 'ログインするアカウント種別を選択してください';

  @override
  String get loginAccountTypeRequired => 'アカウント種別を選択してください';

  @override
  String get loginAccountTypeMismatch =>
      'このアカウントには選択した役割へのアクセス権がありません。別のアカウント種別を選ぶか、管理者にお問い合わせください。';

  @override
  String get loginAccountPickerHelp =>
      '利用する役割を選択してください。アカウントにその役割へのアクセス権が必要です。';

  @override
  String get loginAccountPickerClose => 'アカウント選択を閉じる';

  @override
  String get loginRoleCustomer => 'お部屋探し';

  @override
  String get loginRoleCustomerDescription => '購入・賃貸物件を探し、内見予約を管理できます。';

  @override
  String get loginRoleSale => '営業・仲介担当';

  @override
  String get loginRoleSaleDescription => 'お客様、物件、取引を管理できます。';

  @override
  String get loginRoleOwner => 'オーナー';

  @override
  String get loginRoleOwnerDescription => '物件、部屋、入居者を管理できます。';

  @override
  String get loginRoleAdmin => '管理者';

  @override
  String get loginRoleAdminDescription => 'システム管理アクセス権を持つアカウント向け。';

  @override
  String get loginGuestBrowse => 'ログインせずに続ける';

  @override
  String get appTitle => 'Ancu365';

  @override
  String get settingsTitle => '設定とプライバシー';

  @override
  String get settingsEyebrow => 'アカウント';

  @override
  String get sectionAccount => 'アカウント';

  @override
  String get editProfile => 'プロフィール編集';

  @override
  String get editProfileSub => '氏名、写真、電話番号';

  @override
  String get changePassword => 'パスワードを変更';

  @override
  String get sectionPreferences => '設定';

  @override
  String get language => '言語';

  @override
  String get chooseLanguage => '言語を選択';

  @override
  String get notifications => '通知';

  @override
  String get darkMode => 'ダークモード';

  @override
  String get comingSoon => '近日公開';

  @override
  String get logout => 'ログアウト';

  @override
  String get daTitle => 'アカウント削除';

  @override
  String get daSubtitle => 'アカウントと個人データを完全に削除します';

  @override
  String get daDialogTitle => 'アカウントを削除しますか?';

  @override
  String get daDialogBody =>
      'この操作は取り消せません。個人情報はすべて削除され、再度ログインすることはできなくなります。パスワードを入力して確定してください。';

  @override
  String get daPasswordHint => '現在のパスワード';

  @override
  String get daPasswordRequired => '確定するにはパスワードを入力してください';

  @override
  String get daConfirm => 'アカウント削除';

  @override
  String get daSuccess => 'アカウントを削除しました';

  @override
  String get daFailed => 'アカウントの削除に失敗しました';

  @override
  String get blockUser => 'このユーザーをブロック';

  @override
  String get blockUserSub => 'このユーザーのコンテンツが表示されなくなります';

  @override
  String get blockConfirmTitle => 'このユーザーをブロックしますか?';

  @override
  String get blockConfirmBody =>
      'このユーザーの投稿、動画、コメントが表示されなくなります。設定からブロックを解除できます。';

  @override
  String get blockAction => 'ブロック';

  @override
  String get blockDone => 'ユーザーをブロックしました';

  @override
  String get blockFailed => 'ブロックできませんでした。後ほど再度お試しください';

  @override
  String get unblock => 'ブロック解除';

  @override
  String get unblockDone => 'ブロックを解除しました';

  @override
  String get blockedUsersTitle => 'ブロックしたユーザー';

  @override
  String get blockedUsersSub => 'ブロックしたユーザーを管理します';

  @override
  String get blockedEmpty => 'ブロックしているユーザーはいません';

  @override
  String get reportComment => 'コメントを報告';

  @override
  String get actionsNounComment => 'コメント';

  @override
  String get privacyPolicy => 'プライバシーポリシー';

  @override
  String get termsOfUse => '利用規約';

  @override
  String get sectionLegal => '法的情報';

  @override
  String get logoutConfirm => '本当にログアウトしますか?';

  @override
  String get loggedOut => 'ログアウトしました';

  @override
  String get cancel => 'キャンセル';

  @override
  String get vietnamese => 'ベトナム語';

  @override
  String get english => '英語';

  @override
  String get chinese => '中国語';

  @override
  String get loginEyebrow => 'スピーディ・透明な賃貸';

  @override
  String get loginTagline => '物件を探す、借りる、掲載する — シンプルで透明。';

  @override
  String get loginEmail => 'メールアドレス';

  @override
  String get loginPassword => 'パスワード';

  @override
  String get loginForgot => 'パスワードをお忘れですか?';

  @override
  String get loginButton => 'ログイン';

  @override
  String get loginFailed => 'ログインに失敗しました';

  @override
  String get loginExitHome => 'ホームへ戻る';

  @override
  String get loginOr => 'または';

  @override
  String get loginNoAccount => 'アカウントをお持ちでないですか? ';

  @override
  String get loginRegisterNow => '新規登録';

  @override
  String get loginDemoAccounts => 'デモアカウント';

  @override
  String get demoTenant => '入居者';

  @override
  String get demoHost => 'オーナー';

  @override
  String get demoAdmin => '管理者';

  @override
  String get valEmailRequired => 'メールアドレスを入力してください';

  @override
  String get valEmailInvalid => 'メールアドレスの形式が正しくありません';

  @override
  String get valPasswordRequired => 'パスワードを入力してください';

  @override
  String get loginContinueGoogle => 'Googleで続ける';

  @override
  String get loginContinueFacebook => 'Facebookで続ける';

  @override
  String loginOauthMaintenance(String provider) {
    return '$providerログインはメンテナンス中です。後ほどお試しください。';
  }

  @override
  String get demoDesigner => 'デザイン会社';

  @override
  String get demoBuilder => '施工業者';

  @override
  String get demoInterior => 'インテリア会社';

  @override
  String get emailHint => 'you@example.com';

  @override
  String get passwordHint => '6文字以上';

  @override
  String get registerEyebrow => '新規登録';

  @override
  String get registerTitle => 'アカウント作成';

  @override
  String get registerWelcome => 'ようこそ';

  @override
  String get registerSubtitle => '無料アカウントを作成して、物件探しや掲載を始めましょう。';

  @override
  String get registerName => '氏名';

  @override
  String get registerPhoneOptional => '電話番号（任意）';

  @override
  String get registerConfirmPassword => 'パスワードの確認';

  @override
  String get registerAgreeTerms => '利用規約とプライバシーポリシーに同意します';

  @override
  String get registerNeedAgree => '利用規約に同意する必要があります';

  @override
  String get registerFailed => '登録に失敗しました';

  @override
  String get registerHaveAccount => 'すでにアカウントをお持ちですか？ ';

  @override
  String get valRequired => '必須';

  @override
  String get valPasswordMin => '6文字以上入力してください';

  @override
  String get valPasswordMismatch => 'パスワードが一致しません';

  @override
  String get svcRealEstate => '不動産';

  @override
  String get svcRental => '賃貸物件';

  @override
  String get svcIndustrial => '産業用不動産';

  @override
  String get svcMap => '地図';

  @override
  String get svcConstruction => '建築';

  @override
  String get svcNew => 'NEW';

  @override
  String get svcDesign => 'デザイン';

  @override
  String get svcBuild => '建築';

  @override
  String get svcInterior => 'インテリア';

  @override
  String get svcCommunityTitle => '不動産コミュニティ';

  @override
  String get svcCommunitySubtitle => 'Q&A、エリアレビュー、ルームメイト探し…';

  @override
  String get svcLeaderboardTitle => 'パートナーランキング';

  @override
  String get svcLeaderboardSubtitle => '分野別ランキング：デザイン、建築、インテリア…';

  @override
  String get shellLoginToPostHouse => '物件を賃貸として掲載するにはログインしてください。';

  @override
  String get shellBecomeHostTitle => 'ホストになる';

  @override
  String get shellBecomeHostBody => '最初の物件を投稿すると、自動的にホストにアップグレードされます。続けますか？';

  @override
  String get shellContinue => '続ける';

  @override
  String get shellLoginToPostConstruction => '建築関連の投稿を行うにはログインしてください。';

  @override
  String get shellPostRequest => 'リクエスト投稿';

  @override
  String get shellPostListing => '物件を掲載';

  @override
  String get shellNavRealEstate => 'ニュース';

  @override
  String get shellNavConstruction => '建築';

  @override
  String get shellNavWishlist => 'お気に入り';

  @override
  String get shellNavProfile => 'プロフィール';

  @override
  String get shellNavOverview => '概要';

  @override
  String get shellNavRooms => '賃貸';

  @override
  String get shellNavRequests => 'リクエスト';

  @override
  String get shellHostBuildingsHeader => '賃貸 · 建物台帳';

  @override
  String get drawerCommonSection => '共通';

  @override
  String get hubCommonSection => '共通';

  @override
  String get drawerMessages => 'メッセージ';

  @override
  String get drawerSystemAdmin => 'システム管理';

  @override
  String get drawerHelp => 'ヘルプ';

  @override
  String get drawerAbout => 'このアプリについて';

  @override
  String get drawerRealEstateSection => '不動産';

  @override
  String get drawerMapPlanning => '不動産・都市計画マップ';

  @override
  String get drawerHousesForRent => '賃貸物件';

  @override
  String get drawerIndustrialRealEstate => '産業用不動産';

  @override
  String get drawerPostBusinessSection => '投稿とビジネス';

  @override
  String get drawerConstructionBusinessSection => '依頼と見積もり';

  @override
  String get drawerPostRental => '賃貸物件を掲載';

  @override
  String get drawerBecomeHost => 'オーナー登録';

  @override
  String get drawerConstructionSection => '施工';

  @override
  String get drawerContractorDirectory => '施工業者一覧';

  @override
  String get drawerDesignLibrary => 'デザインライブラリ';

  @override
  String get drawerPartnerLeaderboard => 'パートナーランキング';

  @override
  String get drawerPostConstructionRequest => '施工依頼を投稿';

  @override
  String get drawerContractorChannel => '施工業者チャネル';

  @override
  String get drawerTagline => '不動産 & 施工';

  @override
  String get drawerViewProfile => 'プロフィール表示';

  @override
  String get drawerLoginPrompt => 'ログインして物件保存・メッセージ送信・投稿を行いましょう。';

  @override
  String get drawerLoginRegister => 'ログイン / 新規登録';

  @override
  String get actionsNounHouse => '物件';

  @override
  String get actionsNounPost => '投稿';

  @override
  String get actionsUnsave => '保存を解除';

  @override
  String actionsSaveNoun(Object noun) {
    return '$nounを保存';
  }

  @override
  String get actionsSaveSub => '保存済み一覧で後から確認できます';

  @override
  String actionsLoginToSave(Object noun) {
    return 'この$nounを保存するにはサインインしてください。';
  }

  @override
  String get actionsEdit => '編集';

  @override
  String get actionsDelete => '削除';

  @override
  String get actionsReportWrongInfo => '情報の誤りを報告';

  @override
  String get actionsReportWrongInfoSub => '投稿者に修正を依頼します(苦情ではありません)';

  @override
  String actionsReportNoun(Object noun) {
    return '$nounを通報';
  }

  @override
  String get actionsReportViolationSub => '管理者へ送信して確認します';

  @override
  String get actionsLoginToFeedback => 'フィードバックを送信するにはサインインしてください。';

  @override
  String get actionsFeedbackSent => '投稿者にフィードバックを送信しました。ありがとうございます。';

  @override
  String get actionsReportSent => '通報を送信しました。管理者が確認します。';

  @override
  String get actionsRateLimited => '送信回数が多すぎます。しばらく経ってから再度お試しください。';

  @override
  String get actionsSendFailed => '送信に失敗しました。もう一度お試しください。';

  @override
  String get actionsWrongInfoDesc => '投稿者に確認の通知が届きます。あなたの身元は公開されません。';

  @override
  String get actionsWrongInfoHint => '例:価格変更、賃貸済み、住所間違いなど';

  @override
  String get actionsSend => '送信';

  @override
  String get actionsChooseReason => '最も当てはまる理由をお選びください';

  @override
  String get actionsReasonScam => '詐欺・虚偽物件';

  @override
  String get actionsReasonSpam => 'スパム・繰り返し投稿';

  @override
  String get actionsReasonDuplicate => '他の物件と重複';

  @override
  String get actionsReasonInappropriate => '不適切な内容';

  @override
  String get actionsReasonOther => 'その他の理由';

  @override
  String get homeMenuTooltip => 'メニュー';

  @override
  String get homeSearchTooltip => '検索';

  @override
  String get worldRealEstateLabel => '不動産';

  @override
  String get worldConstructionLabel => '建築 · デザイン';

  @override
  String get homeAdvancedFilterTooltip => '詳細フィルター';

  @override
  String get homeLoginPromptSaveContactPost => '物件の保存・連絡・掲載にはログインしてください。';

  @override
  String get homeAll => 'すべて';

  @override
  String get homeRealEstateReels => '不動産リール';

  @override
  String get homeNoMoreRooms => '— 他に部屋はありません —';

  @override
  String get homeLoadListFailed => '物件を読み込めませんでした';

  @override
  String get homeNoMatchingListings => '条件に合う物件はまだありません';

  @override
  String get homeCheckNetworkRetry => 'ネットワーク接続を確認してもう一度お試しください。';

  @override
  String get homeTryRemoveFilters => 'いくつかのフィルターを外すとさらに物件が表示されます。';

  @override
  String get homeRetry => '再試行';

  @override
  String get homeClearFilters => 'フィルターをクリア';

  @override
  String get homeLoginToSaveFavorite => 'お気に入り物件を保存するにはログインしてください。';

  @override
  String get homeHost => 'ホスト';

  @override
  String get homeSave => '保存';

  @override
  String get homeContact => '連絡';

  @override
  String get homeDetails => '詳細';

  @override
  String get homeLoginToMessageHost => 'ホストにメッセージするにはログインしてください。';

  @override
  String homeAreaM2(Object area) {
    return '$area m²';
  }

  @override
  String homeDistanceAway(Object distance) {
    return '$distance離れています';
  }

  @override
  String get homeFull => '満室';

  @override
  String homeAvailableUnits(Object available, Object total) {
    return '空室 $available/$total';
  }

  @override
  String get homeTabRent => '賃貸';

  @override
  String get homeTabSale => '売却';

  @override
  String get homeFilterRent => 'フィルター：賃貸';

  @override
  String get homeFilterSale => 'フィルター：売却';

  @override
  String get filterTitle => '検索・フィルタ';

  @override
  String get filterReset => 'リセット';

  @override
  String get filterSectionSearchArea => '検索エリア';

  @override
  String get filterSectionPriceRange => '価格帯';

  @override
  String get filterMaxPriceLabel => '上限価格:';

  @override
  String filterPriceValueVnd(Object value) {
    return '$value万円';
  }

  @override
  String filterPriceValueShort(Object value) {
    return '$value万';
  }

  @override
  String get filterSectionArea => '面積(㎡)';

  @override
  String get filterAreaFrom => '下限';

  @override
  String get filterAreaTo => '上限';

  @override
  String get filterSectionBedrooms => '寝室数';

  @override
  String get filterAny => '指定なし';

  @override
  String get filterSectionPropertyType => '物件種別';

  @override
  String get filterClearAll => 'すべてクリア';

  @override
  String get filterApply => 'フィルタを適用';

  @override
  String get filterModeAll => 'すべて';

  @override
  String get filterModeNearby => '近隣';

  @override
  String get filterModePlace => '場所';

  @override
  String get filterPlaceHint => '場所を入力:「○○大学の近く」など…';

  @override
  String get filterLocationUpdate => '現在地を設定済み — タップで更新';

  @override
  String get filterGetCurrentLocation => '現在地を取得';

  @override
  String get filterRadiusLabel => '半径:';

  @override
  String filterRadiusKm(Object value) {
    return '${value}km';
  }

  @override
  String get filterLocationAcquired => '現在地を取得しました ✓';

  @override
  String get filterLocServiceOff => 'デバイスの位置情報がオフです。オンにして再度お試しください。';

  @override
  String get filterLocDenied => '位置情報の許可が必要です。再度試して許可してください。';

  @override
  String get filterLocDeniedForever => '位置情報がブロックされています。設定で許可してください。';

  @override
  String get filterLocOutOfVietnam => 'サービス対象外の地域です。';

  @override
  String get filterLocError => '現在地を取得できませんでした。再度お試しください。';

  @override
  String get filterPrimingTitle => '近くの物件を探す';

  @override
  String get filterPrimingBody =>
      '位置情報を有効にすると、最寄りの物件を正確な距離とともに表示できます。Ancu365は近隣検索時のみ位置情報を使用します。';

  @override
  String get filterPrimingLater => '後で';

  @override
  String get filterEnableLocation => '位置情報を有効化';

  @override
  String get filterNeedLocationFirst => '適用する前に現在地を取得してください。';

  @override
  String get addProjPdfUploadError => 'PDFファイルをアップロードできませんでした';

  @override
  String get addProjTitleRequired => 'プロジェクト名を入力してください';

  @override
  String get addProjWaitImages => '画像のアップロードが完了するまでお待ちください';

  @override
  String get addProjNeedImage => 'プロジェクトの写真を1枚以上追加してください';

  @override
  String get addProjUpdated => '更新しました';

  @override
  String get addProjPosted => '投稿しました。管理者による確認が行われます。';

  @override
  String addProjError(Object error) {
    return 'エラー:$error';
  }

  @override
  String get addProjEyebrow => '業者チャンネル';

  @override
  String addProjEditTitle(Object type) {
    return '$typeを編集';
  }

  @override
  String get addProjTypeDesign => 'デザイン';

  @override
  String get addProjTypeWork => 'プロジェクト';

  @override
  String get addProjCreateDesign => 'デザインを投稿';

  @override
  String get addProjCreateWork => 'プロジェクトを投稿';

  @override
  String addProjPhotoSection(Object type) {
    return '$typeの写真';
  }

  @override
  String get addProjPhotoHelper => '1枚目がカバー写真になります。長押しでカバー設定・削除。最大10枚まで。';

  @override
  String get addProjBasicInfo => '基本情報';

  @override
  String get addProjTitleLabel => 'プロジェクト名';

  @override
  String get addProjTitleHintDesign => '例:モダン3階建てヴィラ 9×16m';

  @override
  String get addProjTitleHintWork => '例:ナム様邸 3階建てタウンハウス - 7区';

  @override
  String get addProjDescLabel => '説明';

  @override
  String get addProjDescHint => '規模、素材、特長など…';

  @override
  String get addProjFieldLabel => '分野';

  @override
  String get addProjFieldBuild => '建築';

  @override
  String get addProjFieldInterior => 'インテリア';

  @override
  String get addProjYearLabel => '完成年';

  @override
  String get addProjSpecsTitle => '住宅モデル仕様';

  @override
  String get addProjSpecsHelper => 'デザインライブラリの絞り込みに正しく表示されるようになります。';

  @override
  String get addProjHouseTypeLabel => '住宅タイプ';

  @override
  String get addProjStyleLabel => 'スタイル';

  @override
  String get addProjFloorsLabel => '階数';

  @override
  String get addProjBedroomsLabel => '寝室数';

  @override
  String get addProjWidthLabel => '敷地幅(m)';

  @override
  String get addProjLengthLabel => '敷地奥行(m)';

  @override
  String get addProjAreaLabel => '建築面積(㎡)';

  @override
  String get addProjCostLabel => '参考価格(円)';

  @override
  String get addProjCostHint => '不明の場合は空欄で結構です';

  @override
  String get addProjPdfSection => '設計資料(PDF)';

  @override
  String get addProjPdfHelper => '図面・資料は管理者が確認します。最大10ファイルまで。';

  @override
  String addProjPdfItem(Object number) {
    return '資料 $number';
  }

  @override
  String get addProjUploading => 'アップロード中…';

  @override
  String get addProjAddPdf => 'PDFファイルを追加';

  @override
  String get addProjSaveChanges => '変更を保存';

  @override
  String get addProjSubmit => '投稿';

  @override
  String get addProjSegWork => '完成プロジェクト';

  @override
  String get addProjSegDesign => 'デザインテンプレート';

  @override
  String get bkDetEyebrow => '予約';

  @override
  String get bkDetTitle => '予約詳細';

  @override
  String get bkDetCancelAppointment => '内見予約をキャンセル';

  @override
  String get bkDetCancelConfirm => 'この内見予約をキャンセルしてもよろしいですか?';

  @override
  String get bkDetClose => '閉じる';

  @override
  String get bkDetCancelBooking => '予約をキャンセル';

  @override
  String get bkDetCancelFailed => 'キャンセルに失敗しました — もう一度お試しください。';

  @override
  String bkDetPhoneCopied(Object phone) {
    return '番号 $phone をコピーしました — 電話アプリを開いて発信してください。';
  }

  @override
  String get bkDetHostNotFound => 'ホスト情報が見つかりません。';

  @override
  String get bkDetHost => 'ホスト';

  @override
  String get bkDetApartment => 'マンション';

  @override
  String get bkDetRoomImage => '部屋写真';

  @override
  String get bkDetScheduleTitle => '予約内容';

  @override
  String get bkDetViewDate => '内見日';

  @override
  String get bkDetTime => '時間';

  @override
  String get bkDetSentAt => '送信日時';

  @override
  String get bkDetYourMessage => 'あなたのメッセージ';

  @override
  String get bkDetNoMessage => 'メッセージはありません。';

  @override
  String get bkDetHostInfo => 'ホスト情報';

  @override
  String get bkDetMessage => 'メッセージ';

  @override
  String get bkDetProgress => '進捗';

  @override
  String get bkDetStepRequested => 'リクエスト送信';

  @override
  String get bkDetStepApproved => 'ホストが承認';

  @override
  String get bkDetStepCompleted => '内見完了';

  @override
  String get bkDetStepBooked => '予約済み';

  @override
  String get bkDetStepRejected => 'ホストが却下';

  @override
  String get bkDetStepCancelled => 'キャンセルしました';

  @override
  String get bkDetStepLost => '他の方が予約済み';

  @override
  String get bkDetStepEnded => '終了';

  @override
  String get bkDetCall => '電話';

  @override
  String get bkDetReviewed => 'レビュー済み';

  @override
  String get bkDetWriteReview => 'レビューを書く';

  @override
  String get bkDetExploreOther => '他の物件を見る';

  @override
  String get bkHistEyebrow => 'アカウント';

  @override
  String get bkHistTitle => '予約履歴';

  @override
  String get bkHistRefresh => '更新';

  @override
  String get bkHistTabPending => '承認待ち';

  @override
  String get bkHistTabApproved => '承認済み';

  @override
  String get bkHistCompleted => '完了';

  @override
  String get bkHistFilterAll => 'すべて';

  @override
  String get bkHistStatusLocked => '予約済み';

  @override
  String get bkHistStatusCancelled => 'キャンセル済み';

  @override
  String get bkHistStatusRejected => '却下';

  @override
  String get bkHistStatusLost => '他の方が成約済み';

  @override
  String get bkHistSearchHint => '名前・住所で検索...';

  @override
  String get bkHistClearSearch => '検索をクリア';

  @override
  String get bkHistRoomPhoto => '部屋写真';

  @override
  String get bkHistDefaultHouseTitle => 'プレミアムマンション';

  @override
  String get bkHistCallHost => 'ホストに電話';

  @override
  String get bkHistMessage => 'メッセージ';

  @override
  String get bkHistReviewed => 'レビュー済み';

  @override
  String get bkHistReview => 'レビュー';

  @override
  String get bkHistApartment => 'マンション';

  @override
  String get bkHistViewOtherHouses => '他の物件を見る';

  @override
  String get bkHistCancelTitle => '予約をキャンセル';

  @override
  String get bkHistCancelConfirm => 'この予約をキャンセルしてもよろしいですか?';

  @override
  String get bkHistClose => '閉じる';

  @override
  String get bkHistCancelAppointment => '内見予約をキャンセル';

  @override
  String get bkHistCancelSuccess => '予約をキャンセルしました';

  @override
  String get bkHistCancelFailed => 'キャンセルに失敗しました';

  @override
  String get bkHistNoHostPhone => 'ホストの電話番号が利用できません';

  @override
  String bkHistPhoneCopied(Object phone) {
    return '番号をコピーしました:$phone';
  }

  @override
  String get bkHistHostNotFound => 'ホストが見つかりません';

  @override
  String get bkHistHost => 'ホスト';

  @override
  String get bkHistNoRequests => 'リクエストはありません';

  @override
  String get bkHistNoResults => '該当する結果が見つかりません';

  @override
  String get bkHistSearchEmpty => '別のキーワードを試すか、検索条件をクリアしてください。';

  @override
  String get bkHistEmptyHint => '予約リクエストがここに表示されます。';

  @override
  String get bkSchedSuccessMessage => '予約リクエストを送信しました。';

  @override
  String get bkSchedSubmitFailed => 'リクエストの送信に失敗しました';

  @override
  String get bkSchedEyebrow => '予約';

  @override
  String get bkSchedAppBarTitle => '内見予約';

  @override
  String get bkSchedCardHeader => '内見予約を申し込む';

  @override
  String get bkSchedStep1 => '1. 内見日を選択';

  @override
  String bkSchedDateLabel(Object date) {
    return '日付:$date';
  }

  @override
  String get bkSchedStep2 => '2. 時間帯を選択(1時間単位)';

  @override
  String get bkSchedStep3 => '3. ホストへのメッセージ(任意)';

  @override
  String get bkSchedMessageHint => '例:駐車場についてもう少し聞きたい、友人を連れて行きたいなど...';

  @override
  String get bkSchedSelectSlotPrompt => '時間帯をお選びください';

  @override
  String get bkSchedSubmit => '予約リクエストを送信';

  @override
  String get bkSchedAfterSubmitTitle => 'リクエスト送信後について';

  @override
  String get bkSchedAfterSubmitDesc => 'ホストに通知が送られ、最長2営業時間以内にリクエストを確認します。';

  @override
  String get bkSchedCancelPolicyTitle => 'キャンセルポリシー';

  @override
  String get bkSchedCancelPolicyDesc => '内見予定時刻の4時間前まで無料で変更・キャンセルが可能です。';

  @override
  String get bkSchedRetry => '再試行';

  @override
  String get bkSchedNoSlots => 'この日は空き時間がありません。別の日をお選びください。';

  @override
  String get ccompTitle => '施工依頼を投稿';

  @override
  String get ccompSend => '送信';

  @override
  String get ccompPost => '投稿';

  @override
  String get ccompYou => 'あなた';

  @override
  String get ccompGuestName => 'ゲスト';

  @override
  String get ccompIntentShare => 'プロジェクトを共有';

  @override
  String get ccompIntentNeed => '施工の依頼';

  @override
  String get ccompContentHintNeed => '何を建てたいですか?ご要望や現状をお聞かせください…';

  @override
  String get ccompContentHintShare => '完成したばかりのプロジェクトをシェアしましょう…';

  @override
  String get ccompServiceBuild => '建築';

  @override
  String get ccompServiceDesign => 'デザイン';

  @override
  String get ccompServiceInterior => 'インテリア';

  @override
  String get ccompServiceIndustrial => '産業施設';

  @override
  String get ccompPhoneHint => '電話番号 *';

  @override
  String get ccompAreaHint => '面積(例:80㎡)';

  @override
  String get ccompBudgetHint => '予算の目安';

  @override
  String get ccompLocationOptional => '所在地(任意)';

  @override
  String get ccompSelectProvince => '都道府県を選択';

  @override
  String get ccompLoading => '読み込み中…';

  @override
  String get ccompSelectWard => '市区町村を選択';

  @override
  String get ccompMapHint => '地図をタップしてピンを立てます(住所は自動入力)。';

  @override
  String ccompPinnedWard(Object ward) {
    return 'ピン位置:$ward';
  }

  @override
  String ccompPinnedCoords(Object lat, Object lng) {
    return 'ピン位置:$lat, $lng';
  }

  @override
  String ccompPhotosCount(Object count, Object max) {
    return '写真($count/$max)';
  }

  @override
  String get ccompLocation => '所在地';

  @override
  String get ccompImagePickFailed => '画像を選択できませんでした';

  @override
  String get ccompSubmitFailed => '投稿に失敗しました。再度お試しください';

  @override
  String get cleadTitle => 'パートナーランキング';

  @override
  String get cleadSubtitle => '評判とレビューに基づく順位';

  @override
  String get cleadTradeDesign => 'デザイン';

  @override
  String get cleadTradeBuild => '建築';

  @override
  String get cleadTradeInterior => 'インテリア';

  @override
  String get cleadTradeIndustrial => '産業用不動産';

  @override
  String get cleadLoadError => 'パートナー一覧を読み込めませんでした';

  @override
  String get cleadEmptyTitle => 'この業種のパートナーはまだいません';

  @override
  String get cleadEmptySubtitle => '別の業種をお試しいただくか、しばらくしてからご確認ください。';

  @override
  String get cleadFallbackCompany => 'パートナー';

  @override
  String get cleadNoRating => 'レビューはまだありません';

  @override
  String cleadRatingCount(Object rating, Object count) {
    return '⭐ $rating($count件のレビュー)';
  }

  @override
  String cleadRatingNew(Object rating, Object count) {
    return '⭐ $rating · $count件のレビュー(新規)';
  }

  @override
  String get cleadBadgeFeatured => '注目';

  @override
  String get cleadBadgePro => 'Pro';

  @override
  String get cleadBadgeVerified => '認証済み';

  @override
  String get compareTitle => '物件を比較';

  @override
  String get compareEmpty => '比較する物件がありません';

  @override
  String get compareCriteria => '項目';

  @override
  String get compareHouseFallback => '物件';

  @override
  String get compareLabelPrice => '価格';

  @override
  String get compareLabelArea => '面積';

  @override
  String get compareLabelPricePerSqm => '㎡単価';

  @override
  String get compareLabelLegal => '権利関係';

  @override
  String get compareLabelBedrooms => '寝室数';

  @override
  String get compareLabelBathrooms => '浴室数';

  @override
  String get compareLabelLocation => '所在地';

  @override
  String get ctrContractor => '施工業者';

  @override
  String get ctrLoadFailed => '読み込みに失敗しました';

  @override
  String get ctrRequestQuote => '見積もりを依頼';

  @override
  String ctrContractorRatingSubtitle(Object rating, Object count) {
    return '施工業者 · ⭐ $rating($count件のレビュー)';
  }

  @override
  String get ctrTrustedUnit => '信頼できる業者';

  @override
  String get ctrVerified => '認証済み';

  @override
  String get ctrCertVerified => '専門資格';

  @override
  String get ctrProjectsStat => 'プロジェクト';

  @override
  String get ctrVerifiedLabel => '審査済み';

  @override
  String get ctrDesignFilesStat => '設計資料';

  @override
  String get ctrReviewsStat => 'レビュー';

  @override
  String ctrYearsExperience(Object yrs) {
    return '経験 $yrs年';
  }

  @override
  String ctrEstablished(Object year) {
    return '設立 $year年';
  }

  @override
  String ctrTeamSize(Object team) {
    return 'チーム $team名';
  }

  @override
  String get ctrWebsite => 'ウェブサイト';

  @override
  String get ctrPortfolioTitle => '施工実績';

  @override
  String get ctrNoProjects => 'プロジェクトはまだありません';

  @override
  String get ctrNoProjectsSubtitle => 'この業者はまだプロジェクトを投稿していません。直接相談を依頼してください。';

  @override
  String get ctrFilterAll => 'すべて';

  @override
  String get ctrFilterHasFiles => '設計資料あり';

  @override
  String get ctrNoMatchFilter => '条件に一致するプロジェクトはありません。';

  @override
  String get ctrProject => 'プロジェクト';

  @override
  String ctrFilesCount(Object count) {
    return '$countファイル';
  }

  @override
  String ctrReviewsTitle(Object count) {
    return 'レビュー($count)';
  }

  @override
  String get ctrNoReviews => 'レビューはまだありません';

  @override
  String get ctrNoReviewsSubtitle => 'この物件に最初のレビューを投稿しましょう。';

  @override
  String get ctrCriteriaQuality => '品質';

  @override
  String get ctrCriteriaTimeliness => '納期';

  @override
  String get ctrCriteriaCommunication => 'コミュニケーション';

  @override
  String get ctrCriteriaBudget => '予算';

  @override
  String get ctrCriteriaProfessionalism => '専門性';

  @override
  String get ctrCriteriaBreakdownTitle => '項目別評価';

  @override
  String ctrReviewCount(Object count) {
    return 'レビュー$count件';
  }

  @override
  String get ctrNotEnoughReviews => '詳細な評価を表示するにはレビュー数が不足しています。';

  @override
  String get ctrUser => 'ユーザー';

  @override
  String get cwLoginToJoinCommunity => '施工コミュニティに参加するにはログインしてください。';

  @override
  String get cwConstructionReels => '施工リール';

  @override
  String get cwPostDeleted => '投稿を削除しました';

  @override
  String get cwPostRemovedModeration => '投稿は削除されました(モデレーション)';

  @override
  String cwErrorWithMsg(Object msg) {
    return 'エラー:$msg';
  }

  @override
  String get cwProject => 'プロジェクト';

  @override
  String cwLocationPin(Object location) {
    return '📍 $location';
  }

  @override
  String get cwViewContractor => '施工業者を見る';

  @override
  String get cwShare => '共有';

  @override
  String get cwCopyLinkFromBrowser => 'ブラウザからリンクをコピーしてください';

  @override
  String get cwNeedConstruction => '施工を依頼';

  @override
  String get cwQuote => '見積もり';

  @override
  String get cwNeedContractorProfile =>
      '見積もりを送るには施工業者プロフィールが必要です(個人→施工業者チャネル)。';

  @override
  String get cwQuoteSent => '見積もりをお客様に送信しました';

  @override
  String get cwContractor => '施工業者';

  @override
  String get cwCatAll => 'すべて';

  @override
  String get cwCatDesign => 'デザイン';

  @override
  String get cwCatBuild => '施工';

  @override
  String get cwCatInterior => 'インテリア';

  @override
  String get cwCatIndustrial => '産業';

  @override
  String get cwFeaturedContractors => 'おすすめ施工業者';

  @override
  String get cwViewAllDesignsGrid => 'すべてのデザインをグリッド表示';

  @override
  String cwNoContentInCategory(Object category) {
    return '$categoryにはまだコンテンツがありません';
  }

  @override
  String get cwBeFirstToShare => '最初にプロジェクトや依頼を投稿してみましょう。';

  @override
  String get cwSendQuote => '見積もりを送る';

  @override
  String get cwAmountVnd => '金額(JPY)*';

  @override
  String get cwAmountHint => '例:1500000000';

  @override
  String get cwNoteOptional => 'メモ(任意)';

  @override
  String get cwSend => '送信';

  @override
  String get designAppBarEyebrow => '施工';

  @override
  String get designLibraryTitle => 'デザインライブラリ';

  @override
  String get designPostDesign => 'デザインを投稿';

  @override
  String get designAll => 'すべて';

  @override
  String get designHouseType => '住宅タイプ';

  @override
  String get designStyle => 'スタイル';

  @override
  String get designFloors => '階数';

  @override
  String designFloorsValue(Object floors) {
    return '$floors階';
  }

  @override
  String get designBedroomsLabel => '寝室数';

  @override
  String get designBedroomsTitle => '寝室数';

  @override
  String designBedroomsShort(Object bedrooms) {
    return '${bedrooms}LDK';
  }

  @override
  String designBedroomsValue(Object bedrooms) {
    return '寝室$bedrooms室';
  }

  @override
  String designAreaValue(Object area) {
    return '$area㎡';
  }

  @override
  String get designVerified => '認証済み';

  @override
  String get designClearFilters => 'フィルタをクリア';

  @override
  String get designLoadError => 'ライブラリを読み込めませんでした';

  @override
  String get designLoadErrorSubtitle => '接続を確認して再度お試しください。';

  @override
  String get designRetry => '再試行';

  @override
  String get designEmptyFilteredTitle => '該当するデザインがありません';

  @override
  String get designEmptyTitle => 'デザインがまだありません';

  @override
  String get designEmptyFilteredSubtitle => 'フィルタを一部解除するとさらに表示されます。';

  @override
  String get designEmptySubtitle => 'デザイン会社がここに住宅デザインを投稿します。後ほどご確認ください。';

  @override
  String get designPostYourDesign => 'あなたのデザインを投稿';

  @override
  String get designEndOfList => '— 以上 —';

  @override
  String get designDefaultTitle => 'デザイン';

  @override
  String get designUnitFallback => '業者';

  @override
  String get designDesignUnitFallback => 'デザイン会社';

  @override
  String editProfUploadError(Object error) {
    return 'アップロードエラー:$error';
  }

  @override
  String get editProfCoverChanged => 'カバー写真を変更しました';

  @override
  String get editProfCoverChangeFailed => 'カバー写真の変更に失敗しました';

  @override
  String get editProfPickBirthday => '生年月日を選択';

  @override
  String get editProfWaitUpload => '画像のアップロードが完了するまでお待ちください';

  @override
  String get editProfSaved => 'プロフィールを更新しました';

  @override
  String get editProfUpdateFailed => '更新に失敗しました';

  @override
  String get editProfEmailInUse => 'このメールアドレスは既に使用されています';

  @override
  String get editProfEyebrow => 'アカウント';

  @override
  String get editProfChangeCover => 'カバー写真を変更(オーナー)';

  @override
  String get editProfSectionPersonal => '個人情報';

  @override
  String get editProfFullName => '氏名';

  @override
  String get editProfRequired => '必須';

  @override
  String get editProfEmailHelper => 'ログインに使用するメールアドレス';

  @override
  String get editProfEmailInvalid => 'メールアドレスが無効です';

  @override
  String get editProfPhone => '電話番号';

  @override
  String get editProfSectionIntro => '自己紹介';

  @override
  String get editProfBioLabel => '自己紹介';

  @override
  String get editProfBioHint => '例:1区でアパートを5年貸しているオーナーです…';

  @override
  String get editProfSectionVerify => '本人確認(任意)';

  @override
  String get editProfIdNumber => '身分証番号';

  @override
  String get editProfIdHelper => '認証を希望しない場合は空欄で構いません';

  @override
  String get editProfSave => '変更を保存';

  @override
  String get editProfNotSelected => '未選択';

  @override
  String get editProfBirthday => '生年月日';

  @override
  String editProfAge(Object age) {
    return '年齢:$age';
  }

  @override
  String get hdBack => '戻る';

  @override
  String get hdShare => '共有';

  @override
  String get hdLinkCopied => 'リンクをコピーしました';

  @override
  String hdImageLabel(Object title, Object n) {
    return '$title — 写真 $n';
  }

  @override
  String get hdPerMonth => '/月';

  @override
  String get hdLoanCalc => '住宅ローンを計算';

  @override
  String hdBedroomsShort(Object n) {
    return '寝室$n';
  }

  @override
  String hdBathroomsShort(Object n) {
    return '浴室$n';
  }

  @override
  String hdAreaSqm(Object area) {
    return '$area m²';
  }

  @override
  String get hdDescriptionTitle => '詳細説明';

  @override
  String get hdHostInfoTitle => 'ホスト情報';

  @override
  String get hdLoginToSave => 'お気に入りに保存するにはログインしてください。';

  @override
  String get hdFavUpdateFailed => 'お気に入りを更新できませんでした';

  @override
  String get hdApptApprovedTitle => '内見が承認されました';

  @override
  String hdApptApprovedSub(Object sched) {
    return '$sched · 時間厳守でお越しください';
  }

  @override
  String get hdApptRejectedTitle => '内見が拒否されました';

  @override
  String get hdApptRejectedSub => '別の時間帯を選択できます';

  @override
  String get hdApptCancelledTitle => '内見をキャンセルしました';

  @override
  String get hdApptCancelledSub => '引き続きご覧になりたい場合は再度ご予約ください';

  @override
  String get hdApptCompletedTitle => 'この物件を内見済みです';

  @override
  String get hdApptLockedTitle => '部屋はロックされました';

  @override
  String get hdApptPendingTitle => '内見を予約しました';

  @override
  String hdApptPendingSub(Object sched) {
    return '$sched · ホストの承認待ち';
  }

  @override
  String get hdLegalRedBook => 'レッドブック';

  @override
  String get hdLegalPinkBook => 'ピンクブック';

  @override
  String get hdLegalSaleContract => '売買契約';

  @override
  String get hdLegalPending => '権利証待ち';

  @override
  String hdPricePerMonth(Object s) {
    return '$s百万円/月';
  }

  @override
  String get hdSpecPrice => '価格';

  @override
  String get hdSpecArea => '面積';

  @override
  String get hdSpecBedrooms => '寝室';

  @override
  String get hdSpecBathrooms => '浴室';

  @override
  String get hdSpecType => '種別';

  @override
  String get hdSpecLegal => '法的状況';

  @override
  String get hdSpecFurniture => '家具';

  @override
  String hdRoomsCount(Object n) {
    return '$n部屋';
  }

  @override
  String get hdPropertySpecsTitle => '物件詳細';

  @override
  String get hdYourListing => 'あなたの物件';

  @override
  String get hdViewBooking => '予約を表示';

  @override
  String get hdRebookViewing => '内見を再予約';

  @override
  String get hdBookViewing => '内見を予約';

  @override
  String get hdLoginToBook => '内見を予約するにはログインしてください。';

  @override
  String hdAreaHa(Object area) {
    return '$area ha';
  }

  @override
  String get hdIndPower => '電力容量';

  @override
  String hdPowerMva(Object power) {
    return '$power MVA';
  }

  @override
  String get hdIndFireSafety => '消防安全';

  @override
  String get hdHas => 'あり';

  @override
  String get hdHasNot => 'なし';

  @override
  String get hdIndLegal => '工業団地の法的状況';

  @override
  String get hdIndustrialSpecsTitle => '工業仕様';

  @override
  String get hdForSale => '売却';

  @override
  String get hdFull => '満室';

  @override
  String hdUnitsAvailable(Object available, Object total) {
    return '空室 $available/$total 部屋';
  }

  @override
  String get hdAvailable => '空室';

  @override
  String get hdHost => 'ホスト';

  @override
  String get hdHostVerifiedTooltip => 'ホストの本人確認済み';

  @override
  String get hdHostTrustedTooltip => '信頼ホスト：高評価・迅速な対応';

  @override
  String hdResponseTime(Object h) {
    return '約$h時間以内に返信';
  }

  @override
  String get hdHidden => '· 非公開';

  @override
  String get hdMessageHost => 'ホストにメッセージ';

  @override
  String get hdReviewsTitle => 'レビュー';

  @override
  String get hdNoReviews => 'レビューはまだありません。';

  @override
  String hdViewAllReviews(Object count) {
    return '$count件のレビューをすべて表示';
  }

  @override
  String get hdUser => 'ユーザー';

  @override
  String get hubProviderChannel => '提供者チャネル';

  @override
  String get hubEnterNameSelectService => '事業者名を入力し、サービスを1つ以上選択してください';

  @override
  String get hubProfileSubmitted => 'プロフィールを送信しました。承認後にディレクトリに掲載されます。';

  @override
  String hubErrorWithMsg(Object error) {
    return 'エラー: $error';
  }

  @override
  String get hubBecomeProvider => 'プロバイダー登録';

  @override
  String get hubRegisterService => 'サービス提供者として登録';

  @override
  String get hubRegisterIntro =>
      'お客様からのご依頼を受け、事業者(設計/施工/内装)をアピールするために登録してください。';

  @override
  String get hubUnitName => '事業者名 *';

  @override
  String get hubUnitNameHint => '例: キエンアン建設';

  @override
  String get hubField => '分野 *';

  @override
  String get hubOperatingArea => '対応エリア';

  @override
  String get hubSelectProvince => '都道府県/市を選択';

  @override
  String get hubIntro => '紹介';

  @override
  String get hubIntroHint => '経験、強み、規模など...';

  @override
  String get hubContactPhone => '連絡先電話番号';

  @override
  String get hubSubmitRegistration => '登録を送信';

  @override
  String get hubOwnerContact => 'オーナー連絡先';

  @override
  String hubNameLabel(Object name) {
    return '名前: $name';
  }

  @override
  String hubPhoneLabel(Object phone) {
    return '電話: $phone';
  }

  @override
  String get hubClose => '閉じる';

  @override
  String get hubOwnerNotShared => 'オーナーはまだ連絡先を共有していません。お待ちください。';

  @override
  String hubCantViewContact(Object msg) {
    return '連絡先を表示できません：$msg';
  }

  @override
  String get hubEditProfile => '事業者プロフィール編集';

  @override
  String get hubAddCover => 'カバー画像を追加';

  @override
  String get hubChangeLogo => 'ユニットロゴを変更';

  @override
  String get hubPhone => '電話番号';

  @override
  String get hubWebsite => 'ウェブサイト(ある場合)';

  @override
  String get hubYearEstablished => '設立年';

  @override
  String get hubTeamSize => 'チーム規模';

  @override
  String hubPeopleSuffix(Object size) {
    return '$size名';
  }

  @override
  String get hubCertNumber => '専門ライセンス番号（ある場合）';

  @override
  String get hubCertHelper => '管理者が確認してバッジを付与します';

  @override
  String get hubCancel => 'キャンセル';

  @override
  String get hubSave => '保存';

  @override
  String get hubNameRequired => '事業者名を入力してください';

  @override
  String get hubProfileUpdated => 'プロフィールを更新しました';

  @override
  String get hubDeleteProjectTitle => 'プロジェクトを削除しますか?';

  @override
  String hubDeleteProjectConfirm(Object title) {
    return '「$title」をプロフィールから削除しますか?この操作は取り消せません。';
  }

  @override
  String get hubThisProject => 'このプロジェクト';

  @override
  String get hubDelete => '削除';

  @override
  String get hubDeleted => '削除しました';

  @override
  String hubImageUploadFailed(Object error) {
    return '画像をアップロードできませんでした: $error';
  }

  @override
  String get hubQuoteSent => 'お客様に見積もりを送信しました';

  @override
  String get hubUnit => '事業者';

  @override
  String get hubActive => '有効';

  @override
  String get hubPendingApproval => '承認待ち';

  @override
  String get hubCertificate => '資格証';

  @override
  String get hubPendingNote =>
      'プロフィールは管理者の承認待ちです。リクエストの閲覧や見積もり送信は可能です。承認後にディレクトリに掲載されます。';

  @override
  String get hubEditProfileShort => 'プロフィール編集';

  @override
  String get hubPostProject => 'プロジェクトを掲載';

  @override
  String get hubMatchingNeeds => 'マッチングニーズ';

  @override
  String get hubNoMatchingNeeds => '該当するニーズはまだありません。後ほどご確認ください。';

  @override
  String get hubMyQuotes => '見積もり履歴';

  @override
  String get hubProjectsDesigns => 'プロジェクト・設計事例';

  @override
  String get hubNoProjects => 'プロジェクトはまだありません';

  @override
  String get hubNoProjectsSub => '完了したプロジェクトや設計事例を掲載して、お客様に実績をアピールしましょう。';

  @override
  String get hubPostFirstProject => '最初のプロジェクトを掲載';

  @override
  String get hubService => 'サービス';

  @override
  String get hubContactsYou => 'あなたへの連絡';

  @override
  String get hubSendQuote => '見積もりを送信';

  @override
  String get hubWon => '成約';

  @override
  String get hubNotSelected => '未選択';

  @override
  String get hubWaiting => '待機中';

  @override
  String get hubRequest => '依頼';

  @override
  String hubQuoteAmount(Object amount) {
    return '見積もり: $amount';
  }

  @override
  String hubMilestoneLine(Object label, Object percent, Object amount) {
    return '• $label($percent%): $amount';
  }

  @override
  String get hubViewContact => '連絡先を表示';

  @override
  String get hubWaitOwnerShare => 'オーナーが連絡先を共有するのをお待ちください';

  @override
  String get hubBillion => '十億';

  @override
  String get hubMillion => '百万';

  @override
  String get hubDong => 'JPY';

  @override
  String get hubProject => 'プロジェクト';

  @override
  String get hubVerified => '認証済み';

  @override
  String get hubSelfPosted => '自主掲載';

  @override
  String hubDesignFiles(Object count) {
    return '設計ファイル$count件';
  }

  @override
  String get hubEdit => '編集';

  @override
  String get hubAmount => '金額（円） *';

  @override
  String get hubAmountHint => '例：1500000000';

  @override
  String get hubNoteOptional => '備考(任意)';

  @override
  String get hubSplitStages => '工程で分割(30/20/20/30)';

  @override
  String get hubStagesSubtitle => '手付金・設計・技術・引き渡し';

  @override
  String get hubSend => '送信';

  @override
  String get myReqTitle => 'サービス依頼履歴';

  @override
  String get myReqEmpty => 'サービスの予約はまだありません';

  @override
  String get myReqContactSharedToast => '電話番号を業者に共有しました';

  @override
  String myReqShareError(Object error) {
    return '共有できませんでした: $error';
  }

  @override
  String get myReqQuoteAccepted => '見積もりを承諾しました';

  @override
  String myReqAcceptError(Object error) {
    return '承諾できません: $error';
  }

  @override
  String get myReqReviewThanks => 'レビューありがとうございます!';

  @override
  String myReqReviewError(Object error) {
    return 'エラー: $error';
  }

  @override
  String get myReqServiceDesign => '設計';

  @override
  String get myReqServiceBuild => '施工';

  @override
  String get myReqServiceInterior => '内装';

  @override
  String get myReqServiceDefault => 'サービス';

  @override
  String get myReqStatusNew => '送信済み';

  @override
  String get myReqStatusAssigned => '業者とマッチング';

  @override
  String get myReqStatusQuoted => '見積もり受領';

  @override
  String get myReqStatusWon => '成約';

  @override
  String get myReqStatusClosed => '終了';

  @override
  String get myReqNoQuotes => '見積もりはまだありません。業者からまもなく返信があります。';

  @override
  String get myReqContractorDefault => '業者';

  @override
  String myReqQuoteAmount(Object amount) {
    return '見積もり: $amount';
  }

  @override
  String get myReqSelectedContractor => 'この業者を選択しました';

  @override
  String get myReqReview => 'レビュー';

  @override
  String get myReqContactSharedLabel => '連絡先を業者に共有済み';

  @override
  String get myReqShareContactBtn => '電話番号を業者に共有';

  @override
  String get myReqAccept => '承諾';

  @override
  String get myReqReviewTitle => '業者をレビュー';

  @override
  String get myReqCritQuality => '品質';

  @override
  String get myReqCritTimeliness => '時間厳守';

  @override
  String get myReqCritCommunication => 'コミュニケーション';

  @override
  String get myReqCritBudget => '予算';

  @override
  String get myReqCritProfessionalism => 'プロ意識';

  @override
  String get myReqDetailedRating => '詳細評価(任意)';

  @override
  String get myReqCommentHint => 'コメント(任意)';

  @override
  String get myReqSend => '送信';

  @override
  String get pgalFileOpenError => 'ファイルを開けませんでした';

  @override
  String get pgalVerifySuccess => 'プロジェクトを認証しました';

  @override
  String pgalErrorWith(Object error) {
    return 'エラー: $error';
  }

  @override
  String get pgalProjectFallback => 'プロジェクト';

  @override
  String get pgalVerified => '認証済み';

  @override
  String pgalDesignFilesCount(Object count) {
    return '設計ファイル($count)';
  }

  @override
  String get pgalDesignUnit => '設計会社';

  @override
  String get pgalConfirmReal => 'プロジェクトが実在することを確認';

  @override
  String get pgalViewFirmProfile => '会社プロフィールを見る';

  @override
  String get pgalRequestConsult => '相談を依頼';

  @override
  String get pgalSpecCode => '設計コード';

  @override
  String get pgalSpecHouseType => '住宅タイプ';

  @override
  String get pgalSpecStyle => 'スタイル';

  @override
  String get pgalSpecFloors => '階数';

  @override
  String pgalFloorsValue(Object count) {
    return '$count階';
  }

  @override
  String get pgalSpecBedrooms => '寝室';

  @override
  String pgalRoomsValue(Object count) {
    return '$count部屋';
  }

  @override
  String get pgalSpecLandArea => '土地面積';

  @override
  String pgalLandAreaValue(Object width, Object length, Object total) {
    return '$width×${length}m(${total}m²)';
  }

  @override
  String get pgalSpecBuildArea => '建築面積';

  @override
  String pgalSqmValue(Object area) {
    return '${area}m²';
  }

  @override
  String get pgalSpecYear => '設計年';

  @override
  String get pgalSpecRegion => '地域';

  @override
  String get pgalSpecEstCost => '参考価格';

  @override
  String get pgalSpecTitle => '仕様';

  @override
  String pgalCostBillion(Object value) {
    return '$value十億';
  }

  @override
  String pgalCostMillion(Object value) {
    return '$value百万';
  }

  @override
  String pgalCostDong(Object value) {
    return '$value円';
  }

  @override
  String get pgalDescTitle => '設計説明';

  @override
  String get pgalCollapse => '折りたたむ';

  @override
  String get pgalExpand => 'もっと見る';

  @override
  String get pgalRelatedTitle => '類似デザイン';

  @override
  String get pgalDesignTemplate => '設計テンプレート';

  @override
  String pgalBedroomsAbbr(Object count) {
    return '$count寝室';
  }

  @override
  String pgalSqmValueCompact(Object area) {
    return '${area}m²';
  }

  @override
  String get pgalDesignFirmName => '設計会社';

  @override
  String pgalRatingLine(Object rating, Object count) {
    return '⭐ $rating · レビュー$count件';
  }

  @override
  String get pgalViewAllFirm => 'この会社の全デザインを見る →';

  @override
  String pgalDrawingIndex(Object index) {
    return '図面・設計 $index';
  }

  @override
  String get postCardEdited => '編集済み';

  @override
  String get postCmtErrorLoad => 'コメントの読み込みに失敗しました';

  @override
  String get postCmtLoginRequired => 'コメントするにはログインしてください。';

  @override
  String get postCmtSendFailed => 'コメントの送信に失敗しました';

  @override
  String get postCmtDeleteFailed => 'コメントの削除に失敗しました';

  @override
  String get postCmtTitle => 'コメント';

  @override
  String get postCmtEmpty => 'コメントはまだありません。最初に投稿しましょう!';

  @override
  String get postCmtEdited => '編集済み';

  @override
  String postCmtMoreImages(Object count) {
    return '+$count枚';
  }

  @override
  String get postCmtDeleted => 'コメントを削除しました';

  @override
  String get postCmtReply => '返信';

  @override
  String get postCmtDelete => '削除';

  @override
  String postCmtReplyingTo(Object name) {
    return '$nameさんへ返信中';
  }

  @override
  String get postCmtHint => 'コメントを書く...';

  @override
  String postCmtReplyHint(Object name) {
    return '$nameさんへ返信...';
  }

  @override
  String postHouseImagePickError(Object error) {
    return '画像選択エラー: $error';
  }

  @override
  String get postHouseSelectRoomType => '部屋タイプを選択してください';

  @override
  String get postHouseWaitUpload => '画像のアップロードが完了するまでお待ちください';

  @override
  String get postHouseNeedOneImage => '画像を1枚以上追加してください';

  @override
  String get postHousePostSuccess => '物件を掲載しました!';

  @override
  String get postHousePendingReviewTitle => '送信完了 — 確認待ち';

  @override
  String get postHousePendingReviewBody =>
      '高額売買物件は公開前に管理者の確認が必要です(通常24時間以内)。進捗はプロフィール → 掲載物件で確認できます。';

  @override
  String get commonUnderstood => '了解しました';

  @override
  String get postHousePostFailed => '物件の掲載に失敗しました';

  @override
  String get postHouseUpdateSuccess => '掲載情報を更新しました';

  @override
  String get postHouseUpdateFailed => '更新に失敗しました';

  @override
  String get postHouseEditTitle => '物件を編集';

  @override
  String get postHouseNewTitle => '新規物件を掲載';

  @override
  String postHousePhotosLabel(Object label, Object current, Object max) {
    return '$label($current/$max)';
  }

  @override
  String get postHousePropertyPhotos => '物件写真';

  @override
  String get postHouseRoomPhotos => '部屋の写真';

  @override
  String get postHouseListingCategory => '物件種別';

  @override
  String get postHouseTitleLabel => 'タイトル';

  @override
  String get postHouseTitleHint => '例：隅田川ビュー・2LDKマンション';

  @override
  String get postHouseRequired => '必須';

  @override
  String get postHouseDescLabel => '説明';

  @override
  String get postHouseDescHint => '部屋の詳細説明...';

  @override
  String get postHouseDraftFoundTitle => '未完了の物件を続けますか?';

  @override
  String get postHouseDraftFoundBody =>
      '前回未完了の物件があります。復元して続けるか、破棄して最初から始めてください。(写真は再選択が必要です。)';

  @override
  String get postHouseDraftRestore => '復元';

  @override
  String get postHouseDraftDiscard => '破棄';

  @override
  String get postHouseDescLabelOptional => '説明(任意)';

  @override
  String get postHouseDescTemplateBtn => '説明テンプレートを挿入';

  @override
  String get postHouseDescTemplate =>
      '• 立地: 市場・学校・バス停近く...\n• 設備: エアコン、給湯器、駐車場...\n• その他費用: 電気、水道、インターネット...\n• 内見のご連絡先: ';

  @override
  String get postHousePropertyType => '物件種別';

  @override
  String get postHouseRoomType => '部屋タイプ';

  @override
  String get postHouseSelectType => '種別を選択';

  @override
  String get postHouseSalePrice => '販売価格（円）';

  @override
  String get postHouseRentPrice => '家賃 / 月（円）';

  @override
  String get postHousePerMonth => '/月';

  @override
  String get postHouseSalePriceHint => '例：25,000,000';

  @override
  String get postHouseRentPriceHint => '例：80,000';

  @override
  String get postHouseArea => '面積(m²)';

  @override
  String get postHouseAreaHint => '例: 65';

  @override
  String get postHouseAddress => '住所';

  @override
  String get postHouseAddressHint => '番地、通り名...';

  @override
  String get postHouseAddressNeedsDetail =>
      '地図は町丁目までしか特定できませんでした。番地と通り名を追加してください。';

  @override
  String get postHouseProvince => '都道府県';

  @override
  String get postHouseSelectProvince => '都道府県を選択してください';

  @override
  String get postHouseWard => '市区町村';

  @override
  String get postHouseLoading => '読み込み中...';

  @override
  String get postHouseSelectWard => '市区町村を選択';

  @override
  String get postHouseMapLocation => '地図上の位置';

  @override
  String get postHouseMapHint => '地図をタップして正確な位置にピンを置く(住所は自動入力されます)。';

  @override
  String postHousePinnedAt(Object lat, Object lng) {
    return 'ピン位置: $lat, $lng';
  }

  @override
  String get postHouseBedrooms => '寝室数';

  @override
  String get postHouseBathrooms => '浴室数';

  @override
  String get postHouseLegal => '権利関係';

  @override
  String get postHouseSaveChanges => '変更を保存';

  @override
  String get postHouseSell => '売却として掲載';

  @override
  String get postHouseRent => '賃貸として掲載';

  @override
  String get postHouseAddPhoto => '写真を追加';

  @override
  String get postHouseCoverPhoto => 'カバー写真';

  @override
  String get postHouseRetry => '再試行';

  @override
  String get postHouseListingForm => '掲載形式';

  @override
  String get postHouseSemanticRent => '掲載種別：賃貸';

  @override
  String get postHouseSemanticSale => '掲載種別：売却';

  @override
  String get postHouseSingleTitle => '1戸 / 1部屋';

  @override
  String get postHouseSingleSubtitle => '一戸建て・分譲マンション';

  @override
  String get postHouseMultiTitle => '複数部屋';

  @override
  String get postHouseMultiSubtitle => '下宿、ミニアパート、ホステル...';

  @override
  String get postHouseLegalRedBook => '土地使用権証明書';

  @override
  String get postHouseLegalPinkBook => '所有権証明書';

  @override
  String get postHouseLegalSaleContract => '売買契約書';

  @override
  String get postHouseLegalPending => '権利証明書申請中';

  @override
  String get postHouseTotalUnits => '総部屋数';

  @override
  String get postHouseTotalUnitsHint => '例：10';

  @override
  String get postHouseAvailableUnits => '空室数';

  @override
  String get postHouseAvailableUnitsHint => '例: 7';

  @override
  String get postHousePriorityTenant => '希望する入居者';

  @override
  String get postHouseGenderAny => '指定なし';

  @override
  String get postHouseGenderMale => '男性';

  @override
  String get postHouseGenderFemale => '女性';

  @override
  String get profPersonal => 'プロフィール';

  @override
  String get profLoginPrompt => 'ログインしてプロフィール、掲載物件、予約、設定を管理してください。';

  @override
  String get profAccount => 'アカウント';

  @override
  String get profSettings => '設定';

  @override
  String get profYourPosts => 'あなたの投稿';

  @override
  String get profSavedListings => '保存した物件';

  @override
  String profAgeYears(Object count) {
    return '$count歳';
  }

  @override
  String get profListings => '掲載物件';

  @override
  String get profAppointmentsStat => '内見予約';

  @override
  String get profFavorites => 'お気に入り';

  @override
  String get profMine => 'マイページ';

  @override
  String get profPostedListings => '掲載済み物件';

  @override
  String get profPostedListingsSubtitle => '貸し出している部屋を管理';

  @override
  String get profViewingAppointments => '内見予約';

  @override
  String get profViewingAppointmentsSubtitle => 'あなたの内見予約一覧';

  @override
  String get profConstructionServices => '建築サービス';

  @override
  String get profMyServiceRequests => 'マイ サービスリクエスト';

  @override
  String get profMyServiceRequestsSubtitle => '見積を追跡し、業者を選択';

  @override
  String get profProviderChannel => 'プロバイダーチャンネル';

  @override
  String get profProviderChannelSubtitle => '会社プロフィール、マッチング案件、見積一覧';

  @override
  String get profBecomeProvider => '建築・設計会社の方ですか？';

  @override
  String get profBecomeProviderSubtitle => '見積依頼を受け取るためにプロフィールを登録';

  @override
  String get profRoleAdmin => '管理者';

  @override
  String get profRoleMember => 'メンバー';

  @override
  String get profModeGuest => '入居希望者';

  @override
  String get profModeHost => 'ホスト';

  @override
  String get profBecomeHost => 'ホストになる';

  @override
  String get profBecomeHostSubtitle => '部屋を掲載して入居者を迎え、収益化 — わずか2分で完了。';

  @override
  String get reelCmtLoadFailed => 'コメントを読み込めませんでした。';

  @override
  String get reelCmtLoginToComment => 'コメントするにはログインしてください。';

  @override
  String get reelCmtRateLimited => 'コメントが早すぎます。数分後に再度お試しください。';

  @override
  String get reelCmtSendFailed => 'コメントの送信に失敗しました。';

  @override
  String get reelCmtDeleteTitle => 'コメントを削除しますか？';

  @override
  String get reelCmtDelete => '削除';

  @override
  String get reelCmtDeleteFailed => 'コメントの削除に失敗しました。';

  @override
  String reelCmtCountLabel(Object count) {
    return 'コメント$count件';
  }

  @override
  String reelCmtReplyingTo(Object name) {
    return '$nameさんへの返信';
  }

  @override
  String get reelCmtInputHint => 'コメントを入力…';

  @override
  String get reelCmtEmpty => 'まだコメントがありません。\n最初のコメントを投稿しましょう！';

  @override
  String get reelCmtDefaultUser => 'ユーザー';

  @override
  String get reelCmtDeletedComment => 'コメントを削除しました';

  @override
  String get reelCmtReply => '返信';

  @override
  String get reelCompTitle => 'リール作成';

  @override
  String get reelCompPost => '投稿';

  @override
  String get reelCompUploading => '動画をアップロード中…';

  @override
  String reelCompUploaded(Object name) {
    return 'アップロード完了：$name';
  }

  @override
  String get reelCompPickVideo => 'ギャラリーから動画を選択';

  @override
  String get reelCompLimits => '最大90秒 · 120MB · 任意の形式';

  @override
  String get reelCompCaption => 'キャプション';

  @override
  String get reelCompCaptionHint => '動画の簡単な説明…';

  @override
  String get reelCompShowIn => '表示するセクション';

  @override
  String get reelCompCatAll => 'すべてのセクション';

  @override
  String get reelCompCatLease => '賃貸';

  @override
  String get reelCompCatIndustrial => '産業用';

  @override
  String get reelCompCatDesign => 'デザイン';

  @override
  String get reelCompCatBuild => '建築';

  @override
  String get reelCompCatInterior => 'インテリア';

  @override
  String get reelCompErrVideoTooLarge =>
      '動画サイズが大きすぎます（上限120MB）。より短い動画を撮影してください。';

  @override
  String get reelCompErrUploadFailed =>
      '動画のアップロードに失敗しました。接続状況をご確認の上、再度お試しください。';

  @override
  String get reelCompErrNoVideo => 'まず動画を選択してください。';

  @override
  String get reelCompSentTitle => '送信済み、審査待ち';

  @override
  String get reelCompSentBody =>
      '動画を処理中です（正規化＋カバー画像生成）。その後、管理者が公開前に確認します。「マイリール」からステータスを追跡できます。';

  @override
  String get reelCompGotIt => '了解';

  @override
  String get reelCompErrRateLimit => '本日のリール投稿上限（5件）に達しました。しばらくしてからお試しください。';

  @override
  String get reelCompErrSubmitFailed => 'リールの投稿に失敗しました。もう一度お試しください。';

  @override
  String get reelViewDataSaverOn => 'データセーバーがオン — 動画は自動再生されません。';

  @override
  String get reelViewDataSaverOff => 'データセーバーがオフです。';

  @override
  String get reelViewLoginToLike => 'このリールにいいねするにはログインしてください。';

  @override
  String get reelViewLoginToReport => 'このリールを報告するにはログインしてください。';

  @override
  String get reelViewReasonSpam => 'スパム／広告';

  @override
  String get reelViewReasonInappropriate => '不適切なコンテンツ';

  @override
  String get reelViewReasonCopyright => '著作権侵害';

  @override
  String get reelViewReasonMisleading => '誤解を招く／詐欺';

  @override
  String get reelViewReasonOther => 'その他の理由';

  @override
  String get reelViewReportTitle => 'リールを報告';

  @override
  String get reelViewReportSuccess =>
      '報告を送信しました。コミュニティの安全維持にご協力いただきありがとうございます。';

  @override
  String get reelViewReportFailed => '報告の送信に失敗しました。';

  @override
  String get reelViewLinkCopied => 'リールのリンクをコピーしました。';

  @override
  String get reelViewDataSaverTooltipOn => 'データセーバー：オン';

  @override
  String get reelViewDataSaverTooltipOff => 'データセーバー：オフ';

  @override
  String get reelViewVideoError => 'この動画を再生できません';

  @override
  String reelViewViewCount(Object count) {
    return '再生数 $count回';
  }

  @override
  String get reelViewShare => 'シェア';

  @override
  String get reelViewUnmute => 'ミュート解除';

  @override
  String get reelViewMute => 'ミュート';

  @override
  String get reelViewReport => '報告';

  @override
  String get roleWelcomeTitle => 'Ancu365へようこそ';

  @override
  String get roleLater => '後で';

  @override
  String get roleQuestion => 'ご利用の目的は？';

  @override
  String get roleSubtitle => '最適なページへご案内するため、1つお選びください。後から変更・追加も可能です。';

  @override
  String get roleSeekerTitle => '住まい／サービスを探しています';

  @override
  String get roleSeekerSubtitle => '賃貸・売却物件の閲覧、建築業者の検索ができます。';

  @override
  String get roleHostTitle => '物件オーナーです';

  @override
  String get roleHostSubtitle => 'お持ちの物件を賃貸または売却として掲載できます。';

  @override
  String get roleProviderTitle => '建築／設計プロバイダーです';

  @override
  String get roleProviderSubtitle => 'プロバイダープロフィールを設定し、お客様からの見積依頼を受け取ります。';

  @override
  String get socialLoginToInteract => 'コミュニティでやり取りするにはログインしてください。';

  @override
  String get socialDeletePostTitle => '投稿を削除';

  @override
  String get socialDeletePostConfirm => 'この投稿を削除してよろしいですか？';

  @override
  String get socialDelete => '削除';

  @override
  String get socialDeleteFailed => '投稿の削除に失敗しました';

  @override
  String get socialAll => 'すべて';

  @override
  String get socialWhatsOnMind => '今どんなことを考えていますか？';

  @override
  String get socialPostPhoto => '写真を投稿';

  @override
  String get socialNoPostsInCategory => 'このカテゴリにはまだ投稿がありません';

  @override
  String get socialNoPosts => 'まだ投稿がありません';

  @override
  String get socialBeFirstToShare => '最初にシェアしましょう！';

  @override
  String get socialEndOfFeed => '— フィードの終わり —';

  @override
  String get socialErrorOccurred => '問題が発生しました';

  @override
  String get socialRetry => '再試行';

  @override
  String get surveyEyebrow => 'パーソナル';

  @override
  String get surveyMyInterestsTitle => '興味のある分野';

  @override
  String get surveySkip => 'スキップ';

  @override
  String get surveyGreeting => 'こんにちは 👋';

  @override
  String get surveyIntro =>
      '興味のあることをAncu365にお知らせいただき、体験をパーソナライズしましょう。複数選択可能です。';

  @override
  String get surveyWhatDoYouWant => '何をしたいですか？';

  @override
  String get surveyRealEstateSection => '不動産';

  @override
  String get surveyConstructionSection => '建築';

  @override
  String get surveyConstructionInterest => '興味のある建築分野';

  @override
  String get surveyAreaOptional => '興味のあるエリア（任意）';

  @override
  String get surveyYouAreTitle => 'あなたは？';

  @override
  String get surveyIAmProvider => '建築／設計／インテリアの会社です';

  @override
  String get surveyIAmProviderHint => '建築セクションをデフォルトで表示し、見積依頼を受け取れるようにします';

  @override
  String get surveyProvinceHint => '都道府県を選択';

  @override
  String get surveySave => '保存';

  @override
  String get surveyStartExploring => '探し始める';

  @override
  String get surveyPrefsUpdated => '設定を更新しました';

  @override
  String get surveyInterestRent => '住まいを借りる';

  @override
  String get surveyInterestBuy => '物件を購入';

  @override
  String get surveyInterestSellOrList => '賃貸／物件掲載';

  @override
  String get surveyInterestFindService => '建築業者を探す';

  @override
  String get surveyInterestFollowConstruction => '建築業界ニュースをフォロー';

  @override
  String get surveyServiceDesign => 'デザイン';

  @override
  String get surveyServiceBuild => '建築';

  @override
  String get surveyServiceInterior => 'インテリア';

  @override
  String get surveyServiceIndustrial => '産業用不動産';

  @override
  String get loanTitle => '住宅ローンシミュレーター';

  @override
  String get loanHomePrice => '物件価格(円)';

  @override
  String get loanHomePriceHint => '例: 20000000';

  @override
  String loanDownPayment(Object pct) {
    return '頭金: $pct%';
  }

  @override
  String get loanInterestRate => '金利(%/年)';

  @override
  String get loanInterestRateHint => '例: 3';

  @override
  String loanTerm(Object years) {
    return '期間: $years年';
  }

  @override
  String loanYearsShort(Object years) {
    return '$years年';
  }

  @override
  String get loanMethod => '返済方式';

  @override
  String get loanMethodReducing => '元金均等返済';

  @override
  String get loanMethodAnnuity => '元利均等返済';

  @override
  String get loanInvalidPrice => '有効な物件価格を入力してください';

  @override
  String loanCalcFailed(Object error) {
    return '計算に失敗しました: $error';
  }

  @override
  String get loanMonthlyPayment => '月々の返済額';

  @override
  String get loanFirstMonthPayment => '初月返済額';

  @override
  String loanLastMonth(Object amount) {
    return '最終月: $amount';
  }

  @override
  String get loanPrincipal => '借入金額';

  @override
  String get loanTotalInterest => '利息総額';

  @override
  String get loanTotalPayment => '返済総額';

  @override
  String get loanTermLabel => '期間';

  @override
  String loanTermValue(Object months, Object years) {
    return '$monthsヶ月($years年)';
  }

  @override
  String get loanDisclaimer => '結果は参考値です。実際の金利は金融機関により決定されます。';

  @override
  String get apptChipPending => '承認待ち';

  @override
  String get apptChipApproved => '承認済み';

  @override
  String get apptChipCompleted => '完了';

  @override
  String get apptChipCancelled => 'キャンセル済み';

  @override
  String get apptChipRejected => '却下';

  @override
  String get apptChipLocked => '予約済み';

  @override
  String get apptChipLost => '成約済み';

  @override
  String get blockLoginToInteract => 'コミュニティに参加するにはログインしてください。';

  @override
  String get blockDeletePostTitle => '投稿を削除';

  @override
  String get blockDeletePostConfirm => 'この投稿を削除してもよろしいですか?';

  @override
  String get blockDelete => '削除';

  @override
  String get blockDeletePostFailed => '投稿の削除に失敗しました';

  @override
  String get blockCommunity => 'コミュニティ';

  @override
  String get blockCompose => '投稿';

  @override
  String blockReelsCategory(Object name) {
    return '$nameリール';
  }

  @override
  String get blockUnitList => '業者一覧';

  @override
  String get blockSearchByLocation => 'エリアで検索…';

  @override
  String get blockProvince => '都道府県';

  @override
  String get blockWard => '市区町村';

  @override
  String get blockKeywordHint => 'キーワード(内容・場所)…';

  @override
  String get blockSearch => '検索';

  @override
  String get blockClearFilter => '絞り込みをクリア';

  @override
  String blockNoPostsIn(Object name) {
    return '$nameにはまだ投稿がありません';
  }

  @override
  String get blockBeFirstToShare => '最初にシェアしましょう。';

  @override
  String get blockNoMorePosts => '— これ以上投稿はありません —';

  @override
  String get chgpwdSuccess => 'パスワードを変更しました';

  @override
  String get chgpwdFailed => 'パスワードの変更に失敗しました';

  @override
  String get chgpwdCurrentLabel => '現在のパスワード';

  @override
  String get chgpwdNewLabel => '新しいパスワード';

  @override
  String get chgpwdConfirmLabel => '新しいパスワード(確認)';

  @override
  String get chgpwdRequired => '必須';

  @override
  String get chgpwdMinLength => '6文字以上';

  @override
  String get chgpwdMismatch => 'パスワードが一致しません';

  @override
  String get clandEyebrow => '建築';

  @override
  String clandDefaultDesc(Object serviceName) {
    return '信頼できる$serviceName業者とつながる。';
  }

  @override
  String get clandDisclaimer => 'Ancu365は仲介プラットフォームです — 契約と支払いは当事者間で直接行われます。';

  @override
  String get clandRequestQuote => '相談・見積もりを依頼';

  @override
  String get clandViewContractors => '施工業者を見る';

  @override
  String get composerPickImageFailed => '画像を選択できませんでした';

  @override
  String get composerSelectCategoryPrompt => '投稿のカテゴリをお選びください';

  @override
  String get composerPostFailed => '投稿に失敗しました。再度お試しください';

  @override
  String get composerEditTitle => '投稿を編集';

  @override
  String get composerCreateTitle => '投稿を作成';

  @override
  String get composerSave => '保存';

  @override
  String get composerPost => '投稿';

  @override
  String get composerContentHint => 'いまどうしていますか?';

  @override
  String get composerSelectCategoryLabel => 'カテゴリを選択 *';

  @override
  String get composerLocationHint => '所在地(任意)— 例:東京都港区';

  @override
  String get composerPhotos => '写真';

  @override
  String get composerDiscardTitle => 'この投稿を破棄しますか?';

  @override
  String get composerDiscardBody => '入力した内容は保存されません。';

  @override
  String get composerKeepEditing => '編集を続ける';

  @override
  String get composerDiscard => '破棄';

  @override
  String composerImagesCount(Object count, Object max) {
    return '写真 $count/$max枚';
  }

  @override
  String ctrListTitle(Object name) {
    return '施工業者 · $name';
  }

  @override
  String get ctrListEmptyTitle => 'このエリアには施工業者がまだいません';

  @override
  String get ctrListEmptyBody => '依頼を送信してください — 条件に合う業者をご案内します。';

  @override
  String get ctrListRequestConsult => '相談を依頼';

  @override
  String get ctrListDefaultName => '施工業者';

  @override
  String get ctrListBadgePromoted => '注目';

  @override
  String get ctrListBadgePro => 'Pro';

  @override
  String get myPostsLoadError => '投稿を読み込めませんでした';

  @override
  String get myPostsLoadErrorHint => '接続を確認してもう一度お試しください。';

  @override
  String get myPostsRetry => '再試行';

  @override
  String get myPostsEmptyTitle => '投稿はまだありません';

  @override
  String get myPostsEmptyHint => 'コミュニティでシェアした投稿がここに表示されます。';

  @override
  String get plistSearchHint => '名前、説明、住所で検索…';

  @override
  String get plistEmptyTitle => '該当する物件が見つかりません';

  @override
  String get plistEmptySubtitle => '別のキーワードをお試しいただくか、後ほどご確認ください。';

  @override
  String plistAreaSqm(Object area) {
    return '${area}m²';
  }

  @override
  String get qualityTitle => '設備品質';

  @override
  String get qualityVerified => '確認済み';

  @override
  String get qualitySelfDeclared => 'オーナー自己申告';

  @override
  String get qualitySubtitle => '設備評価 — 価格帯に影響します。';

  @override
  String qualityStarRating(Object star) {
    return '$star/5';
  }

  @override
  String qualitySuggestedPrice(Object price) {
    return '品質に基づく推奨価格：$price/月';
  }

  @override
  String get qualityNotDeclared => '品質がまだ申告されていません。';

  @override
  String get qualityUpdateButton => '品質を更新';

  @override
  String get qualityDeclareButton => '物件品質を申告';

  @override
  String get qualityVerifRequested => '確認を依頼済み';

  @override
  String get qualityRequestVerification => '現地確認を依頼';

  @override
  String get qualityVerifSubmitted => '確認依頼を送信しました。当社スタッフが現地確認のためご連絡します。';

  @override
  String qualityRequestFailed(Object error) {
    return 'リクエストを送信できませんでした：$error';
  }

  @override
  String get reviewTitle => 'レビュー';

  @override
  String get reviewRatePrompt => 'この物件を星で評価してください';

  @override
  String reviewStarTooltip(Object count) {
    return '$count星';
  }

  @override
  String get reviewCommentLabel => 'ご感想';

  @override
  String get reviewCommentHint => '例：ホストが親切、清潔、記載通りの物件…';

  @override
  String get reviewSubmitButton => 'レビューを投稿';

  @override
  String get reviewSubmitSuccess => 'レビューを投稿しました。ありがとうございます！';

  @override
  String reviewSubmitError(Object error) {
    return 'レビューの投稿に失敗しました：$error';
  }

  @override
  String rfqTitle(Object serviceName) {
    return '相談を依頼 · $serviceName';
  }

  @override
  String get rfqSubtitle => '無料 · 電話番号は公開されません';

  @override
  String get rfqFieldName => '氏名 *';

  @override
  String get rfqFieldPhone => '電話番号 *';

  @override
  String get rfqFieldArea => 'エリア（都道府県／区市町村）';

  @override
  String get rfqFieldBudget => '予算の目安（任意）';

  @override
  String get rfqFieldDesc => 'ご要望をご記入ください';

  @override
  String get rfqSubmit => 'リクエストを送信';

  @override
  String get rfqValidation => '有効な氏名と電話番号を入力してください';

  @override
  String get rfqSendError => 'リクエストの送信に失敗しました。接続状況をご確認の上、再度お試しください。';

  @override
  String get rfqSuccessTitle => 'リクエストを送信しました！';

  @override
  String rfqSuccessBody(Object serviceName) {
    return '$serviceNameのチームから、できる限り早くご連絡いたします。';
  }

  @override
  String get rfqClose => '閉じる';

  @override
  String get searchHint => '物件、業者、コミュニティ投稿を検索…';

  @override
  String get searchEmptyTitle => 'Ancu365のすべてを検索';

  @override
  String get searchEmptySubtitle => '賃貸物件、建築／設計会社、コミュニティ投稿…';

  @override
  String get searchRecentTitle => '最近の検索';

  @override
  String get searchClearAll => 'すべてクリア';

  @override
  String searchNoResults(Object query) {
    return '「$query」の結果が見つかりません';
  }

  @override
  String get searchNoResultsSubtitle => '別のキーワードで試してみてください。';

  @override
  String get searchGroupHouses => '物件';

  @override
  String get searchGroupContractors => '会社';

  @override
  String get searchGroupPosts => 'コミュニティ投稿';

  @override
  String get searchHouseFallback => '物件';

  @override
  String get searchContractorFallback => '会社';

  @override
  String searchRating(Object rating, Object count) {
    return '⭐ $rating · レビュー$count件';
  }

  @override
  String get settingsMyPreferences => 'マイ設定';

  @override
  String get settingsMyPreferencesSub => '目的とエリアに合わせてパーソナライズ';

  @override
  String get settingsLogoutConfirm => 'ログアウトしてよろしいですか？';

  @override
  String get settingsLoggedOut => 'ログアウトしました';

  @override
  String get wishEyebrow => 'ブックマーク済み';

  @override
  String get wishTitle => 'お気に入り';

  @override
  String get wishCompareTooltip => '比較';

  @override
  String get wishRefreshTooltip => '更新';

  @override
  String get wishEmptyTitle => 'まだ部屋がありません';

  @override
  String get wishEmptySubtitle => '気になる部屋のハートをタップすると、ここに保存されます。';

  @override
  String get wishUnfavoriteTooltip => 'お気に入りから削除';

  @override
  String get wishUnfavoriteError => 'お気に入りから削除できませんでした';

  @override
  String get hApprovalInboxTitle => '承認受信箱';

  @override
  String get hApprovalInboxEyebrow => 'オーナー・承認';

  @override
  String get hApprovalEmptyTitle => '依頼はありません';

  @override
  String get hApprovalEmptySubtitle => 'オペレーターからの承認依頼はここに表示されます。';

  @override
  String hApprovalBiometricReason(Object amount) {
    return '$amountの取引を承認するために認証してください';
  }

  @override
  String get hApprovalBiometricRequired => '続行するには生体認証が必要です';

  @override
  String get hApprovalApproveSuccess => '承認しました';

  @override
  String get hApprovalApproveFailed => '承認に失敗しました。再度お試しください。';

  @override
  String get hApprovalRejectSuccess => '依頼を却下しました';

  @override
  String get hApprovalRejectReasonTitle => '却下理由';

  @override
  String get hApprovalRejectReasonHint => '理由(任意)';

  @override
  String get hApprovalSkip => 'スキップ';

  @override
  String get hApprovalReject => '却下';

  @override
  String get hApptTitle => '内見依頼';

  @override
  String get hApptEmpty => '依頼はまだありません。';

  @override
  String hApptCompletedDeals(Object count) {
    return '成約 $count件';
  }

  @override
  String get hApptRateGuest => 'ゲストを評価';

  @override
  String hApptRateGuestTitle(Object name) {
    return '$nameさんを評価';
  }

  @override
  String get hApptGuestFallback => 'ゲスト';

  @override
  String get hApptReviewHint => 'コメント(任意)';

  @override
  String get hApptCancel => 'キャンセル';

  @override
  String get hApptSend => '送信';

  @override
  String get hApptReviewSuccess => 'ゲストを評価しました';

  @override
  String hApptReviewFailed(Object error) {
    return 'レビューを送信できませんでした:$error';
  }

  @override
  String get hApptEmptyHintPending => 'ゲストからの内見依頼はここに表示されます。';

  @override
  String get hApptEmptyHintApproved => '承認済みの予約はまだありません。';

  @override
  String get hApptEmptyHintPast => '終了・却下の依頼はまだありません。';

  @override
  String get hApptTabPending => '保留中';

  @override
  String get hApptTabApproved => '承認済み';

  @override
  String get hApptTabClosed => '終了';

  @override
  String get hAvailTitle => '内見時間帯';

  @override
  String get hAvailWeekdaysSection => '受付曜日';

  @override
  String get hAvailSlotsSection => '受付時間帯(各1時間)';

  @override
  String get hAvailSelectAll => 'すべて選択';

  @override
  String get hAvailDeselect => '選択解除';

  @override
  String get hAvailSave => '時間帯を保存';

  @override
  String get hAvailSavedToast => '内見時間帯を保存しました。';

  @override
  String get hAvailSaveFailed => '保存に失敗しました';

  @override
  String get hAvailIntroDefault =>
      '現在すべての曜日・時間帯で内見を受け付けています。特定時間帯のみ受け付ける場合は絞り込んでください。';

  @override
  String get hAvailIntroCustom => '以下で選択した曜日・時間帯のみ、ゲストが内見予約できます。';

  @override
  String get hAvailEmptyWarning => '曜日や時間帯が未選択です。ゲストが内見予約できません。';

  @override
  String get hAvailMon => '月';

  @override
  String get hAvailTue => '火';

  @override
  String get hAvailWed => '水';

  @override
  String get hAvailThu => '木';

  @override
  String get hAvailFri => '金';

  @override
  String get hAvailSat => '土';

  @override
  String get hAvailSun => '日';

  @override
  String get hContractDetTitle => '契約';

  @override
  String get hContractDetNotFound => '契約が見つかりません';

  @override
  String get hContractDetStartDate => '開始日';

  @override
  String get hContractDetEndDate => '終了日';

  @override
  String get hContractDetRent => '家賃';

  @override
  String hContractDetRentPerMonth(Object amount) {
    return '$amount円/月';
  }

  @override
  String get hContractDetDeposit => '敷金';

  @override
  String hContractDetAmountDong(Object amount) {
    return '$amount円';
  }

  @override
  String get hContractDetTenants => '入居者';

  @override
  String get hContractDetRepresentative => '代表者';

  @override
  String get hContractDetActivate => '契約を有効化';

  @override
  String get hContractDetCheckout => 'チェックアウト(終了)';

  @override
  String get hContractDetTransferRoom => '部屋を変更';

  @override
  String get hContractDetActualEndDate => '実際の退去日';

  @override
  String get hContractDetDepositRefund => '敷金返金';

  @override
  String get hContractDetDamage => '損傷';

  @override
  String get hContractDetStatusDraft => '下書き';

  @override
  String get hContractDetStatusActive => '有効';

  @override
  String get hContractDetStatusExpired => '期限切れ';

  @override
  String get hContractDetStatusTerminated => '解約済み';

  @override
  String get hContractDetActivateEyebrow => '有効化';

  @override
  String get hContractDetActivateConfirmMsg =>
      'この契約を有効化すると部屋のステータスが「入居中」に変更されます。続行しますか?';

  @override
  String get hContractDetActivateSuccess => '契約を有効化しました';

  @override
  String get hContractDetFailed => '失敗しました';

  @override
  String get hContractFormTitle => '新規契約';

  @override
  String get hContractFormEyebrow => 'フォーム';

  @override
  String get hContractFormStartDate => '開始日 *';

  @override
  String get hContractFormEndDate => '終了日 *';

  @override
  String get hContractFormMonthlyRent => '月額家賃(JPY)*';

  @override
  String get hContractFormRentInvalid => '有効な金額を入力してください';

  @override
  String get hContractFormDeposit => '敷金(JPY)';

  @override
  String get hContractFormSubmit => '契約を作成';

  @override
  String get hContractFormSelectDates => '開始日と終了日を選択してください';

  @override
  String get hContractFormEndAfterStart => '終了日は開始日より後にしてください';

  @override
  String get hContractFormOnePrimary => '主契約者(代表者)はちょうど1名必要です';

  @override
  String get hContractFormTenantNameRequired => '入居者の氏名を入力してください';

  @override
  String get hContractFormCreated => '契約を作成しました(ステータス:下書き)';

  @override
  String get hContractFormCreateFailed => '作成に失敗しました';

  @override
  String hContractFormPhotoUploadFailed(Object error) {
    return '写真のアップロードに失敗しました:$error';
  }

  @override
  String hContractFormCccdUploadFailed(Object error) {
    return '身分証写真のアップロードに失敗しました:$error';
  }

  @override
  String hContractTermUploadFailed(Object error) {
    return '写真のアップロードに失敗しました:$error';
  }

  @override
  String get hContractTermActionEnd => '契約を解約';

  @override
  String get hContractTermPickDateFirst => '実際の退去日を選択してください';

  @override
  String get hContractTermEnd => '解約';

  @override
  String get hContractTermConfirmTitle => '契約解約の確認';

  @override
  String get hContractTermConfirmMessage => 'この契約を解約してもよろしいですか?\nこの操作は取り消せません。';

  @override
  String get hContractTermDoneEnded => '契約を解約しました';

  @override
  String get hContractTermFailed => '失敗しました';

  @override
  String get hContractTermMoveOut => '退去';

  @override
  String get hContractTermIntro => '実際の退去日と敷金返金の詳細を確認してください。';

  @override
  String get hContractTermActualEndDate => '実際の退去日 *';

  @override
  String get hContractTermPickDate => '日付を選択';

  @override
  String get hContractTermRefundAmount => '敷金返金額(JPY)';

  @override
  String get hContractTermRefundHelper => '返金なしの場合は0を入力';

  @override
  String get hContractTermDamageNote => '損傷メモ';

  @override
  String get hContractTermDamageNoteHelper => '損傷の内容を記載してください';

  @override
  String get hContractTermDamagePhotos => '損傷写真';

  @override
  String get hContractTermAddPhoto => '写真を追加';

  @override
  String get hContractTermConfirmMoveOut => '退去を確定';

  @override
  String get hContractXferTransferRoom => '部屋を変更';

  @override
  String get hContractXferActionTransfer => '部屋を変更';

  @override
  String get hContractXferContractEyebrow => '契約';

  @override
  String get hContractXferIntro => '建物と空室を選択して契約を移動してください。';

  @override
  String get hContractXferBuildingLabel => '建物 *';

  @override
  String get hContractXferNoBuildings => '建物がありません';

  @override
  String get hContractXferSelectBuilding => '建物を選択';

  @override
  String get hContractXferNoVacantRooms => 'この建物に空室はありません。';

  @override
  String get hContractXferVacantRoomLabel => '空室 *';

  @override
  String get hContractXferSelectRoom => '部屋を選択';

  @override
  String hContractXferRoomOption(Object code, Object price) {
    return '$code — $price円/月';
  }

  @override
  String get hContractXferConfirmTitle => '部屋変更の確認';

  @override
  String hContractXferConfirmMessage(Object roomName) {
    return '契約を部屋 $roomName に変更してもよろしいですか?\n旧部屋は「空室」になります。';
  }

  @override
  String hContractXferSuccess(Object roomName) {
    return '契約を部屋 $roomName に変更しました';
  }

  @override
  String get hContractXferFailed => '失敗しました';

  @override
  String get hContractXferLoadRoomsError => '部屋を読み込めません';

  @override
  String get hDelegDetNotFound => '見つかりません';

  @override
  String get hDelegDetNotFoundDelegation => '委任が見つかりません';

  @override
  String get hDelegDetOperator => 'オペレーター';

  @override
  String get hDelegDetEyebrow => 'オーナー・委任管理';

  @override
  String get hDelegDetPausedToast => '委任を一時停止しました';

  @override
  String get hDelegDetResumedToast => '委任を再開しました';

  @override
  String get hDelegDetTerminateTitle => '委任を終了しますか?';

  @override
  String get hDelegDetTerminateBody => 'オペレーターは30日後にアクセス権を失います。この操作は取り消せません。';

  @override
  String get hDelegDetTerminate => '終了';

  @override
  String get hDelegDetTerminatedToast => '委任を終了しました';

  @override
  String get hDelegDetThresholdsUpdatedToast => '承認しきい値を更新しました';

  @override
  String hDelegDetPermissionLabel(Object role) {
    return '権限:$role';
  }

  @override
  String hDelegDetStartLabel(Object date) {
    return '開始日:$date';
  }

  @override
  String hDelegDetPropertiesLabel(Object count) {
    return '物件数:$count';
  }

  @override
  String get hDelegDetStatusActive => '有効';

  @override
  String get hDelegDetStatusPaused => '一時停止';

  @override
  String get hDelegDetStatusTerminated => '終了';

  @override
  String get hDelegDetRoleOperatorFull => 'フルオペレーター';

  @override
  String get hDelegDetRoleAccountant => '経理担当';

  @override
  String get hDelegDetRoleViewer => '閲覧のみ';

  @override
  String get hDelegDetRoleOwnerView => 'オーナー(閲覧)';

  @override
  String get hDelegDetPause => '一時停止';

  @override
  String get hDelegDetResume => '再開';

  @override
  String get hDelegDetThresholds => '承認しきい値';

  @override
  String get hDelegDetEdit => '編集';

  @override
  String get hDelegDetSaveThresholds => 'しきい値を保存';

  @override
  String get hDelegInvTitle => 'オペレーターを招待';

  @override
  String get hDelegInvEyebrow => 'オーナー・委任';

  @override
  String get hDelegInvOperatorInfo => 'オペレーター情報';

  @override
  String get hDelegInvOperatorEmail => 'オペレーター メール';

  @override
  String get hDelegInvPermissions => '権限';

  @override
  String get hDelegInvThresholds => '承認しきい値（円）';

  @override
  String get hDelegInvSend => '招待を送信';

  @override
  String get hDelegInvRoleOperatorFull => 'フルオペレーション';

  @override
  String get hDelegInvRoleAccountant => '経理担当';

  @override
  String get hDelegInvRoleViewer => '閲覧者';

  @override
  String get hDelegInvEmailRequired => 'メールアドレスを入力してください';

  @override
  String get hDelegInvEmailInvalid => 'メールアドレスが無効です';

  @override
  String get hDelegInvSendSuccess => '招待を送信しました';

  @override
  String get hDelegInvSendFailed => '招待を送信できませんでした。もう一度お試しください。';

  @override
  String get hFeeTitle => 'サービス料金';

  @override
  String get hFeeCreateBuildingFirst => '先に建物を作成してください';

  @override
  String get hFeeEmptyTitle => 'サービス料金はまだありません';

  @override
  String get hFeeEmptySubtitle => '管理するサービス料金を追加してください。';

  @override
  String get hFeeMonthly => '毎月';

  @override
  String get hFeeOneTime => '単発';

  @override
  String get hFeeActive => '有効';

  @override
  String get hFeeInactive => '無効';

  @override
  String get hFeeEnterNameBuilding => '名称と建物を入力してください';

  @override
  String get hFeeSaveFailed => '保存に失敗しました';

  @override
  String get hFeeCreateTitle => 'サービス料金を追加';

  @override
  String get hFeeBuilding => '建物';

  @override
  String get hFeeServiceName => 'サービス名';

  @override
  String get hFeeUnitPrice => '単価（円）';

  @override
  String get hFeeCycle => '周期';

  @override
  String get hFeeSave => '保存';

  @override
  String get hHomeDlgActionDelete => '掲載を削除';

  @override
  String get hHomeDlgDeleteTitle => '掲載を削除';

  @override
  String hHomeDlgDeleteBody(Object title) {
    return '「$title」を削除してもよろしいですか？';
  }

  @override
  String get hHomeDlgDeleteConfirm => '削除';

  @override
  String get hHomeDlgDeleteSuccess => '掲載を削除しました';

  @override
  String get hHomeDlgDeleteFail => '削除に失敗しました';

  @override
  String get hHomeDlgActionCloseUnit => '部屋をクローズ';

  @override
  String get hHomeDlgCloseUnitTitle => '1部屋をクローズ';

  @override
  String hHomeDlgCloseUnitBody(Object title) {
    return '「$title」の1部屋をアプリ外のお客様に貸し出したことを確認しますか？空室数が1減り、保留中の内見リクエストには自動で「成約済み」と通知されます。';
  }

  @override
  String get hHomeDlgCloseUnitConfirm => '部屋をクローズ';

  @override
  String get hHomeDlgCloseUnitSuccess => '1部屋をクローズしました';

  @override
  String get hHomeDlgCloseUnitFail => '操作に失敗しました';

  @override
  String get hHomeDlgLockTitle => '予約を確定';

  @override
  String hHomeDlgLockBody(Object house, Object guest) {
    return '部屋「$house」を$guest様に貸し出しますか？同じ部屋への他の内見リクエストは自動的にクローズされ、お客様に通知されます。';
  }

  @override
  String get hHomeDlgLockDefaultHouse => 'この部屋';

  @override
  String get hHomeDlgLockDefaultGuest => 'このお客様';

  @override
  String get hHomeDlgLockConfirm => '確定';

  @override
  String get hHomeDlgLockSuccess => 'お客様へ部屋を確定しました';

  @override
  String get hHomeDlgLockFail => '予約に失敗しました';

  @override
  String get hHomeListingsTotalEyebrow => '掲載総数';

  @override
  String get hHomeListingsTotalCaption => 'これまでに掲載したすべての物件';

  @override
  String get hHomeListingsPendingEyebrow => '承認待ち';

  @override
  String get hHomeListingsPendingCaption => '管理者の承認待ち';

  @override
  String get hHomeListingsApprovedEyebrow => '公開中';

  @override
  String get hHomeListingsApprovedCaption => '一般公開中';

  @override
  String get hHomeListingsSectionListings => '掲載';

  @override
  String get hHomeListingsEmptyListingsLine => '掲載はまだありません。';

  @override
  String get hHomeListingsEmptyListingsHint => '「新規掲載」をタップして最初の掲載を作成してください。';

  @override
  String get hHomeListingsSectionAppointments => '内見リクエスト';

  @override
  String get hHomeListingsEmptyAppointmentsLine => '保留中の内見リクエストはありません。';

  @override
  String get hHomeListingsEmptyAppointmentsHint => 'お客様が予約するとここに表示されます。';

  @override
  String get hHomeListingsPostNew => '新規掲載';

  @override
  String get hHomeRoomsKpiCollected => '入金済み';

  @override
  String get hHomeRoomsKpiUnpaid => '未収';

  @override
  String get hHomeRoomsKpiOccupancy => '稼働率';

  @override
  String get hHomeRoomsQuickCreateInvoice => '請求書を作成';

  @override
  String get hHomeRoomsQuickMeter => 'メーター検針';

  @override
  String get hHomeRoomsQuickReminder => '未収リマインド';

  @override
  String get hHomeRoomsQuickReports => 'レポート';

  @override
  String get hHomeRoomsTodoHeader => '本日のタスク';

  @override
  String get hHomeRoomsSectionBilling => '請求';

  @override
  String get hHomeRoomsInvoicesTitle => '請求書';

  @override
  String get hHomeRoomsInvoicesSubtitle => '請求書の一覧と発行';

  @override
  String get hHomeRoomsDebtTitle => '未収金';

  @override
  String get hHomeRoomsDebtSubtitle => '部屋ごとに未収を管理';

  @override
  String get hHomeRoomsServiceFeesTitle => 'サービス料金';

  @override
  String get hHomeRoomsServiceFeesSubtitle => '電気・水道・サービス料金の設定';

  @override
  String get hHomeRoomsSectionOps => 'その他の運用';

  @override
  String get hHomeRoomsLeadsTitle => '見込み顧客';

  @override
  String get hHomeRoomsLeadsSubtitle => '内見予約と保存された物件';

  @override
  String get hHomeRoomsKhaiBaoTitle => '宿泊者登録';

  @override
  String get hHomeRoomsHomestayTitle => 'ホームステイ';

  @override
  String get hHomeRoomsSyncTitle => '他のマーケットプレイスへ同期';

  @override
  String get hHomeRoomsAnalyticsTitle => '売上分析';

  @override
  String get hHomeRoomsAnalyticsSubtitle => '5つのKPI・売上、稼働率、ADR';

  @override
  String get hIntroAppBarTitle => 'ホスト登録';

  @override
  String get hIntroEyebrow => 'ANCU365  ·  ホスト版';

  @override
  String get hIntroHeadline => '部屋を開き、\nお客様をお迎えし、\n売上を回収。';

  @override
  String get hIntroSubtitle =>
      '賃貸やホームステイの運営を、物件掲載からお客様の確認、契約締結、請求書の精算まで、Ancu365でスマホからまとめて行えます。';

  @override
  String get hIntroBenefitsLabel => '得られるもの';

  @override
  String get hIntroBenefit1Title => '建物と部屋を管理';

  @override
  String get hIntroBenefit1Body => '部屋の状況、契約、メーターをひとつの電子台帳で管理できます。';

  @override
  String get hIntroBenefit2Title => '内見リクエストを直接受付';

  @override
  String get hIntroBenefit2Body =>
      'お客様が内見時間を予約し、ホストはアプリ内で承認・却下できます。メッセージが散らばりません。';

  @override
  String get hIntroBenefit3Title => '請求書発行と契約締結';

  @override
  String get hIntroBenefit3Body => 'メーターから光熱費を自動計算、契約書への署名と一元保管ができます。';

  @override
  String get hIntroBenefit4Title => 'マルチチャネルで露出';

  @override
  String get hIntroBenefit4Body => '物件は探索ページと物件マップに掲載され、数千人のお客様に届きます。';

  @override
  String get hIntroCta => '登録を開始';

  @override
  String get hIntroCtaNote => '所要時間2〜3分。本人確認書類と振込口座情報が必要です。';

  @override
  String get hInvBatchTitle => '請求書を一括生成';

  @override
  String get hInvBatchBuildingLabel => '建物 *';

  @override
  String get hInvBatchSelectBuilding => '建物を選択';

  @override
  String get hInvBatchMonthLabel => '月（YYYY-MM） *';

  @override
  String get hInvBatchSelectMonth => '月を選択';

  @override
  String get hInvBatchElecPriceLabel => '電気単価（円/kWh）';

  @override
  String get hInvBatchWaterPriceLabel => '水道単価（円/m³）';

  @override
  String get hInvBatchGenerateButton => '請求書を生成';

  @override
  String get hInvBatchHelpText =>
      'システムは建物内のアクティブな契約ごとに請求書（下書き状態）を生成します。この期間の請求書が既に存在する場合はスキップされます（冪等）。';

  @override
  String get hInvBatchSelectRequired => '建物と月を選択してください';

  @override
  String get hInvBatchCreateFailed => '作成に失敗しました';

  @override
  String get hInvDetSentSuccess => '請求書を送信しました — 公開リンクが利用可能です';

  @override
  String hInvDetCannotOpen(Object url) {
    return '開けませんでした：$url';
  }

  @override
  String get hInvDetTitle => '請求書の詳細';

  @override
  String hInvDetPeriod(Object start, Object end) {
    return '期間 $start → $end';
  }

  @override
  String hInvDetDue(Object date) {
    return '支払期限 $date';
  }

  @override
  String get hInvDetDetails => '詳細';

  @override
  String get hInvDetTotal => '合計';

  @override
  String get hInvDetCollected => '入金済み';

  @override
  String get hInvDetRemaining => '残額';

  @override
  String get hInvDetSendInvoice => '請求書を送信';

  @override
  String get hInvDetRecordPayment => '入金を記録';

  @override
  String get hInvDetOpenPublicLink => '公開リンクを開く';

  @override
  String get hInvDetRemindZalo => 'Zaloでリマインド';

  @override
  String get hInvDetCreditNote => 'クレジットノートを作成（調整）';

  @override
  String get hKhaibaoTitle => '届出の詳細';

  @override
  String get hKhaibaoShareSubject => '宿泊者届出フォーム';

  @override
  String get hKhaibaoDeclaredRecorded => '届出を記録しました';

  @override
  String get hKhaibaoSaveFailed => '保存に失敗しました';

  @override
  String get hKhaibaoSkipped => 'スキップ済み';

  @override
  String get hKhaibaoPhone => '電話番号';

  @override
  String get hKhaibaoRoom => '部屋';

  @override
  String get hKhaibaoBuilding => '建物';

  @override
  String get hKhaibaoCheckInDate => 'チェックイン日';

  @override
  String get hKhaibaoLinkExpires => 'リンク有効期限';

  @override
  String get hKhaibaoDeclaredAt => '届出日時';

  @override
  String get hKhaibaoSkipReason => 'スキップ理由';

  @override
  String get hKhaibaoViewForm => '届出フォームを表示（TK1）';

  @override
  String get hKhaibaoMarkDeclared => '届出済み';

  @override
  String get hKhaibaoSkipEarlyLeave => 'スキップ（お客様が早期退去）';

  @override
  String get hKhaibaoSkipHint => '例：お客様が早期退去';

  @override
  String get hKhaibaoSkip => 'スキップ';

  @override
  String get hLeadsTitle => '見込み顧客';

  @override
  String hLeadsTabTarget(Object count) {
    return 'ターゲット（$count）';
  }

  @override
  String hLeadsTabPotential(Object count) {
    return '見込み（$count）';
  }

  @override
  String hLeadsLoadError(Object error) {
    return '読み込めませんでした：$error';
  }

  @override
  String get hLeadsEmptyTarget => 'あなたの物件の内見を予約したお客様はまだいません。';

  @override
  String get hLeadsEmptyPotential => 'あなたの物件をお気に入りに保存したお客様はまだいません。';

  @override
  String get hLeadsBadgeBooked => '予約済み';

  @override
  String get hLeadsBadgeBookViewing => '内見を予約';

  @override
  String get hLeadsBadgeSaved => '保存した物件';

  @override
  String get hLeadsDefaultName => 'お客様';

  @override
  String get hLeadsDefaultHouse => '物件';

  @override
  String get hListingsTitle => 'マイ掲載';

  @override
  String get hListingsRefresh => '更新';

  @override
  String get hListingsPostRoom => '部屋を掲載';

  @override
  String get hListingsEmptyTitle => 'まだ掲載がありません';

  @override
  String get hListingsEmptyHint => '「部屋を掲載」をタップして最初の掲載を作成してください。';

  @override
  String get hListingsEdit => '掲載を編集';

  @override
  String get hListingsDelete => '掲載を削除';

  @override
  String get hListingsDeleteTitle => '掲載を削除';

  @override
  String hListingsDeleteConfirm(Object title) {
    return '「$title」を削除してもよろしいですか？';
  }

  @override
  String get hListingsDeleteAction => '削除';

  @override
  String get hListingsDeleteSuccess => '掲載を削除しました';

  @override
  String get hListingsDeleteFailed => '削除に失敗しました';

  @override
  String get hListingsStatusApproved => '公開中';

  @override
  String get hListingsStatusPending => '審査中';

  @override
  String get hListingsStatusRejected => '却下';

  @override
  String get hListingsStatusHidden => '非公開';

  @override
  String get hProfileSavedInfo => '情報を保存しました';

  @override
  String get hProfileSaveFailed => '保存に失敗しました';

  @override
  String get hProfileEyebrow => 'アカウント';

  @override
  String get hProfileTitle => 'ホストプロフィール';

  @override
  String get hProfileEdit => '編集';

  @override
  String get hProfileEmptyTitle => 'プロフィールはまだありません';

  @override
  String get hProfileEmptySubtitle => 'オンボーディングを完了してホストプロフィールを作成してください。';

  @override
  String get hProfileSaveChanges => '変更を保存';

  @override
  String get hProfileVerified => 'アカウント確認済み';

  @override
  String get hProfilePending => '確認待ち';

  @override
  String get hProfileVerifiedDesc => '部屋を掲載し、支払いを受け取ることができます。';

  @override
  String get hProfilePendingDesc => '本人確認書類をアップロードして確認を完了してください。';

  @override
  String get hProfileIdentitySection => '本人確認';

  @override
  String get hProfileCccdFront => '本人確認書類（表面）';

  @override
  String get hProfileCccdBack => '本人確認書類（裏面）';

  @override
  String get hProfileUploaded => 'アップロード済み';

  @override
  String get hProfileNotUploaded => '未アップロード';

  @override
  String get hProfilePaymentSection => '支払情報';

  @override
  String get hProfileBank => '銀行';

  @override
  String get hProfileBankHint => '例：三菱UFJ銀行';

  @override
  String get hProfileAccountNumber => '口座番号';

  @override
  String get hProfileAccountHolder => '口座名義人';

  @override
  String get hProfileAccountHolderHint => 'カードの名義';

  @override
  String get hProfileTaxId => '納税者番号';

  @override
  String get hProfilePerformanceSection => 'パフォーマンス';

  @override
  String get hProfileRating => '評価';

  @override
  String get hProfileAvgResponse => '平均応答';

  @override
  String get hProfileHours => '時間';

  @override
  String get hResvDetTitle => '予約の詳細';

  @override
  String get hResvDetNotFound => '予約が見つかりません';

  @override
  String get hResvDetError => 'エラー';

  @override
  String get hResvDetReasonHint => '理由…';

  @override
  String get hResvDetConfirm => '確定';

  @override
  String get hResvDetCheckIn => 'チェックイン';

  @override
  String get hResvDetCheckOut => 'チェックアウト';

  @override
  String get hResvDetNights => '泊数';

  @override
  String get hResvDetPhone => '電話番号';

  @override
  String get hResvDetEmail => 'メールアドレス';

  @override
  String get hResvDetTotal => '合計';

  @override
  String get hResvDetRefund => '返金';

  @override
  String get hResvDetCancelledAt => 'キャンセル日時';

  @override
  String get hResvDetReason => '理由';

  @override
  String get hResvDetApprove => '承認';

  @override
  String get hResvDetApproved => '承認済み';

  @override
  String get hResvDetReject => '却下';

  @override
  String get hResvDetRejectReason => '却下理由';

  @override
  String get hResvDetRejected => '却下済み';

  @override
  String get hResvDetCheckedIn => 'チェックイン済み';

  @override
  String get hResvDetCheckedOut => 'チェックアウト済み';

  @override
  String get hResvDetCancel => '予約をキャンセル';

  @override
  String get hResvDetCancelReason => 'キャンセル理由';

  @override
  String get hResvDetCancelled => '予約をキャンセルしました';

  @override
  String get hResvListTitle => '予約';

  @override
  String get hResvListFilterAll => 'すべて';

  @override
  String get hResvListFilterPending => '保留中';

  @override
  String get hResvListFilterApproved => '承認済み';

  @override
  String get hResvListFilterCheckedIn => 'チェックイン済み';

  @override
  String get hResvListFilterCheckedOut => 'チェックアウト済み';

  @override
  String get hResvListFilterCancelled => 'キャンセル済み';

  @override
  String get hResvListEmptyTitle => '予約はありません';

  @override
  String get hResvListEmptySubtitle => 'このフィルターに該当する予約はまだありません。';

  @override
  String hResvListNights(Object count) {
    return '$count泊';
  }

  @override
  String get hRoomDetMaintEyebrow => 'メンテナンスフォーム';

  @override
  String get hRoomDetMaintTitle => '部屋をメンテナンスにする';

  @override
  String get hRoomDetConfirm => '確定';

  @override
  String hRoomDetMaintSetFrom(Object start) {
    return '$startよりメンテナンス設定';
  }

  @override
  String get hRoomDetFailed => '失敗しました';

  @override
  String get hRoomDetEndMaintEyebrow => 'メンテナンス終了';

  @override
  String get hRoomDetEndMaintTitle => '終了してもよろしいですか？';

  @override
  String get hRoomDetEndMaintBody => '部屋は空室の状態に戻ります。';

  @override
  String get hRoomDetEnd => '終了';

  @override
  String get hRoomDetMaintEnded => 'メンテナンスを終了しました';

  @override
  String hRoomDetDuplicated(Object code) {
    return '複製を作成しました $code';
  }

  @override
  String get hRoomDetHeader => '部屋カルテ';

  @override
  String get hRoomDetNotFound => '部屋が見つかりません';

  @override
  String get hRoomDetDuplicate => '部屋を複製';

  @override
  String get hRoomDetSetMaint => 'メンテナンスに設定';

  @override
  String get hRoomDetEndMaint => 'メンテナンス終了';

  @override
  String get hStep1Eyebrow => 'ステップ 1 / 3';

  @override
  String get hStep1Title => 'ホストとして登録';

  @override
  String get hStep1SectionTitle => '個人情報';

  @override
  String get hStep1Subtitle => 'ホストアカウントを確認するため、すべての情報をご記入ください。';

  @override
  String get hStep1NameLabel => '氏名';

  @override
  String get hStep1NameHint => '山田 太郎';

  @override
  String get hStep1NameError => '氏名を入力してください';

  @override
  String get hStep1PhoneLabel => '電話番号';

  @override
  String get hStep1PhoneError => '電話番号が無効です';

  @override
  String get hStep1DobLabel => '生年月日';

  @override
  String get hStep1AddressLabel => '住民票上の住所';

  @override
  String get hStep1AddressHint => '番地、通り、区、市町村、都道府県';

  @override
  String get hStep1AddressError => '住所を入力してください';

  @override
  String get hStep1Next => '次へ';

  @override
  String get hStep1InitError => 'プロフィールの初期化に失敗しました';

  @override
  String get hStep2WarnAtLeastOne => '本人確認書類の少なくとも片面をアップロードしてください';

  @override
  String get hStep2UploadFailed => 'アップロードに失敗しました';

  @override
  String get hStep2Eyebrow => 'ステップ 2 / 3';

  @override
  String get hStep2Title => '本人確認書類の確認';

  @override
  String get hStep2Heading => '本人確認書類をアップロード';

  @override
  String get hStep2Subtitle => '本人確認のため、本人確認書類の表面と裏面の写真をアップロードしてください。';

  @override
  String get hStep2FrontLabel => '本人確認書類（表面）';

  @override
  String get hStep2BackLabel => '本人確認書類（裏面）';

  @override
  String get hStep2SecurityNote =>
      '本人確認書類の写真は暗号化され、安全に保管されます。第三者と共有することはありません。';

  @override
  String get hStep2Next => '次へ';

  @override
  String get hStep3Eyebrow => 'ステップ 3 / 3';

  @override
  String get hStep3Title => '支払情報';

  @override
  String get hStep3ReceivingAccount => '受取口座';

  @override
  String get hStep3Subtitle => '入居者からの支払いを受け取る銀行口座を入力してください。';

  @override
  String get hStep3BankLabel => '銀行 *';

  @override
  String get hStep3BankHint => '銀行を選択';

  @override
  String get hStep3BankRequired => '銀行を選択してください';

  @override
  String get hStep3AccountNumber => '口座番号';

  @override
  String get hStep3AccountNumberRequired => '口座番号を入力してください';

  @override
  String get hStep3AccountNumberInvalid => '口座番号が無効です';

  @override
  String get hStep3AccountHolder => '口座名義人';

  @override
  String get hStep3AccountHolderRequired => '口座名義人を入力してください';

  @override
  String get hStep3TaxId => '納税者番号（任意）';

  @override
  String get hStep3SubmitButton => '登録を完了';

  @override
  String get hStep3SaveFailed => '保存に失敗しました';

  @override
  String get adminCtrTitle => '施工業者の承認';

  @override
  String get adminCtrApproved => 'プロフィールを承認しました';

  @override
  String get adminCtrCertVerified => '資格確認済み';

  @override
  String adminCtrError(Object error) {
    return 'エラー:$error';
  }

  @override
  String get adminCtrRejectTitle => 'このプロフィールを却下しますか?';

  @override
  String get adminCtrRejectBody => 'このプロフィールは一覧に表示されません。';

  @override
  String get adminCtrCancel => 'キャンセル';

  @override
  String get adminCtrReject => '却下';

  @override
  String get adminCtrRejected => '却下しました';

  @override
  String get adminCtrLoadFailed => '読み込みに失敗しました';

  @override
  String get adminCtrLoadFailedHint => '接続状況を確認して再度お試しください。';

  @override
  String get adminCtrRetry => '再試行';

  @override
  String get adminCtrEmptyTitle => '承認待ちのプロフィールはありません';

  @override
  String get adminCtrEmptyHint => '新しいプロフィールがここに表示されます。';

  @override
  String get adminCtrCompanyFallback => '施工業者';

  @override
  String adminCtrCertNumber(Object number) {
    return '免許番号:$number';
  }

  @override
  String get adminCtrCertVerifiedLabel => '確認済み';

  @override
  String get adminCtrVerify => '確認';

  @override
  String get adminCtrApprove => '承認';

  @override
  String get adminHomeTitle => '管理ダッシュボード';

  @override
  String get adminHomePending => '承認待ち';

  @override
  String get adminHomeApproved => '承認済み';

  @override
  String get adminHomeRejected => '却下';

  @override
  String get adminHomePublished => '公開中';

  @override
  String get adminHomeUsers => 'ユーザー';

  @override
  String get adminHomeToolModerateReel => 'リール\n審査';

  @override
  String get adminHomeToolVerifyQueue => '確認\nキュー';

  @override
  String get adminHomeToolPlanningRisk => '計画\nリスク';

  @override
  String get adminHomeToolTrustedMark => '信頼\nマーク';

  @override
  String get adminHomeToolApproveContractor => '施工業者\n承認';

  @override
  String get adminHomeToolMarketResearch => '市場\n調査';

  @override
  String get adminHomeEmptyPending => '確認待ちの物件はありません';

  @override
  String get adminHomeEmptyApproved => '承認済みの物件はまだありません';

  @override
  String get adminHomeEmptyRejected => '却下された物件はまだありません';

  @override
  String adminHomeHost(Object name) {
    return 'ホスト:$name';
  }

  @override
  String get adminHomeReject => '却下';

  @override
  String get adminHomeApprove => '承認';

  @override
  String get adminHomeReapprove => '再承認';

  @override
  String get adminHomeUnpublish => '非公開';

  @override
  String get adminHomeRejectReasonTitle => '却下理由';

  @override
  String get adminHomeRejectReasonHint => 'ホストが修正方法を把握できるよう理由を入力してください...';

  @override
  String get adminHomeMsgApproved => '物件を承認しました';

  @override
  String get adminHomeMsgRejected => '物件を却下しました';

  @override
  String get adminHomeMsgUpdated => '物件を更新しました';

  @override
  String get adminHomeMsgFailed => '操作に失敗しました';

  @override
  String get adminReelEyebrow => 'モデレーション';

  @override
  String get adminReelTitle => 'リール';

  @override
  String get adminReelTabPending => '承認待ち';

  @override
  String get adminReelTabHidden => '非表示';

  @override
  String get adminReelTabPublished => '公開中';

  @override
  String get adminReelEmpty => 'リールはありません';

  @override
  String get adminReelStatsTitle => '運用指標(30日間)';

  @override
  String get adminReelStatReels => 'リール';

  @override
  String get adminReelStatPending => '承認待ち';

  @override
  String get adminReelStatViews => '視聴回数';

  @override
  String get adminReelStatLikes => 'いいね';

  @override
  String get adminReelStatComments => 'コメント';

  @override
  String get adminReelStatStorage => 'ストレージ';

  @override
  String get adminReelStatFailures => '処理エラー';

  @override
  String get adminReelNoCaption => '(キャプションなし)';

  @override
  String adminReelReportCount(Object count) {
    return '$count件の通報';
  }

  @override
  String adminReelRejectReason(Object reason) {
    return '理由:$reason';
  }

  @override
  String get adminReelApprove => '承認';

  @override
  String get adminReelHide => '非表示';

  @override
  String get adminReelReject => '却下';

  @override
  String get adminReelRejectTitle => 'リールを却下';

  @override
  String get adminReelReasonLabel => '理由 *';

  @override
  String get adminReelReasonHint => '例:関連性のない内容';

  @override
  String get adminReelApproved => '承認しました — リールが公開されました';

  @override
  String get adminReelRejected => 'リールを却下しました';

  @override
  String get adminReelHidden => 'リールを非表示にしました';

  @override
  String adminReelActionFailed(Object error) {
    return '操作に失敗しました:$error';
  }

  @override
  String get adminVerifTitle => '確認キュー';

  @override
  String get adminVerifEmpty => 'リクエストはありません';

  @override
  String adminVerifLoadError(Object error) {
    return '読み込めませんでした:$error';
  }

  @override
  String adminVerifRateDialogTitle(Object title) {
    return '確認スターを付与 — $title';
  }

  @override
  String get adminVerifProperty => '物件';

  @override
  String adminVerifStarsLabel(Object count) {
    return '$countスター';
  }

  @override
  String get adminVerifConfirm => '確定';

  @override
  String get adminVerifRatedToast => '確認スターを付与しました。';

  @override
  String adminVerifError(Object error) {
    return 'エラー:$error';
  }

  @override
  String adminVerifSubtitle(Object status, Object date) {
    return 'ステータス:$status · 申請日:$date';
  }

  @override
  String get adminVerifVerifyButton => '確認';

  @override
  String get hActionItemsHeader => '要対応';

  @override
  String get hActionItemsOverdueInvoices => '未払い請求書';

  @override
  String get hActionItemsExpiringContracts => '満了予定の契約';

  @override
  String get hActionItemsOverdueKhaiBao => '一時居住届 未提出';

  @override
  String get hActionItemsMaintenanceRooms => 'メンテナンス中の部屋';

  @override
  String get hActionItemsZaloFailed => 'Zalo督促を作成できませんでした';

  @override
  String hActionItemsInvoiceDue(Object dueDate, Object amount) {
    return '期限 $dueDate・残 $amount円';
  }

  @override
  String get hActionItemsRemindZalo => 'Zaloで督促';

  @override
  String hActionItemsContractRoom(Object contractId, Object roomId) {
    return '契約 #$contractId・部屋 $roomId';
  }

  @override
  String hActionItemsContractExpiry(Object endDate, Object rent) {
    return '満了 $endDate・$rent円/月';
  }

  @override
  String hActionItemsTenant(Object tenantId) {
    return '入居者 #$tenantId';
  }

  @override
  String hActionItemsCheckIn(Object checkInAt) {
    return 'チェックイン $checkInAt';
  }

  @override
  String hActionItemsMaintenanceSince(Object startDate) {
    return '$startDateから';
  }

  @override
  String get hActionItemsMaintenanceActive => 'メンテナンス中';

  @override
  String get hAnalyticsFilterSelectPeriod => '期間を選択';

  @override
  String get hAnalyticsFilterTitle => 'フィルタ';

  @override
  String get hAnalyticsFilterActive => 'フィルタ中';

  @override
  String get hAnalyticsFilterBuilding => '建物';

  @override
  String get hAnalyticsFilterSource => '収益ソース';

  @override
  String get hAnalyticsFilterRoomType => '部屋タイプ';

  @override
  String get hAnalyticsFilterPeriod => '期間';

  @override
  String get hAnalyticsFilterClearPeriod => '期間をクリア';

  @override
  String get hAnalyticsFilterManageSources => 'ソースを管理';

  @override
  String get hAnalyticsFilterReset => 'リセット';

  @override
  String get hAnalyticsFilterApply => '適用';

  @override
  String get hCreateContractTitle => '下書き契約を作成';

  @override
  String get hCreateContractViewRequestEyebrow => '内見依頼';

  @override
  String get hCreateContractGuest => 'ゲスト';

  @override
  String get hCreateContractRequestCode => '依頼コード';

  @override
  String get hCreateContractWhatHappens => '処理内容';

  @override
  String get hCreateContractWhatHappensBody =>
      '• 内見依頼 → ステータス「承認済み」\n• 仮入居者を作成(同一電話番号の既存入居者は再利用)\n• 下書き契約(ソース=マーケットプレイス)が入居者と対象部屋を紐付け\n• 有効化前に開始日・敷金などを編集可能';

  @override
  String get hCreateContractConfirm => '下書き契約の作成を確認';

  @override
  String get hCreateContractCreating => '作成中…';

  @override
  String get hCreateContractError => 'エラー';

  @override
  String hCreateContractCreatedDraft(Object id, Object suffix) {
    return '下書き契約 #$id を作成しました $suffix';
  }

  @override
  String get hCreateContractPlaceholderTenant => '(仮入居者)';

  @override
  String get hPublishTitle => 'マーケットプレイスに公開';

  @override
  String get hPublishListingType => '掲載種別';

  @override
  String get hPublishTitleLabel => 'タイトル（任意）';

  @override
  String get hPublishDescLabel => '説明（任意）';

  @override
  String get hPublishDescHint => '設備、立地、備考など…';

  @override
  String get hPublishPriceLabel => '表示価格（円、空欄の場合はbase_priceを使用）';

  @override
  String get hPublishPriceHint => '例：3500000';

  @override
  String get hPublishSubmitting => '公開中…';

  @override
  String get hPublishSubmit => '掲載を確定';

  @override
  String get hPublishHelp => '物件は一般公開前に管理者の承認が必要です。同期画面からいつでも再度非公開にできます。';

  @override
  String get hPublishSyncSuccess => '物件をマーケットプレイスへ同期しました';

  @override
  String get hPublishError => 'エラー';

  @override
  String get hPublishTypeBoardingHouse => '下宿';

  @override
  String get hPublishTypeHomestay => 'ホームステイ';

  @override
  String get hPublishTypeApartment => 'マンション';

  @override
  String get hSyncTitle => 'マーケットプレイス同期';

  @override
  String get hSyncHideListingTitle => '物件を非表示';

  @override
  String hSyncHideConfirm(Object roomCode) {
    return '部屋 $roomCode をマーケットプレイスから非表示にしますか？物件は「非公開」の状態に切り替わり、削除はされません。後ほど再公開できます。';
  }

  @override
  String get hSyncHideAction => '物件を非表示';

  @override
  String get hSyncHidden => '物件を非公開にしました';

  @override
  String get hSyncError => 'エラー';

  @override
  String get hSyncEmptyTitle => '同期する部屋はまだありません';

  @override
  String get hSyncEmptySubtitle => '部屋を追加してマーケットプレイスとの同期を開始しましょう。';

  @override
  String hSyncMarketplaceStatus(Object status) {
    return 'マーケットプレイスの状態：$status';
  }

  @override
  String hSyncLastSynced(Object time) {
    return '最終同期：$time';
  }

  @override
  String get hSyncPublish => 'マーケットプレイスに公開';

  @override
  String get hSyncResync => '再同期';

  @override
  String get hSyncHide => '非表示';

  @override
  String get opDiscloseTitle => '共有アカウントのお知らせ';

  @override
  String get opDiscloseBody => '共有ビジネスアカウントを使用しています。以下にご注意ください:';

  @override
  String get opDisclosePointAudit => 'すべての操作は共有アカウント名義で監査ログに記録されます。';

  @override
  String get opDisclosePointPassword => 'パスワード変更は貴社の責任です。異常なログインの通知はありません。';

  @override
  String get opDisclosePointRbac => 'ビジネス内の個別権限(RBAC v2)は今後のリリースで利用可能になります。';

  @override
  String get opDiscloseAcknowledge => '了解しました';

  @override
  String opDiscloseAckError(Object error) {
    return '記録中にエラー: $error';
  }

  @override
  String get opInviteTitle => '委任招待';

  @override
  String get opInviteEyebrow => 'オペレーター・招待';

  @override
  String get opInviteEmptyTitle => '招待はありません';

  @override
  String get opInviteEmptySubtitle => 'オーナーから招待されるとここに表示されます。';

  @override
  String get opInviteOwnerFallback => 'オーナー';

  @override
  String opInviteSentDate(Object date) {
    return '送信日: $date';
  }

  @override
  String get opInviteStatusPending => '確認待ち';

  @override
  String get opInviteReject => '辞退';

  @override
  String get opInviteAccept => '承諾';

  @override
  String get opInviteAcceptSuccess => '委任を承諾しました';

  @override
  String get opInviteAcceptError => '承諾できません。もう一度お試しください。';

  @override
  String get opInviteRejectSuccess => '招待を辞退しました';

  @override
  String get opInviteRoleFull => '権限: 全操作';

  @override
  String get opInviteRoleAccountant => '権限: 経理';

  @override
  String get opInviteRoleViewer => '権限: 閲覧のみ';

  @override
  String opInviteRoleOther(Object preset) {
    return '権限: $preset';
  }

  @override
  String get opInviteRoleUnknown => '不明';

  @override
  String get tenantReportSubmittedTitle => '報告を送信しました';

  @override
  String get tenantReportSubmittedHeadline => 'ご報告を受け付けました';

  @override
  String get tenantReportSubmittedSubtitle => '確認後、24時間以内にご連絡いたします。';

  @override
  String get tenantReportBackHome => 'ホームに戻る';

  @override
  String get tenantReportTitle => '代理人を報告';

  @override
  String get tenantReportEyebrow => '入居者 · 報告';

  @override
  String get tenantReportDisclosure =>
      '家主の代理人を名乗る人物に心当たりがない場合は、すぐに報告してください。情報は秘密として扱われます。';

  @override
  String get tenantReportReasonLabel => '理由';

  @override
  String get tenantReportReasonUnknownPerson => '面識のない代理人である';

  @override
  String get tenantReportReasonDifferentInfo => '集金に来た人物の情報が一致しない';

  @override
  String get tenantReportReasonNoNotice => '家主から通知を受けていない';

  @override
  String get tenantReportReasonOther => 'その他の理由';

  @override
  String get tenantReportDetailLabel => '追加情報（任意）';

  @override
  String get tenantReportDetailHint => '事案の詳細をご記入ください…';

  @override
  String get tenantReportSubmitButton => '報告を送信';

  @override
  String tenantReportSubmitFailed(Object error) {
    return '報告の送信に失敗しました：$error';
  }

  @override
  String get auditTitle => '操作履歴';

  @override
  String auditRepresentative(Object name) {
    return '代理 · $name';
  }

  @override
  String get auditOwnerFallback => 'オーナー';

  @override
  String get auditPeriodToday => '今日';

  @override
  String get auditPeriodWeek => '今週';

  @override
  String get auditPeriodMonth => '今月';

  @override
  String get auditLoadError => 'データを読み込めませんでした';

  @override
  String get auditRetry => '再試行';

  @override
  String get auditEmptyTitle => '操作履歴はまだありません';

  @override
  String get auditEmptySubtitle => 'オペレーターの操作履歴がここに表示されます。';

  @override
  String get auditTlOperator => 'オペレーター';

  @override
  String get auditTlOwner => 'オーナー';

  @override
  String get auditTlAction => '操作';

  @override
  String get auditTlJustNow => 'たった今';

  @override
  String auditTlMinutesAgo(Object minutes) {
    return '$minutes分前';
  }

  @override
  String auditTlHoursAgo(Object hours) {
    return '$hours時間前';
  }

  @override
  String auditTlDaysAgo(Object days) {
    return '$days日前';
  }

  @override
  String get forgotValidateEmail => 'メールアドレスを入力してください';

  @override
  String get forgotDialogEyebrow => '復旧';

  @override
  String get forgotDialogTitle => '仮パスワード';

  @override
  String get forgotDialogBody =>
      'アカウントのパスワードをリセットしました。以下の仮パスワードでログインし、すぐに変更してください:';

  @override
  String get forgotCopied => 'コピーしました';

  @override
  String get forgotGotIt => '了解';

  @override
  String forgotError(Object error) {
    return 'エラー:$error';
  }

  @override
  String get forgotAppBarEyebrow => 'サポート';

  @override
  String get forgotTitle => 'パスワードを忘れた方';

  @override
  String get forgotIntro =>
      'アカウントのメールアドレスを入力してください。仮パスワードを発行しますので、ログイン後すぐに変更してください。';

  @override
  String get forgotEmailHint => 'you@example.com';

  @override
  String get forgotSubmit => '仮パスワードを発行';

  @override
  String get guestGateTitle => '続行するにはログイン';

  @override
  String get guestGateBody => '物件保存、オーナー連絡、内見予約、物件掲載、コミュニティ参加にはログインが必要です。';

  @override
  String get guestGateLoginRegister => 'ログイン / 新規登録';

  @override
  String get guestGateLater => '後で';

  @override
  String get guestGateAccount => 'アカウント';

  @override
  String get hBatchRemindTitle => '一括滞納督促';

  @override
  String hBatchRemindSummary(Object count, Object total) {
    return '督促対象 $count部屋・合計 $total';
  }

  @override
  String get hBatchRemindHint => '「督促」をタップしてZaloを開き、各部屋に督促を送信します。';

  @override
  String get hBatchRemindEmpty => '督促が必要な部屋はありません 🎉';

  @override
  String hBatchRemindOverdue(Object amount, Object days) {
    return '滞納 $amount・$days日経過';
  }

  @override
  String get hBatchRemindDone => '督促済み';

  @override
  String get hBatchRemindRemind => '督促';

  @override
  String get hBatchRemindReminding => '督促中…';

  @override
  String hBatchRemindRemindAll(Object count) {
    return 'Zaloで一括督促($count)';
  }

  @override
  String get hCreditNoteInvalidAmount => '無効な金額です';

  @override
  String get hCreditNoteCreated => 'クレジットノートを作成しました';

  @override
  String get hCreditNoteFailed => '作成に失敗しました';

  @override
  String get hCreditNoteTitle => 'クレジットノート作成';

  @override
  String get hCreditNoteDescription =>
      'クレジットノートは支払い済み請求書への正式な調整です。元の請求書は変更されません。';

  @override
  String get hCreditNoteAmountLabel => '調整金額(JPY)*';

  @override
  String get hCreditNoteIssuedDateLabel => '発行日';

  @override
  String get hCreditNoteReasonLabel => '理由';

  @override
  String get hCreditNoteSubmit => 'クレジットノートを作成';

  @override
  String get hInvListTitle => '請求書';

  @override
  String get hInvListBatchCreate => '一括作成';

  @override
  String get hInvListFilterAll => 'すべて';

  @override
  String get hInvListStatusDraft => '下書き';

  @override
  String get hInvListStatusSent => '送信済み';

  @override
  String get hInvListStatusPaid => '支払済み';

  @override
  String get hInvListAllMonths => 'すべての月';

  @override
  String get hInvListEmpty => '請求書はまだありません';

  @override
  String hInvListCreatedCount(Object count) {
    return '$count件の請求書を作成しました';
  }

  @override
  String hInvListPeriod(Object start, Object end) {
    return '期間 $start → $end';
  }

  @override
  String get hInvPayTitle => '入金を記録';

  @override
  String get hInvPayRemaining => '残額：';

  @override
  String get hInvPayAmountLabel => '金額（円） *';

  @override
  String get hInvPayMethodLabel => '方法';

  @override
  String get hInvPayMethodCash => '現金';

  @override
  String get hInvPayMethodBank => '銀行振込';

  @override
  String get hInvPayMethodOther => 'その他';

  @override
  String get hInvPayNoteLabel => 'メモ';

  @override
  String get hInvPaySubmit => '記録';

  @override
  String get hInvPayInvalidAmount => '金額が無効です';

  @override
  String get hInvPayRecordFailed => '入金の記録に失敗しました';

  @override
  String get hMeterOpenFromRoomHint => '部屋の詳細画面から入力してください';

  @override
  String hMeterTitleRoom(Object code) {
    return '検針 • $code';
  }

  @override
  String get hMeterTitle => '電気・水道の検針';

  @override
  String get hMeterAddTooltip => '追加';

  @override
  String get hMeterEmpty => '検針データはまだありません';

  @override
  String hMeterUsageLine(Object kwh, Object water) {
    return '電気：$kwh kWh • 水道：$water m³';
  }

  @override
  String get hMeterFormTitle => '検針値を入力';

  @override
  String get hMeterReadingDate => '検針日';

  @override
  String get hMeterElectricity => '電気（kWh）';

  @override
  String get hMeterWater => '水道（m³）';

  @override
  String get hMeterSave => '検針値を保存';

  @override
  String get hMeterSaveFailed => '保存に失敗しました';

  @override
  String get hOccReportOccupancyRate => '稼働率';

  @override
  String hOccReportRoomsCount(Object count) {
    return '$count部屋';
  }

  @override
  String get hOccReportByRoom => '部屋別';

  @override
  String get hOccReportNoData => 'データはまだありません';

  @override
  String get hRevReportExportFailed => 'CSVのエクスポートに失敗しました';

  @override
  String hRevReportInvoiceSubject(Object month) {
    return '請求書 $month';
  }

  @override
  String get hRevReportTotalRevenue => '売上合計';

  @override
  String get hRevReportGrossRevenue => '総売上';

  @override
  String get hRevReportNetRevenue => '純売上';

  @override
  String get hRevReportNoData => 'データはまだありません';

  @override
  String get hRevReportViewNewStats => '新しい売上分析を表示';

  @override
  String get hRevReportExporting => 'エクスポート中...';

  @override
  String get hRevReportExportCsv => '今月の請求書CSVをエクスポート';

  @override
  String get notifInbox => '受信箱';

  @override
  String get notifMarkAllRead => 'すべて既読にする';

  @override
  String get notifEmpty => '通知はまだありません';

  @override
  String get notifContentGone => 'コンテンツは存在しません';

  @override
  String get notifJustNow => 'たった今';

  @override
  String notifMinutesAgo(Object count) {
    return '$count分前';
  }

  @override
  String notifHoursAgo(Object count) {
    return '$count時間前';
  }

  @override
  String notifDaysAgo(Object count) {
    return '$count日前';
  }

  @override
  String get planErrTitle => 'データの誤りを報告';

  @override
  String get planErrReasonLabel => '理由(10文字以上)';

  @override
  String get planErrReasonHint => '例: このゾーンは実際には住宅地であり、緑地ではありません';

  @override
  String get planErrAttachImage => '写真を添付(任意)';

  @override
  String get planErrImageAttached => '写真を添付しました';

  @override
  String get planErrSubmit => '通報を送信';

  @override
  String get planErrSuccessMsg => '通報を送信しました。ありがとうございます!';

  @override
  String get planErrMinLength => '理由は10文字以上で入力してください';

  @override
  String get planErrUploading => '写真をアップロード中...';

  @override
  String get planErrImageTooLarge => '写真が大きすぎます(最大5MB)';

  @override
  String get planErrRemoveImage => '写真を削除';

  @override
  String planErrParcelId(Object id) {
    return '区画ID: $id';
  }

  @override
  String planErrUploadFailed(Object error) {
    return '写真のアップロードに失敗しました: $error';
  }

  @override
  String planErrSubmitFailed(Object error) {
    return '送信に失敗しました: $error';
  }

  @override
  String get planProvSelectHint => '都道府県・住所を選択';

  @override
  String get planProvTitle => '都道府県選択・住所検索';

  @override
  String get planProvSearchHint => '都道府県、住所、通り、場所...';

  @override
  String get planProvNoResults => '該当する結果がありません';

  @override
  String get planProvEmptyPrompt => '都道府県名または住所を入力してください';

  @override
  String get planProvSectionProvince => '都道府県・市';

  @override
  String get planProvSectionAddress => '住所';

  @override
  String get planProvHasOverlay => '2030年都市計画のオーバーレイあり';

  @override
  String get planProvNoOverlay => '住所のみ — オーバーレイはまだありません';

  @override
  String get planWarnTitle => '情報・都市計画';

  @override
  String get planWarnReport => '情報に誤りがあれば報告';

  @override
  String get planWarnOk => '了解';

  @override
  String planWarnLoadError(Object error) {
    return '読み込めませんでした: $error';
  }

  @override
  String get planWarnNotFound => 'この場所の都市計画情報は見つかりませんでした。';

  @override
  String planWarnRisky(Object zone) {
    return 'このエリアは土地利用計画($zone)の影響を受ける可能性があります。掲載は可能ですが慎重にご検討ください。';
  }

  @override
  String get planWarnSuitable => 'このエリアは掲載に適しています。';

  @override
  String get planWarnZoneLabel => 'ゾーン';

  @override
  String get planWarnAreaLabel => '面積';

  @override
  String get planWarnDistrictLabel => '区・市';

  @override
  String get hDebtAgingTitle => '滞納';

  @override
  String get hDebtAgingEmptyTitle => '滞納データはまだありません';

  @override
  String get hDebtAgingTotal => '滞納合計';

  @override
  String get hDebtAgingByBucket => '経過日数別';

  @override
  String hDebtAgingNeedsReminder(Object count) {
    return '督促が必要($count)';
  }

  @override
  String hDebtAgingBucketDays(Object days) {
    return '区分 $days日';
  }

  @override
  String hDebtAgingInvoiceCount(Object count) {
    return '請求書 $count件';
  }

  @override
  String hDebtAgingOverdue(Object days, Object phone) {
    return '$days日経過・$phone';
  }

  @override
  String get ctrFilterTitle => '施工業者を絞り込む';

  @override
  String get ctrFilterService => '業種';

  @override
  String get ctrFilterProvince => 'エリア';

  @override
  String get ctrFilterSort => '並び替え';

  @override
  String get ctrFilterSortHelper => '「おすすめ」はシステム順:注目 · Proプラン · 認証済み · 評価の順です。';

  @override
  String get ctrFilterAllServices => '全業種';

  @override
  String get ctrFilterAllProvinces => '全国';

  @override
  String get ctrFilterProvinceUnavailable => '都道府県一覧を読み込めませんでした — 後ほどお試しください。';

  @override
  String get ctrFilterSortRecommend => 'おすすめ順';

  @override
  String get ctrFilterSortRating => '評価の高い順';

  @override
  String get ctrFilterSortReviews => 'レビュー数順';

  @override
  String get ctrFilterApply => '適用';

  @override
  String get ctrFilterReset => 'クリア';

  @override
  String get ctrListTitleAll => '施工業者';

  @override
  String get ctrListFilterTooltip => '施工業者を絞り込む';

  @override
  String ctrListResultCount(int count) {
    return '施工業者 $count社';
  }

  @override
  String get ctrListEmptyWidenFilter => '条件を広げる';

  @override
  String get homeConstructionFilterTooltip => '施工業者をフィルター';

  @override
  String get onboardingSkip => 'スキップ';

  @override
  String get onboardingNext => '次へ';

  @override
  String get onboardingStart => 'はじめる';

  @override
  String get onboardingHeroTitle => 'Ancu365へようこそ';

  @override
  String get onboardingHeroSubtitle => 'ひとつのアプリで2つの世界 — 不動産と建築。';

  @override
  String get onboardingHeroCardReTitle => '不動産';

  @override
  String get onboardingHeroCardReDesc => '賃貸、掲載、物件管理';

  @override
  String get onboardingHeroCardBuildTitle => '建築';

  @override
  String get onboardingHeroCardBuildDesc => '設計、施工、内装、見積もり';

  @override
  String get onboardingReTitle => '指先ひとつで不動産';

  @override
  String get onboardingReSubtitle => '物件探し、掲載、管理 — すべて1つの場所で。';

  @override
  String get onboardingReSearch => '物件を探す';

  @override
  String get onboardingReListings => '賃貸物件を見る';

  @override
  String get onboardingRePost => '賃貸掲載';

  @override
  String get onboardingReBooking => '内見予約';

  @override
  String get onboardingReRooms => '部屋・下宿';

  @override
  String get onboardingReManage => '賃貸物件管理';

  @override
  String get onboardingBuildTitle => 'アイデアから完成まで建てる';

  @override
  String get onboardingBuildSubtitle => 'アイデア、業者、見積もりをすばやく繋ぐ。';

  @override
  String get onboardingBuildDesign => '設計';

  @override
  String get onboardingBuildInterior => '内装';

  @override
  String get onboardingBuildConstruct => '施工';

  @override
  String get onboardingBuildGallery => '住宅デザイン';

  @override
  String get onboardingBuildKnowledge => '建築のヒント';

  @override
  String get onboardingBuildRfq => '見積もり依頼';

  @override
  String get onboardingBuildCaption => '業者ディレクトリ・ランキング付き';

  @override
  String get leadSheetTitle => '情報を残していただければ折り返しご連絡します';

  @override
  String get leadSheetSubtitle => '氏名と電話番号だけでOK、ログイン不要です。';

  @override
  String get leadFieldName => '氏名';

  @override
  String get leadFieldPhone => '電話番号';

  @override
  String get leadFieldNote => '備考(任意)';

  @override
  String get leadSubmit => '送信';

  @override
  String get leadValidation => '氏名と有効な電話番号を入力してください。';

  @override
  String get leadSendError => '送信できませんでした。もう一度お試しください。';

  @override
  String get leadSuccessTitle => '受付けました!';

  @override
  String get leadSuccessBody => 'まもなくご連絡いたします。';

  @override
  String get leadClose => '閉じる';

  @override
  String get guestGateLeaveContact => '電話番号を残す、折り返しご連絡';

  @override
  String get adminLeadsTitle => '折り返し連絡リード';

  @override
  String get adminLeadsEmpty => 'まだリードはありません。';

  @override
  String get hubGuest => 'ゲスト';

  @override
  String get hubSearchHint => 'キーワードを入力...';

  @override
  String get hubBannerTitle => 'Ancu365 — 住まいをすばやく、建築をかんたんに';

  @override
  String get hubBannerSubtitle => '不動産 · デザイン · 施工 · インテリア';

  @override
  String get hubNeedTitle => '探しているもの';

  @override
  String get hubNeedSubtitle => '賃貸・購入・売却掲載';

  @override
  String get hubHaveTitle => '貸したい物件があります';

  @override
  String get hubHaveSubtitle => '掲載して今日中に入居者を見つけましょう';

  @override
  String get demandChooserTitle => '何を投稿しますか?';

  @override
  String get demandChooserHave => '物件を所有している';

  @override
  String get demandChooserNeed => '物件を探している';

  @override
  String get demandChooserPostRent => '賃貸物件を掲載';

  @override
  String get demandChooserPostSale => '売却物件を掲載';

  @override
  String get demandChooserNeedRent => '賃貸希望';

  @override
  String get demandChooserNeedBuy => '購入希望';

  @override
  String get demandChooserHaveHint => '住所・写真・価格を含む実物件を投稿します。';

  @override
  String get demandChooserNeedHint => '探している条件を伝えるだけ。写真不要、30秒で完了。';

  @override
  String get demandFormTitleRent => '賃貸希望';

  @override
  String get demandFormTitleBuy => '購入希望';

  @override
  String get demandSecArea => '希望エリア';

  @override
  String get demandSecType => '物件種別';

  @override
  String get demandSecBudget => '予算';

  @override
  String get demandSecMore => '追加情報(任意)';

  @override
  String get demandProvinceHint => '都道府県を選択';

  @override
  String get demandBudgetFrom => '下限';

  @override
  String get demandBudgetTo => '上限';

  @override
  String get demandBudgetUnitRent => '万円/月';

  @override
  String get demandBudgetUnitBuy => '億円';

  @override
  String get demandAreaMin => '最低面積(㎡)';

  @override
  String get demandBedroomsMin => '最低寝室数';

  @override
  String get demandMoveIn => '入居日';

  @override
  String get demandDuration => '賃貸期間(ヶ月)';

  @override
  String get demandOccupants => '入居人数';

  @override
  String get demandPayment => '支払い方法';

  @override
  String get demandPaymentCash => '現金';

  @override
  String get demandPaymentLoan => 'ローン利用';

  @override
  String get demandPurpose => '目的';

  @override
  String get demandPurposeLive => '居住用';

  @override
  String get demandPurposeInvest => '投資';

  @override
  String get demandNeeds => '必須条件';

  @override
  String get demandNeedParking => '駐車場';

  @override
  String get demandNeedFreeHours => '門限なし';

  @override
  String get demandNeedAircon => 'エアコン';

  @override
  String get demandNeedPrivate => '大家と共有しない';

  @override
  String get demandNeedPet => 'ペット可';

  @override
  String get demandNeedBalcony => 'バルコニー';

  @override
  String get demandNote => 'その他';

  @override
  String get demandNoteHint => '例:学校の近く、低層階希望など…';

  @override
  String get demandSubmit => '依頼を投稿';

  @override
  String get demandSubmitted => '投稿しました。30日間有効です。';

  @override
  String get demandListTitle => '依頼一覧';

  @override
  String get demandTabAll => 'すべて';

  @override
  String get demandTabRent => '賃貸希望';

  @override
  String get demandTabBuy => '購入希望';

  @override
  String get demandTabMine => 'マイ依頼';

  @override
  String get demandEmpty => '依頼はまだありません。';

  @override
  String get demandEmptyMine => '依頼を投稿していません。';

  @override
  String get demandExpired => '期限切れ';

  @override
  String get demandClosed => '終了';

  @override
  String get demandActionClose => '終了';

  @override
  String get demandActionExtend => '30日間延長';

  @override
  String get demandContact => 'メッセージ';

  @override
  String demandDaysLeft(int days) {
    return '残り$days日';
  }

  @override
  String get demandNeedLogin => '依頼を投稿するにはログインしてください';

  @override
  String get demandPickTypeFirst => '物件種別を1つ以上選択してください';

  @override
  String get svcCatalogTitle => 'ホームサービス';

  @override
  String get svcGroupQuick => '便利屋・クイックサービス';

  @override
  String get svcGroupBuild => '設計・建築';

  @override
  String get svcQuickHint => 'リクエストを送信いただければ、折り返しご連絡し作業員を手配します。';

  @override
  String svcBookNow(String serviceName) {
    return 'サービスを予約 · $serviceName';
  }

  @override
  String get svcBookedBody => '確認と作業員の手配のため、折り返しお電話いたします。';

  @override
  String get svcReqTitle => 'サービスリクエスト';

  @override
  String get svcReqEmpty => 'まだリクエストがありません。';

  @override
  String get svcReqFilterAll => 'すべて';

  @override
  String get svcReqFilterNew => '新規';

  @override
  String get svcReqFilterDoing => '対応中';

  @override
  String get svcReqFilterDone => '完了';

  @override
  String get svcReqSearchHint => '電話番号または名前で検索';

  @override
  String get svcReqCall => '電話';

  @override
  String get svcReqSchedule => 'スケジュール';

  @override
  String get svcReqNote => '管理者メモ';

  @override
  String get svcReqSave => '保存';

  @override
  String get svcReqSaved => '保存しました';

  @override
  String get svcStatusNew => '新規';

  @override
  String get svcStatusContacted => '連絡済み';

  @override
  String get svcStatusScheduled => '予約済み';

  @override
  String get svcStatusDone => '完了';

  @override
  String get svcStatusCancelled => 'キャンセル';

  @override
  String get svcStatusSpam => 'スパム';

  @override
  String get hubActionTrade => '売買・賃貸';

  @override
  String get hubActionPost => 'リクエストを投稿';

  @override
  String get hubActionPlanning => '情報・都市計画';

  @override
  String get hubActionServices => 'サービス';

  @override
  String get hubRowBrokers => 'トップ仲介担当者';

  @override
  String get hubRowOwners => '直接掲載するオーナー';

  @override
  String get hubActionLease => 'テナント募集';

  @override
  String get hubActionRent => '賃貸希望';

  @override
  String get hubActionSell => '売却';

  @override
  String get hubActionBuy => '購入希望';

  @override
  String get hubFeaturedUnits => 'おすすめの事業者';

  @override
  String get hubServiceUnits => 'サービス提供者';

  @override
  String get hubHighlights => 'ハイライト';

  @override
  String get hubViewAll => 'すべて表示';

  @override
  String get hubNotifications => '通知';

  @override
  String get shellNavHome => 'ホーム';

  @override
  String get hubFeaturedBrokers => 'おすすめの仲介担当者';

  @override
  String get brokerProfileTitle => '担当者プロフィール';

  @override
  String get brokerNotFound => 'プロフィールが見つかりません。';

  @override
  String get brokerListings => '掲載中物件';

  @override
  String get brokerNoListings => '掲載中の物件はまだありません。';

  @override
  String brokerListingCount(int count) {
    return '掲載中物件 $count件';
  }

  @override
  String brokerReviewCount(int count) {
    return 'レビュー $count件';
  }

  @override
  String get brokerStatListings => '物件数';

  @override
  String get brokerStatAreas => '対応エリア';

  @override
  String get brokerStatReviews => 'レビュー';

  @override
  String get brokerStatYears => '経験年数';

  @override
  String get brokerMapTitle => '物件マップ';

  @override
  String get brokerReviewsTitle => 'お客様レビュー';

  @override
  String get mapLegendTitle => '凡例';

  @override
  String get mapLegendSale => '売買';

  @override
  String get mapLegendStayLong => '賃貸・長期';

  @override
  String get mapLegendStayShort => '賃貸・短期';

  @override
  String get mapLegendBusiness => '賃貸・事業用';

  @override
  String get postGroupStep => '物件カテゴリ';

  @override
  String get postTypeStep => '物件種別';

  @override
  String get postGroupStayLong => '長期滞在';

  @override
  String get postGroupStayShort => '短期滞在';

  @override
  String get postGroupBusiness => '事業用';

  @override
  String get postPickGroupFirst => 'まずグループを選択してください';

  @override
  String get brokerShare => 'プロフィールを共有';

  @override
  String get brokerShareCopied => 'プロフィールリンクをコピーしました';

  @override
  String get pfBasicInfo => '基本情報';

  @override
  String get pfBasicHelper => 'お客様が最初に目にする名前と説明。';

  @override
  String get pfContact => '連絡先';

  @override
  String get pfContactHelper => 'お客様はプロフィールから直接連絡できます。';

  @override
  String get pfCapacity => 'キャパシティ';

  @override
  String get pfCapacityHelper => 'お客様はこの情報から対応可能か判断します。';

  @override
  String get pfDocs => '書類・認証';

  @override
  String get pfDocsHelper => '書類が承認されたプロフィールはバッジが付与され、上位に表示されます。';

  @override
  String get pfNameHint => '例: ミンファット建設';

  @override
  String get pfIntroHint => '業務内容、対応エリア、強みは?';

  @override
  String get pfPhoneHint => '09xx xxx xxx';

  @override
  String get pfPhoneInvalid => '無効な電話番号';

  @override
  String get pfWebHint => 'facebook.com/... またはウェブサイト';

  @override
  String get pfCertHint => '実務資格をお持ちの場合は入力してください';

  @override
  String get pfUnitScale => '会社規模';

  @override
  String get pfChangeCover => 'カバー画像を変更';

  @override
  String pfPickPrefix(String field) {
    return '$fieldを選択';
  }

  @override
  String pfEstablishedYear(String year) {
    return '設立: $year年';
  }

  @override
  String get pfEstVerified => '書類により認証済み';

  @override
  String get pfEstPending => '審査中';

  @override
  String get pfEstPendingHint => '管理者が書類を確認中です';

  @override
  String get pfEstRejected => '未承認';

  @override
  String get pfEstRejectedHint => 'タップして理由を確認し、再提出';

  @override
  String get pfEstNone => '設立年が未認証';

  @override
  String get pfEstNoneHint => 'タップして営業許可証を提出';

  @override
  String get pfDiscardTitle => '変更を破棄しますか?';

  @override
  String get pfDiscardBody => 'プロフィールを編集しましたが保存されていません。離れると変更が失われます。';

  @override
  String get pfKeepEditing => '編集を続ける';

  @override
  String get pfDiscard => '破棄';

  @override
  String get pfScaleCorporation => '大企業';

  @override
  String get pfScaleMedium => '中規模会社';

  @override
  String get pfScaleSmall => '小規模会社';

  @override
  String get pfScaleCrew => '施工班';

  @override
  String get pfScaleIndividual => '個人業者';

  @override
  String get pfScaleArchitect => '建築家・スタジオ';

  @override
  String get pfScaleSpecialist => '専門業者';

  @override
  String get sellerStep => 'この物件におけるあなたの役割は？';

  @override
  String get sellerStepHelper =>
      '購入希望者が重視する項目です。自己申告であり、Ancu365は書類の確認を行っていません。';

  @override
  String get sellerOwner => 'オーナー本人による投稿';

  @override
  String get sellerOwnerDesc => 'ご自身の物件です';

  @override
  String get sellerBroker => '代理投稿／仲介業者';

  @override
  String get sellerBrokerDesc => 'オーナーの代わりに投稿';

  @override
  String get sellerRequired => '役割を選択してください';

  @override
  String get sellerBadgeOwner => 'オーナー（自己申告）';

  @override
  String get sellerBadgeBroker => '仲介業者（自己申告）';

  @override
  String get hubFeaturedSellers => 'おすすめの販売者';

  @override
  String get brokerMapExpand => '拡大';

  @override
  String get brokerMapHint => 'ピンをタップすると物件が開きます · ドラッグ・ピンチでズーム';

  @override
  String get brokerMapHintShort => 'ピンチまたは +/− でズーム · ピンをタップで物件を開く';

  @override
  String get planningScreenTitle => '情報・都市計画';

  @override
  String get planningCheckAction => '情報・都市計画';

  @override
  String get planningTabShort => '都市計画';

  @override
  String get planningLayerToggle => '2030年土地利用計画レイヤー';

  @override
  String get planningOpacityLabel => '不透明度';

  @override
  String get planningZoneLegendTitle => '都市計画凡例';

  @override
  String get planningZoneLegendEmpty => '拡大してこのエリアの土地種別を確認';

  @override
  String get planningZoneLegendRasterNote => '凡例は都道府県ソース準拠 · 区画をタップで詳細';

  @override
  String get planningZoneLegendOther => 'その他の種別';

  @override
  String get mapClusterTooltip => 'タップしてクラスターを展開';

  @override
  String get mapSearchHint => '場所を検索';

  @override
  String get mapZoomIn => '拡大';

  @override
  String get mapZoomOut => '縮小';

  @override
  String get mapMyLocation => '現在地';

  @override
  String get mapLocationOff => 'この端末では位置情報サービスがオフになっています';

  @override
  String get mapLocationDenied => '位置情報の許可がありません';

  @override
  String get mapLocationOutside => '位置情報が日本国外です';

  @override
  String get mapLocationError => '位置情報を取得できませんでした。後ほどお試しください';

  @override
  String get mapSearchEmpty => '該当する場所が見つかりません';

  @override
  String get mapLegendHelp => '説明';

  @override
  String get mapLegendStayShortDesc => '日単位・数日の賃貸 — 旅行、出張向け。';

  @override
  String get mapLegendStayLongDesc => '月単位以上の賃貸 — 定住向けの日常生活。';

  @override
  String get mapLegendBusinessDesc => '商業、販売、オフィス、店舗向けに貸し出される物件。';

  @override
  String get mapLegendSaleDesc => '長期保有・自己利用のための売買物件。';

  @override
  String get tradeTabBuy => '物件を探す';

  @override
  String get tradeTabSell => '顧客を探す';

  @override
  String get tradeBuyHint => '売却・賃貸中の物件';

  @override
  String get tradeSellHint => '購入・賃貸を希望する方 — 見つけてもらうために投稿しましょう';

  @override
  String get tradeChipAll => 'すべて';

  @override
  String get tradeChipSale => '売却';

  @override
  String get tradeChipShort => '短期滞在';

  @override
  String get tradeShortStaySearchTitle => '時間貸しの空室を探す';

  @override
  String get tradeShortStaySearchSub => '時間 · 一泊 · 日単位 — 料金を見て今すぐ予約';

  @override
  String get tradeChipLong => '長期滞在';

  @override
  String get tradeChipBusiness => '事業用';

  @override
  String get tradeChipNeedBuy => '購入希望';

  @override
  String get tradeChipNeedRent => '賃貸希望';

  @override
  String get tradeSearchHint => 'タイトルまたはエリアで検索';

  @override
  String get tradeFilter => 'フィルター';

  @override
  String get tradeFilterTitle => '検索結果を絞り込む';

  @override
  String get tradePriceRange => '価格帯';

  @override
  String get tradeAreaFrom => '面積（m²以上）';

  @override
  String get tradeBedrooms => '寝室数';

  @override
  String get tradeApply => '適用';

  @override
  String get tradeClear => 'クリア';

  @override
  String get tradeEmptyBuy => '該当する物件がまだありません';

  @override
  String get tradeEmptySell => '該当する需要がまだありません';

  @override
  String get tradeEmptyHint => 'フィルターを外すか、キーワードを変更してお試しください。';

  @override
  String tradeResultCount(int n) {
    return '検索結果 $n件';
  }

  @override
  String get tfTitle => '検索結果を絞り込む';

  @override
  String get tfPrice => '価格帯';

  @override
  String get tfArea => '床面積';

  @override
  String get tfBedrooms => '寝室数';

  @override
  String get tfSort => '並び順';

  @override
  String get tfAny => 'すべて';

  @override
  String get tfAreaUnder => '30 m²未満';

  @override
  String get tfArea3050 => '30 – 50 m²';

  @override
  String get tfArea5080 => '50 – 80 m²';

  @override
  String get tfAreaOver => '80 m²以上';

  @override
  String get tfSortNewest => '新着順';

  @override
  String get tfSortPriceAsc => '価格が安い順';

  @override
  String get tfSortPriceDesc => '価格が高い順';

  @override
  String get tfReset => 'リセット';

  @override
  String tfSeeCount(int n) {
    return '物件$n件を見る';
  }

  @override
  String get tfSeeNone => '該当なし';

  @override
  String get tfCounting => '集計中…';

  @override
  String get tfBillion => '億';

  @override
  String get tfMillion => '万';

  @override
  String get tfNoLimit => '制限なし';

  @override
  String get tfAdvanced => '詳細フィルター';

  @override
  String get tfPropertyType => '物件種別';

  @override
  String get tfDirection => '方位（風水）';

  @override
  String get tfTrust => '信頼度・品質';

  @override
  String get tfTrustedOnly => '信頼できる物件のみ';

  @override
  String get tfMinRating => '最低評価';

  @override
  String get tfMinQuality => '最低品質星数';

  @override
  String tfQualityStar(int n) {
    return '$n星';
  }

  @override
  String get tfSortTrust => '信頼度';

  @override
  String get tfSortRating => '評価が高い順';

  @override
  String get tfDirN => '北向き';

  @override
  String get tfDirNE => '北東向き';

  @override
  String get tfDirE => '東向き';

  @override
  String get tfDirSE => '南東向き';

  @override
  String get tfDirS => '南向き';

  @override
  String get tfDirSW => '南西向き';

  @override
  String get tfDirW => '西向き';

  @override
  String get tfDirNW => '北西向き';

  @override
  String get reelSectionTitle => '注目のリール';

  @override
  String get reelSeeAll => 'すべて見る';

  @override
  String get exploreTradeTitlePlain => '探す ';

  @override
  String get exploreTradeTitleAccent => '売買・賃貸';

  @override
  String get exploreTradeSubtitle => '売買・賃貸のすべての物件を\nクイックフィルタで検索';

  @override
  String get exploreTradeCta => 'すべての物件を見る';

  @override
  String get homeNewsSection => '最新の物件';

  @override
  String get homeNewsEmpty => '物件はまだありません';

  @override
  String get tfArea2 => '検索エリア';

  @override
  String get tfAreaAll => '全エリア';

  @override
  String get tfAreaNear => '現在地周辺';

  @override
  String get tfAreaPlace => '場所';

  @override
  String get tfPlaceHint => '場所を入力：「東京大学の近く」など…';

  @override
  String get tfRadius => '半径';

  @override
  String get tfLocating => '位置情報を取得中…';

  @override
  String get tfLocated => '位置情報取得完了 ✓';

  @override
  String get tfGeoOnlyBasic => 'エリアで絞り込んだ場合、結果は距離順で表示されます。';

  @override
  String get tfNoMatchPlace => '場所が見つかりません';

  @override
  String get filterLocInsecureContext => 'ページがHTTP配信のため、ブラウザが位置情報をブロックしています。';

  @override
  String get profHostSection => '賃貸管理';

  @override
  String get profHostBuildings => '建物・部屋';

  @override
  String get profHostBuildingsSub => '建物、部屋、現在の入居者';

  @override
  String get profHostContracts => '契約';

  @override
  String get profHostContractsSub => '賃貸契約と終了日';

  @override
  String get profHostInvoices => '請求書';

  @override
  String get profHostInvoicesSub => '家賃、光熱費、キャッシュフロー';

  @override
  String get profHostAppointments => '内見リクエスト';

  @override
  String get profHostAppointmentsSub => '内見を承認・スケジュール';

  @override
  String get profHostKyc => 'ホストプロフィール';

  @override
  String get profHostKycSub => '書類、入金口座、本人確認';

  @override
  String get myReqSubtitle => '予約したサービス';

  @override
  String get myReqEmptyHint => '電気工事、水道、清掃が必要ですか?一度予約すれば折り返しご連絡します。';

  @override
  String get myReqEmptyCta => 'サービスを探す';

  @override
  String get myReqStatusContacted => '連絡済み';

  @override
  String get myReqStatusScheduled => '予定済み';

  @override
  String get myReqStatusDone => '完了';

  @override
  String get myReqStatusCancelled => 'キャンセル';

  @override
  String myReqSentAt(String d) {
    return '送信日 $d';
  }

  @override
  String myReqScheduledAt(String d) {
    return '予定日 $d';
  }

  @override
  String get profMessages => 'メッセージ';

  @override
  String get profMessagesSub => 'ホストや売主とチャット';

  @override
  String get profNextViewing => '次の内見';

  @override
  String profNextViewingAt(String d, String t) {
    return '$d · $t';
  }

  @override
  String get saleCall => 'メッセージ';

  @override
  String saleCallNamed(String ten) {
    return '$tenさんにメッセージ';
  }

  @override
  String get saleShareBtn => 'シェア';

  @override
  String get saleQrTitle => 'スキャンして開く';

  @override
  String get saleQrHint => 'お客様にこのコードをスキャンしてもらってください';

  @override
  String get saleAreaCover => '対応エリア';

  @override
  String get saleReviewsShort => 'お客様の声';

  @override
  String get albumSection => 'プロジェクト';

  @override
  String albumUnits(int n) {
    return '$n戸';
  }

  @override
  String get albumEmpty => 'このプロジェクトにはまだ物件がありません';

  @override
  String get albumTitle => 'プロジェクト';

  @override
  String get albumHidden => '非表示';

  @override
  String get albumMine => 'マイプロジェクト';

  @override
  String get albumMineSub => '建物やプロジェクト単位で物件をまとめます';

  @override
  String get albumNew => '新規プロジェクト';

  @override
  String get albumNameLabel => 'プロジェクト名';

  @override
  String get albumNameHint => 'ヴィンホームズ・グランドパーク — S1';

  @override
  String get albumDescLabel => '説明(任意)';

  @override
  String get albumPublicLabel => '公開ページに表示';

  @override
  String get albumPublicHint => '収集中はオフに — お客様には表示されません';

  @override
  String get albumSave => '保存';

  @override
  String get albumDelete => 'プロジェクトを削除';

  @override
  String get albumDeleteAsk => 'このプロジェクトを削除しますか?';

  @override
  String get albumDeleteNote => '物件は残ります — どのプロジェクトにも属さなくなるだけです。';

  @override
  String get albumNoneYet => 'プロジェクトはまだありません';

  @override
  String get albumNoneHint => '同じ建物の部屋をまとめて、お客様が一括で閲覧できるようにします。';

  @override
  String get albumAddListings => '物件を追加';

  @override
  String get albumPickTitle => '物件を選択';

  @override
  String get albumPickEmpty => 'まだ物件がありません';

  @override
  String albumPickSave(int n) {
    return '$n件の物件を追加';
  }

  @override
  String get albumUnitLabel => '部屋ラベル';

  @override
  String get albumUnitHint => '1201号室';

  @override
  String get albumRemove => 'プロジェクトから削除';

  @override
  String get albumSaved => '保存しました';

  @override
  String get albumNeedName => 'プロジェクト名を入力してください';

  @override
  String tfActiveCount(int n) {
    return 'フィルター$n件';
  }

  @override
  String get homeMapPreviewTitle => '近隣の物件';

  @override
  String get homeMapPreviewOpen => 'マップを開く';

  @override
  String get homeMapPreviewEmpty => '座標付きの物件はまだありません';

  @override
  String get homeMapLocate => '現在地へ移動';

  @override
  String get mapLocationInsecure =>
      'ブラウザはHTTPSでのみ位置情報を許可します。https://でサイトを開いてください。';

  @override
  String get mapLocationBlocked =>
      'このサイトでは位置情報がブロックされています。アドレスバー横の鍵アイコン → 位置情報を許可 → 再読み込みしてください。';

  @override
  String get homeMapExpand => '拡大';

  @override
  String get hubMapSection => '取引が活発なエリア';

  @override
  String get shellNavServices => 'サービス';

  @override
  String get cardOnMap => '地図で見る';

  @override
  String get tradeOpenMap => '地図';

  @override
  String get hubGreeting => 'こんにちは、';

  @override
  String get svcGroupDeal => '売買・法務';

  @override
  String get svcGroupDealHint => '査定、名義変更、ローン、物件検査';

  @override
  String get svcGroupDesignBuild => '設計・施工';

  @override
  String get svcGroupDesignBuildHint => '図面から引渡しまで、ターンキー対応可';

  @override
  String get svcGroupRepair => 'クイック修理';

  @override
  String get svcGroupRepairHint => '即日対応の技術者';

  @override
  String get svcGroupHomeCare => '清掃・引越し';

  @override
  String get svcGroupHomeCareHint => '清掃、引越し、時間制サポート';

  @override
  String get svcGroupOther => 'その他のサービス';

  @override
  String svcCount(int n) {
    return 'サービス$n件';
  }

  @override
  String get svcHeroTitle => '必要なことは何でも、誰かが対応します';

  @override
  String get svcHeroSubtitle => 'リクエストを送信 — Ancu365から折り返しご連絡し、作業員を手配します';

  @override
  String get svcSearchHint => '今日は何をお探しですか？';

  @override
  String svcStat(int n, int g) {
    return 'サービス$n件 · グループ$g件';
  }

  @override
  String get svcNoMatch => '該当するサービスがありません';

  @override
  String get svcNoMatchHint => '「電気」や「塗装」など、短いキーワードでお試しください。';

  @override
  String svcGroupCount(int n) {
    return 'グループ$n件';
  }

  @override
  String get loginIdentifier => 'メールアドレスまたは電話番号';

  @override
  String get identifierHint => '09012345678 または you@example.com';

  @override
  String get valIdentifierRequired => 'メールアドレスまたは電話番号を入力してください';

  @override
  String get registerEmailOptional => 'メールアドレス（任意）';

  @override
  String get registerNeedEmailOrPhone => 'メールアドレスまたは電話番号のいずれかを入力してください';

  @override
  String get registerNoEmailWarning =>
      'メールアドレスなしでは、パスワードを忘れた場合にサポートに連絡する必要があります — リセットリンクはメールでのみ送信されます。';

  @override
  String get valPhoneInvalid => '電話番号が正しくありません（例：09012345678）';

  @override
  String get primingBtnEnable => '今すぐ有効にする';

  @override
  String get primingBtnDefer => '後で';

  @override
  String get primingBtnContinue => '続ける';

  @override
  String get primingBtnCancel => 'キャンセル';

  @override
  String get primingBtnClose => '閉じる';

  @override
  String get primingTrustCanDisable => 'いつでもオフにできます';

  @override
  String get primingTrustNoSpam => 'スパムなし — 役立つお知らせのみ';

  @override
  String get primingSoftReaskNotif => '通知を無効にしています。最新情報を受け取るには設定から有効にしてください。';

  @override
  String get primingSoftReaskCamera =>
      'カメラへのアクセスを無効にしています。写真を撮影するには設定から有効にしてください。';

  @override
  String get primingSoftReaskOpenSettings => '設定を開く';

  @override
  String get primingSoftReaskDismiss => '閉じる';

  @override
  String get primingSettingsNotifTitle => '通知';

  @override
  String get primingSettingsCameraTitle => 'カメラ';

  @override
  String get primingSettingsStatusEnabled => '有効';

  @override
  String get primingSettingsStatusDisabled => '無効';

  @override
  String get primingSettingsActionEnable => '有効にする → 設定を開く';

  @override
  String get jp_shikikin => '敷金';

  @override
  String get jp_reikin => '礼金';

  @override
  String get jp_koushinryo => '更新料';

  @override
  String get jp_hoshou => '保証金';

  @override
  String get jp_brokerage => '仲介手数料';

  @override
  String get jp_management_fee => '管理費';

  @override
  String get jp_monthly_rent => '月額家賃';

  @override
  String get jp_shouhizei => '消費税';

  @override
  String get jp_kyouekihi => '共益費';

  @override
  String get jp_layout => '間取り';

  @override
  String get jp_floor_area => '専有面積';

  @override
  String get jp_building_year => '築年数';

  @override
  String get jp_structure_rc => 'RC（鉄筋コンクリート）';

  @override
  String get jp_structure_wood => '木造';

  @override
  String get jp_structure_steel => '鉄骨';

  @override
  String get jp_structure_src => 'SRC（鉄骨鉄筋コンクリート）';

  @override
  String get jp_orientation_n => '北';

  @override
  String get jp_orientation_ne => '北東';

  @override
  String get jp_orientation_e => '東';

  @override
  String get jp_orientation_se => '南東';

  @override
  String get jp_orientation_s => '南';

  @override
  String get jp_orientation_sw => '南西';

  @override
  String get jp_orientation_w => '西';

  @override
  String get jp_orientation_nw => '北西';

  @override
  String get jp_available_from => '入居可能日';

  @override
  String get jp_floor => '階数';

  @override
  String get jp_nearest_station => '最寄り駅';

  @override
  String get jp_walk_min_from_station => '駅徒歩（分）';

  @override
  String get jp_train_line => '路線';

  @override
  String get jp_viewing_request => '内見リクエスト';

  @override
  String get jp_select_slots => '希望日時を選択';

  @override
  String get jp_slot_confirmed => '内見日時が確定しました';

  @override
  String get jp_viewing_status_pending => '確認待ち';

  @override
  String get jp_viewing_status_confirmed => '確定済み';

  @override
  String get jp_viewing_status_rejected => 'お断り';

  @override
  String get jp_viewing_status_cancelled => 'キャンセル済み';

  @override
  String get jp_viewing_status_completed => '内見完了';

  @override
  String jp_slot_label(int n) {
    return '第$n希望';
  }

  @override
  String get jp_slots_hint => '最大3つまで希望日時を選択できます';

  @override
  String get jp_slots_max_warning => '希望日時は最大3つまでです';

  @override
  String get jp_apply => '入居申込';

  @override
  String get jp_employer => '勤務先';

  @override
  String get jp_annual_income => '年収';

  @override
  String get jp_guarantor => '連帯保証人';

  @override
  String get jp_emergency_contact => '緊急連絡先';

  @override
  String get jp_upload_documents => '書類アップロード';

  @override
  String get jp_application_status_draft => '下書き';

  @override
  String get jp_application_status_submitted => '申込済み';

  @override
  String get jp_application_status_under_review => '審査中';

  @override
  String get jp_application_status_approved => '承認済み';

  @override
  String get jp_application_status_rejected => 'お断り';

  @override
  String get jp_application_status_withdrawn => '取下げ';

  @override
  String get jp_chat_greeting_formal => 'はじめまして。何かお手伝いできることはございますか？';

  @override
  String get jp_chat_viewing_confirm => '内見のご予約を承りました。';

  @override
  String get jp_chat_apology => 'ご不便をおかけして申し訳ございません。';

  @override
  String get jp_chat_available => 'ご希望の日時に内見が可能です。';

  @override
  String get jp_submit => '送信する';

  @override
  String get jp_cancel_viewing => '内見をキャンセルする';

  @override
  String get jp_reschedule => '日時を変更する';

  @override
  String get jp_step_basic_info => '基本情報';

  @override
  String get jp_step_employer => '勤務先・収入';

  @override
  String get jp_step_guarantor => '保証人情報';

  @override
  String get jp_step_documents => '書類提出';

  @override
  String get jp_step_confirm => '確認・送信';

  @override
  String get jp_search_facets_title => '絞り込み検索';

  @override
  String get jp_layout_filter => '間取り';

  @override
  String get jp_rent_range => '家賃';

  @override
  String get jp_area_range => '面積';

  @override
  String get jp_building_age_max => '築年数（上限）';

  @override
  String get jp_walk_min_max => '駅徒歩（上限）';

  @override
  String get jp_flag_pets_ok => 'ペット可';

  @override
  String get jp_flag_no_guarantor => '保証会社不要';

  @override
  String get jp_flag_instruments_ok => '楽器可';

  @override
  String get jp_flag_corporate_ok => '法人契約可';

  @override
  String get jp_sales_dashboard_title => '担当者ダッシュボード';

  @override
  String get jp_assigned_listings => '担当物件';

  @override
  String get jp_pending_viewings => '内見リクエスト待ち';

  @override
  String get jp_pending_applications => '申込審査待ち';

  @override
  String get jp_viewing_inbox_title => '内見リクエスト一覧';

  @override
  String get jp_application_queue_title => '申込一覧';

  @override
  String get jp_confirm_slot => '日時を確定する';

  @override
  String get jp_reject_viewing => '内見を断る';

  @override
  String get jp_application_decision => '申込の審査';

  @override
  String get jp_approve_application => '承認する';

  @override
  String get jp_reject_application => 'お断りする';

  @override
  String get jp_honorific_toggle => '丁寧語を使用する';

  @override
  String get jp_honorific_on => 'オン';

  @override
  String get jp_honorific_off => 'オフ';

  @override
  String get appi_consent_title => '個人情報の取扱いについて';

  @override
  String get appi_purpose_service_use => 'サービス提供 — 物件検索及び契約手続き';

  @override
  String get appi_purpose_marketing => 'マーケティング — 物件提案及び広告';

  @override
  String get appi_purpose_analytics => '分析 — サービス改善及び利用状況の分析';

  @override
  String get appi_purpose_data_sharing_broker => '宅地建物取引業者への取引処理のための情報提供';

  @override
  String get appi_purpose_data_sharing_hoshou => '保証会社への審査のための情報提供';

  @override
  String get appi_consent_required_notice =>
      '「必須」と記載されている目的はサービス提供に必要です。同意いただけない場合、サービスをご利用いただけません。';

  @override
  String get appi_privacy_policy_link => '個人情報保護方針';

  @override
  String get appi_i_agree => '同意する';

  @override
  String get appi_revoke_consent => '同意を撤回する';

  @override
  String get appi_consent_revoked => '同意を撤回しました';

  @override
  String get appi_consent_granted_on => '同意日';

  @override
  String get appi_privacy_settings_title => '個人情報の取扱い';

  @override
  String get appi_consent_list_title => '同意履歴';

  @override
  String get appi_no_consents => '同意履歴はありません';

  @override
  String get data_export_request => '個人情報の開示請求';

  @override
  String get data_export_processing => 'データを準備しています。しばらくお待ちください。';

  @override
  String get data_export_ready => 'エクスポートの準備ができました。タップしてダウンロードしてください。';

  @override
  String get data_export_submit => '開示請求する';

  @override
  String get data_export_title => '個人データのエクスポート';

  @override
  String get data_export_description => 'アカウントに紐づく個人データをまとめてダウンロードリンクをお送りします。';

  @override
  String get data_delete_title => '個人データの削除請求';

  @override
  String get data_delete_warning => 'アカウントに紐づく全ての個人データを削除します。この操作は取り消せません。';

  @override
  String get data_delete_cool_off =>
      '30日間のクーリングオフ期間が適用されます。この期間内にサポートへご連絡いただければキャンセルできます。';

  @override
  String get data_delete_confirm => '「DELETE」と入力して確認してください';

  @override
  String get data_delete_submit => '削除請求する';

  @override
  String get data_delete_type_hint => 'DELETEと入力';

  @override
  String get data_delete_type_error => '確認のためDELETEと入力してください';

  @override
  String get checkout_title => 'お支払い';

  @override
  String get checkout_invoice_summary => '請求内容';

  @override
  String get checkout_total => '合計';

  @override
  String get payment_method_card => 'クレジット・デビットカード';

  @override
  String get payment_method_konbini => 'コンビニ払い';

  @override
  String get payment_method_bank_transfer => '銀行振込';

  @override
  String get payment_card_placeholder => 'カード決済は準備中です';

  @override
  String get payment_bank_placeholder => '確認後に振込先をご案内します';

  @override
  String get konbini_voucher_title => 'お支払い番号';

  @override
  String get konbini_voucher_number => '払込番号';

  @override
  String get konbini_voucher_deadline => '支払期限';

  @override
  String get konbini_voucher_instructions =>
      '下記の払込番号をコンビニのレジまたはマルチコピー機にてお支払いください。';

  @override
  String get konbini_copy_number => '番号をコピー';

  @override
  String get konbini_number_copied => '払込番号をコピーしました';

  @override
  String get konbini_stores => '対応コンビニ';

  @override
  String get payment_status_pending => '支払い待ち';

  @override
  String get payment_status_processing => '処理中';

  @override
  String get payment_status_succeeded => '支払い完了';

  @override
  String get payment_status_failed => '支払い失敗';

  @override
  String get payment_status_expired => '支払い期限切れ';

  @override
  String get payment_status_title => '支払い状況';

  @override
  String get payment_status_checking => '支払い状況を確認中…';

  @override
  String get payment_retry => '再度支払う';

  @override
  String get payment_contact_support => 'サポートに連絡する';

  @override
  String get review_decision => '審査結果';

  @override
  String get review_approve => '承認する';

  @override
  String get review_reject => 'お断りする';

  @override
  String get review_needs_info => '追加情報を要求する';

  @override
  String get review_reason => '理由（任意）';

  @override
  String get review_reason_hint => '審査結果の理由を入力してください';

  @override
  String get review_submit => '審査結果を送信する';

  @override
  String get review_submitting => '送信中…';

  @override
  String get review_submitted => '審査結果を送信しました';

  @override
  String get review_applicant_info => '申込者情報';

  @override
  String get review_employer_info => '勤務先情報';

  @override
  String get review_guarantor_info => '保証人情報';

  @override
  String get review_documents => '提出書類';

  @override
  String get review_no_documents => '書類なし';

  @override
  String get it_session_title => 'IT重説';

  @override
  String get it_session_takken_shi_info => '担当宅地建物取引士';

  @override
  String get it_session_license_number => '宅建士証番号';

  @override
  String get it_session_consent_notice =>
      '本セッションは宅地建物取引業法に基づき録画されます。録画データは5年間保管されます。';

  @override
  String get it_session_i_consent => '録画及び重要事項の説明に同意します';

  @override
  String get it_session_join_zoom => 'Zoomで参加する';

  @override
  String get it_session_recording_notice => '録画についてのお知らせ';

  @override
  String get it_session_consent_required => '参加前に録画への同意が必要です';

  @override
  String get econtract_title => '電子契約';

  @override
  String get econtract_status_pending => '署名待ち';

  @override
  String get econtract_status_signed => '署名済み';

  @override
  String get econtract_status_expired => '有効期限切れ';

  @override
  String get econtract_status_cancelled => 'キャンセル';

  @override
  String get econtract_sign_button => '契約書に署名する';

  @override
  String get econtract_download_signed => '署名済み契約書をダウンロード';

  @override
  String get econtract_open_external => 'ブラウザで開く';

  @override
  String get econtract_signing_note => '署名サービスに移動します。署名後はこの画面に戻ってください。';

  @override
  String get econtract_status_label => '契約状況';

  @override
  String get jp_renewal_eyebrow => '更新';

  @override
  String get jp_renewal_title => '契約更新';

  @override
  String get jp_renewal_contract_summary => '契約概要';

  @override
  String get jp_renewal_property => '物件名';

  @override
  String get jp_renewal_room => '部屋番号';

  @override
  String get jp_renewal_current_term_end => '現契約終了日';

  @override
  String get jp_renewal_new_term_end => '更新後終了日';

  @override
  String get jp_renewal_total_fee => '更新料合計';

  @override
  String get jp_renewal_confirm_cta => '更新を確認する';

  @override
  String get jp_renewal_decline_cta => '再交渉を希望する';

  @override
  String get jp_renewal_confirm_title => '更新の確認';

  @override
  String get jp_renewal_confirm_notice => '確認後、更新料の請求書が発行されます。';

  @override
  String get jp_renewal_confirm_submit => '確認して更新する';

  @override
  String get jp_renewal_status_confirmed => '更新を確認しました。';

  @override
  String get jp_renewal_status_declined => '再交渉のご要望を受け付けました。';

  @override
  String get jp_settlement_eyebrow => '敷金精算';

  @override
  String get jp_settlement_owner_title => '精算内容の入力';

  @override
  String get jp_settlement_tenant_title => '精算内容の確認';

  @override
  String get jp_settlement_deposit_summary => '敷金概要';

  @override
  String get jp_settlement_property => '物件名';

  @override
  String get jp_settlement_room => '部屋番号';

  @override
  String get jp_settlement_tenant => '入居者';

  @override
  String get jp_settlement_deductions => '控除項目';

  @override
  String get jp_settlement_no_deductions => '控除項目はありません';

  @override
  String get jp_settlement_add_deduction => '項目を追加';

  @override
  String get jp_settlement_remove_deduction => '削除';

  @override
  String get jp_settlement_deduction_item => '項目';

  @override
  String get jp_settlement_deduction_title => '項目名';

  @override
  String get jp_settlement_deduction_amount => '金額（円）';

  @override
  String get jp_settlement_deduction_photos => '写真（任意、最大3枚）';

  @override
  String get jp_settlement_net_refund => '返金額';

  @override
  String get jp_settlement_submit_to_tenant => '入居者に送付する';

  @override
  String get jp_settlement_accept_cta => '精算内容に同意する';

  @override
  String get jp_settlement_dispute_cta => '異議を申し立てる';

  @override
  String get jp_settlement_dispute_title => '異議申立';

  @override
  String get jp_settlement_dispute_description => '異議の理由をご記入ください。';

  @override
  String get jp_settlement_dispute_reason_label => '異議の理由';

  @override
  String get jp_settlement_dispute_submit => '異議を申し立てる';

  @override
  String get jp_settlement_status_accepted => '精算内容に同意しました。返金手続きを開始します。';

  @override
  String get jp_settlement_status_disputed => '異議が申し立てられました。';

  @override
  String get jp_kpi_eyebrow => '管理者';

  @override
  String get jp_kpi_dashboard_title => 'KPIダッシュボード';

  @override
  String get jp_kpi_prefecture_label => '都道府県';

  @override
  String get jp_kpi_all_japan => '全国';

  @override
  String get jp_kpi_active_listings => '掲載中物件';

  @override
  String get jp_kpi_pending_applications => '審査中申込';

  @override
  String get jp_kpi_active_contracts => '稼働契約';

  @override
  String get jp_kpi_avg_days_to_sign => '平均成約日数';

  @override
  String get jp_kpi_monthly_revenue => '月次収益';

  @override
  String get jp_deletion_eyebrow => 'アカウント';

  @override
  String get jp_deletion_title => 'アカウント削除';

  @override
  String get jp_deletion_settings_subtitle => '30日後にアカウントと全データが削除されます';

  @override
  String get jp_deletion_warning =>
      'アカウントを削除すると、以下のすべてのデータが完全に削除されます。この操作は取り消せません。';

  @override
  String get jp_deletion_bullet_data => '個人情報・プロフィール情報';

  @override
  String get jp_deletion_bullet_contracts => '契約・取引履歴';

  @override
  String get jp_deletion_bullet_irreversible => 'この操作は取り消せません';

  @override
  String get jp_deletion_cooloff_notice =>
      '削除申請から30日間のクーリングオフ期間が適用されます。この期間内にサポートへご連絡いただければキャンセルできます。';

  @override
  String get jp_deletion_schedule_cta => '削除を申請する';

  @override
  String get jp_deletion_days_remaining => '日後に削除されます';

  @override
  String get jp_deletion_scheduled_notice =>
      'アカウントの削除が予定されています。期間内にキャンセルが可能です。';

  @override
  String get jp_deletion_support_contact =>
      'キャンセルはサポート（support@ancu365.jp）までご連絡ください。';

  @override
  String get jp_deletion_cancel_cta => '削除申請をキャンセルする';

  @override
  String get jp_deletion_cancel_confirm_title => '削除申請のキャンセル';

  @override
  String get jp_deletion_cancel_confirm_body => '削除申請をキャンセルしてよろしいですか？';

  @override
  String get jp_deletion_cancel_no => '戻る';

  @override
  String get jp_deletion_cancel_yes => 'キャンセルする';

  @override
  String get jp_deletion_confirm_sheet_title => '削除の最終確認';

  @override
  String get jp_deletion_confirm_sheet_body => '続行するには、登録済みのメールアドレスを入力してください。';

  @override
  String get jp_deletion_confirm_email_label => 'メールアドレス';

  @override
  String get jp_deletion_confirm_email_hint => '登録メールアドレスを入力';

  @override
  String get jp_deletion_confirm_email_error => 'メールアドレスが一致しません';

  @override
  String get jp_deletion_confirm_submit => '削除を申請する';

  @override
  String get jp_facet_pets_ok_label => 'ペット可';

  @override
  String get jp_facet_walk_min_label => '駅徒歩（分）';

  @override
  String jp_facet_walk_min_value(int min) {
    return '徒歩$min分以内';
  }

  @override
  String get jp_facet_layout_label => '間取り（詳細）';

  @override
  String get helpCenterTitle => 'ヘルプセンター';

  @override
  String get helpCenterSearchHint => 'よくある質問を検索...';

  @override
  String get helpCenterNoResults => '該当する記事が見つかりませんでした';

  @override
  String get helpCenterArticleNotFound => '記事が見つかりません';

  @override
  String get helpCenterLoadError => '記事の読み込みに失敗しました。もう一度お試しください。';

  @override
  String get helpCenterComingSoon => 'コンテンツを準備中です。しばらくお待ちください。';

  @override
  String get legalFooterTokusho => '特定商取引法に基づく表記';

  @override
  String get legalFooterTerms => '利用規約';

  @override
  String get legalFooterPrivacy => 'プライバシーポリシー';

  @override
  String get legalFooterAppiRequest => 'APPI 開示請求';

  @override
  String get legalFooterOperator => '運営会社情報';

  @override
  String get legalFooterCopyright => '© 2026 Synora株式会社 All rights reserved.';
}
