import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:house_booking/core/widgets/ds.dart';
import 'package:house_booking/data/models/reservation_model.dart';
import 'package:house_booking/data/services/ca_thue_api.dart';
import 'package:house_booking/data/services/dat_phong_api.dart';
import 'package:house_booking/data/services/short_stay_api.dart';
import 'package:house_booking/features/guest/short_stay/short_stay_booking_detail_screen.dart';
import 'package:house_booking/features/guest/booking/phieu_dat_phong_screen.dart';
import 'package:house_booking/features/guest/short_stay/short_stay_operations_role.dart';
import 'package:house_booking/features/guest/short_stay/short_stay_rooms_screen.dart';
import 'package:house_booking/features/host/ngan_han/ca_thue/chi_tiet_ca_thue_screen.dart';
import 'package:house_booking/providers/chat_provider.dart';

class ShortStayBookingsScreen extends StatefulWidget {
  const ShortStayBookingsScreen({
    super.key,
    this.operations = false,
    this.operationsRole = ShortStayOperationsRole.sale,
    this.api = const ShortStayApi(),
    this.datPhongApi = const DatPhongApi(),
    this.caThueApi = const CaThueApi(),
    this.locBanDau = 'all',
    this.homNayBanDau = false,
  });

  /// Mở sẵn một bộ lọc vận hành — 'all' | 'pending' | 'upcoming' | 'staying'
  /// | 'history' — khi đi từ ô số đếm ở trang chủ chủ nhà.
  final String locBanDau;

  /// Mở sẵn phạm vi "Hôm nay" thay vì "Tất cả booking".
  final bool homNayBanDau;
  final bool operations;
  final ShortStayOperationsRole operationsRole;
  final ShortStayApi api;
  final DatPhongApi datPhongApi;
  final CaThueApi caThueApi;
  @override
  State<ShortStayBookingsScreen> createState() =>
      _ShortStayBookingsScreenState();
}

class _ShortStayBookingsScreenState extends State<ShortStayBookingsScreen> {
  List<ReservationModel> _rows = [];
  bool _loading = true, _today = false, _working = false;
  String _customerFilter = 'all';
  String _operationFilter = 'all';
  StreamSubscription<Map<String, dynamic>>? _statusSub;
  bool _daNoiRealtime = false;

  bool _isOperationHistory(ReservationModel row) =>
      row.isCheckedOut ||
      row.isCancelled ||
      row.isRejected ||
      row.status == 'no_show';
  String? _error;
  @override
  void initState() {
    super.initState();
    _operationFilter = widget.locBanDau;
    _today = widget.homNayBanDau;
    _load();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_daNoiRealtime) return;
    _daNoiRealtime = true;
    try {
      _statusSub = context.read<ChatProvider>().statusEvents.listen((event) {
        if (event['entity'] == 'reservation') _load(amTham: true);
      });
    } catch (_) {
      // Widget tests may mount this screen without ChatProvider.
    }
  }

  @override
  void dispose() {
    _statusSub?.cancel();
    super.dispose();
  }

  Future<void> _load({bool amTham = false}) async {
    if (!amTham) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final rows = await widget.api.bookings(
        operations: widget.operations,
        today: _today,
      );
      if (mounted) setState(() => _rows = rows);
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _action(ReservationModel r, String action, String label) async {
    final reason = TextEditingController();
    final accepted = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('$label?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Đặt phòng ${r.bookingCode}'),
            if (action == 'cancel')
              const Text(
                'Huỷ đặt phòng sẽ mở lại phòng. Ứng dụng chưa thu tiền và không thực hiện hoàn tiền.',
              ),
            if (action == 'reject' || action == 'cancel')
              TextField(
                controller: reason,
                decoration: InputDecoration(
                  labelText: action == 'reject'
                      ? 'Lý do từ chối *'
                      : 'Lý do huỷ',
                ),
                maxLength: 300,
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Đóng'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(label),
          ),
        ],
      ),
    );
    final note = reason.text.trim();
    // The dialog's exit animation still owns the TextField until the next frame.
    WidgetsBinding.instance.addPostFrameCallback((_) => reason.dispose());
    if (accepted != true || !mounted) return;
    if (action == 'reject' && note.isEmpty) {
      setState(() => _error = 'Vui lòng nhập lý do từ chối.');
      return;
    }
    setState(() => _working = true);
    try {
      if (widget.operations) {
        await widget.api.action(r.id, action, note);
      } else {
        await widget.api.cancel(r.id);
      }
      await _load();
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  @override
  Widget build(BuildContext context) =>
      widget.operations ? _operationsScreen() : _customerScreen();

  Widget _customerScreen() {
    final filtered = _rows.where((row) {
      if (_customerFilter == 'upcoming') {
        return row.isPending || row.isApproved || row.isCheckedIn;
      }
      if (_customerFilter == 'history') {
        return !(row.isPending || row.isApproved || row.isCheckedIn);
      }
      return true;
    }).toList();
    return Scaffold(
      backgroundColor: const Color(0xfff7f9fc),
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        title: const Text('Lịch lưu trú'),
        actions: [
          IconButton(
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Tải lại',
          ),
        ],
      ),
      body: RefreshIndicator(
        color: HD.accent,
        onRefresh: _load,
        child: ListView(
          key: const Key('customer-short-stay-bookings'),
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 32),
          children: [
            _customerFilters(),
            if (_error != null) ...[
              const SizedBox(height: 12),
              _customerNotice(
                Icons.cloud_off_rounded,
                _error!,
                const Color(0xffffeeeb),
                HD.accent,
              ),
            ],
            const SizedBox(height: 17),
            Row(
              children: [
                Expanded(
                  child: Text(
                    _customerFilter == 'history'
                        ? 'Lịch sử lưu trú'
                        : _customerFilter == 'upcoming'
                        ? 'Chuyến ở sắp tới'
                        : 'Tất cả đặt phòng',
                    style: HD.bodyBold(size: 15, color: HD.ink),
                  ),
                ),
                Text(
                  '${filtered.length} lịch',
                  style: HD.body(size: 12.5, color: HD.inkMuted),
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (_loading)
              const Padding(
                padding: EdgeInsets.all(46),
                child: Center(
                  child: CircularProgressIndicator(color: HD.accent),
                ),
              )
            else if (filtered.isEmpty)
              _customerEmpty()
            else
              for (final reservation in filtered) ...[
                _customerBookingCard(reservation),
                const SizedBox(height: 11),
              ],
          ],
        ),
      ),
    );
  }

  Widget _customerFilters() => Container(
    padding: const EdgeInsets.all(4),
    decoration: BoxDecoration(
      color: const Color(0xffeceff4),
      borderRadius: BorderRadius.circular(14),
    ),
    child: Row(
      children: [
        _customerFilterButton('all', 'Tất cả', _rows.length),
        _customerFilterButton(
          'upcoming',
          'Sắp tới',
          _rows
              .where(
                (row) => row.isPending || row.isApproved || row.isCheckedIn,
              )
              .length,
        ),
        _customerFilterButton(
          'history',
          'Lịch sử',
          _rows
              .where(
                (row) => !(row.isPending || row.isApproved || row.isCheckedIn),
              )
              .length,
        ),
      ],
    ),
  );

  Widget _customerFilterButton(String value, String label, int count) =>
      Expanded(
        child: Material(
          color: _customerFilter == value ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(11),
          child: InkWell(
            key: Key('customer-short-stay-filter-$value'),
            onTap: () => setState(() => _customerFilter = value),
            borderRadius: BorderRadius.circular(11),
            child: Container(
              height: 40,
              alignment: Alignment.center,
              decoration: _customerFilter == value
                  ? BoxDecoration(
                      borderRadius: BorderRadius.circular(11),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x10000000),
                          blurRadius: 8,
                          offset: Offset(0, 2),
                        ),
                      ],
                    )
                  : null,
              child: Text(
                '$label ($count)',
                style: _customerFilter == value
                    ? HD.bodyBold(size: 11.5, color: HD.accent)
                    : HD.body(size: 11.5, color: HD.inkMuted),
              ),
            ),
          ),
        ),
      );

  Future<void> _openCustomerDetail(ReservationModel reservation) async {
    // Đơn theo giờ/đêm/ngày mở PHIẾU (mã, QR, đổi giờ, sửa, huỷ) — cùng màn
    // với trang Hoạt động. Màn chi tiết cũ chỉ còn cho đơn theo đêm di sản,
    // vì phiếu không có dữ liệu cho đơn không có hình thức.
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => reservation.bookingMode != null
            ? PhieuDatPhongScreen(
                reservationId: reservation.id,
                api: widget.datPhongApi,
              )
            : ShortStayBookingDetailScreen(
                reservation: reservation,
                api: widget.api,
              ),
      ),
    );
    if (mounted) await _load();
  }

  Widget _customerBookingCard(ReservationModel reservation) {
    final visual = _GuestBookingVisual.of(reservation);
    final roomType =
        reservation.priceBreakdown?['room_type'] as String? ?? 'Phòng';
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        key: Key('customer-short-stay-booking-${reservation.id}'),
        onTap: () => _openCustomerDetail(reservation),
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(11),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xffe5e9ef)),
          ),
          child: Column(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(13),
                    child: Image.asset(
                      'assets/branding/short_stay_room_customer_v1.png',
                      width: 108,
                      height: 92,
                      fit: BoxFit.cover,
                    ),
                  ),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                reservation.buildingName ?? 'Nơi lưu trú',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: HD.bodyBold(size: 14.5, color: HD.ink),
                              ),
                            ),
                            const Icon(
                              Icons.chevron_right_rounded,
                              size: 21,
                              color: HD.inkMuted,
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '$roomType · ${reservation.roomCode ?? 'P${reservation.roomId}'}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: HD.body(size: 11.5, color: HD.inkMuted),
                        ),
                        const SizedBox(height: 7),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: visual.background,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            visual.label,
                            style: HD.bodyBold(size: 10.5, color: visual.color),
                          ),
                        ),
                        const SizedBox(height: 7),
                        Text(
                          shortStayModes[reservation.bookingMode] ?? 'Ngắn hạn',
                          style: HD.bodyBold(size: 11.5, color: HD.ink),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 11),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 9,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xfff7f8fa),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.schedule_rounded,
                      size: 18,
                      color: HD.accent,
                    ),
                    const SizedBox(width: 7),
                    Expanded(
                      child: Text(
                        '${stayTime(reservation.checkInAt)} → ${stayTime(reservation.checkOutAt)}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: HD.body(size: 11.5, color: HD.ink),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 9),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          reservation.bookingCode ?? '#${reservation.id}',
                          style: HD.body(size: 10.5, color: HD.inkMuted),
                        ),
                        Text(
                          stayMoney(reservation.totalAmount),
                          style: HD.bodyBold(size: 15, color: HD.accent),
                        ),
                      ],
                    ),
                  ),
                  if (reservation.canCancel)
                    TextButton(
                      onPressed: _working
                          ? null
                          : () =>
                                _action(reservation, 'cancel', 'Huỷ đặt phòng'),
                      child: const Text('Huỷ đặt phòng'),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _customerEmpty() => Container(
    padding: const EdgeInsets.all(28),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: const Color(0xffe5e9ef)),
    ),
    child: Column(
      children: [
        const Icon(Icons.luggage_outlined, size: 42, color: HD.inkMuted),
        const SizedBox(height: 10),
        Text(
          'Chưa có lịch trong nhóm này',
          style: HD.bodyBold(size: 14, color: HD.ink),
        ),
        const SizedBox(height: 4),
        Text(
          'Các đặt phòng mới và chuyến ở đã hoàn tất sẽ hiển thị tại đây.',
          textAlign: TextAlign.center,
          style: HD.body(size: 12, color: HD.inkMuted),
        ),
      ],
    ),
  );

  Widget _customerNotice(
    IconData icon,
    String text,
    Color background,
    Color foreground,
  ) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: background,
      borderRadius: BorderRadius.circular(13),
    ),
    child: Row(
      children: [
        Icon(icon, color: foreground, size: 20),
        const SizedBox(width: 9),
        Expanded(
          child: Text(text, style: HD.body(size: 12, color: HD.inkMuted)),
        ),
      ],
    ),
  );

  Widget _operationsScreen() {
    final isOwner = widget.operationsRole == ShortStayOperationsRole.owner;
    final filtered = _rows.where((row) {
      return switch (_operationFilter) {
        'pending' => row.isPending,
        'upcoming' => row.isApproved,
        'staying' => row.isCheckedIn,
        'history' => _isOperationHistory(row),
        _ => true,
      };
    }).toList();
    final pending = _rows.where((row) => row.isPending).length;
    final approved = _rows.where((row) => row.isApproved).length;
    final staying = _rows.where((row) => row.isCheckedIn).length;
    final history = _rows.where(_isOperationHistory).length;

    return Scaffold(
      backgroundColor: const Color(0xfff7f9fc),
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        title: Text(isOwner ? 'Vận hành ngắn hạn' : 'Điều phối ngắn hạn'),
        actions: [
          IconButton(
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Tải lại',
          ),
        ],
      ),
      body: RefreshIndicator(
        color: HD.accent,
        onRefresh: _load,
        child: ListView(
          key: Key('short-stay-${isOwner ? 'owner' : 'sale'}-operations'),
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 32),
          children: [
            _operationScope(),
            const SizedBox(height: 9),
            Row(
              children: [
                Expanded(
                  child: _operationCounter(
                    'Chờ duyệt',
                    pending,
                    Icons.pending_actions_rounded,
                    const Color(0xffd96c00),
                    const Color(0xfffff2df),
                    'pending',
                  ),
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: _operationCounter(
                    'Sắp nhận phòng',
                    approved,
                    Icons.event_available_rounded,
                    const Color(0xff276bd7),
                    const Color(0xffeaf2ff),
                    'upcoming',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 9),
            Row(
              children: [
                Expanded(
                  child: _operationCounter(
                    'Đang lưu trú',
                    staying,
                    Icons.bed_rounded,
                    const Color(0xff087c72),
                    const Color(0xffe7f7f4),
                    'staying',
                  ),
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: _operationCounter(
                    'Đã hoàn tất',
                    history,
                    Icons.history_rounded,
                    const Color(0xff68717e),
                    const Color(0xffeef0f3),
                    'history',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 15),
            _operationQuickActions(isOwner),
            if (_error != null) ...[
              const SizedBox(height: 12),
              _customerNotice(
                Icons.cloud_off_rounded,
                _error!,
                const Color(0xffffeeeb),
                HD.accent,
              ),
            ],
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: Text(
                    _operationTitle(),
                    style: HD.bodyBold(size: 15, color: HD.ink),
                  ),
                ),
                TextButton(
                  onPressed: _operationFilter == 'all'
                      ? null
                      : () => setState(() => _operationFilter = 'all'),
                  child: Text('${filtered.length} booking'),
                ),
              ],
            ),
            if (_loading)
              const Padding(
                padding: EdgeInsets.all(46),
                child: Center(
                  child: CircularProgressIndicator(color: HD.accent),
                ),
              )
            else if (filtered.isEmpty)
              _operationEmpty()
            else
              for (final reservation in filtered) ...[
                _operationBookingCard(reservation),
                const SizedBox(height: 11),
              ],
          ],
        ),
      ),
    );
  }

  Widget _operationScope() => Container(
    padding: const EdgeInsets.all(4),
    decoration: BoxDecoration(
      color: const Color(0xffeceff4),
      borderRadius: BorderRadius.circular(13),
    ),
    child: Row(
      children: [
        Expanded(
          child: _operationScopeButton('Tất cả booking', !_today, () {
            if (!_today) return;
            setState(() => _today = false);
            _load();
          }),
        ),
        Expanded(
          child: _operationScopeButton('Hôm nay', _today, () {
            if (_today) return;
            setState(() => _today = true);
            _load();
          }),
        ),
      ],
    ),
  );

  Widget _operationScopeButton(
    String label,
    bool selected,
    VoidCallback onTap,
  ) => Material(
    color: selected ? Colors.white : Colors.transparent,
    borderRadius: BorderRadius.circular(10),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: SizedBox(
        height: 38,
        child: Center(
          child: Text(
            label,
            style: selected
                ? HD.bodyBold(size: 12, color: HD.accent)
                : HD.body(size: 12, color: HD.inkMuted),
          ),
        ),
      ),
    ),
  );

  Widget _operationCounter(
    String label,
    int value,
    IconData icon,
    Color color,
    Color background,
    String filter,
  ) => Material(
    color: Colors.white,
    borderRadius: BorderRadius.circular(15),
    child: InkWell(
      onTap: () => setState(() => _operationFilter = filter),
      borderRadius: BorderRadius.circular(15),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(15),
          border: Border.all(
            color: _operationFilter == filter
                ? color.withValues(alpha: .45)
                : const Color(0xffe5e9ef),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: background,
                borderRadius: BorderRadius.circular(11),
              ),
              child: Icon(icon, color: color, size: 21),
            ),
            const SizedBox(width: 9),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('$value', style: HD.bodyBold(size: 18, color: HD.ink)),
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: HD.body(size: 10.5, color: HD.inkMuted),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );

  Widget _operationQuickActions(bool isOwner) => Row(
    children: [
      Expanded(
        child: _operationAction(
          Icons.meeting_room_outlined,
          'Giá & khóa phòng',
          () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ShortStayRoomsScreen(api: widget.api),
            ),
          ),
        ),
      ),
      const SizedBox(width: 9),
      Expanded(
        child: _operationAction(
          Icons.history_rounded,
          'Lịch sử booking',
          () => setState(() => _operationFilter = 'history'),
        ),
      ),
    ],
  );

  Widget _operationAction(IconData icon, String label, VoidCallback onTap) =>
      Material(
        color: const Color(0xfffff0f1),
        borderRadius: BorderRadius.circular(13),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(13),
          child: Container(
            height: 48,
            padding: const EdgeInsets.symmetric(horizontal: 11),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 19, color: HD.accent),
                const SizedBox(width: 7),
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: HD.bodyBold(size: 11.5, color: HD.accent),
                  ),
                ),
              ],
            ),
          ),
        ),
      );

  String _operationTitle() => switch (_operationFilter) {
    'pending' => 'Yêu cầu chờ duyệt',
    'upcoming' => 'Sắp nhận phòng',
    'staying' => 'Khách đang lưu trú',
    'history' => 'Lịch sử booking',
    _ => 'Booking cần theo dõi',
  };

  Future<void> _openOperationDetail(ReservationModel reservation) async {
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        // Một màn đơn duy nhất cho chủ nhà lẫn sale: quầy lễ tân. Màn tự ẩn
        // phần tiền với người không có quyền tài chính.
        builder: (_) => ChiTietCaThueScreen(
          reservationId: reservation.id,
          api: widget.caThueApi,
          shortStayApi: widget.api,
        ),
      ),
    );
    if (mounted) await _load();
  }

  Widget _operationBookingCard(ReservationModel reservation) {
    final visual = _GuestBookingVisual.of(reservation);
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(17),
      child: InkWell(
        key: Key('short-stay-operation-booking-${reservation.id}'),
        onTap: () => _openOperationDetail(reservation),
        borderRadius: BorderRadius.circular(17),
        child: Container(
          padding: const EdgeInsets.all(11),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(17),
            border: Border.all(color: const Color(0xffe5e9ef)),
          ),
          child: Column(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.asset(
                      'assets/branding/short_stay_room_customer_v1.png',
                      width: 88,
                      height: 78,
                      fit: BoxFit.cover,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: visual.background,
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Text(
                                visual.label,
                                style: HD.bodyBold(
                                  size: 9.5,
                                  color: visual.color,
                                ),
                              ),
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                reservation.bookingCode ?? '#${reservation.id}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.end,
                                style: HD.body(size: 9.5, color: HD.inkMuted),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 7),
                        Text(
                          reservation.buildingName ?? 'Nơi lưu trú',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: HD.bodyBold(size: 13.5, color: HD.ink),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${reservation.roomCode ?? 'P${reservation.roomId}'} · ${reservation.guestName}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: HD.body(size: 11, color: HD.inkMuted),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right_rounded, color: HD.inkMuted),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  const Icon(
                    Icons.schedule_rounded,
                    size: 17,
                    color: HD.accent,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      '${stayTime(reservation.checkInAt)} → ${stayTime(reservation.checkOutAt)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: HD.body(size: 11, color: HD.ink),
                    ),
                  ),
                  Text(
                    stayMoney(reservation.totalAmount),
                    style: HD.bodyBold(size: 12.5, color: HD.accent),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _operationEmpty() => Container(
    padding: const EdgeInsets.all(27),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(17),
      border: Border.all(color: const Color(0xffe5e9ef)),
    ),
    child: Column(
      children: [
        const Icon(Icons.hotel_class_outlined, size: 40, color: HD.inkMuted),
        const SizedBox(height: 9),
        Text(
          'Chưa có booking trong nhóm này',
          style: HD.bodyBold(size: 14, color: HD.ink),
        ),
        const SizedBox(height: 4),
        Text(
          'Booking mới sẽ tự động xuất hiện khi được phân công.',
          textAlign: TextAlign.center,
          style: HD.body(size: 12, color: HD.inkMuted),
        ),
      ],
    ),
  );
}

class _GuestBookingVisual {
  const _GuestBookingVisual(this.label, this.color, this.background);

  factory _GuestBookingVisual.of(ReservationModel reservation) =>
      switch (reservation.status) {
        'approved' => const _GuestBookingVisual(
          'Đã xác nhận',
          Color(0xff07824f),
          Color(0xffe7f7ef),
        ),
        'checked_in' => const _GuestBookingVisual(
          'Đang lưu trú',
          Color(0xff1769d2),
          Color(0xffeaf2ff),
        ),
        'checked_out' => const _GuestBookingVisual(
          'Đã hoàn tất',
          Color(0xff626b78),
          Color(0xffeef0f3),
        ),
        'cancelled' => const _GuestBookingVisual(
          'Đã huỷ',
          Color(0xff6e7580),
          Color(0xffeff0f2),
        ),
        'rejected' => const _GuestBookingVisual(
          'Không xác nhận',
          Color(0xffc33a27),
          Color(0xffffeeeb),
        ),
        _ => const _GuestBookingVisual(
          'Chờ xác nhận',
          Color(0xffc66b00),
          Color(0xfffff2df),
        ),
      };

  final String label;
  final Color color;
  final Color background;
}
