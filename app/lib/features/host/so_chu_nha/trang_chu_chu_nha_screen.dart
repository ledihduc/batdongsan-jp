import 'package:flutter/material.dart';

import 'package:house_booking/core/widgets/ds.dart';
import 'package:house_booking/data/services/so_chu_nha_api.dart';
import 'package:house_booking/features/guest/short_stay/short_stay_bookings_screen.dart';
import 'package:house_booking/features/guest/short_stay/short_stay_operations_role.dart';
import 'package:house_booking/features/host/so_chu_nha/thu_chi_tong_screen.dart';
import 'package:house_booking/features/host/so_chu_nha/toa_nha_cua_toi_screen.dart';
import 'package:house_booking/features/host/so_chu_nha/widgets/so_ui.dart';
import 'package:house_booking/features/notifications/notifications_screen.dart';

/// Màn 1 + 14 — TRANG CHỦ của chủ nhà (mockup 06/10/2026), tab đầu tiên.
///
/// Lời chào + chuông → công tắc Dài hạn | Ngắn hạn → thẻ đỏ "Tổng quan" →
/// Doanh thu tháng (↑%) → Dài hạn: "Việc cần chú ý"; Ngắn hạn: khối "Hôm nay".
/// API: `GET /api/host/so-chu-nha/trang-chu?kenh=`.
class TrangChuChuNhaScreen extends StatefulWidget {
  const TrangChuChuNhaScreen({
    super.key,
    this.api = const SoChuNhaApi(),
    this.onMoToaNha,
    this.onMoThuChi,
    this.moDonNganHan,
  });

  final SoChuNhaApi api;

  /// Mở hộp đơn ngắn hạn với bộ lọc sẵn — test tiêm vào để khỏi dựng màn thật.
  final Future<void> Function(BuildContext context, {required String loc, required bool homNay})?
      moDonNganHan;

  /// Nhảy sang tab "Tòa nhà" / "Thu chi" của shell.
  final VoidCallback? onMoToaNha;
  final VoidCallback? onMoThuChi;

  @override
  State<TrangChuChuNhaScreen> createState() => _TrangChuChuNhaScreenState();
}

class _TrangChuChuNhaScreenState extends State<TrangChuChuNhaScreen> {
  String _kenh = kDaiHan;

  bool get _ngan => _kenh == kNganHan;
  int _lan = 0;

  /// Mở Tòa nhà / Thu chi: shell truyền callback thì nhảy tab, không thì push
  /// ngay trong tab Hoạt động (chủ nhà dùng chung bộ tab với khách/sale).
  Future<void> _moToaNha() async {
    if (widget.onMoToaNha != null) {
      widget.onMoToaNha!();
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => ToaNhaCuaToiScreen(api: widget.api, laTab: false)),
    );
    if (mounted) setState(() => _lan++);
  }

  Future<void> _moThuChi() async {
    if (widget.onMoThuChi != null) {
      widget.onMoThuChi!();
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => ThuChiTongScreen(api: widget.api, laTab: false)),
    );
    if (mounted) setState(() => _lan++);
  }

  /// Ô số đếm / việc ngắn hạn → hộp đơn đã lọc đúng thứ vừa bấm. Trước đây
  /// các ô này chỉ là con số: chủ nhà thấy "2 đơn chờ" mà không bấm vào duyệt
  /// được, phải đi năm chạm qua Cài đặt.
  Future<void> _moDon({required String loc, required bool homNay}) async {
    if (widget.moDonNganHan != null) {
      await widget.moDonNganHan!(context, loc: loc, homNay: homNay);
    } else {
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ShortStayBookingsScreen(
            operations: true,
            operationsRole: ShortStayOperationsRole.owner,
            locBanDau: loc,
            homNayBanDau: homNay,
          ),
        ),
      );
    }
    if (mounted) setState(() => _lan++);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MauCN.nen,
      body: SafeArea(
        bottom: false,
        child: TaiCN<TrangChuCN>(
          khoaTai: '$_kenh-$_lan',
          tai: () => widget.api.trangChu(_kenh),
          dung: (context, d, taiLai) => RefreshIndicator(
            color: HD.accent,
            onRefresh: taiLai,
            child: ListView(
              key: const Key('cn-trang-chu'),
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
              children: [
                _loiChao(d.ten),
                const SizedBox(height: 16),
                CongTacCN(
                  cacO: const ['Dài hạn', 'Ngắn hạn'],
                  chon: _ngan ? 1 : 0,
                  khoa: const [Key('cn-dai-han'), Key('cn-ngan-han')],
                  onChon: (i) => setState(() => _kenh = i == 1 ? kNganHan : kDaiHan),
                ),
                const SizedBox(height: 12),
                _loiTat(),
                const SizedBox(height: 14),
                _theTongQuan(d),
                const SizedBox(height: 14),
                if (_ngan) ...[_homNay(d), const SizedBox(height: 14)],
                _doanhThu(d),
                const SizedBox(height: 22),
                const TieuDeKhoiCN('Việc cần chú ý'),
                for (final v in d.viec) _dongViec(v),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _loiChao(String ten) {
    final ngan = ten.trim().isEmpty ? '' : ten.trim().split(' ').last;
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                ngan.isEmpty ? 'Xin chào 👋' : 'Xin chào, $ngan 👋',
                style: HD.bodyBold(size: 22, color: HD.ink),
              ),
              const SizedBox(height: 3),
              Text(
                'Chúc bạn một ngày làm việc hiệu quả',
                style: HD.body(size: 13.5, color: HD.inkMuted),
              ),
            ],
          ),
        ),
        Material(
          color: MauCN.the,
          shape: const CircleBorder(),
          child: InkWell(
            key: const Key('cn-chuong'),
            customBorder: const CircleBorder(),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const NotificationsScreen()),
            ),
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: MauCN.vien),
              ),
              child: const Icon(Icons.notifications_none_rounded, color: HD.ink),
            ),
          ),
        ),
      ],
    );
  }

  Widget _loiTat() {
    Widget o(String chu, IconData icon, Key khoa, VoidCallback onTap) => Expanded(
      child: TheCN(
        key: khoa,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        onTap: onTap,
        child: Row(
          children: [
            OIconCN(icon, mau: HD.accent, nen: HD.accentTint, co: 36),
            const SizedBox(width: 10),
            Expanded(child: Text(chu, style: HD.bodyBold(size: 14.5, color: HD.ink))),
            const Icon(Icons.chevron_right_rounded, color: HD.inkMuted, size: 20),
          ],
        ),
      ),
    );
    return Row(
      children: [
        o('Tòa nhà', Icons.apartment_rounded, const Key('cn-mo-toa-nha'), _moToaNha),
        const SizedBox(width: 10),
        o('Thu chi', Icons.account_balance_wallet_outlined, const Key('cn-mo-thu-chi'), _moThuChi),
      ],
    );
  }

  Widget _theTongQuan(TrangChuCN d) {
    final so = d.so;
    final o = _ngan
        ? <(String, int)>[
            ('Tòa nhà', so['toa_nha'] ?? 0),
            ('Phòng', so['phong'] ?? 0),
            ('Đang cho thuê', so['dang_cho_thue'] ?? 0),
          ]
        : <(String, int)>[
            ('Tòa nhà', so['toa_nha'] ?? 0),
            ('Phòng', so['phong'] ?? 0),
            ('Đang thuê', so['dang_thue'] ?? 0),
            ('Sắp thu tiền', so['sap_thu_tien'] ?? 0),
            ('Sắp hết hạn', so['sap_het_han'] ?? 0),
            ('Phòng trống', so['phong_trong'] ?? 0),
          ];
    return GestureDetector(
      key: const Key('cn-tong-quan'),
      onTap: _moToaNha,
      child: Container(
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [HD.accent, HD.accentDeep],
          ),
          boxShadow: [
            BoxShadow(color: HD.accent.withValues(alpha: 0.28), blurRadius: 16, offset: const Offset(0, 6)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _ngan ? 'Tổng quan ngắn hạn' : 'Tổng quan dài hạn',
              style: HD.bodyBold(size: 16, color: HD.paperRaised),
            ),
            const SizedBox(height: 10),
            for (var hang = 0; hang < o.length; hang += 3)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  children: [
                    for (var i = hang; i < hang + 3 && i < o.length; i++)
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.only(left: 10),
                          decoration: BoxDecoration(
                            border: i % 3 == 0
                                ? null
                                : Border(
                                    left: BorderSide(
                                      color: HD.paperRaised.withValues(alpha: 0.25),
                                    ),
                                  ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${o[i].$2}',
                                key: Key('cn-so-$i'),
                                style: HD.bodyBold(size: 24, color: HD.paperRaised),
                              ),
                              const SizedBox(height: 2),
                              FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  o[i].$1,
                                  style: HD.body(
                                    size: 12.5,
                                    color: HD.paperRaised.withValues(alpha: 0.88),
                                  ),
                                ),
                              ),
                            ],
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
  }

  Widget _homNay(TrangChuCN d) {
    final h = d.homNay;
    final o = <(String, int, IconData, Color, Color)>[
      ('Đã đặt', h['da_dat'] ?? 0, Icons.event_available_outlined, MauCN.lam, MauCN.lamNen),
      ('Đang ở', h['dang_o'] ?? 0, Icons.hotel_outlined, MauCN.xanh, MauCN.xanhNen),
      ('Sắp trả', h['sap_tra'] ?? 0, Icons.logout_rounded, MauCN.cam, MauCN.camNen),
    ];
    // "Đang ở" lấy MỌI ngày: khách quá giờ từ hôm qua vẫn đang trong phòng.
    final moO = <VoidCallback>[
      () => _moDon(loc: 'all', homNay: true),
      () => _moDon(loc: 'staying', homNay: false),
      () => _moDon(loc: 'staying', homNay: true),
    ];
    return TheCN(
      key: const Key('cn-hom-nay'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Hôm nay', style: HD.bodyBold(size: 16, color: HD.ink)),
          const SizedBox(height: 12),
          Row(
            children: [
              for (var i = 0; i < o.length; i++) ...[
                if (i > 0) const SizedBox(width: 10),
                Expanded(
                  child: Material(
                    color: o[i].$5,
                    borderRadius: BorderRadius.circular(12),
                    child: InkWell(
                    key: Key('cn-hom-nay-$i'),
                    borderRadius: BorderRadius.circular(12),
                    onTap: moO[i],
                    child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
                    child: Column(
                      children: [
                        Icon(o[i].$3, color: o[i].$4, size: 22),
                        const SizedBox(height: 6),
                        Text('${o[i].$2}', style: HD.bodyBold(size: 20, color: o[i].$4)),
                        Text(o[i].$1, style: HD.body(size: 12.5, color: HD.inkSoft)),
                      ],
                    ),
                    ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _doanhThu(TrangChuCN d) {
    final p = d.tangPhanTram;
    final tang = p != null && p >= 0;
    return TheCN(
      key: const Key('cn-doanh-thu'),
      onTap: _ngan ? null : _moThuChi,
      child: Row(
        children: [
          const OIconCN(Icons.account_balance_wallet_outlined, mau: HD.accent, nen: HD.accentTint, co: 46),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Doanh thu tháng ${d.thang}', style: HD.body(size: 13.5, color: HD.inkMuted)),
                const SizedBox(height: 4),
                Text(tienCN(d.doanhThu), style: HD.bodyBold(size: 22, color: HD.ink)),
              ],
            ),
          ),
          if (p != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
              decoration: BoxDecoration(
                color: tang ? MauCN.xanhNen : HD.accentTint,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    tang ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
                    size: 15,
                    color: tang ? MauCN.xanh : HD.accent,
                  ),
                  Text(
                    '${p.abs().toStringAsFixed(p.abs() >= 10 ? 0 : 1)}%',
                    style: HD.bodyBold(size: 13, color: tang ? MauCN.xanh : HD.accent),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _dongViec(ViecCN v) {
    final (icon, mau, nen) = switch (v.loai) {
      'sap_thu' => (Icons.payments_outlined, MauCN.cam, MauCN.camNen),
      'sap_het_han' => (Icons.description_outlined, HD.accent, HD.accentTint),
      'trong_lau' => (Icons.meeting_room_outlined, MauCN.lam, MauCN.lamNen),
      'cho_xac_nhan' => (Icons.pending_actions_outlined, MauCN.cam, MauCN.camNen),
      'sap_tra' => (Icons.logout_rounded, HD.accent, HD.accentTint),
      'thieu_giay_to' => (Icons.warning_amber_rounded, MauCN.cam, MauCN.camNen),
      _ => (Icons.bed_outlined, MauCN.xanh, MauCN.xanhNen),
    };
    final mo = switch (v.loai) {
      'sap_thu' => _moThuChi,
      'cho_xac_nhan' => () => _moDon(loc: 'pending', homNay: false),
      'sap_tra' when _ngan => () => _moDon(loc: 'staying', homNay: true),
      _ => _moToaNha,
    };
    return TheCN(
      key: Key('cn-viec-${v.loai}'),
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      onTap: mo,
      child: Row(
        children: [
          OIconCN(icon, mau: mau, nen: nen),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(v.tieuDe, style: HD.bodyBold(size: 15, color: HD.ink)),
                const SizedBox(height: 2),
                Text(v.phu, style: HD.body(size: 13, color: HD.inkMuted)),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded, color: HD.inkMuted),
        ],
      ),
    );
  }
}
