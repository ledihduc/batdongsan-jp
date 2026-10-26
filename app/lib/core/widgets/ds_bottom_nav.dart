import 'package:flutter/material.dart';

import '../theme/design_tokens.dart';

/// Bottom nav item descriptor for [DsBottomNav].
class DsNavItem {
  const DsNavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
  });
  final IconData icon;
  final IconData activeIcon;
  final String label;
}

/// Bottom nav — paper background, hairline top rule, sans labels,
/// terracotta accent for the selected item.
///
/// Decision (260629): sans labels for accessibility despite editorial direction.
class DsBottomNav extends StatelessWidget {
  const DsBottomNav({
    super.key,
    required this.items,
    required this.currentIndex,
    required this.onTap,
  });

  final List<DsNavItem> items;
  final int currentIndex;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: HD.paperRaised,
        border: Border(top: BorderSide(color: HD.hairline)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 60,
          child: Row(
            children: [
              for (var i = 0; i < items.length; i++)
                Expanded(
                  child: _DsNavTile(
                    item: items[i],
                    selected: i == currentIndex,
                    onTap: () => onTap(i),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DsNavTile extends StatelessWidget {
  const _DsNavTile({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final DsNavItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? HD.accent : HD.inkMuted;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        splashColor: HD.accentTint,
        highlightColor: HD.accentSoft,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Selection indicator — thin terracotta bar at top.
            AnimatedContainer(
              duration: HD.motionShort,
              width: 28,
              height: 3,
              color: selected ? HD.accent : Colors.transparent,
            ),
            const SizedBox(height: HD.s8),
            Icon(
              selected ? item.activeIcon : item.icon,
              size: 22,
              color: color,
              semanticLabel: item.label,
            ),
            const SizedBox(height: 2),
            // forceStrutHeight keeps the label baseline stable when the
            // weight flips from w500 → w700 on selection.
            Text(
              item.label,
              style: HD.navLabel(color: color).copyWith(
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              ),
              maxLines: 1,
              strutStyle: const StrutStyle(
                forceStrutHeight: true,
                fontSize: 11,
                height: 1.1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
