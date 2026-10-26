import 'package:house_booking/features/host/ekyc/ekyc_chu_nha_screen.dart';
import 'package:house_booking/features/guest/short_stay/short_stay_bookings_screen.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:house_booking/core/config/api_config.dart';
import 'package:house_booking/core/config/env.dart';
import 'package:house_booking/core/config/legal_links.dart';
import 'package:house_booking/core/widgets/ds.dart';
import 'package:house_booking/data/models/login_account_type.dart';
import 'package:house_booking/data/services/host_public_api.dart';
import 'package:house_booking/features/guest/profile/change_password_screen.dart';
import 'package:house_booking/features/chat/conversations_screen.dart';
import 'package:house_booking/features/guest/booking/booking_history_screen.dart';
import 'package:house_booking/features/guest/broker/khay_lien_he_sheet.dart';
import 'package:house_booking/features/guest/profile/blocked_users_screen.dart';
import 'package:house_booking/features/guest/profile/edit_profile_screen.dart';
import 'package:house_booking/features/guest/profile/settings_screen.dart'
    show SettingsScreen, logoutFlow, xoaTaiKhoanFlow;
import 'package:house_booking/features/guest/project/sale_projects_screen.dart';
import 'package:house_booking/features/guest/project/building_claim_screen.dart';
import 'package:house_booking/features/guest/sale/link_sale_screen.dart';
import 'package:house_booking/features/guest/sale/sale_code_screen.dart';
import 'package:house_booking/features/guest/service/my_service_requests_screen.dart';
import 'package:house_booking/features/host/appointments/host_appointments_screen.dart';
import 'package:house_booking/features/host/billing/screens/invoice_list_screen.dart';
import 'package:house_booking/features/host/billing/screens/debt_aging_screen.dart';
import 'package:house_booking/features/host/lich_phong/lich_phong_screen.dart';
import 'package:house_booking/features/host/profile/my_listings_screen.dart';
import 'package:house_booking/l10n/app_localizations.dart';
import 'package:house_booking/providers/auth_provider.dart';
import 'package:house_booking/providers/locale_provider.dart';

/// Cài đặt & tài khoản của NGƯỜI BÁN. Route: không có URL (push từ nút ⚙ trên
/// trang cá nhân). Provider: AuthProvider, LocaleProvider.
/// API: GET /api/hosts/{id} (số liệu đầu trang).
///
/// Khác `SettingsScreen` chung ở chỗ nó gom cả công cụ bán hàng — tin đăng, dự
/// án, mã liên kết chủ nhà, lịch dẫn khách — vào cùng một chỗ với cài đặt, vì
/// với sale đó là một việc: quản lý cửa hàng của mình.
///
/// **Nguyên tắc đã áp cho màn này: KHÔNG vẽ mục không chạy được.** Bản thiết kế
/// tham chiếu có ví tiền, gói Pro, điểm uy tín 98/100, tự động đẩy tin, Face
/// ID, thiết bị đang đăng nhập, hotline riêng — hệ thống không có thứ nào
/// trong đó. Vẽ ra là hứa suông, và Apple 2.1 từ chối vì đúng lý do này.
class SaleSettingsScreen extends StatefulWidget {
  const SaleSettingsScreen({super.key, this.profileLoader});

  /// Nguồn số liệu đầu trang. Tách ra vì `ApiClient` đọc JWT qua secure
  /// storage, và trong widget test kênh platform đó KHÔNG BAO GIỜ trả lời —
  /// bơm ở tầng này mới thoát được.
  final Future<Map<String, dynamic>> Function(int userId)? profileLoader;

  @override
  State<SaleSettingsScreen> createState() => _SaleSettingsScreenState();
}

class _SaleSettingsScreenState extends State<SaleSettingsScreen> {
  Map<String, dynamic>? _hoSo;

  @override
  void initState() {
    super.initState();
    _nap();
  }

  Future<void> _nap() async {
    final id = context.read<AuthProvider>().currentUser?.id;
    if (id == null) return;
    try {
      final d = widget.profileLoader != null
          ? await widget.profileLoader!(id)
          : await const HostPublicApi().profile(id);
      if (mounted) setState(() => _hoSo = d);
    } catch (_) {
      // Số liệu đầu trang hỏng thì vẫn phải vào được cài đặt.
    }
  }

  Future<void> _mo(Widget man) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => man));
    if (mounted) _nap();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final u = context.watch<AuthProvider>().currentUser;
    if (u == null) return const SizedBox.shrink();

    return Scaffold(
      backgroundColor: HD.paper,
      appBar: const DsAppBar(title: 'Cài đặt & tài khoản'),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(HD.s12, HD.s12, HD.s12, HD.s32),
        children: [
          _theDauTrang(u),
          const SizedBox(height: HD.s16),
          if (context.watch<AuthProvider>().loginAccountType ==
              LoginAccountType.sale) ...[
            _phimTatTrangSale(u),
            const SizedBox(height: HD.s16),
          ],

          // ĐẶT TRÊN CÙNG, không nhét vào nhóm nào: đây là việc người ta mở
          // app để xem NHIỀU LẦN trong ngày ("nhà mình hẹn xem đã được duyệt
          // chưa"), khác hẳn mấy mục cài đặt bên dưới vốn sửa một lần rồi
          // thôi. Nằm giữa danh sách thì phải cuộn tìm.
          //
          // Đừng lẫn với "Lịch hẹn dẫn khách" ở dưới — cái đó là chiều ngược
          // lại: khách đặt trên tin CỦA MÌNH.
          _khoi([
            _muc(
              Icons.event_available_outlined,
              'Lịch tôi đã đặt xem',
              'Nhà bạn hẹn đi xem, và trạng thái duyệt',
              () => _mo(const BookingHistoryScreen()),
            ),
          ]),

          _khoi([
            _muc(
              Icons.bed_outlined,
              'Đặt phòng ngắn hạn của tôi',
              'Mã đặt phòng, trạng thái và huỷ phòng',
              () => _mo(const ShortStayBookingsScreen()),
            ),
          ]),
          _nhom('Hồ sơ & thương hiệu cá nhân'),
          _khoi([
            _muc(
              Icons.badge_outlined,
              'Thông tin cá nhân & giới thiệu',
              'Tên, ảnh đại diện, tiểu sử nghề nghiệp',
              () => _mo(const EditProfileScreen()),
            ),
            _muc(
              Icons.phone_in_talk_outlined,
              'Liên hệ công khai',
              _chuLienHe(),
              _moLienHe,
            ),
            _muc(
              Icons.verified_user_outlined,
              'Xác minh chủ nhà (CCCD)',
              _hoSo?['verified'] == true
                  ? 'Đã xác minh'
                  : 'Chưa xác minh — gửi CCCD để xác thực thông tin',
              // CCCD hai mặt (+ giấy phép KD nếu có) → admin duyệt.
              () => _mo(const EkycChuNhaScreen()),
              duoi: _hoSo?['verified'] == true ? _chipXanh('Đã duyệt') : null,
            ),
            _mucLink(),
          ]),

          _nhom('Tài sản được Sale tạo hộ'),
          _khoi([
            _muc(
              Icons.key_outlined,
              'Nhận tài sản từ Sale',
              'Nhập mã Sale gửi để nhận tòa nhà và phòng',
              () => _mo(const BuildingClaimScreen()),
            ),
          ]),

          _nhom('Tin đăng & kinh doanh'),
          _khoi([
            _muc(
              Icons.hotel_outlined,
              'Quản lý ở ngắn hạn',
              'Đơn hôm nay, nhận/trả phòng, giá và khoá phòng',
              () => _mo(const ShortStayBookingsScreen(operations: true)),
            ),
          ]),
          _khoi([
            _muc(
              Icons.article_outlined,
              'Tin đăng của tôi',
              'Sửa, ẩn, xoá, đăng tin mới',
              () => _mo(const MyListingsScreen()),
            ),
            _muc(
              Icons.apartment_rounded,
              'Dự án & phòng đang quản lý',
              'Gom phòng theo tòa; mỗi phòng có thể thuộc Chủ nhà và Sale khác nhau',
              () => _mo(const SaleProjectsScreen()),
            ),
            _muc(
              Icons.qr_code_2,
              'Mã liên kết chủ nhà',
              'Gửi cho chủ phòng để họ nhận quản lý điện nước, hoá đơn',
              () => _mo(const SaleCodeScreen()),
            ),
            _muc(
              Icons.calendar_month_outlined,
              'Lịch hẹn dẫn khách',
              'Khách đặt xem nhà — duyệt hoặc đổi giờ',
              () => _mo(const HostAppointmentsScreen()),
            ),
            _muc(
              Icons.chat_bubble_outline,
              'Tin nhắn với khách',
              'Hộp thoại đang mở',
              () => _mo(const ConversationsScreen()),
            ),
            _muc(
              Icons.handyman_outlined,
              l.myReqTitle,
              l.myReqSubtitle,
              () => _mo(const MyServiceRequestsScreen()),
            ),
            _muc(
              Icons.link,
              'Liên kết với sale',
              'Có mã do người đăng tin đưa? Nhập vào đây',
              () => _mo(const LinkSaleScreen()),
            ),
          ]),

          // Hiện công cụ vận hành theo chế độ đang chọn. API giới hạn dữ liệu
          // theo tài sản của tài khoản hoặc quyền được bàn giao.
          if (_laChuNha(context)) ...[
            // KHÔNG còn mục "Tổng quan quản lý" ở đây: từ 08/09/2026 tab Cá
            // nhân của chủ nhà CHÍNH LÀ màn tổng quan đó. Để lại thì chủ nhà mở
            // cài đặt rồi bấm vào, quay về đúng màn vừa rời — một vòng tròn.
            _nhom('Quản lý nhà cho thuê'),
            _khoi([
              _muc(
                Icons.receipt_long_outlined,
                l.profHostInvoices,
                l.profHostInvoicesSub,
                () => _mo(const InvoiceListScreen()),
              ),
              // Lịch bận/trống từng phòng. Trước nằm ở nút "Lịch phòng" của
              // trang chủ cũ; trang chủ mới (theo mockup) không còn nút đó và
              // nav của app không có tab Lịch phòng — không đặt ở đây là màn
              // mồ côi.
              _muc(
                Icons.event_available_outlined,
                'Lịch phòng trống',
                'Phòng nào bận đến bao giờ, trống từ ngày nào',
                () => _mo(const LichPhongScreen()),
              ),
              // Lối cũ tới công nợ là chip "phòng nợ" trên thẻ toà — mockup
              // trang chủ mới không còn thẻ đó.
              _muc(
                Icons.account_balance_wallet_outlined,
                'Công nợ',
                'Phòng nào còn nợ tiền, nợ bao lâu',
                () => _mo(const DebtAgingScreen()),
              ),
            ]),
          ],

          _nhom('Bảo mật & tài khoản'),
          _khoi([
            _muc(
              Icons.lock_reset,
              l.changePassword,
              'Đổi mật khẩu đăng nhập',
              () => _mo(const ChangePasswordScreen()),
            ),
            _muc(
              Icons.block,
              l.blockedUsersTitle,
              l.blockedUsersSub,
              () => _mo(const BlockedUsersScreen()),
            ),
            _muc(
              Icons.language,
              l.language,
              _tenNgonNgu(
                l,
                context.watch<LocaleProvider>().locale.languageCode,
              ),
              () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              ),
            ),
          ]),

          _nhom('Hỗ trợ & điều khoản'),
          _khoi([
            _muc(
              Icons.privacy_tip_outlined,
              l.privacyPolicy,
              'Cách dữ liệu của bạn và của khách được dùng',
              () => _moLink(LegalLinks.privacy),
              duoi: const Icon(Icons.open_in_new, size: 17, color: HD.inkMuted),
            ),
            _muc(
              Icons.description_outlined,
              l.termsOfUse,
              'Quy định khi đăng tin và dẫn khách',
              () => _moLink(LegalLinks.terms),
              duoi: const Icon(Icons.open_in_new, size: 17, color: HD.inkMuted),
            ),
          ]),

          const SizedBox(height: HD.s24),
          DsButton(
            label: l.logout,
            icon: Icons.logout,
            variant: DsButtonVariant.secondary,
            expand: true,
            onPressed: () => logoutFlow(context),
          ),
          const SizedBox(height: HD.s8),
          Center(
            child: TextButton.icon(
              style: TextButton.styleFrom(foregroundColor: HD.inkMuted),
              icon: const Icon(Icons.delete_forever, size: 17),
              label: Text(l.daTitle, style: HD.body(size: 13)),
              onPressed: () => xoaTaiKhoanFlow(context, l),
            ),
          ),
        ],
      ),
    );
  }

  // ── Thẻ đầu trang ──────────────────────────────────────────────────────────

  /// Chỉ số liệu ĐO ĐƯỢC. Bản thiết kế tham chiếu có "Số dư ví tin đăng
  /// 2.450.000đ" và "Điểm uy tín sàn 98/100" — hệ thống không có ví, cũng
  /// không có thang điểm nào như vậy. Thay bằng điểm đánh giá thật và số tin
  /// đang đăng thật.
  Widget _theDauTrang(dynamic u) {
    final diem = (_hoSo?['rating'] as num?)?.toDouble();
    final soNhanXet = (_hoSo?['review_count'] as num?)?.toInt() ?? 0;
    final soTin = (_hoSo?['listing_count'] as num?)?.toInt() ?? 0;
    final tinCay = _hoSo?['trusted'] == true;

    return Container(
      padding: const EdgeInsets.all(HD.s16),
      decoration: BoxDecoration(
        color: HD.paperRaised,
        borderRadius: BorderRadius.circular(HD.r12),
        border: Border.all(color: HD.hairline),
      ),
      child: Column(
        children: [
          Row(
            children: [
              _anh(u.name as String, u.avatarPath as String?),
              const SizedBox(width: HD.s12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            u.name as String,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: HD.bodyBold(size: 17),
                          ),
                        ),
                        if (tinCay) ...[
                          const SizedBox(width: 5),
                          _chipVang('UY TÍN'),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      // SĐT che bớt ngay trên màn của chính chủ: màn này hay
                      // được mở giữa chỗ đông người, và số đầy đủ đã có ở
                      // "Thông tin cá nhân".
                      '${_cheSo(u.phone as String)} · ${u.email}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: HD.body(size: 12.5, color: HD.inkSoft),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: HD.s12),
          // `IntrinsicHeight` + `stretch`: ô trái có thêm dòng "N nhận xét",
          // ô phải không — Row canh giữa thì hai ô so le nhau, mép trên và mép
          // dưới đều lệch. Ép cùng chiều cao theo ô cao nhất.
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: _oSo(
                    Icons.star_rounded,
                    'Điểm đánh giá',
                    diem == null || soNhanXet == 0
                        ? 'Chưa có'
                        : '${diem.toStringAsFixed(1)}/5',
                    phu: soNhanXet > 0 ? '$soNhanXet nhận xét' : null,
                    mau: HD.warning,
                    nen: HD.warningTint,
                  ),
                ),
                const SizedBox(width: HD.s8),
                Expanded(
                  child: _oSo(
                    Icons.article_outlined,
                    'Tin đang đăng',
                    '$soTin',
                    mau: HD.accent,
                    nen: HD.accentTint,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _anh(String ten, String? url) {
    final abs = (url == null || url.isEmpty)
        ? null
        : (url.startsWith('http') ? url : '${ApiConfig.baseUrl}$url');
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        color: HD.accentTint,
        borderRadius: BorderRadius.circular(HD.r12),
      ),
      clipBehavior: Clip.antiAlias,
      child: abs == null
          ? Center(
              child: Text(
                ten.trim().isEmpty ? '?' : ten.trim()[0].toUpperCase(),
                style: HD.masthead(size: 24, color: HD.accent),
              ),
            )
          : CachedNetworkImage(imageUrl: abs, fit: BoxFit.cover),
    );
  }

  /// Ô số liệu. Mỗi ô một SẮC RIÊNG (vàng cho điểm, đỏ cho tin) thay vì cùng
  /// một nền xám — hai con số khác loại mà trông y hệt nhau thì phải đọc nhãn
  /// mới phân biệt được.
  Widget _oSo(
    IconData icon,
    String nhan,
    String so, {
    String? phu,
    required Color mau,
    required Color nen,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: HD.s12, vertical: 10),
      decoration: BoxDecoration(
        color: nen,
        borderRadius: BorderRadius.circular(HD.r8),
        border: Border.all(color: mau.withValues(alpha: .18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 15, color: mau),
              const SizedBox(width: 5),
              Flexible(
                child: Text(
                  nhan,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  // `inkSoft` chứ không phải `inkMuted`: token nói rõ
                  // inkMuted trên nền chìm là tụt dưới chuẩn tương phản.
                  style: HD.bodyBold(size: 11.5, color: HD.inkSoft),
                ),
              ),
            ],
          ),
          const SizedBox(height: 3),
          Text(so, style: HD.masthead(size: 20, color: mau)),
          // Ô không có dòng phụ vẫn chừa đúng khoảng đó, để con số hai bên
          // nằm trên cùng một đường thay vì cái cao cái thấp.
          Text(phu ?? '', style: HD.body(size: 11.5, color: HD.inkSoft)),
        ],
      ),
    );
  }

  /// Link trang công khai + nút sao chép — thứ sale gửi cho khách nhiều nhất
  /// trong ngày, nên nó xứng đáng một hàng riêng thay vì nằm trong menu chia sẻ.
  Widget _mucLink() {
    final id = context.read<AuthProvider>().currentUser?.id ?? 0;
    final ten = (_hoSo?['name'] as String?) ?? '';
    final url = Env.brokerPublicUrl(id, ten);
    return Padding(
      padding: const EdgeInsets.fromLTRB(HD.s12, HD.s8, HD.s12, HD.s8),
      child: Row(
        children: [
          _oIcon(Icons.link),
          const SizedBox(width: HD.s12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Link Trang Sale', style: HD.bodyBold(size: 14.5)),
                Text(
                  url.replaceFirst(RegExp(r'^https?://'), ''),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: HD.body(size: 12, color: HD.accent),
                ),
              ],
            ),
          ),
          const SizedBox(width: HD.s8),
          DsButton(
            label: 'Sao chép',
            icon: Icons.content_copy,
            variant: DsButtonVariant.secondary,
            size: DsButtonSize.compact,
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: url));
              if (mounted) AppFeedback.success(context, 'Đã sao chép link');
            },
          ),
        ],
      ),
    );
  }

  // ── Mảnh dựng ──────────────────────────────────────────────────────────────

  /// Phím tắt tới landing page công khai của Sale. Đặt ngay sau thẻ danh tính
  /// vì đây là trang Sale gửi cho khách nhiều lần mỗi ngày, không phải một tuỳ
  /// chọn cài đặt dùng một lần.
  Widget _phimTatTrangSale(dynamic u) {
    final id = u.id as int? ?? 0;
    return Container(
      padding: const EdgeInsets.all(HD.s16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFFECEF), Color(0xFFFFF7F4)],
        ),
        borderRadius: BorderRadius.circular(HD.r12),
        border: Border.all(color: HD.accent.withValues(alpha: .18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: HD.accent,
                  borderRadius: BorderRadius.circular(HD.r12),
                ),
                child: const Icon(
                  Icons.storefront_rounded,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: HD.s12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Trang Sale của tôi', style: HD.bodyBold(size: 16)),
                    const SizedBox(height: 2),
                    Text(
                      'Landing page có hồ sơ, dự án, tin đăng, đánh giá và liên hệ nhanh',
                      style: HD.body(size: 12, color: HD.inkSoft),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: HD.s12),
          Row(
            children: [
              Expanded(
                child: DsButton(
                  label: 'Xem trang',
                  icon: Icons.open_in_new_rounded,
                  size: DsButtonSize.compact,
                  onPressed: id <= 0 ? null : () => context.push('/sale/$id'),
                ),
              ),
              const SizedBox(width: HD.s8),
              Expanded(
                child: DsButton(
                  label: 'Sửa liên hệ',
                  icon: Icons.contact_phone_outlined,
                  variant: DsButtonVariant.secondary,
                  size: DsButtonSize.compact,
                  onPressed: _moLienHe,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Chế độ hiển thị độc lập với vai trò hệ thống trong JWT.
  bool _laChuNha(BuildContext context) =>
      context.watch<AuthProvider>().loginAccountType == LoginAccountType.owner;

  Widget _nhom(String chu) => Padding(
    padding: const EdgeInsets.fromLTRB(HD.s8, HD.s20, HD.s8, HD.s8),
    child: Text(chu.toUpperCase(), style: HD.eyebrow(color: HD.accent)),
  );

  Widget _khoi(List<Widget> con) => Container(
    decoration: BoxDecoration(
      color: HD.paperRaised,
      borderRadius: BorderRadius.circular(HD.r12),
      border: Border.all(color: HD.hairline),
    ),
    clipBehavior: Clip.antiAlias,
    child: Column(
      children: [
        for (var i = 0; i < con.length; i++) ...[
          if (i > 0)
            const Padding(
              padding: EdgeInsets.only(left: 56),
              child: Divider(height: 1, color: HD.hairline),
            ),
          con[i],
        ],
      ],
    ),
  );

  /// Ô icon vuông. Nền ĐỎ NHẠT + icon đỏ thương hiệu, không phải xám trên xám.
  ///
  /// Bản trước dùng `paperSunken` với icon `inkSoft`: hai màu chỉ cách nhau
  /// một bậc xám nên cả cột icon chìm nghỉm, mắt không bắt được hàng nào với
  /// hàng nào khi lướt.
  Widget _oIcon(IconData icon) => Container(
    width: 36,
    height: 36,
    decoration: BoxDecoration(
      color: HD.accentTint,
      borderRadius: BorderRadius.circular(HD.r8),
    ),
    child: Icon(icon, size: 19, color: HD.accent),
  );

  Widget _muc(
    IconData icon,
    String chu,
    String? phu,
    VoidCallback cham, {
    Widget? duoi,
  }) {
    return InkWell(
      onTap: cham,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: HD.s12,
          vertical: HD.s12,
        ),
        child: Row(
          children: [
            _oIcon(icon),
            const SizedBox(width: HD.s12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(chu, style: HD.bodyBold(size: 14.5)),
                  if (phu != null && phu.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 1),
                      child: Text(
                        phu,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: HD.body(size: 12, color: HD.inkSoft),
                      ),
                    ),
                ],
              ),
            ),
            if (duoi != null) ...[duoi, const SizedBox(width: HD.s8)],
            const Icon(Icons.chevron_right, size: 20, color: HD.inkMuted),
          ],
        ),
      ),
    );
  }

  Widget _chipXanh(String chu) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
    decoration: BoxDecoration(
      color: HD.positiveTint,
      borderRadius: BorderRadius.circular(HD.rPill),
    ),
    child: Text(chu, style: HD.bodyBold(size: 11, color: HD.positive)),
  );

  Widget _chipVang(String chu) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
    decoration: BoxDecoration(
      color: HD.warningTint,
      borderRadius: BorderRadius.circular(HD.r4),
      border: Border.all(color: HD.warning.withValues(alpha: .4)),
    ),
    child: Text(
      chu,
      style: HD.eyebrow(color: HD.warning).copyWith(fontSize: 9.5),
    ),
  );

  // ── Hành động ──────────────────────────────────────────────────────────────

  String _chuLienHe() {
    final coSo = _hoSo?['phone'] != null;
    final coZalo = (_hoSo?['zalo'] as String?)?.isNotEmpty ?? false;
    final coFacebook = (_hoSo?['facebook'] as String?)?.isNotEmpty ?? false;
    final co = <String>[
      if (coSo) 'gọi trực tiếp',
      if (coZalo) 'Zalo',
      if (coFacebook) 'Facebook',
    ];
    return co.isEmpty
        ? 'Khách chỉ nhắn được trong app'
        : 'Khách ${co.join(' · ')}';
  }

  Future<void> _moLienHe() async {
    final doi = await showDsBottomSheet<bool>(
      context: context,
      builder: (_) => const KhayLienHeSheet(),
    );
    if (doi == true && mounted) _nap();
  }

  Future<void> _moLink(String url) async {
    await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  }

  /// `0908123456` → `0908 *** 456`.
  String _cheSo(String so) {
    final s = so.trim();
    if (s.length < 7) return s;
    return '${s.substring(0, 4)} *** ${s.substring(s.length - 3)}';
  }

  String _tenNgonNgu(AppLocalizations l, String ma) => switch (ma) {
    'en' => l.english,
    'zh' => l.chinese,
    _ => l.vietnamese,
  };
}
