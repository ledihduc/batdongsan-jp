import 'package:flutter/material.dart';
import 'package:house_booking/data/models/heatmap_cell_model.dart';
import 'package:house_booking/features/host/analytics/widgets/color_palette.dart';
import 'package:house_booking/core/widgets/ds.dart';

/// A single heatmap cell — 24×24pt min size per AC-08.
///
/// Visual: colored background (per OccupancyPalette) + stripe overlay for
/// overdue + a11y pattern character for color-blind users.
///
/// [day] and [status] come from the HeatmapCell model.
class HeatmapCellWidget extends StatelessWidget {
  const HeatmapCellWidget({
    super.key,
    required this.day,
    required this.status,
    required this.roomName,
    required this.onTap,
    this.cellSize = 28.0,
  });

  final int day;
  final HeatmapCellStatus status;
  final String roomName;
  final VoidCallback onTap;

  /// Cell size in dp — 28dp matches Phase 00 perf spec (ListView itemExtent).
  final double cellSize;

  @override
  Widget build(BuildContext context) {
    final bgColor = OccupancyPalette.statusToColor(status);
    final patternChar = OccupancyPalette.statusToChar(status);
    final textColor = status == HeatmapCellStatus.paid
        ? Colors.white
        : Colors.black54;
    final painter = OccupancyPalette.stripePainterFor(status);
    final semanticsLabel = OccupancyPalette.semanticsLabel(roomName, day, status);

    return Semantics(
      label: semanticsLabel,
      button: true,
      child: GestureDetector(
        onTap: onTap,
        child: SizedBox(
          width: cellSize,
          height: cellSize,
          child: Stack(
            children: [
              // Base color fill
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    color: bgColor,
                    border: Border.all(
                      color: HD.hairline,
                      width: 0.5,
                    ),
                  ),
                ),
              ),
              // Stripe overlay for overdue (visible in greyscale)
              if (painter != null)
                Positioned.fill(
                  child: ClipRect(child: CustomPaint(painter: painter)),
                ),
              // A11y pattern character for color-blind users
              if (patternChar.isNotEmpty)
                Positioned.fill(
                  child: Center(
                    child: Text(
                      patternChar,
                      style: TextStyle(
                        fontSize: 9,
                        color: textColor,
                        height: 1.0,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
