import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:house_booking/core/utils/formatters.dart';
import 'package:house_booking/data/models/room_model.dart';
import 'package:house_booking/data/services/kenh_khai_thac_api.dart';
import 'package:house_booking/features/host/dashboard/host_dashboard_tokens.dart';

/// Thẻ phòng trong SỔ PHÒNG — màn "Quản lí phòng" (mockup 11/09/2026).
///
/// Mã phòng + nút ⋮ · giá theo đơn vị của kênh + nhãn tình trạng · dòng dưới là
/// người đang ở, "Chưa có khách thuê" hoặc "Đang bảo trì". [dangDanhSach] dựng
/// cùng nội dung thành một hàng ngang cho chế độ "Dạng danh sách".
class RoomGridCard extends StatelessWidget {
  const RoomGridCard({
    super.key,
    required this.room,
    required this.onTap,
    this.menu,
    this.dangDanhSach = false,
  });

  final RoomModel room;
  final VoidCallback onTap;

  /// Nút ⋮ — màn sổ phòng dựng, vì nó giữ provider và điều hướng.
  final Widget? menu;
  final bool dangDanhSach;

  @override
  Widget build(BuildContext context) {
    final nguoi = _NguoiO.cua(room);
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: HD.sunkenShadow,
      ),
      child: Material(
        color: HD.paperRaised,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: HD.hairline.withValues(alpha: 0.5)),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(HD.s12),
            child: dangDanhSach ? _hang(nguoi) : _o(nguoi),
          ),
        ),
      ),
    );
  }

  Widget _ma(double size) => Text(
    room.code,
    maxLines: 1,
    overflow: TextOverflow.ellipsis,
    style: HD
        .bodyBold(size: size)
        .copyWith(fontWeight: FontWeight.w800, letterSpacing: -0.3),
  );

  Widget _o(_NguoiO nguoi) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          Expanded(child: _ma(17)),
          ?menu,
        ],
      ),
      const SizedBox(height: HD.s4),
      Row(
        children: [
          Expanded(child: _Gia(room: room)),
          const SizedBox(width: HD.s4),
          NhanTinhTrang(tinhTrang: room.tinhTrangHien),
        ],
      ),
      const Spacer(),
      Container(height: 1, color: HD.hairline.withValues(alpha: 0.35)),
      const SizedBox(height: HD.s8),
      Row(
        children: [
          nguoi.hinh(32),
          const SizedBox(width: HD.s8),
          Expanded(child: nguoi.chu()),
        ],
      ),
    ],
  );

  Widget _hang(_NguoiO nguoi) => Row(
    children: [
      nguoi.hinh(40),
      const SizedBox(width: HD.s12),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Flexible(child: _ma(15)),
                const SizedBox(width: 6),
                NhanTinhTrang(tinhTrang: room.tinhTrangHien),
              ],
            ),
            const SizedBox(height: 2),
            nguoi.chu(),
          ],
        ),
      ),
      const SizedBox(width: HD.s8),
      SizedBox(
        width: 92,
        child: _Gia(room: room, canhPhai: true),
      ),
      ?menu,
    ],
  );
}

/// Nhãn tình trạng — "Đang ở" · "Sắp trả" · "Trống" · "Bảo trì".
class NhanTinhTrang extends StatelessWidget {
  const NhanTinhTrang({super.key, required this.tinhTrang});

  final String tinhTrang;

  static const nhan = {
    'dang_o': 'Đang ở',
    'sap_tra': 'Sắp trả',
    'trong': 'Trống',
    'bao_tri': 'Bảo trì',
  };

  @override
  Widget build(BuildContext context) {
    final (nen, chu) = mauTinhTrang(tinhTrang);
    final Widget dau = switch (tinhTrang) {
      'sap_tra' => Icon(Icons.schedule, size: 10, color: chu),
      'bao_tri' => Icon(Icons.build, size: 9, color: chu),
      _ => Container(
        width: 6,
        height: 6,
        decoration: BoxDecoration(
          color: tinhTrang == 'trong' ? HD.inkMuted : chu,
          shape: BoxShape.circle,
        ),
      ),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: nen,
        borderRadius: BorderRadius.circular(HD.rPill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          dau,
          const SizedBox(width: 4),
          Text(
            nhan[tinhTrang] ?? tinhTrang,
            style: HD.bodyBold(size: 10, color: chu),
          ),
        ],
      ),
    );
  }
}

/// (nền, chữ) theo tình trạng. Chữ `HD.warning` thẳng trên nền vàng nhạt gần
/// như không đọc được → pha đậm về phía mực.
(Color, Color) mauTinhTrang(String tinhTrang) => switch (tinhTrang) {
  'dang_o' => (HD.positiveTint, HD.positive),
  'sap_tra' => (HD.accentTint, HD.accent),
  'bao_tri' => (HD.warningTint, _vangDam),
  _ => (HD.paperSunken, HD.inkSoft),
};

final Color _vangDam = Color.lerp(HD.warning, HD.ink, 0.45)!;

class _Gia extends StatelessWidget {
  const _Gia({required this.room, this.canhPhai = false});

  final RoomModel room;
  final bool canhPhai;

  @override
  Widget build(BuildContext context) {
    final gia = room.giaKenh ?? room.basePrice;
    final canh = canhPhai ? Alignment.centerRight : Alignment.centerLeft;
    if (gia <= 0) {
      return Align(
        alignment: canh,
        child: Text(
          'Chưa đặt giá',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: HD.body(size: 11, color: HD.inkMuted),
        ),
      );
    }
    final hauTo = KenhKhaiThac.hauToDonVi[room.donVi ?? 'thang'] ?? '/tháng';
    return LayoutBuilder(
      builder: (_, c) => FittedBox(
        fit: BoxFit.scaleDown,
        alignment: canh,
        child: Text.rich(
          TextSpan(
            children: [
              // Thẻ hẹp (điện thoại 360–390px): "5.000.000đ/tháng" cạnh nhãn
              // tình trạng không vừa → "5tr/tháng". Rộng như mockup thì in đủ.
              TextSpan(
                text: c.maxWidth >= 96 ? PriceFormat.full(gia) : _giaGon(gia),
                style: HD.bodyBold(size: 11, color: HD.inkSoft),
              ),
              TextSpan(
                text: hauTo,
                style: HD.body(size: 10, color: HD.inkMuted),
              ),
            ],
          ),
          maxLines: 1,
        ),
      ),
    );
  }
}

/// Dòng dưới của thẻ: ai đang ở / sẵn sàng cho thuê / đang bảo trì.
class _NguoiO {
  const _NguoiO(this.tinhTrang, this.dong1, this.dong2, {this.ten});

  factory _NguoiO.cua(RoomModel r) {
    switch (r.tinhTrangHien) {
      case 'dang_o':
      case 'sap_tra':
        final String? han = r.hopDongDen != null
            ? 'Hợp đồng đến ${_ngayDayDu(r.hopDongDen!)}'
            : r.traPhongLuc != null
            ? 'Trả phòng ${_gioNgay(r.traPhongLuc!)}'
            : null;
        final ten = r.khachThue?.trim() ?? '';
        // Sale phụ trách không nhận tên khách (server giữ lại) — vẫn phải nói
        // được là phòng có người.
        if (ten.isEmpty) {
          return _NguoiO(r.tinhTrangHien, 'Đang có khách thuê', han);
        }
        return _NguoiO(r.tinhTrangHien, ten, han, ten: ten);
      case 'bao_tri':
        final xong = r.maintenanceEnd ?? '';
        return _NguoiO(
          'bao_tri',
          'Đang bảo trì',
          xong.isEmpty
              ? 'Chưa hẹn ngày xong'
              : 'Dự kiến hoàn thành ${_ngayNgan(xong)}',
        );
      default:
        return const _NguoiO('trong', 'Chưa có khách thuê', 'Sẵn sàng cho thuê');
    }
  }

  final String tinhTrang;
  final String dong1;
  final String? dong2;
  final String? ten;

  Widget hinh(double co) {
    if (tinhTrang == 'trong') return _VongNetDut(co: co);
    final (nen, chu) = mauTinhTrang(tinhTrang);
    return Container(
      width: co,
      height: co,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: nen, shape: BoxShape.circle),
      child: ten != null
          ? Text(
              _chuCaiDau(ten!),
              style: HD.bodyBold(size: co * 0.4, color: chu),
            )
          : Icon(
              tinhTrang == 'bao_tri'
                  ? Icons.build_outlined
                  : Icons.person_outline,
              size: co * 0.45,
              color: chu,
            ),
    );
  }

  Widget chu() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(
        dong1,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: HD.bodyBold(size: 11.5),
      ),
      if (dong2 != null)
        Text(
          dong2!,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: HD.body(size: 9.5, color: HD.inkMuted),
        ),
    ],
  );
}

/// Vòng tròn nét đứt có dấu + — chỗ trống chờ khách thuê.
class _VongNetDut extends StatelessWidget {
  const _VongNetDut({required this.co});

  final double co;

  @override
  Widget build(BuildContext context) => CustomPaint(
    painter: const _NetDut(HD.hairlineStrong),
    child: SizedBox(
      width: co,
      height: co,
      child: Icon(Icons.add, size: co * 0.4, color: HD.inkMuted),
    ),
  );
}

class _NetDut extends CustomPainter {
  const _NetDut(this.mau);

  final Color mau;

  @override
  void paint(Canvas canvas, Size size) {
    final but = Paint()
      ..color = mau
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final vong = Rect.fromCircle(
      center: size.center(Offset.zero),
      radius: size.shortestSide / 2 - 0.5,
    );
    const doan = 12;
    for (var i = 0; i < doan; i++) {
      canvas.drawArc(vong, i * 2 * math.pi / doan, math.pi / doan, false, but);
    }
  }

  @override
  bool shouldRepaint(_NetDut old) => old.mau != mau;
}

/// "5,5tr" — giá gọn cho thẻ hẹp, dấu phẩy thập phân như người Việt đọc.
String _giaGon(double v) => PriceFormat.compact(v).replaceAll('.', ',');

/// '2025-09-30' → '30/09/2025'. Chuỗi lạ thì trả nguyên.
String _ngayDayDu(String iso) {
  final d = DateTime.tryParse(iso);
  return d == null ? iso : '${_hai(d.day)}/${_hai(d.month)}/${d.year}';
}

/// '2026-08-20' → '20/08'.
String _ngayNgan(String iso) {
  final d = DateTime.tryParse(iso);
  return d == null ? iso : '${_hai(d.day)}/${_hai(d.month)}';
}

String _gioNgay(DateTime d) =>
    '${_hai(d.hour)}:${_hai(d.minute)} ${_hai(d.day)}/${_hai(d.month)}';

String _hai(int n) => n.toString().padLeft(2, '0');

/// Chữ cái đầu của TÊN (từ cuối) — "Nguyễn Văn An" → "A", như danh bạ Việt.
String _chuCaiDau(String ten) {
  final tu = ten.trim().split(RegExp(r'\s+'));
  final cuoi = tu.isEmpty ? '' : tu.last;
  return cuoi.isEmpty ? '?' : cuoi.substring(0, 1).toUpperCase();
}
