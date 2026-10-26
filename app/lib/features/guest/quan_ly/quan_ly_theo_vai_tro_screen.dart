import 'package:flutter/material.dart';
import 'package:house_booking/data/services/so_chu_nha_api.dart';
import 'package:house_booking/features/host/so_chu_nha/trang_chu_chu_nha_screen.dart';
import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:provider/provider.dart';

import 'package:house_booking/core/widgets/ds.dart';
import 'package:house_booking/data/models/viewing_appointment_model.dart';
import 'package:house_booking/data/services/hoat_dong_khach_api.dart';
import 'package:house_booking/data/services/management_read_model_api.dart';
import 'package:house_booking/data/services/quan_ly_api.dart';
import 'package:house_booking/data/services/rental_journey_api.dart';
import 'package:house_booking/data/services/tong_quan_chu_nha_api.dart';
import 'package:house_booking/data/services/sale_yeu_cau_api.dart';
import 'package:house_booking/data/services/chu_nha_api.dart' as cn;
import 'package:house_booking/data/services/sale_van_hanh_api.dart';
import 'package:house_booking/features/auth/guest_gate.dart';
import 'package:house_booking/features/guest/booking/coc_xac_nhan_thue_screen.dart';
import 'package:house_booking/features/guest/booking/phieu_dat_phong_screen.dart';
import 'package:house_booking/features/guest/booking/phieu_hen_xem_screen.dart';
import 'package:house_booking/features/guest/customer/customer_screens.dart';
import 'package:house_booking/features/guest/short_stay/short_stay_bookings_screen.dart';
import 'package:house_booking/features/guest/short_stay/short_stay_operations_role.dart';
import 'package:house_booking/features/guest/short_stay/short_stay_search_screen.dart';
import 'package:house_booking/features/guest/quan_ly/khach_hoat_dong_view.dart';
import 'package:house_booking/features/guest/quan_ly/lich_xem_nha_screen.dart';
import 'package:house_booking/features/guest/quan_ly/management_work_items_screen.dart';
import 'package:house_booking/features/guest/quan_ly/phong_dang_thue_screen.dart';
import 'package:house_booking/features/guest/profile/settings_screen.dart'
    show logoutFlow;
import 'package:house_booking/features/host/appointments/host_appointments_screen.dart';
import 'package:house_booking/features/host/host_home_screen.dart';
import 'package:house_booking/features/host/journey/chi_tiet_yeu_cau_xem_screen.dart';
import 'package:house_booking/features/host/journey/xac_nhan_coc_chu_nha_screen.dart';
import 'package:house_booking/features/host/khach_thue/khach_thue_screen.dart';
import 'package:house_booking/features/host/ngan_han/ca_thue/chi_tiet_ca_thue_screen.dart';
import 'package:house_booking/features/host/chu_nha/tong_quan_chu_nha_v2_screen.dart';
import 'package:house_booking/features/sale/hoat_dong/sale_hoat_dong_screen.dart';
import 'package:house_booking/features/host/ngan_han/quan_ly_ngan_han_chu_nha_screen.dart';
import 'package:house_booking/features/host/billing/screens/invoice_detail_screen.dart';
import 'package:house_booking/features/host/property/screens/building_list_screen.dart';
import 'package:house_booking/features/host/property/providers/building_provider.dart';
import 'package:house_booking/features/host/property/screens/contract_detail_screen.dart';
import 'package:house_booking/features/host/reports/screens/reports_home_screen.dart';
import 'package:house_booking/features/notifications/notifications_screen.dart';
import 'package:house_booking/features/sale/chi_tiet_yeu_cau_khach_screen.dart';
import 'package:house_booking/features/sale/gui_ho_so_chot_thue_screen.dart';
import 'package:house_booking/features/sale/bang_dieu_hanh_sale.dart';
import 'package:house_booking/features/sale/lich_xem_hom_nay_screen.dart';
import 'package:house_booking/features/sale/sale_workspace_screen.dart';
import 'package:house_booking/features/sale/yeu_cau_list_screen.dart';
import 'package:house_booking/features/shared/long_term_stay_workspace_screen.dart';
import 'package:house_booking/providers/auth_provider.dart';
import 'package:house_booking/providers/notification_provider.dart';
import 'package:house_booking/providers/viewing_appointment_provider.dart';

/// Trang Quản lý chung cho ba vai trò, theo đúng ngôn ngữ của mockup:
///
///   App bar → banner theo vai trò (vai CỐ ĐỊNH theo vai đã chọn lúc đăng
///   nhập — không còn công tắc Khách/Sale/Chủ nhà) →
///   bốn số tổng quan → danh sách lối vào nghiệp vụ.
///
/// Đây chỉ là "sảnh" điều phối. Các luồng sâu đã có (quản lý tòa nhà, lịch
/// xem, khách thuê, báo cáo...) vẫn được giữ nguyên và mở từ từng dòng. Nhờ đó
/// đổi giao diện không làm mất nghiệp vụ chủ nhà đang vận hành.
class QuanLyTheoVaiTroScreen extends StatefulWidget {
  const QuanLyTheoVaiTroScreen({
    super.key,
    required this.cheDo,
    required this.coCheDoSale,
    required this.coCheDoChuNha,
    this.onTiepTucTimNha,
    this.quanLyApi = const QuanLyApi(),
    this.saleApi = const RentalJourneyApi(),
    this.saleYeuCauApi = const SaleYeuCauApi(),
    this.hoatDongKhachApi = const HoatDongKhachApi(),
    this.chuNhaApi = const TongQuanChuNhaApi(),
    this.managementReadModelApi = const ManagementReadModelApi(),
    this.saleVanHanhApi = const SaleVanHanhApi(),
    this.chuNhaV2Api = const cn.ChuNhaApi(),
    this.soChuNhaApi = const SoChuNhaApi(),
    this.buildingProvider,
  });

  /// ValueListenable được dùng thay cho một String thuần vì mỗi tab của shell
  /// có Navigator riêng. Route gốc chỉ được sinh một lần; notifier giúp đổi vai
  /// từ tab Cá nhân vẫn cập nhật trang Quản lý đã cache mà không dựng lại tab.
  final ValueListenable<String> cheDo;
  final bool coCheDoSale;
  final bool coCheDoChuNha;
  final VoidCallback? onTiepTucTimNha;
  final QuanLyApi quanLyApi;
  final RentalJourneyApi saleApi;
  final SaleYeuCauApi saleYeuCauApi;
  final HoatDongKhachApi hoatDongKhachApi;
  final TongQuanChuNhaApi chuNhaApi;
  final ManagementReadModelApi managementReadModelApi;

  /// Tab "Hoạt động" của sale (mockup 05/10/2026) — tiêm để test.
  final SaleVanHanhApi saleVanHanhApi;

  /// Tab "Hoạt động" của chủ nhà (Tổng quan chủ nhà) — tiêm để test.
  final cn.ChuNhaApi chuNhaV2Api;
  final SoChuNhaApi soChuNhaApi;
  final BuildingProvider? buildingProvider;

  @override
  State<QuanLyTheoVaiTroScreen> createState() => _QuanLyTheoVaiTroScreenState();
}

class _QuanLyTheoVaiTroScreenState extends State<QuanLyTheoVaiTroScreen> {
  late String _mode = _modeHopLe(widget.cheDo.value);
  int? _uid;

  TongHopQuanLy? _khach;
  List<ViewingAppointmentModel>? _hangSale;
  List<RentalJourney>? _hoSoSale;
  TongQuanChuNha? _chuNha;
  final Map<String, ManagementSummary> _managementV2Summaries = {};
  bool _daKiemTraManagementV2 = false;
  bool _managementV2DuocBat = false;
  bool _shortStayV2DuocBat = false;
  Set<String> _managementV2Modes = const {};
  final Map<String, String> _nhanhTheoVai = {
    'customer': 'long_term',
    'sale': 'long_term',
    'owner': 'long_term',
  };

  // Khách hàng KHÔNG chia dài/ngắn hạn (mockup 24/09/2026): mọi việc thuê ở
  // nằm chung một màn, booking ngắn hạn chỉ là một ô trong đó.
  bool get _laNganHan =>
      _mode != 'customer' && _nhanhTheoVai[_mode] == 'short_stay';

  final Set<String> _dangTai = {};
  final Set<String> _daTai = {};
  final Map<String, String> _loi = {};

  String _modeHopLe(String mode) {
    if (mode == 'owner' && _coCheDoChuNha) return mode;
    if (mode == 'sale' && _coCheDoSale) return mode;
    return 'customer';
  }

  bool get _coCheDoSale => _managementV2DuocBat
      ? _managementV2Modes.contains('sale')
      : widget.coCheDoSale;

  bool get _coCheDoChuNha => _managementV2DuocBat
      ? _managementV2Modes.contains('owner')
      : widget.coCheDoChuNha;

  @override
  void initState() {
    super.initState();
    widget.cheDo.addListener(_cheDoBenNgoaiDoi);
  }

  @override
  void didUpdateWidget(QuanLyTheoVaiTroScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.cheDo != widget.cheDo) {
      oldWidget.cheDo.removeListener(_cheDoBenNgoaiDoi);
      widget.cheDo.addListener(_cheDoBenNgoaiDoi);
      _cheDoBenNgoaiDoi();
    }
  }

  @override
  void dispose() {
    widget.cheDo.removeListener(_cheDoBenNgoaiDoi);
    super.dispose();
  }

  void _cheDoBenNgoaiDoi() {
    final mode = _modeHopLe(widget.cheDo.value);
    if (!mounted || mode == _mode) return;
    setState(() => _mode = mode);
    _nap(mode);
  }

  void _theoTaiKhoan(int? uid) {
    if (_uid == uid) return;
    _uid = uid;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _uid != uid) return;
      setState(() {
        _khach = null;
        _hangSale = null;
        _hoSoSale = null;
        _chuNha = null;
        _managementV2Summaries.clear();
        _daKiemTraManagementV2 = false;
        _managementV2DuocBat = false;
        _shortStayV2DuocBat = false;
        _managementV2Modes = const {};
        _dangTai.clear();
        _daTai.clear();
        _loi.clear();
      });
      if (uid != null) _nap(_mode);
    });
  }

  Future<void> _nap(String mode, {bool batBuoc = false}) async {
    if (_uid == null || _dangTai.contains(mode)) return;
    if (!batBuoc && _daTai.contains(mode)) return;
    final uidLucGoi = _uid;
    setState(() {
      _dangTai.add(mode);
      _loi.remove(mode);
    });
    try {
      if (mode == 'customer') {
        final data = await widget.quanLyApi.tongHop(GocQuanLy.cuaToi);
        if (!mounted || uidLucGoi != _uid) return;
        setState(() => _khach = data);
      } else if (mode == 'sale') {
        // Tab của sale nay là `SaleHoatDongScreen` (mockup 05/10/2026), màn
        // đó tự tải; hàng đợi cũ không còn hiện ở đâu nên không gọi nữa.
      } else {
        final data = await widget.chuNhaApi.lay();
        if (!mounted || uidLucGoi != _uid) return;
        setState(() => _chuNha = data);
      }
      await _napManagementV2(mode, uidLucGoi);
      if (mounted) setState(() => _daTai.add(mode));
    } catch (_) {
      if (mounted && uidLucGoi == _uid) {
        setState(() => _loi[mode] = 'Chưa tải được số liệu. Chạm để thử lại.');
      }
    } finally {
      if (mounted && uidLucGoi == _uid) {
        setState(() => _dangTai.remove(mode));
      }
    }
  }

  /// Management V2 chỉ là lớp đọc tăng cường. Mọi lỗi/404 từ backend chưa
  /// rollout đều bị cô lập ở đây để dữ liệu và điều hướng Quản lý cũ không bị
  /// ảnh hưởng. Khi cờ server tắt, app tuyệt đối không hiển thị panel mới.
  Future<void> _napManagementV2(String mode, int? uidLucGoi) async {
    try {
      if (!_daKiemTraManagementV2) {
        final caps = await widget.managementReadModelApi.capabilities();
        if (!mounted || uidLucGoi != _uid) return;
        setState(() {
          _daKiemTraManagementV2 = true;
          _managementV2DuocBat = caps.managementV2Enabled;
          _shortStayV2DuocBat = caps.shortStayInventoryV2Enabled;
          _managementV2Modes = caps.modes.toSet();
        });
        final validMode = _modeHopLe(_mode);
        if (validMode != _mode && mounted) {
          setState(() => _mode = validMode);
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && uidLucGoi == _uid) _nap(validMode);
          });
          return;
        }
      }
      if (!_managementV2DuocBat) return;
      final summary = await widget.managementReadModelApi.summary(
        mode: ManagementMode.fromValue(mode),
      );
      if (!mounted || uidLucGoi != _uid) return;
      setState(() => _managementV2Summaries[mode] = summary);
    } catch (_) {
      // Fallback im lặng: endpoint V2 là additive và có thể chưa tồn tại ở
      // một cụm backend đang rollout dần.
    }
  }

  void _bao(String text) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  void _mo(Widget man) =>
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => man));

  int _thongBaoChuaDoc() {
    try {
      return context.watch<NotificationProvider>().unread;
    } on ProviderNotFoundException {
      return 0;
    }
  }

  int _lichChuNhaCho() {
    try {
      return context
          .watch<ViewingAppointmentProvider>()
          .appointments
          .where((a) => a.status == 'pending')
          .length;
    } on ProviderNotFoundException {
      return 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().currentUser;
    final summaryV2 = _managementV2Summaries[_mode];
    _theoTaiKhoan(user?.id);
    if (user == null) {
      return const GuestTabPlaceholder(
        title: 'Quản lý',
        icon: Icons.assignment_outlined,
        message:
            'Đăng nhập để theo dõi hành trình tìm nhà, công việc Sale hoặc '
            'tài sản cho thuê của bạn.',
      );
    }

    // KHÁCH HÀNG: trang "Hoạt động" theo mockup 03/10/2026 (Ngắn hạn | Dài
    // hạn · Đang thuê · Lịch xem sắp tới · Lịch sử) — màn riêng, tự tải.
    if (_mode == 'customer') {
      return KhachHoatDongView(
        key: ValueKey('khach-hoat-dong-${user.id}'),
        api: widget.quanLyApi,
        onTimNha: widget.onTiepTucTimNha,
      );
    }

    // SALE: tab "Hoạt động" theo mockup 05/10/2026 (Ngắn hạn | Dài hạn · lối
    // tắt · Tổng quan · Cần xử lý hôm nay) — bộ màn riêng, tự tải.
    if (_mode == 'sale') {
      return SaleHoatDongScreen(
        key: ValueKey('sale-hoat-dong-${user.id}'),
        api: widget.saleVanHanhApi,
      );
    }

    // CHỦ NHÀ: tab Hoạt động = SỔ CHỦ NHÀ (mockup 06/10/2026) — Trang chủ
    // chủ nhà, từ đó vào Tòa nhà · Thu chi · từng phòng. Chủ nhà dùng chung
    // bộ tab với khách/sale, chỉ tab này khác.
    if (_mode == 'owner') {
      return TrangChuChuNhaScreen(
        key: ValueKey('chu-nha-hoat-dong-${user.id}'),
        api: widget.soChuNhaApi,
      );
    }

    // Chủ nhà đi vào sổ Tòa nhà trước. Dài hạn, ngắn hạn và linh hoạt là ba
    // không gian vận hành bên trong từng tòa, không phải dashboard toàn cục.
    // App bar, bộ chọn vai trò và bottom navigation của shell vẫn được giữ.
    if (_mode == 'owner') {
      return Scaffold(
        backgroundColor: const Color(0xfff7f9fc),
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              _appBar(),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 2, 16, 12),
                child: _TheVaiDangNhap(mode: _mode),
              ),
              Expanded(child: _ownerBuildingList()),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xfff5f6fa),
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          color: HD.accent,
          onRefresh: () => _nap(_mode, batBuoc: true),
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(child: _appBar()),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 2, 16, 28),
                sliver: SliverList.list(
                  children: [
                    // Vai trò cố định theo vai đã chọn lúc đăng nhập: không còn
                    // công tắc Khách/Sale/Chủ nhà. Thẻ này nói rõ đang ở vai
                    // nào và chỉ cách đổi (đăng xuất → chọn vai khác).
                    _TheVaiDangNhap(mode: _mode),
                    if (_shortStayV2DuocBat && _mode != 'customer') ...[
                      const SizedBox(height: 10),
                      _chonLoaiVanHanh(),
                    ],
                    if (_mode != 'customer') ...[
                      const SizedBox(height: 14),
                      _banner(),
                      const SizedBox(height: 14),
                    ] else
                      const SizedBox(height: 10),
                    // Sale dài hạn dùng BẢNG ĐIỀU HÀNH THEO YÊU CẦU (mockup
                    // 23/09/2026): phễu yêu cầu + tiền tháng này + lối vào
                    // từng cụm. Bốn thẻ cũ đếm theo lịch xem, không trả lời
                    // được "khách này đang ở bước nào".
                    if (_mode == 'sale' && !_laNganHan)
                      BangDieuHanhSale(
                        api: widget.saleYeuCauApi,
                        lichApi: widget.saleApi,
                        hienHero: false,
                      )
                    else ...[
                      _tieuDeMuc('Tổng quan'),
                      const SizedBox(height: 9),
                      _tongQuan(),
                    ],
                    if (_managementV2DuocBat &&
                        summaryV2 != null &&
                        _mode == 'owner' &&
                        !_laNganHan) ...[
                      const SizedBox(height: 14),
                      _tomTatHanhTrinhMoi(summaryV2),
                    ],
                    if (_managementV2DuocBat &&
                        summaryV2 != null &&
                        _laNganHan) ...[
                      const SizedBox(height: 12),
                      _tomTatNganHan(summaryV2),
                    ],
                    if (_mode != 'customer' &&
                        !(_mode == 'sale' && !_laNganHan)) ...[
                      const SizedBox(height: 17),
                      _tieuDeMuc(
                        _laNganHan
                            ? 'Quản lý ngắn hạn'
                            : (_mode == 'owner'
                                  ? 'Quản lý dài hạn'
                                  : 'Dài hạn của tôi'),
                      ),
                      const SizedBox(height: 9),
                      _danhSach(),
                    ],
                    if (_loi[_mode] case final loi?) ...[
                      const SizedBox(height: 12),
                      InkWell(
                        key: const Key('quan-ly-vai-tro-thu-lai'),
                        onTap: () => _nap(_mode, batBuoc: true),
                        borderRadius: BorderRadius.circular(12),
                        child: Padding(
                          padding: const EdgeInsets.all(8),
                          child: Text(
                            loi,
                            textAlign: TextAlign.center,
                            style: HD.body(size: 12.5, color: HD.negative),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _ownerBuildingList() {
    if (widget.buildingProvider case final provider?) {
      return ChangeNotifierProvider<BuildingProvider>.value(
        value: provider,
        child: BuildingListScreen(overviewApi: widget.chuNhaApi),
      );
    }
    try {
      context.read<BuildingProvider>();
      return BuildingListScreen(overviewApi: widget.chuNhaApi);
    } on ProviderNotFoundException {
      // Giữ màn dùng độc lập được trong widget test và route nhúng; app thật
      // đã cấp provider ở root nên không tạo thêm instance.
      return ChangeNotifierProvider(
        create: (_) => BuildingProvider(),
        child: BuildingListScreen(overviewApi: widget.chuNhaApi),
      );
    }
  }

  Widget _appBar() => SizedBox(
    height: 58,
    child: Row(
      children: [
        const SizedBox(width: 18),
        Expanded(
          child: Text('Quản lý', style: HD.bodyBold(size: 24, color: HD.ink)),
        ),
        IconButton(
          key: const Key('quan-ly-vai-tro-thong-bao'),
          tooltip: 'Thông báo',
          onPressed: () => _mo(const NotificationsScreen()),
          icon: Badge(
            isLabelVisible: _thongBaoChuaDoc() > 0,
            label: Text(
              _thongBaoChuaDoc() > 99 ? '99+' : '${_thongBaoChuaDoc()}',
            ),
            child: const Icon(Icons.notifications_none_rounded, size: 27),
          ),
        ),
        const SizedBox(width: 8),
      ],
    ),
  );

  Widget _chonLoaiVanHanh() => Semantics(
    label: 'Chọn loại quản lý dài hạn hoặc ngắn hạn',
    child: Container(
      key: const Key('chon-loai-van-hanh'),
      height: 46,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xfff0f2f6),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Expanded(
            child: _LoaiVanHanhTab(
              key: const Key('loai-van-hanh-dai-han'),
              icon: Icons.home_work_outlined,
              label: 'Dài hạn',
              selected: !_laNganHan,
              onTap: () => _doiLoaiVanHanh('long_term'),
            ),
          ),
          Expanded(
            child: _LoaiVanHanhTab(
              key: const Key('loai-van-hanh-ngan-han'),
              icon: Icons.bedtime_outlined,
              label: 'Ngắn hạn',
              selected: _laNganHan,
              onTap: () => _doiLoaiVanHanh('short_stay'),
            ),
          ),
        ],
      ),
    ),
  );

  void _doiLoaiVanHanh(String value) {
    if (_nhanhTheoVai[_mode] == value) return;
    setState(() => _nhanhTheoVai[_mode] = value);
  }

  Widget _banner() {
    if (_laNganHan) {
      final (title, subtitle, color) = switch (_mode) {
        'sale' => (
          'Điều phối lưu trú ngắn hạn',
          'Theo dõi đơn · hỗ trợ nhận trả phòng',
          const Color(0xffffeeee),
        ),
        'owner' => (
          'Vận hành phòng ngắn hạn',
          'Lịch phòng rõ ràng · tối ưu công suất',
          const Color(0xffe8f7f0),
        ),
        _ => (
          'Chuyến ở ngắn hạn của bạn',
          'Đặt phòng · nhận phòng · theo dõi lịch sử',
          const Color(0xfffff2e7),
        ),
      };
      final accent = _mode == 'owner' ? const Color(0xff087f4f) : HD.accent;
      return Container(
        key: Key('banner-quan-ly-$_mode-short-stay'),
        height: 108,
        padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(13),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: HD.bodyBold(size: 16, color: accent)),
                  const SizedBox(height: 5),
                  Text(
                    subtitle,
                    maxLines: 2,
                    style: HD.body(size: 12, color: HD.inkMuted),
                  ),
                ],
              ),
            ),
            Container(
              width: 62,
              height: 62,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: .72),
                borderRadius: BorderRadius.circular(19),
              ),
              child: Icon(
                Icons.calendar_view_week_rounded,
                size: 34,
                color: accent,
              ),
            ),
          ],
        ),
      );
    }
    final (asset, title, subtitle, color) = switch (_mode) {
      'sale' => (
        'assets/branding/manage_sale.webp',
        'Công việc Sale hôm nay',
        'Kết nối đúng người\nChốt thuê thành công',
        const Color(0xffffeeee),
      ),
      'owner' => (
        'assets/branding/manage_owner.webp',
        'Quản lý bất động sản của bạn',
        'Cho thuê hiệu quả\nTối ưu doanh thu',
        const Color(0xffe8f7f0),
      ),
      _ => (
        'assets/branding/manage_customer.webp',
        'Mọi thông tin thuê nhà trong một nơi',
        'Theo dõi lịch xem, quản lý hợp đồng, hóa đơn và các hoạt động '
            'của bạn dễ dàng hơn.',
        const Color(0xffffeeee),
      ),
    };
    final laKhach = _mode == 'customer';
    final accent = _mode == 'owner' ? const Color(0xff087f4f) : HD.accent;
    return Container(
      key: Key('banner-quan-ly-$_mode'),
      height: laKhach ? 138 : 118,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(13),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            asset,
            fit: BoxFit.cover,
            alignment: Alignment.centerRight,
            errorBuilder: (_, _, _) => const SizedBox.shrink(),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(14, 10, laKhach ? 178 : 152, 9),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: HD.bodyBold(size: 17, color: accent),
                ),
                const SizedBox(height: 5),
                Text(
                  subtitle,
                  maxLines: laKhach ? 3 : 2,
                  overflow: TextOverflow.ellipsis,
                  style: HD.body(size: 12, color: HD.inkSoft),
                ),
                if (!laKhach) ...[
                  const SizedBox(height: 8),
                  Container(
                    width: 26,
                    height: 3,
                    decoration: BoxDecoration(
                      color: accent,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _tieuDeMuc(String text) =>
      Text(text, style: HD.bodyBold(size: 18, color: HD.ink));

  Widget _tongQuan() {
    final cards = _laNganHan
        ? _theNganHan()
        : switch (_mode) {
            'sale' => _theSale(),
            'owner' => _theChuNha(),
            _ => _theKhach(),
          };
    return Column(
      children: [
        Row(
          children: [
            Expanded(child: cards[0]),
            const SizedBox(width: 10),
            Expanded(child: cards[1]),
          ],
        ),
        const SizedBox(height: 9),
        Row(
          children: [
            Expanded(child: cards[2]),
            const SizedBox(width: 10),
            Expanded(child: cards[3]),
          ],
        ),
      ],
    );
  }

  List<Widget> _theNganHan() {
    final summary = _managementV2Summaries[_mode];
    final counters = summary?.shortStay ?? const ShortStayCounters();
    final loading = _dangTai.contains(_mode);
    return [
      _TheTongQuan(
        icon: Icons.receipt_long_rounded,
        color: HD.accent,
        value: '${counters.total}',
        label: _mode == 'customer' ? 'Đặt phòng' : 'Tổng đơn',
        loading: loading,
        onTap: _moNganHanTheoVaiTro,
      ),
      _TheTongQuan(
        icon: Icons.hourglass_top_rounded,
        color: const Color(0xffff9800),
        value: '${counters.pending}',
        label: _mode == 'customer' ? 'Chờ xác nhận' : 'Chờ xử lý',
        loading: loading,
        onTap: _moNganHanTheoVaiTro,
      ),
      _TheTongQuan(
        icon: Icons.event_available_rounded,
        color: const Color(0xff246be8),
        value: '${counters.confirmed}',
        label: 'Đã xác nhận',
        loading: loading,
        onTap: _moNganHanTheoVaiTro,
      ),
      _TheTongQuan(
        icon: Icons.bed_rounded,
        color: const Color(0xff149768),
        value: '${counters.checkedIn}',
        label: _mode == 'customer' ? 'Đang lưu trú' : 'Đang ở',
        loading: loading,
        onTap: _moNganHanTheoVaiTro,
      ),
    ];
  }

  /// Panel chỉ hiện sau cờ `management_v2_enabled`; nó bổ sung một lát cắt
  /// trạng thái chuẩn hoá, không thay các thẻ/tuyến điều hướng legacy bên trên.
  Widget _tomTatHanhTrinhMoi(ManagementSummary summary) {
    const items = [
      (ManagementBucket.actionRequired, 'Cần xử lý', HD.accent),
      (ManagementBucket.waitingExternal, 'Chờ phản hồi', Color(0xffff9800)),
      (ManagementBucket.upcoming, 'Sắp tới', Color(0xff15976a)),
      (ManagementBucket.afterViewing, 'Sau khi xem', Color(0xffc65b00)),
      (ManagementBucket.history, 'Lịch sử', Color(0xff246be8)),
    ];
    return Container(
      key: const Key('management-v2-summary'),
      padding: const EdgeInsets.fromLTRB(14, 8, 8, 14),
      decoration: BoxDecoration(
        color: HD.paperRaised,
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0D000000),
            blurRadius: 12,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Tình trạng hành trình',
                style: HD.bodyBold(size: 15.5, color: HD.ink),
              ),
              const Spacer(),
              TextButton(
                key: const Key('management-v2-open-work-items'),
                onPressed: _moCongViecManagementV2,
                style: TextButton.styleFrom(
                  foregroundColor: HD.accent,
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  minimumSize: const Size(0, 32),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${summary.viewings} lịch xem',
                      style: HD.body(size: 12.5, color: HD.accent),
                    ),
                    const Icon(Icons.chevron_right, size: 18, color: HD.accent),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final item in items)
                _TrangThaiV2Chip(
                  label: item.$2,
                  value: summary.longTerm.count(item.$1),
                  color: item.$3,
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _tomTatNganHan(ManagementSummary summary) {
    final counters = summary.shortStay;
    return Container(
      key: const Key('short-stay-summary'),
      padding: const EdgeInsets.fromLTRB(13, 12, 13, 12),
      decoration: BoxDecoration(
        color: const Color(0xfffff7f1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xffffdfc7)),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: const Color(0xffffe7d5),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.bedtime_rounded, color: Color(0xffc65300)),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Hoạt động ngắn hạn',
                  style: HD.bodyBold(size: 14, color: HD.ink),
                ),
                const SizedBox(height: 3),
                Text(
                  '${counters.pending} chờ xử lý · ${counters.confirmed} đã xác nhận · ${counters.checkedIn} đang ở',
                  style: HD.body(size: 11.5, color: HD.inkMuted),
                ),
              ],
            ),
          ),
          IconButton(
            key: const Key('open-short-stay-workspace'),
            tooltip: 'Mở quản lý ngắn hạn',
            onPressed: _moNganHanTheoVaiTro,
            icon: const Icon(Icons.arrow_forward_rounded, color: HD.accent),
          ),
        ],
      ),
    );
  }

  List<Widget> _theKhach() {
    final d = _khach;
    final muonThue = d?.danhSach.where((m) => m.laDeNghiThue).length ?? 0;
    return [
      _TheTongQuan(
        icon: Icons.calendar_month_rounded,
        color: HD.accent,
        value: '${d?.dem.daDat ?? 0}',
        label: 'Lịch xem',
        loading: _dangTai.contains('customer'),
        onTap: () => _mo(LichXemNhaScreen(api: widget.quanLyApi)),
      ),
      _TheTongQuan(
        icon: Icons.hourglass_bottom_rounded,
        color: const Color(0xffffa000),
        value: '${d?.dem.canXuLy ?? 0}',
        label: 'Đang cần nhắc',
        loading: _dangTai.contains('customer'),
        onTap: _moQuanLyKhach,
      ),
      _TheTongQuan(
        icon: Icons.favorite_rounded,
        color: const Color(0xffed1c32),
        value: '$muonThue',
        label: 'Muốn thuê',
        loading: _dangTai.contains('customer'),
        onTap: _moQuanLyKhach,
      ),
      _TheTongQuan(
        icon: Icons.home_rounded,
        color: const Color(0xff149768),
        value: '${d?.dem.dangO ?? 0}',
        label: 'Đang ở',
        loading: _dangTai.contains('customer'),
        onTap: _moDangOKhach,
      ),
    ];
  }

  List<Widget> _theSale() {
    final hang = _hangSale ?? const <ViewingAppointmentModel>[];
    final homNay = _iso(DateTime.now());
    final moi = hang.where((a) => a.status == 'pending').length;
    final cho = hang
        .where((a) => a.status == 'pending' || a.status == 'doi_gio')
        .length;
    final lich = hang.where((a) => a.bookingDate == homNay).length;
    final giaoDich = _hoSoSale?.length ?? 0;
    final loading = _dangTai.contains('sale');
    return [
      _TheTongQuan(
        icon: Icons.people_alt_rounded,
        color: HD.accent,
        value: '$moi',
        label: 'Khách mới',
        loading: loading,
        onTap: _moViecSale,
      ),
      _TheTongQuan(
        icon: Icons.schedule_rounded,
        color: const Color(0xffffa000),
        value: '$cho',
        label: 'Lịch chờ xử lý',
        loading: loading,
        onTap: _moViecSale,
      ),
      _TheTongQuan(
        icon: Icons.calendar_today_rounded,
        color: const Color(0xff246be8),
        value: '$lich',
        label: 'Lịch hôm nay',
        loading: loading,
        onTap: () => _mo(LichXemHomNayScreen(api: widget.saleApi)),
      ),
      _TheTongQuan(
        icon: Icons.description_rounded,
        color: const Color(0xff2563d9),
        value: '$giaoDich',
        label: 'Giao dịch chờ',
        loading: loading,
        onTap: _moViecSale,
      ),
    ];
  }

  List<Widget> _theChuNha() {
    final d = _chuNha;
    final loading = _dangTai.contains('owner');
    return [
      _TheTongQuan(
        icon: Icons.apartment_rounded,
        color: const Color(0xff246be8),
        value: '${d?.soToa ?? 0}',
        label: 'Tòa nhà',
        loading: loading,
        onTap: _moQuanLyToaNha,
      ),
      _TheTongQuan(
        icon: Icons.meeting_room_rounded,
        color: const Color(0xffff9800),
        value: '${d?.phongTrong ?? 0}',
        label: 'Phòng đang cho thuê',
        loading: loading,
        onTap: _moDanhSachToa,
      ),
      _TheTongQuan(
        icon: Icons.calendar_month_rounded,
        color: HD.accent,
        value: '${_lichChuNhaCho()}',
        label: 'Lịch xem sắp tới',
        loading: loading,
        onTap: () => _mo(
          HostAppointmentsScreen(managementApi: widget.managementReadModelApi),
        ),
      ),
      _TheTongQuan(
        icon: Icons.bar_chart_rounded,
        color: const Color(0xff098454),
        value: _tienGon(d?.doanhThuThang ?? 0),
        label: 'Doanh thu tháng này',
        loading: loading,
        onTap: () => _mo(const ReportsHomeScreen()),
      ),
    ];
  }

  Widget _danhSach() {
    if (_laNganHan) return _danhSachNganHan();
    final rows = switch (_mode) {
      'sale' => <_MucQuanLyVaiTro>[
        _MucQuanLyVaiTro(
          Icons.meeting_room_rounded,
          'Phòng đang ở',
          'Phòng được phân công, chỉ số và hỗ trợ khách thuê',
          const Color(0xff246be8),
          null,
          _moPhongSale,
        ),
        _MucQuanLyVaiTro(
          Icons.person_rounded,
          'Khách quan tâm',
          'Quản lý khách hàng/lead',
          HD.accent,
          _hangSale?.where((a) => a.status == 'pending').length,
          _moViecSale,
        ),
        _MucQuanLyVaiTro(
          Icons.calendar_month_rounded,
          'Điều phối lịch xem',
          'Xem và xử lý lịch hẹn',
          HD.accent,
          _hangSale
              ?.where((a) => a.status == 'pending' || a.status == 'doi_gio')
              .length,
          _moViecSale,
        ),
        _MucQuanLyVaiTro(
          Icons.event_available_rounded,
          'Lịch đã xác nhận',
          'Các lịch xem đã chốt',
          const Color(0xff149768),
          _hangSale?.where((a) => a.status == 'approved').length,
          () => _mo(LichXemHomNayScreen(api: widget.saleApi)),
        ),
        _MucQuanLyVaiTro(
          Icons.favorite_rounded,
          'Khách muốn thuê',
          'Khách đã xem và có nhu cầu',
          const Color(0xffffa000),
          _hoSoSale?.length,
          _moViecSale,
        ),
        _MucQuanLyVaiTro(
          Icons.assignment_turned_in_rounded,
          'Chốt thuê & báo cáo',
          'Hoàn thiện hồ sơ giao dịch',
          const Color(0xff246be8),
          null,
          _moViecSale,
        ),
        _MucQuanLyVaiTro(
          Icons.warning_rounded,
          'Báo cáo sự cố',
          'Tạo báo cáo khi có vấn đề',
          HD.accent,
          null,
          _moWorkspaceSale,
        ),
      ],
      'owner' => <_MucQuanLyVaiTro>[
        _MucQuanLyVaiTro(
          Icons.apartment_rounded,
          'Tòa nhà của tôi',
          'Quản lý thông tin tòa nhà',
          const Color(0xff15976a),
          null,
          _moQuanLyToaNha,
        ),
        _MucQuanLyVaiTro(
          Icons.meeting_room_rounded,
          'Phòng cho thuê',
          'Danh sách phòng và tình trạng',
          const Color(0xff15976a),
          null,
          _moDanhSachToa,
        ),
        _MucQuanLyVaiTro(
          Icons.home_work_rounded,
          'Phòng đang ở',
          'Khách thuê, hợp đồng, điện nước và hóa đơn',
          const Color(0xff15976a),
          null,
          _moPhongDangOChuNha,
        ),
        _MucQuanLyVaiTro(
          Icons.calendar_month_rounded,
          'Lịch xem nhà',
          'Các lịch hẹn khách xem',
          const Color(0xff246be8),
          _lichChuNhaCho(),
          () => _mo(
            HostAppointmentsScreen(
              managementApi: widget.managementReadModelApi,
            ),
          ),
        ),
        _MucQuanLyVaiTro(
          Icons.description_rounded,
          'Hợp đồng',
          'Quản lý hợp đồng thuê',
          const Color(0xff15976a),
          null,
          () => _mo(const KhachThueScreen()),
        ),
        _MucQuanLyVaiTro(
          Icons.receipt_long_rounded,
          'Điện nước & hóa đơn',
          'Chốt chỉ số, khoản thu và lịch sử thanh toán',
          const Color(0xff246be8),
          null,
          _moQuanLyToaNha,
        ),
        _MucQuanLyVaiTro(
          Icons.bar_chart_rounded,
          'Doanh thu',
          'Thống kê doanh thu và chi phí',
          HD.accent,
          null,
          () => _mo(const ReportsHomeScreen()),
        ),
        _MucQuanLyVaiTro(
          Icons.support_agent_rounded,
          'Báo cáo & hỗ trợ',
          'Xem báo cáo, liên hệ hỗ trợ',
          const Color(0xff246be8),
          null,
          () => _mo(const ReportsHomeScreen()),
        ),
      ],
      _ => <_MucQuanLyVaiTro>[
        _MucQuanLyVaiTro(
          Icons.calendar_month_rounded,
          'Lịch xem nhà',
          'Xem và quản lý các lịch hẹn',
          const Color(0xff246be8),
          _khach?.dem.daDat,
          () => _mo(LichXemNhaScreen(api: widget.quanLyApi)),
        ),
        _MucQuanLyVaiTro(
          Icons.hourglass_bottom_rounded,
          'Nhà đang cân nhắc',
          'Các căn nhà bạn đang xem xét',
          const Color(0xffffa000),
          _khach?.dem.canXuLy,
          _moQuanLyKhach,
        ),
        _MucQuanLyVaiTro(
          Icons.favorite_rounded,
          'Nhà muốn thuê',
          'Các căn nhà bạn quan tâm thuê',
          HD.accent,
          null,
          _moQuanLyKhach,
        ),
        _MucQuanLyVaiTro(
          Icons.home_rounded,
          'Đang ở',
          'Hợp đồng và thông tin đang thuê',
          const Color(0xff15976a),
          _khach?.dem.dangO,
          _moDangOKhach,
        ),
        _MucQuanLyVaiTro(
          Icons.history_rounded,
          'Lịch sử',
          'Lịch sử xem nhà và giao dịch',
          const Color(0xff246be8),
          null,
          _moQuanLyKhach,
        ),
      ],
    };

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xffedf0f4)),
      ),
      child: Column(
        children: [
          for (var i = 0; i < rows.length; i++) ...[
            if (i > 0)
              const Divider(height: 1, indent: 58, color: Color(0xffedf0f4)),
            _DongQuanLy(data: rows[i]),
          ],
        ],
      ),
    );
  }

  Widget _danhSachNganHan() {
    final counters =
        _managementV2Summaries[_mode]?.shortStay ?? const ShortStayCounters();
    final rows = switch (_mode) {
      'sale' => <_MucQuanLyVaiTro>[
        _MucQuanLyVaiTro(
          Icons.receipt_long_rounded,
          'Điều phối đặt phòng',
          'Đơn được phân công và việc cần xử lý',
          HD.accent,
          counters.pending,
          _moNganHanTheoVaiTro,
        ),
        _MucQuanLyVaiTro(
          Icons.event_available_rounded,
          'Lịch nhận & trả phòng',
          'Các lượt đã xác nhận sắp diễn ra',
          const Color(0xff246be8),
          counters.confirmed,
          _moNganHanTheoVaiTro,
        ),
        _MucQuanLyVaiTro(
          Icons.bed_rounded,
          'Khách đang ở',
          'Theo dõi và hỗ trợ trong thời gian lưu trú',
          const Color(0xff149768),
          counters.checkedIn,
          _moNganHanTheoVaiTro,
        ),
        _MucQuanLyVaiTro(
          Icons.history_rounded,
          'Lịch sử vận hành',
          'Đã trả phòng, đã hủy hoặc không đến',
          const Color(0xff6b7280),
          counters.history,
          _moNganHanTheoVaiTro,
        ),
      ],
      'owner' => <_MucQuanLyVaiTro>[
        _MucQuanLyVaiTro(
          Icons.calendar_view_week_rounded,
          'Lịch phòng ngắn hạn',
          'Lịch ngày, tuần và sơ đồ phòng theo giờ',
          HD.accent,
          null,
          _moNganHanTheoVaiTro,
        ),
        _MucQuanLyVaiTro(
          Icons.receipt_long_rounded,
          'Đơn đặt phòng',
          'Duyệt, từ chối và theo dõi đặt phòng',
          const Color(0xffff9800),
          counters.pending,
          () => _mo(
            const ShortStayBookingsScreen(
              operations: true,
              operationsRole: ShortStayOperationsRole.owner,
            ),
          ),
        ),
        _MucQuanLyVaiTro(
          Icons.login_rounded,
          'Nhận & trả phòng',
          'Các lượt sắp đến và khách đang lưu trú',
          const Color(0xff149768),
          counters.confirmed + counters.checkedIn,
          () => _mo(
            const ShortStayBookingsScreen(
              operations: true,
              operationsRole: ShortStayOperationsRole.owner,
            ),
          ),
        ),
        _MucQuanLyVaiTro(
          Icons.tune_rounded,
          'Giá & khóa phòng',
          'Quản lý giá bán và ngày ngừng nhận khách',
          const Color(0xff246be8),
          null,
          _moNganHanTheoVaiTro,
        ),
      ],
      _ => <_MucQuanLyVaiTro>[
        _MucQuanLyVaiTro(
          Icons.receipt_long_rounded,
          'Đặt phòng của tôi',
          'Theo dõi toàn bộ chuyến ở ngắn hạn',
          HD.accent,
          counters.total,
          _moNganHanTheoVaiTro,
        ),
        _MucQuanLyVaiTro(
          Icons.search_rounded,
          'Tìm phòng ngắn hạn',
          'Theo giờ, qua đêm hoặc theo ngày',
          const Color(0xff246be8),
          null,
          () => _mo(const ShortStaySearchScreen()),
        ),
        _MucQuanLyVaiTro(
          Icons.event_available_rounded,
          'Đã xác nhận',
          'Các chuyến sắp nhận phòng',
          const Color(0xff149768),
          counters.confirmed,
          _moNganHanTheoVaiTro,
        ),
        _MucQuanLyVaiTro(
          Icons.history_rounded,
          'Lịch sử lưu trú',
          'Đã hoàn tất hoặc đã hủy',
          const Color(0xff6b7280),
          counters.history,
          _moNganHanTheoVaiTro,
        ),
      ],
    };
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xffedf0f4)),
      ),
      child: Column(
        children: [
          for (var i = 0; i < rows.length; i++) ...[
            if (i > 0)
              const Divider(height: 1, indent: 58, color: Color(0xffedf0f4)),
            _DongQuanLy(data: rows[i]),
          ],
        ],
      ),
    );
  }

  void _moQuanLyKhach() => _mo(
    _TrangCoTieuDe(
      title: 'Quản lý của tôi',
      child: CustomerManagementScreen(
        api: widget.quanLyApi,
        managementApi: widget.managementReadModelApi,
      ),
    ),
  );

  void _moCongViecManagementV2() => _mo(
    ManagementWorkItemsScreen(
      mode: ManagementMode.fromValue(_mode),
      api: widget.managementReadModelApi,
      onOpenItem: _moChiTietManagementV2,
    ),
  );

  /// `detail_route` do server phát hành. Chỉ mở route đúng schema/kind; không
  /// có fallback suy đoán id hoặc action từ client để tránh lộ/chạy nhầm luồng.
  Future<void> _moChiTietManagementV2(ManagementWorkItem item) async {
    final segments = Uri.tryParse(item.detailRoute)?.pathSegments ?? const [];
    if (segments.length != 2) {
      _bao('Liên kết chi tiết không còn hợp lệ. Vui lòng tải lại danh sách.');
      return;
    }
    final id = int.tryParse(segments[1]);
    if (id == null || id <= 0) {
      _bao('Liên kết chi tiết không hợp lệ.');
      return;
    }
    if (item.kind == 'VIEWING' && segments[0] == 'viewing-appointments') {
      switch (_mode) {
        case 'sale':
          _mo(ChiTietYeuCauKhachScreen(appointmentId: id));
        case 'owner':
          _mo(ChiTietYeuCauXemScreen(appointmentId: id));
        default:
          _mo(PhieuHenXemScreen(appointmentId: id));
      }
      return;
    }
    if (item.kind == 'RENTAL_JOURNEY' && segments[0] == 'rental-journeys') {
      switch (_mode) {
        case 'sale':
          _mo(GuiHoSoChotThueScreen(journeyId: id));
        case 'owner':
          _mo(XacNhanCocChuNhaScreen(journeyId: id));
        default:
          _mo(CocXacNhanThueScreen(journeyId: id));
      }
      return;
    }
    if (item.kind == 'RESERVATION' && segments[0] == 'reservations') {
      switch (_mode) {
        case 'sale':
        case 'owner':
          _mo(ChiTietCaThueScreen(reservationId: id));
        default:
          _mo(PhieuDatPhongScreen(reservationId: id));
      }
      return;
    }
    if (item.kind == 'CONTRACT' && segments[0] == 'contracts') {
      switch (_mode) {
        case 'sale':
          _mo(const LongTermStayWorkspaceScreen(role: StayWorkspaceRole.sale));
        case 'owner':
          _mo(ContractDetailScreen(contractId: id));
        default:
          _mo(PhongDangThueScreen(contractId: id));
      }
      return;
    }
    if (item.kind == 'INVOICE' &&
        segments[0] == 'contracts' &&
        _mode == 'customer') {
      _mo(PhongDangThueScreen(contractId: id));
      return;
    }
    if (item.kind == 'INVOICE' && segments[0] == 'invoices') {
      if (_mode == 'owner') {
        _mo(InvoiceDetailScreen(invoiceId: id));
      } else {
        // Sale chỉ theo dõi/hỗ trợ, không được đi vào màn quản trị tài khoản
        // nhận tiền của Chủ nhà.
        _mo(const LongTermStayWorkspaceScreen(role: StayWorkspaceRole.sale));
      }
      return;
    }
    _bao('Loại công việc này chưa có màn chi tiết tương ứng.');
  }

  void _moDangOKhach() => _mo(
    _TrangCoTieuDe(
      title: 'Phòng đang ở',
      child: CustomerManagementScreen(
        initialTab: 3,
        api: widget.quanLyApi,
        managementApi: widget.managementReadModelApi,
      ),
    ),
  );

  void _moViecSale() => _mo(YeuCauListScreen(api: widget.saleYeuCauApi));

  void _moWorkspaceSale() => _mo(
    _TrangCoTieuDe(
      title: 'Sale Workspace',
      child: SaleWorkspaceScreen(api: widget.quanLyApi),
    ),
  );

  void _moPhongSale() =>
      _mo(const LongTermStayWorkspaceScreen(role: StayWorkspaceRole.sale));

  void _moNganHanTheoVaiTro() {
    switch (_mode) {
      case 'owner':
        _mo(QuanLyNganHanChuNhaScreen(api: widget.chuNhaApi));
        return;
      case 'sale':
        _mo(
          const ShortStayBookingsScreen(
            operations: true,
            operationsRole: ShortStayOperationsRole.sale,
          ),
        );
        return;
      default:
        _mo(const ShortStayBookingsScreen());
        return;
    }
  }

  void _moQuanLyToaNha() => _mo(const HostHomeScreen());

  void _moDanhSachToa() => _mo(
    const _TrangCoTieuDe(title: 'Tòa nhà & phòng', child: BuildingListScreen()),
  );

  void _moPhongDangOChuNha() =>
      _mo(const LongTermStayWorkspaceScreen(role: StayWorkspaceRole.owner));

  static String _iso(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  static String _tienGon(double value) {
    if (value >= 1000000000) {
      return '${_boSo0(value / 1000000000)}tỷ';
    }
    if (value >= 1000000) return '${_boSo0(value / 1000000)}tr';
    if (value >= 1000) return '${_boSo0(value / 1000)}k';
    return _boSo0(value);
  }

  static String _boSo0(double value) {
    final s = value.toStringAsFixed(1);
    return s.endsWith('.0') ? s.substring(0, s.length - 2) : s;
  }
}

/// Thẻ "đang đăng nhập với vai …" ở đầu trang Quản lý. Vai không đổi được tại
/// chỗ: muốn dùng vai khác thì đăng xuất rồi chọn vai đó khi đăng nhập lại —
/// nút "Đổi vai" đi thẳng vào luồng đăng xuất dùng chung (có hộp xác nhận).
class _TheVaiDangNhap extends StatelessWidget {
  const _TheVaiDangNhap({required this.mode});

  final String mode;

  @override
  Widget build(BuildContext context) {
    final (ten, icon, mau, nen) = switch (mode) {
      'sale' => (
        'Sale',
        Icons.work_outline_rounded,
        HD.pinBusiness,
        const Color(0xFFE8F0FC),
      ),
      'owner' => (
        'Chủ nhà',
        Icons.home_work_outlined,
        HD.positive,
        HD.positiveTint,
      ),
      _ => (
        'Khách hàng',
        Icons.person_outline_rounded,
        HD.accent,
        HD.accentTint,
      ),
    };
    return Container(
      key: const Key('the-vai-dang-nhap'),
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xffedf0f4)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x09000000),
            blurRadius: 12,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(color: nen, shape: BoxShape.circle),
            child: Icon(icon, color: mau, size: 23),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Bạn đang đăng nhập với vai',
                  style: HD.caption().copyWith(color: HD.inkMuted),
                ),
                const SizedBox(height: 2),
                Text(
                  ten,
                  key: const Key('the-vai-dang-nhap-ten'),
                  style: HD.bodyBold(size: 16, color: mau),
                ),
                const SizedBox(height: 3),
                Text(
                  'Muốn dùng vai khác? Đăng xuất rồi chọn vai khi đăng nhập lại.',
                  style: HD.caption().copyWith(
                    color: HD.inkMuted,
                    fontSize: 11.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          OutlinedButton.icon(
            key: const Key('the-vai-doi-vai'),
            onPressed: () => logoutFlow(context),
            icon: const Icon(Icons.swap_horiz_rounded, size: 18),
            label: const Text('Đổi vai'),
            style: OutlinedButton.styleFrom(
              foregroundColor: mau,
              side: BorderSide(color: mau.withValues(alpha: 0.45)),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              minimumSize: const Size(0, 38),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              textStyle: HD.bodyBold(size: 13),
            ),
          ),
        ],
      ),
    );
  }
}

class _LoaiVanHanhTab extends StatelessWidget {
  const _LoaiVanHanhTab({
    super.key,
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: selected ? HD.accentSoft : Colors.transparent,
    borderRadius: BorderRadius.circular(11),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(11),
      child: Container(
        constraints: const BoxConstraints(minHeight: 38),
        alignment: Alignment.center,
        decoration: selected
            ? BoxDecoration(
                borderRadius: BorderRadius.circular(11),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x10000000),
                    blurRadius: 8,
                    offset: Offset(0, 2),
                  ),
                ],
              )
            : null,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18, color: selected ? HD.accent : HD.inkMuted),
            const SizedBox(width: 7),
            Text(
              label,
              style: selected
                  ? HD.bodyBold(size: 13.5, color: HD.accent)
                  : HD.body(size: 13.5, color: HD.inkMuted),
            ),
          ],
        ),
      ),
    ),
  );
}

class _TrangThaiV2Chip extends StatelessWidget {
  const _TrangThaiV2Chip({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final int value;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    constraints: const BoxConstraints(minWidth: 96),
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
    decoration: BoxDecoration(
      color: color.withValues(alpha: .10),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: color.withValues(alpha: .22)),
    ),
    child: Text('$label · $value', style: HD.body(size: 12.5, color: color)),
  );
}

class _TheTongQuan extends StatelessWidget {
  const _TheTongQuan({
    required this.icon,
    required this.color,
    required this.value,
    required this.label,
    required this.loading,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final String value;
  final String label;
  final bool loading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.white,
    borderRadius: BorderRadius.circular(13),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(13),
      child: Container(
        height: 65,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(13),
          border: Border.all(color: const Color(0xffe9edf2)),
        ),
        child: Row(
          children: [
            Container(
              width: 37,
              height: 37,
              decoration: BoxDecoration(
                color: color.withValues(alpha: .10),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 21),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AnimatedOpacity(
                    opacity: loading ? .35 : 1,
                    duration: const Duration(milliseconds: 160),
                    child: Text(
                      value,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: HD.bodyBold(size: 17, color: HD.ink),
                    ),
                  ),
                  Text(
                    label,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: HD.body(size: 10.8, color: HD.inkMuted),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _MucQuanLyVaiTro {
  const _MucQuanLyVaiTro(
    this.icon,
    this.title,
    this.subtitle,
    this.color,
    this.badge,
    this.onTap,
  );

  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final int? badge;
  final VoidCallback onTap;
}

class _DongQuanLy extends StatelessWidget {
  const _DongQuanLy({required this.data});

  final _MucQuanLyVaiTro data;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: data.onTap,
    borderRadius: BorderRadius.circular(13),
    child: Padding(
      padding: const EdgeInsets.fromLTRB(12, 9, 9, 9),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: data.color.withValues(alpha: .10),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(data.icon, color: data.color, size: 20),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(data.title, style: HD.bodyBold(size: 13.2, color: HD.ink)),
                const SizedBox(height: 1),
                Text(
                  data.subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: HD.body(size: 10.8, color: HD.inkMuted),
                ),
              ],
            ),
          ),
          if (data.badge != null && data.badge! > 0)
            Container(
              constraints: const BoxConstraints(minWidth: 25),
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: HD.accent,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(
                '${data.badge}',
                style: HD.bodyBold(size: 10.5, color: Colors.white),
              ),
            ),
          const SizedBox(width: 4),
          const Icon(Icons.chevron_right_rounded, color: HD.inkMuted, size: 21),
        ],
      ),
    ),
  );
}

/// Bọc những màn cũ vốn được thiết kế như tab gốc (không có nút back) để khi
/// mở từ sảnh Quản lý người dùng luôn có đường quay lại.
class _TrangCoTieuDe extends StatelessWidget {
  const _TrangCoTieuDe({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: HD.paper,
    appBar: AppBar(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      title: Text(title, style: HD.bodyBold(size: 17)),
    ),
    body: child,
  );
}
