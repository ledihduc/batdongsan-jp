import 'package:flutter/material.dart';
import '../host_dashboard_tokens.dart';

/// Custom tab bar — eyebrow caps with an animated 2px ink underline.
/// Replaces Material's heavy bottom-bar tab indicator.
class HDTabBar extends StatelessWidget {
  const HDTabBar({
    super.key,
    required this.controller,
    required this.labels,
  });

  final TabController controller;
  final List<String> labels;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: HD.paper,
        border: Border(bottom: BorderSide(color: HD.hairline)),
      ),
      child: TabBar(
        controller: controller,
        indicator: const UnderlineTabIndicator(
          borderSide: BorderSide(width: 2.5, color: HD.ink),
          insets: EdgeInsets.symmetric(horizontal: HD.s20),
        ),
        labelPadding: const EdgeInsets.symmetric(vertical: HD.s12),
        indicatorSize: TabBarIndicatorSize.tab,
        dividerHeight: 0,
        tabs: [
          for (var i = 0; i < labels.length; i++)
            _TabLabel(index: i + 1, label: labels[i], controller: controller),
        ],
      ),
    );
  }
}

class _TabLabel extends StatelessWidget {
  const _TabLabel({
    required this.index,
    required this.label,
    required this.controller,
  });

  final int index;
  final String label;
  final TabController controller;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final active = controller.index == index - 1;
        final color = active ? HD.ink : HD.inkMuted;
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '0$index',
              style: HD.tabular(color: active ? HD.accent : HD.inkMuted, size: 10),
            ),
            const SizedBox(width: HD.s8),
            Text(
              label.toUpperCase(),
              style: HD.eyebrow(color: color).copyWith(
                    fontSize: 11,
                    fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                  ),
            ),
          ],
        );
      },
    );
  }
}
