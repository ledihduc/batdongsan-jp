import 'package:flutter/material.dart';

import 'package:house_booking/core/widgets/ds.dart';
import 'package:house_booking/data/services/so_chu_nha_api.dart';
import 'package:house_booking/features/host/so_chu_nha/widgets/so_ui.dart';
import 'package:house_booking/features/host/so_chu_nha/widgets/the_dong_tien.dart';

/// Màn 9 — TẠO HÓA ĐƠN của một phòng.
///
/// Kỳ tháng → các dòng tiền (cùng hàm với hoá đơn thật) → Tổng tiền → đáy:
/// "Xem trước" (bản hoá đơn như khách nhận) / "Tạo hóa đơn" (lập + gửi khách).
/// API: `GET /api/host/so-chu-nha/phong/{id}/thu-tien`, `POST …/hoa-don`.
class TaoHoaDonScreen extends StatefulWidget {
  const TaoHoaDonScreen({super.key, required this.roomId, this.api = const SoChuNhaApi()});

  final int roomId;
  final SoChuNhaApi api;

  @override
  State<TaoHoaDonScreen> createState() => _TaoHoaDonScreenState();
}

class _TaoHoaDonScreenState extends State<TaoHoaDonScreen> {
  String? _thang;
  KyThuCN? _ky;
  Object? _loi;
  bool _dang = false;

  @override
  void initState() {
    super.initState();
    _tai();
  }

  Future<void> _tai() async {
    setState(() => _loi = null);
    try {
      final k = await widget.api.kyThu(widget.roomId, thang: _thang);
      if (mounted) setState(() => _ky = k);
    } catch (e) {
      if (mounted) setState(() => _loi = e);
    }
  }

  Future<void> _tao(KyThuCN k) async {
    setState(() => _dang = true);
    try {
      final moi = await widget.api.taoHoaDon(widget.roomId, k.thang);
      if (!mounted) return;
      setState(() {
        _ky = moi;
        _dang = false;
      });
      baoCN(context, 'Đã tạo và gửi hóa đơn ${kyCN(k.thang).toLowerCase()}');
    } catch (e) {
      if (!mounted) return;
      setState(() => _dang = false);
      baoCN(context, loiCN(e), loi: true);
    }
  }

  void _xemTruoc(KyThuCN k) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: MauCN.the,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.75,
        maxChildSize: 0.95,
        builder: (context, cuon) => ListView(
          key: const Key('cn-xem-truoc-hoa-don'),
          controller: cuon,
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
          children: [
            Center(child: Text('HÓA ĐƠN TIỀN PHÒNG', style: HD.bodyBold(size: 17, color: HD.ink))),
            const SizedBox(height: 4),
            Center(
              child: Text(
                '${k.tenPhong} · ${kyCN(k.thang)}',
                style: HD.body(size: 14, color: HD.inkMuted),
              ),
            ),
            if (k.han != null)
              Center(child: Text('Hạn thanh toán ${ngayCN(k.han)}', style: HD.body(size: 13, color: HD.inkMuted))),
            const SizedBox(height: 18),
            TheDongTienCN(ky: k),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final k = _ky;
    final daCo = k?.daCoHoaDon == true;
    return ManCN(
      tieuDe: 'Tạo hóa đơn',
      day: k == null
          ? null
          : HaiNutCN(
              trai: NutCN(
                'Xem trước',
                key: const Key('cn-xem-truoc'),
                kieu: KieuNutCN.vien,
                onPressed: () => _xemTruoc(k),
              ),
              phai: NutCN(
                daCo ? 'Đã tạo' : 'Tạo hóa đơn',
                key: const Key('cn-tao-hoa-don'),
                dangChay: _dang,
                onPressed: daCo ? null : () => _tao(k),
              ),
            ),
      body: k == null
          ? (_loi != null
                ? RongCN(loiCN(_loi!), icon: Icons.cloud_off_rounded)
                : const Center(child: CircularProgressIndicator(color: HD.accent)))
          : ListView(
              key: const Key('cn-tao-hoa-don-noi-dung'),
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              children: [
                Text(k.tenPhong, style: HD.bodyBold(size: 18, color: HD.ink)),
                const SizedBox(height: 14),
                OChonKyCN(
                  nhan: 'Kỳ tháng',
                  ky: k.thang,
                  cacKy: k.kyChon,
                  onChon: (t) {
                    _thang = t;
                    _tai();
                  },
                ),
                const SizedBox(height: 16),
                if (daCo)
                  Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: MauCN.lamNen,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.info_outline_rounded, color: MauCN.lam, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Hóa đơn kỳ này đã gửi cho khách — ${k.trangThai == 'da_thu' ? 'đã thu đủ' : 'chờ thu'}.',
                            style: HD.bodyBold(size: 13.5, color: MauCN.lam),
                          ),
                        ),
                      ],
                    ),
                  ),
                TheDongTienCN(ky: k),
                const SizedBox(height: 10),
                Text(
                  'Điện nước tính theo chỉ số đã chốt. Hóa đơn tạo xong sẽ gửi ngay cho người thuê.',
                  style: HD.body(size: 12.5, color: HD.inkMuted),
                ),
              ],
            ),
    );
  }
}
