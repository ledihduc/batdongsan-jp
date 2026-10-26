import 'package:flutter/material.dart';

import 'package:house_booking/core/widgets/ds.dart';
import 'package:house_booking/data/services/sale_van_hanh_api.dart';
import 'package:house_booking/features/sale/hoat_dong/chi_tiet_don_sale_screen.dart';
import 'package:house_booking/features/sale/hoat_dong/chi_tiet_lich_sale_screen.dart';
import 'package:house_booking/features/sale/hoat_dong/widgets/sale_ui.dart';

/// Một dòng "Cần xử lý hôm nay" (mockup màn 2): avatar khách · "Khách Trần
/// Minh" + nhãn · việc · "Ngày 08/10 • 09:00" · ›.
class DongViecSale extends StatelessWidget {
  const DongViecSale({super.key, required this.v, required this.onTap});

  final ViecSale v;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = v.thoiGian;
    return InkWell(
      key: Key('viec-${v.loai}-${v.id}'),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AvatarSale(ten: v.khachTen, url: v.khachAnh, co: 46),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          v.tieuDe,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: HD.bodyBold(size: 15, color: HD.ink),
                        ),
                      ),
                      const SizedBox(width: 6),
                      NhanSale.tong(v.nhan, v.tong),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    v.moTa,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: HD.body(size: 13.5, color: HD.inkMuted),
                  ),
                  if (t != null && v.loai != 'cho_chu_xac_nhan') ...[
                    const SizedBox(height: 3),
                    Text(
                      'Ngày ${ngayThang(t)} • ${gioPhut(t)}',
                      style: HD.body(size: 13, color: HD.inkMuted),
                    ),
                  ],
                ],
              ),
            ),
            const Padding(
              padding: EdgeInsets.only(top: 2, left: 4),
              child: Icon(Icons.chevron_right_rounded, color: HD.inkSoft),
            ),
          ],
        ),
      ),
    );
  }
}

/// Mở đúng màn chi tiết của một việc: lịch xem (dài hạn) hoặc đơn (ngắn hạn).
Future<void> moViecSale(
  BuildContext context,
  ViecSale v,
  String kenh, {
  SaleVanHanhApi api = const SaleVanHanhApi(),
}) => Navigator.of(context).push(
  MaterialPageRoute(
    builder: (_) => kenh == kKenhNganHan
        ? ChiTietDonSaleScreen(reservationId: v.id, api: api)
        : ChiTietLichSaleScreen(appointmentId: v.id, api: api),
  ),
);
