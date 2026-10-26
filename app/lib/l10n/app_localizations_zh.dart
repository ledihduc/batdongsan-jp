// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get loginAccountType => '账户类型';

  @override
  String get loginAccountTypeHint => '请选择登录账户类型';

  @override
  String get loginAccountTypeRequired => '请选择账户类型';

  @override
  String get loginAccountTypeMismatch => '此账户无权使用所选角色。请选择其他账户类型或联系管理员。';

  @override
  String get loginAccountPickerHelp => '选择您要使用的角色。您的账户必须已获得相应权限。';

  @override
  String get loginAccountPickerClose => '关闭账户选择';

  @override
  String get loginRoleCustomer => '找房用户';

  @override
  String get loginRoleCustomerDescription => '寻找买卖或租赁房源，查看您的预约。';

  @override
  String get loginRoleSale => '销售 / 经纪人';

  @override
  String get loginRoleSaleDescription => '管理客户、房源和交易。';

  @override
  String get loginRoleOwner => '房东';

  @override
  String get loginRoleOwnerDescription => '管理房产、房间和租客。';

  @override
  String get loginRoleAdmin => '管理员';

  @override
  String get loginRoleAdminDescription => '适用于已获得系统管理权限的账户。';

  @override
  String get loginGuestBrowse => '无需登录，继续浏览';

  @override
  String get appTitle => 'Vua Nhà';

  @override
  String get settingsTitle => '设置与隐私';

  @override
  String get settingsEyebrow => '账户';

  @override
  String get sectionAccount => '账户';

  @override
  String get editProfile => '编辑资料';

  @override
  String get editProfileSub => '姓名、头像、电话号码';

  @override
  String get changePassword => '修改密码';

  @override
  String get sectionPreferences => '偏好设置';

  @override
  String get language => '语言';

  @override
  String get chooseLanguage => '选择语言';

  @override
  String get notifications => '通知';

  @override
  String get darkMode => '深色模式';

  @override
  String get comingSoon => '即将推出';

  @override
  String get logout => '退出登录';

  @override
  String get daTitle => '删除账户';

  @override
  String get daSubtitle => '永久删除您的账户和个人数据';

  @override
  String get daDialogTitle => '删除账户？';

  @override
  String get daDialogBody => '此操作无法撤销。您的所有个人信息将被删除，且将无法再次登录。请输入密码以确认。';

  @override
  String get daPasswordHint => '当前密码';

  @override
  String get daPasswordRequired => '请输入密码以确认';

  @override
  String get daConfirm => '删除账户';

  @override
  String get daSuccess => '您的账户已删除';

  @override
  String get daFailed => '删除账户失败';

  @override
  String get blockUser => '屏蔽此人';

  @override
  String get blockUserSub => '您将不再看到其内容';

  @override
  String get blockConfirmTitle => '屏蔽此人？';

  @override
  String get blockConfirmBody => '您将不再看到其帖子、视频和评论。可在设置中取消屏蔽。';

  @override
  String get blockAction => '屏蔽';

  @override
  String get blockDone => '已屏蔽该用户';

  @override
  String get blockFailed => '屏蔽失败，请稍后再试';

  @override
  String get unblock => '取消屏蔽';

  @override
  String get unblockDone => '已取消屏蔽';

  @override
  String get blockedUsersTitle => '已屏蔽的用户';

  @override
  String get blockedUsersSub => '管理您屏蔽的用户';

  @override
  String get blockedEmpty => '您还没有屏蔽任何人';

  @override
  String get reportComment => '举报评论';

  @override
  String get actionsNounComment => '评论';

  @override
  String get privacyPolicy => '隐私政策';

  @override
  String get termsOfUse => '使用条款';

  @override
  String get sectionLegal => '法律';

  @override
  String get logoutConfirm => '确定要退出登录吗？';

  @override
  String get loggedOut => '已退出登录';

  @override
  String get cancel => '取消';

  @override
  String get vietnamese => '越南语';

  @override
  String get english => '英语';

  @override
  String get chinese => '中文';

  @override
  String get loginEyebrow => '快捷 · 透明租房';

  @override
  String get loginTagline => '找房、租房、发布房源——简单又透明。';

  @override
  String get loginEmail => '邮箱';

  @override
  String get loginPassword => '密码';

  @override
  String get loginForgot => '忘记密码？';

  @override
  String get loginButton => '登录';

  @override
  String get loginFailed => '登录失败';

  @override
  String get loginExitHome => '返回首页';

  @override
  String get loginOr => '或';

  @override
  String get loginNoAccount => '还没有账户？';

  @override
  String get loginRegisterNow => '立即注册';

  @override
  String get loginDemoAccounts => '演示账户';

  @override
  String get demoTenant => '租客';

  @override
  String get demoHost => '房东';

  @override
  String get demoAdmin => '管理员';

  @override
  String get valEmailRequired => '请输入邮箱';

  @override
  String get valEmailInvalid => '邮箱格式不正确';

  @override
  String get valPasswordRequired => '请输入密码';

  @override
  String get loginContinueGoogle => '使用 Google 继续';

  @override
  String get loginContinueFacebook => '使用 Facebook 继续';

  @override
  String loginOauthMaintenance(String provider) {
    return '$provider 登录正在维护中，请稍后再试。';
  }

  @override
  String get demoDesigner => '设计单位';

  @override
  String get demoBuilder => '施工单位';

  @override
  String get demoInterior => '室内单位';

  @override
  String get emailHint => 'you@example.com';

  @override
  String get passwordHint => '至少 6 个字符';

  @override
  String get registerEyebrow => '注册';

  @override
  String get registerTitle => '创建账户';

  @override
  String get registerWelcome => '欢迎来到';

  @override
  String get registerSubtitle => '创建免费账户，开始查找和发布房源。';

  @override
  String get registerName => '姓名';

  @override
  String get registerPhoneOptional => '电话号码（可选）';

  @override
  String get registerConfirmPassword => '确认密码';

  @override
  String get registerAgreeTerms => '我同意《条款与隐私政策》';

  @override
  String get registerNeedAgree => '您需要同意服务条款';

  @override
  String get registerFailed => '注册失败';

  @override
  String get registerHaveAccount => '已有账户？';

  @override
  String get valRequired => '必填';

  @override
  String get valPasswordMin => '至少 6 个字符';

  @override
  String get valPasswordMismatch => '两次密码不一致';

  @override
  String get svcRealEstate => '房地产';

  @override
  String get svcRental => '出租房';

  @override
  String get svcIndustrial => '工业地产';

  @override
  String get svcMap => '地图';

  @override
  String get svcConstruction => '施工';

  @override
  String get svcNew => '新';

  @override
  String get svcDesign => '设计';

  @override
  String get svcBuild => '建造';

  @override
  String get svcInterior => '室内装修';

  @override
  String get svcCommunityTitle => '房地产社区';

  @override
  String get svcCommunitySubtitle => '问答、区域点评、寻找室友…';

  @override
  String get svcLeaderboardTitle => '合作伙伴排行榜';

  @override
  String get svcLeaderboardSubtitle => '按行业排名：设计、建造、室内装修…';

  @override
  String get shellLoginToPostHouse => '登录以发布您的房源出租信息。';

  @override
  String get shellBecomeHostTitle => '成为房东';

  @override
  String get shellBecomeHostBody => '您将发布第一条房源信息并自动升级为房东。是否继续？';

  @override
  String get shellContinue => '继续';

  @override
  String get shellLoginToPostConstruction => '登录以发布施工帖子。';

  @override
  String get shellPostRequest => '发布需求';

  @override
  String get shellPostListing => '发布信息';

  @override
  String get shellNavRealEstate => '资讯';

  @override
  String get shellNavConstruction => '施工';

  @override
  String get shellNavWishlist => '收藏';

  @override
  String get shellNavProfile => '个人';

  @override
  String get shellNavOverview => '概览';

  @override
  String get shellNavRooms => '出租房';

  @override
  String get shellNavRequests => '请求';

  @override
  String get shellHostBuildingsHeader => '出租房 · 楼栋台账';

  @override
  String get drawerCommonSection => '通用';

  @override
  String get hubCommonSection => '通用';

  @override
  String get drawerMessages => '消息';

  @override
  String get drawerSystemAdmin => '系统管理';

  @override
  String get drawerHelp => '帮助';

  @override
  String get drawerAbout => '关于应用';

  @override
  String get drawerRealEstateSection => '房地产';

  @override
  String get drawerMapPlanning => '房产与规划地图';

  @override
  String get drawerHousesForRent => '出租房屋';

  @override
  String get drawerIndustrialRealEstate => '工业地产';

  @override
  String get drawerPostBusinessSection => '发布与经营';

  @override
  String get drawerConstructionBusinessSection => '需求与报价';

  @override
  String get drawerPostRental => '发布出租信息';

  @override
  String get drawerBecomeHost => '成为房东';

  @override
  String get drawerConstructionSection => '施工';

  @override
  String get drawerContractorDirectory => '承包商名录';

  @override
  String get drawerDesignLibrary => '设计图库';

  @override
  String get drawerPartnerLeaderboard => '合作伙伴排行榜';

  @override
  String get drawerPostConstructionRequest => '发布施工需求';

  @override
  String get drawerContractorChannel => '施工单位频道';

  @override
  String get drawerTagline => '房地产与施工';

  @override
  String get drawerViewProfile => '查看个人资料';

  @override
  String get drawerLoginPrompt => '登录以收藏信息、发送消息和发帖。';

  @override
  String get drawerLoginRegister => '登录 / 注册';

  @override
  String get actionsNounHouse => '房源';

  @override
  String get actionsNounPost => '帖子';

  @override
  String get actionsUnsave => '取消保存';

  @override
  String actionsSaveNoun(Object noun) {
    return '保存$noun';
  }

  @override
  String get actionsSaveSub => '稍后在已保存中查看';

  @override
  String actionsLoginToSave(Object noun) {
    return '登录以保存该$noun。';
  }

  @override
  String get actionsEdit => '编辑';

  @override
  String get actionsDelete => '删除';

  @override
  String get actionsReportWrongInfo => '报告信息有误';

  @override
  String get actionsReportWrongInfoSub => '发送给发布者以便更正 — 并非举报';

  @override
  String actionsReportNoun(Object noun) {
    return '举报$noun';
  }

  @override
  String get actionsReportViolationSub => '提交管理员审核';

  @override
  String get actionsLoginToFeedback => '登录以发送反馈。';

  @override
  String get actionsFeedbackSent => '已将反馈发送给发布者。谢谢！';

  @override
  String get actionsReportSent => '已发送举报。管理员将进行审核。';

  @override
  String get actionsRateLimited => '发送过于频繁，请几分钟后再试。';

  @override
  String get actionsSendFailed => '发送失败，请重试。';

  @override
  String get actionsWrongInfoDesc => '发布者将收到通知以便核实。您的身份将被保密。';

  @override
  String get actionsWrongInfoHint => '例如：价格已变、已出租、地址有误……';

  @override
  String get actionsSend => '发送';

  @override
  String get actionsChooseReason => '选择最合适的理由';

  @override
  String get actionsReasonScam => '诈骗/虚假信息';

  @override
  String get actionsReasonSpam => '垃圾信息、重复发布';

  @override
  String get actionsReasonDuplicate => '与其他信息重复';

  @override
  String get actionsReasonInappropriate => '内容不当';

  @override
  String get actionsReasonOther => '其他理由';

  @override
  String get homeMenuTooltip => '菜单';

  @override
  String get homeSearchTooltip => '搜索';

  @override
  String get worldRealEstateLabel => '房地产';

  @override
  String get worldConstructionLabel => '施工 · 设计';

  @override
  String get homeAdvancedFilterTooltip => '高级筛选';

  @override
  String get homeLoginPromptSaveContactPost => '登录以保存房源、联系和发布。';

  @override
  String get homeAll => '全部';

  @override
  String get homeRealEstateReels => '房产短视频';

  @override
  String get homeNoMoreRooms => '— 没有更多房源 —';

  @override
  String get homeLoadListFailed => '无法加载列表';

  @override
  String get homeNoMatchingListings => '暂无匹配的房源';

  @override
  String get homeCheckNetworkRetry => '请检查网络连接后重试。';

  @override
  String get homeTryRemoveFilters => '尝试减少筛选条件以查看更多房源。';

  @override
  String get homeRetry => '重试';

  @override
  String get homeClearFilters => '清除筛选';

  @override
  String get homeLoginToSaveFavorite => '登录以保存收藏的房源。';

  @override
  String get homeHost => '房东';

  @override
  String get homeSave => '保存';

  @override
  String get homeContact => '联系';

  @override
  String get homeDetails => '详情';

  @override
  String get homeLoginToMessageHost => '登录以私信房东。';

  @override
  String homeAreaM2(Object area) {
    return '$area 平方米';
  }

  @override
  String homeDistanceAway(Object distance) {
    return '距离 $distance';
  }

  @override
  String get homeFull => '已满';

  @override
  String homeAvailableUnits(Object available, Object total) {
    return '剩 $available/$total';
  }

  @override
  String get homeTabRent => '出租';

  @override
  String get homeTabSale => '买卖';

  @override
  String get homeFilterRent => '筛选：出租';

  @override
  String get homeFilterSale => '筛选：买卖';

  @override
  String get filterTitle => '搜索与筛选';

  @override
  String get filterReset => '重置';

  @override
  String get filterSectionSearchArea => '搜索区域';

  @override
  String get filterSectionPriceRange => '价格范围';

  @override
  String get filterMaxPriceLabel => '最高价格：';

  @override
  String filterPriceValueVnd(Object value) {
    return '$value百万越南盾';
  }

  @override
  String filterPriceValueShort(Object value) {
    return '$value百万';
  }

  @override
  String get filterSectionArea => '面积 (m²)';

  @override
  String get filterAreaFrom => '从';

  @override
  String get filterAreaTo => '到';

  @override
  String get filterSectionBedrooms => '卧室数量';

  @override
  String get filterAny => '任意';

  @override
  String get filterSectionPropertyType => '住宿类型';

  @override
  String get filterClearAll => '清除全部';

  @override
  String get filterApply => '应用筛选';

  @override
  String get filterModeAll => '全部';

  @override
  String get filterModeNearby => '附近';

  @override
  String get filterModePlace => '地点';

  @override
  String get filterPlaceHint => '输入地点：“百科大学附近”…';

  @override
  String get filterLocationUpdate => '已获取位置 — 点按更新';

  @override
  String get filterGetCurrentLocation => '获取当前位置';

  @override
  String get filterRadiusLabel => '半径：';

  @override
  String filterRadiusKm(Object value) {
    return '$value 公里';
  }

  @override
  String get filterLocationAcquired => '已获取您的位置 ✓';

  @override
  String get filterLocServiceOff => '设备定位已关闭。请开启后重试。';

  @override
  String get filterLocDenied => '需要位置权限。请重试并允许。';

  @override
  String get filterLocDeniedForever => '位置权限被阻止 — 请在设置中授予。';

  @override
  String get filterLocOutOfVietnam => '位置超出服务范围。';

  @override
  String get filterLocError => '无法获取位置。请重试。';

  @override
  String get filterPrimingTitle => '查找您附近的房源';

  @override
  String get filterPrimingBody => '开启定位可查看最近的房源及准确距离。Vua Nhà 仅在您搜索附近时使用您的位置。';

  @override
  String get filterPrimingLater => '稍后';

  @override
  String get filterEnableLocation => '开启定位';

  @override
  String get filterNeedLocationFirst => '请先获取当前位置再应用。';

  @override
  String get addProjPdfUploadError => '无法上传 PDF 文件';

  @override
  String get addProjTitleRequired => '请输入工程名称';

  @override
  String get addProjWaitImages => '请等待图片上传完成';

  @override
  String get addProjNeedImage => '请至少为工程添加 1 张照片';

  @override
  String get addProjUpdated => '已更新';

  @override
  String get addProjPosted => '已发布。资料将由管理员审核确认。';

  @override
  String addProjError(Object error) {
    return '错误：$error';
  }

  @override
  String get addProjEyebrow => '服务商频道';

  @override
  String addProjEditTitle(Object type) {
    return '编辑$type';
  }

  @override
  String get addProjTypeDesign => '设计方案';

  @override
  String get addProjTypeWork => '工程';

  @override
  String get addProjCreateDesign => '发布设计方案';

  @override
  String get addProjCreateWork => '发布工程';

  @override
  String addProjPhotoSection(Object type) {
    return '$type照片';
  }

  @override
  String get addProjPhotoHelper => '第一张为封面照片。长按可设为封面/删除。最多 10 张。';

  @override
  String get addProjBasicInfo => '基本信息';

  @override
  String get addProjTitleLabel => '工程名称';

  @override
  String get addProjTitleHintDesign => '例如：现代三层别墅 9x16 米';

  @override
  String get addProjTitleHintWork => '例如：南先生的三层联排别墅 - 第七郡';

  @override
  String get addProjDescLabel => '描述';

  @override
  String get addProjDescHint => '规模、材料、亮点…';

  @override
  String get addProjFieldLabel => '领域';

  @override
  String get addProjFieldBuild => '建筑';

  @override
  String get addProjFieldInterior => '室内装修';

  @override
  String get addProjYearLabel => '完工年份';

  @override
  String get addProjSpecsTitle => '房型参数';

  @override
  String get addProjSpecsHelper => '帮助方案出现在设计库的正确筛选中。';

  @override
  String get addProjHouseTypeLabel => '房屋类型';

  @override
  String get addProjStyleLabel => '风格';

  @override
  String get addProjFloorsLabel => '楼层数';

  @override
  String get addProjBedroomsLabel => '卧室';

  @override
  String get addProjWidthLabel => '土地宽度（米）';

  @override
  String get addProjLengthLabel => '土地长度（米）';

  @override
  String get addProjAreaLabel => '建筑面积（平方米）';

  @override
  String get addProjCostLabel => '参考价格（越南盾）';

  @override
  String get addProjCostHint => '如无可留空';

  @override
  String get addProjPdfSection => '设计文件（PDF）';

  @override
  String get addProjPdfHelper => '图纸/文件 — 将由管理员审核。最多 10 个文件。';

  @override
  String addProjPdfItem(Object number) {
    return '文件 $number';
  }

  @override
  String get addProjUploading => '上传中…';

  @override
  String get addProjAddPdf => '添加 PDF 文件';

  @override
  String get addProjSaveChanges => '保存更改';

  @override
  String get addProjSubmit => '发布';

  @override
  String get addProjSegWork => '已完成工程';

  @override
  String get addProjSegDesign => '设计方案';

  @override
  String get bkDetEyebrow => '预约';

  @override
  String get bkDetTitle => '预约详情';

  @override
  String get bkDetCancelAppointment => '取消预约';

  @override
  String get bkDetCancelConfirm => '确定要取消这次看房预约吗？';

  @override
  String get bkDetClose => '关闭';

  @override
  String get bkDetCancelBooking => '取消排期';

  @override
  String get bkDetCancelFailed => '取消失败 — 请重试。';

  @override
  String bkDetPhoneCopied(Object phone) {
    return '已复制号码 $phone — 打开电话应用拨打。';
  }

  @override
  String get bkDetHostNotFound => '找不到房东信息。';

  @override
  String get bkDetHost => '房东';

  @override
  String get bkDetApartment => '公寓';

  @override
  String get bkDetRoomImage => '房间照片';

  @override
  String get bkDetScheduleTitle => '预约';

  @override
  String get bkDetViewDate => '看房日期';

  @override
  String get bkDetTime => '时间';

  @override
  String get bkDetSentAt => '发送时间';

  @override
  String get bkDetYourMessage => '您的留言';

  @override
  String get bkDetNoMessage => '没有留言。';

  @override
  String get bkDetHostInfo => '房东信息';

  @override
  String get bkDetMessage => '发消息';

  @override
  String get bkDetProgress => '进度';

  @override
  String get bkDetStepRequested => '请求已发送';

  @override
  String get bkDetStepApproved => '房东已确认';

  @override
  String get bkDetStepCompleted => '看房完成';

  @override
  String get bkDetStepBooked => '房间已定';

  @override
  String get bkDetStepRejected => '房东已拒绝';

  @override
  String get bkDetStepCancelled => '您已取消';

  @override
  String get bkDetStepLost => '已被他人预定';

  @override
  String get bkDetStepEnded => '已结束';

  @override
  String get bkDetCall => '打电话';

  @override
  String get bkDetReviewed => '已评价';

  @override
  String get bkDetWriteReview => '写评价';

  @override
  String get bkDetExploreOther => '浏览其他房源';

  @override
  String get bkHistEyebrow => '账户';

  @override
  String get bkHistTitle => '预约记录';

  @override
  String get bkHistRefresh => '刷新';

  @override
  String get bkHistTabPending => '待审核';

  @override
  String get bkHistTabApproved => '已批准';

  @override
  String get bkHistCompleted => '已完成';

  @override
  String get bkHistFilterAll => '全部';

  @override
  String get bkHistStatusLocked => '已订房';

  @override
  String get bkHistStatusCancelled => '已取消';

  @override
  String get bkHistStatusRejected => '已拒绝';

  @override
  String get bkHistStatusLost => '已被他人预订';

  @override
  String get bkHistSearchHint => '按名称/地址搜索...';

  @override
  String get bkHistClearSearch => '清除搜索';

  @override
  String get bkHistRoomPhoto => '房间照片';

  @override
  String get bkHistDefaultHouseTitle => '高级公寓';

  @override
  String get bkHistCallHost => '致电房东';

  @override
  String get bkHistMessage => '发消息';

  @override
  String get bkHistReviewed => '已评价';

  @override
  String get bkHistReview => '评价';

  @override
  String get bkHistApartment => '公寓';

  @override
  String get bkHistViewOtherHouses => '查看其他房源';

  @override
  String get bkHistCancelTitle => '取消预约';

  @override
  String get bkHistCancelConfirm => '确定要取消此预约吗？';

  @override
  String get bkHistClose => '关闭';

  @override
  String get bkHistCancelAppointment => '取消预约';

  @override
  String get bkHistCancelSuccess => '预约已取消';

  @override
  String get bkHistCancelFailed => '取消失败';

  @override
  String get bkHistNoHostPhone => '暂无房东电话';

  @override
  String bkHistPhoneCopied(Object phone) {
    return '已复制号码：$phone';
  }

  @override
  String get bkHistHostNotFound => '未找到房东';

  @override
  String get bkHistHost => '房东';

  @override
  String get bkHistNoRequests => '暂无请求';

  @override
  String get bkHistNoResults => '未找到结果';

  @override
  String get bkHistSearchEmpty => '尝试其他关键词或清除搜索筛选。';

  @override
  String get bkHistEmptyHint => '您的预约请求将显示在此处。';

  @override
  String get bkSchedSuccessMessage => '预约请求已成功发送！';

  @override
  String get bkSchedSubmitFailed => '请求发送失败';

  @override
  String get bkSchedEyebrow => '预约';

  @override
  String get bkSchedAppBarTitle => '预约看房';

  @override
  String get bkSchedCardHeader => '预约看房时间';

  @override
  String get bkSchedStep1 => '1. 选择看房日期';

  @override
  String bkSchedDateLabel(Object date) {
    return '日期：$date';
  }

  @override
  String get bkSchedStep2 => '2. 选择时间段（每段1小时）';

  @override
  String get bkSchedStep3 => '3. 给房东的留言（可选）';

  @override
  String get bkSchedMessageHint => '例如：我想进一步了解停车位，或者我会带朋友一起来……';

  @override
  String get bkSchedSelectSlotPrompt => '请选择时间段';

  @override
  String get bkSchedSubmit => '发送预约请求';

  @override
  String get bkSchedAfterSubmitTitle => '发送请求后';

  @override
  String get bkSchedAfterSubmitDesc => '房东将收到通知，并在最多2个工作小时内为您确认。';

  @override
  String get bkSchedCancelPolicyTitle => '取消政策';

  @override
  String get bkSchedCancelPolicyDesc => '您可在预约时间前4小时内免费更改或取消看房。';

  @override
  String get bkSchedRetry => '重试';

  @override
  String get bkSchedNoSlots => '当天没有可预约的时间段。请选择其他日期。';

  @override
  String get ccompTitle => '发布施工';

  @override
  String get ccompSend => '发送';

  @override
  String get ccompPost => '发布';

  @override
  String get ccompYou => '你';

  @override
  String get ccompGuestName => '访客';

  @override
  String get ccompIntentShare => '分享工程';

  @override
  String get ccompIntentNeed => '需要施工';

  @override
  String get ccompContentHintNeed => '你需要施工什么？描述需求和现状…';

  @override
  String get ccompContentHintShare => '分享你刚完成的工程…';

  @override
  String get ccompServiceBuild => '建筑';

  @override
  String get ccompServiceDesign => '设计';

  @override
  String get ccompServiceInterior => '室内';

  @override
  String get ccompServiceIndustrial => '工业';

  @override
  String get ccompPhoneHint => '电话号码 *';

  @override
  String get ccompAreaHint => '面积（例如 80m²）';

  @override
  String get ccompBudgetHint => '预计预算';

  @override
  String get ccompLocationOptional => '位置（可选）';

  @override
  String get ccompSelectProvince => '选择省/市';

  @override
  String get ccompLoading => '加载中…';

  @override
  String get ccompSelectWard => '选择坊/乡';

  @override
  String get ccompMapHint => '点击地图以标记位置（地址自动填充）。';

  @override
  String ccompPinnedWard(Object ward) {
    return '已标记：$ward';
  }

  @override
  String ccompPinnedCoords(Object lat, Object lng) {
    return '已标记：$lat, $lng';
  }

  @override
  String ccompPhotosCount(Object count, Object max) {
    return '照片（$count/$max）';
  }

  @override
  String get ccompLocation => '位置';

  @override
  String get ccompImagePickFailed => '无法选择图片';

  @override
  String get ccompSubmitFailed => '发布失败，请重试';

  @override
  String get cleadTitle => '合作伙伴排行榜';

  @override
  String get cleadSubtitle => '按信誉和评价排名';

  @override
  String get cleadTradeDesign => '设计';

  @override
  String get cleadTradeBuild => '建筑';

  @override
  String get cleadTradeInterior => '室内';

  @override
  String get cleadTradeIndustrial => '工业地产';

  @override
  String get cleadLoadError => '无法加载合作伙伴列表';

  @override
  String get cleadEmptyTitle => '该行业暂无合作伙伴';

  @override
  String get cleadEmptySubtitle => '请尝试其他行业或稍后再来。';

  @override
  String get cleadFallbackCompany => '合作伙伴';

  @override
  String get cleadNoRating => '暂无评价';

  @override
  String cleadRatingCount(Object rating, Object count) {
    return '⭐ $rating（$count 条评价）';
  }

  @override
  String cleadRatingNew(Object rating, Object count) {
    return '⭐ $rating · $count 条评价（新）';
  }

  @override
  String get cleadBadgeFeatured => '推荐';

  @override
  String get cleadBadgePro => '专业版';

  @override
  String get cleadBadgeVerified => '已认证';

  @override
  String get compareTitle => '房产比较';

  @override
  String get compareEmpty => '没有可比较的房产';

  @override
  String get compareCriteria => '标准';

  @override
  String get compareHouseFallback => '房产';

  @override
  String get compareLabelPrice => '价格';

  @override
  String get compareLabelArea => '面积';

  @override
  String get compareLabelPricePerSqm => '每平方米价格';

  @override
  String get compareLabelLegal => '法律状态';

  @override
  String get compareLabelBedrooms => '卧室';

  @override
  String get compareLabelBathrooms => '卫生间';

  @override
  String get compareLabelLocation => '区域';

  @override
  String get ctrContractor => '承包商';

  @override
  String get ctrLoadFailed => '加载失败';

  @override
  String get ctrRequestQuote => '请求报价';

  @override
  String ctrContractorRatingSubtitle(Object rating, Object count) {
    return '承包商 · ⭐ $rating ($count 条评价)';
  }

  @override
  String get ctrTrustedUnit => '可信单位';

  @override
  String get ctrVerified => '已验证';

  @override
  String get ctrCertVerified => '执业证书';

  @override
  String get ctrProjectsStat => '项目';

  @override
  String get ctrVerifiedLabel => '已核实';

  @override
  String get ctrDesignFilesStat => '设计文件';

  @override
  String get ctrReviewsStat => '评价';

  @override
  String ctrYearsExperience(Object yrs) {
    return '$yrs 年经验';
  }

  @override
  String ctrEstablished(Object year) {
    return '成立于 $year';
  }

  @override
  String ctrTeamSize(Object team) {
    return '团队 $team 人';
  }

  @override
  String get ctrWebsite => '网站';

  @override
  String get ctrPortfolioTitle => '已完成项目';

  @override
  String get ctrNoProjects => '暂无项目';

  @override
  String get ctrNoProjectsSubtitle => '该单位尚未发布任何工程。发送请求以获得直接咨询。';

  @override
  String get ctrFilterAll => '全部';

  @override
  String get ctrFilterHasFiles => '含设计文件';

  @override
  String get ctrNoMatchFilter => '没有符合筛选条件的项目。';

  @override
  String get ctrProject => '项目';

  @override
  String ctrFilesCount(Object count) {
    return '$count 个文件';
  }

  @override
  String ctrReviewsTitle(Object count) {
    return '评价 ($count)';
  }

  @override
  String get ctrNoReviews => '暂无评价';

  @override
  String get ctrNoReviewsSubtitle => '成为第一个评价该单位的客户。';

  @override
  String get ctrCriteriaQuality => '质量';

  @override
  String get ctrCriteriaTimeliness => '进度';

  @override
  String get ctrCriteriaCommunication => '沟通';

  @override
  String get ctrCriteriaBudget => '预算';

  @override
  String get ctrCriteriaProfessionalism => '专业度';

  @override
  String get ctrCriteriaBreakdownTitle => '按标准细分';

  @override
  String ctrReviewCount(Object count) {
    return '$count 条评价';
  }

  @override
  String get ctrNotEnoughReviews => '评价不足，无法进行详细评分。';

  @override
  String get ctrUser => '用户';

  @override
  String get cwLoginToJoinCommunity => '登录以加入施工社区。';

  @override
  String get cwConstructionReels => '施工短视频';

  @override
  String get cwPostDeleted => '已删除帖子';

  @override
  String get cwPostRemovedModeration => '已移除帖子（审核）';

  @override
  String cwErrorWithMsg(Object msg) {
    return '错误：$msg';
  }

  @override
  String get cwProject => '工程';

  @override
  String cwLocationPin(Object location) {
    return '📍 $location';
  }

  @override
  String get cwViewContractor => '查看单位';

  @override
  String get cwShare => '分享';

  @override
  String get cwCopyLinkFromBrowser => '从浏览器复制链接';

  @override
  String get cwNeedConstruction => '需要施工';

  @override
  String get cwQuote => '报价';

  @override
  String get cwNeedContractorProfile => '您需要单位资料才能报价（个人 → 单位频道）。';

  @override
  String get cwQuoteSent => '已向客户发送报价';

  @override
  String get cwContractor => '单位';

  @override
  String get cwCatAll => '全部';

  @override
  String get cwCatDesign => '设计';

  @override
  String get cwCatBuild => '建筑';

  @override
  String get cwCatInterior => '室内';

  @override
  String get cwCatIndustrial => '工业';

  @override
  String get cwFeaturedContractors => '精选单位';

  @override
  String get cwViewAllDesignsGrid => '以网格查看所有设计';

  @override
  String cwNoContentInCategory(Object category) {
    return '$category 分类暂无内容';
  }

  @override
  String get cwBeFirstToShare => '成为第一个分享项目或发布需求的人。';

  @override
  String get cwSendQuote => '发送报价';

  @override
  String get cwAmountVnd => '金额（越南盾）*';

  @override
  String get cwAmountHint => '例如：1500000000';

  @override
  String get cwNoteOptional => '备注（可选）';

  @override
  String get cwSend => '发送';

  @override
  String get designAppBarEyebrow => '施工';

  @override
  String get designLibraryTitle => '设计库';

  @override
  String get designPostDesign => '发布设计';

  @override
  String get designAll => '全部';

  @override
  String get designHouseType => '房屋类型';

  @override
  String get designStyle => '风格';

  @override
  String get designFloors => '层数';

  @override
  String designFloorsValue(Object floors) {
    return '$floors 层';
  }

  @override
  String get designBedroomsLabel => '卧室';

  @override
  String get designBedroomsTitle => '卧室数量';

  @override
  String designBedroomsShort(Object bedrooms) {
    return '$bedrooms 卧';
  }

  @override
  String designBedroomsValue(Object bedrooms) {
    return '$bedrooms 间卧室';
  }

  @override
  String designAreaValue(Object area) {
    return '${area}m²';
  }

  @override
  String get designVerified => '已核实';

  @override
  String get designClearFilters => '清除筛选';

  @override
  String get designLoadError => '无法加载资料库';

  @override
  String get designLoadErrorSubtitle => '请检查网络连接后重试。';

  @override
  String get designRetry => '重试';

  @override
  String get designEmptyFilteredTitle => '没有符合的设计';

  @override
  String get designEmptyTitle => '暂无设计';

  @override
  String get designEmptyFilteredSubtitle => '尝试减少筛选条件以查看更多设计。';

  @override
  String get designEmptySubtitle => '设计单位将在此发布房屋设计，请稍后再来。';

  @override
  String get designPostYourDesign => '发布你的设计';

  @override
  String get designEndOfList => '— 到底了 —';

  @override
  String get designDefaultTitle => '设计方案';

  @override
  String get designUnitFallback => '单位';

  @override
  String get designDesignUnitFallback => '设计单位';

  @override
  String editProfUploadError(Object error) {
    return '上传错误：$error';
  }

  @override
  String get editProfCoverChanged => '封面已更换';

  @override
  String get editProfCoverChangeFailed => '更换封面失败';

  @override
  String get editProfPickBirthday => '选择出生日期';

  @override
  String get editProfWaitUpload => '请等待图片上传完成';

  @override
  String get editProfSaved => '资料已更新';

  @override
  String get editProfUpdateFailed => '更新失败';

  @override
  String get editProfEmailInUse => '该邮箱已被使用';

  @override
  String get editProfEyebrow => '账户';

  @override
  String get editProfChangeCover => '更换封面（房东）';

  @override
  String get editProfSectionPersonal => '个人信息';

  @override
  String get editProfFullName => '姓名';

  @override
  String get editProfRequired => '必填';

  @override
  String get editProfEmailHelper => '用于登录的邮箱';

  @override
  String get editProfEmailInvalid => '邮箱无效';

  @override
  String get editProfPhone => '电话号码';

  @override
  String get editProfSectionIntro => '简介';

  @override
  String get editProfBioLabel => '自我介绍';

  @override
  String get editProfBioHint => '例如：我是第一郡的房东，有5年出租公寓经验……';

  @override
  String get editProfSectionVerify => '验证（可选）';

  @override
  String get editProfIdNumber => '身份证号';

  @override
  String get editProfIdHelper => '如暂不验证请留空';

  @override
  String get editProfSave => '保存更改';

  @override
  String get editProfNotSelected => '未选择';

  @override
  String get editProfBirthday => '出生日期';

  @override
  String editProfAge(Object age) {
    return '年龄：$age';
  }

  @override
  String get hdBack => '返回';

  @override
  String get hdShare => '分享';

  @override
  String get hdLinkCopied => '已复制链接';

  @override
  String hdImageLabel(Object title, Object n) {
    return '$title — 图片 $n';
  }

  @override
  String get hdPerMonth => '/月';

  @override
  String get hdLoanCalc => '计算银行贷款';

  @override
  String hdBedroomsShort(Object n) {
    return '$n 室';
  }

  @override
  String hdBathroomsShort(Object n) {
    return '$n 卫';
  }

  @override
  String hdAreaSqm(Object area) {
    return '$area m²';
  }

  @override
  String get hdDescriptionTitle => '详细描述';

  @override
  String get hdHostInfoTitle => '房东信息';

  @override
  String get hdLoginToSave => '登录后收藏房源。';

  @override
  String get hdFavUpdateFailed => '无法更新收藏';

  @override
  String get hdApptApprovedTitle => '看房预约已通过';

  @override
  String hdApptApprovedSub(Object sched) {
    return '$sched · 请准时到达';
  }

  @override
  String get hdApptRejectedTitle => '看房预约被拒绝';

  @override
  String get hdApptRejectedSub => '您可以选择其他时间段';

  @override
  String get hdApptCancelledTitle => '您已取消看房预约';

  @override
  String get hdApptCancelledSub => '如仍想看房请重新预约';

  @override
  String get hdApptCompletedTitle => '您已看过此房';

  @override
  String get hdApptLockedTitle => '房间已锁定';

  @override
  String get hdApptPendingTitle => '您已预约看房';

  @override
  String hdApptPendingSub(Object sched) {
    return '$sched · 等待房东确认';
  }

  @override
  String get hdLegalRedBook => '红本（土地证）';

  @override
  String get hdLegalPinkBook => '粉本（房产证）';

  @override
  String get hdLegalSaleContract => '买卖合同';

  @override
  String get hdLegalPending => '等待产权证';

  @override
  String hdPricePerMonth(Object s) {
    return '$s 百万/月';
  }

  @override
  String get hdSpecPrice => '价格';

  @override
  String get hdSpecArea => '面积';

  @override
  String get hdSpecBedrooms => '卧室数量';

  @override
  String get hdSpecBathrooms => '卫生间数量';

  @override
  String get hdSpecType => '类型';

  @override
  String get hdSpecLegal => '法律状态';

  @override
  String get hdSpecFurniture => '家具';

  @override
  String hdRoomsCount(Object n) {
    return '$n 间';
  }

  @override
  String get hdPropertySpecsTitle => '房产特点';

  @override
  String get hdYourListing => '您的房源';

  @override
  String get hdViewBooking => '查看预约';

  @override
  String get hdRebookViewing => '重新预约看房';

  @override
  String get hdBookViewing => '预约看房';

  @override
  String get hdLoginToBook => '登录后预约看房。';

  @override
  String hdAreaHa(Object area) {
    return '$area 公顷';
  }

  @override
  String get hdIndPower => '电力负荷';

  @override
  String hdPowerMva(Object power) {
    return '$power MVA';
  }

  @override
  String get hdIndFireSafety => '消防';

  @override
  String get hdHas => '有';

  @override
  String get hdHasNot => '无';

  @override
  String get hdIndLegal => '工业园区法律';

  @override
  String get hdIndustrialSpecsTitle => '工业参数';

  @override
  String get hdForSale => '出售中';

  @override
  String get hdFull => '已满';

  @override
  String hdUnitsAvailable(Object available, Object total) {
    return '剩 $available/$total 间';
  }

  @override
  String get hdAvailable => '可入住';

  @override
  String get hdHost => '房东';

  @override
  String get hdHostVerifiedTooltip => '房东身份已验证';

  @override
  String get hdHostTrustedTooltip => '信誉房东：评价高、回复快';

  @override
  String hdResponseTime(Object h) {
    return '约 $h 小时回复';
  }

  @override
  String get hdHidden => '· 已隐藏';

  @override
  String get hdMessageHost => '联系房东';

  @override
  String get hdReviewsTitle => '评价';

  @override
  String get hdNoReviews => '暂无评价。';

  @override
  String hdViewAllReviews(Object count) {
    return '查看全部 $count 条评价';
  }

  @override
  String get hdUser => '用户';

  @override
  String get hubProviderChannel => '服务商渠道';

  @override
  String get hubEnterNameSelectService => '请输入单位名称并至少选择 1 项服务';

  @override
  String get hubProfileSubmitted => '资料已提交。等待审核后将显示在名录中。';

  @override
  String hubErrorWithMsg(Object error) {
    return '错误：$error';
  }

  @override
  String get hubBecomeProvider => '成为服务单位';

  @override
  String get hubRegisterService => '注册提供服务';

  @override
  String get hubRegisterIntro => '注册以接收客户需求并推广您的单位（设计／施工／室内）。';

  @override
  String get hubUnitName => '单位名称 *';

  @override
  String get hubUnitNameHint => '例如：建安建筑';

  @override
  String get hubField => '领域 *';

  @override
  String get hubOperatingArea => '经营区域';

  @override
  String get hubSelectProvince => '选择省/市';

  @override
  String get hubIntro => '简介';

  @override
  String get hubIntroHint => '经验、优势、规模……';

  @override
  String get hubContactPhone => '联系电话';

  @override
  String get hubSubmitRegistration => '提交注册资料';

  @override
  String get hubOwnerContact => '房主联系方式';

  @override
  String hubNameLabel(Object name) {
    return '姓名：$name';
  }

  @override
  String hubPhoneLabel(Object phone) {
    return '电话：$phone';
  }

  @override
  String get hubClose => '关闭';

  @override
  String get hubOwnerNotShared => '房主尚未分享联系方式。请稍候。';

  @override
  String hubCantViewContact(Object msg) {
    return '无法查看联系方式：$msg';
  }

  @override
  String get hubEditProfile => '编辑单位资料';

  @override
  String get hubAddCover => '添加封面图';

  @override
  String get hubChangeLogo => '更换单位标志';

  @override
  String get hubPhone => '电话号码';

  @override
  String get hubWebsite => '网站（如有）';

  @override
  String get hubYearEstablished => '成立年份';

  @override
  String get hubTeamSize => '团队规模';

  @override
  String hubPeopleSuffix(Object size) {
    return '$size 人';
  }

  @override
  String get hubCertNumber => '执业证书编号（如有）';

  @override
  String get hubCertHelper => '管理员将核对后授予徽章';

  @override
  String get hubCancel => '取消';

  @override
  String get hubSave => '保存';

  @override
  String get hubNameRequired => '单位名称不能为空';

  @override
  String get hubProfileUpdated => '资料已更新';

  @override
  String get hubDeleteProjectTitle => '删除作品？';

  @override
  String hubDeleteProjectConfirm(Object title) {
    return '从资料中删除\"$title\"？此操作无法撤销。';
  }

  @override
  String get hubThisProject => '此作品';

  @override
  String get hubDelete => '删除';

  @override
  String get hubDeleted => '已删除';

  @override
  String hubImageUploadFailed(Object error) {
    return '无法上传图片：$error';
  }

  @override
  String get hubQuoteSent => '报价已发送给客户';

  @override
  String get hubUnit => '单位';

  @override
  String get hubActive => '运营中';

  @override
  String get hubPendingApproval => '待审核';

  @override
  String get hubCertificate => '证书';

  @override
  String get hubPendingNote => '您的资料正在等待管理员审核。您仍可查看需求并发送报价；资料将在审核通过后显示在名录中。';

  @override
  String get hubEditProfileShort => '编辑资料';

  @override
  String get hubPostProject => '发布作品';

  @override
  String get hubMatchingNeeds => '匹配需求';

  @override
  String get hubNoMatchingNeeds => '暂无匹配需求。请稍后再来。';

  @override
  String get hubMyQuotes => '我的报价';

  @override
  String get hubProjectsDesigns => '作品与设计样板';

  @override
  String get hubNoProjects => '还没有作品';

  @override
  String get hubNoProjectsSub => '发布已完成的作品或设计样板，让客户了解您的实力。';

  @override
  String get hubPostFirstProject => '发布第一个作品';

  @override
  String get hubService => '服务';

  @override
  String get hubContactsYou => '联系您';

  @override
  String get hubSendQuote => '发送报价';

  @override
  String get hubWon => '已中选';

  @override
  String get hubNotSelected => '未中选';

  @override
  String get hubWaiting => '等待中';

  @override
  String get hubRequest => '需求';

  @override
  String hubQuoteAmount(Object amount) {
    return '报价：$amount';
  }

  @override
  String hubMilestoneLine(Object label, Object percent, Object amount) {
    return '• $label（$percent%）：$amount';
  }

  @override
  String get hubViewContact => '查看联系方式';

  @override
  String get hubWaitOwnerShare => '等待房主分享联系方式';

  @override
  String get hubBillion => '十亿';

  @override
  String get hubMillion => '百万';

  @override
  String get hubDong => '越南盾';

  @override
  String get hubProject => '作品';

  @override
  String get hubVerified => '已验证';

  @override
  String get hubSelfPosted => '自行发布';

  @override
  String hubDesignFiles(Object count) {
    return '$count 个设计文件';
  }

  @override
  String get hubEdit => '编辑';

  @override
  String get hubAmount => '金额（越南盾）*';

  @override
  String get hubAmountHint => '例如：1500000000';

  @override
  String get hubNoteOptional => '备注（可选）';

  @override
  String get hubSplitStages => '按阶段分期（30/20/20/30）';

  @override
  String get hubStagesSubtitle => '定金 · 概念 · 技术 · 交付';

  @override
  String get hubSend => '发送';

  @override
  String get myReqTitle => '我的服务请求';

  @override
  String get myReqEmpty => '你还没有预约任何服务';

  @override
  String get myReqContactSharedToast => '已将电话号码分享给施工单位';

  @override
  String myReqShareError(Object error) {
    return '无法分享：$error';
  }

  @override
  String get myReqQuoteAccepted => '已接受报价';

  @override
  String myReqAcceptError(Object error) {
    return '无法接受：$error';
  }

  @override
  String get myReqReviewThanks => '感谢您的评价！';

  @override
  String myReqReviewError(Object error) {
    return '错误：$error';
  }

  @override
  String get myReqServiceDesign => '设计';

  @override
  String get myReqServiceBuild => '建造';

  @override
  String get myReqServiceInterior => '室内装修';

  @override
  String get myReqServiceDefault => '服务';

  @override
  String get myReqStatusNew => '已发送';

  @override
  String get myReqStatusAssigned => '已对接施工单位';

  @override
  String get myReqStatusQuoted => '已收到报价';

  @override
  String get myReqStatusWon => '已成交';

  @override
  String get myReqStatusClosed => '已关闭';

  @override
  String get myReqNoQuotes => '暂无报价。施工单位将尽快回复。';

  @override
  String get myReqContractorDefault => '施工单位';

  @override
  String myReqQuoteAmount(Object amount) {
    return '报价：$amount';
  }

  @override
  String get myReqSelectedContractor => '已选择该施工单位';

  @override
  String get myReqReview => '评价';

  @override
  String get myReqContactSharedLabel => '已向施工单位分享联系方式';

  @override
  String get myReqShareContactBtn => '向施工单位分享电话';

  @override
  String get myReqAccept => '接受';

  @override
  String get myReqReviewTitle => '评价施工单位';

  @override
  String get myReqCritQuality => '质量';

  @override
  String get myReqCritTimeliness => '进度';

  @override
  String get myReqCritCommunication => '沟通';

  @override
  String get myReqCritBudget => '预算';

  @override
  String get myReqCritProfessionalism => '专业度';

  @override
  String get myReqDetailedRating => '详细评分（可选）';

  @override
  String get myReqCommentHint => '评论（可选）';

  @override
  String get myReqSend => '发送';

  @override
  String get pgalFileOpenError => '无法打开文件';

  @override
  String get pgalVerifySuccess => '已确认项目';

  @override
  String pgalErrorWith(Object error) {
    return '错误：$error';
  }

  @override
  String get pgalProjectFallback => '项目';

  @override
  String get pgalVerified => '已核实';

  @override
  String pgalDesignFilesCount(Object count) {
    return '设计文件（$count）';
  }

  @override
  String get pgalDesignUnit => '设计单位';

  @override
  String get pgalConfirmReal => '确认项目真实';

  @override
  String get pgalViewFirmProfile => '查看单位资料';

  @override
  String get pgalRequestConsult => '申请咨询';

  @override
  String get pgalSpecCode => '设计编号';

  @override
  String get pgalSpecHouseType => '房屋类型';

  @override
  String get pgalSpecStyle => '风格';

  @override
  String get pgalSpecFloors => '层数';

  @override
  String pgalFloorsValue(Object count) {
    return '$count 层';
  }

  @override
  String get pgalSpecBedrooms => '卧室';

  @override
  String pgalRoomsValue(Object count) {
    return '$count 间';
  }

  @override
  String get pgalSpecLandArea => '土地面积';

  @override
  String pgalLandAreaValue(Object width, Object length, Object total) {
    return '$width×${length}m（$total m²）';
  }

  @override
  String get pgalSpecBuildArea => '建筑面积';

  @override
  String pgalSqmValue(Object area) {
    return '$area m²';
  }

  @override
  String get pgalSpecYear => '设计年份';

  @override
  String get pgalSpecRegion => '地区';

  @override
  String get pgalSpecEstCost => '参考价格';

  @override
  String get pgalSpecTitle => '技术参数';

  @override
  String pgalCostBillion(Object value) {
    return '$value 十亿';
  }

  @override
  String pgalCostMillion(Object value) {
    return '$value 百万';
  }

  @override
  String pgalCostDong(Object value) {
    return '$value 越南盾';
  }

  @override
  String get pgalDescTitle => '设计说明';

  @override
  String get pgalCollapse => '收起';

  @override
  String get pgalExpand => '查看更多';

  @override
  String get pgalRelatedTitle => '相似方案';

  @override
  String get pgalDesignTemplate => '设计方案';

  @override
  String pgalBedroomsAbbr(Object count) {
    return '$count 卧';
  }

  @override
  String pgalSqmValueCompact(Object area) {
    return '${area}m²';
  }

  @override
  String get pgalDesignFirmName => '设计单位';

  @override
  String pgalRatingLine(Object rating, Object count) {
    return '⭐ $rating · $count 条评价';
  }

  @override
  String get pgalViewAllFirm => '查看该单位全部方案 →';

  @override
  String pgalDrawingIndex(Object index) {
    return '图纸/设计 $index';
  }

  @override
  String get postCardEdited => '已编辑';

  @override
  String get postCmtErrorLoad => '无法加载评论';

  @override
  String get postCmtLoginRequired => '登录后发表评论。';

  @override
  String get postCmtSendFailed => '发送评论失败';

  @override
  String get postCmtDeleteFailed => '删除评论失败';

  @override
  String get postCmtTitle => '评论';

  @override
  String get postCmtEmpty => '暂无评论，来抢沙发吧！';

  @override
  String get postCmtEdited => '已编辑';

  @override
  String postCmtMoreImages(Object count) {
    return '+$count 张图片';
  }

  @override
  String get postCmtDeleted => '评论已删除';

  @override
  String get postCmtReply => '回复';

  @override
  String get postCmtDelete => '删除';

  @override
  String postCmtReplyingTo(Object name) {
    return '正在回复 $name';
  }

  @override
  String get postCmtHint => '写评论……';

  @override
  String postCmtReplyHint(Object name) {
    return '回复 $name……';
  }

  @override
  String postHouseImagePickError(Object error) {
    return '选择图片出错：$error';
  }

  @override
  String get postHouseSelectRoomType => '请选择房间类型';

  @override
  String get postHouseWaitUpload => '请等待图片上传完成';

  @override
  String get postHouseNeedOneImage => '至少需要 1 张图片';

  @override
  String get postHousePostSuccess => '发布成功！';

  @override
  String get postHousePendingReviewTitle => '已提交 — 等待审核';

  @override
  String get postHousePendingReviewBody =>
      '高价值出售房源需管理员审核后才会公开显示（通常在24小时内）。您可在“我的 → 我发布的房源”查看状态。';

  @override
  String get commonUnderstood => '知道了';

  @override
  String get postHousePostFailed => '发布房源失败';

  @override
  String get postHouseUpdateSuccess => '已更新房源';

  @override
  String get postHouseUpdateFailed => '更新失败';

  @override
  String get postHouseEditTitle => '编辑房源';

  @override
  String get postHouseNewTitle => '发布新房源';

  @override
  String postHousePhotosLabel(Object label, Object current, Object max) {
    return '$label（$current/$max）';
  }

  @override
  String get postHousePropertyPhotos => '房产照片';

  @override
  String get postHouseRoomPhotos => '房间照片';

  @override
  String get postHouseListingCategory => '房源类别';

  @override
  String get postHouseTitleLabel => '标题';

  @override
  String get postHouseTitleHint => '例如：两居室，可看西贡河景';

  @override
  String get postHouseRequired => '必填';

  @override
  String get postHouseDescLabel => '描述';

  @override
  String get postHouseDescHint => '房间的详细描述……';

  @override
  String get postHouseDraftFoundTitle => '继续未完成的房源？';

  @override
  String get postHouseDraftFoundBody =>
      '您上次有一条尚未发布的房源。恢复后可继续填写，或放弃以重新开始。（图片需要重新选择。）';

  @override
  String get postHouseDraftRestore => '恢复';

  @override
  String get postHouseDraftDiscard => '放弃草稿';

  @override
  String get postHouseDescLabelOptional => '描述（选填）';

  @override
  String get postHouseDescTemplateBtn => '插入描述模板';

  @override
  String get postHouseDescTemplate =>
      '• 位置：靠近市场/学校/车站……\n• 设施：空调、热水器、停车位……\n• 其他费用：电费、水费、网费……\n• 看房联系：';

  @override
  String get postHousePropertyType => '房产类型';

  @override
  String get postHouseRoomType => '房间类型';

  @override
  String get postHouseSelectType => '选择类型';

  @override
  String get postHouseSalePrice => '售价（₫）';

  @override
  String get postHouseRentPrice => '月租（₫）';

  @override
  String get postHousePerMonth => '/月';

  @override
  String get postHouseSalePriceHint => '例如：2,500,000,000';

  @override
  String get postHouseRentPriceHint => '例如：8,000,000';

  @override
  String get postHouseArea => '面积（m²）';

  @override
  String get postHouseAreaHint => '例如：65';

  @override
  String get postHouseAddress => '地址';

  @override
  String get postHouseAddressHint => '门牌号、街道……';

  @override
  String get postHouseAddressNeedsDetail => '地图仅能定位到坊/乡一级——请补充门牌号和街道名称。';

  @override
  String get postHouseProvince => '省 / 市';

  @override
  String get postHouseSelectProvince => '选择省/市';

  @override
  String get postHouseWard => '坊 / 社';

  @override
  String get postHouseLoading => '加载中……';

  @override
  String get postHouseSelectWard => '选择坊/社';

  @override
  String get postHouseMapLocation => '地图位置';

  @override
  String get postHouseMapHint => '点击地图以标记准确位置（地址将自动填充）。';

  @override
  String postHousePinnedAt(Object lat, Object lng) {
    return '已标记：$lat, $lng';
  }

  @override
  String get postHouseBedrooms => '卧室';

  @override
  String get postHouseBathrooms => '卫生间';

  @override
  String get postHouseLegal => '产权状态';

  @override
  String get postHouseSaveChanges => '保存更改';

  @override
  String get postHouseSell => '发布出售';

  @override
  String get postHouseRent => '发布出租';

  @override
  String get postHouseAddPhoto => '添加照片';

  @override
  String get postHouseCoverPhoto => '封面照片';

  @override
  String get postHouseRetry => '重试';

  @override
  String get postHouseListingForm => '发布形式';

  @override
  String get postHouseSemanticRent => '房源类型：出租';

  @override
  String get postHouseSemanticSale => '房源类型：出售';

  @override
  String get postHouseSingleTitle => '1 套 / 1 间';

  @override
  String get postHouseSingleSubtitle => '整套住房、独立公寓';

  @override
  String get postHouseMultiTitle => '多间房';

  @override
  String get postHouseMultiSubtitle => '出租楼、迷你公寓、旅舍……';

  @override
  String get postHouseLegalRedBook => '红本（土地证）';

  @override
  String get postHouseLegalPinkBook => '粉本（产权证）';

  @override
  String get postHouseLegalSaleContract => '买卖合同';

  @override
  String get postHouseLegalPending => '待发证';

  @override
  String get postHouseTotalUnits => '房间总数';

  @override
  String get postHouseTotalUnitsHint => '例如：10';

  @override
  String get postHouseAvailableUnits => '空余';

  @override
  String get postHouseAvailableUnitsHint => '例如：7';

  @override
  String get postHousePriorityTenant => '优先对象';

  @override
  String get postHouseGenderAny => '不限';

  @override
  String get postHouseGenderMale => '男';

  @override
  String get postHouseGenderFemale => '女';

  @override
  String get profPersonal => '个人';

  @override
  String get profLoginPrompt => '登录以管理个人资料、发布的房源、预约和设置。';

  @override
  String get profAccount => '账户';

  @override
  String get profSettings => '设置';

  @override
  String get profYourPosts => '你的帖子';

  @override
  String get profSavedListings => '已保存房源';

  @override
  String profAgeYears(Object count) {
    return '$count 岁';
  }

  @override
  String get profListings => '房源';

  @override
  String get profAppointmentsStat => '预约';

  @override
  String get profFavorites => '收藏';

  @override
  String get profMine => '我的';

  @override
  String get profPostedListings => '已发布房源';

  @override
  String get profPostedListingsSubtitle => '管理你出租的房间';

  @override
  String get profViewingAppointments => '看房预约';

  @override
  String get profViewingAppointmentsSubtitle => '你的看房预约';

  @override
  String get profConstructionServices => '施工服务';

  @override
  String get profMyServiceRequests => '我的服务请求';

  @override
  String get profMyServiceRequestsSubtitle => '跟踪报价并选择承包商';

  @override
  String get profProviderChannel => '服务商中心';

  @override
  String get profProviderChannelSubtitle => '公司资料、匹配需求、我的报价';

  @override
  String get profBecomeProvider => '您是施工／设计单位吗？';

  @override
  String get profBecomeProviderSubtitle => '注册资料即可接收客户的报价请求';

  @override
  String get profRoleAdmin => '管理员';

  @override
  String get profRoleMember => '会员';

  @override
  String get profModeGuest => '租客';

  @override
  String get profModeHost => '房东';

  @override
  String get profBecomeHost => '成为房东';

  @override
  String get profBecomeHostSubtitle => '上架房间、迎接房客、收款 — 仅需 2 分钟。';

  @override
  String get reelCmtLoadFailed => '无法加载评论。';

  @override
  String get reelCmtLoginToComment => '登录后即可评论。';

  @override
  String get reelCmtRateLimited => '您评论得有点快，请过几分钟再试。';

  @override
  String get reelCmtSendFailed => '发送评论失败。';

  @override
  String get reelCmtDeleteTitle => '删除评论？';

  @override
  String get reelCmtDelete => '删除';

  @override
  String get reelCmtDeleteFailed => '删除评论失败。';

  @override
  String reelCmtCountLabel(Object count) {
    return '$count 条评论';
  }

  @override
  String reelCmtReplyingTo(Object name) {
    return '正在回复 $name';
  }

  @override
  String get reelCmtInputHint => '写评论…';

  @override
  String get reelCmtEmpty => '还没有评论。\n来做第一个吧！';

  @override
  String get reelCmtDefaultUser => '用户';

  @override
  String get reelCmtDeletedComment => '评论已删除';

  @override
  String get reelCmtReply => '回复';

  @override
  String get reelCompTitle => '创建 Reel';

  @override
  String get reelCompPost => '发布';

  @override
  String get reelCompUploading => '正在上传视频…';

  @override
  String reelCompUploaded(Object name) {
    return '已上传：$name';
  }

  @override
  String get reelCompPickVideo => '从相册选择视频';

  @override
  String get reelCompLimits => '最长 90 秒 · 120MB · 任意格式';

  @override
  String get reelCompCaption => '说明';

  @override
  String get reelCompCaptionHint => '简短描述你的视频…';

  @override
  String get reelCompShowIn => '显示在板块';

  @override
  String get reelCompCatAll => '全部板块';

  @override
  String get reelCompCatLease => '租赁';

  @override
  String get reelCompCatIndustrial => '工业';

  @override
  String get reelCompCatDesign => '设计';

  @override
  String get reelCompCatBuild => '建筑';

  @override
  String get reelCompCatInterior => '室内';

  @override
  String get reelCompErrVideoTooLarge => '视频过大（最大 120MB）。请录制更短的视频。';

  @override
  String get reelCompErrUploadFailed => '视频上传失败。请检查网络连接后重试。';

  @override
  String get reelCompErrNoVideo => '请先选择视频。';

  @override
  String get reelCompSentTitle => '已提交，等待审核';

  @override
  String get reelCompSentBody =>
      '视频正在处理中（标准化 + 生成封面），随后管理员会审核，通过后才会公开显示。你可以在\"我的 Reel\"中查看状态。';

  @override
  String get reelCompGotIt => '知道了';

  @override
  String get reelCompErrRateLimit => '你今天已发布 5 个 Reel（上限）。请稍后再试。';

  @override
  String get reelCompErrSubmitFailed => '发布 Reel 失败。请重试。';

  @override
  String get reelViewDataSaverOn => '已开启省流量模式 — 视频不会自动播放。';

  @override
  String get reelViewDataSaverOff => '已关闭省流量模式。';

  @override
  String get reelViewLoginToLike => '登录后即可点赞该短视频。';

  @override
  String get reelViewLoginToReport => '登录后即可举报该短视频。';

  @override
  String get reelViewReasonSpam => '垃圾信息 / 广告';

  @override
  String get reelViewReasonInappropriate => '不当内容';

  @override
  String get reelViewReasonCopyright => '侵犯版权';

  @override
  String get reelViewReasonMisleading => '虚假信息 / 诈骗';

  @override
  String get reelViewReasonOther => '其他原因';

  @override
  String get reelViewReportTitle => '举报短视频';

  @override
  String get reelViewReportSuccess => '举报已提交。感谢您帮助维护社区安全。';

  @override
  String get reelViewReportFailed => '举报提交失败。';

  @override
  String get reelViewLinkCopied => '已复制短视频链接。';

  @override
  String get reelViewDataSaverTooltipOn => '省流量模式：开';

  @override
  String get reelViewDataSaverTooltipOff => '省流量模式：关';

  @override
  String get reelViewVideoError => '无法播放该视频';

  @override
  String reelViewViewCount(Object count) {
    return '$count 次观看';
  }

  @override
  String get reelViewShare => '分享';

  @override
  String get reelViewUnmute => '开启声音';

  @override
  String get reelViewMute => '关闭声音';

  @override
  String get reelViewReport => '举报';

  @override
  String get roleWelcomeTitle => '欢迎来到 Vua Nhà';

  @override
  String get roleLater => '稍后';

  @override
  String get roleQuestion => '您以什么身份加入?';

  @override
  String get roleSubtitle => '选择一项,我们将带您前往合适的页面。您之后可以更改或补充。';

  @override
  String get roleSeekerTitle => '我在找房子 / 服务';

  @override
  String get roleSeekerSubtitle => '浏览租售房源,寻找施工单位。';

  @override
  String get roleHostTitle => '我是房东';

  @override
  String get roleHostSubtitle => '发布您的房产出租 / 出售信息。';

  @override
  String get roleProviderTitle => '我是施工 / 设计单位';

  @override
  String get roleProviderSubtitle => '建立单位档案,接收客户的报价请求。';

  @override
  String get socialLoginToInteract => '登录以与社区互动。';

  @override
  String get socialDeletePostTitle => '删除帖子';

  @override
  String get socialDeletePostConfirm => '确定要删除这篇帖子吗？';

  @override
  String get socialDelete => '删除';

  @override
  String get socialDeleteFailed => '删除帖子失败';

  @override
  String get socialAll => '全部';

  @override
  String get socialWhatsOnMind => '你在想什么？';

  @override
  String get socialPostPhoto => '发布照片';

  @override
  String get socialNoPostsInCategory => '该分类下还没有帖子';

  @override
  String get socialNoPosts => '还没有任何帖子';

  @override
  String get socialBeFirstToShare => '来做第一个分享的人吧！';

  @override
  String get socialEndOfFeed => '— 没有更多帖子 —';

  @override
  String get socialErrorOccurred => '发生错误';

  @override
  String get socialRetry => '重试';

  @override
  String get surveyEyebrow => '个人';

  @override
  String get surveyMyInterestsTitle => '我的兴趣';

  @override
  String get surveySkip => '跳过';

  @override
  String get surveyGreeting => '你好 👋';

  @override
  String get surveyIntro => '告诉 Vua Nhà 你关心什么，以便个性化你的体验。可以多选。';

  @override
  String get surveyWhatDoYouWant => '你想做什么？';

  @override
  String get surveyRealEstateSection => '房地产';

  @override
  String get surveyConstructionSection => '建筑';

  @override
  String get surveyConstructionInterest => '感兴趣的施工领域';

  @override
  String get surveyAreaOptional => '感兴趣的地区（可选）';

  @override
  String get surveyYouAreTitle => '您的身份？';

  @override
  String get surveyIAmProvider => '我是施工／设计／室内单位';

  @override
  String get surveyIAmProviderHint => '选择后默认进入施工版块，并可接收客户的报价请求';

  @override
  String get surveyProvinceHint => '选择省/市';

  @override
  String get surveySave => '保存';

  @override
  String get surveyStartExploring => '开始探索';

  @override
  String get surveyPrefsUpdated => '偏好已更新';

  @override
  String get surveyInterestRent => '租房';

  @override
  String get surveyInterestBuy => '买房置地';

  @override
  String get surveyInterestSellOrList => '出租 / 发布房源';

  @override
  String get surveyInterestFindService => '寻找施工单位';

  @override
  String get surveyInterestFollowConstruction => '关注建筑行业资讯';

  @override
  String get surveyServiceDesign => '设计';

  @override
  String get surveyServiceBuild => '建造';

  @override
  String get surveyServiceInterior => '室内装修';

  @override
  String get surveyServiceIndustrial => '工业地产';

  @override
  String get loanTitle => '贷款计算';

  @override
  String get loanHomePrice => '房价（越南盾）';

  @override
  String get loanHomePriceHint => '例如：2000000000';

  @override
  String loanDownPayment(Object pct) {
    return '首付：$pct%';
  }

  @override
  String get loanInterestRate => '利率（%/年）';

  @override
  String get loanInterestRateHint => '例如：10';

  @override
  String loanTerm(Object years) {
    return '期限：$years 年';
  }

  @override
  String loanYearsShort(Object years) {
    return '$years 年';
  }

  @override
  String get loanMethod => '还款方式';

  @override
  String get loanMethodReducing => '递减余额';

  @override
  String get loanMethodAnnuity => '每月等额还款';

  @override
  String get loanInvalidPrice => '请输入有效的房价';

  @override
  String loanCalcFailed(Object error) {
    return '无法计算：$error';
  }

  @override
  String get loanMonthlyPayment => '每月还款';

  @override
  String get loanFirstMonthPayment => '首月还款';

  @override
  String loanLastMonth(Object amount) {
    return '末月：$amount';
  }

  @override
  String get loanPrincipal => '贷款金额';

  @override
  String get loanTotalInterest => '利息总额';

  @override
  String get loanTotalPayment => '还款总额';

  @override
  String get loanTermLabel => '期限';

  @override
  String loanTermValue(Object months, Object years) {
    return '$months 个月（$years 年）';
  }

  @override
  String get loanDisclaimer => '结果仅供参考；实际利率由银行确定。';

  @override
  String get apptChipPending => '待审核';

  @override
  String get apptChipApproved => '已批准';

  @override
  String get apptChipCompleted => '已完成';

  @override
  String get apptChipCancelled => '已取消';

  @override
  String get apptChipRejected => '已拒绝';

  @override
  String get apptChipLocked => '已锁定房间';

  @override
  String get apptChipLost => '已被他人预订';

  @override
  String get blockLoginToInteract => '登录以与社区互动。';

  @override
  String get blockDeletePostTitle => '删除帖子';

  @override
  String get blockDeletePostConfirm => '确定要删除这篇帖子吗？';

  @override
  String get blockDelete => '删除';

  @override
  String get blockDeletePostFailed => '删除帖子失败';

  @override
  String get blockCommunity => '社区';

  @override
  String get blockCompose => '发帖';

  @override
  String blockReelsCategory(Object name) {
    return '$name Reels';
  }

  @override
  String get blockUnitList => '单位列表';

  @override
  String get blockSearchByLocation => '按地区搜索…';

  @override
  String get blockProvince => '省 / 市';

  @override
  String get blockWard => '街道 / 乡镇';

  @override
  String get blockKeywordHint => '关键词（内容 / 地区）…';

  @override
  String get blockSearch => '搜索';

  @override
  String get blockClearFilter => '清除筛选';

  @override
  String blockNoPostsIn(Object name) {
    return '$name 中还没有帖子';
  }

  @override
  String get blockBeFirstToShare => '来做第一个分享的人吧！';

  @override
  String get blockNoMorePosts => '— 没有更多帖子 —';

  @override
  String get chgpwdSuccess => '密码修改成功';

  @override
  String get chgpwdFailed => '密码修改失败';

  @override
  String get chgpwdCurrentLabel => '当前密码';

  @override
  String get chgpwdNewLabel => '新密码';

  @override
  String get chgpwdConfirmLabel => '确认新密码';

  @override
  String get chgpwdRequired => '必填';

  @override
  String get chgpwdMinLength => '至少6个字符';

  @override
  String get chgpwdMismatch => '密码不一致';

  @override
  String get clandEyebrow => '施工';

  @override
  String clandDefaultDesc(Object serviceName) {
    return '连接可靠的$serviceName服务商。';
  }

  @override
  String get clandDisclaimer => 'Vua Nhà 是中介连接平台——合同和付款由双方直接进行。';

  @override
  String get clandRequestQuote => '请求咨询／报价';

  @override
  String get clandViewContractors => '查看承包商';

  @override
  String get composerPickImageFailed => '无法选择图片';

  @override
  String get composerSelectCategoryPrompt => '请为帖子选择一个分类';

  @override
  String get composerPostFailed => '发布失败，请重试';

  @override
  String get composerEditTitle => '编辑帖子';

  @override
  String get composerCreateTitle => '创建帖子';

  @override
  String get composerSave => '保存';

  @override
  String get composerPost => '发布';

  @override
  String get composerContentHint => '你在想什么？';

  @override
  String get composerSelectCategoryLabel => '选择分类 *';

  @override
  String get composerLocationHint => '地点（可选）— 例如：胡志明市第7郡';

  @override
  String get composerPhotos => '图片';

  @override
  String get composerDiscardTitle => '放弃这篇帖子？';

  @override
  String get composerDiscardBody => '您正在编辑的内容将不会被保存。';

  @override
  String get composerKeepEditing => '继续编辑';

  @override
  String get composerDiscard => '放弃';

  @override
  String composerImagesCount(Object count, Object max) {
    return '$count/$max 张图片';
  }

  @override
  String ctrListTitle(Object name) {
    return '承包商 · $name';
  }

  @override
  String get ctrListEmptyTitle => '该地区暂无承包商';

  @override
  String get ctrListEmptyBody => '提交需求 — 我们将为您对接合适的服务方。';

  @override
  String get ctrListRequestConsult => '申请咨询';

  @override
  String get ctrListDefaultName => '承包商';

  @override
  String get ctrListBadgePromoted => '精选';

  @override
  String get ctrListBadgePro => '专业版';

  @override
  String get myPostsLoadError => '无法加载帖子';

  @override
  String get myPostsLoadErrorHint => '请检查网络连接后重试。';

  @override
  String get myPostsRetry => '重试';

  @override
  String get myPostsEmptyTitle => '您还没有任何帖子';

  @override
  String get myPostsEmptyHint => '您在社区发布的帖子将显示在这里。';

  @override
  String get plistSearchHint => '按名称、描述、地址搜索…';

  @override
  String get plistEmptyTitle => '未找到匹配的房源';

  @override
  String get plistEmptySubtitle => '请尝试其他关键词或稍后再来。';

  @override
  String plistAreaSqm(Object area) {
    return '$area m²';
  }

  @override
  String get qualityTitle => '设施质量';

  @override
  String get qualityVerified => '已核实';

  @override
  String get qualitySelfDeclared => '房东自报';

  @override
  String get qualitySubtitle => '设施评分 — 影响价格区间。';

  @override
  String qualityStarRating(Object star) {
    return '$star/5';
  }

  @override
  String qualitySuggestedPrice(Object price) {
    return '按质量建议价格：$price/月';
  }

  @override
  String get qualityNotDeclared => '尚未申报质量。';

  @override
  String get qualityUpdateButton => '更新质量';

  @override
  String get qualityDeclareButton => '申报房屋质量';

  @override
  String get qualityVerifRequested => '已提交核实申请';

  @override
  String get qualityRequestVerification => '申请实地核实';

  @override
  String get qualityVerifSubmitted => '核实申请已提交。团队将联系您进行检查。';

  @override
  String qualityRequestFailed(Object error) {
    return '无法发送请求：$error';
  }

  @override
  String get reviewTitle => '评价';

  @override
  String get reviewRatePrompt => '给这个房子打几星？';

  @override
  String reviewStarTooltip(Object count) {
    return '$count 星';
  }

  @override
  String get reviewCommentLabel => '你的感受';

  @override
  String get reviewCommentHint => '例如：房东友善、房间干净、与描述相符……';

  @override
  String get reviewSubmitButton => '提交评价';

  @override
  String get reviewSubmitSuccess => '评价已提交，谢谢你！';

  @override
  String reviewSubmitError(Object error) {
    return '提交评价失败：$error';
  }

  @override
  String rfqTitle(Object serviceName) {
    return '咨询请求 · $serviceName';
  }

  @override
  String get rfqSubtitle => '免费 · 不会公开分享您的电话号码';

  @override
  String get rfqFieldName => '姓名 *';

  @override
  String get rfqFieldPhone => '电话号码 *';

  @override
  String get rfqFieldArea => '区域（省/区）';

  @override
  String get rfqFieldBudget => '预计预算（可选）';

  @override
  String get rfqFieldDesc => '描述您的需求';

  @override
  String get rfqSubmit => '发送请求';

  @override
  String get rfqValidation => '请输入有效的姓名和电话号码';

  @override
  String get rfqSendError => '请求发送失败。请检查网络连接后重试。';

  @override
  String get rfqSuccessTitle => '请求已发送！';

  @override
  String rfqSuccessBody(Object serviceName) {
    return '$serviceName 团队将尽快与您联系。';
  }

  @override
  String get rfqClose => '关闭';

  @override
  String get searchHint => '搜索房源、施工单位、社区帖子…';

  @override
  String get searchEmptyTitle => '在 Vua Nhà 上搜索一切';

  @override
  String get searchEmptySubtitle => '租赁房源、施工/设计单位、社区帖子…';

  @override
  String get searchRecentTitle => '最近搜索';

  @override
  String get searchClearAll => '全部清除';

  @override
  String searchNoResults(Object query) {
    return '未找到“$query”';
  }

  @override
  String get searchNoResultsSubtitle => '请尝试去掉声调或使用其他关键词。';

  @override
  String get searchGroupHouses => '房源';

  @override
  String get searchGroupContractors => '单位';

  @override
  String get searchGroupPosts => '社区帖子';

  @override
  String get searchHouseFallback => '房源';

  @override
  String get searchContractorFallback => '单位';

  @override
  String searchRating(Object rating, Object count) {
    return '⭐ $rating · $count 条评价';
  }

  @override
  String get settingsMyPreferences => '我的偏好';

  @override
  String get settingsMyPreferencesSub => '按目的和区域个性化';

  @override
  String get settingsLogoutConfirm => '确定要退出登录吗？';

  @override
  String get settingsLoggedOut => '已退出登录';

  @override
  String get wishEyebrow => '已收藏';

  @override
  String get wishTitle => '收藏';

  @override
  String get wishCompareTooltip => '对比';

  @override
  String get wishRefreshTooltip => '刷新';

  @override
  String get wishEmptyTitle => '暂无房源';

  @override
  String get wishEmptySubtitle => '点击喜欢房源上的爱心即可保存到这里。';

  @override
  String get wishUnfavoriteTooltip => '取消收藏';

  @override
  String get wishUnfavoriteError => '无法取消收藏';

  @override
  String get hApprovalInboxTitle => '审批收件箱';

  @override
  String get hApprovalInboxEyebrow => '房主 · 审批';

  @override
  String get hApprovalEmptyTitle => '没有请求';

  @override
  String get hApprovalEmptySubtitle => '当运营人员需要审批时，请求将显示在此处。';

  @override
  String hApprovalBiometricReason(Object amount) {
    return '验证身份以批准 $amount 交易';
  }

  @override
  String get hApprovalBiometricRequired => '需要生物识别验证才能继续';

  @override
  String get hApprovalApproveSuccess => '审批成功';

  @override
  String get hApprovalApproveFailed => '审批失败。请重试。';

  @override
  String get hApprovalRejectSuccess => '请求已拒绝';

  @override
  String get hApprovalRejectReasonTitle => '拒绝理由';

  @override
  String get hApprovalRejectReasonHint => '理由（可选）';

  @override
  String get hApprovalSkip => '跳过';

  @override
  String get hApprovalReject => '拒绝';

  @override
  String get hApptTitle => '看房请求';

  @override
  String get hApptEmpty => '暂无请求。';

  @override
  String hApptCompletedDeals(Object count) {
    return '$count 笔已完成交易';
  }

  @override
  String get hApptRateGuest => '评价客户';

  @override
  String hApptRateGuestTitle(Object name) {
    return '评价 $name';
  }

  @override
  String get hApptGuestFallback => '客户';

  @override
  String get hApptReviewHint => '评论（可选）';

  @override
  String get hApptCancel => '取消';

  @override
  String get hApptSend => '发送';

  @override
  String get hApptReviewSuccess => '已评价客户';

  @override
  String hApptReviewFailed(Object error) {
    return '无法提交评价：$error';
  }

  @override
  String get hApptEmptyHintPending => '当客户发送看房请求时，将显示在此处。';

  @override
  String get hApptEmptyHintApproved => '暂无已批准的预约。';

  @override
  String get hApptEmptyHintPast => '暂无已关闭或被拒绝的请求。';

  @override
  String get hApptTabPending => '待审批';

  @override
  String get hApptTabApproved => '已批准';

  @override
  String get hApptTabClosed => '已关闭';

  @override
  String get hAvailTitle => '看房时段';

  @override
  String get hAvailWeekdaysSection => '每周接待客户的日子';

  @override
  String get hAvailSlotsSection => '接待客户的时段（每段1小时）';

  @override
  String get hAvailSelectAll => '全选';

  @override
  String get hAvailDeselect => '取消选择';

  @override
  String get hAvailSave => '保存时段';

  @override
  String get hAvailSavedToast => '已保存看房时段。';

  @override
  String get hAvailSaveFailed => '保存失败';

  @override
  String get hAvailIntroDefault => '您目前在所有日期和所有时段都接受看房。如果只想在特定时间接待客户，请缩小范围。';

  @override
  String get hAvailIntroCustom => '客户只能在您下方选择的日期和时段预约看房。';

  @override
  String get hAvailEmptyWarning => '未选择任何日期或时段——客户将无法预约看房。';

  @override
  String get hAvailMon => '周一';

  @override
  String get hAvailTue => '周二';

  @override
  String get hAvailWed => '周三';

  @override
  String get hAvailThu => '周四';

  @override
  String get hAvailFri => '周五';

  @override
  String get hAvailSat => '周六';

  @override
  String get hAvailSun => '周日';

  @override
  String get hContractDetTitle => '合同';

  @override
  String get hContractDetNotFound => '未找到合同';

  @override
  String get hContractDetStartDate => '开始日期';

  @override
  String get hContractDetEndDate => '结束日期';

  @override
  String get hContractDetRent => '租金';

  @override
  String hContractDetRentPerMonth(Object amount) {
    return '$amount đ/月';
  }

  @override
  String get hContractDetDeposit => '押金';

  @override
  String hContractDetAmountDong(Object amount) {
    return '$amount đ';
  }

  @override
  String get hContractDetTenants => '租客';

  @override
  String get hContractDetRepresentative => '代表';

  @override
  String get hContractDetActivate => '激活合同';

  @override
  String get hContractDetCheckout => '退房（结束）';

  @override
  String get hContractDetTransferRoom => '换房';

  @override
  String get hContractDetActualEndDate => '实际退房日期';

  @override
  String get hContractDetDepositRefund => '押金退还';

  @override
  String get hContractDetDamage => '损坏';

  @override
  String get hContractDetStatusDraft => '草稿';

  @override
  String get hContractDetStatusActive => '生效中';

  @override
  String get hContractDetStatusExpired => '已过期';

  @override
  String get hContractDetStatusTerminated => '已结束';

  @override
  String get hContractDetActivateEyebrow => '激活';

  @override
  String get hContractDetActivateConfirmMsg => '激活此合同会将房间状态改为\"出租中\"。是否继续？';

  @override
  String get hContractDetActivateSuccess => '合同已激活';

  @override
  String get hContractDetFailed => '失败';

  @override
  String get hContractFormTitle => '新合同';

  @override
  String get hContractFormEyebrow => '表单';

  @override
  String get hContractFormStartDate => '开始日期 *';

  @override
  String get hContractFormEndDate => '结束日期 *';

  @override
  String get hContractFormMonthlyRent => '月租金（越南盾）*';

  @override
  String get hContractFormRentInvalid => '请输入有效金额';

  @override
  String get hContractFormDeposit => '押金（越南盾）';

  @override
  String get hContractFormSubmit => '创建合同';

  @override
  String get hContractFormSelectDates => '请选择开始和结束日期';

  @override
  String get hContractFormEndAfterStart => '结束日期必须晚于开始日期';

  @override
  String get hContractFormOnePrimary => '必须有且仅有 1 位主承租人（代表）';

  @override
  String get hContractFormTenantNameRequired => '承租人姓名不能为空';

  @override
  String get hContractFormCreated => '合同已创建（状态：草稿）';

  @override
  String get hContractFormCreateFailed => '创建失败';

  @override
  String hContractFormPhotoUploadFailed(Object error) {
    return '图片上传失败：$error';
  }

  @override
  String hContractFormCccdUploadFailed(Object error) {
    return '身份证照片上传失败：$error';
  }

  @override
  String hContractTermUploadFailed(Object error) {
    return '图片上传失败：$error';
  }

  @override
  String get hContractTermActionEnd => '结束合同';

  @override
  String get hContractTermPickDateFirst => '请选择实际退房日期';

  @override
  String get hContractTermEnd => '结束';

  @override
  String get hContractTermConfirmTitle => '确认结束合同';

  @override
  String get hContractTermConfirmMessage => '确定要结束此合同吗？\n此操作无法撤销。';

  @override
  String get hContractTermDoneEnded => '合同已结束';

  @override
  String get hContractTermFailed => '失败';

  @override
  String get hContractTermMoveOut => '退房';

  @override
  String get hContractTermIntro => '确认实际退房日期及押金退还信息。';

  @override
  String get hContractTermActualEndDate => '实际退房日期 *';

  @override
  String get hContractTermPickDate => '选择日期';

  @override
  String get hContractTermRefundAmount => '押金退还金额（越南盾）';

  @override
  String get hContractTermRefundHelper => '若不退还请输入 0';

  @override
  String get hContractTermDamageNote => '损坏备注';

  @override
  String get hContractTermDamageNoteHelper => '如有损坏请描述';

  @override
  String get hContractTermDamagePhotos => '损坏照片';

  @override
  String get hContractTermAddPhoto => '添加照片';

  @override
  String get hContractTermConfirmMoveOut => '确认退房';

  @override
  String get hContractXferTransferRoom => '转房';

  @override
  String get hContractXferActionTransfer => '转房';

  @override
  String get hContractXferContractEyebrow => '合同';

  @override
  String get hContractXferIntro => '选择楼栋和空房，将合同转移过去。';

  @override
  String get hContractXferBuildingLabel => '楼栋 *';

  @override
  String get hContractXferNoBuildings => '没有楼栋';

  @override
  String get hContractXferSelectBuilding => '选择楼栋';

  @override
  String get hContractXferNoVacantRooms => '该楼栋没有空房。';

  @override
  String get hContractXferVacantRoomLabel => '空房 *';

  @override
  String get hContractXferSelectRoom => '选择房间';

  @override
  String hContractXferRoomOption(Object code, Object price) {
    return '$code — $price 越南盾/月';
  }

  @override
  String get hContractXferConfirmTitle => '确认转房';

  @override
  String hContractXferConfirmMessage(Object roomName) {
    return '确定要将合同转移到房间 $roomName 吗？\n原房间将变为“空房”。';
  }

  @override
  String hContractXferSuccess(Object roomName) {
    return '合同已转移到房间 $roomName';
  }

  @override
  String get hContractXferFailed => '失败';

  @override
  String get hContractXferLoadRoomsError => '无法加载房间';

  @override
  String get hDelegDetNotFound => '未找到';

  @override
  String get hDelegDetNotFoundDelegation => '未找到委托';

  @override
  String get hDelegDetOperator => '运营方';

  @override
  String get hDelegDetEyebrow => '房东 · 管理委托';

  @override
  String get hDelegDetPausedToast => '已暂停委托';

  @override
  String get hDelegDetResumedToast => '已恢复委托';

  @override
  String get hDelegDetTerminateTitle => '终止委托？';

  @override
  String get hDelegDetTerminateBody => '运营方将在 30 天后失去访问权限。此操作无法撤销。';

  @override
  String get hDelegDetTerminate => '终止';

  @override
  String get hDelegDetTerminatedToast => '已终止委托';

  @override
  String get hDelegDetThresholdsUpdatedToast => '已更新审批阈值';

  @override
  String hDelegDetPermissionLabel(Object role) {
    return '权限：$role';
  }

  @override
  String hDelegDetStartLabel(Object date) {
    return '开始：$date';
  }

  @override
  String hDelegDetPropertiesLabel(Object count) {
    return '资产：$count';
  }

  @override
  String get hDelegDetStatusActive => '运行中';

  @override
  String get hDelegDetStatusPaused => '已暂停';

  @override
  String get hDelegDetStatusTerminated => '已终止';

  @override
  String get hDelegDetRoleOperatorFull => '完整运营';

  @override
  String get hDelegDetRoleAccountant => '会计';

  @override
  String get hDelegDetRoleViewer => '仅查看';

  @override
  String get hDelegDetRoleOwnerView => '房东（查看）';

  @override
  String get hDelegDetPause => '暂停';

  @override
  String get hDelegDetResume => '继续';

  @override
  String get hDelegDetThresholds => '审批阈值';

  @override
  String get hDelegDetEdit => '编辑';

  @override
  String get hDelegDetSaveThresholds => '保存阈值';

  @override
  String get hDelegInvTitle => '邀请运营方';

  @override
  String get hDelegInvEyebrow => '房主 · 委托';

  @override
  String get hDelegInvOperatorInfo => '运营方信息';

  @override
  String get hDelegInvOperatorEmail => '运营方邮箱';

  @override
  String get hDelegInvPermissions => '权限';

  @override
  String get hDelegInvThresholds => '审批阈值 (VND)';

  @override
  String get hDelegInvSend => '发送邀请';

  @override
  String get hDelegInvRoleOperatorFull => '完整运营';

  @override
  String get hDelegInvRoleAccountant => '会计';

  @override
  String get hDelegInvRoleViewer => '仅查看';

  @override
  String get hDelegInvEmailRequired => '请输入邮箱';

  @override
  String get hDelegInvEmailInvalid => '邮箱无效';

  @override
  String get hDelegInvSendSuccess => '邀请已成功发送';

  @override
  String get hDelegInvSendFailed => '无法发送邀请。请重试。';

  @override
  String get hFeeTitle => '服务费';

  @override
  String get hFeeCreateBuildingFirst => '请先创建楼宇';

  @override
  String get hFeeEmptyTitle => '暂无服务费';

  @override
  String get hFeeEmptySubtitle => '添加服务费以进行管理。';

  @override
  String get hFeeMonthly => '每月';

  @override
  String get hFeeOneTime => '一次性';

  @override
  String get hFeeActive => '启用';

  @override
  String get hFeeInactive => '停用';

  @override
  String get hFeeEnterNameBuilding => '请输入名称和楼宇';

  @override
  String get hFeeSaveFailed => '保存失败';

  @override
  String get hFeeCreateTitle => '添加服务费';

  @override
  String get hFeeBuilding => '楼宇';

  @override
  String get hFeeServiceName => '服务名称';

  @override
  String get hFeeUnitPrice => '单价 (VND)';

  @override
  String get hFeeCycle => '周期';

  @override
  String get hFeeSave => '保存';

  @override
  String get hHomeDlgActionDelete => '删除房源';

  @override
  String get hHomeDlgDeleteTitle => '删除房源';

  @override
  String hHomeDlgDeleteBody(Object title) {
    return '确定要删除\"$title\"吗？';
  }

  @override
  String get hHomeDlgDeleteConfirm => '删除';

  @override
  String get hHomeDlgDeleteSuccess => '已删除房源';

  @override
  String get hHomeDlgDeleteFail => '删除失败';

  @override
  String get hHomeDlgActionCloseUnit => '关闭房间';

  @override
  String get hHomeDlgCloseUnitTitle => '关闭一个房间';

  @override
  String hHomeDlgCloseUnitBody(Object title) {
    return '确认已将\"$title\"的一间房出租给应用外的人？可用房间数将减少1，待处理的看房请求将自动被通知为\"已被预订\"。';
  }

  @override
  String get hHomeDlgCloseUnitConfirm => '关闭房间';

  @override
  String get hHomeDlgCloseUnitSuccess => '已关闭一个房间';

  @override
  String get hHomeDlgCloseUnitFail => '操作失败';

  @override
  String get hHomeDlgLockTitle => '锁定房间';

  @override
  String hHomeDlgLockBody(Object house, Object guest) {
    return '确认将房间\"$house\"出租给$guest？同一房间的其他看房请求将自动关闭，客人将收到通知。';
  }

  @override
  String get hHomeDlgLockDefaultHouse => '此房间';

  @override
  String get hHomeDlgLockDefaultGuest => '此客人';

  @override
  String get hHomeDlgLockConfirm => '锁定';

  @override
  String get hHomeDlgLockSuccess => '已为客人锁定房间';

  @override
  String get hHomeDlgLockFail => '锁定失败';

  @override
  String get hHomeListingsTotalEyebrow => '房源总数';

  @override
  String get hHomeListingsTotalCaption => '迄今发布的所有房源';

  @override
  String get hHomeListingsPendingEyebrow => '待审核';

  @override
  String get hHomeListingsPendingCaption => '等待管理员审核';

  @override
  String get hHomeListingsApprovedEyebrow => '已发布';

  @override
  String get hHomeListingsApprovedCaption => '公开显示';

  @override
  String get hHomeListingsSectionListings => '房源列表';

  @override
  String get hHomeListingsEmptyListingsLine => '暂无房源。';

  @override
  String get hHomeListingsEmptyListingsHint => '点击\"发布新房源\"创建第一条房源。';

  @override
  String get hHomeListingsSectionAppointments => '看房预约请求';

  @override
  String get hHomeListingsEmptyAppointmentsLine => '没有待处理的看房请求。';

  @override
  String get hHomeListingsEmptyAppointmentsHint => '当有客户预约时，将显示在这里。';

  @override
  String get hHomeListingsPostNew => '发布新房源';

  @override
  String get hHomeRoomsKpiCollected => '已收';

  @override
  String get hHomeRoomsKpiUnpaid => '欠款';

  @override
  String get hHomeRoomsKpiOccupancy => '入住率';

  @override
  String get hHomeRoomsQuickCreateInvoice => '创建账单';

  @override
  String get hHomeRoomsQuickMeter => '抄水电表';

  @override
  String get hHomeRoomsQuickReminder => '催缴欠款';

  @override
  String get hHomeRoomsQuickReports => '报表';

  @override
  String get hHomeRoomsTodoHeader => '今日待办';

  @override
  String get hHomeRoomsSectionBilling => '收支';

  @override
  String get hHomeRoomsInvoicesTitle => '账单';

  @override
  String get hHomeRoomsInvoicesSubtitle => '账单列表与开具';

  @override
  String get hHomeRoomsDebtTitle => '应收账款';

  @override
  String get hHomeRoomsDebtSubtitle => '按房间跟踪欠款';

  @override
  String get hHomeRoomsServiceFeesTitle => '服务费';

  @override
  String get hHomeRoomsServiceFeesSubtitle => '配置电/水/服务费';

  @override
  String get hHomeRoomsSectionOps => '其他运营';

  @override
  String get hHomeRoomsLeadsTitle => '感兴趣的客户';

  @override
  String get hHomeRoomsLeadsSubtitle => '预约看房与收藏';

  @override
  String get hHomeRoomsKhaiBaoTitle => '暂住登记';

  @override
  String get hHomeRoomsHomestayTitle => '民宿';

  @override
  String get hHomeRoomsSyncTitle => '同步至其他平台';

  @override
  String get hHomeRoomsAnalyticsTitle => '营收统计';

  @override
  String get hHomeRoomsAnalyticsSubtitle => '5项KPI • 营收、入住率、ADR';

  @override
  String get hIntroAppBarTitle => '成为房东';

  @override
  String get hIntroEyebrow => 'ANCU365  ·  房东版';

  @override
  String get hIntroHeadline => '开放房间，\n迎接房客，\n收取租金。';

  @override
  String get hIntroSubtitle =>
      '通过 An Cu 365 直接在手机上运营您的出租房和民宿——从发布房源、审核房客到签订合同和结算账单。';

  @override
  String get hIntroBenefitsLabel => '您能获得什么';

  @override
  String get hIntroBenefit1Title => '管理楼栋和房间';

  @override
  String get hIntroBenefit1Body => '在一个电子账本中跟踪房间状态、合同和水电表。';

  @override
  String get hIntroBenefit2Title => '直接接收看房请求';

  @override
  String get hIntroBenefit2Body => '房客预约时间——您可在应用内直接批准或拒绝，无需零散的消息往来。';

  @override
  String get hIntroBenefit3Title => '开具账单和完成租约';

  @override
  String get hIntroBenefit3Body => '根据水电表自动计算水电费；签订合同并集中存储。';

  @override
  String get hIntroBenefit4Title => '多渠道展示';

  @override
  String get hIntroBenefit4Body => '房源展示在探索页和房源地图上，触达数千名房客。';

  @override
  String get hIntroCta => '开始注册';

  @override
  String get hIntroCtaNote => '需要 2–3 分钟。需提供身份证 + 收款账户信息。';

  @override
  String get hInvBatchTitle => '批量生成账单';

  @override
  String get hInvBatchBuildingLabel => '楼栋 *';

  @override
  String get hInvBatchSelectBuilding => '选择楼栋';

  @override
  String get hInvBatchMonthLabel => '月份 (YYYY-MM) *';

  @override
  String get hInvBatchSelectMonth => '选择月份';

  @override
  String get hInvBatchElecPriceLabel => '电费单价 (VND/kWh)';

  @override
  String get hInvBatchWaterPriceLabel => '水费单价 (VND/m³)';

  @override
  String get hInvBatchGenerateButton => '生成账单';

  @override
  String get hInvBatchHelpText => '系统为楼栋内每份生效合同生成账单（草稿状态）。若该周期账单已存在，系统将跳过（幂等）。';

  @override
  String get hInvBatchSelectRequired => '请选择楼栋和月份';

  @override
  String get hInvBatchCreateFailed => '生成失败';

  @override
  String get hInvDetSentSuccess => '发票已发送 — 公开链接已就绪';

  @override
  String hInvDetCannotOpen(Object url) {
    return '无法打开：$url';
  }

  @override
  String get hInvDetTitle => '发票详情';

  @override
  String hInvDetPeriod(Object start, Object end) {
    return '周期 $start → $end';
  }

  @override
  String hInvDetDue(Object date) {
    return '到期 $date';
  }

  @override
  String get hInvDetDetails => '明细';

  @override
  String get hInvDetTotal => '总计';

  @override
  String get hInvDetCollected => '已收';

  @override
  String get hInvDetRemaining => '剩余';

  @override
  String get hInvDetSendInvoice => '发送发票';

  @override
  String get hInvDetRecordPayment => '登记付款';

  @override
  String get hInvDetOpenPublicLink => '打开公开链接';

  @override
  String get hInvDetRemindZalo => '通过 Zalo 提醒';

  @override
  String get hInvDetCreditNote => '创建贷记单（调整）';

  @override
  String get hKhaibaoTitle => '申报详情';

  @override
  String get hKhaibaoShareSubject => '暂住申报表';

  @override
  String get hKhaibaoDeclaredRecorded => '已记录申报';

  @override
  String get hKhaibaoSaveFailed => '保存失败';

  @override
  String get hKhaibaoSkipped => '已跳过';

  @override
  String get hKhaibaoPhone => '电话号码';

  @override
  String get hKhaibaoRoom => '房间';

  @override
  String get hKhaibaoBuilding => '楼宇';

  @override
  String get hKhaibaoCheckInDate => '入住日期';

  @override
  String get hKhaibaoLinkExpires => '链接过期时间';

  @override
  String get hKhaibaoDeclaredAt => '申报时间';

  @override
  String get hKhaibaoSkipReason => '跳过原因';

  @override
  String get hKhaibaoViewForm => '查看申报表 (TK1)';

  @override
  String get hKhaibaoMarkDeclared => '已申报';

  @override
  String get hKhaibaoSkipEarlyLeave => '跳过（客人提前离开）';

  @override
  String get hKhaibaoSkipHint => '例如：客人提前离开';

  @override
  String get hKhaibaoSkip => '跳过';

  @override
  String get hLeadsTitle => '感兴趣的客户';

  @override
  String hLeadsTabTarget(Object count) {
    return '目标 ($count)';
  }

  @override
  String hLeadsTabPotential(Object count) {
    return '潜在 ($count)';
  }

  @override
  String hLeadsLoadError(Object error) {
    return '无法加载：$error';
  }

  @override
  String get hLeadsEmptyTarget => '还没有客户预约看您的房源。';

  @override
  String get hLeadsEmptyPotential => '还没有客户将您的房源加入心愿单。';

  @override
  String get hLeadsBadgeBooked => '已预约';

  @override
  String get hLeadsBadgeBookViewing => '预约看房';

  @override
  String get hLeadsBadgeSaved => '已收藏';

  @override
  String get hLeadsDefaultName => '访客';

  @override
  String get hLeadsDefaultHouse => '房产';

  @override
  String get hListingsTitle => '我的房源';

  @override
  String get hListingsRefresh => '刷新';

  @override
  String get hListingsPostRoom => '发布房源';

  @override
  String get hListingsEmptyTitle => '您还没有发布任何房源';

  @override
  String get hListingsEmptyHint => '点击\"发布房源\"创建您的第一条房源。';

  @override
  String get hListingsEdit => '编辑房源';

  @override
  String get hListingsDelete => '删除房源';

  @override
  String get hListingsDeleteTitle => '删除房源';

  @override
  String hListingsDeleteConfirm(Object title) {
    return '确定要删除\"$title\"吗？';
  }

  @override
  String get hListingsDeleteAction => '删除';

  @override
  String get hListingsDeleteSuccess => '已删除房源';

  @override
  String get hListingsDeleteFailed => '删除失败';

  @override
  String get hListingsStatusApproved => '发布中';

  @override
  String get hListingsStatusPending => '待审核';

  @override
  String get hListingsStatusRejected => '已拒绝';

  @override
  String get hListingsStatusHidden => '已隐藏';

  @override
  String get hProfileSavedInfo => '信息已保存';

  @override
  String get hProfileSaveFailed => '保存失败';

  @override
  String get hProfileEyebrow => '账户';

  @override
  String get hProfileTitle => '房东资料';

  @override
  String get hProfileEdit => '编辑';

  @override
  String get hProfileEmptyTitle => '暂无资料';

  @override
  String get hProfileEmptySubtitle => '请完成入驻流程以创建房东资料。';

  @override
  String get hProfileSaveChanges => '保存更改';

  @override
  String get hProfileVerified => '账户已验证';

  @override
  String get hProfilePending => '等待验证';

  @override
  String get hProfileVerifiedDesc => '您可以发布房源并接收付款。';

  @override
  String get hProfilePendingDesc => '上传身份证以完成验证。';

  @override
  String get hProfileIdentitySection => '身份验证';

  @override
  String get hProfileCccdFront => '身份证正面';

  @override
  String get hProfileCccdBack => '身份证背面';

  @override
  String get hProfileUploaded => '已上传';

  @override
  String get hProfileNotUploaded => '未上传';

  @override
  String get hProfilePaymentSection => '付款信息';

  @override
  String get hProfileBank => '银行';

  @override
  String get hProfileBankHint => '例如：Vietcombank';

  @override
  String get hProfileAccountNumber => '账号';

  @override
  String get hProfileAccountHolder => '账户持有人';

  @override
  String get hProfileAccountHolderHint => '卡上姓名';

  @override
  String get hProfileTaxId => '税号';

  @override
  String get hProfilePerformanceSection => '绩效';

  @override
  String get hProfileRating => '评分';

  @override
  String get hProfileAvgResponse => '平均响应';

  @override
  String get hProfileHours => '小时';

  @override
  String get hResvDetTitle => '预订详情';

  @override
  String get hResvDetNotFound => '未找到订单';

  @override
  String get hResvDetError => '错误';

  @override
  String get hResvDetReasonHint => '原因…';

  @override
  String get hResvDetConfirm => '确认';

  @override
  String get hResvDetCheckIn => '入住';

  @override
  String get hResvDetCheckOut => '退房';

  @override
  String get hResvDetNights => '晚数';

  @override
  String get hResvDetPhone => '电话';

  @override
  String get hResvDetEmail => '电子邮件';

  @override
  String get hResvDetTotal => '总金额';

  @override
  String get hResvDetRefund => '退款';

  @override
  String get hResvDetCancelledAt => '取消时间';

  @override
  String get hResvDetReason => '原因';

  @override
  String get hResvDetApprove => '批准订单';

  @override
  String get hResvDetApproved => '已批准';

  @override
  String get hResvDetReject => '拒绝';

  @override
  String get hResvDetRejectReason => '拒绝原因';

  @override
  String get hResvDetRejected => '已拒绝';

  @override
  String get hResvDetCheckedIn => '已入住';

  @override
  String get hResvDetCheckedOut => '已退房';

  @override
  String get hResvDetCancel => '取消订单';

  @override
  String get hResvDetCancelReason => '取消原因';

  @override
  String get hResvDetCancelled => '订单已取消';

  @override
  String get hResvListTitle => '预订';

  @override
  String get hResvListFilterAll => '全部';

  @override
  String get hResvListFilterPending => '待审核';

  @override
  String get hResvListFilterApproved => '已批准';

  @override
  String get hResvListFilterCheckedIn => '入住中';

  @override
  String get hResvListFilterCheckedOut => '已退房';

  @override
  String get hResvListFilterCancelled => '已取消';

  @override
  String get hResvListEmptyTitle => '没有预订';

  @override
  String get hResvListEmptySubtitle => '暂无符合此筛选条件的预订。';

  @override
  String hResvListNights(Object count) {
    return '$count 晚';
  }

  @override
  String get hRoomDetMaintEyebrow => '维护申报';

  @override
  String get hRoomDetMaintTitle => '将房间设为维护中';

  @override
  String get hRoomDetConfirm => '确认';

  @override
  String hRoomDetMaintSetFrom(Object start) {
    return '已设置从 $start 起维护';
  }

  @override
  String get hRoomDetFailed => '失败';

  @override
  String get hRoomDetEndMaintEyebrow => '结束维护';

  @override
  String get hRoomDetEndMaintTitle => '确认结束？';

  @override
  String get hRoomDetEndMaintBody => '房间将恢复为空置状态。';

  @override
  String get hRoomDetEnd => '结束';

  @override
  String get hRoomDetMaintEnded => '已结束维护';

  @override
  String hRoomDetDuplicated(Object code) {
    return '已创建副本 $code';
  }

  @override
  String get hRoomDetHeader => '房间档案';

  @override
  String get hRoomDetNotFound => '未找到房间';

  @override
  String get hRoomDetDuplicate => '复制房间';

  @override
  String get hRoomDetSetMaint => '设置维护';

  @override
  String get hRoomDetEndMaint => '结束维护';

  @override
  String get hStep1Eyebrow => '第 1 步 / 共 3 步';

  @override
  String get hStep1Title => '注册成为房东';

  @override
  String get hStep1SectionTitle => '个人信息';

  @override
  String get hStep1Subtitle => '请填写完整信息以验证您的房东账户。';

  @override
  String get hStep1NameLabel => '姓名';

  @override
  String get hStep1NameHint => '张三';

  @override
  String get hStep1NameError => '请输入姓名';

  @override
  String get hStep1PhoneLabel => '电话号码';

  @override
  String get hStep1PhoneError => '电话号码无效';

  @override
  String get hStep1DobLabel => '出生日期';

  @override
  String get hStep1AddressLabel => '常住地址';

  @override
  String get hStep1AddressHint => '门牌号、街道、乡/镇、区/县、省/市';

  @override
  String get hStep1AddressError => '请输入地址';

  @override
  String get hStep1Next => '下一步';

  @override
  String get hStep1InitError => '初始化资料失败';

  @override
  String get hStep2WarnAtLeastOne => '请至少上传身份证的一面';

  @override
  String get hStep2UploadFailed => '上传失败';

  @override
  String get hStep2Eyebrow => '步骤 2 / 3';

  @override
  String get hStep2Title => '验证身份证';

  @override
  String get hStep2Heading => '上传身份证';

  @override
  String get hStep2Subtitle => '请上传身份证正反面照片以验证身份。';

  @override
  String get hStep2FrontLabel => '身份证正面';

  @override
  String get hStep2BackLabel => '身份证背面';

  @override
  String get hStep2SecurityNote => '您的身份证照片经过加密并安全存储。我们不会将此信息分享给第三方。';

  @override
  String get hStep2Next => '下一步';

  @override
  String get hStep3Eyebrow => '第 3 / 3 步';

  @override
  String get hStep3Title => '付款信息';

  @override
  String get hStep3ReceivingAccount => '收款账户';

  @override
  String get hStep3Subtitle => '输入您的银行账户以接收租客的付款。';

  @override
  String get hStep3BankLabel => '银行 *';

  @override
  String get hStep3BankHint => '选择银行';

  @override
  String get hStep3BankRequired => '请选择银行';

  @override
  String get hStep3AccountNumber => '账号';

  @override
  String get hStep3AccountNumberRequired => '请输入账号';

  @override
  String get hStep3AccountNumberInvalid => '账号无效';

  @override
  String get hStep3AccountHolder => '账户持有人姓名';

  @override
  String get hStep3AccountHolderRequired => '请输入账户持有人姓名';

  @override
  String get hStep3TaxId => '税号（可选）';

  @override
  String get hStep3SubmitButton => '完成注册';

  @override
  String get hStep3SaveFailed => '保存失败';

  @override
  String get adminCtrTitle => '审核单位';

  @override
  String get adminCtrApproved => '已通过资料';

  @override
  String get adminCtrCertVerified => '证书已核实';

  @override
  String adminCtrError(Object error) {
    return '错误：$error';
  }

  @override
  String get adminCtrRejectTitle => '拒绝该资料？';

  @override
  String get adminCtrRejectBody => '该资料将不会显示在名录中。';

  @override
  String get adminCtrCancel => '取消';

  @override
  String get adminCtrReject => '拒绝';

  @override
  String get adminCtrRejected => '已拒绝';

  @override
  String get adminCtrLoadFailed => '加载失败';

  @override
  String get adminCtrLoadFailedHint => '请检查网络后重试。';

  @override
  String get adminCtrRetry => '重试';

  @override
  String get adminCtrEmptyTitle => '没有待审核的资料';

  @override
  String get adminCtrEmptyHint => '新资料将显示在这里。';

  @override
  String get adminCtrCompanyFallback => '单位';

  @override
  String adminCtrCertNumber(Object number) {
    return '执业证：$number';
  }

  @override
  String get adminCtrCertVerifiedLabel => '已核实';

  @override
  String get adminCtrVerify => '核实';

  @override
  String get adminCtrApprove => '通过';

  @override
  String get adminHomeTitle => '管理员控制台';

  @override
  String get adminHomePending => '待审核';

  @override
  String get adminHomeApproved => '已通过';

  @override
  String get adminHomeRejected => '已拒绝';

  @override
  String get adminHomePublished => '已发布';

  @override
  String get adminHomeUsers => '用户';

  @override
  String get adminHomeToolModerateReel => '审核\nReel';

  @override
  String get adminHomeToolVerifyQueue => '审核\n队列';

  @override
  String get adminHomeToolPlanningRisk => '规划\n风险';

  @override
  String get adminHomeToolTrustedMark => '信誉\n标记';

  @override
  String get adminHomeToolApproveContractor => '审核\n单位';

  @override
  String get adminHomeToolMarketResearch => '市场\n调研';

  @override
  String get adminHomeEmptyPending => '没有待审核的房源';

  @override
  String get adminHomeEmptyApproved => '暂无已通过的房源';

  @override
  String get adminHomeEmptyRejected => '暂无被拒绝的房源';

  @override
  String adminHomeHost(Object name) {
    return '房东：$name';
  }

  @override
  String get adminHomeReject => '拒绝';

  @override
  String get adminHomeApprove => '通过';

  @override
  String get adminHomeReapprove => '重新通过';

  @override
  String get adminHomeUnpublish => '下架';

  @override
  String get adminHomeRejectReasonTitle => '拒绝原因';

  @override
  String get adminHomeRejectReasonHint => '填写原因，让房东知道如何修改……';

  @override
  String get adminHomeMsgApproved => '已通过房源';

  @override
  String get adminHomeMsgRejected => '已拒绝房源';

  @override
  String get adminHomeMsgUpdated => '已更新房源';

  @override
  String get adminHomeMsgFailed => '操作失败';

  @override
  String get adminReelEyebrow => '审核';

  @override
  String get adminReelTitle => '短视频';

  @override
  String get adminReelTabPending => '待审核';

  @override
  String get adminReelTabHidden => '已隐藏';

  @override
  String get adminReelTabPublished => '已发布';

  @override
  String get adminReelEmpty => '没有短视频';

  @override
  String get adminReelStatsTitle => '运营指标（30 天）';

  @override
  String get adminReelStatReels => '短视频';

  @override
  String get adminReelStatPending => '待审核';

  @override
  String get adminReelStatViews => '播放量';

  @override
  String get adminReelStatLikes => '点赞';

  @override
  String get adminReelStatComments => '评论';

  @override
  String get adminReelStatStorage => '存储';

  @override
  String get adminReelStatFailures => '处理失败';

  @override
  String get adminReelNoCaption => '（无说明）';

  @override
  String adminReelReportCount(Object count) {
    return '$count 条举报';
  }

  @override
  String adminReelRejectReason(Object reason) {
    return '原因：$reason';
  }

  @override
  String get adminReelApprove => '通过';

  @override
  String get adminReelHide => '隐藏';

  @override
  String get adminReelReject => '拒绝';

  @override
  String get adminReelRejectTitle => '拒绝短视频';

  @override
  String get adminReelReasonLabel => '原因 *';

  @override
  String get adminReelReasonHint => '例如：内容不相关';

  @override
  String get adminReelApproved => '已通过 — 短视频已公开显示';

  @override
  String get adminReelRejected => '已拒绝短视频';

  @override
  String get adminReelHidden => '已隐藏短视频';

  @override
  String adminReelActionFailed(Object error) {
    return '操作失败：$error';
  }

  @override
  String get adminVerifTitle => '审核队列';

  @override
  String get adminVerifEmpty => '没有请求';

  @override
  String adminVerifLoadError(Object error) {
    return '无法加载：$error';
  }

  @override
  String adminVerifRateDialogTitle(Object title) {
    return '评定审核星级 — $title';
  }

  @override
  String get adminVerifProperty => '房产';

  @override
  String adminVerifStarsLabel(Object count) {
    return '$count 星';
  }

  @override
  String get adminVerifConfirm => '确认';

  @override
  String get adminVerifRatedToast => '已评定审核星级。';

  @override
  String adminVerifError(Object error) {
    return '错误：$error';
  }

  @override
  String adminVerifSubtitle(Object status, Object date) {
    return '状态：$status · 请求：$date';
  }

  @override
  String get adminVerifVerifyButton => '审核';

  @override
  String get hActionItemsHeader => '待处理';

  @override
  String get hActionItemsOverdueInvoices => '逾期账单';

  @override
  String get hActionItemsExpiringContracts => '即将到期的合同';

  @override
  String get hActionItemsOverdueKhaiBao => '逾期暂住登记';

  @override
  String get hActionItemsMaintenanceRooms => '维护中的房间';

  @override
  String get hActionItemsZaloFailed => '无法创建 Zalo 提醒';

  @override
  String hActionItemsInvoiceDue(Object dueDate, Object amount) {
    return '到期 $dueDate · 剩余 $amount VND';
  }

  @override
  String get hActionItemsRemindZalo => '通过 Zalo 提醒';

  @override
  String hActionItemsContractRoom(Object contractId, Object roomId) {
    return '合同 #$contractId · 房间 $roomId';
  }

  @override
  String hActionItemsContractExpiry(Object endDate, Object rent) {
    return '到期 $endDate · $rent VND/月';
  }

  @override
  String hActionItemsTenant(Object tenantId) {
    return '租客 #$tenantId';
  }

  @override
  String hActionItemsCheckIn(Object checkInAt) {
    return '入住 $checkInAt';
  }

  @override
  String hActionItemsMaintenanceSince(Object startDate) {
    return '自 $startDate';
  }

  @override
  String get hActionItemsMaintenanceActive => '维护中';

  @override
  String get hAnalyticsFilterSelectPeriod => '选择时段';

  @override
  String get hAnalyticsFilterTitle => '筛选';

  @override
  String get hAnalyticsFilterActive => '筛选中';

  @override
  String get hAnalyticsFilterBuilding => '楼栋';

  @override
  String get hAnalyticsFilterSource => '收入来源';

  @override
  String get hAnalyticsFilterRoomType => '房间类型';

  @override
  String get hAnalyticsFilterPeriod => '时段';

  @override
  String get hAnalyticsFilterClearPeriod => '清除时段';

  @override
  String get hAnalyticsFilterManageSources => '管理来源';

  @override
  String get hAnalyticsFilterReset => '重置';

  @override
  String get hAnalyticsFilterApply => '应用';

  @override
  String get hCreateContractTitle => '创建草稿合同';

  @override
  String get hCreateContractViewRequestEyebrow => '看房请求';

  @override
  String get hCreateContractGuest => '客户';

  @override
  String get hCreateContractRequestCode => '请求编号';

  @override
  String get hCreateContractWhatHappens => '将会发生';

  @override
  String get hCreateContractWhatHappensBody =>
      '• 看房请求 → 状态\"已批准\"。\n• 创建一个临时租户（或复用电话号码相同的现有租户）。\n• 一份草稿合同（来源 = marketplace）关联该租户与源房间。\n• 在激活前，您可继续编辑合同（开始日期、押金…）。';

  @override
  String get hCreateContractConfirm => '确认创建草稿合同';

  @override
  String get hCreateContractCreating => '创建中…';

  @override
  String get hCreateContractError => '错误';

  @override
  String hCreateContractCreatedDraft(Object id, Object suffix) {
    return '已创建草稿合同 #$id $suffix';
  }

  @override
  String get hCreateContractPlaceholderTenant => '（临时租户）';

  @override
  String get hPublishTitle => '发布到市场';

  @override
  String get hPublishListingType => '房源类型';

  @override
  String get hPublishTitleLabel => '标题（可选）';

  @override
  String get hPublishDescLabel => '描述（可选）';

  @override
  String get hPublishDescHint => '设施、位置、注意事项…';

  @override
  String get hPublishPriceLabel => '显示价格（越南盾，留空则使用 base_price）';

  @override
  String get hPublishPriceHint => '例如：3500000';

  @override
  String get hPublishSubmitting => '发布中…';

  @override
  String get hPublishSubmit => '确认发布';

  @override
  String get hPublishHelp => '房源需经管理员审核后才会公开显示。您可随时从同步页面重新隐藏。';

  @override
  String get hPublishSyncSuccess => '房源已同步到市场';

  @override
  String get hPublishError => '错误';

  @override
  String get hPublishTypeBoardingHouse => '出租房';

  @override
  String get hPublishTypeHomestay => '民宿';

  @override
  String get hPublishTypeApartment => '公寓';

  @override
  String get hSyncTitle => '市场同步';

  @override
  String get hSyncHideListingTitle => '隐藏房源';

  @override
  String hSyncHideConfirm(Object roomCode) {
    return '从市场中隐藏房间 $roomCode？房源将切换为\"隐藏\"状态，不会被删除。之后可重新发布。';
  }

  @override
  String get hSyncHideAction => '隐藏房源';

  @override
  String get hSyncHidden => '房源已隐藏';

  @override
  String get hSyncError => '错误';

  @override
  String get hSyncEmptyTitle => '暂无可同步的房间';

  @override
  String get hSyncEmptySubtitle => '添加房间即可开始与市场同步。';

  @override
  String hSyncMarketplaceStatus(Object status) {
    return '市场状态：$status';
  }

  @override
  String hSyncLastSynced(Object time) {
    return '上次同步：$time';
  }

  @override
  String get hSyncPublish => '发布到市场';

  @override
  String get hSyncResync => '重新同步';

  @override
  String get hSyncHide => '隐藏';

  @override
  String get opDiscloseTitle => '共享账户通知';

  @override
  String get opDiscloseBody => '您正在使用共享的企业账户。请注意：';

  @override
  String get opDisclosePointAudit => '所有操作都会以共享账户身份记录在审计日志中。';

  @override
  String get opDisclosePointPassword => '更改密码是贵公司的责任。系统不会在出现异常登录时发出警报。';

  @override
  String get opDisclosePointRbac => '企业内的个人权限管理（RBAC v2）将在后续版本中推出。';

  @override
  String get opDiscloseAcknowledge => '我明白了';

  @override
  String opDiscloseAckError(Object error) {
    return '记录时出错：$error';
  }

  @override
  String get opInviteTitle => '委托邀请';

  @override
  String get opInviteEyebrow => '运营方 · 邀请';

  @override
  String get opInviteEmptyTitle => '暂无邀请';

  @override
  String get opInviteEmptySubtitle => '当房东邀请您时，邀请将显示在此处。';

  @override
  String get opInviteOwnerFallback => '房东';

  @override
  String opInviteSentDate(Object date) {
    return '发送时间：$date';
  }

  @override
  String get opInviteStatusPending => '待确认';

  @override
  String get opInviteReject => '拒绝';

  @override
  String get opInviteAccept => '接受';

  @override
  String get opInviteAcceptSuccess => '已成功接受委托';

  @override
  String get opInviteAcceptError => '无法接受，请重试。';

  @override
  String get opInviteRejectSuccess => '已拒绝邀请';

  @override
  String get opInviteRoleFull => '权限：完整运营';

  @override
  String get opInviteRoleAccountant => '权限：会计';

  @override
  String get opInviteRoleViewer => '权限：仅查看';

  @override
  String opInviteRoleOther(Object preset) {
    return '权限：$preset';
  }

  @override
  String get opInviteRoleUnknown => '未知';

  @override
  String get tenantReportSubmittedTitle => '举报已提交';

  @override
  String get tenantReportSubmittedHeadline => '您的举报已收到';

  @override
  String get tenantReportSubmittedSubtitle => '我们将进行审核并在24小时内与您联系。';

  @override
  String get tenantReportBackHome => '返回首页';

  @override
  String get tenantReportTitle => '举报代理人';

  @override
  String get tenantReportEyebrow => '租客 · 举报';

  @override
  String get tenantReportDisclosure => '如果您不认识自称是房东代理人的人，请立即举报。您的信息将被保密。';

  @override
  String get tenantReportReasonLabel => '原因';

  @override
  String get tenantReportReasonUnknownPerson => '此人不是我认识的代理人';

  @override
  String get tenantReportReasonDifferentInfo => '信息与上门收款的人不符';

  @override
  String get tenantReportReasonNoNotice => '房东尚未通知我';

  @override
  String get tenantReportReasonOther => '其他原因';

  @override
  String get tenantReportDetailLabel => '补充说明（可选）';

  @override
  String get tenantReportDetailHint => '请进一步描述事件……';

  @override
  String get tenantReportSubmitButton => '提交举报';

  @override
  String tenantReportSubmitFailed(Object error) {
    return '举报提交失败：$error';
  }

  @override
  String get auditTitle => '活动日志';

  @override
  String auditRepresentative(Object name) {
    return '代表 · $name';
  }

  @override
  String get auditOwnerFallback => '房主';

  @override
  String get auditPeriodToday => '今天';

  @override
  String get auditPeriodWeek => '本周';

  @override
  String get auditPeriodMonth => '本月';

  @override
  String get auditLoadError => '无法加载数据';

  @override
  String get auditRetry => '重试';

  @override
  String get auditEmptyTitle => '暂无活动';

  @override
  String get auditEmptySubtitle => '运营人员的操作将显示在此处。';

  @override
  String get auditTlOperator => '操作员';

  @override
  String get auditTlOwner => '房主';

  @override
  String get auditTlAction => '操作';

  @override
  String get auditTlJustNow => '刚刚';

  @override
  String auditTlMinutesAgo(Object minutes) {
    return '$minutes分钟前';
  }

  @override
  String auditTlHoursAgo(Object hours) {
    return '$hours小时前';
  }

  @override
  String auditTlDaysAgo(Object days) {
    return '$days天前';
  }

  @override
  String get forgotValidateEmail => '请输入邮箱';

  @override
  String get forgotDialogEyebrow => '恢复';

  @override
  String get forgotDialogTitle => '临时密码';

  @override
  String get forgotDialogBody => '您的账户密码已重置。请使用下面的临时密码登录，然后立即修改：';

  @override
  String get forgotCopied => '已复制';

  @override
  String get forgotGotIt => '知道了';

  @override
  String forgotError(Object error) {
    return '错误：$error';
  }

  @override
  String get forgotAppBarEyebrow => '支持';

  @override
  String get forgotTitle => '忘记密码';

  @override
  String get forgotIntro => '输入您的账户邮箱——系统将生成一个临时密码，供您登录后立即修改。';

  @override
  String get forgotEmailHint => 'you@example.com';

  @override
  String get forgotSubmit => '生成临时密码';

  @override
  String get guestGateTitle => '登录以继续';

  @override
  String get guestGateBody => '您需要登录才能收藏房源、联系房东、预约看房、发布房源或加入社区。';

  @override
  String get guestGateLoginRegister => '登录 / 注册';

  @override
  String get guestGateLater => '稍后';

  @override
  String get guestGateAccount => '账户';

  @override
  String get hBatchRemindTitle => '批量催缴';

  @override
  String hBatchRemindSummary(Object count, Object total) {
    return '$count 个房间需催缴 · 合计 $total';
  }

  @override
  String get hBatchRemindHint => '点击\"催缴\"打开 Zalo 逐个房间发送提醒。';

  @override
  String get hBatchRemindEmpty => '没有需要催缴的房间 🎉';

  @override
  String hBatchRemindOverdue(Object amount, Object days) {
    return '欠款 $amount · 逾期 $days 天';
  }

  @override
  String get hBatchRemindDone => '已催缴';

  @override
  String get hBatchRemindRemind => '催缴';

  @override
  String get hBatchRemindReminding => '催缴中...';

  @override
  String hBatchRemindRemindAll(Object count) {
    return '通过 Zalo 全部催缴 ($count)';
  }

  @override
  String get hCreditNoteInvalidAmount => '金额无效';

  @override
  String get hCreditNoteCreated => '贷记单已创建';

  @override
  String get hCreditNoteFailed => '创建失败';

  @override
  String get hCreditNoteTitle => '创建贷记单';

  @override
  String get hCreditNoteDescription => '贷记单是对已收款发票的有效调整。原始发票不会被更改。';

  @override
  String get hCreditNoteAmountLabel => '调整金额（VND）*';

  @override
  String get hCreditNoteIssuedDateLabel => '发行日期';

  @override
  String get hCreditNoteReasonLabel => '原因';

  @override
  String get hCreditNoteSubmit => '创建贷记单';

  @override
  String get hInvListTitle => '发票';

  @override
  String get hInvListBatchCreate => '批量生成';

  @override
  String get hInvListFilterAll => '全部';

  @override
  String get hInvListStatusDraft => '草稿';

  @override
  String get hInvListStatusSent => '已发送';

  @override
  String get hInvListStatusPaid => '已收款';

  @override
  String get hInvListAllMonths => '所有月份';

  @override
  String get hInvListEmpty => '暂无发票';

  @override
  String hInvListCreatedCount(Object count) {
    return '已生成 $count 张发票';
  }

  @override
  String hInvListPeriod(Object start, Object end) {
    return '周期 $start → $end';
  }

  @override
  String get hInvPayTitle => '记录付款';

  @override
  String get hInvPayRemaining => '剩余：';

  @override
  String get hInvPayAmountLabel => '金额 (VND) *';

  @override
  String get hInvPayMethodLabel => '方式';

  @override
  String get hInvPayMethodCash => '现金';

  @override
  String get hInvPayMethodBank => '银行转账';

  @override
  String get hInvPayMethodOther => '其他';

  @override
  String get hInvPayNoteLabel => '备注';

  @override
  String get hInvPaySubmit => '记录';

  @override
  String get hInvPayInvalidAmount => '金额无效';

  @override
  String get hInvPayRecordFailed => '记录失败';

  @override
  String get hMeterOpenFromRoomHint => '请从房间详情进入以录入读数';

  @override
  String hMeterTitleRoom(Object code) {
    return '读数 • $code';
  }

  @override
  String get hMeterTitle => '水电读数';

  @override
  String get hMeterAddTooltip => '添加';

  @override
  String get hMeterEmpty => '暂无读数';

  @override
  String hMeterUsageLine(Object kwh, Object water) {
    return '电: $kwh kWh • 水: $water m³';
  }

  @override
  String get hMeterFormTitle => '录入读数';

  @override
  String get hMeterReadingDate => '抄表日期';

  @override
  String get hMeterElectricity => '电 (kWh)';

  @override
  String get hMeterWater => '水 (m³)';

  @override
  String get hMeterSave => '保存读数';

  @override
  String get hMeterSaveFailed => '保存失败';

  @override
  String get hOccReportOccupancyRate => '入住率';

  @override
  String hOccReportRoomsCount(Object count) {
    return '$count 间房';
  }

  @override
  String get hOccReportByRoom => '按房间';

  @override
  String get hOccReportNoData => '暂无数据';

  @override
  String get hRevReportExportFailed => '导出 CSV 失败';

  @override
  String hRevReportInvoiceSubject(Object month) {
    return '发票 $month';
  }

  @override
  String get hRevReportTotalRevenue => '总收入';

  @override
  String get hRevReportGrossRevenue => '总营收';

  @override
  String get hRevReportNetRevenue => '净收入';

  @override
  String get hRevReportNoData => '暂无数据';

  @override
  String get hRevReportViewNewStats => '查看新的收入统计';

  @override
  String get hRevReportExporting => '正在导出…';

  @override
  String get hRevReportExportCsv => '导出本月发票 CSV';

  @override
  String get notifInbox => '收件箱';

  @override
  String get notifMarkAllRead => '全部标记为已读';

  @override
  String get notifEmpty => '暂无通知';

  @override
  String get notifContentGone => '内容已不存在';

  @override
  String get notifJustNow => '刚刚';

  @override
  String notifMinutesAgo(Object count) {
    return '$count 分钟前';
  }

  @override
  String notifHoursAgo(Object count) {
    return '$count 小时前';
  }

  @override
  String notifDaysAgo(Object count) {
    return '$count 天前';
  }

  @override
  String get planErrTitle => '举报错误数据';

  @override
  String get planErrReasonLabel => '原因（≥10个字符）';

  @override
  String get planErrReasonHint => '例如：该区域实际为居住区，而非绿地';

  @override
  String get planErrAttachImage => '附加照片（可选）';

  @override
  String get planErrImageAttached => '已附加照片';

  @override
  String get planErrSubmit => '提交举报';

  @override
  String get planErrSuccessMsg => '举报已提交。谢谢您！';

  @override
  String get planErrMinLength => '原因至少需要10个字符';

  @override
  String get planErrUploading => '正在上传照片…';

  @override
  String get planErrImageTooLarge => '照片过大（最大5 MB）';

  @override
  String get planErrRemoveImage => '删除照片';

  @override
  String planErrParcelId(Object id) {
    return '地块 ID：$id';
  }

  @override
  String planErrUploadFailed(Object error) {
    return '照片上传失败：$error';
  }

  @override
  String planErrSubmitFailed(Object error) {
    return '提交失败：$error';
  }

  @override
  String get planProvSelectHint => '选择省份 / 地址';

  @override
  String get planProvTitle => '选择省份 / 查找地址';

  @override
  String get planProvSearchHint => '省份、地址、街道、地点……';

  @override
  String get planProvNoResults => '未找到结果';

  @override
  String get planProvEmptyPrompt => '输入省份名称或地址';

  @override
  String get planProvSectionProvince => '省 / 市';

  @override
  String get planProvSectionAddress => '地址';

  @override
  String get planProvHasOverlay => '有 2030 规划图层';

  @override
  String get planProvNoOverlay => '仅地址 — 暂无图层';

  @override
  String get planWarnTitle => '信息与规划';

  @override
  String get planWarnReport => '信息有误请举报';

  @override
  String get planWarnOk => '知道了';

  @override
  String planWarnLoadError(Object error) {
    return '加载失败：$error';
  }

  @override
  String get planWarnNotFound => '未找到此位置的规划信息。';

  @override
  String planWarnRisky(Object zone) {
    return '该区域可能受土地使用规划影响（$zone）。您仍可发布房源，但请谨慎考虑。';
  }

  @override
  String get planWarnSuitable => '该区域适合发布房源。';

  @override
  String get planWarnZoneLabel => '区域';

  @override
  String get planWarnAreaLabel => '面积';

  @override
  String get planWarnDistrictLabel => '区';

  @override
  String get hDebtAgingTitle => '欠款';

  @override
  String get hDebtAgingEmptyTitle => '暂无欠款数据';

  @override
  String get hDebtAgingTotal => '欠款总额';

  @override
  String get hDebtAgingByBucket => '按账龄分组';

  @override
  String hDebtAgingNeedsReminder(Object count) {
    return '需催缴 ($count)';
  }

  @override
  String hDebtAgingBucketDays(Object days) {
    return '账龄 $days 天';
  }

  @override
  String hDebtAgingInvoiceCount(Object count) {
    return '$count 张发票';
  }

  @override
  String hDebtAgingOverdue(Object days, Object phone) {
    return '逾期 $days 天 • $phone';
  }

  @override
  String get ctrFilterTitle => '筛选施工单位';

  @override
  String get ctrFilterService => '行业';

  @override
  String get ctrFilterProvince => '地区';

  @override
  String get ctrFilterSort => '排序';

  @override
  String get ctrFilterSortHelper => '“推荐”为系统排序：推广单位 · Pro 套餐 · 已认证 · 评分。';

  @override
  String get ctrFilterAllServices => '全部行业';

  @override
  String get ctrFilterAllProvinces => '全国';

  @override
  String get ctrFilterProvinceUnavailable => '省市列表加载失败，请稍后再试。';

  @override
  String get ctrFilterSortRecommend => '推荐';

  @override
  String get ctrFilterSortRating => '评分最高';

  @override
  String get ctrFilterSortReviews => '评价最多';

  @override
  String get ctrFilterApply => '应用';

  @override
  String get ctrFilterReset => '清除';

  @override
  String get ctrListTitleAll => '施工单位';

  @override
  String get ctrListFilterTooltip => '筛选单位';

  @override
  String ctrListResultCount(int count) {
    return '$count 家单位';
  }

  @override
  String get ctrListEmptyWidenFilter => '放宽筛选';

  @override
  String get homeConstructionFilterTooltip => '筛选施工单位';

  @override
  String get onboardingSkip => '跳过';

  @override
  String get onboardingNext => '下一步';

  @override
  String get onboardingStart => '开始';

  @override
  String get onboardingHeroTitle => '欢迎使用 Vua Nhà';

  @override
  String get onboardingHeroSubtitle => '一个应用，两个世界 — 房地产与建筑。';

  @override
  String get onboardingHeroCardReTitle => '房地产';

  @override
  String get onboardingHeroCardReDesc => '租房、出租、管理房源';

  @override
  String get onboardingHeroCardBuildTitle => '建筑';

  @override
  String get onboardingHeroCardBuildDesc => '设计、施工、室内、报价';

  @override
  String get onboardingReTitle => '房地产触手可及';

  @override
  String get onboardingReSubtitle => '找房、出租与管理 — 尽在一处。';

  @override
  String get onboardingReSearch => '找房';

  @override
  String get onboardingReListings => '浏览租房';

  @override
  String get onboardingRePost => '发布出租';

  @override
  String get onboardingReBooking => '预约看房';

  @override
  String get onboardingReRooms => '出租房、宿舍';

  @override
  String get onboardingReManage => '房源管理';

  @override
  String get onboardingBuildTitle => '从创意到完工';

  @override
  String get onboardingBuildSubtitle => '创意、施工单位与报价 — 快速连接。';

  @override
  String get onboardingBuildDesign => '设计';

  @override
  String get onboardingBuildInterior => '室内';

  @override
  String get onboardingBuildConstruct => '施工';

  @override
  String get onboardingBuildGallery => '美宅样板';

  @override
  String get onboardingBuildKnowledge => '建筑经验';

  @override
  String get onboardingBuildRfq => '发布报价请求';

  @override
  String get onboardingBuildCaption => '含单位名录和排行榜';

  @override
  String get leadSheetTitle => '留下信息，我们回电';

  @override
  String get leadSheetSubtitle => '只需姓名和电话 — 无需登录。';

  @override
  String get leadFieldName => '姓名';

  @override
  String get leadFieldPhone => '电话号码';

  @override
  String get leadFieldNote => '备注（可选）';

  @override
  String get leadSubmit => '发送';

  @override
  String get leadValidation => '请输入姓名和有效的电话号码。';

  @override
  String get leadSendError => '发送失败，请重试。';

  @override
  String get leadSuccessTitle => '已收到！';

  @override
  String get leadSuccessBody => '我们会尽快与您联系。';

  @override
  String get leadClose => '关闭';

  @override
  String get guestGateLeaveContact => '留电话，我们回电';

  @override
  String get adminLeadsTitle => '回电线索';

  @override
  String get adminLeadsEmpty => '暂无线索。';

  @override
  String get hubGuest => '访客';

  @override
  String get hubSearchHint => '输入关键词...';

  @override
  String get hubBannerTitle => 'Vua Nhà — 快速找房，轻松施工';

  @override
  String get hubBannerSubtitle => '房地产 · 设计 · 施工 · 室内';

  @override
  String get hubNeedTitle => '我要找房';

  @override
  String get hubNeedSubtitle => '求租 · 求购 · 发布出售';

  @override
  String get hubHaveTitle => '我有房出租';

  @override
  String get hubHaveSubtitle => '发布房源，当天选租客';

  @override
  String get demandChooserTitle => '您想发布什么？';

  @override
  String get demandChooserHave => '我有房产';

  @override
  String get demandChooserNeed => '我在找房';

  @override
  String get demandChooserPostRent => '发布出租';

  @override
  String get demandChooserPostSale => '发布出售';

  @override
  String get demandChooserNeedRent => '我要租房';

  @override
  String get demandChooserNeedBuy => '我要买房';

  @override
  String get demandChooserHaveHint => '发布真实房源：地址、照片、价格。';

  @override
  String get demandChooserNeedHint => '说出您的需求 — 无需照片，30 秒完成。';

  @override
  String get demandFormTitleRent => '我要租房';

  @override
  String get demandFormTitleBuy => '我要买房';

  @override
  String get demandSecArea => '期望区域';

  @override
  String get demandSecType => '房型';

  @override
  String get demandSecBudget => '预算';

  @override
  String get demandSecMore => '更多信息（可选）';

  @override
  String get demandProvinceHint => '选择省/市';

  @override
  String get demandBudgetFrom => '从';

  @override
  String get demandBudgetTo => '至';

  @override
  String get demandBudgetUnitRent => '百万/月';

  @override
  String get demandBudgetUnitBuy => '十亿';

  @override
  String get demandAreaMin => '最小面积（平方米）';

  @override
  String get demandBedroomsMin => '最少卧室数';

  @override
  String get demandMoveIn => '入住时间';

  @override
  String get demandDuration => '租期（月）';

  @override
  String get demandOccupants => '入住人数';

  @override
  String get demandPayment => '付款方式';

  @override
  String get demandPaymentCash => '现金';

  @override
  String get demandPaymentLoan => '需贷款';

  @override
  String get demandPurpose => '用途';

  @override
  String get demandPurposeLive => '自住';

  @override
  String get demandPurposeInvest => '投资';

  @override
  String get demandNeeds => '必备条件';

  @override
  String get demandNeedParking => '停车位';

  @override
  String get demandNeedFreeHours => '无门禁';

  @override
  String get demandNeedAircon => '空调';

  @override
  String get demandNeedPrivate => '独立房源';

  @override
  String get demandNeedPet => '可养宠物';

  @override
  String get demandNeedBalcony => '阳台';

  @override
  String get demandNote => '补充说明';

  @override
  String get demandNoteHint => '例如：靠近学校，优先低楼层…';

  @override
  String get demandSubmit => '发布需求';

  @override
  String get demandSubmitted => '已发布，有效期 30 天。';

  @override
  String get demandListTitle => '需求列表';

  @override
  String get demandTabAll => '全部';

  @override
  String get demandTabRent => '求租';

  @override
  String get demandTabBuy => '求购';

  @override
  String get demandTabMine => '我的需求';

  @override
  String get demandEmpty => '暂无需求。';

  @override
  String get demandEmptyMine => '您还没有发布需求。';

  @override
  String get demandExpired => '已过期';

  @override
  String get demandClosed => '已关闭';

  @override
  String get demandActionClose => '关闭';

  @override
  String get demandActionExtend => '延长 30 天';

  @override
  String get demandContact => '发消息';

  @override
  String demandDaysLeft(int days) {
    return '剩余 $days 天';
  }

  @override
  String get demandNeedLogin => '请登录后发布需求';

  @override
  String get demandPickTypeFirst => '请至少选择一种房型';

  @override
  String get svcCatalogTitle => '家居服务';

  @override
  String get svcGroupQuick => '快修服务';

  @override
  String get svcGroupBuild => '设计与施工';

  @override
  String get svcQuickHint => '提交需求，我们回电并安排师傅。';

  @override
  String svcBookNow(String serviceName) {
    return '预约服务 · $serviceName';
  }

  @override
  String get svcBookedBody => '我们会回电确认并安排师傅。';

  @override
  String get svcReqTitle => '服务需求';

  @override
  String get svcReqEmpty => '暂无需求。';

  @override
  String get svcReqFilterAll => '全部';

  @override
  String get svcReqFilterNew => '新';

  @override
  String get svcReqFilterDoing => '处理中';

  @override
  String get svcReqFilterDone => '已完成';

  @override
  String get svcReqSearchHint => '按电话或姓名搜索';

  @override
  String get svcReqCall => '拨打';

  @override
  String get svcReqSchedule => '安排时间';

  @override
  String get svcReqNote => '管理员备注';

  @override
  String get svcReqSave => '保存';

  @override
  String get svcReqSaved => '已保存';

  @override
  String get svcStatusNew => '新';

  @override
  String get svcStatusContacted => '已联系';

  @override
  String get svcStatusScheduled => '已安排';

  @override
  String get svcStatusDone => '已完成';

  @override
  String get svcStatusCancelled => '已取消';

  @override
  String get svcStatusSpam => '垃圾';

  @override
  String get hubActionTrade => '买卖 · 租赁';

  @override
  String get hubActionPost => '发布需求';

  @override
  String get hubActionPlanning => '信息与规划';

  @override
  String get hubActionServices => '服务';

  @override
  String get hubRowBrokers => '优秀经纪人';

  @override
  String get hubRowOwners => '房东自发布';

  @override
  String get hubActionLease => '出租';

  @override
  String get hubActionRent => '求租';

  @override
  String get hubActionSell => '出售';

  @override
  String get hubActionBuy => '求购';

  @override
  String get hubFeaturedUnits => '优秀单位';

  @override
  String get hubServiceUnits => '服务单位';

  @override
  String get hubHighlights => '精选资讯';

  @override
  String get hubViewAll => '查看全部';

  @override
  String get hubNotifications => '通知';

  @override
  String get shellNavHome => '首页';

  @override
  String get hubFeaturedBrokers => '优秀经纪人';

  @override
  String get brokerProfileTitle => '经纪人资料';

  @override
  String get brokerNotFound => '未找到该资料。';

  @override
  String get brokerListings => '在售房源';

  @override
  String get brokerNoListings => '暂无在售房源。';

  @override
  String brokerListingCount(int count) {
    return '$count 条房源';
  }

  @override
  String brokerReviewCount(int count) {
    return '$count 条评价';
  }

  @override
  String get brokerStatListings => '房源';

  @override
  String get brokerStatAreas => '区域';

  @override
  String get brokerStatReviews => '评价';

  @override
  String get brokerStatYears => '年数';

  @override
  String get brokerMapTitle => '成交地图';

  @override
  String get brokerReviewsTitle => '客户评价';

  @override
  String get mapLegendTitle => '图例';

  @override
  String get mapLegendSale => '出售';

  @override
  String get mapLegendStayLong => '出租 · 长租';

  @override
  String get mapLegendStayShort => '出租 · 短租';

  @override
  String get mapLegendBusiness => '出租 · 商用';

  @override
  String get postGroupStep => '房源分组';

  @override
  String get postTypeStep => '房源类型';

  @override
  String get postGroupStayLong => '长租住宿';

  @override
  String get postGroupStayShort => '短租住宿';

  @override
  String get postGroupBusiness => '商用';

  @override
  String get postPickGroupFirst => '请先选择分组';

  @override
  String get brokerShare => '分享资料';

  @override
  String get brokerShareCopied => '已复制资料链接';

  @override
  String get pfBasicInfo => '基本信息';

  @override
  String get pfBasicHelper => '客户最先看到的名称和简介。';

  @override
  String get pfContact => '联系方式';

  @override
  String get pfContactHelper => '客户可从资料页直接致电。';

  @override
  String get pfCapacity => '能力';

  @override
  String get pfCapacityHelper => '客户据此判断你能否胜任。';

  @override
  String get pfDocs => '证件与认证';

  @override
  String get pfDocsHelper => '证件通过审核的资料会显示徽章并排名靠前。';

  @override
  String get pfNameHint => '例：明发建筑';

  @override
  String get pfIntroHint => '你做什么、在哪个区域、强项是什么？';

  @override
  String get pfPhoneHint => '09xx xxx xxx';

  @override
  String get pfPhoneInvalid => '电话号码无效';

  @override
  String get pfWebHint => 'facebook.com/... 或网站';

  @override
  String get pfCertHint => '如有执业证书请填写';

  @override
  String get pfUnitScale => '单位规模';

  @override
  String get pfChangeCover => '更换封面';

  @override
  String pfPickPrefix(String field) {
    return '选择$field';
  }

  @override
  String pfEstablishedYear(String year) {
    return '成立年份：$year';
  }

  @override
  String get pfEstVerified => '已凭证件核验';

  @override
  String get pfEstPending => '等待审核';

  @override
  String get pfEstPendingHint => '管理员正在核对证件';

  @override
  String get pfEstRejected => '未通过';

  @override
  String get pfEstRejectedHint => '点击查看原因并重新提交';

  @override
  String get pfEstNone => '成立年份未核验';

  @override
  String get pfEstNoneHint => '点击提交营业执照';

  @override
  String get pfDiscardTitle => '放弃修改？';

  @override
  String get pfDiscardBody => '你修改了资料但尚未保存，现在离开会丢失这些修改。';

  @override
  String get pfKeepEditing => '继续编辑';

  @override
  String get pfDiscard => '放弃修改';

  @override
  String get pfScaleCorporation => '大型集团';

  @override
  String get pfScaleMedium => '中型公司';

  @override
  String get pfScaleSmall => '小型公司';

  @override
  String get pfScaleCrew => '施工队';

  @override
  String get pfScaleIndividual => '个人承包';

  @override
  String get pfScaleArchitect => '建筑师/团队';

  @override
  String get pfScaleSpecialist => '专业承包商';

  @override
  String get sellerStep => '你以什么身份发布这条房源？';

  @override
  String get sellerStepHelper => '客户很在意这一点。此为自行申报，Vua Nhà 尚未核验证件。';

  @override
  String get sellerOwner => '房东自行发布';

  @override
  String get sellerOwnerDesc => '是你本人的房产';

  @override
  String get sellerBroker => '代发 / 经纪人';

  @override
  String get sellerBrokerDesc => '你替房东发布';

  @override
  String get sellerRequired => '请选择身份';

  @override
  String get sellerBadgeOwner => '房东（自行申报）';

  @override
  String get sellerBadgeBroker => '经纪人（自行申报）';

  @override
  String get hubFeaturedSellers => '优秀卖家';

  @override
  String get brokerMapExpand => '放大查看';

  @override
  String get brokerMapHint => '点击图钉查看房源 · 拖动与双指缩放';

  @override
  String get brokerMapHintShort => '双指或 +/− 缩放 · 点击图钉查看房源';

  @override
  String get planningScreenTitle => '信息与规划';

  @override
  String get planningCheckAction => '信息与规划';

  @override
  String get planningTabShort => '规划';

  @override
  String get planningLayerToggle => '2030 土地利用规划图层';

  @override
  String get planningOpacityLabel => '透明度';

  @override
  String get planningZoneLegendTitle => '规划图例';

  @override
  String get planningZoneLegendEmpty => '放大以查看该区域的土地类型';

  @override
  String get planningZoneLegendRasterNote => '图例来自省级数据源 · 点击地块查看详情';

  @override
  String get planningZoneLegendOther => '其他类型';

  @override
  String get mapClusterTooltip => '点击展开聚合';

  @override
  String get mapSearchHint => '搜索地点';

  @override
  String get mapZoomIn => '放大';

  @override
  String get mapZoomOut => '缩小';

  @override
  String get mapMyLocation => '我的位置';

  @override
  String get mapLocationOff => '设备定位服务已关闭';

  @override
  String get mapLocationDenied => '未授予位置权限';

  @override
  String get mapLocationOutside => '您的位置在越南境外';

  @override
  String get mapLocationError => '无法获取位置，请稍后重试';

  @override
  String get mapSearchEmpty => '未找到地点';

  @override
  String get mapLegendHelp => '说明';

  @override
  String get mapLegendStayShortDesc => '按天或数日出租，适合度假、出差和旅行。';

  @override
  String get mapLegendStayLongDesc => '按月或更长期出租，适合稳定居住生活。';

  @override
  String get mapLegendBusinessDesc => '出租的商铺场地，可用于经营、零售、办公或开店。';

  @override
  String get mapLegendSaleDesc => '买卖房产，长期持有和使用。';

  @override
  String get tradeTabBuy => '找房源';

  @override
  String get tradeTabSell => '找客户';

  @override
  String get tradeBuyHint => '正在出售和出租的房源';

  @override
  String get tradeSellHint => '正在求购、求租的人 — 发布房源让他们找到你';

  @override
  String get tradeChipAll => '全部';

  @override
  String get tradeChipSale => '出售';

  @override
  String get tradeChipShort => '短租';

  @override
  String get tradeShortStaySearchTitle => '按小时查找空房';

  @override
  String get tradeShortStaySearchSub => '按小时 · 过夜 · 按天 — 查看价格并立即预订';

  @override
  String get tradeChipLong => '长租';

  @override
  String get tradeChipBusiness => '商用';

  @override
  String get tradeChipNeedBuy => '求购';

  @override
  String get tradeChipNeedRent => '求租';

  @override
  String get tradeSearchHint => '按标题或区域搜索';

  @override
  String get tradeFilter => '筛选';

  @override
  String get tradeFilterTitle => '筛选结果';

  @override
  String get tradePriceRange => '价格区间';

  @override
  String get tradeAreaFrom => '面积起 (m²)';

  @override
  String get tradeBedrooms => '卧室';

  @override
  String get tradeApply => '应用';

  @override
  String get tradeClear => '清除';

  @override
  String get tradeEmptyBuy => '暂无匹配房源';

  @override
  String get tradeEmptySell => '暂无匹配需求';

  @override
  String get tradeEmptyHint => '请尝试减少筛选条件或更换关键词。';

  @override
  String tradeResultCount(int n) {
    return '$n 条结果';
  }

  @override
  String get tfTitle => '筛选结果';

  @override
  String get tfPrice => '价格区间';

  @override
  String get tfArea => '面积';

  @override
  String get tfBedrooms => '卧室';

  @override
  String get tfSort => '排序';

  @override
  String get tfAny => '全部';

  @override
  String get tfAreaUnder => '30 m² 以下';

  @override
  String get tfArea3050 => '30 – 50 m²';

  @override
  String get tfArea5080 => '50 – 80 m²';

  @override
  String get tfAreaOver => '80 m² 以上';

  @override
  String get tfSortNewest => '最新';

  @override
  String get tfSortPriceAsc => '价格由低到高';

  @override
  String get tfSortPriceDesc => '价格由高到低';

  @override
  String get tfReset => '重置';

  @override
  String tfSeeCount(int n) {
    return '查看 $n 条';
  }

  @override
  String get tfSeeNone => '没有匹配的房源';

  @override
  String get tfCounting => '统计中…';

  @override
  String get tfBillion => '十亿';

  @override
  String get tfMillion => '百万';

  @override
  String get tfNoLimit => '不限';

  @override
  String get tfAdvanced => '高级筛选';

  @override
  String get tfPropertyType => '房源类型';

  @override
  String get tfDirection => '朝向（风水）';

  @override
  String get tfTrust => '信誉与品质';

  @override
  String get tfTrustedOnly => '仅显示信誉房源';

  @override
  String get tfMinRating => '最低评分';

  @override
  String get tfMinQuality => '最低品质星级';

  @override
  String tfQualityStar(int n) {
    return '$n 星';
  }

  @override
  String get tfSortTrust => '信誉';

  @override
  String get tfSortRating => '高评分';

  @override
  String get tfDirN => '北';

  @override
  String get tfDirNE => '东北';

  @override
  String get tfDirE => '东';

  @override
  String get tfDirSE => '东南';

  @override
  String get tfDirS => '南';

  @override
  String get tfDirSW => '西南';

  @override
  String get tfDirW => '西';

  @override
  String get tfDirNW => '西北';

  @override
  String get reelSectionTitle => '精选短视频';

  @override
  String get reelSeeAll => '查看全部';

  @override
  String get exploreTradeTitlePlain => '探索 ';

  @override
  String get exploreTradeTitleAccent => '买卖 · 租赁';

  @override
  String get exploreTradeSubtitle => '房产买卖与租赁信息汇总，\n附快速筛选';

  @override
  String get exploreTradeCta => '查看汇总';

  @override
  String get homeNewsSection => '最新房源';

  @override
  String get homeNewsEmpty => '暂无房源';

  @override
  String get tfArea2 => '搜索区域';

  @override
  String get tfAreaAll => '全部';

  @override
  String get tfAreaNear => '附近';

  @override
  String get tfAreaPlace => '地点';

  @override
  String get tfPlaceHint => '输入地点：\"洪德大学附近\"…';

  @override
  String get tfRadius => '半径';

  @override
  String get tfLocating => '正在获取位置…';

  @override
  String get tfLocated => '已获取位置 ✓';

  @override
  String get tfGeoOnlyBasic => '按区域筛选时，结果按距离排序。';

  @override
  String get tfNoMatchPlace => '未找到该地点';

  @override
  String get filterLocInsecureContext => '页面通过 HTTP 打开，浏览器已阻止定位。';

  @override
  String get profHostSection => '租赁管理';

  @override
  String get profHostBuildings => '楼宇与房间';

  @override
  String get profHostBuildingsSub => '楼宇、房间、在租租客';

  @override
  String get profHostContracts => '合同';

  @override
  String get profHostContractsSub => '租赁合同与到期日';

  @override
  String get profHostInvoices => '账单';

  @override
  String get profHostInvoicesSub => '房租、水电、收支';

  @override
  String get profHostAppointments => '看房预约';

  @override
  String get profHostAppointmentsSub => '审批与安排看房';

  @override
  String get profHostKyc => '房东资料';

  @override
  String get profHostKycSub => '证件、收款账户、认证';

  @override
  String get myReqSubtitle => '你已预约的服务';

  @override
  String get myReqEmptyHint => '需要电工、水管工或保洁？预约一次，我们会回电安排。';

  @override
  String get myReqEmptyCta => '浏览服务';

  @override
  String get myReqStatusContacted => '已联系';

  @override
  String get myReqStatusScheduled => '已排期';

  @override
  String get myReqStatusDone => '已完成';

  @override
  String get myReqStatusCancelled => '已取消';

  @override
  String myReqSentAt(String d) {
    return '发送于 $d';
  }

  @override
  String myReqScheduledAt(String d) {
    return '预约 $d';
  }

  @override
  String get profMessages => '消息';

  @override
  String get profMessagesSub => '与房东和卖家沟通';

  @override
  String get profNextViewing => '即将看房';

  @override
  String profNextViewingAt(String d, String t) {
    return '$d · $t';
  }

  @override
  String get saleCall => '发消息';

  @override
  String saleCallNamed(String ten) {
    return '发消息给 $ten';
  }

  @override
  String get saleShareBtn => '分享';

  @override
  String get saleQrTitle => '扫码打开';

  @override
  String get saleQrHint => '让客户扫描此码';

  @override
  String get saleAreaCover => '房源所在区域';

  @override
  String get saleReviewsShort => '客户评价';

  @override
  String get albumSection => '项目';

  @override
  String albumUnits(int n) {
    return '$n 套';
  }

  @override
  String get albumEmpty => '该项目暂无房源';

  @override
  String get albumTitle => '项目';

  @override
  String get albumHidden => '已隐藏';

  @override
  String get albumMine => '我的项目';

  @override
  String get albumMineSub => '按楼宇或项目分组房源';

  @override
  String get albumNew => '新建项目';

  @override
  String get albumNameLabel => '项目名称';

  @override
  String get albumNameHint => 'Vinhomes Grand Park — S1';

  @override
  String get albumDescLabel => '描述（可选）';

  @override
  String get albumPublicLabel => '在个人主页公开';

  @override
  String get albumPublicHint => '整理中可先关闭，客户看不到';

  @override
  String get albumSave => '保存';

  @override
  String get albumDelete => '删除项目';

  @override
  String get albumDeleteAsk => '删除此项目？';

  @override
  String get albumDeleteNote => '房源仍然保留，只是不再属于任何项目。';

  @override
  String get albumNoneYet => '暂无项目';

  @override
  String get albumNoneHint => '把同一栋楼的房源归到一个项目，客户可一次看完。';

  @override
  String get albumAddListings => '添加房源';

  @override
  String get albumPickTitle => '选择房源';

  @override
  String get albumPickEmpty => '你还没有房源';

  @override
  String albumPickSave(int n) {
    return '添加 $n 套';
  }

  @override
  String get albumUnitLabel => '房号';

  @override
  String get albumUnitHint => '1201 室';

  @override
  String get albumRemove => '移出项目';

  @override
  String get albumSaved => '已保存';

  @override
  String get albumNeedName => '请输入项目名称';

  @override
  String tfActiveCount(int n) {
    return '$n 项筛选';
  }

  @override
  String get homeMapPreviewTitle => '你附近的房源';

  @override
  String get homeMapPreviewOpen => '打开地图';

  @override
  String get homeMapPreviewEmpty => '暂无带坐标的房源';

  @override
  String get homeMapLocate => '回到我的位置';

  @override
  String get mapLocationInsecure => '浏览器仅在 HTTPS 下允许获取位置，请使用 https:// 地址打开。';

  @override
  String get mapLocationBlocked => '该网站的定位权限已被阻止。点击地址栏旁的锁形图标 → 允许位置 → 重新加载。';

  @override
  String get homeMapExpand => '展开';

  @override
  String get hubMapSection => '交易活跃区域';

  @override
  String get shellNavServices => '服务';

  @override
  String get cardOnMap => '在地图上查看';

  @override
  String get tradeOpenMap => '地图';

  @override
  String get hubGreeting => '你好，';

  @override
  String get svcGroupDeal => '买卖与法务';

  @override
  String get svcGroupDealHint => '估价、过户、贷款、验房';

  @override
  String get svcGroupDesignBuild => '设计与施工';

  @override
  String get svcGroupDesignBuildHint => '从图纸到交付，含整包服务';

  @override
  String get svcGroupRepair => '快速维修';

  @override
  String get svcGroupRepairHint => '当天上门';

  @override
  String get svcGroupHomeCare => '清洁与搬家';

  @override
  String get svcGroupHomeCareHint => '清洁、搬家、钟点工';

  @override
  String get svcGroupOther => '其他服务';

  @override
  String svcCount(int n) {
    return '$n 项服务';
  }

  @override
  String get svcHeroTitle => '需要什么都有师傅';

  @override
  String get svcHeroSubtitle => '提交需求，Vua Nhà 回电并安排师傅';

  @override
  String get svcSearchHint => '今天需要什么服务？';

  @override
  String svcStat(int n, int g) {
    return '$n 项服务 · $g 个分组';
  }

  @override
  String get svcNoMatch => '没有匹配的服务';

  @override
  String get svcNoMatchHint => '试试更短的关键词，例如“điện”或“sơn”。';

  @override
  String svcGroupCount(int n) {
    return '$n 个分组';
  }

  @override
  String get loginIdentifier => '邮箱或手机号';

  @override
  String get identifierHint => '0912345678 或 you@example.com';

  @override
  String get valIdentifierRequired => '请输入邮箱或手机号';

  @override
  String get registerEmailOptional => '邮箱（选填）';

  @override
  String get registerNeedEmailOrPhone => '请至少填写邮箱或手机号';

  @override
  String get registerNoEmailWarning => '未填写邮箱时，忘记密码需联系客服——重置链接仅通过邮箱发送。';

  @override
  String get valPhoneInvalid => '手机号格式不正确（例：0912345678）';

  @override
  String get primingBtnEnable => '立即开启';

  @override
  String get primingBtnDefer => '稍后再说';

  @override
  String get primingBtnContinue => '继续';

  @override
  String get primingBtnCancel => '取消';

  @override
  String get primingBtnClose => '关闭';

  @override
  String get primingTrustCanDisable => '随时可关闭';

  @override
  String get primingTrustNoSpam => '不发垃圾信息 — 仅发送有用通知';

  @override
  String get primingSoftReaskNotif => '您已关闭通知。请在设置中开启，以免错过重要消息。';

  @override
  String get primingSoftReaskCamera => '您已关闭摄像头权限。请在设置中开启以拍摄照片。';

  @override
  String get primingSoftReaskOpenSettings => '打开设置';

  @override
  String get primingSoftReaskDismiss => '忽略';

  @override
  String get primingSettingsNotifTitle => '通知';

  @override
  String get primingSettingsCameraTitle => '摄像头';

  @override
  String get primingSettingsStatusEnabled => '已开启';

  @override
  String get primingSettingsStatusDisabled => '已关闭';

  @override
  String get primingSettingsActionEnable => '开启 → 前往设置';

  @override
  String get jp_shikikin => '押金 (敷金)';

  @override
  String get jp_reikin => '礼金 (礼金)';

  @override
  String get jp_koushinryo => '续约费 (更新料)';

  @override
  String get jp_hoshou => '保证金 (保証金)';

  @override
  String get jp_brokerage => '中介费 (仲介手数料)';

  @override
  String get jp_management_fee => '管理费 (管理費)';

  @override
  String get jp_monthly_rent => '月租金 (月額家賃)';

  @override
  String get jp_shouhizei => '消费税 (消費税)';

  @override
  String get jp_kyouekihi => '公共服务费 (共益費)';

  @override
  String get jp_layout => '户型 (間取り)';

  @override
  String get jp_floor_area => '专有面积 (専有面積)';

  @override
  String get jp_building_year => '建造年份 (築年数)';

  @override
  String get jp_structure_rc => '钢筋混凝土 (RC)';

  @override
  String get jp_structure_wood => '木结构 (木造)';

  @override
  String get jp_structure_steel => '钢结构 (鉄骨)';

  @override
  String get jp_structure_src => '钢骨钢筋混凝土 (SRC)';

  @override
  String get jp_orientation_n => '朝北 (北)';

  @override
  String get jp_orientation_ne => '朝东北 (北東)';

  @override
  String get jp_orientation_e => '朝东 (東)';

  @override
  String get jp_orientation_se => '朝东南 (南東)';

  @override
  String get jp_orientation_s => '朝南 (南)';

  @override
  String get jp_orientation_sw => '朝西南 (南西)';

  @override
  String get jp_orientation_w => '朝西 (西)';

  @override
  String get jp_orientation_nw => '朝西北 (北西)';

  @override
  String get jp_available_from => '可入住日期 (入居可能日)';

  @override
  String get jp_floor => '楼层 (階数)';

  @override
  String get jp_nearest_station => '最近车站 (最寄り駅)';

  @override
  String get jp_walk_min_from_station => '步行至车站 (徒歩分)';

  @override
  String get jp_train_line => '线路 (路線)';

  @override
  String get jp_viewing_request => '看房申请 (内見リクエスト)';

  @override
  String get jp_select_slots => '选择时间段';

  @override
  String get jp_slot_confirmed => '已确认时间段';

  @override
  String get jp_viewing_status_pending => '待确认';

  @override
  String get jp_viewing_status_confirmed => '已确认';

  @override
  String get jp_viewing_status_rejected => '已拒绝';

  @override
  String get jp_viewing_status_cancelled => '已取消';

  @override
  String get jp_viewing_status_completed => '已完成';

  @override
  String jp_slot_label(int n) {
    return '时间段 $n';
  }

  @override
  String get jp_slots_hint => '最多选择3个时间段';

  @override
  String get jp_slots_max_warning => '最多只能选择3个时间段';

  @override
  String get jp_apply => '申请入住 (入居申込)';

  @override
  String get jp_employer => '工作单位 (勤務先)';

  @override
  String get jp_annual_income => '年收入 (年収)';

  @override
  String get jp_guarantor => '保证人 (連帯保証人)';

  @override
  String get jp_emergency_contact => '紧急联系人 (緊急連絡先)';

  @override
  String get jp_upload_documents => '上传文件 (書類アップロード)';

  @override
  String get jp_application_status_draft => '草稿';

  @override
  String get jp_application_status_submitted => '已提交';

  @override
  String get jp_application_status_under_review => '审核中';

  @override
  String get jp_application_status_approved => '已批准';

  @override
  String get jp_application_status_rejected => '已拒绝';

  @override
  String get jp_application_status_withdrawn => '已撤回';

  @override
  String get jp_chat_greeting_formal => '您好，请问有什么可以帮助您？';

  @override
  String get jp_chat_viewing_confirm => '我确认看房预约。';

  @override
  String get jp_chat_apology => '对于给您带来的不便，深感抱歉。';

  @override
  String get jp_chat_available => '我可以在这个时间看房。';

  @override
  String get jp_submit => '提交';

  @override
  String get jp_cancel_viewing => '取消看房';

  @override
  String get jp_reschedule => '重新安排';

  @override
  String get jp_step_basic_info => '基本信息';

  @override
  String get jp_step_employer => '工作信息';

  @override
  String get jp_step_guarantor => '保证人';

  @override
  String get jp_step_documents => '证明文件';

  @override
  String get jp_step_confirm => '确认';

  @override
  String get jp_search_facets_title => '筛选搜索';

  @override
  String get jp_layout_filter => '房型';

  @override
  String get jp_rent_range => '租金范围';

  @override
  String get jp_area_range => '面积';

  @override
  String get jp_building_age_max => '最大楼龄';

  @override
  String get jp_walk_min_max => '最长步行时间';

  @override
  String get jp_flag_pets_ok => '允许宠物 (ペット可)';

  @override
  String get jp_flag_no_guarantor => '无需保证公司 (保証会社不要)';

  @override
  String get jp_flag_instruments_ok => '允许乐器 (楽器可)';

  @override
  String get jp_flag_corporate_ok => '法人合同 (法人契約可)';

  @override
  String get jp_sales_dashboard_title => '负责人面板';

  @override
  String get jp_assigned_listings => '负责的房源';

  @override
  String get jp_pending_viewings => '待处理看房申请';

  @override
  String get jp_pending_applications => '待处理入住申请';

  @override
  String get jp_viewing_inbox_title => '看房申请';

  @override
  String get jp_application_queue_title => '申请队列';

  @override
  String get jp_confirm_slot => '确认时间段';

  @override
  String get jp_reject_viewing => '拒绝申请';

  @override
  String get jp_application_decision => '申请决定';

  @override
  String get jp_approve_application => '批准';

  @override
  String get jp_reject_application => '拒绝';

  @override
  String get jp_honorific_toggle => '使用敬语 (丁寧語)';

  @override
  String get jp_honorific_on => '开启';

  @override
  String get jp_honorific_off => '关闭';

  @override
  String get appi_consent_title => '个人信息处理';

  @override
  String get appi_purpose_service_use => '服务提供 — 房产搜索及合同处理';

  @override
  String get appi_purpose_marketing => '营销 — 房产推荐及促销';

  @override
  String get appi_purpose_analytics => '分析 — 服务改善及使用分析';

  @override
  String get appi_purpose_data_sharing_broker => '与持牌经纪商共享数据以处理交易';

  @override
  String get appi_purpose_data_sharing_hoshou => '与担保公司（保証会社）共享数据以进行审查';

  @override
  String get appi_consent_required_notice => '标记为必要的目的是提供服务所必需的。您必须同意这些才能继续。';

  @override
  String get appi_privacy_policy_link => '隐私政策（個人情報保護方針）';

  @override
  String get appi_i_agree => '我同意（同意する）';

  @override
  String get appi_revoke_consent => '撤回';

  @override
  String get appi_consent_revoked => '已撤回同意';

  @override
  String get appi_consent_granted_on => '同意日期';

  @override
  String get appi_privacy_settings_title => '个人信息（個人情報の取扱い）';

  @override
  String get appi_consent_list_title => '同意历史';

  @override
  String get appi_no_consents => '暂无同意记录';

  @override
  String get data_export_request => '申请数据导出';

  @override
  String get data_export_processing => '正在准备您的数据，请稍候。';

  @override
  String get data_export_ready => '您的数据已准备好，点击下载。';

  @override
  String get data_export_submit => '申请导出';

  @override
  String get data_export_title => '导出个人数据';

  @override
  String get data_export_description => '我们将汇总与您账户相关的所有个人数据并发送下载链接。';

  @override
  String get data_delete_title => '删除个人数据';

  @override
  String get data_delete_warning => '此操作将永久删除与您账户相关的所有个人数据，无法撤销。';

  @override
  String get data_delete_cool_off => '适用30天冷静期。您可以在此期间联系客服取消申请。';

  @override
  String get data_delete_confirm => '请输入DELETE以确认';

  @override
  String get data_delete_submit => '申请删除';

  @override
  String get data_delete_type_hint => '输入DELETE';

  @override
  String get data_delete_type_error => '请输入DELETE以确认';

  @override
  String get checkout_title => '支付';

  @override
  String get checkout_invoice_summary => '账单摘要';

  @override
  String get checkout_total => '合计';

  @override
  String get payment_method_card => '信用卡/借记卡';

  @override
  String get payment_method_konbini => '便利店付款（コンビニ）';

  @override
  String get payment_method_bank_transfer => '银行转账（振込）';

  @override
  String get payment_card_placeholder => '信用卡支付即将推出';

  @override
  String get payment_bank_placeholder => '确认后将提供转账信息';

  @override
  String get konbini_voucher_title => '支付凭证';

  @override
  String get konbini_voucher_number => '凭证号码';

  @override
  String get konbini_voucher_deadline => '支付截止日期';

  @override
  String get konbini_voucher_instructions => '请持此凭证号码前往任意参与便利店的收银台或多功能终端付款。';

  @override
  String get konbini_copy_number => '复制号码';

  @override
  String get konbini_number_copied => '已复制凭证号码';

  @override
  String get konbini_stores => '参与门店';

  @override
  String get payment_status_pending => '等待付款';

  @override
  String get payment_status_processing => '处理中';

  @override
  String get payment_status_succeeded => '支付成功';

  @override
  String get payment_status_failed => '支付失败';

  @override
  String get payment_status_expired => '支付已过期';

  @override
  String get payment_status_title => '支付状态';

  @override
  String get payment_status_checking => '正在查询支付状态…';

  @override
  String get payment_retry => '重新支付';

  @override
  String get payment_contact_support => '联系客服';

  @override
  String get review_decision => '审查决定';

  @override
  String get review_approve => '批准';

  @override
  String get review_reject => '拒绝';

  @override
  String get review_needs_info => '请求补充信息';

  @override
  String get review_reason => '原因（可选）';

  @override
  String get review_reason_hint => '请填写此决定的原因';

  @override
  String get review_submit => '提交决定';

  @override
  String get review_submitting => '提交中…';

  @override
  String get review_submitted => '决定已提交';

  @override
  String get review_applicant_info => '申请人信息';

  @override
  String get review_employer_info => '雇主信息';

  @override
  String get review_guarantor_info => '担保人信息';

  @override
  String get review_documents => '文件';

  @override
  String get review_no_documents => '未上传文件';

  @override
  String get it_session_title => 'IT重说 — 在线说明';

  @override
  String get it_session_takken_shi_info => '持证房地产经纪人（宅建士）';

  @override
  String get it_session_license_number => '执照号码';

  @override
  String get it_session_consent_notice =>
      '本次会话将被录制以符合法律要求。录制内容将根据《宅地建物取引业法》保留5年。';

  @override
  String get it_session_i_consent => '我同意录制及重要事项说明';

  @override
  String get it_session_join_zoom => '通过Zoom参加';

  @override
  String get it_session_recording_notice => '录制通知';

  @override
  String get it_session_consent_required => '参加前必须同意录制';

  @override
  String get econtract_title => '电子合同（電子契約）';

  @override
  String get econtract_status_pending => '等待签署';

  @override
  String get econtract_status_signed => '已签署';

  @override
  String get econtract_status_expired => '已过期';

  @override
  String get econtract_status_cancelled => '已取消';

  @override
  String get econtract_sign_button => '签署合同';

  @override
  String get econtract_download_signed => '下载已签署合同';

  @override
  String get econtract_open_external => '在浏览器中打开';

  @override
  String get econtract_signing_note => '您将被重定向到签署服务。签署后请返回此页面。';

  @override
  String get econtract_status_label => '合同状态';

  @override
  String get jp_renewal_eyebrow => '续约';

  @override
  String get jp_renewal_title => '合同续约';

  @override
  String get jp_renewal_contract_summary => '合同概要';

  @override
  String get jp_renewal_property => '物业';

  @override
  String get jp_renewal_room => '房间号';

  @override
  String get jp_renewal_current_term_end => '当前合同结束日';

  @override
  String get jp_renewal_new_term_end => '续约后结束日';

  @override
  String get jp_renewal_total_fee => '续约费合计';

  @override
  String get jp_renewal_confirm_cta => '确认续约';

  @override
  String get jp_renewal_decline_cta => '申请重新协商';

  @override
  String get jp_renewal_confirm_title => '确认续约';

  @override
  String get jp_renewal_confirm_notice => '确认后将开具续约费发票。';

  @override
  String get jp_renewal_confirm_submit => '确认并续约';

  @override
  String get jp_renewal_status_confirmed => '已确认续约。';

  @override
  String get jp_renewal_status_declined => '已收到重新协商申请。';

  @override
  String get jp_settlement_eyebrow => '押金结算';

  @override
  String get jp_settlement_owner_title => '填写扣除项目';

  @override
  String get jp_settlement_tenant_title => '查看结算详情';

  @override
  String get jp_settlement_deposit_summary => '押金概要';

  @override
  String get jp_settlement_property => '物业';

  @override
  String get jp_settlement_room => '房间号';

  @override
  String get jp_settlement_tenant => '租客';

  @override
  String get jp_settlement_deductions => '扣除项目';

  @override
  String get jp_settlement_no_deductions => '无扣除项目';

  @override
  String get jp_settlement_add_deduction => '添加项目';

  @override
  String get jp_settlement_remove_deduction => '删除';

  @override
  String get jp_settlement_deduction_item => '项目';

  @override
  String get jp_settlement_deduction_title => '项目名称';

  @override
  String get jp_settlement_deduction_amount => '金额（¥）';

  @override
  String get jp_settlement_deduction_photos => '照片（可选，最多3张）';

  @override
  String get jp_settlement_net_refund => '退款金额';

  @override
  String get jp_settlement_submit_to_tenant => '发送给租客';

  @override
  String get jp_settlement_accept_cta => '同意结算';

  @override
  String get jp_settlement_dispute_cta => '提出异议';

  @override
  String get jp_settlement_dispute_title => '异议申请';

  @override
  String get jp_settlement_dispute_description => '请描述您的异议原因。';

  @override
  String get jp_settlement_dispute_reason_label => '异议原因';

  @override
  String get jp_settlement_dispute_submit => '提交异议';

  @override
  String get jp_settlement_status_accepted => '已同意结算，退款流程已开始。';

  @override
  String get jp_settlement_status_disputed => '异议已提交。';

  @override
  String get jp_kpi_eyebrow => '管理员';

  @override
  String get jp_kpi_dashboard_title => 'KPI仪表板';

  @override
  String get jp_kpi_prefecture_label => '都道府县';

  @override
  String get jp_kpi_all_japan => '全日本';

  @override
  String get jp_kpi_active_listings => '在架房源';

  @override
  String get jp_kpi_pending_applications => '待审申请';

  @override
  String get jp_kpi_active_contracts => '有效合同';

  @override
  String get jp_kpi_avg_days_to_sign => '平均签约天数';

  @override
  String get jp_kpi_monthly_revenue => '月收入';

  @override
  String get jp_deletion_eyebrow => '账户';

  @override
  String get jp_deletion_title => '删除账户';

  @override
  String get jp_deletion_settings_subtitle => '账户及所有数据将在30天后删除';

  @override
  String get jp_deletion_warning => '删除账户将永久删除以下所有数据，此操作无法撤销。';

  @override
  String get jp_deletion_bullet_data => '个人信息与个人资料';

  @override
  String get jp_deletion_bullet_contracts => '合同与交易历史';

  @override
  String get jp_deletion_bullet_irreversible => '此操作无法撤销';

  @override
  String get jp_deletion_cooloff_notice => '从删除申请日期起适用30天冷静期。在此期间联系客服可取消申请。';

  @override
  String get jp_deletion_schedule_cta => '申请删除';

  @override
  String get jp_deletion_days_remaining => '天后删除';

  @override
  String get jp_deletion_scheduled_notice => '您的账户删除已安排。在冷静期内可取消。';

  @override
  String get jp_deletion_support_contact => '如需取消，请联系 support@ancu365.jp。';

  @override
  String get jp_deletion_cancel_cta => '取消删除申请';

  @override
  String get jp_deletion_cancel_confirm_title => '取消删除申请';

  @override
  String get jp_deletion_cancel_confirm_body => '确定要取消删除申请吗？';

  @override
  String get jp_deletion_cancel_no => '返回';

  @override
  String get jp_deletion_cancel_yes => '确定取消';

  @override
  String get jp_deletion_confirm_sheet_title => '最终确认';

  @override
  String get jp_deletion_confirm_sheet_body => '请输入您的注册邮箱以继续。';

  @override
  String get jp_deletion_confirm_email_label => '电子邮件地址';

  @override
  String get jp_deletion_confirm_email_hint => '输入注册邮箱';

  @override
  String get jp_deletion_confirm_email_error => '电子邮件地址不匹配';

  @override
  String get jp_deletion_confirm_submit => '申请删除';

  @override
  String get jp_facet_pets_ok_label => '允许宠物';

  @override
  String get jp_facet_walk_min_label => '步行时间（分钟）';

  @override
  String jp_facet_walk_min_value(int min) {
    return '$min分钟步行范围内';
  }

  @override
  String get jp_facet_layout_label => '户型';

  @override
  String get helpCenterTitle => '帮助中心';

  @override
  String get helpCenterSearchHint => '搜索问题...';

  @override
  String get helpCenterNoResults => '未找到结果';

  @override
  String get helpCenterArticleNotFound => '文章未找到';

  @override
  String get helpCenterLoadError => '文章加载失败，请重试。';

  @override
  String get helpCenterComingSoon => '内容正在准备中，请稍后再访问。';

  @override
  String get legalFooterTokusho => '特定商取引法に基づく表記';

  @override
  String get legalFooterTerms => '服务条款';

  @override
  String get legalFooterPrivacy => '隐私政策';

  @override
  String get legalFooterAppiRequest => 'APPI信息公开申请';

  @override
  String get legalFooterOperator => '运营商信息';

  @override
  String get legalFooterCopyright => '© 2026 Synora K.K. All rights reserved.';
}
