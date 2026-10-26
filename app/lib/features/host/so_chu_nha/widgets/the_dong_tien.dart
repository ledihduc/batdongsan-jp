import 'package:flutter/material.dart';

import 'package:house_booking/core/widgets/ds.dart';
import 'package:house_booking/data/services/so_chu_nha_api.dart';
import 'package:house_booking/features/host/so_chu_nha/widgets/so_ui.dart';

/// Ô "Kỳ thu / Kỳ tháng": hiện tháng đang chọn, chạm mở danh sách kỳ.
class OChonKyCN extends StatelessWidget {
  const OChonKyCN({
    super.key,
    required this.nhan,
    required this.ky,
    required this.cacKy,
    required this.onChon,
  });

  final String nhan;
  final String ky;
  final List<String> cacKy;
  final ValueChanged<String> onChon;

  Future<void> _mo(BuildContext context) async {
    final chon = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: MauCN.the,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.symmetric(vertical: 12),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
              child: Text(nhan, style: HD.bodyBold(size: 17, color: HD.ink)),
            ),
            for (final k in cacKy)
              ListTile(
                key: Key('cn-ky-chon-$k'),
                title: Text(kyCN(k), style: HD.body(size: 15, color: HD.ink)),
                trailing: k == ky ? const Icon(Icons.check_rounded, color: HD.accent) : null,
                onTap: () => Navigator.pop(context, k),
              ),
          ],
        ),
      ),
    );
    if (chon != null && chon != ky) onChon(chon);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(nhan, style: HD.bodyBold(size: 14, color: HD.ink)),
        const SizedBox(height: 8),
        Material(
          color: MauCN.the,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            key: const Key('cn-o-ky'),
            borderRadius: BorderRadius.circular(12),
            onTap: cacKy.length > 1 ? () => _mo(context) : null,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: HD.hairline),
              ),
              child: Row(
                children: [
                  const Icon(Icons.calendar_month_outlined, size: 20, color: HD.inkMuted),
                  const SizedBox(width: 10),
                  Expanded(child: Text(kyCN(ky), style: HD.body(size: 15, color: HD.ink))),
                  const Icon(Icons.keyboard_arrow_down_rounded, color: HD.inkMuted),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Thẻ các dòng tiền của một kỳ: Tiền phòng · Điện (60 kWh) · Nước (8 m³) ·
/// dịch vụ… → Tổng tiền đỏ.
class TheDongTienCN extends StatelessWidget {
  const TheDongTienCN({super.key, required this.ky});

  final KyThuCN ky;

  @override
  Widget build(BuildContext context) {
    return TheCN(
      key: const Key('cn-dong-tien'),
      padding: const EdgeInsets.fromLTRB(14, 6, 14, 6),
      child: Column(
        children: [
          for (var i = 0; i < ky.dong.length; i++) ...[
            if (i > 0) Divider(height: 1, color: MauCN.vien),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 11),
              child: Row(
                children: [
                  Builder(
                    builder: (_) {
                      final (icon, mau) = _bieuTuong(ky.dong[i]);
                      return Icon(icon, size: 19, color: mau);
                    },
                  ),
                  const SizedBox(width: 10),
                  Expanded(child: Text(ky.dong[i].ten, style: HD.body(size: 14.5, color: HD.ink))),
                  Text(tienCN(ky.dong[i].soTien), style: HD.bodyBold(size: 14.5, color: HD.ink)),
                ],
              ),
            ),
          ],
          Divider(height: 1, thickness: 1.2, color: HD.hairline),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 13),
            child: Row(
              children: [
                Expanded(child: Text('Tổng tiền', style: HD.bodyBold(size: 16, color: HD.ink))),
                Text(
                  tienCN(ky.tong),
                  key: const Key('cn-tong-tien'),
                  style: HD.bodyBold(size: 20, color: HD.accent),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  (IconData, Color) _bieuTuong(DongTienCN d) => switch (d.loai) {
    'rent' => (Icons.home_outlined, HD.accent),
    'electricity' => (Icons.bolt_rounded, MauCN.cam),
    'water' => (Icons.water_drop_outlined, MauCN.lam),
    'adjustment' => (Icons.discount_outlined, MauCN.xanh),
    _ => bieuTuongDichVu('', d.ten),
  };
}
