/// Helpers format ngày giờ tiếng Việt cho UI hiển thị.
///
/// Backend trả `booking_date` dưới dạng ISO "YYYY-MM-DD" và `created_at` dưới
/// dạng full ISO timestamp. UI cần format ngắn gọn, thân thiện kiểu Việt:
/// "Chủ nhật, 28/06/2026" hoặc "28/06/2026 09:12".

const List<String> _weekdayNames = <String>[
  '',           // 0 unused — DateTime.weekday trả 1..7
  'Thứ 2',
  'Thứ 3',
  'Thứ 4',
  'Thứ 5',
  'Thứ 6',
  'Thứ 7',
  'Chủ nhật',
];

/// Format ISO date string "YYYY-MM-DD" → "Thứ X, DD/MM/YYYY" (có thứ trong
/// tuần) hoặc "DD/MM/YYYY" nếu [withWeekday] false.
///
/// Trả lại nguyên chuỗi input nếu parse thất bại — guard cho dữ liệu lỗi
/// thay vì throw.
String formatVnDate(String isoDate, {bool withWeekday = true}) {
  final d = DateTime.tryParse(isoDate);
  if (d == null) return isoDate;
  final dd = d.day.toString().padLeft(2, '0');
  final mm = d.month.toString().padLeft(2, '0');
  final yyyy = d.year;
  if (!withWeekday) return '$dd/$mm/$yyyy';
  return '${_weekdayNames[d.weekday]}, $dd/$mm/$yyyy';
}

/// Format DateTime → "DD/MM/YYYY HH:mm" cho hiển thị thời điểm gửi/tạo.
String formatVnDateTime(DateTime dt) {
  final dd = dt.day.toString().padLeft(2, '0');
  final mm = dt.month.toString().padLeft(2, '0');
  final hh = dt.hour.toString().padLeft(2, '0');
  final mi = dt.minute.toString().padLeft(2, '0');
  return '$dd/$mm/${dt.year} $hh:$mi';
}
