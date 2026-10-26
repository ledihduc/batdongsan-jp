import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:house_booking/core/widgets/ds_app_bar.dart';
import 'package:house_booking/features/host/dashboard/host_dashboard_tokens.dart';
import 'package:house_booking/features/host/marketplace/providers/marketplace_provider.dart';

/// Phase 08 — approve a marketplace-sourced pending Reservation (homestay flow).
class CreateReservationFromBookingScreen extends StatefulWidget {
  const CreateReservationFromBookingScreen({
    super.key,
    required this.reservationId,
    required this.guestName,
    required this.checkInDate,
    required this.checkOutDate,
  });

  final int reservationId;
  final String guestName;
  final String checkInDate;
  final String checkOutDate;

  @override
  State<CreateReservationFromBookingScreen> createState() =>
      _CreateReservationFromBookingScreenState();
}

class _CreateReservationFromBookingScreenState
    extends State<CreateReservationFromBookingScreen> {
  bool _submitting = false;

  Future<void> _approve() async {
    setState(() => _submitting = true);
    final prov = context.read<MarketplaceProvider>();
    final ok = await prov.approveReservationFromBooking(widget.reservationId);
    if (!mounted) return;
    setState(() => _submitting = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(ok ? 'Đã duyệt đặt phòng' : (prov.error ?? 'Lỗi'))),
    );
    if (ok) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: HD.paper,
      appBar: const DsAppBar(
        title: 'Duyệt đặt phòng homestay',
      ),
      body: ListView(
        padding: const EdgeInsets.all(HD.s20),
        children: [
          Text(widget.guestName, style: HD.masthead()),
          const SizedBox(height: HD.s24),
          _row('Check-in', widget.checkInDate),
          _row('Check-out', widget.checkOutDate),
          _row('Mã đặt phòng', '#${widget.reservationId}'),
          const SizedBox(height: HD.s24),
          Container(
            padding: const EdgeInsets.all(HD.s16),
            decoration: BoxDecoration(
              color: HD.paperRaised,
              border: Border.all(color: HD.hairline),
            ),
            child: Text(
              'Duyệt sẽ chuyển đặt phòng từ "Chờ duyệt" sang "Đã duyệt" và '
              'khoá lịch các đêm tương ứng. Khách sẽ nhận thông báo.',
              style: HD.body(),
            ),
          ),
          const SizedBox(height: HD.s32),
          FilledButton(
            onPressed: _submitting ? null : _approve,
            style: FilledButton.styleFrom(
              backgroundColor: HD.positive,
              padding: const EdgeInsets.symmetric(vertical: HD.s16),
            ),
            child: Text(_submitting ? 'Đang duyệt…' : 'Duyệt đặt phòng'),
          ),
        ],
      ),
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(width: 110, child: Text(label.toUpperCase(), style: HD.eyebrow())),
          Expanded(child: Text(value, style: HD.body())),
        ],
      ),
    );
  }
}
