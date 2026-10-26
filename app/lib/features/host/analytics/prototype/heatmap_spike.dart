// Phase 00 Gate spike — heatmap virtualization prototype.
//
// Purpose: prove ListView.builder + sticky first col + colored cells can hit
// ≥30fps with 50 rooms × 31 days on mid-range device (Samsung A14).
//
// NOT production code. Validates AC-08 (heatmap UX) before Phase 06 dev.
// Run via: import in any debug screen, push HeatmapSpikeScreen onto route.
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:house_booking/core/widgets/ds.dart';

class HeatmapSpikeScreen extends StatelessWidget {
  const HeatmapSpikeScreen({super.key, this.rooms = 50, this.days = 31});

  final int rooms;
  final int days;

  static const double _cellSize = 28; // 24-28 dp per AC-08 a11y
  static const double _roomColWidth = 96;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: DsAppBar(
        title: 'Heatmap spike • $rooms rooms × $days days',
      ),
      body: Column(
        children: [
          _DayHeader(days: days, cellSize: _cellSize, roomColWidth: _roomColWidth),
          Expanded(
            child: ListView.builder(
              itemCount: rooms,
              itemExtent: _cellSize,
              itemBuilder: (ctx, roomIdx) {
                return _RoomRow(
                  roomIdx: roomIdx,
                  days: days,
                  cellSize: _cellSize,
                  roomColWidth: _roomColWidth,
                );
              },
            ),
          ),
          const _Legend(),
        ],
      ),
    );
  }
}

class _DayHeader extends StatelessWidget {
  const _DayHeader({
    required this.days,
    required this.cellSize,
    required this.roomColWidth,
  });

  final int days;
  final double cellSize;
  final double roomColWidth;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 32,
      child: Row(
        children: [
          SizedBox(width: roomColWidth, child: const _CornerCell()),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const NeverScrollableScrollPhysics(),
              child: Row(
                children: List.generate(days, (i) {
                  return SizedBox(
                    width: cellSize,
                    height: cellSize,
                    child: Center(
                      child: Text(
                        '${i + 1}',
                        style: const TextStyle(fontSize: 10, color: Colors.black54),
                      ),
                    ),
                  );
                }),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RoomRow extends StatelessWidget {
  const _RoomRow({
    required this.roomIdx,
    required this.days,
    required this.cellSize,
    required this.roomColWidth,
  });

  final int roomIdx;
  final int days;
  final double cellSize;
  final double roomColWidth;

  @override
  Widget build(BuildContext context) {
    final rng = Random(roomIdx);
    return Row(
      children: [
        // Sticky first col: room name.
        SizedBox(
          width: roomColWidth,
          height: cellSize,
          child: Container(
            color: HD.paperSunken,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            alignment: Alignment.centerLeft,
            child: Text(
              'P.${100 + roomIdx}',
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
            ),
          ),
        ),
        // Day cells.
        Expanded(
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            physics: const ClampingScrollPhysics(),
            itemCount: days,
            itemExtent: cellSize,
            itemBuilder: (ctx, dayIdx) {
              final state = rng.nextInt(4);
              return _Cell(state: state, size: cellSize);
            },
          ),
        ),
      ],
    );
  }
}

class _Cell extends StatelessWidget {
  const _Cell({required this.state, required this.size});

  final int state; // 0=vacant 1=booked 2=paid_checkin 3=overdue
  final double size;

  static const _colors = [
    Color(0xFFFFFFFF), // vacant — white
    Color(0xFFE3F2FD), // booked — light blue
    Color(0xFF42A5F5), // paid+checked-in — strong blue
    Color(0xFFE57373), // overdue — red
  ];

  static const _patterns = ['', '/', '+', '!']; // color-blind safe fallback chars

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: _colors[state],
        border: Border.all(color: HD.hairline, width: 0.5),
      ),
      alignment: Alignment.center,
      child: Text(
        _patterns[state],
        style: TextStyle(
          fontSize: 9,
          color: state == 2 ? Colors.white : Colors.black54,
        ),
      ),
    );
  }
}

class _CornerCell extends StatelessWidget {
  const _CornerCell();
  @override
  Widget build(BuildContext context) {
    return Container(
      color: HD.hairline,
      alignment: Alignment.center,
      child: const Text(
        'Phòng',
        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend();
  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _LegendChip(color: _Cell._colors[0], label: 'Trống'),
            _LegendChip(color: _Cell._colors[1], label: 'Đã đặt'),
            _LegendChip(color: _Cell._colors[2], label: 'Đã trả'),
            _LegendChip(color: _Cell._colors[3], label: 'Quá hạn'),
          ],
        ),
      ),
    );
  }
}

class _LegendChip extends StatelessWidget {
  const _LegendChip({required this.color, required this.label});
  final Color color;
  final String label;
  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 14, height: 14, color: color),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontSize: 11)),
      ],
    );
  }
}
