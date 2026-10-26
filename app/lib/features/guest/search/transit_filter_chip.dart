/// Transit filter chip for JP station search in the search facets drawer.
///
/// Displays a removable chip showing the selected station + walk time.
library;

import 'package:flutter/material.dart';
import 'package:house_booking/core/widgets/ds.dart';
import 'package:house_booking/data/models/jp/jp_station.dart';

/// A chip that shows a selected station and allows removal.
class TransitFilterChip extends StatelessWidget {
  const TransitFilterChip({
    super.key,
    required this.station,
    required this.walkMin,
    required this.onRemove,
    this.onTap,
  });

  final JpStation station;
  final int walkMin;
  final VoidCallback onRemove;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: HD.accentTint,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: HD.accent.withOpacity(0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.train_outlined, size: 14, color: HD.accent),
            const SizedBox(width: 4),
            Text(
              '${station.name} 徒歩${walkMin}分以内',
              style: const TextStyle(
                fontSize: 12,
                color: HD.accent,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(width: 6),
            GestureDetector(
              onTap: onRemove,
              child: const Icon(Icons.close, size: 14, color: HD.accent),
            ),
          ],
        ),
      ),
    );
  }
}
