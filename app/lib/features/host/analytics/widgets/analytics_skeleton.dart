import 'package:flutter/material.dart';
import 'package:house_booking/features/host/dashboard/host_dashboard_tokens.dart';

/// Loading skeleton for the analytics home screen.
///
/// Shows 5 placeholder rectangles in the same 2-column grid layout as KPI cards.
/// Uses simple animated grey containers (no shimmer package required).
class AnalyticsSkeleton extends StatefulWidget {
  const AnalyticsSkeleton({super.key});

  @override
  State<AnalyticsSkeleton> createState() => _AnalyticsSkeletonState();
}

class _AnalyticsSkeletonState extends State<AnalyticsSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _opacity = Tween<double>(begin: 0.3, end: 0.7).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _opacity,
      builder: (context, _) {
        return SingleChildScrollView(
          physics: const NeverScrollableScrollPhysics(),
          child: Padding(
            padding: const EdgeInsets.all(HD.s12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Period swiper skeleton
                _SkeletonBar(opacity: _opacity.value, height: 48),
                const SizedBox(height: HD.s12),
                // KPI grid: 2 columns, 3 rows (5 cards + 1 filler)
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisSpacing: HD.s8,
                  mainAxisSpacing: HD.s8,
                  childAspectRatio: 1.4,
                  children: List.generate(
                    6,
                    (i) => _SkeletonCard(opacity: _opacity.value),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _SkeletonBar extends StatelessWidget {
  const _SkeletonBar({required this.opacity, required this.height});

  final double opacity;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: opacity,
      child: Container(
        height: height,
        decoration: BoxDecoration(
          color: HD.hairline,
          borderRadius: BorderRadius.circular(4),
        ),
      ),
    );
  }
}

class _SkeletonCard extends StatelessWidget {
  const _SkeletonCard({required this.opacity});

  final double opacity;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: opacity,
      child: Container(
        padding: const EdgeInsets.all(HD.s12),
        decoration: BoxDecoration(
          color: HD.paperRaised,
          border: Border.all(color: HD.hairline),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(height: 10, width: 80, color: HD.hairline),
            const SizedBox(height: HD.s8),
            Container(height: 24, width: 60, color: HD.hairline),
            const SizedBox(height: HD.s4),
            Container(height: 10, width: 40, color: HD.hairline),
          ],
        ),
      ),
    );
  }
}
