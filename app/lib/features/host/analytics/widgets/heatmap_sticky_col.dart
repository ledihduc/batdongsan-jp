import 'package:flutter/material.dart';
import 'package:house_booking/features/host/dashboard/host_dashboard_tokens.dart';

/// Sticky first column overlaying room names in the heatmap.
///
/// Must be placed inside a [Stack] with the heatmap grid as the back layer.
/// The sticky column syncs vertical scroll via a linked [ScrollController].
///
/// [roomNames] — ordered list matching the heatmap rows.
/// [scrollController] — linked to the main ListView.builder's controller.
/// [rowHeight] — must match the ListView itemExtent.
/// [headerHeight] — offset from top (day header + appbar area).
class HeatmapStickyCol extends StatelessWidget {
  const HeatmapStickyCol({
    super.key,
    required this.roomNames,
    required this.scrollController,
    required this.rowHeight,
    required this.columnWidth,
    this.headerHeight = 32.0,
  });

  final List<String> roomNames;
  final ScrollController scrollController;
  final double rowHeight;
  final double columnWidth;
  final double headerHeight;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: headerHeight,
      left: 0,
      bottom: 0,
      width: columnWidth,
      child: IgnorePointer(
        child: ListView.builder(
          controller: scrollController,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: roomNames.length,
          itemExtent: rowHeight,
          itemBuilder: (_, i) => _RoomNameCell(
            name: roomNames[i],
            height: rowHeight,
            width: columnWidth,
          ),
        ),
      ),
    );
  }
}

class _RoomNameCell extends StatelessWidget {
  const _RoomNameCell({
    required this.name,
    required this.height,
    required this.width,
  });

  final String name;
  final double height;
  final double width;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: HD.paperSunken,
        border: Border(
          right: BorderSide(color: HD.hairline),
          bottom: BorderSide(color: HD.hairline, width: 0.5),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8),
      alignment: Alignment.centerLeft,
      child: Text(
        name,
        style: HD.caption(color: HD.inkSoft).copyWith(
          fontWeight: FontWeight.w600,
          fontSize: 10,
        ),
        overflow: TextOverflow.ellipsis,
        maxLines: 1,
      ),
    );
  }
}
