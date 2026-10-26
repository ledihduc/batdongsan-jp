import 'package:flutter/material.dart';

import 'package:house_booking/core/widgets/ds.dart';
import 'package:house_booking/data/services/chu_nha_api.dart';
import 'package:house_booking/features/guest/thue_o/ho_so_thue.dart';
import 'package:house_booking/features/host/chu_nha/tao_hop_dong_screen.dart';
import 'package:house_booking/features/host/chu_nha/nha_va_phong_screen.dart';
import 'package:house_booking/features/host/chu_nha/tai_chinh_chu_nha_screen.dart';
import 'package:house_booking/features/host/chu_nha/yeu_cau_tu_sale_screen.dart';
import 'package:house_booking/features/host/chu_nha/widgets/chu_nha_ui.dart';
import 'package:house_booking/features/notifications/notifications_screen.dart';

/// Màn 1 — Tổng quan của chủ nhà (mockup "Góc nhìn Chủ nhà", 04/10/2026). Tab
/// đầu tiên của chủ nhà.
///
/// Lời chào + chuông → 4 ô số (Đang thuê · Phòng trống · Có lịch xem · Sắp
/// trả) → Doanh thu tháng (+% so tháng trước) → "Cần xác nhận": lịch xem chờ
/// duyệt (Từ chối / Xác nhận ngay tại chỗ) và yêu cầu chốt phòng (Xem).
///
/// API: `GET /api/host/chu-nha/tong-quan`.
class TongQuanChuNhaV2Screen extends StatefulWidget {
  const TongQuanChuNhaV2Screen({
    super.key,
    this.api = const ChuNhaApi(),
    this.onXemTaiChinh,
    this.onXemTatCa,
  });

  final ChuNhaApi api;

  /// "Xem chi tiết" doanh thu → tab Tài chính.
  final VoidCallback? onXemTaiChinh;

  /// "Xem tất cả" việc cần xác nhận → tab Hoạt động.
  final VoidCallback? onXemTatCa;

  @override
  State<TongQuanChuNhaV2Screen> createState() => _TongQuanChuNhaV2ScreenState();
}

class _TongQuanChuNhaV2ScreenState extends State<TongQuanChuNhaV2Screen> {
  TongQuanChuNha? _tq;
  String? _loi;

  @override
  void initState() {
    super.initState();
    _nap();
  }

  Future<void> _nap() async {
    try {
      final tq = await widget.api.tongQuan();
      if (mounted) setState(() => (_tq = tq, _loi = null));
    } catch (_) {
      if (mounted) {
        setState(() => _loi = 'Chưa tải được tổng quan. Kéo để thử lại.');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final tq = _tq;
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: RefreshIndicator(
          color: HD.accent,
          onRefresh: _nap,
          child: ListView(
            key: const Key('tong-quan-chu-nha'),
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 24),
            children: [
              _dau(tq),
              const SizedBox(height: 14),
              _loiTat(),
              const SizedBox(height: 16),
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
                _oSo(tq),
                const SizedBox(height: 12),
                _doanhThu(tq),
                const SizedBox(height: 18),
                _canXacNhan(tq),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _mo(Widget man) async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => man));
    if (mounted) _nap();
  }

  void _xemTaiChinh() => widget.onXemTaiChinh != null
      ? widget.onXemTaiChinh!()
      : _mo(TaiChinhChuNhaScreen(api: widget.api, laTab: false));

  void _xemYeuCau() => widget.onXemTatCa != null
      ? widget.onXemTatCa!()
      : _mo(YeuCauTuSaleScreen(api: widget.api, laTab: false));

  /// Lối tắt — chủ nhà dùng chung bộ tab với khách/sale (06/10/2026), nên ba
  /// màn từng là tab riêng nay mở từ đây.
  Widget _loiTat() {
    final o = <(String, IconData, VoidCallback)>[
      (
        'Nhà & phòng',
        Icons.grid_view_rounded,
        () => _mo(NhaVaPhongScreen(api: widget.api, laTab: false)),
      ),
      ('Yêu cầu từ Sale', Icons.hub_outlined, _xemYeuCau),
      ('Tài chính', Icons.request_quote_outlined, _xemTaiChinh),
    ];
    return Row(
      children: [
        for (var i = 0; i < o.length; i++) ...[
          if (i > 0) const SizedBox(width: 10),
          Expanded(
            child: Material(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              child: InkWell(
                key: Key('loi-tat-chu-nha-$i'),
                borderRadius: BorderRadius.circular(14),
                onTap: o[i].$3,
                child: Container(
                  height: 84,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: i == 0 ? HD.accent : kVienCN,
                      width: i == 0 ? 1.5 : 1,
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        o[i].$2,
                        size: 26,
                        color: i == 0 ? HD.accent : HD.ink,
                      ),
                      const SizedBox(height: 6),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: Text(
                            o[i].$1,
                            style: i == 0
                                ? HD.bodyBold(size: 13, color: HD.accent)
                                : HD.body(size: 13, color: HD.inkSoft),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _dau(TongQuanChuNha? tq) => Row(
    children: [
      Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: HD.accentTint,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(Icons.home_rounded, color: HD.accent, size: 26),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Xin chào, ${tq?.ten ?? ''}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: HD.bodyBold(size: 16.5, color: HD.ink),
            ),
            const SizedBox(height: 2),
            phuCN('Chủ nhà · ${tq?.soToa ?? 0} tòa nhà'),
          ],
        ),
      ),
      IconButton(
        key: const Key('chuong-thong-bao'),
        tooltip: 'Thông báo',
        icon: const Icon(Icons.notifications_rounded, color: HD.accent),
        onPressed: () => Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (_) => const NotificationsScreen())),
      ),
    ],
  );

  Widget _oSo(TongQuanChuNha tq) {
    final o = [
      (tq.dangThue, 'Đang thuê', HD.positive, const Color(0xFFEAF7EE)),
      (
        tq.phongTrong,
        'Phòng trống',
        const Color(0xFF8A4B2A),
        const Color(0xFFFBF1EC),
      ),
      (tq.coLichXem, 'Có lịch xem', HD.accent, const Color(0xFFFDECEC)),
      (tq.sapTra, 'Sắp trả', kCamCN, const Color(0xFFFFF4E0)),
    ];
    Widget the(int i) => Expanded(
      child: Container(
        key: Key('o-so-$i'),
        height: 70,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: o[i].$4,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '${o[i].$1}',
              style: HD.bodyBold(size: 22, color: i == 0 ? HD.ink : o[i].$3),
            ),
            Text(o[i].$2, style: HD.body(size: 12.5, color: o[i].$3)),
          ],
        ),
      ),
    );
    return Column(
      children: [
        Row(children: [the(0), const SizedBox(width: 10), the(1)]),
        const SizedBox(height: 10),
        Row(children: [the(2), const SizedBox(width: 10), the(3)]),
      ],
    );
  }

  Widget _doanhThu(TongQuanChuNha tq) {
    final tang = tq.doanhThuTang;
    return TheCN(
      padding: const EdgeInsets.all(14),
      margin: EdgeInsets.zero,
      onTap: _xemTaiChinh,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Doanh thu tháng ${tq.thang}',
            style: HD.body(size: 13, color: HD.ink),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    tienVN(tq.doanhThuThang),
                    style: HD.bodyBold(size: 24, color: HD.positive),
                  ),
                ),
              ),
              if (tang != null)
                NhanCN(
                  '${tang >= 0 ? '+' : ''}${tang.toStringAsFixed(tang % 1 == 0 ? 0 : 1)}%',
                  mau: tang >= 0 ? HD.positive : HD.accent,
                  nen: tang >= 0 ? HD.positiveTint : HD.accentTint,
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text('Xem chi tiết ›', style: HD.body(size: 12.5, color: kXanhDuong)),
        ],
      ),
    );
  }

  Widget _canXacNhan(TongQuanChuNha tq) {
    final ds = tq.canXacNhan;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Cần xác nhận (${ds.length})',
                style: HD.bodyBold(size: 15.5, color: HD.ink),
              ),
            ),
            InkWell(
              key: const Key('xem-tat-ca'),
              onTap: _xemYeuCau,
              child: Text(
                'Xem tất cả ›',
                style: HD.body(size: 12.5, color: HD.accent),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (ds.isEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: kNenCN,
              borderRadius: BorderRadius.circular(12),
            ),
            child: phuCN('Không có việc nào chờ bạn xác nhận.'),
          )
        else
          for (final m in ds.take(5)) _MucCan(m: m, ct: this),
      ],
    );
  }

  Future<void> _tuChoi(LichChuNha m) async {
    final lyDo = await hoiLyDoTuChoi(context, tieuDe: 'Từ chối lịch xem');
    if (lyDo == null || !mounted) return;
    if (await chayCN(
      context,
      () => widget.api.tuChoiLich(m.id, lyDo: lyDo),
      xong: 'Đã từ chối · Sale đã được báo',
    )) {
      _nap();
    }
  }

  Future<void> _xacNhan(LichChuNha m) async {
    if (await chayCN(
      context,
      () => widget.api.duyetLich(m.id),
      xong: 'Đã xác nhận lịch xem',
    )) {
      _nap();
    }
  }

  Future<void> _xem(LichChuNha m) async {
    if (m.laGiaoDich) {
      _xemYeuCau();
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => TaoHopDongScreen(lich: m, api: widget.api),
      ),
    );
    if (mounted) _nap();
  }
}

class _MucCan extends StatelessWidget {
  const _MucCan({required this.m, required this.ct});

  final LichChuNha m;
  final _TongQuanChuNhaV2ScreenState ct;

  @override
  Widget build(BuildContext context) {
    final laLich = m.kieu == 'lich_xem';
    return TheCN(
      key: Key('can-${m.kieu}-${m.id}'),
      padding: const EdgeInsets.all(12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: HD.accentTint,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              laLich ? Icons.event_available_rounded : Icons.home_work_rounded,
              color: HD.accent,
              size: 19,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  laLich ? 'Xác nhận lịch xem' : 'Xác nhận chốt phòng',
                  style: HD.bodyBold(size: 14, color: HD.ink),
                ),
                const SizedBox(height: 3),
                phuCN(m.tenPhong, maxLines: 1),
                phuCN(laLich ? lucHenCN(m) : 'Khách muốn thuê', maxLines: 1),
                if (m.sale != null) phuCN('Sale: ${m.sale!.ten}', maxLines: 1),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: laLich
                      ? Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            NutCN(
                              'Từ chối',
                              key: Key('tu-choi-${m.id}'),
                              onPressed: () => ct._tuChoi(m),
                            ),
                            const SizedBox(width: 8),
                            NutCN(
                              'Xác nhận',
                              key: Key('xac-nhan-${m.id}'),
                              dac: true,
                              onPressed: () => ct._xacNhan(m),
                            ),
                          ],
                        )
                      : NutCN(
                          'Xem',
                          key: Key('xem-chot-${m.id}'),
                          onPressed: () => ct._xem(m),
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
