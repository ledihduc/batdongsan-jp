import 'package:flutter/material.dart';

import '../theme/design_tokens.dart';

/// Editorial tab bar — hairline underline, italic serif labels for active.
/// Use as a controlled widget; parent owns selection state.
class DsTabBar extends StatelessWidget {
  const DsTabBar({
    super.key,
    required this.tabs,
    required this.currentIndex,
    required this.onTap,
    this.padding = const EdgeInsets.symmetric(horizontal: HD.s12),
  });

  final List<String> tabs;
  final int currentIndex;
  final ValueChanged<int> onTap;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: HD.paper,
        border: Border(bottom: BorderSide(color: HD.hairline)),
      ),
      child: Padding(
        padding: padding,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (var i = 0; i < tabs.length; i++)
                _DsTabItem(
                  label: tabs[i],
                  selected: i == currentIndex,
                  onTap: () => onTap(i),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DsTabItem extends StatelessWidget {
  const _DsTabItem({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      splashColor: HD.accentTint,
      highlightColor: HD.accentSoft,
      child: AnimatedContainer(
        duration: HD.motionShort,
        padding: const EdgeInsets.symmetric(
          horizontal: HD.s12,
          vertical: HD.s12,
        ),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: selected ? HD.accent : Colors.transparent,
              width: 2,
            ),
          ),
        ),
        child: Text(
          label,
          style: selected
              ? HD.sectionTitle(size: 16)
              : HD.body(size: 14, color: HD.inkMuted),
        ),
      ),
    );
  }
}

/// Segmented control — 2-4 options in a pill bar. Bold contrast for selected.
class DsSegmented<T> extends StatelessWidget {
  const DsSegmented({
    super.key,
    required this.options,
    required this.value,
    required this.onChanged,
    this.dense = false,
  });

  final List<({T value, String label, IconData? icon})> options;
  final T value;
  final ValueChanged<T> onChanged;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: HD.paperSunken,
        borderRadius: BorderRadius.circular(HD.r8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final opt in options)
            _DsSegment(
              label: opt.label,
              icon: opt.icon,
              selected: opt.value == value,
              dense: dense,
              onTap: () => onChanged(opt.value),
            ),
        ],
      ),
    );
  }
}

class _DsSegment extends StatelessWidget {
  const _DsSegment({
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
    this.dense = false,
  });

  final String label;
  final IconData? icon;
  final bool selected;
  final VoidCallback onTap;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: HD.motionShort,
        curve: HD.curveExpressive,
        padding: EdgeInsets.symmetric(
          horizontal: dense ? HD.s8 : HD.s12,
          vertical: dense ? 6 : HD.s8,
        ),
        decoration: BoxDecoration(
          color: selected ? HD.paperRaised : Colors.transparent,
          borderRadius: BorderRadius.circular(HD.r4),
          border: Border.all(
            color: selected ? HD.hairlineStrong : Colors.transparent,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                size: dense ? 13 : 15,
                color: selected ? HD.ink : HD.inkMuted,
              ),
              const SizedBox(width: HD.s4),
            ],
            Text(
              label,
              style: HD.body(
                size: dense ? 12 : 13,
                color: selected ? HD.ink : HD.inkMuted,
              ).copyWith(
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
