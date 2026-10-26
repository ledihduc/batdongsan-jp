import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:house_booking/core/widgets/ds_app_bar.dart';
import 'package:house_booking/features/host/dashboard/host_dashboard_tokens.dart';
import 'package:house_booking/features/host/homestay/providers/homestay_calendar_provider.dart';
import 'package:house_booking/features/host/homestay/widgets/calendar_day_cell.dart';
import 'package:house_booking/features/host/homestay/screens/room_calendar_screen.dart';

/// Phase 07 — multi-room month grid. Each row = a homestay room across the
/// month. Tap a cell → drill into single-room calendar.
class UnifiedCalendarScreen extends StatefulWidget {
  const UnifiedCalendarScreen({super.key});

  @override
  State<UnifiedCalendarScreen> createState() => _UnifiedCalendarScreenState();
}

class _UnifiedCalendarScreenState extends State<UnifiedCalendarScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<HomestayCalendarProvider>().fetchUnified();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: HD.paper,
      appBar: const DsAppBar(
        title: 'Lịch homestay',
      ),
      body: Consumer<HomestayCalendarProvider>(
        builder: (context, prov, _) {
          return Column(
            children: [
              _monthPicker(prov),
              const HDHairline(),
              if (prov.isLoading)
                const Padding(
                  padding: EdgeInsets.all(HD.s32),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (prov.error != null)
                Padding(
                  padding: const EdgeInsets.all(HD.s24),
                  child: Text(prov.error!, style: HD.body(color: HD.negative)),
                )
              else if (prov.unified == null || prov.unified!.rows.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(HD.s32),
                  child: Text(
                    'Chưa có phòng homestay. Thêm phòng để bắt đầu.',
                    style: HD.body(),
                  ),
                )
              else
                Expanded(child: _grid(prov)),
            ],
          );
        },
      ),
    );
  }

  Widget _monthPicker(HomestayCalendarProvider prov) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: HD.s20, vertical: HD.s12),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Tháng trước',
            icon: const Icon(Icons.chevron_left, color: HD.ink),
            onPressed: () => prov.shiftMonth(-1),
          ),
          Expanded(
            child: Center(
              child: Text(prov.month, style: HD.tabular(size: 18)),
            ),
          ),
          IconButton(
            tooltip: 'Tháng sau',
            icon: const Icon(Icons.chevron_right, color: HD.ink),
            onPressed: () => prov.shiftMonth(1),
          ),
        ],
      ),
    );
  }

  Widget _grid(HomestayCalendarProvider prov) {
    final rows = prov.unified!.rows;
    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: HD.s12),
      itemCount: rows.length,
      separatorBuilder: (_, __) => const SizedBox(height: HD.s12),
      itemBuilder: (context, i) {
        final row = rows[i];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: HD.s20),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '${row.buildingName} • ${row.roomCode}',
                      style: HD.bodyBold(),
                    ),
                  ),
                  TextButton(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            RoomCalendarScreen(roomId: row.roomId, roomLabel: row.roomCode),
                      ),
                    ),
                    child: Text('Mở', style: HD.eyebrow(color: HD.accent)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: HD.s8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: HD.s20),
              child: Row(
                children: [
                  for (final d in row.days)
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: CalendarDayCell(day: d, compact: true),
                    ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}
