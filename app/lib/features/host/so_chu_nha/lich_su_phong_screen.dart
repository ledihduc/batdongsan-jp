import 'package:flutter/material.dart';

import 'package:house_booking/core/widgets/ds.dart';
import 'package:house_booking/data/services/so_chu_nha_api.dart';
import 'package:house_booking/features/host/so_chu_nha/widgets/so_ui.dart';

/// Màn 11 — LỊCH SỬ PHÒNG: tab Biến động · Hợp đồng · Hóa đơn · Điện nước,
/// mỗi tab là một dòng thời gian (chấm màu + đường nối), mới nhất trên cùng.
/// API: `GET /api/host/so-chu-nha/phong/{id}/lich-su`.
class LichSuPhongScreen extends StatefulWidget {
  const LichSuPhongScreen({super.key, required this.roomId, this.api = const SoChuNhaApi()});

  final int roomId;
  final SoChuNhaApi api;

  @override
  State<LichSuPhongScreen> createState() => _LichSuPhongScreenState();
}

class _LichSuPhongScreenState extends State<LichSuPhongScreen> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    return ManCN(
      tieuDe: 'Lịch sử phòng',
      body: Column(
        children: [
          TabCN(
            tab: const ['Biến động', 'Hợp đồng', 'Hóa đơn', 'Điện nước'],
            chon: _tab,
            onChon: (i) => setState(() => _tab = i),
          ),
          Expanded(
            child: TaiCN<LichSuPhongCN>(
              tai: () => widget.api.lichSu(widget.roomId),
              dung: (context, d, taiLai) {
                final ds = switch (_tab) {
                  1 => d.hopDong,
                  2 => d.hoaDon,
                  3 => d.dienNuoc,
                  _ => d.bienDong,
                };
                return RefreshIndicator(
                  color: HD.accent,
                  onRefresh: taiLai,
                  child: ListView(
                    key: Key('cn-lich-su-$_tab'),
                    padding: const EdgeInsets.fromLTRB(16, 18, 16, 24),
                    children: [
                      if (ds.isEmpty) const RongCN('Chưa có sự kiện nào.', icon: Icons.history_rounded),
                      for (var i = 0; i < ds.length; i++) _moc(ds[i], cuoi: i == ds.length - 1),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _moc(SuKienCN s, {required bool cuoi}) {
    final (icon, mau) = switch (s.loai) {
      'hop_dong' => (Icons.description_outlined, HD.accent),
      'gia_han' => (Icons.update_rounded, MauCN.xanh),
      'ket_thuc' => (Icons.logout_rounded, MauCN.xam),
      'hoa_don' => (Icons.receipt_long_outlined, MauCN.lam),
      'thu_tien' => (Icons.payments_outlined, MauCN.xanh),
      'dien_nuoc' => (Icons.bolt_rounded, MauCN.cam),
      'sua_chua' => (Icons.handyman_outlined, MauCN.tim),
      _ => (Icons.add_home_outlined, HD.inkMuted),
    };
    // Chỉ in NGÀY: mốc giờ server lưu theo UTC không kèm múi, in giờ ra là lệch 7 tiếng.
    final ngay = s.luc == null ? '' : ngayCN(s.luc);
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 36,
            child: Column(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(color: mau.withValues(alpha: 0.12), shape: BoxShape.circle),
                  child: Icon(icon, size: 17, color: mau),
                ),
                if (!cuoi)
                  Expanded(child: Container(width: 2, color: HD.hairline.withValues(alpha: 0.7))),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 18, top: 2),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(ngay, style: HD.body(size: 12.5, color: HD.inkMuted)),
                  const SizedBox(height: 2),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: Text(s.tieuDe, style: HD.bodyBold(size: 14.5, color: HD.ink))),
                      if (s.soTien != null)
                        Text(
                          tienCN(s.soTien!),
                          style: HD.bodyBold(
                            size: 14,
                            color: s.loai == 'thu_tien' ? MauCN.xanh : (s.loai == 'sua_chua' ? HD.accent : HD.ink),
                          ),
                        ),
                    ],
                  ),
                  if (s.moTa.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(s.moTa, style: HD.body(size: 13, color: HD.inkSoft)),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
