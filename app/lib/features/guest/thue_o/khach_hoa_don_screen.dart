import 'package:flutter/material.dart';

import 'package:house_booking/core/widgets/ds.dart';
import 'package:house_booking/features/guest/thue_o/ho_so_thue.dart';
import 'package:house_booking/features/guest/thue_o/khach_chi_tiet_hoa_don_screen.dart';
import 'package:house_booking/features/guest/thue_o/widgets/thue_o_ui.dart';

/// Màn 4 — Hóa đơn (mockup 04/10/2026): tab Chưa thanh toán | Đã thanh toán;
/// mỗi thẻ: biểu tượng tài liệu · "Hóa đơn tháng MM/YYYY" · số tiền · hạn ·
/// huy hiệu · nút "Thanh toán" (đỏ) hoặc "Xem" (xám).
class KhachHoaDonScreen extends StatefulWidget {
  const KhachHoaDonScreen({super.key, required this.hoSo});

  final HoSoThue hoSo;

  @override
  State<KhachHoaDonScreen> createState() => _KhachHoaDonScreenState();
}

class _KhachHoaDonScreenState extends State<KhachHoaDonScreen> {
  bool _chuaTra = true;

  void _mo(HoaDonThue h) => Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => KhachChiTietHoaDonScreen(hoSo: widget.hoSo, hoaDon: h),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final tat = widget.hoSo.hoaDon;
    final ds = tat.where((h) => h.daThanhToan != _chuaTra).toList();
    return TrangThueO(
      tieuDe: 'Hóa đơn',
      body: ListView(
        key: const Key('khach-hoa-don'),
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
        children: [
          HaiTab(
            trai: 'Chưa thanh toán',
            phai: 'Đã thanh toán',
            chonTrai: _chuaTra,
            onChon: (v) => setState(() => _chuaTra = v),
          ),
          const SizedBox(height: 14),
          if (ds.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 40),
              child: Text(
                _chuaTra
                    ? 'Bạn không có hóa đơn nào cần thanh toán.'
                    : 'Chưa có hóa đơn nào đã thanh toán.',
                textAlign: TextAlign.center,
                style: HD.body(color: HD.inkMuted),
              ),
            )
          else
            for (final h in ds) _TheHoaDon(h: h, onTap: () => _mo(h)),
        ],
      ),
    );
  }
}

class _TheHoaDon extends StatelessWidget {
  const _TheHoaDon({required this.h, required this.onTap});

  final HoaDonThue h;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final nhan = h.daThanhToan
        ? NhanTron.xanh('Đã thanh toán')
        : h.quaHan
        ? NhanTron.cam('Quá hạn')
        : null;
    return KhoiTrang(
      child: Row(
        key: Key('hoa-don-${h.id}'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: h.daThanhToan ? const Color(0xFFF4F5F7) : HD.accentTint,
              borderRadius: BorderRadius.circular(10),
            ),
            child: IconTaiLieu(mau: h.daThanhToan ? HD.inkMuted : HD.accent),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Hóa đơn tháng ${h.ky}',
                        style: HD.bodyBold(size: 14.5, color: HD.ink),
                      ),
                    ),
                    if (nhan != null) nhan,
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  tienVN(h.tong),
                  style: HD.bodyBold(size: 15, color: HD.ink),
                ),
                const SizedBox(height: 2),
                Text(
                  'Hạn thanh toán: ${ngayVN(h.han)}',
                  style: HD.body(size: 12.5, color: HD.inkMuted),
                ),
                const SizedBox(height: 10),
                if (h.daThanhToan)
                  NutXam('Xem', onPressed: onTap)
                else
                  NutDo('Thanh toán', cao: 40, onPressed: onTap),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
