import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

import '../theme/design_tokens.dart';

/// Ô khung xương chờ tải, có DẢI SÁNG QUÉT NGANG.
///
/// Bản trước tự viết: một `AnimationController` nhấp nháy độ mờ qua lại. Nhấp
/// nháy dễ bị đọc thành "màn hình đang lỗi" chứ không phải "đang tải"; dải sáng
/// quét theo một hướng thì nói rõ là có thứ gì đó đang tới.
///
/// Bọc `shimmer` ở TỪNG ô thay vì bọc cả màn: gói này quét một dải sáng đi qua
/// vùng nó bao, nên bọc cả màn sẽ cho một vệt sáng khổng lồ lướt qua mọi thứ
/// cùng lúc — trông như lỗi vẽ, không như từng khối đang nạp.
class Skeleton extends StatelessWidget {
  final double width;
  final double height;
  final BorderRadius? borderRadius;

  const Skeleton({
    super.key,
    this.width = double.infinity,
    this.height = 16,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: HD.paperSunken,
      highlightColor: HD.paperRaised,
      period: const Duration(milliseconds: 1300),
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          // Nền phải ĐỤC: Shimmer tô lên phần không trong suốt của con nó, ô
          // trong suốt thì không có gì để quét sáng.
          color: HD.paperSunken,
          borderRadius: borderRadius ?? BorderRadius.circular(HD.r4),
        ),
      ),
    );
  }
}

/// Alias for new code.
typedef DsSkeleton = Skeleton;

/// House card skeleton — 2-col list, used in guest home + wishlist.
class HouseCardSkeleton extends StatelessWidget {
  const HouseCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(HD.r12),
      child: Container(
        color: HD.paperRaised,
        child: const Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AspectRatio(
              aspectRatio: 4 / 3,
              child: Skeleton(borderRadius: BorderRadius.zero),
            ),
            Padding(
              padding: EdgeInsets.all(HD.s12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Skeleton(width: 60, height: 11),
                  SizedBox(height: HD.s8),
                  Skeleton(height: 13),
                  SizedBox(height: 6),
                  Skeleton(width: 80, height: 13),
                  SizedBox(height: HD.s8),
                  Skeleton(width: 100, height: 10),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Row skeleton for list screens — avatar / title / subtitle / right-aligned chip.
class DsRowSkeleton extends StatelessWidget {
  const DsRowSkeleton({super.key, this.showLeading = true});
  final bool showLeading;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: HD.s16,
        vertical: HD.s12,
      ),
      child: Row(
        children: [
          if (showLeading) ...[
            const Skeleton(width: 40, height: 40),
            const SizedBox(width: HD.s12),
          ],
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Skeleton(width: 160, height: 13),
                SizedBox(height: HD.s4),
                Skeleton(width: 100, height: 11),
              ],
            ),
          ),
          const Skeleton(width: 60, height: 18),
        ],
      ),
    );
  }
}
