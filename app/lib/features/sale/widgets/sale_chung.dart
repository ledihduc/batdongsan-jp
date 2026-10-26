import 'package:flutter/material.dart';

import 'package:house_booking/core/widgets/ds.dart';

/// Bộ áo chung của cụm "Sale quản lý theo yêu cầu" (mockup 23/09/2026).
///
/// Năm màn dùng lại đúng một bộ: ô số liệu, chip lọc, nhãn trạng thái, thẻ
/// rỗng. Mỗi màn tự vẽ lại là mỗi màn một kiểu bo góc và một tông đỏ khác.

/// Tiền cho người đọc lướt: "320 triệu", "32,5 triệu", "15 triệu/tháng".
String saleTien(double v, {String hau = ''}) {
  if (v >= 1000000000) {
    final ty = v / 1000000000;
    return '${_so(ty)} tỷ$hau';
  }
  if (v >= 1000000) {
    return '${_so(v / 1000000)} triệu$hau';
  }
  if (v >= 1000) return '${_so(v / 1000)}k$hau';
  return '${v.toStringAsFixed(0)}đ$hau';
}

String _so(double v) => v == v.roundToDouble()
    ? v.toStringAsFixed(0)
    : v.toStringAsFixed(1).replaceAll('.', ',');

/// "2 giờ trước" · "1 ngày trước" — mốc tương đối như mockup.
String saleTruoc(DateTime? luc, {DateTime? bayGio}) {
  if (luc == null) return '';
  final d = (bayGio ?? DateTime.now()).difference(luc);
  if (d.inMinutes < 1) return 'vừa xong';
  if (d.inMinutes < 60) return '${d.inMinutes} phút trước';
  if (d.inHours < 24) return '${d.inHours} giờ trước';
  if (d.inDays < 30) return '${d.inDays} ngày trước';
  return '${luc.day.toString().padLeft(2, '0')}/${luc.month.toString().padLeft(2, '0')}/${luc.year}';
}

/// Màu của từng bước pipeline — cùng một bước thì cùng màu ở mọi màn.
Color saleMauBuoc(String buoc) => switch (buoc) {
  'lead_moi' => HD.svcBlue,
  'da_lien_he' || 'da_gui_can' => HD.svcViolet,
  'da_xac_nhan_lich' => HD.svcOrange,
  'sau_xem' => HD.svcAmber,
  'muon_thue' => HD.accent,
  'cho_coc' => HD.warning,
  'da_chot' => HD.positive,
  _ => HD.inkMuted,
};

/// Ô số liệu ở "Tổng quan" — số to, nhãn nhỏ, icon trong khuôn màu nhạt.
class SaleOSo extends StatelessWidget {
  const SaleOSo({
    super.key,
    required this.icon,
    required this.so,
    required this.nhan,
    required this.mau,
    this.phu,
  });

  final IconData icon;
  final String so;
  final String nhan;
  final Color mau;

  /// Dòng phụ kiểu "+20%"; để trống khi CHƯA có số liệu kỳ trước — vẽ mũi tên
  /// tăng mà không có gì để so là bịa.
  final String? phu;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: HD.paperRaised,
        borderRadius: BorderRadius.circular(HD.r12),
        border: Border.all(color: HD.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: mau.withValues(alpha: .12),
              borderRadius: BorderRadius.circular(HD.r8),
            ),
            child: Icon(icon, size: 18, color: mau),
          ),
          const SizedBox(height: 8),
          Text(so, style: HD.bodyBold(size: 20)),
          Text(
            nhan,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: HD.body(size: 11.5, color: HD.inkMuted),
          ),
          if (phu != null && phu!.isNotEmpty)
            Text(phu!, style: HD.bodyBold(size: 11, color: HD.positive)),
        ],
      ),
    );
  }
}

/// Chip lọc kèm số đếm: "Tất cả (68)".
class SaleChipLoc extends StatelessWidget {
  const SaleChipLoc({
    super.key,
    required this.nhan,
    required this.so,
    required this.chon,
    required this.onTap,
  });

  final String nhan;
  final int so;
  final bool chon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(HD.rPill),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: chon ? HD.accent : HD.paperRaised,
            borderRadius: BorderRadius.circular(HD.rPill),
            border: Border.all(color: chon ? HD.accent : HD.hairline),
          ),
          child: Text(
            '$nhan ($so)',
            style: HD.bodyBold(
              size: 12.5,
              color: chon ? Colors.white : HD.inkSoft,
            ),
          ),
        ),
      ),
    );
  }
}

/// Nhãn trạng thái tròn cạnh — dùng cho bước pipeline và trạng thái khách.
class SaleNhan extends StatelessWidget {
  const SaleNhan({super.key, required this.chu, required this.mau});

  final String chu;
  final Color mau;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
    decoration: BoxDecoration(
      color: mau.withValues(alpha: .12),
      borderRadius: BorderRadius.circular(HD.rPill),
    ),
    child: Text(chu, style: HD.bodyBold(size: 11, color: mau)),
  );
}

/// Ảnh đại diện khách: ảnh thật thì hiện ảnh, không thì chữ cái đầu của TÊN.
class SaleAnhKhach extends StatelessWidget {
  const SaleAnhKhach({super.key, required this.ten, this.kichThuoc = 44});

  final String ten;
  final double kichThuoc;

  @override
  Widget build(BuildContext context) {
    final chu = ten.trim().isEmpty
        ? '?'
        : ten.trim().split(RegExp(r'\s+')).last.characters.first.toUpperCase();
    return Container(
      width: kichThuoc,
      height: kichThuoc,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: HD.accentTint,
        shape: BoxShape.circle,
        border: Border.all(color: HD.accent.withValues(alpha: .25)),
      ),
      child: Text(
        chu,
        style: HD.bodyBold(size: kichThuoc * 0.38, color: HD.accent),
      ),
    );
  }
}

/// Trạng thái rỗng — NÓI RÕ phải làm gì, không chỉ "chưa có dữ liệu".
class SaleRong extends StatelessWidget {
  const SaleRong({
    super.key,
    required this.icon,
    required this.tieuDe,
    required this.mo,
    this.nut,
  });

  final IconData icon;
  final String tieuDe;
  final String mo;
  final Widget? nut;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 24),
    child: Column(
      children: [
        Icon(icon, size: 40, color: HD.inkMuted),
        const SizedBox(height: 10),
        Text(tieuDe, style: HD.bodyBold(size: 14.5)),
        const SizedBox(height: 4),
        Text(
          mo,
          textAlign: TextAlign.center,
          style: HD.body(size: 12.5, color: HD.inkMuted),
        ),
        if (nut != null) ...[const SizedBox(height: 14), nut!],
      ],
    ),
  );
}

/// Thanh báo lỗi tải — kéo xuống thử lại, không nuốt lỗi.
class SaleBaoLoi extends StatelessWidget {
  const SaleBaoLoi({super.key, required this.loi, this.onThuLai});

  final String loi;
  final VoidCallback? onThuLai;

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.symmetric(vertical: 12),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: HD.negativeTint,
      borderRadius: BorderRadius.circular(HD.r12),
    ),
    child: Row(
      children: [
        const Icon(Icons.error_outline, size: 18, color: HD.negative),
        const SizedBox(width: 8),
        Expanded(
          child: Text(loi, style: HD.body(size: 12.5, color: HD.negative)),
        ),
        if (onThuLai != null)
          TextButton(onPressed: onThuLai, child: const Text('Thử lại')),
      ],
    ),
  );
}
