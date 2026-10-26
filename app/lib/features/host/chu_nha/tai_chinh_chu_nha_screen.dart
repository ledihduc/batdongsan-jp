import 'package:flutter/material.dart';

import 'package:house_booking/core/widgets/ds.dart';
import 'package:house_booking/data/services/chu_nha_api.dart';
import 'package:house_booking/features/guest/thue_o/ho_so_thue.dart';
import 'package:house_booking/features/host/chu_nha/widgets/chu_nha_ui.dart';
import 'package:house_booking/features/host/dien_nuoc/dien_nuoc_dai_han_screen.dart';
import 'package:house_booking/features/host/quan_ly_dai_han/doanh_thu_screen.dart';
import 'package:house_booking/features/host/quan_ly_dai_han/hoa_don_screen.dart';
import 'package:house_booking/features/host/quan_ly_dai_han/hop_dong_screen.dart';
import 'package:house_booking/features/host/quan_ly_dai_han/khach_hang_screen.dart';

/// Tab "Tài chính" của chủ nhà (mockup "Góc nhìn Chủ nhà", 04/10/2026 — khối
/// "Quản lý hóa đơn & thu chi").
///
/// Doanh thu tháng → năm bước thu tiền theo thứ tự làm thật: Nhập chỉ số
/// điện nước → Tạo hóa đơn → Theo dõi thanh toán → Hợp đồng · Khách hàng →
/// Báo cáo doanh thu. Mỗi bước mở màn quản lý theo TOÀ đang chọn.
///
/// API: `GET /api/host/chu-nha/tong-quan` (doanh thu) + `GET /api/host/chu-nha/phong`
/// (danh sách toà).
class TaiChinhChuNhaScreen extends StatefulWidget {
  const TaiChinhChuNhaScreen({
    super.key,
    this.api = const ChuNhaApi(),
    this.laTab = true,
  });

  /// Gốc của tab dưới → không có nút quay lại.
  final bool laTab;

  final ChuNhaApi api;

  @override
  State<TaiChinhChuNhaScreen> createState() => _TaiChinhChuNhaScreenState();
}

class _TaiChinhChuNhaScreenState extends State<TaiChinhChuNhaScreen> {
  TongQuanChuNha? _tq;
  List<({int id, String ten, String diaChi})> _toa = const [];
  int? _chon;
  String? _loi;

  @override
  void initState() {
    super.initState();
    _nap();
  }

  Future<void> _nap() async {
    try {
      final r = await Future.wait([widget.api.tongQuan(), widget.api.phong()]);
      if (!mounted) return;
      final p = r[1] as PhongCuaToa;
      setState(() {
        _tq = r[0] as TongQuanChuNha;
        _toa = p.toa;
        _chon ??= p.toaChon;
        _loi = null;
      });
    } catch (_) {
      if (mounted) {
        setState(() => _loi = 'Chưa tải được số liệu. Kéo để thử lại.');
      }
    }
  }

  ({int id, String ten, String diaChi})? get _toaChon {
    for (final t in _toa) {
      if (t.id == _chon) return t;
    }
    return null;
  }

  void _mo(Widget Function(int id, String ten) man) {
    final t = _toaChon;
    if (t == null) return;
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => man(t.id, t.ten)));
  }

  @override
  Widget build(BuildContext context) {
    final tq = _tq;
    final buoc = [
      (
        Icons.speed_rounded,
        'Nhập chỉ số điện nước',
        'Duyệt ảnh công tơ khách gửi, chốt số tháng',
        () => _mo(
          (id, _) => DienNuocDaiHanScreen(
            toa: [for (final t in _toa) (id: t.id, ten: t.ten)],
            buildingId: id,
          ),
        ),
      ),
      (
        Icons.receipt_long_rounded,
        'Hóa đơn & thanh toán',
        'Tạo hóa đơn, gửi khách, theo dõi đã / chưa thanh toán',
        () => _mo(
          (id, ten) => HoaDonToaScreen(buildingId: id, buildingName: ten),
        ),
      ),
      (
        Icons.description_outlined,
        'Hợp đồng',
        'Hợp đồng đang chạy, sắp hết hạn, chờ gia hạn',
        () => _mo(
          (id, ten) => HopDongToaScreen(buildingId: id, buildingName: ten),
        ),
      ),
      (
        Icons.people_alt_outlined,
        'Khách hàng',
        'Khách đang thuê và công nợ',
        () => _mo(
          (id, ten) => KhachHangToaScreen(buildingId: id, buildingName: ten),
        ),
      ),
      (
        Icons.bar_chart_rounded,
        'Báo cáo doanh thu',
        'Theo tháng / quý',
        () => _mo(
          (id, ten) => DoanhThuToaScreen(buildingId: id, buildingName: ten),
        ),
      ),
    ];
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: appBarCN(context, 'Tài chính', quayLai: !widget.laTab),
      body: RefreshIndicator(
        color: HD.accent,
        onRefresh: _nap,
        child: ListView(
          key: const Key('tai-chinh-chu-nha'),
          padding: const EdgeInsets.fromLTRB(14, 8, 14, 24),
          children: [
            if (tq == null)
              Padding(
                padding: const EdgeInsets.only(top: 80),
                child: Center(
                  child: _loi == null
                      ? const CircularProgressIndicator(color: HD.accent)
                      : phuCN(_loi!),
                ),
              )
            else ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFEAF7EE),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Doanh thu tháng ${tq.thang} (tất cả toà)',
                      style: HD.body(size: 13, color: HD.ink),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      tienVN(tq.doanhThuThang),
                      style: HD.bodyBold(size: 26, color: HD.positive),
                    ),
                    if (tq.doanhThuTang != null)
                      phuCN(
                        '${tq.doanhThuTang! >= 0 ? '+' : ''}'
                        '${tq.doanhThuTang!.toStringAsFixed(1)}% so với tháng trước',
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              if (_toa.length > 1) ...[
                Container(
                  height: 44,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFDDE0E5)),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<int>(
                      value: _chon,
                      isExpanded: true,
                      style: HD.body(size: 14, color: HD.ink),
                      items: [
                        for (final t in _toa)
                          DropdownMenuItem(value: t.id, child: Text(t.ten)),
                      ],
                      onChanged: (v) => setState(() => _chon = v),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
              ],
              Text(
                'Quản lý hóa đơn & thu chi',
                style: HD.bodyBold(size: 15.5, color: HD.ink),
              ),
              const SizedBox(height: 4),
              phuCN(
                _toaChon == null
                    ? 'Bạn chưa quản lý toà nào.'
                    : 'Toà ${_toaChon!.ten} · theo thứ tự thu tiền hằng tháng.',
              ),
              const SizedBox(height: 10),
              for (var i = 0; i < buoc.length; i++)
                TheCN(
                  key: Key('tai-chinh-$i'),
                  onTap: _toaChon == null ? null : buoc[i].$4,
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF4E0),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(buoc[i].$1, color: kCamCN, size: 21),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${i + 1}. ${buoc[i].$2}',
                              style: HD.bodyBold(size: 14, color: HD.ink),
                            ),
                            const SizedBox(height: 2),
                            phuCN(buoc[i].$3),
                          ],
                        ),
                      ),
                      const Icon(
                        Icons.chevron_right_rounded,
                        color: HD.inkSoft,
                      ),
                    ],
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}
