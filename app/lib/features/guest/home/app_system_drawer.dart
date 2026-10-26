import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'package:house_booking/core/config/brand.dart';
import 'package:house_booking/core/widgets/ds.dart';
import 'package:house_booking/data/models/user_preferences.dart'
    show kWorldConstruction;
import 'package:house_booking/features/auth/guest_gate.dart';
import 'package:house_booking/features/chat/conversations_screen.dart';
import 'package:house_booking/features/guest/browse/property_listing_screen.dart';
import 'package:house_booking/features/guest/service/service_catalog_screen.dart';
import 'package:house_booking/features/host/onboarding/become_host_intro_screen.dart';
import 'package:house_booking/features/notifications/notifications_screen.dart';
import 'package:house_booking/l10n/app_localizations.dart';
import 'package:house_booking/providers/auth_provider.dart';
import 'package:house_booking/providers/chat_provider.dart';
import 'package:house_booking/providers/notification_provider.dart';

/// Menu HỆ THỐNG (hamburger bên trái) — điều hướng ĐỔI THEO THẾ GIỚI đang xem
/// ([world] = realestate|construction): mỗi phần hiện đúng mục chức năng của
/// nó. Phần chung (hộp thư, quản trị, trợ giúp) luôn có. Cài đặt CÁ NHÂN nằm
/// trong Hồ sơ (avatar bên phải), không ở đây.
class AppSystemDrawer extends StatelessWidget {
  const AppSystemDrawer({
    super.key,
    this.world = 'realestate',
    this.onPostHouse,
    this.onOpenProfile,
  });

  /// Thế giới hiện tại → quyết định nhóm mục hiển thị.
  final String world;

  /// Mở luồng đăng tin (shell nắm logic guest-gate + become-host).
  final VoidCallback? onPostHouse;

  /// Nhảy tới tab Cá nhân.
  final VoidCallback? onOpenProfile;

  /// Đang ở nửa Thi công? Quyết định nhãn + màu nhấn của menu.
  bool get _laThiCong => world == kWorldConstruction;

  void _go(BuildContext context, Widget screen) {
    Navigator.pop(context); // đóng drawer
    Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().currentUser;
    final canHost = user?.role == 'host' || user?.role == 'admin';
    final isAdmin = user?.role == 'admin';

    return Drawer(
      backgroundColor: HD.paper,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _header(context, user),
            // TOP (cuộn) — CHỈ chức năng RIÊNG của thế giới đang xem.
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 8),
                children: [
                  if (_laThiCong)
                    ..._constructionItems(context)
                  else
                    ..._realestateItems(context, canHost, user != null),
                ],
              ),
            ),
            // FOOTER (ghim đáy) — chức năng DÙNG CHUNG cho cả 2 thế giới.
            _footerMenu(context, isAdmin),
          ],
        ),
      ),
    );
  }

  /// Footer menu (ghim đáy) — chức năng DÙNG CHUNG cả 2 thế giới: hộp thư,
  /// quản trị, trợ giúp. Tách khỏi vùng chức năng riêng ở trên.
  Widget _footerMenu(BuildContext context, bool isAdmin) {
    final l = AppLocalizations.of(context);
    // Material (KHÔNG phải Container có màu) để hiệu ứng chạm của ListTile vẽ
    // ĐƯỢC lên trên nền. Flutter báo thẳng: "ListTile background color or ink
    // splashes may be invisible" khi ListTile nằm trong DecoratedBox có màu.
    return Material(
      color: HD.paperRaised,
      child: Container(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: HD.hairline)),
        ),
        padding: const EdgeInsets.only(top: 6, bottom: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Bỏ nhãn nhóm ở footer: đã có đường kẻ phân cách phía trên, nhãn chỉ
            // tốn ~30px chiều cao — mà chiều cao ở đây đang là thứ đẩy mục cuối
            // của danh sách ra khỏi màn trên web di động.
            _itemBadge(
              context,
              Icons.chat_bubble_outline,
              l.drawerMessages,
              badge: context.watch<ChatProvider>().totalUnread,
              onTap: () => _go(context, const ConversationsScreen()),
            ),
            _itemBadge(
              context,
              Icons.notifications_none_outlined,
              l.notifications,
              badge: context.watch<NotificationProvider>().unread,
              onTap: () => _go(context, const NotificationsScreen()),
            ),
            if (isAdmin)
              _item(
                context,
                Icons.admin_panel_settings_outlined,
                l.drawerSystemAdmin,
                onTap: () {
                  Navigator.pop(context);
                  context.push('/admin');
                },
              ),
            // Trợ giúp + Về ứng dụng: gộp 1 hàng gọn để footer không quá cao.
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 2),
              child: Row(
                children: [
                  _miniLink(
                    context,
                    Icons.help_outline,
                    l.drawerHelp,
                    onTap: () => Navigator.pop(context),
                  ),
                  const SizedBox(width: 8),
                  _miniLink(
                    context,
                    Icons.info_outline,
                    l.drawerAbout,
                    onTap: () {
                      Navigator.pop(context);
                      showAboutDialog(
                        context: context,
                        applicationName: Brand.name,
                        applicationVersion: '1.0.0',
                        applicationLegalese: Brand.legalese,
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _miniLink(
    BuildContext context,
    IconData icon,
    String label, {
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16, color: HD.inkMuted),
              const SizedBox(width: 6),
              // Flexible + ellipsis: chữ dài (hoặc người dùng phóng cỡ chữ hệ
              // thống) làm hàng này TRÀN NGANG — test dựng menu ở bề rộng 390px
              // bắt được "overflowed by 25 pixels".
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12, color: HD.inkSoft),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Mục cho thế giới BẤT ĐỘNG SẢN.
  List<Widget> _realestateItems(
    BuildContext context,
    bool canHost,
    bool daDangNhap,
  ) {
    final l = AppLocalizations.of(context);
    return [
      _label(l.drawerRealEstateSection),
      _item(
        context,
        Icons.map_outlined,
        l.drawerMapPlanning,
        onTap: () {
          Navigator.pop(context);
          context.push('/map');
        },
      ),
      _item(
        context,
        Icons.holiday_village_outlined,
        l.drawerHousesForRent,
        onTap: () =>
            _go(context, const PropertyListingScreen(title: 'Nhà cho thuê')),
      ),
      _item(
        context,
        Icons.factory_outlined,
        l.drawerIndustrialRealEstate,
        onTap: () => _go(
          context,
          const PropertyListingScreen(
            title: 'Mặt bằng kinh doanh',
            groupKey: 'business',
          ),
        ),
      ),
      // Đã bỏ "Hỏi đáp khu vực" (cộng đồng lease): feed chính đã là cộng đồng,
      // mục này không còn cần.
      const SizedBox(height: 4),
      _label(l.drawerPostBusinessSection),
      _item(
        context,
        Icons.add_home_outlined,
        l.drawerPostRental,
        highlight: true,
        onTap: () {
          Navigator.pop(context);
          onPostHouse?.call();
        },
      ),
      if (!canHost)
        _item(
          context,
          Icons.storefront_outlined,
          l.drawerBecomeHost,
          onTap: () => _go(context, const BecomeHostIntroScreen()),
        ),
    ];
  }

  /// Mục cho thế giới DỊCH VỤ (thợ & dịch vụ nhà cửa).
  ///
  /// Mảng thi công (sàn nhà thầu, báo giá, thư viện thiết kế) đã được gỡ khỏi
  /// sản phẩm; chỗ này nay chỉ còn một lối duy nhất — xem danh mục nghề rồi đặt.
  List<Widget> _constructionItems(BuildContext context) {
    final l = AppLocalizations.of(context);
    return [
      _label(l.svcCatalogTitle),
      _item(
        context,
        Icons.handyman_outlined,
        l.svcCatalogTitle,
        highlight: true,
        onTap: () => _go(context, const ServiceCatalogScreen()),
      ),
    ];
  }

  Widget _header(BuildContext context, dynamic user) {
    final l = AppLocalizations.of(context);
    return Container(
      width: double.infinity,
      // Đầu menu THU GỌN. Trước đây padding 20/20 + khẩu hiệu + hàng người
      // dùng chiếm ~160px; cộng với footer ghim đáy thì trên web di động (thanh
      // địa chỉ trình duyệt ăn mất chiều cao, còn ~620px) danh sách chỉ còn
      // ~310px — KHÔNG đủ chỗ, "Thư viện thiết kế" và "Bảng xếp hạng" bị đẩy ra
      // ngoài và Flutter thậm chí không dựng chúng. Người dùng mở menu ra thấy
      // thiếu hẳn chức năng. (Test drawer_visibility_test.dart khoá lại ca này.)
      padding: const EdgeInsets.fromLTRB(20, 12, 16, 12),
      // Nền đầu menu đổi theo thế giới — trước đây cả hai dùng chung
      // HD.appGradient nên phần đập vào mắt đầu tiên là y hệt nhau.
      decoration: BoxDecoration(
        gradient: _laThiCong
            ? LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [HD.constructionTint, HD.paperRaised],
              )
            : HD.appGradient,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const BrandLogo.mark(size: 26),
              const SizedBox(width: 8),
              RichText(
                text: TextSpan(
                  children: [
                    TextSpan(
                      text: Brand.logoPart1,
                      style: HD.masthead(size: 26),
                    ),
                    TextSpan(
                      // Logo bất biến — xem chú thích ở guest_home_screen.
                      text: Brand.logoPart2,
                      style: HD.mastheadItalic(color: HD.accent, size: 26),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          // NHÃN THẾ GIỚI ngay đầu menu. Trước đây hai menu tuy KHÁC danh sách
          // mục nhưng cùng tiêu đề, cùng màu, cùng bố cục nên mở ra vẫn thấy
          // như một — không có gì nói cho người dùng biết họ đang ở nửa nào.
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: HD.worldTint(_laThiCong),
              borderRadius: BorderRadius.circular(HD.rPill),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _laThiCong
                      ? Icons.construction_outlined
                      : Icons.apartment_outlined,
                  size: 13,
                  color: HD.worldAccentDeep(_laThiCong),
                ),
                const SizedBox(width: 4),
                Text(
                  _laThiCong
                      ? l.worldConstructionLabel
                      : l.worldRealEstateLabel,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: .3,
                    color: HD.worldAccentDeep(_laThiCong),
                  ),
                ),
              ],
            ),
          ),
          // Khẩu hiệu CHỈ hiện khi chưa đăng nhập: khi đã có hàng tên + avatar
          // bên dưới thì nó chỉ là chữ trang trí, mà chiều cao ở đây đang là
          // thứ khiến mục cuối bị đẩy khỏi màn.
          if (user == null) ...[
            const SizedBox(height: 6),
            Text(
              l.drawerTagline,
              style: const TextStyle(color: HD.inkSoft, fontSize: 12),
            ),
          ],
          if (user != null) ...[
            const SizedBox(height: 10),
            InkWell(
              onTap: () {
                Navigator.pop(context);
                onOpenProfile?.call();
              },
              borderRadius: BorderRadius.circular(12),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: HD.accentSoft,
                    backgroundImage: (user.avatarPath as String).isNotEmpty
                        ? CachedNetworkImageProvider(user.avatarPath as String)
                        : null,
                    child: (user.avatarPath as String).isEmpty
                        ? const Icon(Icons.person, color: HD.accent, size: 20)
                        : null,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${user.name}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: HD.ink,
                            fontSize: 14,
                          ),
                        ),
                        Text(
                          l.drawerViewProfile,
                          style: const TextStyle(
                            color: HD.accent,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right, color: HD.inkMuted, size: 18),
                ],
              ),
            ),
          ] else ...[
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(backgroundColor: HD.accent),
                onPressed: () {
                  Navigator.pop(context);
                  GuestGate.promptLogin(context, message: l.drawerLoginPrompt);
                },
                icon: const Icon(Icons.login, size: 18),
                label: Text(l.drawerLoginRegister),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _label(String t) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 12, 20, 6),
    child: Text(
      t,
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.bold,
        letterSpacing: 1.1,
        color: HD.inkMuted,
      ),
    ),
  );

  Widget _item(
    BuildContext context,
    IconData icon,
    String title, {
    required VoidCallback onTap,
    bool highlight = false,
  }) {
    // Icon mang MÀU THẾ GIỚI. Trước đây luôn xanh BĐS kể cả trong menu Thi
    // công — mỗi hàng đều có một ô màu xanh, nên dù danh sách mục đã khác,
    // hai menu vẫn cho cảm giác y hệt nhau khi liếc qua.
    final mau = HD.worldAccent(_laThiCong);
    final mauNen = HD.worldTint(_laThiCong);
    return ListTile(
      dense: true,
      leading: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: highlight ? mau : mauNen,
          borderRadius: BorderRadius.circular(9),
        ),
        child: Icon(icon, color: highlight ? HD.paperRaised : mau, size: 19),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 14,
          color: highlight ? HD.worldAccentDeep(_laThiCong) : HD.ink,
        ),
      ),
      onTap: onTap,
    );
  }

  Widget _itemBadge(
    BuildContext context,
    IconData icon,
    String title, {
    required int badge,
    required VoidCallback onTap,
  }) {
    return ListTile(
      dense: true,
      leading: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: HD.accentSoft,
          borderRadius: BorderRadius.circular(9),
        ),
        child: Icon(icon, color: HD.accent, size: 19),
      ),
      title: Text(
        title,
        style: const TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 14,
          color: HD.ink,
        ),
      ),
      trailing: badge <= 0
          ? null
          : Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: HD.accent,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                badge > 99 ? '99+' : '$badge',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
      onTap: onTap,
    );
  }
}
