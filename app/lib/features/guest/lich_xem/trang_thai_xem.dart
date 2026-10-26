import 'package:flutter/material.dart';

import 'package:house_booking/core/widgets/ds.dart';

/// Trạng thái một lịch xem phòng NHÌN TỪ KHÁCH (mockup "Luồng lịch xem phòng
/// sắp tới", 04/10/2026). Một chỗ quy đổi để thẻ danh sách và màn chi tiết
/// luôn nói cùng một chữ về cùng một lịch.
enum BuocXem {
  /// Khách vừa gửi, chờ sale xác nhận (pending).
  daGui('Đã gửi lịch', Color(0xFFC77C00), Color(0xFFFFF4E0)),

  /// Bên bán báo bận, đề xuất giờ khác — khách phải chọn lại (doi_gio).
  choChonGio('Chờ bạn chọn giờ', Color(0xFFC77C00), Color(0xFFFFF4E0)),
  daXacNhan('Đã xác nhận', Color(0xFF16A34A), Color(0xFFE7F7EC)),

  /// Buổi xem đã diễn ra, khách chưa đánh giá.
  daXem('Đã xem', Color(0xFF2563EB), Color(0xFFE8F0FE)),
  daChot('Đã chốt', Color(0xFF7C3AED), Color(0xFFF1EAFE)),
  khongChot('Không chốt', Color(0xFF6B7280), Color(0xFFF1F2F4)),
  daHuy('Đã hủy', HD.accent, HD.accentTint),

  /// Qua giờ hẹn mà sale chưa từng xác nhận — không ai đến xem.
  hetHan('Hết hạn', Color(0xFF6B7280), Color(0xFFF1F2F4));

  const BuocXem(this.chu, this.mau, this.nen);

  final String chu;
  final Color mau;
  final Color nen;

  /// Bước đang ở trên thanh 5 bước (Đã gửi lịch · Chờ xác nhận · Đã xác nhận
  /// · Đã xem · Kết quả): mọi bước có chỉ số < giá trị này đã xong.
  int get buocHienTai => switch (this) {
    daGui || choChonGio => 1,
    daXacNhan => 2,
    daXem => 3,
    daChot || khongChot => 5,
    daHuy || hetHan => 0,
  };
}

/// [trangThai] là trạng thái THÔ server trả (pending · approved · doi_gio ·
/// completed · locked · cancelled · rejected · lost…); [ketQua] là kết quả
/// khách tự ghi ('chot' · 'khong_chot'); [luc] là giờ hẹn.
///
/// Lịch đã duyệt mà đã tới giờ hẹn được coi là ĐÃ XEM: sale hiếm khi bấm
/// "hoàn thành", và server cũng nhận đánh giá từ giờ bắt đầu lịch.
BuocXem buocXemCua(
  String trangThai, {
  String? ketQua,
  DateTime? luc,
  DateTime? bayGio,
}) {
  // Khách muốn thuê nhưng chủ nhà không đồng ý → lịch khép 'lost'.
  if (trangThai == 'lost') return BuocXem.khongChot;
  if (ketQua == 'chot') return BuocXem.daChot;
  if (ketQua == 'khong_chot') return BuocXem.khongChot;
  final now = bayGio ?? DateTime.now();
  final quaGio = luc != null && !now.isBefore(luc);
  return switch (trangThai) {
    'pending' => quaGio ? BuocXem.hetHan : BuocXem.daGui,
    // Đang chờ khách chọn giờ mới: giờ cũ đã bị huỷ, qua giờ cũ chưa là hết hạn.
    'doi_gio' => BuocXem.choChonGio,
    'approved' || 'confirmed' =>
      quaGio ? BuocXem.daXem : BuocXem.daXacNhan,
    'completed' || 'locked' || 'awaiting_guest' => BuocXem.daXem,
    _ => BuocXem.daHuy,
  };
}

const kTenBuoc = [
  'Đã gửi lịch',
  'Chờ xác nhận',
  'Đã xác nhận',
  'Đã xem',
  'Kết quả',
];

const _thu = ['Thứ 2', 'Thứ 3', 'Thứ 4', 'Thứ 5', 'Thứ 6', 'Thứ 7', 'Chủ nhật'];

String _hai(int n) => n.toString().padLeft(2, '0');

/// "Thứ 2, 07/10/2024".
String thuNgay(DateTime d) =>
    '${_thu[d.weekday - 1]}, ${_hai(d.day)}/${_hai(d.month)}/${d.year}';

/// "Thứ 2, 07/10" — dạng ngắn trong câu.
String thuNgayNgan(DateTime d) =>
    '${_thu[d.weekday - 1]}, ${_hai(d.day)}/${_hai(d.month)}';

/// "09:00 - 09:30" từ khoá giờ server ('09:00-10:00' hoặc '09:00').
String khoangGio(String gio) {
  final p = gio.split('-').map((s) => s.trim()).toList();
  if (p.length >= 2 && p[1].isNotEmpty) return '${p[0]} - ${p[1]}';
  return p.first;
}
