import 'package:flutter/material.dart';

import 'package:house_booking/core/widgets/ds.dart';
import 'package:house_booking/data/services/quan_ly_api.dart';
import 'package:house_booking/features/guest/quan_ly/widgets/the_muc_quan_ly.dart';

/// Tóm tắt một phòng đang có khách thuê dài hạn — mở từ trang Quản lý, góc
/// "Khách thuê".
///
/// Chỉ là bảng TÓM TẮT, không phải màn hợp đồng: hợp đồng / hoá đơn là việc
/// của chủ phòng (các API đó gác bằng vai chủ nhà). Sale phụ trách cần biết
/// phòng nào đang có người và tới bao giờ thì trống lại — đủ để hẹn khách mới.
/// Tên người thuê chỉ có khi server cho (`duoc_xem_tai_chinh`).
class HopDongKhachSheet extends StatelessWidget {
  const HopDongKhachSheet({super.key, required this.m});

  final MucQuanLy m;

  @override
  Widget build(BuildContext context) {
    final (mau, icon) = kieuTong(m.tong);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(HD.s20, HD.s12, HD.s20, HD.s20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: HD.hairline,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: HD.s16),
            Row(
              children: [
                Expanded(child: Text(m.tieuDe, style: HD.bodyBold(size: 18))),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: mau.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(HD.rPill),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(icon, size: 15, color: mau),
                      const SizedBox(width: 4),
                      Text(
                        m.nhan,
                        style: TextStyle(
                          color: mau,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (m.diaChi.isNotEmpty) ...[
              const SizedBox(height: HD.s4),
              Text(m.diaChi, style: HD.body(size: 13, color: HD.inkMuted)),
            ],
            const SizedBox(height: HD.s16),
            _Dong(icon: Icons.event_note_outlined, chu: m.dong),
            if (m.khach != null)
              _Dong(icon: Icons.person_outline, chu: 'Người thuê: ${m.khach}')
            else
              const _Dong(
                icon: Icons.lock_outline,
                chu: 'Tên người thuê và tiền thuê chỉ chủ phòng xem được.',
                mo: true,
              ),
          ],
        ),
      ),
    );
  }
}

class _Dong extends StatelessWidget {
  const _Dong({required this.icon, required this.chu, this.mo = false});

  final IconData icon;
  final String chu;
  final bool mo;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: HD.s8),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: HD.inkMuted),
        const SizedBox(width: HD.s8),
        Expanded(
          child: Text(
            chu,
            style: HD.body(size: 14, color: mo ? HD.inkMuted : HD.inkSoft),
          ),
        ),
      ],
    ),
  );
}
