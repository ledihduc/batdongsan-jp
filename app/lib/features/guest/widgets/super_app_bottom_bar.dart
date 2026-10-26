import 'package:flutter/material.dart';
import 'package:house_booking/core/theme/design_tokens.dart';

/// bTaskee-style bottom navigation: 4 destinations split 2 | 2 around a
/// central docked circular FAB.
///
/// Rendered only when `FeatureFlags.superAppNav` is ON — the flat
/// [NavigationBar] path in `GuestShell` stays byte-for-byte unchanged so a
/// rollback is a build-flag flip, not a code revert (repo dark-launch rule).
class SuperAppBottomBar extends StatelessWidget {
  const SuperAppBottomBar({
    super.key,
    required this.currentIndex,
    required this.onSelected,
    required this.items,
    this.hasCenterNotch = true,
  });

  /// Highlighted slot, 0..3.
  final int currentIndex;

  /// Fired with the tapped slot index (0..3).
  final ValueChanged<int> onSelected;

  /// Exactly 4 items. Slots [0,1] paint left of the notch, [2,3] right.
  final List<SuperAppNavItem> items;

  /// Reserve the central gap for a docked FAB. When false (no FAB, e.g.
  /// signed-out visitor) the four slots spread evenly with no gap so the bar
  /// never shows an empty notch.
  final bool hasCenterNotch;

  @override
  Widget build(BuildContext context) {
    assert(items.length == 4, 'SuperAppBottomBar requires exactly 4 items');
    return BottomAppBar(
      color: HD.paperRaised,
      elevation: 8,
      shape: hasCenterNotch ? const CircularNotchedRectangle() : null,
      notchMargin: 8,
      height: 62,
      padding: EdgeInsets.zero,
      child: Row(
        children: [
          Expanded(child: _slot(0)),
          Expanded(child: _slot(1)),
          // Gap = FAB diameter (56) + breathing room so the docked circle
          // clears both neighbouring slots.
          if (hasCenterNotch) const SizedBox(width: HD.s64),
          Expanded(child: _slot(2)),
          Expanded(child: _slot(3)),
        ],
      ),
    );
  }

  Widget _slot(int i) {
    final item = items[i];
    final selected = i == currentIndex;
    final color = selected ? HD.accent : HD.inkMuted;
    return InkResponse(
      onTap: () => onSelected(i),
      radius: 40,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          IconTheme.merge(
            data: IconThemeData(color: color, size: 24),
            child: selected ? item.selectedIcon : item.icon,
          ),
          const SizedBox(height: 2),
          Text(
            item.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: HD
                .navLabel(color: color)
                .copyWith(
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                ),
          ),
        ],
      ),
    );
  }
}

/// Immutable descriptor for one [SuperAppBottomBar] slot. Mirrors the
/// icon/label pair used by the flat NavigationBar so both nav paths share the
/// same intent and badge widgets.
class SuperAppNavItem {
  const SuperAppNavItem({
    required this.icon,
    required this.selectedIcon,
    required this.label,
  });

  final Widget icon;
  final Widget selectedIcon;
  final String label;
}
