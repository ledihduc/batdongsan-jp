import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import 'package:house_booking/core/config/api_config.dart';
import 'package:house_booking/core/widgets/ds.dart';
import 'package:house_booking/core/widgets/full_image_viewer.dart';

/// Mảnh dùng chung của cụm ĐIỆN NƯỚC: đường dẫn ảnh, cách in số và ngày, nhãn
/// trạng thái chỉ số, ô ảnh công tơ, hộp thoại yêu cầu chụp lại.
///
/// Bảng duyệt cả toà và màn chi tiết một phòng cùng đọc một con số — nhãn và
/// cách in phải ở MỘT chỗ, không thì mỗi màn gọi một kiểu và hai bên cãi nhau.

String anhTuyetDoi(String url) =>
    url.startsWith('http') ? url : '${ApiConfig.baseUrl}$url';

/// Số công tơ: số tròn in không phần lẻ, `null` in gạch ngang (chưa có số).
String soDienNuoc(double? v) {
  if (v == null) return '—';
  return v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(1);
}

String _hai(int n) => n.toString().padLeft(2, '0');

/// ISO → '12/08/2024'. Rỗng khi không đọc được.
String ngayVN(String? iso) {
  final d = DateTime.tryParse(iso ?? '');
  return d == null ? '' : '${_hai(d.day)}/${_hai(d.month)}/${d.year}';
}

/// ISO → '12/08/2024 09:14'.
String ngayGioVN(String? iso) {
  final d = DateTime.tryParse(iso ?? '');
  return d == null ? '' : '${ngayVN(iso)} ${_hai(d.hour)}:${_hai(d.minute)}';
}

/// '2026-08' → 'Tháng 8, 2026'.
String nhanThang(String thang) {
  final p = thang.split('-');
  return p.length == 2 ? 'Tháng ${int.tryParse(p[1]) ?? p[1]}, ${p[0]}' : thang;
}

/// '2026-08' → 'T8/2026' (nhãn cột biểu đồ).
String thangNgan(String thang) {
  final p = thang.split('-');
  return p.length == 2 ? 'T${int.tryParse(p[1]) ?? p[1]}/${p[0]}' : thang;
}

/// Nhãn · màu · biểu tượng của trạng thái chỉ số. 'thieu_anh' không phải một
/// cột trong bảng: nó là "chờ duyệt nhưng thiếu ảnh công tơ".
({String chu, Color mau, IconData icon}) nhanTrangThaiChiSo(String trangThai) =>
    switch (trangThai) {
      'da_duyet' => (chu: 'Đã xác nhận', mau: HD.positive, icon: Icons.check_circle),
      'cho_duyet' => (chu: 'Chờ chủ nhà duyệt', mau: HD.svcAmber, icon: Icons.schedule),
      'thieu_anh' => (chu: 'Thiếu ảnh công tơ', mau: HD.negative, icon: Icons.error_outline),
      'can_chup_lai' => (chu: 'Đã yêu cầu chụp lại', mau: HD.negative, icon: Icons.refresh),
      _ => (chu: 'Chưa gửi chỉ số', mau: HD.inkMuted, icon: Icons.hourglass_empty),
    };

/// Ảnh công tơ, hoặc ô viền nét đứt khi chưa có ảnh. Bấm vào ảnh là xem cỡ lớn.
class AnhCongTo extends StatelessWidget {
  const AnhCongTo({
    super.key,
    required this.url,
    required this.nhan,
    required this.mau,
    this.rong,
    this.cao = 72,
    this.nhanDuoi = false,
    this.nutMoRong = false,
  });

  final String? url;

  /// 'điện' / 'nước' — vào câu "Chưa có ảnh điện".
  final String nhan;
  final Color mau;

  /// `null` = giãn hết chiều ngang chỗ chứa.
  final double? rong;
  final double cao;
  final bool nhanDuoi;
  final bool nutMoRong;

  @override
  Widget build(BuildContext context) {
    final u = url;
    if (u == null) {
      return CustomPaint(
        painter: VienNetDut(mau),
        child: SizedBox(
          width: rong,
          height: cao,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.add_photo_alternate_outlined, color: mau, size: 22),
              Text(
                'Chưa có ảnh $nhan',
                textAlign: TextAlign.center,
                style: HD.body(size: 10, color: mau),
              ),
            ],
          ),
        ),
      );
    }
    final anh = ClipRRect(
      borderRadius: BorderRadius.circular(HD.r12),
      child: Stack(
        children: [
          CachedNetworkImage(
            imageUrl: anhTuyetDoi(u),
            width: rong,
            height: cao,
            fit: BoxFit.cover,
            errorWidget: (_, _, _) => SizedBox(
              width: rong,
              height: cao,
              child: const Center(child: Icon(Icons.broken_image_outlined)),
            ),
          ),
          if (nutMoRong)
            Positioned(
              right: 6,
              bottom: 6,
              child: Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: HD.ink.withValues(alpha: 0.5),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.open_in_full, size: 14, color: Colors.white),
              ),
            ),
        ],
      ),
    );
    final bamDuoc = GestureDetector(
      onTap: () => showImageGallery(context, [anhTuyetDoi(u)]),
      child: anh,
    );
    if (!nhanDuoi) return bamDuoc;
    return Column(
      children: [
        bamDuoc,
        Text('Ảnh $nhan', style: HD.body(size: 11, color: HD.inkMuted)),
      ],
    );
  }
}

/// Viền nét đứt — Flutter không có sẵn, mà ô "chưa có ảnh" cần khác hẳn ô ảnh
/// thật để mắt nhận ra ngay phòng nào thiếu.
class VienNetDut extends CustomPainter {
  VienNetDut(this.mau);

  final Color mau;

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = mau
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;
    final path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(8)),
      );
    for (final m in path.computeMetrics()) {
      for (double d = 0; d < m.length; d += 8) {
        canvas.drawPath(m.extractPath(d, d + 4), p);
      }
    }
  }

  @override
  bool shouldRepaint(covariant VienNetDut old) => old.mau != mau;
}

/// Hộp thoại tự giữ controller. Huỷ controller ngay sau `showDialog` thì ô
/// nhập — vẫn đang chạy hiệu ứng đóng — dùng một controller đã bị huỷ.
class HopThoaiChupLai extends StatefulWidget {
  const HopThoaiChupLai({super.key, required this.maPhong});

  final String maPhong;

  @override
  State<HopThoaiChupLai> createState() => _HopThoaiChupLaiState();
}

class _HopThoaiChupLaiState extends State<HopThoaiChupLai> {
  final _lyDo = TextEditingController(text: 'Ảnh công tơ chưa rõ');

  @override
  void dispose() {
    _lyDo.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text('Yêu cầu phòng ${widget.maPhong} chụp lại?'),
    content: TextField(
      controller: _lyDo,
      maxLines: 2,
      decoration: const InputDecoration(
        labelText: 'Lý do (người thuê sẽ đọc được)',
        border: OutlineInputBorder(),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Huỷ'),
      ),
      FilledButton(
        onPressed: () => Navigator.pop(context, _lyDo.text),
        child: const Text('Gửi yêu cầu'),
      ),
    ],
  );
}

/// Chỗ trống có lời giải thích — không để màn trắng im lặng.
class DienNuocRong extends StatelessWidget {
  const DienNuocRong(this.chu, {super.key});

  final String chu;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: HD.s32),
    child: Center(
      child: Text(
        chu,
        textAlign: TextAlign.center,
        style: HD.body(size: 14, color: HD.inkMuted),
      ),
    ),
  );
}
