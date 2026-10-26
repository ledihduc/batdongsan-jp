/// Tên thương hiệu — NGUỒN DUY NHẤT.
///
/// Trước đây chuỗi "ancu365" nằm rải rác ~20 chỗ trong code (logo ở 5 màn, tiêu
/// đề app, hộp thoại "Về ứng dụng", ghi công dữ liệu bản đồ, chia sẻ tin…) nên
/// đổi tên là phải đi lùng từng chỗ và chắc chắn sót. Nay mọi nơi đọc từ đây.
///
/// KHÔNG đụng tới định danh kỹ thuật: mã gói Android/iOS, tên miền, tên repo,
/// khoá ký APK. Đổi những thứ đó là phá bản cài đặt đang có trên máy người dùng
/// và mất luôn đường cập nhật ứng dụng đã phát hành.
class Brand {
  Brand._();

  /// Tên đầy đủ, dùng cho tiêu đề và câu chữ.
  static const String name = 'Vua Nhà';

  /// Logo dựng bằng hai mảnh: phần đầu chữ thường, phần sau in nghiêng màu
  /// nhấn (xem `HD.masthead` / `HD.mastheadItalic`).
  static const String logoPart1 = 'Vua';
  static const String logoPart2 = 'Nhà';

  /// Dòng bản quyền ở hộp thoại "Về ứng dụng".
  static const String legalese = '© 2026 $name';
}
