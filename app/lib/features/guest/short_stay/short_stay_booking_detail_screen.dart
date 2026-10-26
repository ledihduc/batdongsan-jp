import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:house_booking/core/widgets/ds.dart';
import 'package:house_booking/data/models/reservation_model.dart';
import 'package:house_booking/data/services/short_stay_api.dart';
import 'package:house_booking/providers/chat_provider.dart';

const _roomAsset = 'assets/branding/short_stay_room_customer_v1.png';

/// Chi tiết một chuyến ở ngắn hạn của Khách hàng.
///
/// Đây là màn chỉ dành cho khách. Sale và Chủ nhà tiếp tục sử dụng workspace
/// vận hành hiện hữu để không làm thay đổi quyền hay thao tác nghiệp vụ.
class ShortStayBookingDetailScreen extends StatefulWidget {
  const ShortStayBookingDetailScreen({
    super.key,
    required this.reservation,
    this.api = const ShortStayApi(),
  });

  final ReservationModel reservation;
  final ShortStayApi api;

  @override
  State<ShortStayBookingDetailScreen> createState() =>
      _ShortStayBookingDetailScreenState();
}

class _ShortStayBookingDetailScreenState
    extends State<ShortStayBookingDetailScreen> {
  late ReservationModel _reservation;
  Map<String, dynamic>? _room;
  bool _loadingRoom = true;
  bool _working = false;
  StreamSubscription<Map<String, dynamic>>? _statusSub;
  bool _daNoiRealtime = false;

  @override
  void initState() {
    super.initState();
    _reservation = widget.reservation;
    _loadRoom();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_daNoiRealtime) return;
    _daNoiRealtime = true;
    try {
      _statusSub = context.read<ChatProvider>().statusEvents.listen((event) {
        final id = (event['entity_id'] as num?)?.toInt();
        if (event['entity'] == 'reservation' && id == _reservation.id) {
          _reloadReservation();
        }
      });
    } catch (_) {
      // Widget tests may mount this screen without ChatProvider.
    }
  }

  Future<void> _reloadReservation() async {
    try {
      final latest = await widget.api.reservation(_reservation.id);
      if (mounted && latest != null) setState(() => _reservation = latest);
    } catch (_) {}
  }

  @override
  void dispose() {
    _statusSub?.cancel();
    super.dispose();
  }

  Future<void> _loadRoom() async {
    try {
      final room = await widget.api.detail(_reservation.roomId);
      if (mounted) setState(() => _room = room);
    } catch (_) {
      // Thông tin trong snapshot đặt phòng vẫn đủ để hiển thị. Phòng có thể đã
      // ngừng mở bán nên endpoint công khai không còn trả dữ liệu.
    } finally {
      if (mounted) setState(() => _loadingRoom = false);
    }
  }

  Future<void> _cancel() async {
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Huỷ đặt phòng?'),
        content: Text(
          'Bạn muốn huỷ mã ${_reservation.bookingCode ?? '#${_reservation.id}'}? '
          'Phòng sẽ được mở lại theo chính sách đã hiển thị khi đặt.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Giữ đặt phòng'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Huỷ đặt phòng'),
          ),
        ],
      ),
    );
    if (accepted != true || !mounted) return;
    setState(() => _working = true);
    try {
      final result = await widget.api.cancel(_reservation.id);
      if (!mounted) return;
      setState(() => _reservation = result);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Đã huỷ đặt phòng.')));
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$error')));
      }
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final visual = _StatusVisual.of(_reservation);
    final address = [
      _room?['address'],
      _room?['district'],
      _room?['city'],
    ].whereType<String>().where((value) => value.trim().isNotEmpty).join(', ');
    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop && _reservation.status != widget.reservation.status) {
          // Navigator result is also set by the explicit leading action below
          // on older Flutter versions; parent always refreshes defensively.
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xfff7f9fc),
        appBar: AppBar(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
          title: const Text('Đặt phòng'),
          leading: IconButton(
            tooltip: 'Quay lại',
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: () => Navigator.pop(
              context,
              _reservation.status != widget.reservation.status,
            ),
          ),
        ),
        body: ListView(
          key: const Key('customer-short-stay-detail'),
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 32),
          children: [
            _statusHero(visual),
            const SizedBox(height: 12),
            _roomCard(address),
            const SizedBox(height: 12),
            _staySummary(),
            if ((_reservation.note ?? '').trim().isNotEmpty) ...[
              const SizedBox(height: 12),
              _section(
                title: 'Ghi chú',
                child: Text(
                  _reservation.note!,
                  style: HD.body(size: 13, color: HD.ink),
                ),
              ),
            ],
            if (_reservation.rejectionReason != null) ...[
              const SizedBox(height: 12),
              _notice(
                Icons.info_outline_rounded,
                'Lý do: ${_reservation.rejectionReason}',
                warning: true,
              ),
            ],
            const SizedBox(height: 18),
            if (_reservation.canCancel)
              SizedBox(
                height: 50,
                child: OutlinedButton.icon(
                  key: const Key('customer-short-stay-cancel-detail'),
                  onPressed: _working ? null : _cancel,
                  icon: _working
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.close_rounded),
                  label: const Text('Huỷ đặt phòng'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: HD.accent,
                    side: const BorderSide(color: HD.accent),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(13),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _staySummary() => _section(
    title: 'Chuyến ở',
    child: Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _dateBox(
                'NHẬN PHÒNG',
                _reservation.checkInAt ?? _reservation.checkInDate,
                Icons.login_rounded,
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 8),
              child: Icon(
                Icons.arrow_forward_rounded,
                size: 18,
                color: HD.inkMuted,
              ),
            ),
            Expanded(
              child: _dateBox(
                'TRẢ PHÒNG',
                _reservation.checkOutAt ?? _reservation.checkOutDate,
                Icons.logout_rounded,
              ),
            ),
          ],
        ),
        const Divider(height: 24),
        _moneyRow(
          'Tổng thanh toán',
          stayMoney(_reservation.totalAmount),
          strong: true,
        ),
        if (_reservation.depositPaid > 0)
          _moneyRow(
            'Đã thanh toán',
            stayMoney(_reservation.depositPaid),
            positive: true,
          ),
      ],
    ),
  );

  Widget _statusHero(_StatusVisual visual) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: visual.background,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: visual.color.withValues(alpha: .22)),
    ),
    child: Row(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(15),
          ),
          child: Icon(visual.icon, color: visual.color, size: 27),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                visual.label,
                style: HD.bodyBold(size: 17, color: visual.color),
              ),
              const SizedBox(height: 3),
              Text(
                visual.description,
                style: HD.body(size: 12, color: HD.inkMuted),
              ),
            ],
          ),
        ),
      ],
    ),
  );

  Widget _roomCard(String address) => Container(
    clipBehavior: Clip.antiAlias,
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: const Color(0xffe7eaf0)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Stack(
          children: [
            AspectRatio(
              aspectRatio: 16 / 8.2,
              child: Image.asset(_roomAsset, fit: BoxFit.cover),
            ),
            Positioned(
              top: 12,
              left: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xd9000000),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  shortStayModes[_reservation.bookingMode] ?? 'Ngắn hạn',
                  style: HD.bodyBold(size: 11.5, color: Colors.white),
                ),
              ),
            ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.all(15),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _reservation.buildingName ?? 'Nơi lưu trú',
                style: HD.bodyBold(size: 18, color: HD.ink),
              ),
              const SizedBox(height: 4),
              Text(
                '${_room?['room_type'] ?? _reservation.priceBreakdown?['room_type'] ?? 'Phòng'} · ${_reservation.roomCode ?? 'P${_reservation.roomId}'}',
                style: HD.body(size: 13, color: HD.inkMuted),
              ),
              if (address.isNotEmpty) ...[
                const SizedBox(height: 7),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.location_on_outlined,
                      size: 18,
                      color: HD.accent,
                    ),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Text(
                        address,
                        style: HD.body(size: 12, color: HD.inkMuted),
                      ),
                    ),
                  ],
                ),
              ] else if (_loadingRoom)
                const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: LinearProgressIndicator(minHeight: 2),
                ),
              const SizedBox(height: 10),
              Row(
                children: [
                  const Icon(Icons.confirmation_number_outlined, size: 17),
                  const SizedBox(width: 6),
                  Expanded(
                    child: SelectableText(
                      _reservation.bookingCode ?? '#${_reservation.id}',
                      style: HD.bodyBold(size: 12.5, color: HD.ink),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    ),
  );

  Widget _progress() {
    final current = switch (_reservation.status) {
      'pending' => 1,
      'approved' => 2,
      'checked_in' => 3,
      'checked_out' => 4,
      _ => 1,
    };
    const labels = ['Đã gửi', 'Xác nhận', 'Nhận phòng', 'Hoàn tất'];
    return _section(
      title: 'Tiến trình chuyến ở',
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var index = 0; index < labels.length; index++) ...[
            Expanded(
              child: Column(
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: index < current
                          ? HD.accent
                          : const Color(0xffeef1f5),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      index < current ? Icons.check_rounded : Icons.circle,
                      color: index < current ? Colors.white : HD.inkMuted,
                      size: index < current ? 18 : 8,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    labels[index],
                    textAlign: TextAlign.center,
                    style: index < current
                        ? HD.bodyBold(size: 10.5, color: HD.ink)
                        : HD.body(size: 10.5, color: HD.inkMuted),
                  ),
                ],
              ),
            ),
            if (index < labels.length - 1)
              Container(
                width: 18,
                height: 2,
                margin: const EdgeInsets.only(top: 14),
                color: index + 1 < current
                    ? HD.accent
                    : const Color(0xffe2e6ec),
              ),
          ],
        ],
      ),
    );
  }

  Widget _section({required String title, required Widget child}) => Container(
    padding: const EdgeInsets.all(15),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(17),
      border: Border.all(color: const Color(0xffe7eaf0)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: HD.bodyBold(size: 15, color: HD.ink)),
        const SizedBox(height: 12),
        child,
      ],
    ),
  );

  Widget _dateBox(String label, String value, IconData icon) {
    final display = value.contains('T') ? stayTime(value) : value;
    return Container(
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: const Color(0xfff8f9fb),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: HD.accent, size: 19),
          const SizedBox(height: 7),
          Text(label, style: HD.bodyBold(size: 9.5, color: HD.inkMuted)),
          const SizedBox(height: 2),
          Text(display, style: HD.bodyBold(size: 12, color: HD.ink)),
        ],
      ),
    );
  }

  Widget _moneyRow(
    String label,
    String value, {
    bool strong = false,
    bool positive = false,
  }) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: strong
                ? HD.bodyBold(size: 14, color: HD.ink)
                : HD.body(size: 12.5, color: HD.inkMuted),
          ),
        ),
        Text(
          value,
          style: HD.bodyBold(
            size: strong ? 16 : 12.5,
            color: positive
                ? const Color(0xff0b8f58)
                : (strong ? HD.accent : HD.ink),
          ),
        ),
      ],
    ),
  );

  Widget _notice(IconData icon, String text, {bool warning = false}) =>
      Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: warning ? const Color(0xfffff4e6) : const Color(0xffeef6ff),
          borderRadius: BorderRadius.circular(13),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              icon,
              size: 20,
              color: warning
                  ? const Color(0xffd97706)
                  : const Color(0xff2675d8),
            ),
            const SizedBox(width: 9),
            Expanded(
              child: Text(text, style: HD.body(size: 12, color: HD.inkMuted)),
            ),
          ],
        ),
      );
}

class _StatusVisual {
  const _StatusVisual(
    this.label,
    this.description,
    this.color,
    this.background,
    this.icon,
  );

  factory _StatusVisual.of(ReservationModel reservation) =>
      switch (reservation.status) {
        'approved' => const _StatusVisual(
          'Đã xác nhận',
          'Phòng đã được giữ cho bạn.',
          Color(0xff07824f),
          Color(0xffe9f8f0),
          Icons.event_available_rounded,
        ),
        'checked_in' => const _StatusVisual(
          'Đang lưu trú',
          'Bạn đã nhận phòng.',
          Color(0xff1769d2),
          Color(0xffeaf2ff),
          Icons.bed_rounded,
        ),
        'checked_out' => const _StatusVisual(
          'Đã hoàn tất',
          'Chuyến ở đã kết thúc.',
          Color(0xff5b6574),
          Color(0xfff0f2f5),
          Icons.check_circle_rounded,
        ),
        'cancelled' => const _StatusVisual(
          'Đã huỷ',
          'Đặt phòng này đã được huỷ.',
          Color(0xff707784),
          Color(0xfff1f2f4),
          Icons.cancel_outlined,
        ),
        'rejected' => const _StatusVisual(
          'Không được xác nhận',
          'Yêu cầu không được tiếp nhận.',
          Color(0xffc33a27),
          Color(0xffffeeeb),
          Icons.error_outline_rounded,
        ),
        _ => const _StatusVisual(
          'Chờ xác nhận',
          'Đã gửi yêu cầu.',
          Color(0xffc66b00),
          Color(0xfffff4e5),
          Icons.hourglass_top_rounded,
        ),
      };

  final String label;
  final String description;
  final Color color;
  final Color background;
  final IconData icon;
}
