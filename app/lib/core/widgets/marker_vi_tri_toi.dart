import 'package:flutter/material.dart';

import 'package:house_booking/core/theme/design_tokens.dart';

/// Dấu "VỊ TRÍ CỦA TÔI" trên bản đồ.
///
/// **Vì sao KHÔNG dùng chấm tròn:** mọi tin đăng trên bản đồ đều là đĩa tròn đặc
/// viền trắng, và bốn màu pin đã dùng hết xanh lá (dài hạn) · cam (ngắn hạn) ·
/// xanh dương (kinh doanh) · đỏ (bán). Nghĩa là **đổi màu không cứu được**: một
/// chấm tròn nữa, màu gì cũng đọc thành "thêm một tin đăng ở đây". Phải đổi
/// HÌNH DẠNG.
///
/// Chữ thập định vị có bốn gai chìa ra — không pin nào có gai, nên nhận ra được
/// ngay cả ở cỡ 20px trên bìa hồ sơ, chỗ mà mọi chi tiết nhỏ đều mất.
///
/// Vẽ hai lớp (trắng to hơn ở dưới làm viền, đậm ở trên) vì bản đồ có cả vùng
/// sáng lẫn tối: một màu duy nhất thì kiểu gì cũng có nền nuốt mất nó.
class MarkerViTriToi extends StatelessWidget {
  const MarkerViTriToi({super.key, this.size = 20});

  final double size;

  /// Cạnh ô [Marker] cần đặt: chừa chỗ cho viền trắng ở ngoài.
  static double hopCho(double size) => size + 6;

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        Icon(Icons.my_location, size: size + 4, color: Colors.white),
        Icon(
          Icons.my_location,
          size: size,
          color: HD.ink,
          shadows: const [Shadow(color: Colors.black26, blurRadius: 3)],
        ),
      ],
    );
  }
}
