import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'package:house_booking/core/widgets/ds.dart';

/// Khối giao diện dùng chung cho chuỗi màn "thuê ở" của khách (mockup
/// 04/10/2026): khung trang tiêu đề giữa, thẻ trắng, dòng nhãn–giá trị, huy
/// hiệu, nút đỏ, ô chọn ảnh. Giữ một chỗ để chín màn trông như một bộ.

const kNenTrang = Color(0xFFF6F7F9);
const kVien = Color(0xFFEFF0F3);
const kCam = Color(0xFFC77C00);

/// Trang con: nút quay lại bên trái, tiêu đề giữa, nền xám rất nhạt.
class TrangThueO extends StatelessWidget {
  const TrangThueO({
    super.key,
    required this.tieuDe,
    required this.body,
    this.duoi,
  });

  final String tieuDe;
  final Widget body;
  final Widget? duoi;

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: kNenTrang,
    appBar: AppBar(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.white,
      elevation: 0,
      centerTitle: true,
      leading: IconButton(
        tooltip: 'Quay lại',
        icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
        onPressed: () => Navigator.of(context).maybePop(),
      ),
      title: Text(tieuDe, style: HD.bodyBold(size: 17, color: HD.ink)),
    ),
    body: body,
    bottomNavigationBar: duoi == null
        ? null
        : SafeArea(
            minimum: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: duoi!,
          ),
  );
}

/// Thẻ trắng bo 14, viền mảnh.
class KhoiTrang extends StatelessWidget {
  const KhoiTrang({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(14),
    this.margin = const EdgeInsets.only(bottom: 12),
  });

  final Widget child;
  final EdgeInsets padding;
  final EdgeInsets margin;

  @override
  Widget build(BuildContext context) => Container(
    margin: margin,
    padding: padding,
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: kVien),
    ),
    // Material trong suốt: ListTile/InkWell bên trong cần nó để vẽ hiệu ứng chạm.
    child: Material(type: MaterialType.transparency, child: child),
  );
}

class TieuDeKhoi extends StatelessWidget {
  const TieuDeKhoi(this.chu, {super.key, this.phai});

  final String chu;
  final Widget? phai;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Row(
      children: [
        Expanded(
          child: Text(chu, style: HD.bodyBold(size: 16, color: HD.ink)),
        ),
        if (phai != null) phai!,
      ],
    ),
  );
}

/// "Loại phòng ........ Studio" — nhãn xám trái, giá trị đậm phải.
class DongThongTin extends StatelessWidget {
  const DongThongTin(
    this.nhan,
    this.gia, {
    super.key,
    this.mauGia,
    this.giaDam = false,
    this.vach = true,
  });

  final String nhan;
  final String gia;
  final Color? mauGia;
  final bool giaDam;
  final bool vach;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(vertical: 11),
    decoration: BoxDecoration(
      border: vach ? const Border(bottom: BorderSide(color: kVien)) : null,
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(nhan, style: HD.body(size: 13.5, color: HD.inkMuted)),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            gia,
            textAlign: TextAlign.right,
            style: giaDam
                ? HD.bodyBold(size: 14.5, color: mauGia ?? HD.ink)
                : HD.body(size: 13.5, color: mauGia ?? HD.ink),
          ),
        ),
      ],
    ),
  );
}

/// Huy hiệu bo tròn: "Đang hiệu lực", "Quá hạn", "Đã thanh toán"…
class NhanTron extends StatelessWidget {
  const NhanTron(this.chu, {super.key, required this.mau, required this.nen});

  final String chu;
  final Color mau;
  final Color nen;

  factory NhanTron.xanh(String chu) =>
      NhanTron(chu, mau: HD.positive, nen: HD.positiveTint);
  factory NhanTron.cam(String chu) =>
      NhanTron(chu, mau: kCam, nen: HD.warningTint);
  factory NhanTron.do_(String chu) =>
      NhanTron(chu, mau: HD.accent, nen: HD.accentTint);

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
      color: nen,
      borderRadius: BorderRadius.circular(HD.rPill),
    ),
    child: Text(chu, style: HD.bodyBold(size: 12, color: mau)),
  );
}

/// Nút đỏ đặc kín bề ngang.
class NutDo extends StatelessWidget {
  const NutDo(
    this.chu, {
    super.key,
    required this.onPressed,
    this.dangChay = false,
    this.cao = 46,
  });

  final String chu;
  final VoidCallback? onPressed;
  final bool dangChay;
  final double cao;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: cao,
    width: double.infinity,
    child: FilledButton(
      style: FilledButton.styleFrom(
        backgroundColor: HD.accent,
        disabledBackgroundColor: HD.accent.withValues(alpha: 0.45),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        textStyle: HD.bodyBold(size: 15),
      ),
      onPressed: dangChay ? null : onPressed,
      child: dangChay
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2.4,
                color: Colors.white,
              ),
            )
          : Text(chu),
    ),
  );
}

/// Nút xám nhạt ("Xem").
class NutXam extends StatelessWidget {
  const NutXam(this.chu, {super.key, required this.onPressed});

  final String chu;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 40,
    width: double.infinity,
    child: TextButton(
      style: TextButton.styleFrom(
        backgroundColor: const Color(0xFFF1F2F4),
        foregroundColor: HD.inkSoft,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        textStyle: HD.body(size: 14),
      ),
      onPressed: onPressed,
      child: Text(chu),
    ),
  );
}

/// Hai tab dạng nút: đỏ đặc / xám ("Chưa thanh toán | Đã thanh toán").
class HaiTab extends StatelessWidget {
  const HaiTab({
    super.key,
    required this.trai,
    required this.phai,
    required this.chonTrai,
    required this.onChon,
  });

  final String trai;
  final String phai;
  final bool chonTrai;
  final ValueChanged<bool> onChon;

  @override
  Widget build(BuildContext context) => Container(
    height: 44,
    padding: const EdgeInsets.all(3),
    decoration: BoxDecoration(
      color: const Color(0xFFF1F2F4),
      borderRadius: BorderRadius.circular(10),
    ),
    child: Row(
      children: [
        for (final (chu, laTrai) in [(trai, true), (phai, false)])
          Expanded(
            child: GestureDetector(
              key: Key('tab-${laTrai ? 'trai' : 'phai'}'),
              onTap: () => onChon(laTrai),
              child: Container(
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: chonTrai == laTrai ? HD.accent : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  chu,
                  style: HD
                      .body(
                        size: 13.5,
                        color: chonTrai == laTrai ? Colors.white : HD.inkSoft,
                      )
                      .copyWith(
                        fontWeight: chonTrai == laTrai
                            ? FontWeight.w600
                            : FontWeight.w500,
                      ),
                ),
              ),
            ),
          ),
      ],
    ),
  );
}

/// Biểu tượng tài liệu viền đỏ (thẻ hoá đơn, kỳ điện nước).
class IconTaiLieu extends StatelessWidget {
  const IconTaiLieu({super.key, this.mau = HD.accent, this.to = false});

  final Color mau;
  final bool to;

  @override
  Widget build(BuildContext context) =>
      Icon(Icons.description_outlined, color: mau, size: to ? 34 : 28);
}

/// Ô "Chụp hoặc chọn ảnh" + ảnh đã chọn có nút ✕ — màn gửi ảnh / báo sự cố.
class OChonAnh extends StatelessWidget {
  const OChonAnh({
    super.key,
    required this.onChon,
    this.url,
    this.dangTai = false,
    this.onXoa,
    this.cao = 96,
  });

  final VoidCallback onChon;
  final String? url;
  final bool dangTai;
  final VoidCallback? onXoa;
  final double cao;

  @override
  Widget build(BuildContext context) {
    final o = InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: dangTai ? null : onChon,
      child: Container(
        height: cao,
        decoration: BoxDecoration(
          color: const Color(0xFFF7F8FA),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFE3E5E9)),
        ),
        child: Center(
          child: dangTai
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.2,
                    color: HD.accent,
                  ),
                )
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.photo_camera_outlined,
                      color: HD.inkSoft,
                      size: 24,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Chụp hoặc chọn ảnh',
                      style: HD.body(size: 12, color: HD.inkMuted),
                    ),
                  ],
                ),
        ),
      ),
    );
    final u = url;
    if (u == null) return o;
    return Row(
      children: [
        Expanded(child: o),
        const SizedBox(width: 10),
        Expanded(
          child: AnhDaChon(url: u, cao: cao, onXoa: onXoa),
        ),
      ],
    );
  }
}

/// Ảnh đã chọn, góc phải có nút ✕ để bỏ.
class AnhDaChon extends StatelessWidget {
  const AnhDaChon({super.key, required this.url, this.cao = 96, this.onXoa});

  final String url;
  final double cao;
  final VoidCallback? onXoa;

  @override
  Widget build(BuildContext context) => Stack(
    children: [
      ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: CachedNetworkImage(
          imageUrl: url,
          height: cao,
          width: double.infinity,
          fit: BoxFit.cover,
          errorWidget: (_, _, _) => Container(
            height: cao,
            color: HD.paperSunken,
            child: const Icon(Icons.broken_image_outlined),
          ),
        ),
      ),
      if (onXoa != null)
        Positioned(
          right: 4,
          top: 4,
          child: InkWell(
            onTap: onXoa,
            child: Container(
              width: 22,
              height: 22,
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.close_rounded, size: 15),
            ),
          ),
        ),
    ],
  );
}

/// Chọn một ảnh (camera trên điện thoại / tệp trên máy tính) rồi tải lên.
/// Trả URL đã tải, hoặc null nếu người dùng huỷ.
Future<String?> chonVaTaiAnh(
  BuildContext context,
  Future<String> Function(List<int> bytes, String filename) upload,
) async {
  final f = await ImagePicker().pickImage(
    source: ImageSource.gallery,
    maxWidth: 1600,
    imageQuality: 85,
  );
  if (f == null) return null;
  final bytes = await f.readAsBytes();
  return upload(bytes, f.name.isEmpty ? 'anh.jpg' : f.name);
}

/// Màn xác nhận đã gửi (mockup 8 & 10): biểu tượng lớn + tiêu đề + lời nhắn +
/// nút "Về trang chủ" — quay về đầu chuỗi màn (trang Hoạt động).
class ManThanhCong extends StatelessWidget {
  const ManThanhCong({
    super.key,
    required this.icon,
    required this.tieuDe,
    required this.loiNhan,
  });

  final IconData icon;
  final String tieuDe;
  final String loiNhan;

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.white,
    body: SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          children: [
            const Spacer(flex: 3),
            SizedBox(
              width: 120,
              height: 110,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  for (final (dx, dy, c) in const [
                    (2.0, 22.0, Color(0xFF3B82F6)),
                    (104.0, 8.0, HD.accent),
                    (112.0, 52.0, HD.positive),
                    (12.0, 74.0, HD.accent),
                    (82.0, 0.0, Color(0xFF22C55E)),
                  ])
                    Positioned(
                      left: dx,
                      top: dy,
                      child: Transform.rotate(
                        angle: 0.6,
                        child: Container(width: 6, height: 6, color: c),
                      ),
                    ),
                  Positioned(
                    left: 26,
                    top: 14,
                    child: Icon(icon, size: 70, color: HD.accent),
                  ),
                  Positioned(
                    left: 76,
                    top: 58,
                    child: Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: HD.positive,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 3),
                      ),
                      child: const Icon(
                        Icons.check_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),
            Text(
              tieuDe,
              textAlign: TextAlign.center,
              style: HD.bodyBold(size: 19, color: HD.ink),
            ),
            const SizedBox(height: 10),
            Text(
              loiNhan,
              textAlign: TextAlign.center,
              style: HD.body(size: 13.5, color: HD.inkMuted),
            ),
            const SizedBox(height: 32),
            NutDo(
              'Về trang chủ',
              key: const Key('ve-trang-chu'),
              onPressed: () => Navigator.of(context).popUntil((r) => r.isFirst),
            ),
            const Spacer(flex: 4),
          ],
        ),
      ),
    ),
  );
}
