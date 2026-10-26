import 'package:cached_network_image/cached_network_image.dart';
import 'package:fl_chart/fl_chart.dart'
    show
        AxisTitles,
        BarAreaData,
        FlBorderData,
        FlDotCirclePainter,
        FlDotData,
        FlGridData,
        FlSpot,
        FlTitlesData,
        LineChart,
        LineChartBarData,
        LineChartData,
        LineTooltipItem,
        LineTouchData,
        LineTouchTooltipData,
        SideTitles;
import 'package:flutter/material.dart';

import 'package:house_booking/core/utils/formatters.dart';
import 'package:house_booking/core/widgets/ds.dart';
import 'package:house_booking/data/services/dien_nuoc_api.dart';
import 'package:house_booking/data/services/tong_quan_chu_nha_api.dart';
import 'package:house_booking/features/host/journey/tong_quan_xem_nha_screen.dart';
import 'package:house_booking/features/host/billing/screens/service_fee_list_screen.dart';
import 'package:house_booking/features/host/dien_nuoc/dien_nuoc_dai_han_screen.dart';
import 'package:house_booking/features/host/khach_thue/khach_thue_screen.dart';
import 'package:house_booking/features/host/property/screens/owner_building_management_screen.dart';
import 'package:house_booking/features/host/property/screens/building_list_screen.dart';
import 'package:house_booking/features/host/reports/screens/reports_home_screen.dart';
import 'package:house_booking/features/notifications/notifications_screen.dart';

/// TRANG CHỦ CHỦ NHÀ — dựng theo mockup "An Cư - Quản lý tòa nhà" (11/09/2026):
/// chọn toà · 4 thẻ số · lọc loại hình · "Tòa nhà của bạn" · thao tác nhanh ·
/// "Tình hình lưu trú". Nằm trong `HostHomeScreen` (tab Cá nhân của chủ nhà);
/// thanh điều hướng dưới là của app, không vẽ ở đây.
/// API: `TongQuanChuNhaApi` (`GET /api/host/tong-quan`).
///
/// Mọi con số là số đo thật. Chỗ server không tính được — tháng trước không có
/// doanh thu, chưa có phòng cho thuê nào — trả `null` và màn này ẨN dòng đó,
/// không in số minh hoạ.
///
/// Mockup có nút "Lịch phòng" ở thanh nav và thẻ toà cũ có chip "phòng nợ" —
/// cả hai không còn trên màn này, nên Lịch phòng và Công nợ nay nằm trong
/// "Cài đặt & tài khoản". Bỏ lối mà không đặt lại là màn con mồ côi.
class TongQuanChuNhaScreen extends StatefulWidget {
  const TongQuanChuNhaScreen({
    super.key,
    this.api = const TongQuanChuNhaApi(),
    this.dienNuocApi = const DienNuocApi(),
    this.ten = '',
    this.anhDaiDien,
    this.soChuaDoc = 0,
    this.onMoTrangCaNhan,
    this.onMoCaiDat,
    this.soLichHenCho = 0,
    this.onMoLichHen,
  });

  final TongQuanChuNhaApi api;
  final DienNuocApi dienNuocApi;
  final String ten;
  final String? anhDaiDien;
  final int soChuaDoc;

  /// Hai lối trong menu ẢNH ĐẠI DIỆN. Chủ nhà không có trang công khai như
  /// sale — thiếu hai lối này là không còn đường tới cài đặt và đăng xuất.
  final VoidCallback? onMoTrangCaNhan;
  final VoidCallback? onMoCaiDat;

  /// Khách hẹn xem phòng đang chờ chủ nhà trả lời (duyệt / từ chối / đổi giờ).
  /// 0 thì không vẽ gì — thẻ báo việc chỉ xuất hiện khi CÓ việc.
  final int soLichHenCho;
  final VoidCallback? onMoLichHen;

  @override
  State<TongQuanChuNhaScreen> createState() => _TongQuanChuNhaScreenState();
}

class _TongQuanChuNhaScreenState extends State<TongQuanChuNhaScreen> {
  TongQuanChuNha? _so;
  int? _toaId;
  String _loc = 'tat_ca';
  bool _dangTai = false;
  String? _loi;

  /// Giữ từ lượt tải KHÔNG lọc. Lọc một toà thì server chỉ trả đúng toà đó —
  /// dựng ô chọn từ đó thì ô chọn còn một dòng, không quay lại "Tất cả" được.
  List<({int id, String ten})> _tatCaToa = const [];

  static const _cacLoc = [
    ('tat_ca', 'Tất cả', Icons.grid_view_rounded),
    ('ngan_han', 'Ngắn hạn', Icons.schedule),
    ('dai_han', 'Dài hạn', Icons.calendar_today_outlined),
    ('kinh_doanh', 'Kinh doanh', Icons.shopping_cart_outlined),
    ('cho_thue', 'Cho thuê', Icons.home_outlined),
    ('khach_san', 'Khách sạn', Icons.apartment_outlined),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _nap());
  }

  Future<void> _nap() async {
    setState(() {
      _dangTai = true;
      _loi = null;
    });
    try {
      final so = await widget.api.lay(buildingId: _toaId);
      if (!mounted) return;
      setState(() {
        _so = so;
        if (_toaId == null) _tatCaToa = so.toa;
      });
    } catch (_) {
      if (mounted) {
        setState(() => _loi = 'Không tải được số liệu. Kéo xuống để thử lại.');
      }
    } finally {
      if (mounted) setState(() => _dangTai = false);
    }
  }

  void _mo(Widget man) =>
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => man));

  void _moDienNuoc() => _mo(
    DienNuocDaiHanScreen(
      toa: _tatCaToa,
      buildingId: _toaId,
      api: widget.dienNuocApi,
    ),
  );

  @override
  Widget build(BuildContext context) {
    final so = _so;
    return Material(
      color: HD.paper,
      child: RefreshIndicator(
        onRefresh: _nap,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(HD.s16, HD.s12, HD.s16, HD.s32),
          children: [
            _heroHeader(),
            const SizedBox(height: HD.s16),
            if (widget.soLichHenCho > 0 && widget.onMoLichHen != null) ...[
              _theLichHen(),
              const SizedBox(height: HD.s16),
            ],
            if (so == null && _loi != null)
              _Rong(chu: _loi!, nut: 'Thử lại', onNut: _nap)
            else if (so == null)
              const Padding(
                padding: EdgeInsets.all(HD.s32),
                child: Center(child: CircularProgressIndicator()),
              )
            else ...[
              _chonToa(so),
              if (_dangTai)
                const Padding(
                  padding: EdgeInsets.only(top: HD.s4),
                  child: LinearProgressIndicator(minHeight: 2),
                ),
              const SizedBox(height: HD.s16),
              _theSo(so),
              const SizedBox(height: HD.s16),
              _locToa(),
              const SizedBox(height: HD.s16),
              _danhSachToa(so),
              const SizedBox(height: HD.s20),
              _thaoTacNhanh(),
              if (so.tyLeLapDay != null ||
                  so.lapDay6Thang.any((x) => x.tyLe != null)) ...[
                const SizedBox(height: HD.s20),
                _BieuDoLuuTru(so: so),
              ],
            ],
          ],
        ),
      ),
    );
  }

  // ── Lịch hẹn xem đang chờ ────────────────────────────────────────────────

  Widget _theLichHen() => _The(
    onTap: widget.onMoLichHen,
    child: Row(
      key: const Key('the-lich-hen-cho'),
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: const BoxDecoration(
            color: HD.warningTint,
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.event_note, color: HD.svcAmber, size: 22),
        ),
        const SizedBox(width: HD.s12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${widget.soLichHenCho} khách hẹn xem phòng · chờ bạn trả lời',
                style: HD.bodyBold(size: 14),
              ),
              const SizedBox(height: 2),
              Text(
                'Duyệt, hoặc bận thì bấm "Bận · đổi giờ" để khách chọn lại',
                style: HD.body(size: 12, color: HD.inkMuted),
              ),
            ],
          ),
        ),
        const Icon(Icons.chevron_right, color: HD.inkMuted),
      ],
    ),
  );

  // ── Đầu trang ─────────────────────────────────────────────────────────────

  Widget _heroHeader() => ClipRRect(
    borderRadius: const BorderRadius.vertical(bottom: Radius.circular(22)),
    child: SizedBox(
      height: 220,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset('assets/branding/hero_bg.jpg', fit: BoxFit.cover),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  HD.accent.withValues(alpha: .94),
                  HD.accent.withValues(alpha: .78),
                  HD.accent.withValues(alpha: .58),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          _anhDaiDien(),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Xin chào,',
                                  style: HD.body(
                                    size: 12,
                                    color: Colors.white70,
                                  ),
                                ),
                                Text(
                                  widget.ten,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: HD.bodyBold(
                                    size: 18,
                                    color: Colors.white,
                                  ),
                                ),
                                Text(
                                  'Chủ nhà',
                                  style: HD.body(
                                    size: 10,
                                    color: Colors.white70,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Image.asset(
                            'assets/branding/logo_mark.png',
                            fit: BoxFit.contain,
                          ),
                        ),
                        Text(
                          'VuaNhà',
                          style: HD.bodyBold(size: 11, color: Colors.white),
                        ),
                      ],
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      tooltip: 'Thông báo',
                      onPressed: () => _mo(const NotificationsScreen()),
                      icon: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          const Icon(
                            Icons.notifications_none_rounded,
                            color: Colors.white,
                            size: 27,
                          ),
                          if (widget.soChuaDoc > 0)
                            Positioned(
                              right: -1,
                              top: -1,
                              child: Container(
                                key: const ValueKey('cham-thong-bao'),
                                width: 9,
                                height: 9,
                                decoration: const BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                Material(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(30),
                  child: InkWell(
                    onTap: () => _mo(const BuildingListScreen()),
                    borderRadius: BorderRadius.circular(30),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 13,
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.search_rounded,
                            color: HD.inkMuted,
                            size: 22,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Nhập từ khóa, khu vực, dự án...',
                              style: HD.body(size: 14, color: HD.inkMuted),
                            ),
                          ),
                          Container(
                            width: 40,
                            height: 40,
                            decoration: const BoxDecoration(
                              color: HD.accent,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.search_rounded,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );

  Widget _anhDaiDien() {
    final url = widget.anhDaiDien ?? '';
    final anh = Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: HD.paperSunken,
        shape: BoxShape.circle,
        border: Border.all(color: HD.hairline.withValues(alpha: 0.6)),
        boxShadow: HD.sunkenShadow,
      ),
      clipBehavior: Clip.antiAlias,
      child: url.isEmpty
          ? const Icon(Icons.person, size: 24, color: HD.inkMuted)
          : CachedNetworkImage(
              imageUrl: anhTuyetDoi(url),
              fit: BoxFit.cover,
              errorWidget: (_, _, _) =>
                  const Icon(Icons.person, size: 24, color: HD.inkMuted),
            ),
    );
    if (widget.onMoTrangCaNhan == null && widget.onMoCaiDat == null) {
      return anh;
    }
    return PopupMenuButton<VoidCallback>(
      tooltip: 'Tài khoản',
      position: PopupMenuPosition.under,
      onSelected: (mo) => mo(),
      itemBuilder: (_) => [
        if (widget.onMoTrangCaNhan != null)
          PopupMenuItem(
            value: widget.onMoTrangCaNhan,
            child: const ListTile(
              leading: Icon(Icons.person_outline),
              title: Text('Trang cá nhân của tôi'),
            ),
          ),
        if (widget.onMoCaiDat != null)
          PopupMenuItem(
            value: widget.onMoCaiDat,
            child: const ListTile(
              leading: Icon(Icons.settings_outlined),
              title: Text('Tài khoản & cài đặt'),
            ),
          ),
      ],
      child: anh,
    );
  }

  // ── Chọn toà + bốn thẻ số ─────────────────────────────────────────────────

  Widget _chonToa(TongQuanChuNha so) {
    var ten = 'Tất cả tòa nhà';
    for (final t in _tatCaToa) {
      if (t.id == _toaId) ten = t.ten;
    }
    return PopupMenuButton<int>(
      tooltip: 'Chọn tòa nhà',
      position: PopupMenuPosition.under,
      // -1 = "Tất cả": PopupMenuButton không gọi onSelected với giá trị null.
      onSelected: (id) {
        setState(() => _toaId = id < 0 ? null : id);
        _nap();
      },
      itemBuilder: (_) => [
        const PopupMenuItem(value: -1, child: Text('Tất cả tòa nhà')),
        for (final t in _tatCaToa)
          PopupMenuItem(value: t.id, child: Text(t.ten)),
      ],
      child: _The(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Row(
          children: [
            const _OIcon(
              icon: Icons.apartment,
              mau: HD.accent,
              canh: 40,
              bo: HD.r12,
              coIcon: 20,
            ),
            const SizedBox(width: HD.s12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    ten,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: HD.bodyBold(size: 14.5),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${so.soToa} tòa nhà · ${so.soPhong} phòng',
                    style: HD.body(size: 11.5, color: HD.inkMuted),
                  ),
                ],
              ),
            ),
            const Icon(Icons.keyboard_arrow_down, color: HD.inkMuted),
          ],
        ),
      ),
    );
  }

  Widget _theSo(TongQuanChuNha so) {
    final tang = so.doanhThuTang;
    final the = [
      _TheSo(
        icon: Icons.apartment,
        mau: HD.accent,
        giaTri: TextSpan(text: '${so.soToa}'),
        nhan: 'Tòa nhà',
        phu: so.toaMoiThangNay > 0
            ? '▲ +${so.toaMoiThangNay} so với tháng trước'
            : null,
        mauPhu: HD.positive,
      ),
      _TheSo(
        icon: Icons.home_outlined,
        mau: HD.positive,
        giaTri: TextSpan(text: '${so.phongDaThue}'),
        nhan: 'Phòng đã thuê',
        phu: so.tyLeLapDay == null
            ? null
            : '${_phanTram(so.tyLeLapDay!)} lấp đầy',
        mauPhu: HD.positive,
      ),
      _TheSo(
        icon: Icons.remove,
        mau: HD.inkMuted,
        giaTri: TextSpan(text: '${so.phongTrong}'),
        nhan: 'Phòng trống',
        phu: so.tyLeTrong == null ? null : _phanTram(so.tyLeTrong!),
        mauPhu: HD.inkMuted,
      ),
      _TheSo(
        icon: Icons.payments_outlined,
        mau: HD.accent,
        giaTri: _tienSpan(so.doanhThuThang),
        nhan: 'Doanh thu tháng này',
        phu: tang == null
            ? null
            : '${tang >= 0 ? '▲ +' : '▼ -'}${_phanTram(tang.abs())} '
                  'so với T${so.thangTruoc}',
        mauPhu: tang == null || tang >= 0 ? HD.positive : HD.negative,
      ),
    ];
    // Bốn cột ở MỌI độ rộng như mockup; thẻ cao bằng nhau dù dòng phụ xuống
    // hai dòng ở màn hẹp.
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < the.length; i++) ...[
            if (i > 0) const SizedBox(width: 10),
            Expanded(child: the[i]),
          ],
        ],
      ),
    );
  }

  // ── Lọc + danh sách toà ───────────────────────────────────────────────────

  Widget _locToa() => SingleChildScrollView(
    scrollDirection: Axis.horizontal,
    child: Row(
      children: [
        for (final (k, nhan, icon) in _cacLoc)
          Padding(
            padding: const EdgeInsets.only(right: HD.s8),
            child: _ChipLoc(
              key: ValueKey('loc-$k'),
              nhan: nhan,
              icon: icon,
              chon: _loc == k,
              onTap: () => setState(() => _loc = k),
            ),
          ),
      ],
    ),
  );

  /// Mỗi chip lọc đúng theo nhãn server gắn cho toà (`loai`) — cùng bộ nhãn
  /// hiện trên thẻ, nên bấm "Khách sạn" là ra đúng những thẻ mang nhãn đó.
  bool _hopLoc(ToaNha t) => _loc == 'tat_ca' || t.loai.contains(_loc);

  Widget _danhSachToa(TongQuanChuNha so) {
    final hien = so.toaNha.where(_hopLoc).take(3).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text('Tòa nhà của bạn', style: HD.bodyBold(size: 16)),
            ),
            InkWell(
              onTap: () => _mo(const BuildingListScreen()),
              borderRadius: BorderRadius.circular(HD.r8),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: HD.s4,
                  vertical: 2,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Xem tất cả',
                      style: HD.bodyBold(size: 12, color: HD.accent),
                    ),
                    const Icon(Icons.chevron_right, size: 16, color: HD.accent),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: HD.s12),
        if (so.toaNha.isEmpty)
          _Rong(
            chu: 'Chưa có tòa nhà nào.',
            nut: 'Thêm tòa nhà',
            onNut: () => _mo(const BuildingListScreen()),
          )
        else if (hien.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: HD.s16),
            child: Center(
              child: Text(
                'Không có tòa nhà nào thuộc loại này.',
                style: HD.body(size: 13, color: HD.inkMuted),
              ),
            ),
          )
        else
          for (var i = 0; i < hien.length; i++) ...[
            if (i > 0) const SizedBox(height: HD.s12),
            _TheToa(
              key: ValueKey('toa-${hien[i].buildingId}'),
              toa: hien[i],
              onTap: () => _mo(
                OwnerBuildingManagementScreen(
                  buildingId: hien[i].buildingId,
                  buildingName: hien[i].ten,
                  address: hien[i].diaChi,
                ),
              ),
            ),
          ],
      ],
    );
  }

  // ── Thao tác nhanh ────────────────────────────────────────────────────────

  Widget _thaoTacNhanh() {
    final muc = <(IconData, String, Color, VoidCallback)>[
      (
        Icons.table_chart_outlined,
        'Quản lí phòng',
        HD.accent,
        () => _mo(const BuildingListScreen()),
      ),
      (Icons.bolt, 'Điện nước', HD.svcOrange, _moDienNuoc),
      (
        Icons.event_available,
        'Yêu cầu xem nhà',
        HD.svcBlue,
        () => _mo(TongQuanXemNhaScreen(tenChuNha: widget.ten)),
      ),
      (
        Icons.grid_view_rounded,
        'Dịch vụ',
        HD.svcViolet,
        () => _mo(const ServiceFeeListScreen()),
      ),
      (
        Icons.people_alt,
        'Khách thuê',
        HD.svcBlue,
        () => _mo(const KhachThueScreen()),
      ),
      (
        Icons.bar_chart_rounded,
        'Báo cáo',
        HD.svcGreen,
        () => _mo(const ReportsHomeScreen()),
      ),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Thao tác nhanh', style: HD.bodyBold(size: 16)),
        const SizedBox(height: HD.s12),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final (icon, nhan, mau, onTap) in muc)
              Expanded(
                child: _NutNhanh(
                  icon: icon,
                  nhan: nhan,
                  mau: mau,
                  onTap: onTap,
                ),
              ),
          ],
        ),
      ],
    );
  }
}

// ── Định dạng ────────────────────────────────────────────────────────────────

String _phanTram(double v) {
  final r = (v * 10).round() / 10;
  return '${r == r.roundToDouble() ? r.toStringAsFixed(0) : r.toStringAsFixed(1)}%';
}

/// "125,6 triệu" — cách người Việt đọc tiền; "125.600.000đ" dài tràn thẻ.
String _tienGon(double v) {
  String so(double x) {
    final s = x.toStringAsFixed(1);
    return (s.endsWith('.0') ? s.substring(0, s.length - 2) : s).replaceAll(
      '.',
      ',',
    );
  }

  if (v >= 1e9) return '${so(v / 1e9)} tỷ';
  if (v >= 1e6) return '${so(v / 1e6)} triệu';
  return PriceFormat.full(v);
}

/// Số to, đơn vị nhỏ — "125,6" + " triệu" như mockup.
InlineSpan _tienSpan(double v) {
  final chu = _tienGon(v);
  final cach = chu.indexOf(' ');
  if (cach < 0) return TextSpan(text: chu);
  return TextSpan(
    children: [
      TextSpan(text: chu.substring(0, cach)),
      TextSpan(text: chu.substring(cach), style: HD.bodyBold(size: 12)),
    ],
  );
}

String _thangNgan(int thang) => 'Th$thang';

// ── Thành phần ───────────────────────────────────────────────────────────────

const double _boThe = 16;

/// Thẻ trắng bo 16, viền mảnh, bóng rất nhẹ — khung chung của mọi khối.
class _The extends StatelessWidget {
  const _The({
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.all(HD.s12),
  });

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(_boThe),
      boxShadow: HD.sunkenShadow,
    ),
    child: Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(_boThe),
        side: BorderSide(color: HD.hairline.withValues(alpha: 0.5)),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(padding: padding, child: child),
      ),
    ),
  );
}

class _OIcon extends StatelessWidget {
  const _OIcon({
    required this.icon,
    required this.mau,
    required this.canh,
    required this.bo,
    required this.coIcon,
  });

  final IconData icon;
  final Color mau;
  final double canh;
  final double bo;
  final double coIcon;

  @override
  Widget build(BuildContext context) => Container(
    width: canh,
    height: canh,
    decoration: BoxDecoration(
      color: mau.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(bo),
    ),
    child: Icon(icon, size: coIcon, color: mau),
  );
}

class _TheSo extends StatelessWidget {
  const _TheSo({
    required this.icon,
    required this.mau,
    required this.giaTri,
    required this.nhan,
    required this.phu,
    required this.mauPhu,
  });

  final IconData icon;
  final Color mau;
  final InlineSpan giaTri;
  final String nhan;
  final String? phu;
  final Color mauPhu;

  @override
  Widget build(BuildContext context) => _The(
    padding: const EdgeInsets.all(10),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _OIcon(icon: icon, mau: mau, canh: 24, bo: HD.r8, coIcon: 14),
        const SizedBox(height: 6),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text.rich(giaTri, maxLines: 1, style: HD.bodyBold(size: 19)),
        ),
        Text(
          nhan,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: HD.body(size: 11, color: HD.inkMuted),
        ),
        const Spacer(),
        if (phu != null)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              phu!,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: HD.bodyBold(size: 9.5, color: mauPhu),
            ),
          ),
      ],
    ),
  );
}

class _ChipLoc extends StatelessWidget {
  const _ChipLoc({
    super.key,
    required this.nhan,
    required this.icon,
    required this.chon,
    required this.onTap,
  });

  final String nhan;
  final IconData icon;
  final bool chon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: chon ? HD.accent : Colors.white,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(HD.r12),
      side: chon
          ? BorderSide.none
          : BorderSide(color: HD.hairline.withValues(alpha: 0.8)),
    ),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(HD.r12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: chon ? Colors.white : HD.inkMuted),
            const SizedBox(width: 6),
            Text(
              nhan,
              style: chon
                  ? HD.bodyBold(size: 12, color: Colors.white)
                  : HD.body(size: 12, color: HD.ink),
            ),
          ],
        ),
      ),
    ),
  );
}

class _TheToa extends StatelessWidget {
  const _TheToa({super.key, required this.toa, required this.onTap});

  final ToaNha toa;
  final VoidCallback onTap;

  static const _nhan = {
    'khach_san': ('Khách sạn', HD.svcViolet),
    'kinh_doanh': ('Kinh doanh', HD.svcBlue),
    'ngan_han': ('Ngắn hạn', HD.accent),
    'dai_han': ('Dài hạn', HD.inkMuted),
    'cho_thue': ('Cho thuê', HD.accent),
  };

  @override
  Widget build(BuildContext context) {
    // Thứ tự nhãn là thứ tự server trả.
    final the = <(String, Color)>[
      for (final k in toa.loai)
        if (_nhan[k] case final n?) n,
    ];
    return _The(
      onTap: onTap,
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(HD.r12),
            child: SizedBox(width: 66, height: 66, child: _anh()),
          ),
          const SizedBox(width: HD.s12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  toa.ten,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: HD.bodyBold(size: 14),
                ),
                if (toa.diaChi.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      toa.diaChi,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: HD.body(size: 11, color: HD.inkMuted),
                    ),
                  ),
                if (the.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      for (final (nhan, mau) in the) _Tag(nhan: nhan, mau: mau),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: HD.s8),
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(
                              text: '${toa.daThue}',
                              style: HD.bodyBold(size: 11),
                            ),
                            TextSpan(
                              text: '/${toa.tong} phòng',
                              style: HD.body(size: 10, color: HD.inkMuted),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 4),
                      SizedBox(
                        width: 64,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(HD.rPill),
                          child: LinearProgressIndicator(
                            value: toa.tong == 0
                                ? 0
                                : (toa.daThue / toa.tong).clamp(0.0, 1.0),
                            minHeight: 6,
                            backgroundColor: HD.paperSunken,
                            color: HD.positive,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: HD.s8),
                  SizedBox(
                    width: 32,
                    child: Text(
                      '${toa.tyLe}%',
                      textAlign: TextAlign.right,
                      style: HD.bodyBold(size: 11, color: HD.inkMuted),
                    ),
                  ),
                  const Icon(Icons.chevron_right, size: 16, color: HD.inkMuted),
                ],
              ),
              const SizedBox(height: 10),
              _TrangThai(hoatDong: toa.hoatDong),
            ],
          ),
        ],
      ),
    );
  }

  Widget _anh() {
    const rong = ColoredBox(
      color: HD.paperSunken,
      child: Center(child: Icon(Icons.apartment, color: HD.inkMuted)),
    );
    final url = toa.anhBia ?? '';
    if (url.isEmpty) return rong;
    return CachedNetworkImage(
      imageUrl: anhTuyetDoi(url),
      fit: BoxFit.cover,
      placeholder: (_, _) => rong,
      errorWidget: (_, _, _) => rong,
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag({required this.nhan, required this.mau});

  final String nhan;
  final Color mau;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: HD.s8, vertical: 2),
    decoration: BoxDecoration(
      color: mau.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(6),
    ),
    child: Text(nhan, style: HD.body(size: 10, color: mau)),
  );
}

class _TrangThai extends StatelessWidget {
  const _TrangThai({required this.hoatDong});

  final bool hoatDong;

  @override
  Widget build(BuildContext context) {
    final mau = hoatDong ? HD.positive : HD.inkMuted;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: HD.s8, vertical: 2),
      decoration: BoxDecoration(
        color: mau.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(HD.rPill),
        border: Border.all(color: mau.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: mau, shape: BoxShape.circle),
          ),
          const SizedBox(width: 4),
          Text(
            // Toà chưa có phòng nào bật kênh cho thuê — chưa phải "hoạt động".
            hoatDong ? 'Hoạt động' : 'Chưa khai thác',
            style: HD.bodyBold(size: 9.5, color: mau),
          ),
        ],
      ),
    );
  }
}

class _NutNhanh extends StatelessWidget {
  const _NutNhanh({
    required this.icon,
    required this.nhan,
    required this.mau,
    required this.onTap,
  });

  final IconData icon;
  final String nhan;
  final Color mau;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(_boThe),
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: HD.s4),
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(_boThe),
              border: Border.all(color: HD.hairline.withValues(alpha: 0.5)),
              boxShadow: HD.sunkenShadow,
            ),
            alignment: Alignment.center,
            child: _OIcon(
              icon: icon,
              mau: mau,
              canh: 36,
              bo: HD.r12,
              coIcon: 20,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            nhan,
            textAlign: TextAlign.center,
            maxLines: 2,
            style: HD.body(size: 11, color: HD.ink),
          ),
        ],
      ),
    ),
  );
}

/// "Tình hình lưu trú" — tỉ lệ lấp đầy 6 tháng, MỘT chuỗi số nên không cần
/// chú giải: tiêu đề gọi tên nó. Nét 2px, chấm có vòng trắng, nền loang rất
/// nhạt; chạm vào điểm hiện số của tháng đó. Số tháng này in to ở trên, nên
/// tooltip không phải đường DUY NHẤT để đọc được con số.
class _BieuDoLuuTru extends StatelessWidget {
  const _BieuDoLuuTru({required this.so});

  final TongQuanChuNha so;

  @override
  Widget build(BuildContext context) {
    final chuoi = so.lapDay6Thang;
    final hienTai = so.tyLeLapDay;
    final tang = so.lapDayTang;
    final thangNay = chuoi.isEmpty ? '' : ' tháng ${chuoi.last.thang}';
    return _The(
      padding: const EdgeInsets.all(HD.s16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _OIcon(
                icon: Icons.trending_up,
                mau: HD.accent,
                canh: 32,
                bo: HD.r8,
                coIcon: 16,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Tình hình lưu trú$thangNay',
                      style: HD.bodyBold(size: 13.5),
                    ),
                    if (hienTai != null)
                      Text(_phanTram(hienTai), style: HD.bodyBold(size: 20)),
                    if (tang != null)
                      Text(
                        '${tang >= 0 ? '▲ +' : '▼ -'}${_phanTram(tang.abs())} '
                        'so với tháng trước',
                        style: HD.bodyBold(
                          size: 10,
                          color: tang >= 0 ? HD.positive : HD.negative,
                        ),
                      ),
                  ],
                ),
              ),
              if (hienTai != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: HD.s8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: HD.accent,
                    borderRadius: BorderRadius.circular(HD.rPill),
                  ),
                  child: Text(
                    _phanTram(hienTai),
                    style: HD.bodyBold(size: 10, color: Colors.white),
                  ),
                ),
            ],
          ),
          const SizedBox(height: HD.s16),
          // Bản "bảng" đọc được bằng trình đọc màn hình — biểu đồ không phải
          // đường duy nhất tới các con số.
          Semantics(
            label:
                'Tỉ lệ lấp đầy 6 tháng: ${[for (final x in chuoi) '${_thangNgan(x.thang)} ${x.tyLe == null ? 'chưa có số' : _phanTram(x.tyLe!)}'].join(', ')}',
            child: ExcludeSemantics(
              child: SizedBox(height: 104, child: LineChart(_duLieu(chuoi))),
            ),
          ),
        ],
      ),
    );
  }

  LineChartData _duLieu(List<({int nam, int thang, double? tyLe})> chuoi) {
    final cuoi = chuoi.length - 1;
    return LineChartData(
      minX: 0,
      maxX: cuoi > 0 ? cuoi.toDouble() : 1,
      minY: 0,
      // Thang cố định 0–100%: tỉ lệ lấp đầy luôn nằm trong đó, và thang tự co
      // giãn theo dữ liệu sẽ biến 70→72% thành một cú dựng đứng.
      maxY: 108,
      gridData: const FlGridData(show: false),
      borderData: FlBorderData(show: false),
      titlesData: FlTitlesData(
        leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        rightTitles: const AxisTitles(
          sideTitles: SideTitles(showTitles: false),
        ),
        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 22,
            interval: 1,
            getTitlesWidget: (v, _) {
              final i = v.round();
              if (i < 0 || i > cuoi || v != i.toDouble()) {
                return const SizedBox.shrink();
              }
              return Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  _thangNgan(chuoi[i].thang),
                  style: HD.body(size: 10, color: HD.inkMuted),
                ),
              );
            },
          ),
        ),
      ),
      lineTouchData: LineTouchData(
        touchTooltipData: LineTouchTooltipData(
          getTooltipColor: (_) => HD.ink.withValues(alpha: 0.9),
          getTooltipItems: (diem) => [
            for (final d in diem)
              LineTooltipItem(
                '${_thangNgan(chuoi[d.x.round()].thang)}: ${_phanTram(d.y)}',
                HD.caption(color: Colors.white).copyWith(fontSize: 11),
              ),
          ],
        ),
      ),
      lineBarsData: [
        LineChartBarData(
          spots: [
            for (var i = 0; i < chuoi.length; i++)
              // Tháng chưa có phòng nào → đứt nét, không vẽ thành 0%.
              chuoi[i].tyLe == null
                  ? FlSpot.nullSpot
                  : FlSpot(i.toDouble(), chuoi[i].tyLe!),
          ],
          isCurved: true,
          curveSmoothness: 0.3,
          preventCurveOverShooting: true,
          color: HD.accent,
          barWidth: 2,
          dotData: FlDotData(
            show: true,
            getDotPainter: (_, _, _, i) => FlDotCirclePainter(
              radius: i == cuoi ? 5 : 4,
              color: HD.accent,
              strokeColor: Colors.white,
              strokeWidth: 2,
            ),
          ),
          belowBarData: BarAreaData(
            show: true,
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                HD.accent.withValues(alpha: 0.16),
                HD.accent.withValues(alpha: 0),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _Rong extends StatelessWidget {
  const _Rong({required this.chu, this.nut, this.onNut});

  final String chu;
  final String? nut;
  final VoidCallback? onNut;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: HD.s24),
    child: Column(
      children: [
        Text(
          chu,
          textAlign: TextAlign.center,
          style: HD.body(size: 14, color: HD.inkMuted),
        ),
        if (nut != null) ...[
          const SizedBox(height: HD.s12),
          OutlinedButton(onPressed: onNut, child: Text(nut!)),
        ],
      ],
    ),
  );
}
