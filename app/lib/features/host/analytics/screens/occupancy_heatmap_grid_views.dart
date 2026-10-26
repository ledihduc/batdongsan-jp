import 'package:flutter/material.dart';
import 'package:house_booking/data/models/heatmap_cell_model.dart';
import 'package:house_booking/features/host/analytics/widgets/heatmap_cell.dart';
import 'package:house_booking/features/host/analytics/widgets/heatmap_cell_detail_sheet.dart';
import 'package:house_booking/features/host/analytics/widgets/heatmap_group_row.dart';
import 'package:house_booking/features/host/analytics/widgets/heatmap_sticky_col.dart';
import 'package:house_booking/features/host/dashboard/host_dashboard_tokens.dart';

import 'occupancy_heatmap_widgets.dart';

// ---------------------------------------------------------------------------
// HeatmapGridView — full virtualized room×day grid (≤30 rooms).
// Uses LayoutBuilder to pass finite height to InteractiveViewer child.
// ---------------------------------------------------------------------------

class HeatmapGridView extends StatelessWidget {
  const HeatmapGridView({
    super.key,
    required this.heatmap,
    required this.anchorDate,
    required this.verticalController,
  });

  final OccupancyHeatmapModel heatmap;
  final DateTime anchorDate;
  final ScrollController verticalController;

  @override
  Widget build(BuildContext context) {
    final monthLabel = 'T${anchorDate.month}/${anchorDate.year}';
    final gridWidth = kRoomColWidth + heatmap.days * kCellWidth;

    return LayoutBuilder(
      builder: (ctx, constraints) {
        final gridHeight = constraints.maxHeight;
        // Grid intentionally wider than viewport (user pans/zooms via InteractiveViewer).
        // ClipRect prevents overflow rendering errors in test environments.
        return ClipRect(
          child: InteractiveViewer(
            constrained: false,
            minScale: 0.5,
            maxScale: 2.5,
            child: SizedBox(
              width: gridWidth,
              height: gridHeight,
              child: Column(
                children: [
                  // Day header row
                  HeatmapDayHeader(daysInMonth: heatmap.days),
                  // Virtualized room rows
                  Expanded(
                    child: Stack(
                      children: [
                        // Main scrollable grid
                        ListView.builder(
                          controller: verticalController,
                          itemCount: heatmap.rooms.length,
                          itemExtent: kRowHeight,
                          itemBuilder: (ctx, rowIdx) {
                            final room = heatmap.rooms[rowIdx];
                            return HeatmapRoomRowWidget(
                              room: room,
                              daysInMonth: heatmap.days,
                              monthLabel: monthLabel,
                            );
                          },
                        ),
                        // Sticky room-name column
                        HeatmapStickyCol(
                          roomNames:
                              heatmap.rooms.map((r) => r.roomName).toList(),
                          scrollController: verticalController,
                          rowHeight: kRowHeight,
                          columnWidth: kRoomColWidth,
                          headerHeight: 0,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// HeatmapGroupView — building-level aggregated view for rooms > threshold.
// ---------------------------------------------------------------------------

class HeatmapGroupView extends StatefulWidget {
  const HeatmapGroupView({super.key, required this.heatmap, required this.anchorDate});

  final OccupancyHeatmapModel heatmap;
  final DateTime anchorDate;

  @override
  State<HeatmapGroupView> createState() => _HeatmapGroupViewState();
}

class _HeatmapGroupViewState extends State<HeatmapGroupView> {
  // Track which buildings are expanded.
  final Set<String> _expanded = {};

  Map<String, List<HeatmapRoomRow>> get _byBuilding {
    final map = <String, List<HeatmapRoomRow>>{};
    for (final room in widget.heatmap.rooms) {
      map.putIfAbsent(room.buildingName, () => []).add(room);
    }
    return map;
  }

  void _toggleBuilding(String buildingName) {
    setState(() {
      if (_expanded.contains(buildingName)) {
        _expanded.remove(buildingName);
      } else {
        _expanded.add(buildingName);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final grouped = _byBuilding;
    final monthLabel = 'T${widget.anchorDate.month}/${widget.anchorDate.year}';

    return ListView.builder(
      itemCount: grouped.length,
      itemBuilder: (ctx, i) {
        final buildingName = grouped.keys.elementAt(i);
        final rooms = grouped[buildingName]!;
        final isExpanded = _expanded.contains(buildingName);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            HeatmapGroupRow(
              buildingName: buildingName,
              rooms: rooms,
              daysInMonth: widget.heatmap.days,
              onExpand: () => _toggleBuilding(buildingName),
              rowHeight: 44,
            ),
            // Expanded: inline heatmap for this building's rooms
            if (isExpanded)
              _ExpandedBuildingGrid(
                rooms: rooms,
                daysInMonth: widget.heatmap.days,
                monthLabel: monthLabel,
              ),
          ],
        );
      },
    );
  }
}

class _ExpandedBuildingGrid extends StatelessWidget {
  const _ExpandedBuildingGrid({
    required this.rooms,
    required this.daysInMonth,
    required this.monthLabel,
  });

  final List<HeatmapRoomRow> rooms;
  final int daysInMonth;
  final String monthLabel;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          HeatmapDayHeader(daysInMonth: daysInMonth),
          ...rooms.map((room) => Row(
                children: [
                  // Room name col
                  Container(
                    width: kRoomColWidth,
                    height: kRowHeight,
                    color: HD.paperSunken,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    alignment: Alignment.centerLeft,
                    child: Text(
                      room.roomName,
                      style: HD.caption(color: HD.inkSoft).copyWith(
                        fontWeight: FontWeight.w600,
                        fontSize: 10,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  // Day cells
                  ...List.generate(daysInMonth, (dayIdx) {
                    final dayNum = dayIdx + 1;
                    final cell = room.cells.firstWhere(
                      (c) => c.day == dayNum,
                      orElse: () => HeatmapCell(
                        day: dayNum,
                        status: HeatmapCellStatus.vacant,
                      ),
                    );
                    return HeatmapCellWidget(
                      day: cell.day,
                      status: cell.status,
                      roomName: room.roomName,
                      cellSize: kCellWidth,
                      onTap: () => showHeatmapCellDetail(
                        context: context,
                        room: room,
                        cell: cell,
                        monthLabel: monthLabel,
                      ),
                    );
                  }),
                ],
              )),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// HeatmapRoomRowWidget — single virtualized row in the full grid view.
// ---------------------------------------------------------------------------

class HeatmapRoomRowWidget extends StatelessWidget {
  const HeatmapRoomRowWidget({
    super.key,
    required this.room,
    required this.daysInMonth,
    required this.monthLabel,
  });

  final HeatmapRoomRow room;
  final int daysInMonth;
  final String monthLabel;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // Sticky name col placeholder (real col is in Stack overlay)
        SizedBox(width: kRoomColWidth),
        // Virtualized horizontal day cells
        SizedBox(
          width: daysInMonth * kCellWidth,
          height: kRowHeight,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            physics: const ClampingScrollPhysics(),
            itemCount: daysInMonth,
            itemExtent: kCellWidth,
            itemBuilder: (ctx, dayIdx) {
              final dayNum = dayIdx + 1;
              final cell = room.cells.firstWhere(
                (c) => c.day == dayNum,
                orElse: () =>
                    HeatmapCell(day: dayNum, status: HeatmapCellStatus.vacant),
              );
              return HeatmapCellWidget(
                day: cell.day,
                status: cell.status,
                roomName: room.roomName,
                cellSize: kCellWidth,
                onTap: () => showHeatmapCellDetail(
                  context: context,
                  room: room,
                  cell: cell,
                  monthLabel: monthLabel,
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
