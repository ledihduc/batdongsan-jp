import 'package:flutter/material.dart';

import 'package:house_booking/core/widgets/ds.dart';
import 'package:house_booking/data/services/so_chu_nha_api.dart';
import 'package:house_booking/features/host/so_chu_nha/tao_hoa_don_screen.dart';
import 'package:house_booking/features/host/so_chu_nha/thu_tien_screen.dart';
import 'package:house_booking/features/host/so_chu_nha/widgets/so_ui.dart';

/// Màn 7 — "Thu chi – Phòng 201": tab Thu tiền | Chi phí.
///
/// Thu tiền: Đã thu / Còn phải thu → "Lịch thu tiền" (Chưa thu / Đã thu).
/// Chi phí: tổng chi + sổ sửa chữa có tiền. Đáy: Thu tiền / Tạo hóa đơn.
/// API: `GET /api/host/so-chu-nha/phong/{id}/thu-chi`.
class ThuChiPhongScreen extends StatefulWidget {
  const ThuChiPhongScreen({super.key, required this.roomId, this.api = const SoChuNhaApi()});

  final int roomId;
  final SoChuNhaApi api;

  @override
  State<ThuChiPhongScreen> createState() => _ThuChiPhongScreenState();
}

class _ThuChiPhongScreenState extends State<ThuChiPhongScreen> {
  int _tab = 0;
  int _lan = 0;
  ThuChiPhongCN? _d;

  Future<void> _day(Widget man) async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => man));
    if (mounted) setState(() => _lan++);
  }

  @override
  Widget build(BuildContext context) {
    final d = _d;
    return ManCN(
      tieuDe: d == null ? 'Thu chi' : 'Thu chi – ${d.tenPhong}',
      day: d != null && d.coHopDong
          ? HaiNutCN(
              trai: NutCN(
                'Thu tiền',
                key: const Key('cn-nut-thu-tien'),
                kieu: KieuNutCN.vien,
                onPressed: () => _day(ThuTienScreen(roomId: widget.roomId, api: widget.api)),
              ),
              phai: NutCN(
                'Tạo hóa đơn',
                key: const Key('cn-nut-tao-hoa-don'),
                onPressed: () => _day(TaoHoaDonScreen(roomId: widget.roomId, api: widget.api)),
              ),
            )
          : null,
      body: Column(
        children: [
          TabCN(tab: const ['Thu tiền', 'Chi phí'], chon: _tab, onChon: (i) => setState(() => _tab = i)),
          Expanded(
            child: TaiCN<ThuChiPhongCN>(
              khoaTai: _lan,
              tai: () async {
                final d = await widget.api.thuChi(widget.roomId);
                if (mounted && _d == null) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted) setState(() => _d = d);
                  });
                }
                _d = d;
                return d;
              },
              dung: (context, d, taiLai) => RefreshIndicator(
                color: HD.accent,
                onRefresh: taiLai,
                child: _tab == 0 ? _thu(d) : _chi(d),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _oTong(String nhan, double tien, Color mau, Color nen, IconData icon) => Expanded(
    child: Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: nen, borderRadius: BorderRadius.circular(14)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: mau),
              const SizedBox(width: 6),
              Text(nhan, style: HD.body(size: 13, color: HD.inkSoft)),
            ],
          ),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(tienCN(tien), style: HD.bodyBold(size: 19, color: mau)),
          ),
        ],
      ),
    ),
  );

  Widget _thu(ThuChiPhongCN d) {
    return ListView(
      key: const Key('cn-thu-chi-thu'),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        Row(
          children: [
            _oTong('Đã thu', d.daThu, MauCN.xanh, MauCN.xanhNen, Icons.check_circle_outline_rounded),
            const SizedBox(width: 12),
            _oTong('Còn phải thu', d.conPhaiThu, HD.accent, HD.accentTint, Icons.schedule_rounded),
          ],
        ),
        const SizedBox(height: 20),
        const TieuDeKhoiCN('Lịch thu tiền'),
        if (d.lichThu.isEmpty) const RongCN('Chưa có kỳ thu nào.', icon: Icons.receipt_long_outlined),
        for (final k in d.lichThu)
          TheCN(
            key: Key('cn-ky-${k.ky}'),
            margin: const EdgeInsets.only(bottom: 10),
            onTap: d.coHopDong
                ? () => _day(ThuTienScreen(roomId: widget.roomId, thang: k.ky, api: widget.api))
                : null,
            child: Row(
              children: [
                OIconCN(
                  k.trangThai == 'da_thu' ? Icons.task_alt_rounded : Icons.receipt_long_outlined,
                  mau: k.trangThai == 'da_thu' ? MauCN.xanh : HD.accent,
                  nen: k.trangThai == 'da_thu' ? MauCN.xanhNen : HD.accentTint,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(kyCN(k.ky), style: HD.bodyBold(size: 15, color: HD.ink)),
                      const SizedBox(height: 2),
                      Text(
                        k.invoiceId == null ? 'Hạn ${ngayCN(k.han)} · chưa lập hóa đơn' : 'Hạn ${ngayCN(k.han)}',
                        style: HD.body(size: 12.5, color: HD.inkMuted),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(tienCN(k.tong), style: HD.bodyBold(size: 14.5, color: HD.ink)),
                    const SizedBox(height: 4),
                    NhanCN.trangThai(k.trangThai),
                  ],
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _chi(ThuChiPhongCN d) {
    return ListView(
      key: const Key('cn-thu-chi-chi'),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        Row(
          children: [
            _oTong('Tổng chi phí', d.tongChi, MauCN.cam, MauCN.camNen, Icons.build_outlined),
          ],
        ),
        const SizedBox(height: 20),
        const TieuDeKhoiCN('Khoản chi'),
        if (d.chiPhi.isEmpty)
          const RongCN('Chưa có khoản chi nào cho phòng này.', icon: Icons.build_circle_outlined),
        for (final c in d.chiPhi)
          TheCN(
            margin: const EdgeInsets.only(bottom: 10),
            child: Row(
              children: [
                const OIconCN(Icons.handyman_outlined, mau: MauCN.cam, nen: MauCN.camNen),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(c.tieuDe, style: HD.bodyBold(size: 15, color: HD.ink)),
                      const SizedBox(height: 2),
                      Text(ngayCN(c.ngay), style: HD.body(size: 12.5, color: HD.inkMuted)),
                    ],
                  ),
                ),
                Text('-${tienCN(c.soTien)}', style: HD.bodyBold(size: 14.5, color: HD.accent)),
              ],
            ),
          ),
      ],
    );
  }
}
