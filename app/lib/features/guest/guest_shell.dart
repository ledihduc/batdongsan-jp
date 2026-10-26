import 'package:flutter/material.dart';
import 'package:convex_bottom_bar/convex_bottom_bar.dart';
import 'package:house_booking/core/widgets/nav_tap_bounce.dart';
import 'package:flutter/services.dart' show SystemNavigator;
import 'package:house_booking/l10n/app_localizations.dart';
import 'package:provider/provider.dart';
import 'package:house_booking/data/models/user_preferences.dart';
import 'package:house_booking/data/models/login_account_type.dart';
import 'package:house_booking/data/services/user_prefs_service.dart';
import 'package:house_booking/data/services/preferences_service.dart'
    show PreferencesService, defaultWorldRevision;
import 'package:house_booking/features/auth/guest_gate.dart';
import 'package:house_booking/features/guest/service/service_catalog_screen.dart';
import 'package:house_booking/core/config/feature_flags.dart';
import 'package:house_booking/features/guest/widgets/super_app_bottom_bar.dart';
import 'package:house_booking/features/guest/home/guest_home_screen.dart';
import 'package:house_booking/features/guest/quan_ly/quan_ly_theo_vai_tro_screen.dart';
import 'package:house_booking/features/host/post/post_house_screen.dart';
import 'package:house_booking/features/onboarding/service_hub_screen.dart';
import 'package:house_booking/features/guest/broker/broker_profile_screen.dart';
import 'package:house_booking/features/guest/profile/profile_screen.dart';
import 'package:house_booking/features/guest/profile/sale_settings_screen.dart';
import 'package:house_booking/features/host/property/screens/building_list_screen.dart';
import 'package:house_booking/features/host/dashboard/host_dashboard_tokens.dart';
import 'package:house_booking/providers/auth_provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:house_booking/core/config/api_config.dart';
import 'package:house_booking/providers/viewing_appointment_provider.dart';

/// Bottom-nav shell with Airbnb-style persona switching.
///
/// Reduces footer from 6 → 4 fixed tabs by partitioning destinations between
/// two modes. The role selector lives in the Activity tab; current mode
/// persists via [UserPrefsService] so the app reopens where the user left off.
class GuestShell extends StatefulWidget {
  const GuestShell({super.key, this.initialTab = 0});

  /// Slot to highlight on first build. Khách: 0=Trang chủ · 1/2=hai thế giới ·
  /// 3=Hoạt động (đổi Khách/Sale/Chủ nhà trong màn) · 4=Cá nhân.
  final int initialTab;

  @override
  State<GuestShell> createState() => _GuestShellState();
}

class _GuestShellState extends State<GuestShell> {
  // Deep-links cũ có thể truyền initialTab=4/5 (Quy hoạch / Tin đăng đã bỏ).
  // Clamp về 0 (Khám phá) cho an toàn — đẩy về tab 3 (Cá nhân) sẽ confusing.
  late int _currentIndex = (widget.initialTab >= 0 && widget.initialTab <= 4)
      ? widget.initialTab
      : 0;
  String _activeMode = 'customer';
  late final ValueNotifier<String> _modeNotifier = ValueNotifier(_activeMode);
  late final AuthProvider _auth;
  int _modeRevision = 0;

  /// Các "thế giới" ở giữa bottom nav. Trước đây có hai (BĐS + Thi công) và
  /// thứ tự bị đảo theo khảo sát, nên mọi chỗ phải hỏi [_currentWorld] chứ
  /// không so sánh chỉ số. Nay mảng thi công đã được gỡ khỏi sản phẩm nên chỉ
  /// còn BĐS — giữ nguyên cấu trúc danh sách để không phải viết lại toàn bộ
  /// phần điều hướng vốn đã có test khoá.
  final List<String> _worldOrder = const [kWorldRealEstate];

  /// Số tab của shell. MỘT bộ tab duy nhất cho mọi tài khoản.
  ///
  /// Trước đây có hai "persona" (khách 5 tab / chủ nhà 4 tab) và người dùng bị
  /// đẩy qua lại giữa chúng. Nay có một bộ tab; ba trải nghiệm nằm chung trong
  /// trang Quản lý và đổi bằng công tắc vai trò ở đầu trang.
  static const int _tabCount = 5;

  /// Slot vật lý của thế giới ĐẦU TIÊN trong bottom nav. Khách: 1 (sau Trang
  /// chủ). Chủ nhà: không có thế giới nào.
  static const int _worldSlot0 = 1;

  /// Thế giới ứng với tab đang chọn; rỗng nếu đang ở Trang chủ/Quản lý/Cá
  /// nhân. Hai cờ dưới quyết định vai nào được phép chọn trong trang Quản lý.
  bool get _coCheDoChuNha {
    final user = Provider.of<AuthProvider>(context, listen: false).currentUser;
    return user?.canLoginAs(LoginAccountType.owner) ?? false;
  }

  bool get _coCheDoSale {
    return Provider.of<AuthProvider>(
          context,
          listen: false,
        ).currentUser?.canLoginAs(LoginAccountType.sale) ==
        true;
  }

  String get _currentWorld {
    final i = _currentIndex - _worldSlot0;
    return (i >= 0 && i < _worldOrder.length) ? _worldOrder[i] : '';
  }

  /// Vị trí đã kéo của nút "Đăng tin" (góc trái-trên, toạ độ trong body Stack).
  /// null → dùng vị trí mặc định (giữa, ngay trên bottom bar). Cho phép người
  /// dùng dời nút khi nó che nội dung (vd nút gửi tin nhắn ở màn chat).
  Offset? _fabPos;
  bool _draggingFab = false;
  Size? _fabSize;
  final GlobalKey _fabKey = GlobalKey();
  final GlobalKey _fabStackKey = GlobalKey();

  /// Navigator lồng cho MỖI tab — để trang con mở bằng Navigator.push ở lại
  /// TRONG vùng tab (nằm trên bottom bar) thay vì phủ toàn màn. Nhờ đó bottom
  /// bar luôn hiện khi vào các page con của từng mục.
  final Map<String, GlobalKey<NavigatorState>> _tabNavKeys = {};

  /// Định danh ổn định cho Navigator của tab [index].
  ///
  /// HAI slot đầu (thế giới) key theo WORLD, KHÔNG theo chỉ số vật lý: khi người
  /// dùng được cá nhân hoá Thi-công-trước, `_worldOrder` bị ĐẢO async SAU khi
  /// shell đã dựng. Nếu Navigator key theo chỉ số thì slot 0 giữ nguyên Navigator
  /// CŨ — đã sinh trang chủ một lần bằng màn thế giới cũ (BĐS) — nên đổi `child`
  /// sang Thi công KHÔNG sinh lại route: body + menu kẹt ở BĐS dù nhãn footer đã
  /// đổi (bug chủ dự án gặp). Key theo world → Navigator đi theo đúng thế giới của
  /// nó sang slot mới, mỗi thế giới giữ một Navigator seed đúng màn của mình.
  String _tabIdentity(int index) {
    final w = index - _worldSlot0;
    if (w >= 0 && w < _worldOrder.length) return 'world_${_worldOrder[w]}';
    return 'idx_$index';
  }

  GlobalKey<NavigatorState> _tabNavKey(int index) => _tabNavKeys.putIfAbsent(
    _tabIdentity(index),
    () => GlobalKey<NavigatorState>(),
  );

  /// Tab trước đó — chỉ dùng để biết nội dung mới nên trượt vào từ bên nào.
  /// Sang phải thì vào từ phải, sang trái thì từ trái; trượt sai chiều khiến
  /// người dùng thấy như vừa lùi lại trong khi họ đang tiến tới.
  int _tabTruoc = 0;

  @override
  void initState() {
    super.initState();
    _auth = context.read<AuthProvider>();
    _activeMode = _auth.loginAccountType?.name ?? 'customer';
    if (_activeMode == 'admin') _activeMode = 'customer';
    _modeNotifier.value = _activeMode;
    _auth.addListener(_syncLoginMode);
    _resolveWorldOrder();
    // Người dùng đổi "Màn hình mặc định" trong Profile → đảo lại thứ tự tab ngay,
    // không cần khởi động lại app.
    defaultWorldRevision.addListener(_resolveWorldOrder);
    WidgetsBinding.instance.addPostFrameCallback((_) => _refreshBadges());
    _loadFabPos();
    _loadActiveMode();
  }

  Future<void> _loadActiveMode() async {
    final revision = _modeRevision;
    final stored = await UserPrefsService.instance.getLastMode();
    if (!mounted || revision != _modeRevision) return;
    // Storage may be unavailable in private browsing. The login selection is
    // still valid for this session and must win over a role-based default.
    final saved = _auth.loginAccountType?.name ?? stored;
    final mode = saved == 'customer'
        ? 'customer'
        : saved == 'owner' && _coCheDoChuNha
        ? 'owner'
        : saved == 'sale' && _coCheDoSale
        ? 'sale'
        : 'customer';
    _modeNotifier.value = mode;
    if (mode != _activeMode) setState(() => _activeMode = mode);
  }

  void _syncLoginMode() {
    final selected = _auth.loginAccountType;
    if (!mounted || selected == null) return;
    final mode = selected == LoginAccountType.admin
        ? 'customer'
        : selected.name;
    if (mode == _activeMode) return;
    _modeRevision++;
    setState(() => _activeMode = mode);
    _modeNotifier.value = mode;
  }

  @override
  void dispose() {
    _auth.removeListener(_syncLoginMode);
    defaultWorldRevision.removeListener(_resolveWorldOrder);
    _modeNotifier.dispose();
    super.dispose();
  }

  Future<void> _loadFabPos() async {
    final saved = await UserPrefsService.instance.getFabOffset();
    if (!mounted || saved == null) return;
    setState(() => _fabPos = Offset(saved[0], saved[1]));
  }

  /// Cá nhân hoá THỨ TỰ tab theo khảo sát: người quan tâm Thi công → tab Thi
  /// công đứng đầu (slot 0) nên mở app là thấy ngay màn Thi công; người quan
  /// tâm BĐS giữ thứ tự mặc định. Không đổi `_currentIndex` — chỉ đổi ý nghĩa
  /// của slot 0, nhờ đó deep-link `initialTab` vẫn trỏ đúng vị trí vật lý.
  /// Thứ tự ưu tiên khi quyết định "thế giới" nào đứng slot 0:
  ///   1. Người dùng TỰ chọn trong Profile  → luôn thắng.
  ///   2. Tài khoản là ĐƠN VỊ thi công/thiết kế/nội thất → Thi công.
  ///   3. Khảo sát phân loại suy ra (mặc định BĐS).
  ///
  /// (2) có vì đơn vị đăng nhập vào là để tìm việc/gửi báo giá — bắt họ mỗi lần
  /// mở app phải tự chuyển sang tab Thi công là đẩy chỗ kiếm tiền của họ ra xa.
  /// Danh tính đơn vị KHÔNG nằm trong khảo sát (interests) nên trước đây không
  /// có gì phản ánh nó vào thứ tự tab.
  Future<void> _resolveWorldOrder() async {
    final prefs = await PreferencesService.instance.getLocal();
    final tuChon = await PreferencesService.instance.isDefaultWorldExplicit();
    if (!mounted) return;
    // Không còn khái niệm "đơn vị thi công" — mảng đó đã gỡ khỏi sản phẩm.
    const laDonVi = false;
    if (!mounted) return;
    _applyWorldOrder(
      UserPreferences.resolveWorld(
        theGioiDaLuu: prefs.defaultWorld,
        nguoiDungTuChon: tuChon,
        laDonVi: laDonVi,
      ),
    );
  }

  void _applyWorldOrder(String defaultWorld) {
    // Không còn gì để đảo: chỉ có một thế giới.
    return;
  }

  void _refreshBadges() {
    final user = Provider.of<AuthProvider>(context, listen: false).currentUser;
    if (user == null) return;
    Provider.of<ViewingAppointmentProvider>(
      context,
      listen: false,
    ).refreshBadgeCounts(user.id!);
  }

  void _jumpTo(int idx) {
    setState(() {
      _tabTruoc = _currentIndex;
      _currentIndex = idx.clamp(0, _tabCount - 1);
    });
    _onTabChanged(_currentIndex);
  }

  void _onTabChanged(int index) {
    final user = Provider.of<AuthProvider>(context, listen: false).currentUser;
    if (user == null) return;
    _refreshBadges();
  }

  /// Mở màn đăng tin.
  ///
  /// TRƯỚC ĐÂY chỗ này chặn lại bằng hộp thoại "Trở thành chủ nhà" rồi mới cho
  /// đăng, vì backend nâng vai lên 'host' ở tin đầu tiên. Nhưng đăng tin là
  /// việc của NGƯỜI BÁN — mà mọi tài khoản đăng ký đều là người bán. Bắt họ
  /// nhận mình là chủ nhà để đăng một tin là hỏi sai câu hỏi, và còn đẩy họ
  /// sang một bộ tab khác ngay sau đó.
  Future<void> _onPostHouseTap() async {
    final l = AppLocalizations.of(context);
    // Browse-first: khách chưa đăng nhập → mời đăng nhập trước khi đăng tin.
    if (!GuestGate.requireAuth(context, message: l.shellLoginToPostHouse)) {
      return;
    }
    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const PostHouseScreen()),
    );
  }

  Future<void> _onPrimaryPost() async {
    // Không còn tab Thi công: nút đăng luôn là đăng tin BĐS.
    _onPostHouseTap();
  }

  @override
  Widget build(BuildContext context) {
    final ap = Provider.of<ViewingAppointmentProvider>(context);
    final user = Provider.of<AuthProvider>(context, listen: false).currentUser;

    // Tab "Cá nhân" là TRANG CÔNG KHAI của chính mình, không phải một danh
    // sách menu tài khoản.
    //
    // Lý do: `/sale/:id` là trang họ gửi cho khách. Sửa hồ sơ ở một màn riêng
    // rồi tự hình dung kết quả là cách chắc chắn nhất để bio dài quá khổ hay
    // ảnh lệch khung lọt ra ngoài. Ở đây họ sửa NGAY TRÊN bản khách thấy.
    //
    // MỌI tài khoản đều vào đúng màn này — sale và guest là MỘT, không rẽ theo
    // `account_type` hay `role` nữa. Menu tài khoản (cài đặt, đăng xuất, hoá
    // đơn, đơn của tôi…) lùi vào sau nút bánh răng ở góc phải.
    //
    // Chưa đăng nhập thì không có hồ sơ để mà mở → giữ `ProfileScreen`, nó
    // dựng đúng lời mời đăng nhập.
    void moCaiDat() => Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const SaleSettingsScreen()));

    // CHỦ NHÀ đi đường khác. Trang cá nhân công khai là công cụ của người BÁN —
    // nó tồn tại để gửi link cho khách xem hàng. Chủ nhà không bán, họ VẬN HÀNH
    // toà: hợp đồng, khách thuê, hoá đơn, công tơ. Bắt họ nhìn một trang hồ sơ
    // môi giới rỗng mỗi lần mở tab là đặt sai thứ vào chỗ dễ thấy nhất, còn
    // việc thật thì chôn sau hai lớp menu.
    //
    // Rẽ theo `role == 'host'`, và role đó chỉ đến từ việc THẬT SỰ nhận quản lý
    // một toà (nhập mã bàn giao) — không phải một hạng tài khoản tự phong.
    // CHỦ NHÀ dùng CÙNG trang cá nhân với sale, chỉ KHÔNG đăng tin.
    //
    // Đổi 12/09/2026 theo yêu cầu chủ dự án: trước đây tab Cá nhân của chủ nhà
    // là thẳng bảng điều khiển quản lý nhà, nên họ không có chỗ nào xem/sửa hồ
    // sơ của chính mình. Nay bảng điều khiển dời sang slot "Quản lí nhà" (chỗ
    // của "Đã đặt"), còn tab Cá nhân là trang hồ sơ như mọi tài khoản khác.
    //
    // Vì sao chặn đăng tin: chủ nhà VẬN HÀNH toà, tin rao là việc của sale.
    // Đường đăng tin của họ là gán phòng vào tin có sẵn ở bảng điều khiển.
    final laChuNha = _activeMode == 'owner';
    final Widget profile = user == null
        // `wishlistTab: -1` = KHÔNG còn tab yêu thích để nhảy tới; trang Cá
        // nhân sẽ tự mở `WishlistScreen` bằng push.
        ? ProfileScreen(onJumpTab: _jumpTo, wishlistTab: -1)
        : ValueListenableBuilder<String>(
            valueListenable: _modeNotifier,
            builder: (context, mode, child) => BrokerProfileScreen(
              userId: user.id!,
              name: user.name,
              avatarPath: user.avatarPath,
              laChuTrang: true,
              choDangBai: mode != 'owner',
              onMoCaiDat: moCaiDat,
            ),
          );

    // Khách và sale dùng CHUNG một bộ tab: Trang chủ · Tin tức · Dịch vụ ·
    // Hoạt động · Cá nhân (tab Hoạt động khác theo vai — QuanLyTheoVaiTroScreen).
    // CHỦ NHÀ cũng vậy (chủ dự án 06/10): tab Hoạt động mở Sổ chủ nhà.
    final List<Widget> screens = <Widget>[
            // Slot 0 — TRANG CHỦ: tổng hợp dịch vụ của cả hai thế giới.
            ServiceHubScreen(
              // Slot 1 = Tin tức. Truyền callback thay vì để hub tự biết số
              // slot: thứ tự tab đổi theo vai và theo cấu hình, hằng số 1 nằm
              // trong hub sẽ âm thầm sai vào một ngày nào đó.
              onOpenNews: () => _jumpTo(1),
              // Slot 2 = Dịch vụ. Trước đây ô "Dịch vụ" ở trang chủ tự push
              // một bản ServiceCatalogScreen THỨ HAI vào trong tab Trang chủ:
              // thanh dưới vẫn sáng "Trang chủ", và người dùng có hai bản sao
              // cùng màn nằm ở hai tab khác nhau, cuộn tới đâu cũng không ăn
              // khớp. Nay chuyển hẳn sang tab Dịch vụ có sẵn.
              onOpenServices: () => _jumpTo(2),
            ),
            // Slot 1 — BẤT ĐỘNG SẢN.
            for (final world in _worldOrder)
              GuestHomeScreen(
                key: ValueKey('world_$world'),
                world: world,
                onOpenProfile: () => _jumpTo(4),
                // Vai cố định theo lựa chọn lúc đăng nhập: không còn đổi vai ngay
                // trong app. Muốn dùng vai khác thì đăng xuất rồi đăng nhập lại.
                onOpenMode: null,
                onPostHouse: _onPostHouseTap,
              ),
            // Slot 2 — DỊCH VỤ (thay cho tab Thi công đã gỡ).
            const ServiceCatalogScreen(),
            // Slot 3 — QUẢN LÝ chung: mở đúng sảnh của vai đã đăng nhập (Khách,
            // Sale hoặc Chủ nhà); từng sảnh dẫn vào các luồng nghiệp vụ chi tiết.
            QuanLyTheoVaiTroScreen(
              cheDo: _modeNotifier,
              coCheDoSale: _coCheDoSale,
              coCheDoChuNha: _coCheDoChuNha,
              onTiepTucTimNha: () => _jumpTo(1),
            ),
            profile,
          ];

    // Super-app nav (bTaskee-style) is a dark-launched build flag. When ON the
    // footer becomes a 4-slot bar with a central docked circular FAB; when OFF
    // (default) the existing flat NavigationBar + extended FAB path is kept
    // untouched so rollback is a flag flip, not a code revert.
    final superNav = FeatureFlags.superAppNav;

    // Flat path: extended FAB shows for authenticated users on guest home tab.
    // Pure guests see it too and are prompted with an upgrade dialog before
    // mounting the post screen (auto-upgrades to host on first listing via
    // backend JWT swap).
    // Hiện trên 2 tab thế giới (slot 1 & 2) — hành động đăng đổi theo tab.
    // KHÔNG hiện ở Trang chủ vì trang chủ đã có sẵn ô "Cho thuê"/"Cần bán".
    final showFlatFab =
        !superNav && _currentWorld.isNotEmpty && user != null && !laChuNha;

    // Super-app path: a persistent central "Đăng tin" button available across
    // all tabs for signed-in users. Signed-out visitors get a notch-less bar
    // (no floating action) rather than an empty docked slot.
    final showCenterFab = superNav && user != null && !laChuNha;

    return PopScope(
      // canPop:false → tự xử lý back: ưu tiên pop trang con trong tab hiện tại,
      // rồi về tab BĐS (0), cuối cùng mới cho thoát app.
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        final nav = _tabNavKeys[_tabIdentity(_currentIndex)]?.currentState;
        if (nav != null && nav.canPop()) {
          nav.pop();
        } else if (_currentIndex != 0) {
          setState(() => _currentIndex = 0);
          _onTabChanged(0);
        } else {
          SystemNavigator.pop();
        }
      },
      child: Scaffold(
        // Nút "Đăng tin" KHÔNG dùng Scaffold.floatingActionButton nữa: nó cố định
        // và nổi đè lên mọi màn con push trong tab (vd che nút Gửi ở màn chat).
        // Thay bằng FAB kéo-thả tự do trong body Stack — người dùng dời được khi
        // nó vướng. Vị trí lưu qua UserPrefsService. Áp dụng cả tab BĐS lẫn Thi
        // công.
        body: LayoutBuilder(
          builder: (context, constraints) => Stack(
            key: _fabStackKey,
            clipBehavior: Clip.none,
            children: [
              Positioned.fill(child: _shellBody(screens)),
              if (showCenterFab || showFlatFab)
                _draggablePostFab(constraints, circular: showCenterFab),
            ],
          ),
        ),
        bottomNavigationBar: superNav
            ? SuperAppBottomBar(
                currentIndex: _currentIndex,
                hasCenterNotch: showCenterFab,
                onSelected: (index) {
                  _chonTab(index);
                },
                items: _guestNavItems(ap),
              )
            : _thanhDuoi(ap),
      ),
    );
  }

  /// Thân shell (stack tab) — tách khỏi build để bọc trong Stack chứa FAB
  /// kéo-thả.
  ///
  /// `AnimatedSwitcher` ở đây TRƯỚC ĐÂY dùng để fade giữa hai persona. Không
  /// còn persona nữa nên nó chỉ còn bọc hiệu ứng trượt giữa các tab; giữ lại
  /// với duration 0 để không đổi cảm giác chuyển tab vốn đã có test khoá.
  Widget _shellBody(List<Widget> screens) {
    return Column(
      children: [
        Expanded(
          child: AnimatedSwitcher(
            duration: Duration.zero,
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            child: _ChuyenTab(
              index: _currentIndex,
              sangPhai: _currentIndex >= _tabTruoc,
              child: _LazyIndexedStack(
                index: _currentIndex,
                children: [
                  for (var i = 0; i < screens.length; i++)
                    _TabNavigator(
                      navigatorKey: _tabNavKey(i),
                      child: screens[i],
                    ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// FAB "Đăng tin" kéo-thả. Mặc định nổi giữa, ngay trên bottom bar; kéo để dời
  /// đi chỗ khác khi che nội dung. Vị trí (góc trái-trên trong body) được clamp
  /// trong vùng nhìn thấy và lưu lại qua [UserPrefsService].
  Widget _draggablePostFab(BoxConstraints c, {required bool circular}) {
    final l = AppLocalizations.of(context);
    // LỖI ĐÃ SỬA: nhãn/icon trước đây suy từ `_currentIndex == 1`, trong khi
    // hành động (_onPrimaryPost) suy từ `_isConstructionTab`. Slot 0/1 ĐẢO
    // theo sở thích người dùng (đơn vị thi công mở app vào tab Thi công ở slot
    // 0), nên với họ nút ghi "Đăng tin" nhưng bấm vào lại mở đăng yêu cầu thi
    // công — nhãn nói một đằng, làm một nẻo.
    // Màu nhấn theo thế giới: nút nổi bật nhất màn hình cũng là chỗ báo "bạn
    // đang ở nửa nào" rõ nhất.
    final mauFab = HD.accentDeep;
    final fab = circular
        ? FloatingActionButton(
            key: _fabKey,
            heroTag: 'post_fab',
            onPressed: _draggingFab ? null : _onPrimaryPost,
            shape: const CircleBorder(),
            backgroundColor: mauFab,
            foregroundColor: HD.paperRaised,
            tooltip: l.shellPostListing,
            child: const Icon(Icons.add),
          )
        : FloatingActionButton.extended(
            key: _fabKey,
            heroTag: 'post_fab',
            onPressed: _draggingFab ? null : _onPrimaryPost,
            backgroundColor: mauFab,
            foregroundColor: HD.paperRaised,
            icon: const Icon(Icons.add_home_outlined),
            label: Text(
              l.shellPostListing,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          );

    final gesture = GestureDetector(
      onPanStart: (_) => _onFabPanStart(),
      onPanUpdate: (d) {
        if (_fabPos == null) return;
        setState(() => _fabPos = _clampFabPos(_fabPos! + d.delta, c));
      },
      onPanEnd: (_) => _onFabPanEnd(),
      child: fab,
    );

    // Chưa kéo lần nào → vị trí mặc định (giữa, trên bar ~12px). Đã kéo →
    // toạ độ trái-trên đã lưu.
    if (_fabPos == null) {
      return Positioned(
        left: 0,
        right: 0,
        bottom: 12,
        child: Center(child: gesture),
      );
    }
    final p = _clampFabPos(_fabPos!, c);
    return Positioned(left: p.dx, top: p.dy, child: gesture);
  }

  void _onFabPanStart() {
    // Khởi tạo toạ độ từ vị trí đang render (chạy cho cả trạng thái mặc định),
    // để kéo mượt 1:1 dù nút đang ở đâu / hình dạng nào.
    final box = _fabKey.currentContext?.findRenderObject() as RenderBox?;
    final stack = _fabStackKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || stack == null) return;
    final topLeft = stack.globalToLocal(box.localToGlobal(Offset.zero));
    setState(() {
      _fabSize = box.size;
      _fabPos = topLeft;
      _draggingFab = true;
    });
  }

  void _onFabPanEnd() {
    setState(() => _draggingFab = false);
    final p = _fabPos;
    if (p != null) UserPrefsService.instance.setFabOffset(p.dx, p.dy);
  }

  Offset _clampFabPos(Offset pos, BoxConstraints c) {
    final size = _fabSize ?? const Size(56, 56);
    const margin = 8.0;
    final maxL = (c.maxWidth - size.width - margin);
    final maxT = (c.maxHeight - size.height - margin);
    return Offset(
      pos.dx.clamp(margin, maxL < margin ? margin : maxL),
      pos.dy.clamp(margin, maxT < margin ? margin : maxT),
    );
  }

  /// Chọn tab. Chạm lại tab ĐANG mở → pop trang con của tab đó về gốc (hành vi
  /// quen thuộc của bottom-nav: tab đang xem thì đưa về đầu).
  void _chonTab(int index) {
    if (index == _currentIndex) {
      _tabNavKeys[_tabIdentity(index)]?.currentState?.popUntil(
        (r) => r.isFirst,
      );
      return;
    }
    setState(() {
      _tabTruoc = _currentIndex;
      _currentIndex = index;
    });
    _onTabChanged(index);
  }

  /// Icon mục "Cá nhân": hiện AVATAR người dùng nếu đã đặt (khử lối vào trùng
  /// với avatar AppBar cũ — nay CHỈ 1 lối vào profile qua tab này). Chưa có ảnh
  /// → giữ icon person.
  Widget _personIcon({required bool selected}) {
    final avatar = Provider.of<AuthProvider>(
      context,
      listen: false,
    ).currentUser?.avatarPath;
    if (avatar == null || avatar.isEmpty) {
      // PHẢI tự đặt màu: thanh dưới tắt tô-màu-đè cho tab này (để ảnh đại diện
      // thật không bị nhuộm đỏ), nên icon dự phòng cũng không được tô giúp —
      // thiếu dòng này thì tab Cá nhân đang chọn vẫn đen sì.
      return Icon(
        selected ? Icons.person : Icons.person_outline,
        color: selected ? HD.accent : HD.inkMuted,
      );
    }
    final img = CircleAvatar(
      radius: 12,
      backgroundImage: CachedNetworkImageProvider(
        avatar.startsWith('http') ? avatar : '${ApiConfig.baseUrl}$avatar',
      ),
    );
    if (!selected) return img;
    // Trạng thái chọn: viền accent (bù cho việc avatar không đổi màu như icon).
    return Container(
      padding: const EdgeInsets.all(1.5),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: HD.accent, width: 2),
      ),
      child: img,
    );
  }

  /// Super-app nav items mirroring [_guestDestinations] (icons + labels +
  /// badge). Kept in lock-step so the flat and bTaskee paths stay identical
  /// in meaning — only the chrome differs.
  List<SuperAppNavItem> _guestNavItems(ViewingAppointmentProvider ap) {
    final l = AppLocalizations.of(context);
    return [
      SuperAppNavItem(
        icon: const Icon(Icons.home_outlined),
        selectedIcon: NavTapBounce(selected: true, child: Icon(Icons.home)),
        label: l.shellNavHome,
      ),
      for (final _ in _worldOrder)
        SuperAppNavItem(
          icon: const Icon(Icons.home_work_outlined),
          selectedIcon: NavTapBounce(
            selected: true,
            child: Icon(Icons.home_work),
          ),
          label: l.shellNavRealEstate,
        ),
      SuperAppNavItem(
        icon: const Icon(Icons.handyman_outlined),
        selectedIcon: NavTapBounce(selected: true, child: Icon(Icons.handyman)),
        label: l.shellNavServices,
      ),
      SuperAppNavItem(
        icon: const Icon(Icons.assignment_outlined),
        selectedIcon: NavTapBounce(
          selected: true,
          child: Icon(Icons.assignment),
        ),
        label: 'Hoạt động',
      ),
      SuperAppNavItem(
        icon: _personIcon(selected: false),
        selectedIcon: NavTapBounce(
          selected: true,
          child: _personIcon(selected: true),
        ),
        label: l.shellNavProfile,
      ),
    ];
  }

  /// Thanh điều hướng dưới.
  ///
  /// Dùng [GNav] thay cho `NavigationBar` của Material vì Material tự chạy
  /// cross-fade icon ↔ selectedIcon khoảng 500ms: mọi hiệu ứng tự thêm (nhô
  /// lên, nảy) đều bị nuốt dưới lớp đó, thử thế nào cũng không thấy gì. GNav
  /// giao toàn quyền cho mình — viên nền trượt theo tab và icon phóng to là
  /// hoạt ảnh của chính nó, không phải thứ chồng lên.
  Widget _thanhDuoi(ViewingAppointmentProvider ap) {
    final muc = _guestTabs();
    final i = _currentIndex.clamp(0, muc.length - 1);
    return ConvexAppBar(
      // `react`: MỌI tab giữ icon + nhãn, mảng cong TRƯỢT sang tab vừa chọn và
      // icon ở đó phóng to. Đã thử `titled` trước — kiểu đó bỏ icon của các tab
      // không được chọn, chỉ còn chữ trơ trọi, khác hẳn ảnh mẫu.
      style: TabStyle.react,
      items: muc,
      // ConvexAppBar giữ chỉ số riêng bên trong. Không đưa key theo chỉ số thì
      // khi tab đổi từ NƠI KHÁC (bấm ô ở trang chủ, nút back) thanh vẫn tô sáng
      // tab cũ — lệch hẳn với nội dung đang hiện.
      key: ValueKey('convex_$i'),
      initialActiveIndex: i,
      onTap: _chonTab,
      backgroundColor: HD.paperRaised,
      color: HD.inkMuted,
      activeColor: HD.accent,
      // Mảng cong lấy màu nền của thanh để trông như thanh tự phồng lên, chứ
      // không phải một bong bóng màu khác dán vào.
      height: 58,
      curveSize: 74,
      top: -18,
      elevation: 4,
      curve: Curves.easeOutCubic,
    );
  }

  /// Icon của tab ĐANG CHỌN: vòng tròn viền đỏ bao quanh, nhãn đỏ nằm dưới do
  /// thanh tự vẽ.
  ///
  /// Phải truyền dưới dạng WIDGET chứ không phải `IconData`, kèm
  /// `isIconBlend: false` ở [TabItem] — nếu để thanh tự tô màu thì nó nhuộm cả
  /// vòng tròn lẫn nền thành một khối đỏ đặc, mất hẳn nét viền.
  List<TabItem> _guestTabs() {
    final l = AppLocalizations.of(context);
    return [
      TabItem<dynamic>(
        icon: Icons.home_outlined,
        activeIcon: _iconVongTron(Icons.home),
        isIconBlend: false,
        title: l.shellNavHome,
      ),
      for (final _ in _worldOrder)
        TabItem<dynamic>(
          icon: Icons.home_work_outlined,
          activeIcon: _iconVongTron(Icons.home_work),
          isIconBlend: false,
          title: l.shellNavRealEstate,
        ),
      TabItem<dynamic>(
        icon: Icons.handyman_outlined,
        activeIcon: _iconVongTron(Icons.handyman),
        isIconBlend: false,
        title: l.shellNavServices,
      ),
      // Một tab Hoạt động duy nhất; công tắc vai trò nằm ngay đầu trang như
      // mockup, nên footer không đổi nhãn/icon khi chuyển Khách/Sale/Chủ nhà.
      TabItem<dynamic>(
        icon: Icons.assignment_outlined,
        activeIcon: _iconVongTron(Icons.assignment),
        isIconBlend: false,
        title: 'Hoạt động',
      ),
      // ẢNH ĐẠI DIỆN thật, không phải icon người chung chung: TabItem nhận cả
      // Widget chứ không chỉ IconData. `isIconBlend: false` để avatar giữ màu
      // gốc thay vì bị tô đè theo màu tab.
      TabItem<dynamic>(
        icon: _personIcon(selected: false),
        activeIcon: _personIcon(selected: true),
        isIconBlend: false,
        title: l.shellNavProfile,
      ),
    ];
  }

  Widget _iconVongTron(IconData icon) {
    return Container(
      width: 32,
      height: 32,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: HD.accentTint,
        border: Border.all(color: HD.accent, width: 2),
      ),
      child: Icon(icon, color: HD.accent, size: 17),
    );
  }
}

/// Editorial chrome around chrome-less [BuildingListScreen] so it can serve
/// as a top-level Host tab.
///
/// Note: outer [GuestShell] already owns the Scaffold. Nesting another
/// Scaffold duplicates MediaQuery padding insets and makes
/// `ScaffoldMessenger.of(context)` resolve to this inner scaffold (snackbars
/// disappear with the tab on persona switch). Paint our own SafeArea +

/// IndexedStack lazy: chỉ build con đã từng được hiển thị. Vẫn giữ state các
/// tab đã visit (Offstage cache) — y hệt UX của IndexedStack thường, nhưng
/// không pay startup cost cho 3 tab chưa dùng (mỗi tab kéo theo fetch + WS).
class _LazyIndexedStack extends StatefulWidget {
  const _LazyIndexedStack({required this.index, required this.children});

  final int index;
  final List<Widget> children;

  @override
  State<_LazyIndexedStack> createState() => _LazyIndexedStackState();
}

class _LazyIndexedStackState extends State<_LazyIndexedStack> {
  late List<bool> _visited;

  @override
  void initState() {
    super.initState();
    _visited = List<bool>.filled(widget.children.length, false, growable: true);
    _visited[widget.index] = true;
  }

  @override
  void didUpdateWidget(_LazyIndexedStack oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Children list có thể thay đổi khi persona mode đổi — reset cờ visited.
    if (oldWidget.children.length != widget.children.length) {
      _visited = List<bool>.filled(
        widget.children.length,
        false,
        growable: true,
      );
    }
    if (widget.index >= 0 && widget.index < _visited.length) {
      _visited[widget.index] = true;
    }
  }

  @override
  Widget build(BuildContext context) {
    return IndexedStack(
      index: widget.index,
      children: List<Widget>.generate(widget.children.length, (i) {
        if (!_visited[i]) {
          // Reserve slot rỗng; tab chưa visit chưa init → tiết kiệm fetch+timer.
          return const SizedBox.shrink();
        }
        return widget.children[i];
      }),
    );
  }
}

/// Navigator lồng cho một tab. Trang con mở bằng `Navigator.push(context, …)`
/// từ trong tab sẽ dùng Navigator NÀY (gần nhất) → hiển thị TRONG vùng tab,
/// nằm trên bottom bar. Nhờ đó footer luôn hiện khi vào các page con.
///
/// Trang mở bằng `context.push('/…')` (go_router) vẫn lên root navigator (toàn
/// màn) — đúng cho các trang có URL riêng (chi tiết tin, bản đồ, reel).
class _TabNavigator extends StatelessWidget {
  const _TabNavigator({required this.navigatorKey, required this.child});

  final GlobalKey<NavigatorState> navigatorKey;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Navigator(
      key: navigatorKey,
      onGenerateRoute: (settings) =>
          MaterialPageRoute(settings: settings, builder: (_) => child),
    );
  }
}

/// Hiệu ứng chuyển nội dung khi đổi tab: trượt nhẹ theo hướng đi + mờ dần vào.
///
/// Cố ý KHÔNG dùng [AnimatedSwitcher] hay [PageView]: cả hai đều dựng lại (hoặc
/// giữ sống) cây widget của tab, làm mất vị trí cuộn và bắn lại request của
/// từng tab. Ở đây [IndexedStack] bên dưới vẫn giữ nguyên state như cũ, lớp này
/// chỉ tô hiệu ứng lên khung hình đã dựng.
///
/// Biên độ trượt cố ý NHỎ (6% bề rộng): trượt cả màn hình ở thanh 5 tab làm mắt
/// phải đuổi theo, mà người dùng bấm tab là muốn tới nơi ngay.
class _ChuyenTab extends StatelessWidget {
  const _ChuyenTab({
    required this.index,
    required this.sangPhai,
    required this.child,
  });

  final int index;
  final bool sangPhai;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      // Đổi tab = đổi key = chạy lại từ đầu.
      key: ValueKey(index),
      tween: Tween<double>(begin: 0, end: 1),
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeOutCubic,
      builder: (context, v, ch) {
        final w = MediaQuery.of(context).size.width;
        final dx = (1 - v) * w * 0.06 * (sangPhai ? 1 : -1);
        return Opacity(
          opacity: v,
          child: Transform.translate(offset: Offset(dx, 0), child: ch),
        );
      },
      child: child,
    );
  }
}
