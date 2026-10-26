import 'package:flutter/material.dart';

import 'package:house_booking/core/theme/design_tokens.dart';
import 'package:house_booking/core/utils/formatters.dart';
import 'package:house_booking/data/services/ca_thue_api.dart';

/// Mảnh dùng chung cho BỐN màn quầy lễ tân (chi tiết đặt · nhận phòng · đang ở
/// · trả phòng). Bốn màn là bốn thời điểm của CÙNG một ca, nên thẻ, hàng tiền
/// và cách hiển thị giờ phải giống hệt nhau — khách nhìn phiếu ở màn nào cũng
/// đọc ra một con số.

/// Thẻ trắng bo tròn, có chấm màu + tiêu đề nhỏ — khuôn thẻ của cụm ngắn hạn.
class TheCa extends StatelessWidget {
  const TheCa({
    super.key,
    required this.tieuDe,
    required this.child,
    this.cham = HD.accent,
    this.phai,
  });

  final String tieuDe;
  final Widget child;
  final Color cham;
  final Widget? phai;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: HD.hairline.withValues(alpha: 0.8)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Container(
              width: 9,
              height: 9,
              decoration: BoxDecoration(color: cham, shape: BoxShape.circle),
            ),
            const SizedBox(width: HD.s8),
            Expanded(
              child: Text(
                tieuDe,
                style: HD.bodyBold(size: 11.5, color: HD.inkSoft),
              ),
            ),
            if (phai != null) phai!,
          ],
        ),
        const SizedBox(height: HD.s12),
        child,
      ],
    ),
  );
}

/// Một dòng của bảng quyết toán: nhãn bên trái, số tiền bên phải.
class HangTien extends StatelessWidget {
  const HangTien(
    this.nhan,
    this.so, {
    super.key,
    this.phu,
    this.mau,
    this.dam = false,
    this.icon,
  });

  final String nhan;
  final String so;

  /// Chú thích nhỏ dưới nhãn ("Đã trả", "2 chai × 10.000đ").
  final String? phu;
  final Color? mau;
  final bool dam;
  final IconData? icon;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (icon != null) ...[
          Icon(icon, size: 15, color: mau ?? HD.inkMuted),
          const SizedBox(width: HD.s8),
        ],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                nhan,
                style: dam
                    ? HD.bodyBold(size: 13, color: HD.ink)
                    : HD.body(size: 13, color: HD.inkSoft),
              ),
              if (phu != null)
                Text(phu!, style: HD.body(size: 11, color: HD.inkMuted)),
            ],
          ),
        ),
        const SizedBox(width: HD.s8),
        Text(
          so,
          style: HD.bodyBold(size: dam ? 15 : 13, color: mau ?? HD.ink),
        ),
      ],
    ),
  );
}

/// Nhãn trạng thái ca — một bảng màu duy nhất cho cả bốn màn.
class ChipTrangThai extends StatelessWidget {
  const ChipTrangThai(this.ca, {super.key});

  final CaThue ca;

  static (String, Color, IconData) mo(CaThue ca) {
    if (ca.daTra) return ('Đã trả phòng', HD.neutral, Icons.task_alt);
    if (ca.dangO) {
      return ca.tienDo.quaGio
          ? ('Đang ở · quá giờ', HD.negative, Icons.running_with_errors)
          : ('Đang ở', HD.positive, Icons.hotel);
    }
    if (ca.trangThai == 'cancelled') {
      return ('Đã huỷ', HD.inkMuted, Icons.cancel);
    }
    if (ca.trangThai == 'pending') {
      return ('Chờ duyệt', HD.warning, Icons.pending_actions);
    }
    return ('Sắp nhận phòng', HD.accent, Icons.hourglass_top);
  }

  @override
  Widget build(BuildContext context) {
    final (chu, mau, icon) = mo(ca);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: mau.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: mau),
          const SizedBox(width: 5),
          Text(chu, style: HD.bodyBold(size: 11, color: mau)),
        ],
      ),
    );
  }
}

/// Ô số liệu nhỏ (giờ vào / giờ ra / tổng tiền).
class ONhanh extends StatelessWidget {
  const ONhanh({
    super.key,
    required this.nhan,
    required this.so,
    this.phu,
    this.mau = HD.ink,
    this.nen = HD.paperSunken,
    this.icon,
  });

  final String nhan;
  final String so;
  final String? phu;
  final Color mau;
  final Color nen;
  final IconData? icon;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: HD.s12, vertical: 10),
    decoration: BoxDecoration(
      color: nen,
      borderRadius: BorderRadius.circular(HD.r12),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            if (icon != null) ...[
              Icon(icon, size: 12, color: HD.inkMuted),
              const SizedBox(width: 4),
            ],
            Text(nhan, style: HD.body(size: 10.5, color: HD.inkMuted)),
          ],
        ),
        const SizedBox(height: 3),
        Text(so, style: HD.bodyBold(size: 17, color: mau)),
        if (phu != null)
          Text(phu!, style: HD.body(size: 10.5, color: HD.inkMuted)),
      ],
    ),
  );
}

// ── Định dạng ───────────────────────────────────────────────────────────────

String gioPhut(DateTime t) =>
    '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

String ngayVN(DateTime t) =>
    '${t.day.toString().padLeft(2, '0')}/${t.month.toString().padLeft(2, '0')}/${t.year}';

/// "Hôm nay" / "Ngày mai" / "12/08/2026" — mốc so là giờ MÁY CHỦ trong [ca].
String ngayTuongDoi(DateTime t, DateTime moc) {
  final a = DateTime(t.year, t.month, t.day);
  final b = DateTime(moc.year, moc.month, moc.day);
  final chenh = a.difference(b).inDays;
  if (chenh == 0) return 'Hôm nay';
  if (chenh == 1) return 'Ngày mai';
  if (chenh == -1) return 'Hôm qua';
  return ngayVN(t);
}

/// 155 → "2 giờ 35 phút"; 60 → "1 giờ"; 45 → "45 phút".
String doDai(int phut) {
  if (phut < 60) return '$phut phút';
  final gio = phut ~/ 60;
  final du = phut % 60;
  return du == 0 ? '$gio giờ' : '$gio giờ $du phút';
}

/// 155 → "2h35m" — bản ngắn cho đồng hồ.
String doDaiNgan(int phut) {
  final gio = phut ~/ 60;
  final du = phut % 60;
  return gio == 0 ? '${du}m' : '${gio}h${du.toString().padLeft(2, '0')}m';
}

String tien(double v) => PriceFormat.full(v.abs());

/// Hỏi lý do từ chối — bắt buộc có (backend cũng đòi), vì khách cần biết vì
/// sao đơn bị trả, và sale cần biết để tìm phòng khác cho khách.
Future<String?> hoiLyDoTuChoi(BuildContext context) {
  final c = TextEditingController();
  return showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text('Từ chối đơn', style: HD.bodyBold(size: 16)),
      content: TextField(
        key: const ValueKey('ly-do-tu-choi'),
        controller: c,
        autofocus: true,
        decoration: const InputDecoration(
          labelText: 'Lý do',
          hintText: 'Phòng đang sửa, trùng lịch…',
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: const Text('Đóng'),
        ),
        FilledButton(
          key: const ValueKey('xac-nhan-tu-choi'),
          onPressed: () {
            final t = c.text.trim();
            if (t.isEmpty) return;
            Navigator.of(ctx).pop(t);
          },
          style: FilledButton.styleFrom(backgroundColor: HD.negative),
          child: const Text('Từ chối'),
        ),
      ],
    ),
  );
}
