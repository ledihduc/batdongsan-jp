import 'package:flutter/material.dart';

import 'package:house_booking/core/theme/design_tokens.dart';

/// Thang "SAO CHẤT LƯỢNG" dạng vạch terracotta ▰▰▰▱▱.
///
/// CỐ TÌNH khác sao vàng ⭐ của review (design quyết định) để người dùng không
/// nhầm 2 hệ: chất lượng-tiện nghi (ảnh hưởng giá) vs đánh giá người thuê.
/// [verified]=true → tô đặc (đã thẩm định); false → nhạt (chủ tự khai).
class DsQualityStars extends StatelessWidget {
  const DsQualityStars({
    super.key,
    required this.value,
    this.max = 5,
    this.verified = false,
    this.width = 14,
    this.height = 18,
  });

  final int value;
  final int max;
  final bool verified;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    final onColor = verified ? HD.accent : HD.accent.withValues(alpha: 0.45);
    return Semantics(
      label: 'Chất lượng $value trên $max'
          '${verified ? ", đã thẩm định" : ", chủ tự khai"}',
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (int i = 1; i <= max; i++)
            Container(
              margin: const EdgeInsets.only(right: 3),
              width: width,
              height: height,
              decoration: BoxDecoration(
                color: i <= value ? onColor : HD.hairline,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
        ],
      ),
    );
  }
}
