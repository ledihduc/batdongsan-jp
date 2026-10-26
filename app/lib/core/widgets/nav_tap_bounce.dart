import 'package:flutter/material.dart';

/// Icon thanh điều hướng NHÔ LÊN và nảy một nhịp khi được chọn.
///
/// Vì sao cần: [NavigationBar] của Material chỉ trượt viên nền và đổi màu — êm
/// nhưng không có phản hồi nào nói "tôi vừa nhận cú chạm của bạn". Trên máy
/// yếu, khi màn mới mất một hai nhịp để dựng, người dùng không chắc mình đã bấm
/// trúng nên bấm thêm lần nữa.
///
/// Mục được chọn còn ĐỨNG CAO HƠN vài pixel và giữ nguyên ở đó, để nhìn lướt
/// qua là biết mình đang ở đâu mà không cần đọc nhãn.
///
/// Chỉ nảy khi CHUYỂN SANG được chọn. Mục đang bỏ chọn giữ nguyên kích thước và
/// độ cao — cho cả năm icon cùng nhúc nhích mỗi lần đổi tab thì thành nhiễu,
/// không phải phản hồi.
class NavTapBounce extends StatelessWidget {
  const NavTapBounce({required this.child, required this.selected, super.key});

  final Widget child;
  final bool selected;

  /// Độ nhô của mục đang chọn (pixel).
  static const double _doNho = 4;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      // Đổi key = dựng lại widget = chạy lại animation từ đầu. Không có nó thì
      // lần chọn thứ hai trở đi sẽ không nảy nữa vì tween đã ở đích.
      key: ValueKey(selected),
      tween: Tween<double>(begin: selected ? 0 : 1, end: 1),
      duration: const Duration(milliseconds: 420),
      // elasticOut cho cảm giác "bật lên rồi ổn định", giống nút vật lý. Nó
      // vọt quá 1 rồi lùi lại, nên icon nhô hơi quá đà một chút — đúng ý.
      curve: Curves.elasticOut,
      builder: (_, v, ch) {
        // MỘT Transform duy nhất thay vì lồng translate trong scale: hai lớp
        // biến đổi lồng nhau tạo thêm một layer hợp thành mỗi khung hình, mà ở
        // đây chỉ cần một ma trận.
        final tiLe = selected ? 0.72 + 0.28 * v : 1.0;
        final nho = selected ? -_doNho * v : 0.0;
        return Transform(
          alignment: Alignment.center,
          transform: Matrix4.identity()
            ..translate(0.0, nho)
            ..scale(tiLe),
          child: ch,
        );
      },
      child: child,
    );
  }
}
