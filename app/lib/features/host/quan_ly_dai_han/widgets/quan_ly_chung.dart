import 'package:flutter/material.dart';

import 'package:house_booking/core/widgets/ds.dart';

/// Mảnh giao diện dùng chung cho BỐN màn quản lý cho thuê dài hạn
/// (Khách hàng · Hợp đồng · Hóa đơn · Doanh thu, mockup 23/09/2026).
///
/// Bốn màn cùng một bộ áo: thẻ trắng bo 14, viền `QL.vien`, nền `QL.nen`, ô
/// đếm ở đầu và hàng chip lọc ngay dưới. Chép bốn lần là bốn màn trôi dần khỏi
/// nhau sau vài lần sửa.

/// Hằng số áo ngoài — màu CHỈ khai ở `design_tokens.dart`, đây là bí danh.
abstract final class QL {
  static const Color nen = Color(0xfff7f9fc);
  static const Color vien = Color(0xffe0e6ee);
  static const Color xanh = Color(0xff078a59);
  static const Color cam = Color(0xffdf8a00);
  static const Color lam = Color(0xff246be8);

  static final BoxDecoration the = BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(14),
    border: Border.all(color: vien),
  );
}

/// Thanh tiêu đề chung: nút quay lại + tên toà.
PreferredSizeWidget qlAppBar(BuildContext context, String tenToa) => AppBar(
  backgroundColor: Colors.white,
  surfaceTintColor: Colors.transparent,
  elevation: 0,
  centerTitle: true,
  leading: const BackButton(color: HD.ink),
  title: Text(
    tenToa,
    maxLines: 1,
    overflow: TextOverflow.ellipsis,
    style: HD.bodyBold(size: 15.5),
  ),
  bottom: const PreferredSize(
    preferredSize: Size.fromHeight(1),
    child: Divider(height: 1, color: QL.vien),
  ),
);

/// Tiền rút gọn kiểu người Việt đọc: 4.8tr · 950k · 4.800.000đ khi cần đủ.
String qlTien(double v, {bool day = false}) {
  if (day) {
    final s = v.round().toString();
    final b = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) b.write('.');
      b.write(s[i]);
    }
    return '${b}đ';
  }
  if (v.abs() >= 1000000) {
    final n = v / 1000000;
    return '${n.toStringAsFixed(n == n.roundToDouble() ? 0 : 1).replaceAll('.', ',')}tr';
  }
  if (v.abs() >= 1000) return '${(v / 1000).round()}k';
  return v.round().toString();
}

/// `2026-01-10` → `10/01/2026`. Chuỗi lạ thì trả nguyên — không đoán.
String qlNgay(String iso) {
  final d = DateTime.tryParse(iso);
  if (d == null) return iso;
  return '${d.day.toString().padLeft(2, '0')}/'
      '${d.month.toString().padLeft(2, '0')}/${d.year}';
}

/// `2026-09` → `Tháng 9/2026`.
String qlThang(String thang) {
  if (thang.length < 7) return thang;
  return 'Tháng ${int.tryParse(thang.substring(5, 7)) ?? thang}/'
      '${thang.substring(0, 4)}';
}

/// Ô đếm đầu màn: số to, nhãn nhỏ, icon nền nhạt.
class QlOSo extends StatelessWidget {
  const QlOSo({
    super.key,
    required this.khoa,
    required this.icon,
    required this.mau,
    required this.so,
    required this.nhan,
    this.onTap,
  });

  final String khoa;
  final IconData icon;
  final Color mau;
  final String so;
  final String nhan;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.white,
    borderRadius: BorderRadius.circular(14),
    child: InkWell(
      key: Key('ql-o-$khoa'),
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 10),
        decoration: QL.the,
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: mau.withValues(alpha: .11),
                borderRadius: BorderRadius.circular(11),
              ),
              child: Icon(icon, size: 18, color: mau),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    so,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: HD.bodyBold(size: 16, color: mau),
                  ),
                  Text(
                    nhan,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: HD.body(size: 9.5, color: HD.inkMuted),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

/// Hàng chip lọc / tab cuộn ngang. Chip đang chọn nền đỏ, chữ trắng.
class QlHangChip extends StatelessWidget {
  const QlHangChip({
    super.key,
    required this.muc,
    required this.dangChon,
    required this.onChon,
  });

  final List<({String ma, String nhan})> muc;
  final String dangChon;
  final ValueChanged<String> onChon;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 34,
    child: ListView.separated(
      scrollDirection: Axis.horizontal,
      itemCount: muc.length,
      separatorBuilder: (_, _) => const SizedBox(width: 8),
      itemBuilder: (_, i) {
        final m = muc[i];
        final chon = m.ma == dangChon;
        return InkWell(
          key: Key('ql-chip-${m.ma}'),
          onTap: () => onChon(m.ma),
          borderRadius: BorderRadius.circular(HD.rPill),
          child: Container(
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: chon ? HD.accent : Colors.white,
              borderRadius: BorderRadius.circular(HD.rPill),
              border: Border.all(color: chon ? HD.accent : QL.vien),
            ),
            child: Text(
              m.nhan,
              style: HD.bodyBold(
                size: 12,
                color: chon ? Colors.white : HD.inkSoft,
              ),
            ),
          ),
        );
      },
    ),
  );
}

/// Nhãn trạng thái nhỏ trên thẻ (Đang ở · Sắp hết hạn · Quá hạn 4 ngày…).
class QlChipNhan extends StatelessWidget {
  const QlChipNhan({super.key, required this.chu, required this.mau});

  final String chu;
  final Color mau;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: mau.withValues(alpha: .12),
      borderRadius: BorderRadius.circular(HD.rPill),
    ),
    child: Text(chu, style: HD.bodyBold(size: 10.5, color: mau)),
  );
}

/// Ảnh đại diện khách: chữ cái đầu trên nền nhạt — không bịa ảnh người thật.
class QlAnhKhach extends StatelessWidget {
  const QlAnhKhach({super.key, required this.ten, this.canh = 42});

  final String ten;
  final double canh;

  @override
  Widget build(BuildContext context) {
    // Người Việt gọi nhau bằng TÊN — chữ cái của từ CUỐI, lấy ký tự ĐẦU của
    // từ đó. "Phạm Minh Tuấn" → T (ký tự cuối lại ra "n").
    final tu = ten.trim().split(RegExp(r'\s+'));
    final chu = tu.isEmpty || tu.last.isEmpty ? '?' : tu.last.characters.first;
    return Container(
      width: canh,
      height: canh,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        color: HD.paperSunken,
        shape: BoxShape.circle,
      ),
      child: Text(
        chu.toUpperCase(),
        style: HD.bodyBold(size: canh * 0.4, color: HD.inkSoft),
      ),
    );
  }
}

/// Thanh tiến độ hợp đồng / thu tiền.
class QlThanhTienDo extends StatelessWidget {
  const QlThanhTienDo({
    super.key,
    required this.phanTram,
    this.mau = HD.accent,
    this.cao = 6,
  });

  final int phanTram;
  final Color mau;
  final double cao;

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(cao),
    child: LinearProgressIndicator(
      value: (phanTram.clamp(0, 100)) / 100,
      minHeight: cao,
      backgroundColor: HD.paperSunken,
      valueColor: AlwaysStoppedAnimation(mau),
    ),
  );
}

/// Trạng thái rỗng — nói rõ vì sao trống, không để màn trắng.
class QlRong extends StatelessWidget {
  const QlRong({
    super.key,
    required this.icon,
    required this.tieuDe,
    required this.phu,
  });

  final IconData icon;
  final String tieuDe;
  final String phu;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 20),
    alignment: Alignment.center,
    child: Column(
      children: [
        Icon(icon, size: 34, color: HD.inkMuted),
        const SizedBox(height: 8),
        Text(tieuDe, style: HD.bodyBold(size: 14)),
        const SizedBox(height: 3),
        Text(
          phu,
          textAlign: TextAlign.center,
          style: HD.body(size: 12, color: HD.inkMuted),
        ),
      ],
    ),
  );
}

/// Báo lỗi tải — nói thật là chưa tải được, không hiện số 0 giả.
class QlBaoLoi extends StatelessWidget {
  const QlBaoLoi({super.key, required this.chu});

  final String chu;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: HD.accentTint,
      borderRadius: BorderRadius.circular(12),
    ),
    child: Row(
      children: [
        const Icon(Icons.wifi_off_rounded, size: 18, color: HD.accent),
        const SizedBox(width: 8),
        Expanded(child: Text(chu, style: HD.body(size: 12.5))),
      ],
    ),
  );
}
