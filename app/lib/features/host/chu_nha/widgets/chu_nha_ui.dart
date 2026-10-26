import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import 'package:house_booking/core/widgets/ds.dart';
import 'package:house_booking/data/services/api_client.dart';
import 'package:house_booking/data/services/chu_nha_api.dart';
import 'package:house_booking/features/guest/thue_o/ho_so_thue.dart';

/// Khối giao diện dùng chung của bộ màn "Góc nhìn Chủ nhà" (mockup
/// 04/10/2026): nhãn trạng thái phòng, nút Từ chối/Xác nhận, ảnh nhỏ, định
/// dạng ngày giờ và hộp hỏi lý do từ chối.

const kVienCN = Color(0xFFEDEEF1);
const kNenCN = Color(0xFFF6F7F9);
const kCamCN = Color(0xFFC77C00);
const kXanhDuong = Color(0xFF2563EB);

/// Mọi chỗ in khách ở phía chủ nhà — chủ nhà làm việc với khách QUA sale.
const kAnThongTin = '[ẩn thông tin]';

const _thu = ['Thứ 2', 'Thứ 3', 'Thứ 4', 'Thứ 5', 'Thứ 6', 'Thứ 7', 'Chủ nhật'];

/// "Thứ 5, 10/10/2024".
String thuNgayCN(DateTime d) =>
    '${_thu[d.weekday - 1]}, ${hai(d.day)}/${hai(d.month)}/${d.year}';

/// "10:00 - 10:30" từ khoá giờ server ('10:00-11:00').
String khoangGioCN(String gio) {
  final p = gio.split('-').map((s) => s.trim()).toList();
  return p.length >= 2 && p[1].isNotEmpty ? '${p[0]} - ${p[1]}' : p.first;
}

/// "Thứ 5, 10/10/2024 • 10:00 - 10:30".
String lucHenCN(LichChuNha m) {
  final d = m.luc;
  return d == null
      ? khoangGioCN(m.gio)
      : '${thuNgayCN(d)} • ${khoangGioCN(m.gio)}';
}

/// Nhãn trạng thái phòng: Đang thuê · Trống · Có lịch xem · Sắp trả · Bảo trì.
class NhanPhong extends StatelessWidget {
  const NhanPhong(this.trangThai, {super.key});

  final String trangThai;

  static (String, Color, Color) kieu(String tt) => switch (tt) {
    'dang_thue' => ('Đang thuê', HD.positive, HD.positiveTint),
    'co_lich_xem' => ('Có lịch xem', HD.accent, HD.accentTint),
    'sap_tra' => ('Sắp trả', kCamCN, Color(0xFFFFF4E0)),
    'cho_chot' => ('Chờ chốt', kCamCN, Color(0xFFFFF4E0)),
    'bao_tri' => ('Bảo trì', Color(0xFF6B7280), Color(0xFFF1F2F4)),
    _ => ('Trống', Color(0xFF6B7280), Color(0xFFF1F2F4)),
  };

  @override
  Widget build(BuildContext context) {
    final (chu, mau, nen) = kieu(trangThai);
    return NhanCN(chu, mau: mau, nen: nen);
  }
}

class NhanCN extends StatelessWidget {
  const NhanCN(this.chu, {super.key, required this.mau, required this.nen});

  final String chu;
  final Color mau;
  final Color nen;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
    decoration: BoxDecoration(
      color: nen,
      borderRadius: BorderRadius.circular(HD.rPill),
    ),
    child: Text(chu, style: HD.bodyBold(size: 11.5, color: mau)),
  );
}

/// Nhãn trạng thái một lịch xem phía chủ nhà.
NhanCN nhanLichCN(LichChuNha m) {
  if (m.ketQua == 'chot') {
    return const NhanCN(
      'Đã xem · Chốt',
      mau: HD.positive,
      nen: HD.positiveTint,
    );
  }
  if (m.ketQua == 'khong_chot') {
    return const NhanCN(
      'Đã xem\nKhông chốt',
      mau: Color(0xFF6B7280),
      nen: Color(0xFFF1F2F4),
    );
  }
  return switch (m.trangThai) {
    'pending' when !m.quaGio => const NhanCN(
      'Chờ xác nhận',
      mau: kCamCN,
      nen: Color(0xFFFFF4E0),
    ),
    'pending' => const NhanCN(
      'Hết hạn',
      mau: Color(0xFF6B7280),
      nen: Color(0xFFF1F2F4),
    ),
    'doi_gio' => const NhanCN(
      'Chờ khách chọn giờ',
      mau: kCamCN,
      nen: Color(0xFFFFF4E0),
    ),
    'approved' when !m.quaGio => const NhanCN(
      'Đã xác nhận',
      mau: kXanhDuong,
      nen: Color(0xFFE8F0FE),
    ),
    'approved' || 'completed' => const NhanCN(
      'Đã xem',
      mau: kXanhDuong,
      nen: Color(0xFFE8F0FE),
    ),
    'awaiting_guest' || 'locked' => const NhanCN(
      'Chờ khách ký',
      mau: kCamCN,
      nen: Color(0xFFFFF4E0),
    ),
    'rejected' => const NhanCN(
      'Đã từ chối',
      mau: HD.accent,
      nen: HD.accentTint,
    ),
    _ => const NhanCN('Đã hủy', mau: HD.accent, nen: HD.accentTint),
  };
}

/// Ảnh vuông bo góc; không có ảnh thì nền xám + icon.
class AnhNhoCN extends StatelessWidget {
  const AnhNhoCN({super.key, this.url, this.rong = 56, this.cao = 46});

  final String? url;
  final double rong;
  final double cao;

  @override
  Widget build(BuildContext context) {
    const nen = ColoredBox(
      color: HD.paperSunken,
      child: Center(
        child: Icon(Icons.bed_outlined, size: 20, color: HD.inkMuted),
      ),
    );
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(
        width: rong,
        height: cao,
        child: (url ?? '').isEmpty
            ? nen
            : CachedNetworkImage(
                imageUrl: duongDanAnh(url!),
                fit: BoxFit.cover,
                placeholder: (_, _) => nen,
                errorWidget: (_, _, _) => nen,
              ),
      ),
    );
  }
}

/// Nút viền đỏ "Từ chối" / "Xem" và nút đặc đỏ "Xác nhận".
class NutCN extends StatelessWidget {
  const NutCN(
    this.chu, {
    super.key,
    required this.onPressed,
    this.dac = false,
    this.cao = 36,
  });

  final String chu;
  final VoidCallback? onPressed;
  final bool dac;
  final double cao;

  @override
  Widget build(BuildContext context) {
    final hinh = RoundedRectangleBorder(borderRadius: BorderRadius.circular(8));
    final chuW = FittedBox(fit: BoxFit.scaleDown, child: Text(chu));
    return SizedBox(
      height: cao,
      child: dac
          ? FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: HD.accent,
                shape: hinh,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                textStyle: HD.bodyBold(size: 13.5),
              ),
              onPressed: onPressed,
              child: chuW,
            )
          : OutlinedButton(
              style: OutlinedButton.styleFrom(
                foregroundColor: HD.accent,
                side: const BorderSide(color: HD.accent),
                shape: hinh,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                textStyle: HD.bodyBold(size: 13.5),
              ),
              onPressed: onPressed,
              child: chuW,
            ),
    );
  }
}

/// Thẻ trắng viền mảnh dùng khắp bộ màn.
class TheCN extends StatelessWidget {
  const TheCN({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(12),
    this.margin = const EdgeInsets.only(bottom: 10),
    this.onTap,
  });

  final Widget child;
  final EdgeInsets padding;
  final EdgeInsets margin;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Padding(
    padding: margin,
    child: Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: kVienCN),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(padding: padding, child: child),
      ),
    ),
  );
}

/// Dòng chữ phụ xám nhỏ.
Text phuCN(String s, {int? maxLines}) => Text(
  s,
  maxLines: maxLines,
  overflow: maxLines == null ? null : TextOverflow.ellipsis,
  style: HD.body(size: 12.5, color: HD.inkMuted),
);

/// Hỏi lý do rồi trả về chuỗi (rỗng được); null = người dùng thôi không từ chối.
Future<String?> hoiLyDoTuChoi(
  BuildContext context, {
  String tieuDe = 'Từ chối',
}) {
  final ctl = TextEditingController();
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    useRootNavigator: true,
    showDragHandle: true,
    backgroundColor: Colors.white,
    builder: (ctx) => Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        0,
        20,
        16 + MediaQuery.of(ctx).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(tieuDe, style: HD.bodyBold(size: 18)),
          const SizedBox(height: 10),
          TextField(
            key: const Key('ly-do-tu-choi'),
            controller: ctl,
            maxLines: 3,
            decoration: InputDecoration(
              hintText: 'Lý do (không bắt buộc) — Sale sẽ nhận được',
              hintStyle: HD.body(size: 13.5, color: HD.inkMuted),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 46,
            child: FilledButton(
              key: const Key('xac-nhan-tu-choi'),
              style: FilledButton.styleFrom(
                backgroundColor: HD.accent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onPressed: () => Navigator.of(ctx).pop(ctl.text.trim()),
              child: const Text('Xác nhận từ chối'),
            ),
          ),
        ],
      ),
    ),
  );
}

/// Chạy một hành động API, báo lỗi bằng SnackBar. Trả true khi xong.
Future<bool> chayCN(
  BuildContext context,
  Future<void> Function() viec, {
  required String xong,
}) async {
  final tin = ScaffoldMessenger.of(context);
  try {
    await viec();
    tin.showSnackBar(SnackBar(content: Text(xong)));
    return true;
  } catch (e) {
    tin.showSnackBar(
      SnackBar(
        content: Text(
          e is ApiException ? e.message : 'Chưa thực hiện được, thử lại nhé.',
        ),
      ),
    );
    return false;
  }
}

/// Tiêu đề trang gốc của tab (không có nút quay lại) hoặc trang con.
PreferredSizeWidget appBarCN(
  BuildContext context,
  String tieuDe, {
  bool quayLai = true,
  List<Widget>? actions,
}) => AppBar(
  backgroundColor: Colors.white,
  surfaceTintColor: Colors.white,
  elevation: 0,
  centerTitle: true,
  automaticallyImplyLeading: false,
  leading: quayLai
      ? IconButton(
          tooltip: 'Quay lại',
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.of(context).maybePop(),
        )
      : null,
  title: Text(tieuDe, style: HD.bodyBold(size: 17, color: HD.ink)),
  actions: actions,
);
