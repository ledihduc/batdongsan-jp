import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'package:house_booking/core/config/brand.dart';
import 'package:house_booking/core/config/api_config.dart';
import 'package:house_booking/core/widgets/ds.dart';
import 'package:house_booking/data/services/host_public_api.dart';
import 'package:house_booking/features/guest/broker/broker_profile_screen.dart';
import 'package:house_booking/features/guest/broker/sale_directory_screen.dart';
import 'package:house_booking/features/guest/browse/trade_hub_screen.dart';
import 'package:house_booking/features/guest/home/widgets/home_map_preview.dart';
import 'package:house_booking/features/guest/home/widgets/latest_listings_strip.dart';
import 'package:house_booking/features/guest/search/search_screen.dart';
import 'package:house_booking/features/notifications/notifications_screen.dart';
import 'package:house_booking/l10n/app_localizations.dart';
import 'package:house_booking/providers/auth_provider.dart';

/// TRANG CHỦ — tổng hợp mọi dịch vụ của app (BĐS + Thi công).
/// Route: không có URL (slot 0 của [GuestShell], có bottom nav).
/// Provider: AuthProvider (tên/avatar để chào).
/// API: GET /api/hosts/featured · /api/construction/contractors ·
/// /api/construction/services — TẤT CẢ đều fail-silent: lỗi mạng chỉ làm mục đó ẩn đi,
/// không bao giờ chặn trang chủ.
///
/// Mọi lối đi đều mở màn con bằng `Navigator.push` để nằm TRONG tab (giữ bottom
/// bar) — trừ "Kiểm tra quy hoạch" dùng `context.push('/planning')` vì đó là
/// GoRoute có URL (mở thẳng bản đồ ở chế độ quy hoạch).
/// cổng đăng nhập + mời nâng cấp chủ nhà).
class ServiceHubScreen extends StatefulWidget {
  const ServiceHubScreen({super.key, this.onOpenNews, this.onOpenServices});

  /// Chuyển thanh dưới sang tab Tin tức. Do shell cấp vì chỉ nó biết thứ tự tab.
  final VoidCallback? onOpenNews;

  /// Chuyển thanh dưới sang tab Dịch vụ — cũng do shell cấp, cùng lý do.
  final VoidCallback? onOpenServices;

  @override
  State<ServiceHubScreen> createState() => _ServiceHubScreenState();
}

class _ServiceHubScreenState extends State<ServiceHubScreen> {
  static const _hostApi = HostPublicApi();

  List<Map<String, dynamic>> _brokers = const [];

  /// Người bán TỰ KHAI là môi giới (`seller_kind == 'broker'`, suy từ tin của
  /// họ ở backend). Phần còn lại — gồm cả người CHƯA khai — nằm ở [_owners]:
  /// chưa khai thì không đoán bừa là môi giới.
  List<Map<String, dynamic>> get _agents =>
      _brokers.where((b) => b['seller_kind'] == 'broker').toList();

  List<Map<String, dynamic>> get _owners =>
      _brokers.where((b) => b['seller_kind'] != 'broker').toList();
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    // Lỗi thì để danh sách rỗng chứ không dựng màn lỗi: đây là một dải phụ,
    // hỏng nó không được kéo cả trang chủ sập theo.
    final ds = await _hostApi.featured().catchError(
      (_) => <Map<String, dynamic>>[],
    );
    if (!mounted) return;
    setState(() {
      _brokers = ds.take(10).toList();
      _loading = false;
    });
  }

  // ── Điều hướng ────────────────────────────────────────────────────────────
  void _push(Widget screen) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: HD.paper,
      body: SafeArea(
        bottom: false,
        // Khối đầu trang nằm TRONG danh sách cuộn, không còn cố định bên trên:
        // ảnh minh hoạ trôi lên theo ngón tay thay vì đứng yên chiếm chỗ khi
        // người dùng đang đọc nội dung phía dưới.
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            _Header(
              onSearch: () => _push(const SearchScreen()),
              onNotifications: () => _push(const NotificationsScreen()),
              onBanner: () => _push(TradeHubScreen(title: l.hubActionTrade)),
            ),
            Padding(
              // Chừa trên đúng NỬA THẺ đang tràn xuống + khoảng thở.
              padding: const EdgeInsets.fromLTRB(
                HD.s16,
                _Header.nuaThe + HD.s16,
                HD.s16,
                HD.s24,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _primaryActions(l),
                  const SizedBox(height: HD.s16),
                  if (_loading) const _SectionSkeleton(),
                  // Bản đồ xem trước — dải ngang, đặt TRÊN mục dịch vụ. Nó là
                  // lối vào nhanh nhất tới kho tin, nên đứng ngay sau bốn ô
                  // hành động chứ không nằm lẫn giữa các danh sách.
                  DsSectionHeader(
                    title: l.hubMapSection,
                    padding: EdgeInsets.zero,
                    titleSize: 18,
                  ),
                  const SizedBox(height: HD.s12),
                  const HomeMapPreview(requestLocationOnLoad: true),
                  const SizedBox(height: HD.s20),

                  // Tin đăng mới nhất. Đặt ngay sau bản đồ: hai khối này là
                  // NỘI DUNG THẬT của app, còn danh sách người bán và lưới
                  // menu bên dưới chỉ là lối đi.
                  DsSectionHeader(
                    title: l.homeNewsSection,
                    padding: EdgeInsets.zero,
                    titleSize: 18,
                    trailingLabel: l.hubViewAll,
                    onTrailingTap: () => widget.onOpenNews?.call(),
                  ),
                  const SizedBox(height: HD.s12),
                  const LatestListingsStrip(),
                  const SizedBox(height: HD.s24),
                  // ĐÃ BỎ dải "Đơn vị dịch vụ". Nó là bản rút gọn của tab
                  // "Dịch vụ" ở thanh dưới — cùng nguồn `GET /api/services`,
                  // cùng hành động (mở form đặt dịch vụ) — nên chỉ làm trang
                  // này dài thêm mà không dẫn đi đâu mới.
                  // Người bán tiêu biểu — xếp CUỐI phần nội dung. Đây là
                  // danh sách người, không phải thứ người dùng tới đây để làm;
                  // đứng ngay dưới 4 ô hành động thì nó đẩy tin đăng và đơn vị
                  // dịch vụ (thứ có nội dung mới mỗi ngày) xuống quá sâu.
                  if (!_loading) ...[
                    DsSectionHeader(
                      // "Người bán tiêu biểu" chứ không phải "Môi giới tiêu
                      // biểu": danh sách này gồm mọi người có tin, phần lớn là
                      // chủ nhà tự đăng — gọi tất cả là môi giới là sai. Vì
                      // vậy chia làm hai hàng theo nhãn TỰ KHAI của họ.
                      title: l.hubFeaturedSellers,
                      padding: EdgeInsets.zero,
                      titleSize: 18,
                      trailingLabel: l.hubViewAll,
                      onTrailingTap: () => _push(const SaleDirectoryScreen()),
                    ),
                    if (_brokers.isEmpty) ...[
                      const SizedBox(height: HD.s12),
                      _saleDirectoryCallout(),
                    ],
                    if (_agents.isNotEmpty) ...[
                      const SizedBox(height: HD.s12),
                      _nhanHang(l.hubRowBrokers),
                      const SizedBox(height: HD.s8),
                      _brokerStrip(_agents),
                    ],
                    if (_owners.isNotEmpty) ...[
                      const SizedBox(height: HD.s12),
                      _nhanHang(l.hubRowOwners),
                      const SizedBox(height: HD.s8),
                      _brokerStrip(_owners),
                    ],
                  ],
                  // ĐÃ BỎ lưới menu cuối trang (BẤT ĐỘNG SẢN · Thợ & dịch vụ
                  // nhanh · CHUNG). Bốn trong sáu ô của nó trùng với bốn ô hành
                  // động ở đầu trang và với thanh tab dưới; hai mục còn lại chỉ
                  // có ĐÚNG MỘT ô dưới một tiêu đề in hoa, nhìn như lỗi dựng.
                  //
                  // Hai lối đi không trùng vẫn còn đường khác: "Trở thành chủ
                  // nhà" nằm ở tab Cá nhân, "BĐS công nghiệp" vào bằng chip
                  // "Kinh doanh" trong màn Mua bán · Cho thuê.
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── 4 ô hành động chính ───────────────────────────────────────────────────
  /// Bốn ô CÙNG một màu đỏ thương hiệu — phân biệt bằng icon + nhãn, không
  /// bằng màu. Bản trước dùng 4 màu khác nhau (đỏ · vàng · đỏ sẫm · xanh lá):
  /// bốn màu ngang cấp không nói lên thứ tự ưu tiên nào, mà vàng/xanh lá còn
  /// mang nghĩa "cảnh báo/thành công" ở chỗ khác trong app.
  ///
  /// Bốn việc, bốn đích khác nhau:
  ///   * Cho thuê — xem danh sách tin cho thuê.
  ///   * Đăng tin — sang tab Tin tức.
  ///   * Check quy hoạch — vào THẲNG `/planning` (GoRoute có URL).
  ///   * Dịch vụ — danh bạ đơn vị dịch vụ/nhà thầu.
  Widget _primaryActions(AppLocalizations l) {
    final o = <_HubAction>[
      // null = không lọc loại giao dịch: ô này gộp cả mua bán lẫn cho thuê.
      // Ô này KHÔNG mở danh sách trộn lẫn nữa: người đi mua và người đi bán
      // cần hai thứ ngược nhau, [TradeHubScreen] tách hẳn hai bên.
      _HubAction(
        Icons.home_work_outlined,
        l.hubActionTrade,
        () => _push(TradeHubScreen(title: l.hubActionTrade)),
      ),
      // Ô này KHÔNG vào thẳng form đăng tin nữa: "Đăng tin nhu cầu" gồm cả tin
      // rao (tôi có nhà) lẫn tin nhu cầu (tôi đang tìm) — hai loại dữ liệu khác
      // hẳn nhau, nên phải hỏi trước.
      // Sang thẳng tab Tin tức. Trước đây ô này mở màn "Bạn muốn đăng gì?" —
      // màn đó được push lên navigator GỐC nên nó nổi trên MỌI tab: bấm về
      // Trang chủ vẫn thấy nó nằm đè lên, tưởng như app quay ngược lại.
      // Đăng tin nhu cầu nay đi bằng nút "Đăng tin" trong màn Mua bán · Cho thuê.
      _HubAction(
        Icons.drive_file_rename_outline,
        l.hubActionPost,
        () => widget.onOpenNews?.call(),
      ),
      _HubAction(
        Icons.travel_explore_outlined,
        l.hubActionPlanning,
        () => context.push('/planning'),
      ),
      // Sang thẳng TAB Dịch vụ chứ không push một bản sao vào tab này: đã có
      // đúng màn đó ở thanh dưới, push thêm là hai bản sao ở hai tab.
      _HubAction(
        Icons.handshake_outlined,
        l.hubActionServices,
        () => widget.onOpenServices?.call(),
      ),
    ];
    return Column(
      children: [
        Row(
          children: [
            Expanded(child: _actionTile(o[0])),
            const SizedBox(width: HD.s8),
            Expanded(child: _actionTile(o[1])),
          ],
        ),
        const SizedBox(height: HD.s8),
        Row(
          children: [
            Expanded(child: _actionTile(o[2])),
            const SizedBox(width: HD.s8),
            Expanded(child: _actionTile(o[3])),
          ],
        ),
      ],
    );
  }

  /// Chiều cao CỐ ĐỊNH cho cả bốn ô.
  ///
  /// Trước đây mỗi ô tự cao theo nhãn của chính nó: "Mua bán · Cho thuê" xuống
  /// hai dòng trên máy hẹp còn "Dịch vụ" chỉ một dòng, nên bốn ô so le nhau —
  /// và `Row` mặc định canh GIỮA theo trục dọc chứ không kéo cho bằng, nên hai
  /// ô cùng hàng cũng lệch. Cố định chiều cao là cách chắc chắn cho mọi bề
  /// rộng máy VÀ mọi bản dịch (nhãn tiếng Anh/Trung dài ngắn khác tiếng Việt).
  static const double _hubActionHeight = 50;

  Widget _actionTile(_HubAction item) {
    return SizedBox(
      // Khoá để test bố cục tóm đúng 4 ô này (màn còn nhiều InkWell khác: ô
      // tìm kiếm, thẻ người bán…).
      key: ValueKey('hubAction_${item.label}'),
      height: _hubActionHeight,
      child: Material(
        color: HD.accent,
        borderRadius: BorderRadius.circular(HD.r12),
        child: InkWell(
          borderRadius: BorderRadius.circular(HD.r12),
          onTap: item.onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(item.icon, color: Colors.white, size: 18),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    item.label,
                    // Tối đa 2 dòng rồi mới cắt: ô đã cố định chiều cao nên
                    // nhãn dài không còn đẩy các ô lệch nhau nữa.
                    maxLines: 2,
                    textAlign: TextAlign.center,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      height: 1.15,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Môi giới tiêu biểu ────────────────────────────────────────────────────
  Widget _saleDirectoryCallout() => Material(
    color: HD.accentTint,
    borderRadius: BorderRadius.circular(HD.r12),
    child: InkWell(
      onTap: () => _push(const SaleDirectoryScreen()),
      borderRadius: BorderRadius.circular(HD.r12),
      child: Padding(
        padding: const EdgeInsets.all(HD.s12),
        child: Row(
          children: [
            const CircleAvatar(
              backgroundColor: HD.paperRaised,
              child: Icon(Icons.person_search_rounded, color: HD.accent),
            ),
            const SizedBox(width: HD.s12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Tìm Sale', style: HD.bodyBold(size: 14.5)),
                  Text(
                    'Tìm theo tên hoặc email để xem hồ sơ và liên hệ',
                    style: HD.body(size: 12, color: HD.inkMuted),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: HD.accent),
          ],
        ),
      ),
    ),
  );

  Widget _brokerStrip(List<Map<String, dynamic>> ds) {
    return SizedBox(
      height: 104,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: ds.length,
        separatorBuilder: (_, _) => const SizedBox(width: HD.s12),
        itemBuilder: (_, i) {
          final b = ds[i];
          final id = b['id'] as int?;
          final name = (b['name'] as String?) ?? '';
          final avatar = b['avatar_path'] as String?;
          final trusted = b['trusted'] == true;
          return SizedBox(
            width: 76,
            child: InkWell(
              onTap: id == null
                  ? null
                  : () => _push(
                      BrokerProfileScreen(
                        userId: id,
                        name: name,
                        avatarPath: avatar,
                      ),
                    ),
              child: Column(
                children: [
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      CircleAvatar(
                        radius: 26,
                        backgroundColor: HD.accentTint,
                        backgroundImage: (avatar != null && avatar.isNotEmpty)
                            ? CachedNetworkImageProvider(_abs(avatar))
                            : null,
                        child: (avatar == null || avatar.isEmpty)
                            ? const Icon(
                                Icons.person,
                                color: HD.accent,
                                size: 24,
                              )
                            : null,
                      ),
                      // Tick "chủ nhà tin cậy" — ngưỡng do backend quyết
                      // (đã xác minh + điểm ≥4.8 + ≥5 đánh giá).
                      if (trusted)
                        const Positioned(
                          right: -2,
                          bottom: -2,
                          child: CircleAvatar(
                            radius: 9,
                            backgroundColor: HD.paperRaised,
                            child: Icon(
                              Icons.verified,
                              size: 14,
                              color: HD.positive,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: HD.s4),
                  Text(
                    name,
                    maxLines: 2,
                    textAlign: TextAlign.center,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 11, color: HD.inkSoft),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  /// Nhãn hàng con trong một mục (nhỏ hơn tiêu đề mục).
  Widget _nhanHang(String t) => Text(
    t,
    style: const TextStyle(
      fontSize: 13,
      fontWeight: FontWeight.w600,
      color: HD.inkSoft,
    ),
  );
}

/// Một ô hành động lớn ở trang chủ (icon · nhãn · việc cần làm). Không có
/// trường màu: bốn ô dùng chung màu thương hiệu.
class _HubAction {
  const _HubAction(this.icon, this.label, this.onTap);

  final IconData icon;
  final String label;
  final VoidCallback onTap;
}

/// Absolute URL helper — mirrors `_abs` trong các màn construction.
String _abs(String url) =>
    url.startsWith('http') ? url : '${ApiConfig.baseUrl}$url';

/// Đầu trang đỏ: người dùng · logo thương hiệu (xem `Brand`) · chuông.
/// Khối đầu trang chủ: lời chào · logo · chuông · ô tìm kiếm · thẻ giới thiệu,
/// tất cả đặt trên MỘT nền minh hoạ liền mạch.
///
/// Trước đây đầu trang là một khối đỏ phẳng, còn thẻ giới thiệu nằm rời trong
/// danh sách cuộn bên dưới. Gộp lại thành một khối vì mắt đọc chúng như một
/// mảng: chào — tìm — vào việc.
class _Header extends StatelessWidget {
  const _Header({
    required this.onSearch,
    required this.onNotifications,
    required this.onBanner,
  });

  final VoidCallback onSearch;
  final VoidCallback onNotifications;
  final VoidCallback onBanner;

  /// Ảnh nền minh hoạ. Thiếu tệp thì rơi về nền vẽ bằng mã — KHÔNG để màn hình
  /// vỡ chỉ vì một tệp ảnh chưa được thả vào.
  static const String _anhNen = 'assets/branding/hero_bg.jpg';

  /// Chiều cao THẺ giới thiệu, cố định. Cần con số biết trước vì thẻ tràn một
  /// nửa xuống dưới mép ảnh: phần nội dung phía sau phải chừa đúng bấy nhiêu
  /// chỗ, mà đo chiều cao thật lúc chạy thì phải dựng hai lần mỗi khung hình.
  static const double _caoThe = 84;

  /// Nửa thẻ tràn xuống — nơi gọi dùng để chừa khoảng trên.
  static const double nuaThe = _caoThe / 2;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final user = context.select<AuthProvider, String?>(
      (a) => a.currentUser?.name,
    );
    final avatar = context.select<AuthProvider, String?>(
      (a) => a.currentUser?.avatarPath,
    );

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned.fill(
          child: Image.asset(
            _anhNen,
            fit: BoxFit.cover,
            alignment: Alignment.bottomCenter,
            errorBuilder: (_, _, _) => const _NenDuPhong(),
          ),
        ),
        // Lớp phủ đỏ ĐẬM DẦN LÊN TRÊN. Không phải để cho đẹp: ảnh nền vùng
        // trên chỉ sáng 119/255, chữ trắng đặt lên đó đạt tương phản ~2,5:1 —
        // dưới xa ngưỡng đọc được 4,5:1. Phủ xong phần trên thành đỏ đặc như
        // ảnh mẫu, phần dưới vẫn để lộ minh hoạ và gợn sóng.
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  HD.accent,
                  HD.accent.withValues(alpha: 0.82),
                  HD.accent.withValues(alpha: 0.0),
                ],
                stops: const [0, 0.34, 0.72],
              ),
            ),
          ),
        ),
        Padding(
          // Chừa đáy rộng hơn ba cạnh kia: gợn sóng trắng của ảnh nền nằm ở
          // dưới cùng, thẻ giới thiệu đè lên thì mất luôn chỗ chuyển tiếp sang
          // nền trắng của trang.
          padding: const EdgeInsets.fromLTRB(HD.s16, HD.s16, HD.s16, HD.s16),
          // Chiều cao TỐI THIỂU: nếu để khối co theo nội dung thì thẻ giới
          // thiệu nằm sát đáy và che gần hết minh hoạ — chỉ còn thấy một mẩu
          // mái nhà. Chừa sẵn khoảng trống dưới thẻ để ngôi nhà và gợn sóng
          // hiện ra.
          child: ConstrainedBox(
            // Hạ dần theo hai lần cắt đỉnh ảnh (100px rồi 50px nữa): phần bị
            // cắt vốn chỉ là mảng đỏ phẳng, giữ nguyên chiều cao cũ chỉ tổ đẩy
            // nội dung xuống sâu hơn mà không cho thấy gì thêm. 300 → 260 → 215.
            constraints: const BoxConstraints(minHeight: 215),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(child: _loiChao(l, user, avatar)),
                    _logo(),
                    Expanded(
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: IconButton(
                          onPressed: onNotifications,
                          tooltip: l.hubNotifications,
                          icon: const Icon(
                            Icons.notifications_none,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: HD.s12),
                _oTim(l),
              ],
            ),
          ),
        ),
        // Thẻ giới thiệu VẮT NGANG mép dưới ảnh: nửa trên đè lên minh hoạ, nửa
        // dưới thò xuống nền trắng của trang. `Clip.none` ở Stack là bắt buộc,
        // không thì phần thò ra bị cắt cụt.
        Positioned(
          left: HD.s16,
          right: HD.s16,
          bottom: -nuaThe,
          height: _caoThe,
          child: _theGioiThieu(l),
        ),
      ],
    );
  }

  Widget _loiChao(AppLocalizations l, String? user, String? avatar) {
    return Row(
      children: [
        CircleAvatar(
          radius: 16,
          backgroundColor: Colors.white24,
          backgroundImage: (avatar != null && avatar.isNotEmpty)
              ? CachedNetworkImageProvider(_abs(avatar))
              : null,
          child: (avatar == null || avatar.isEmpty)
              ? const Icon(Icons.person, size: 18, color: Colors.white)
              : null,
        ),
        const SizedBox(width: HD.s8),
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                l.hubGreeting,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.85),
                  fontSize: 11,
                ),
              ),
              Text(
                user ?? l.hubGuest,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _logo() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const BrandLogo.mark(size: 26, onDark: true),
        RichText(
          text: TextSpan(
            children: [
              TextSpan(
                text: Brand.logoPart1,
                style: HD.masthead(size: 15, color: Colors.white),
              ),
              TextSpan(
                text: Brand.logoPart2,
                style: HD.mastheadItalic(size: 15, color: Colors.white),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _oTim(AppLocalizations l) {
    return InkWell(
      onTap: onSearch,
      borderRadius: BorderRadius.circular(HD.rPill),
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 5, 5, 5),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(HD.rPill),
        ),
        child: Row(
          children: [
            const Icon(Icons.search, color: HD.inkMuted, size: 20),
            const SizedBox(width: HD.s8),
            Expanded(
              child: Text(
                l.hubSearchHint,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: HD.inkMuted, fontSize: 13),
              ),
            ),
            // Nút tròn đỏ ở cuối ô: ô này chỉ là LỐI VÀO màn tìm kiếm, nên cần
            // một thứ trông bấm được — chữ mờ không nói lên điều đó.
            Container(
              width: 36,
              height: 36,
              decoration: const BoxDecoration(
                color: HD.accent,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.search, color: Colors.white, size: 19),
            ),
          ],
        ),
      ),
    );
  }

  Widget _theGioiThieu(AppLocalizations l) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(HD.r12),
      elevation: 3,
      child: InkWell(
        borderRadius: BorderRadius.circular(HD.r12),
        onTap: onBanner,
        child: Padding(
          padding: const EdgeInsets.all(HD.s12),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: const BoxDecoration(
                  color: HD.accent,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.apartment_rounded,
                  color: Colors.white,
                  size: 19,
                ),
              ),
              const SizedBox(width: HD.s12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      l.hubBannerTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: HD.bodyBold(size: 13).copyWith(color: HD.accent),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      l.hubBannerSubtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: HD.caption(),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: HD.inkMuted, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}

/// Nền vẽ bằng mã, dùng khi chưa có tệp ảnh minh hoạ: dải đỏ chuyển sắc + một
/// gợn sóng trắng ở đáy, giữ đúng bố cục để thả ảnh thật vào không phải sửa gì.
class _NenDuPhong extends StatelessWidget {
  const _NenDuPhong();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(gradient: HD.accentGradient),
      child: CustomPaint(painter: _SongTrang(), child: const SizedBox.expand()),
    );
  }
}

class _SongTrang extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..color = Colors.white;
    final duong = Path()
      ..moveTo(0, size.height)
      ..lineTo(0, size.height * 0.88)
      // Một gợn: điểm điều khiển lệch phải để sóng dâng dần về bên phải, giống
      // đường lượn trong ảnh minh hoạ.
      ..quadraticBezierTo(
        size.width * 0.45,
        size.height * 0.74,
        size.width,
        size.height * 0.95,
      )
      ..lineTo(size.width, size.height)
      ..close();
    canvas.drawPath(duong, p);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _SectionSkeleton extends StatelessWidget {
  const _SectionSkeleton();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: List.generate(
        2,
        (_) => Padding(
          padding: const EdgeInsets.only(bottom: HD.s16),
          child: Container(
            height: 84,
            decoration: BoxDecoration(
              color: HD.paperSunken,
              borderRadius: BorderRadius.circular(HD.r12),
            ),
          ),
        ),
      ),
    );
  }
}
