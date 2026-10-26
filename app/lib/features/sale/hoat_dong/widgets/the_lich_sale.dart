import 'package:flutter/material.dart';

import 'package:house_booking/core/widgets/ds.dart';
import 'package:house_booking/data/services/sale_van_hanh_api.dart';
import 'package:house_booking/features/sale/hoat_dong/widgets/nhan_sale.dart';
import 'package:house_booking/features/sale/hoat_dong/widgets/sale_ui.dart';

/// Thẻ một lịch xem / đơn đặt phòng (mockup màn 5): ảnh · tên phòng + nhãn ·
/// "Khách: …" · ngày giờ · hàng nút theo `hanhDong` server trả.
class TheLichSale extends StatelessWidget {
  const TheLichSale({
    super.key,
    required this.lich,
    required this.onHanhDong,
  });

  final LichSale lich;

  /// tu_choi · xac_nhan · doi_lich · cap_nhat_ket_qua · xem_chi_tiet
  final ValueChanged<String> onHanhDong;

  String get _thoiGian {
    final l = lich;
    final bd = l.batDau;
    if (l.laDon) {
      final kt = l.ketThuc;
      if (bd == null) return l.kieu;
      final den = kt == null
          ? ''
          : (kt.day == bd.day && kt.month == bd.month
                ? ' - ${gioPhut(kt)}'
                : ' → ${ngayThang(kt)} ${gioPhut(kt)}');
      return '${ngayThang(bd)} • ${gioPhut(bd)}$den';
    }
    if (bd == null) return khungGio(l.gio);
    final gio = l.gio.isEmpty ? gioPhut(bd) : khungGio(l.gio);
    return '${ngayThang(bd)} • $gio';
  }

  @override
  Widget build(BuildContext context) {
    final (chu, tong) = nhanLich(lich.nhan);
    return TheSale(
      key: Key('the-lich-${lich.loai}-${lich.id}'),
      onTap: () => onHanhDong('xem_chi_tiet'),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AnhSale(url: lich.phongAnh, co: 84),
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
                        lich.phongTen,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: HD.bodyBold(size: 14.5, color: HD.ink),
                      ),
                    ),
                    const SizedBox(width: 6),
                    NhanSale.tong(chu, tong),
                  ],
                ),
                const SizedBox(height: 5),
                Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: 'Khách: ',
                        style: HD.body(size: 13.5, color: HD.inkMuted),
                      ),
                      TextSpan(
                        text: lich.khachTen,
                        style: HD.body(size: 13.5, color: HD.inkSoft),
                      ),
                    ],
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 5),
                DongIconSale(
                  icon: Icons.event_outlined,
                  chu: lich.laDon && lich.kieu.isNotEmpty
                      ? '$_thoiGian · ${lich.kieu}'
                      : _thoiGian,
                  co: 13,
                ),
                const SizedBox(height: 10),
                _hangNut(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _hangNut() {
    final nut = lich.hanhDong;
    if (nut.contains('tu_choi') && nut.contains('xac_nhan')) {
      return Row(
        children: [
          Expanded(
            child: NutSale(
              'Từ chối',
              key: Key('tu-choi-${lich.id}'),
              kieu: KieuNutSale.vienDo,
              onPressed: () => onHanhDong('tu_choi'),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: NutSale(
              'Xác nhận',
              key: Key('xac-nhan-${lich.id}'),
              kieu: KieuNutSale.do_,
              onPressed: () => onHanhDong('xac_nhan'),
            ),
          ),
        ],
      );
    }
    if (nut.contains('doi_lich') && nut.contains('cap_nhat_ket_qua')) {
      return Row(
        children: [
          Expanded(
            child: NutSale(
              'Đổi lịch',
              key: Key('doi-lich-${lich.id}'),
              kieu: KieuNutSale.vienDo,
              onPressed: () => onHanhDong('doi_lich'),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: NutSale(
              'Cập nhật kết quả',
              key: Key('cap-nhat-${lich.id}'),
              kieu: KieuNutSale.lam,
              onPressed: () => onHanhDong('cap_nhat_ket_qua'),
            ),
          ),
        ],
      );
    }
    if (nut.contains('cap_nhat_ket_qua')) {
      return NutSale(
        'Cập nhật kết quả',
        key: Key('cap-nhat-${lich.id}'),
        kieu: KieuNutSale.lam,
        onPressed: () => onHanhDong('cap_nhat_ket_qua'),
      );
    }
    return NutSale(
      'Xem chi tiết',
      key: Key('xem-chi-tiet-${lich.id}'),
      kieu: KieuNutSale.vienXam,
      onPressed: () => onHanhDong('xem_chi_tiet'),
    );
  }
}
