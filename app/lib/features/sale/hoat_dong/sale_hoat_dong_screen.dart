import 'package:flutter/material.dart';

import 'package:house_booking/core/widgets/ds.dart';
import 'package:house_booking/data/services/sale_van_hanh_api.dart';
import 'package:house_booking/features/sale/hoat_dong/bai_dang_cua_toi_screen.dart';
import 'package:house_booking/features/sale/hoat_dong/can_xu_ly_sale_screen.dart';
import 'package:house_booking/features/sale/hoat_dong/don_lich_xem_screen.dart';
import 'package:house_booking/features/sale/hoat_dong/hop_dong_sale_screen.dart';
import 'package:house_booking/features/sale/hoat_dong/khach_hang_sale_screen.dart';
import 'package:house_booking/features/sale/hoat_dong/quan_ly_sale_screen.dart';
import 'package:house_booking/features/sale/hoat_dong/widgets/dong_viec_sale.dart';
import 'package:house_booking/features/sale/hoat_dong/widgets/sale_ui.dart';

/// Màn 2 — tab "Hoạt động" của SALE (mockup 05/10/2026).
///
/// Công tắc Ngắn hạn | Dài hạn → bốn ô lối tắt (Quản lý · Lịch xem · Khách
/// hàng · Hợp đồng) → "Tổng quan" bốn con số → "Cần xử lý hôm nay".
/// Tab của shell, không có nút quay lại. API: `GET /api/sale/van-hanh/tong-quan`.
class SaleHoatDongScreen extends StatefulWidget {
  const SaleHoatDongScreen({super.key, this.api = const SaleVanHanhApi()});

  final SaleVanHanhApi api;

  @override
  State<SaleHoatDongScreen> createState() => _SaleHoatDongScreenState();
}

class _SaleHoatDongScreenState extends State<SaleHoatDongScreen> {
  String _kenh = kKenhDaiHan;
  int _lan = 0;

  bool get _ngan => _kenh == kKenhNganHan;

  Future<void> _mo(Widget man) async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => man));
    if (mounted) setState(() => _lan++);
  }

  @override
  Widget build(BuildContext context) {
    final api = widget.api;
    return TrangSale(
      tieuDe: 'Hoạt động',
      coNutLui: false,
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 14),
            child: CongTacHaiO(
              trai: 'Ngắn hạn',
              phai: 'Dài hạn',
              chonTrai: _ngan,
              khoaTrai: const Key('kenh-ngan-han'),
              khoaPhai: const Key('kenh-dai-han'),
              onChon: (trai) =>
                  setState(() => _kenh = trai ? kKenhNganHan : kKenhDaiHan),
            ),
          ),
          Expanded(
            child: TaiSale<TongQuanVanHanh>(
              khoaTai: '$_kenh-$_lan',
              tai: () => api.tongQuan(_kenh),
              dung: (context, d, taiLai) => RefreshIndicator(
                color: HD.accent,
                onRefresh: taiLai,
                child: ListView(
                  key: const Key('sale-hoat-dong'),
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  children: [
                    _loiTat(api),
                    const SizedBox(height: 22),
                    Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: 'Tổng quan',
                            style: HD.bodyBold(size: 20, color: HD.ink),
                          ),
                          TextSpan(
                            text: ' (${nhanKenh(_kenh)})',
                            style: HD.body(size: 18, color: HD.ink),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    _oSo(d.so, api),
                    const SizedBox(height: 22),
                    Row(
                      children: [
                        Expanded(
                          child: Text.rich(
                            TextSpan(
                              children: [
                                TextSpan(
                                  text: 'Cần xử lý hôm nay',
                                  style: HD.bodyBold(size: 18, color: HD.ink),
                                ),
                                TextSpan(
                                  text: ' (${d.canXuLy.length})',
                                  style: HD.body(size: 17, color: HD.ink),
                                ),
                              ],
                            ),
                          ),
                        ),
                        if (d.canXuLy.isNotEmpty)
                          TextButton(
                            key: const Key('xem-tat-ca-viec'),
                            style: TextButton.styleFrom(foregroundColor: HD.accent),
                            onPressed: () =>
                                _mo(CanXuLySaleScreen(kenh: _kenh, api: api)),
                            child: Text(
                              'Xem tất cả',
                              style: HD.bodyBold(size: 14, color: HD.accent),
                            ),
                          ),
                      ],
                    ),
                    if (d.canXuLy.isEmpty)
                      const RongSale(
                        chu: 'Hôm nay chưa có việc nào cần xử lý.',
                        icon: Icons.task_alt_rounded,
                      )
                    else
                      for (var i = 0; i < d.canXuLy.length && i < 4; i++) ...[
                        if (i > 0) Divider(height: 1, color: SaleMau.vien),
                        DongViecSale(
                          v: d.canXuLy[i],
                          onTap: () async {
                            await moViecSale(context, d.canXuLy[i], _kenh, api: api);
                            if (mounted) setState(() => _lan++);
                          },
                        ),
                      ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _loiTat(SaleVanHanhApi api) {
    final o = <(String, IconData, Widget Function(), bool)>[
      ('Quản lý', Icons.work_outline_rounded, () => QuanLySaleScreen(kenh: _kenh, api: api), true),
      (
        _ngan ? 'Đơn đặt' : 'Lịch xem',
        Icons.calendar_month_outlined,
        () => DonLichXemScreen(kenh: _kenh, api: api),
        false,
      ),
      ('Khách hàng', Icons.people_alt_outlined, () => KhachHangSaleScreen(kenh: _kenh, api: api), false),
      ('Hợp đồng', Icons.description_outlined, () => HopDongSaleScreen(kenh: _kenh, api: api), false),
    ];
    return Row(
      children: [
        for (var i = 0; i < o.length; i++) ...[
          if (i > 0) const SizedBox(width: 10),
          Expanded(
            child: AspectRatio(
              aspectRatio: 0.98,
              child: Material(
                color: SaleMau.nen,
                borderRadius: BorderRadius.circular(14),
                child: InkWell(
                  key: Key('loi-tat-${o[i].$1}'),
                  borderRadius: BorderRadius.circular(14),
                  onTap: () => _mo(o[i].$3()),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: o[i].$4 ? HD.accent : SaleMau.vien,
                        width: o[i].$4 ? 1.5 : 1,
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(o[i].$2, size: 28, color: o[i].$4 ? HD.accent : HD.ink),
                        const SizedBox(height: 8),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: Text(
                              o[i].$1,
                              style: o[i].$4
                                  ? HD.bodyBold(size: 13.5, color: HD.accent)
                                  : HD.body(size: 13.5, color: HD.inkSoft),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _oSo(SoTongQuan so, SaleVanHanhApi api) {
    final o = <(int, String, Color, Color, Widget Function())>[
      (so.baiDang, 'Bài đăng', SaleMau.xanh, SaleMau.xanhNen, () => BaiDangCuaToiScreen(kenh: _kenh, api: api)),
      (so.khachMoi, 'Khách mới', SaleMau.lam, SaleMau.lamNhat, () => KhachHangSaleScreen(kenh: _kenh, api: api)),
      (
        so.lichXem,
        _ngan ? 'Đơn đặt' : 'Lịch xem',
        HD.accent,
        HD.accentTint,
        () => DonLichXemScreen(kenh: _kenh, api: api),
      ),
      (
        so.choChot,
        _ngan ? 'Chờ xác nhận' : 'Chờ chốt',
        SaleMau.camDam,
        SaleMau.camNen,
        () => _ngan
            ? DonLichXemScreen(kenh: _kenh, api: api, locBanDau: 'cho_chu_xac_nhan')
            : HopDongSaleScreen(kenh: _kenh, api: api),
      ),
    ];
    return Row(
      children: [
        for (var i = 0; i < o.length; i++) ...[
          if (i > 0) const SizedBox(width: 8),
          Expanded(
            child: Material(
              color: o[i].$4,
              borderRadius: BorderRadius.circular(12),
              child: InkWell(
                key: Key('o-so-$i'),
                borderRadius: BorderRadius.circular(12),
                onTap: () => _mo(o[i].$5()),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 14, 8, 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${o[i].$1}', style: HD.bodyBold(size: 22, color: o[i].$3)),
                      const SizedBox(height: 4),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(o[i].$2, style: HD.body(size: 12.5, color: o[i].$3)),
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
}
