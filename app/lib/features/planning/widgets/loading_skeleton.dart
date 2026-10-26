import 'package:flutter/material.dart';

/// Skeleton overlay hiển thị khi đang tải dữ liệu thửa đất (AC-08).
/// Xuất hiện trong < 200ms sau khi tap (không chặn scroll bản đồ).
class LoadingSkeleton extends StatelessWidget {
  const LoadingSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Positioned(
      bottom: 80,
      left: 16,
      right: 16,
      child: Material(
        elevation: 4,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _SkeletonLine(width: 180),
              const SizedBox(height: 10),
              _SkeletonLine(width: 120),
              const SizedBox(height: 8),
              _SkeletonLine(width: 200),
              const SizedBox(height: 8),
              _SkeletonLine(width: 150),
              const SizedBox(height: 12),
              const Center(child: CircularProgressIndicator(strokeWidth: 2)),
            ],
          ),
        ),
      ),
    );
  }
}

class _SkeletonLine extends StatelessWidget {
  const _SkeletonLine({required this.width});

  final double width;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: 14,
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }
}
