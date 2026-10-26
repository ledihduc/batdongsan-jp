import 'package:flutter/material.dart';

import 'package:house_booking/features/host/dashboard/host_dashboard_tokens.dart';

/// Generic multi-select chip group.
///
/// Renders a Wrap of [FilterChip] widgets for the given [options].
/// Selections are controlled externally via [selected] / [onChanged].
class FilterChipGroup extends StatelessWidget {
  const FilterChipGroup({
    super.key,
    required this.options,
    required this.selected,
    required this.onChanged,
    this.label,
  });

  /// Available options — each has an [id] and display [label].
  final List<({int id, String label})> options;

  /// Currently selected IDs.
  final Set<int> selected;

  /// Called when user toggles a chip. Receives new full selection set.
  final void Function(Set<int> newSelected) onChanged;

  /// Optional section label displayed above the chips.
  final String? label;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (label != null) ...[
          Text(label!, style: HD.caption(color: HD.inkSoft).copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: HD.s4),
        ],
        Wrap(
          spacing: HD.s8,
          runSpacing: HD.s4,
          children: options.map((opt) {
            final isSelected = selected.contains(opt.id);
            return FilterChip(
              key: Key('filter_chip_${opt.id}'),
              label: Text(
                opt.label,
                style: HD.caption(
                  color: isSelected ? HD.paperRaised : HD.ink,
                ).copyWith(fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal),
              ),
              selected: isSelected,
              onSelected: (checked) {
                final next = Set<int>.from(selected);
                if (checked) {
                  next.add(opt.id);
                } else {
                  next.remove(opt.id);
                }
                onChanged(next);
              },
              selectedColor: HD.ink,
              checkmarkColor: HD.paperRaised,
              backgroundColor: HD.paper,
              side: BorderSide(color: isSelected ? HD.ink : HD.hairline),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(4),
              ),
              padding: const EdgeInsets.symmetric(horizontal: HD.s4, vertical: 0),
              materialTapTargetSize: MaterialTapTargetSize.padded,
            );
          }).toList(),
        ),
      ],
    );
  }
}
