import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:house_booking/core/widgets/ds_app_bar.dart';
import 'package:house_booking/features/host/dashboard/host_dashboard_tokens.dart';
import 'package:house_booking/features/host/homestay/providers/homestay_calendar_provider.dart';
import 'package:house_booking/features/host/homestay/widgets/calendar_day_cell.dart';
import 'package:house_booking/features/host/homestay/screens/block_dates_screen.dart';

/// Phase 07 — single-room month calendar.
///
/// 7-column grid (Mon..Sun) with empty leading cells for the first week
/// so day-of-week alignment matches a paper calendar.
class RoomCalendarScreen extends StatefulWidget {
  const RoomCalendarScreen({
    super.key,
    required this.roomId,
    required this.roomLabel,
  });

  final int roomId;
  final String roomLabel;

  @override
  State<RoomCalendarScreen> createState() => _RoomCalendarScreenState();
}

class _RoomCalendarScreenState extends State<RoomCalendarScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<HomestayCalendarProvider>().fetchRoom(widget.roomId);
    });
  }

  /// Weekday of the first day in the month — used to compute leading blanks.
  int _firstWeekdayMondayBased(String month) {
    final parts = month.split('-');
    final dt = DateTime(int.parse(parts[0]), int.parse(parts[1]), 1);
    return dt.weekday - 1; // Mon=0..Sun=6
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: HD.paper,
      appBar: DsAppBar(
        title: 'Phòng ${widget.roomLabel}',
        actions: [
          IconButton(
            icon: const Icon(Icons.block, color: HD.ink),
            tooltip: 'Chặn lịch',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => BlockDatesScreen(roomId: widget.roomId),
              ),
            ),
          ),
        ],
      ),
      body: Consumer<HomestayCalendarProvider>(
        builder: (context, prov, _) {
          if (prov.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          final cal = prov.selected;
          if (cal == null) return const SizedBox.shrink();

          final leading = _firstWeekdayMondayBased(cal.month);
          final total = leading + cal.days.length;
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: HD.s20, vertical: HD.s12),
                child: Row(
                  children: [
                    IconButton(
                      tooltip: 'Tháng trước',
                      icon: const Icon(Icons.chevron_left),
                      onPressed: () =>
                          prov.shiftMonth(-1).then((_) => prov.fetchRoom(widget.roomId)),
                    ),
                    Expanded(
                      child: Center(
                        child: Text(cal.month, style: HD.tabular(size: 18)),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Tháng sau',
                      icon: const Icon(Icons.chevron_right),
                      onPressed: () =>
                          prov.shiftMonth(1).then((_) => prov.fetchRoom(widget.roomId)),
                    ),
                  ],
                ),
              ),
              const HDHairline(),
              _weekdayHeader(),
              Expanded(
                child: GridView.builder(
                  padding: const EdgeInsets.all(HD.s12),
                  gridDelegate:
                      const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 7,
                    childAspectRatio: 0.85,
                    mainAxisSpacing: 4,
                    crossAxisSpacing: 4,
                  ),
                  itemCount: total,
                  itemBuilder: (context, i) {
                    if (i < leading) return const SizedBox.shrink();
                    final day = cal.days[i - leading];
                    return CalendarDayCell(day: day, compact: true);
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _weekdayHeader() {
    const labels = ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN'];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: HD.s12, vertical: HD.s8),
      child: Row(
        children: [
          for (final l in labels)
            Expanded(
              child: Center(
                child: Text(l, style: HD.eyebrow()),
              ),
            ),
        ],
      ),
    );
  }
}
