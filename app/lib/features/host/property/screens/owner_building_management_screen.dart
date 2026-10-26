import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:house_booking/core/widgets/ds.dart';
import 'package:house_booking/data/models/room_model.dart';
import 'package:house_booking/data/services/tong_quan_chu_nha_api.dart';
import 'package:house_booking/features/guest/short_stay/short_stay_bookings_screen.dart';
import 'package:house_booking/features/guest/short_stay/short_stay_operations_role.dart';
import 'package:house_booking/features/guest/short_stay/short_stay_rooms_screen.dart';
import 'package:house_booking/features/host/appointments/host_appointments_screen.dart';
import 'package:house_booking/features/host/billing/screens/invoice_list_screen.dart';
import 'package:house_booking/features/host/dien_nuoc/dien_nuoc_dai_han_screen.dart';
import 'package:house_booking/features/host/khach_thue/khach_thue_screen.dart';
import 'package:house_booking/features/host/ngan_han/lich_ngan_han_screen.dart';
import 'package:house_booking/features/host/ngan_han/loai_phong_screen.dart';
import 'package:house_booking/features/host/property/providers/room_provider.dart';
import 'package:house_booking/features/host/property/screens/building_detail_screen.dart';
import 'package:house_booking/features/host/quan_ly_dai_han/doanh_thu_screen.dart';
import 'package:house_booking/features/host/quan_ly_dai_han/hoa_don_screen.dart';
import 'package:house_booking/features/host/quan_ly_dai_han/hop_dong_screen.dart';
import 'package:house_booking/features/host/quan_ly_dai_han/khach_hang_screen.dart';
import 'package:house_booking/features/host/property/screens/room_detail_screen.dart';
import 'package:house_booking/features/host/reports/screens/reports_home_screen.dart';
import 'package:house_booking/features/notifications/notifications_screen.dart';

/// Workspace cấp tòa dành riêng cho Chủ nhà.
///
/// Màn chỉ nằm trong Navigator của tab Hoạt động, không dựng bottom navigation
/// mới. Những module vận hành cũ vẫn là nguồn sự thật; workspace này chỉ làm
/// lối vào rõ ràng theo đúng ba tầng: tổng quan → dài hạn / ngắn hạn.
class OwnerBuildingManagementScreen extends StatefulWidget {
  const OwnerBuildingManagementScreen({
    super.key,
    required this.buildingId,
    required this.buildingName,
    this.address = '',
    this.hostId,
    this.api = const TongQuanChuNhaApi(),
    this.roomProvider,
  });

  final int buildingId;
  final String buildingName;
  final String address;
  final int? hostId;
  final TongQuanChuNhaApi api;
  final RoomProvider? roomProvider;

  @override
  State<OwnerBuildingManagementScreen> createState() =>
      _OwnerBuildingManagementScreenState();
}

class _OwnerBuildingManagementScreenState
    extends State<OwnerBuildingManagementScreen> {
  late final RoomProvider _rooms = widget.roomProvider ?? RoomProvider();
  bool get _ownsRooms => widget.roomProvider == null;
  TongQuanChuNha? _summary;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    if (_ownsRooms) _rooms.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final calls = <Future<void>>[
        widget.api.lay(buildingId: widget.buildingId).then((value) {
          _summary = value;
        }),
        if (_ownsRooms) _rooms.fetchRooms(widget.buildingId),
      ];
      await Future.wait(calls);
    } catch (_) {
      _error = 'Chưa tải được toàn bộ số liệu của tòa nhà.';
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _push(Widget screen) =>
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));

  @override
  Widget build(BuildContext context) => ChangeNotifierProvider.value(
    value: _rooms,
    child: Scaffold(
      backgroundColor: const Color(0xfff7f9fc),
      appBar: _appBar(
        context,
        title: 'Quản lý',
        trailing: IconButton(
          tooltip: 'Thông báo',
          onPressed: () => _push(const NotificationsScreen()),
          icon: const Icon(Icons.notifications_none_rounded),
        ),
      ),
      body: Consumer<RoomProvider>(
        builder: (_, rooms, _) => RefreshIndicator(
          color: HD.accent,
          onRefresh: _load,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            children: [
              _rolePill(),
              const SizedBox(height: 12),
              _buildingHero(),
              const SizedBox(height: 18),
              _sectionTitle('Tổng quan tòa nhà'),
              const SizedBox(height: 10),
              _overviewMetrics(rooms.rooms),
              const SizedBox(height: 12),
              _mixCard(rooms.rooms),
              const SizedBox(height: 12),
              _attentionCard(rooms.rooms),
              if (_error != null) ...[
                const SizedBox(height: 10),
                _notice(_error!, HD.warning),
              ],
              if (_loading) ...[
                const SizedBox(height: 10),
                const LinearProgressIndicator(minHeight: 2, color: HD.accent),
              ],
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: _modeCard(
                      key: const Key('owner-building-long-term'),
                      title: 'Quản lý dài hạn',
                      subtitle: 'Hợp đồng, khách thuê, hóa đơn',
                      icon: Icons.home_rounded,
                      tint: const Color(0xffe8f8f1),
                      color: const Color(0xff078a59),
                      onTap: () => _openLong(rooms.rooms),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _modeCard(
                      key: const Key('owner-building-short-term'),
                      title: 'Quản lý ngắn hạn',
                      subtitle: 'Booking, check-in, doanh thu',
                      icon: Icons.nightlight_round,
                      tint: const Color(0xfffff0e4),
                      color: const Color(0xffc75b0a),
                      onTap: () => _openShort(rooms.rooms),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              _modeCard(
                key: const Key('owner-building-flexible'),
                title: 'Quản lý linh hoạt',
                subtitle:
                    'Một phòng vật lý, kết hợp dài hạn và ngắn hạn theo lịch',
                icon: Icons.hub_rounded,
                tint: const Color(0xfff2ebff),
                color: const Color(0xff7046c7),
                onTap: () => _openFlexible(rooms.rooms),
              ),
            ],
          ),
        ),
      ),
    ),
  );

  void _openLong(List<RoomModel> rooms) => _push(
    OwnerLongTermManagementScreen(
      buildingId: widget.buildingId,
      buildingName: widget.buildingName,
      hostId: widget.hostId,
      rooms: rooms,
      summary: _summary,
      roomProvider: _rooms,
    ),
  );

  void _openShort(List<RoomModel> rooms) => _push(
    OwnerShortTermManagementScreen(
      buildingId: widget.buildingId,
      buildingName: widget.buildingName,
      rooms: rooms,
      summary: _summary,
    ),
  );

  void _openFlexible(List<RoomModel> rooms) => _push(
    OwnerFlexibleRoomsScreen(
      buildingName: widget.buildingName,
      rooms: rooms,
      roomProvider: _rooms,
    ),
  );

  Widget _rolePill() => Align(
    alignment: Alignment.centerRight,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0xffe5f5ef),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.home_rounded, size: 15, color: Color(0xff078a59)),
          const SizedBox(width: 6),
          Text(
            'Chủ nhà',
            style: HD.bodyBold(size: 12, color: const Color(0xff078a59)),
          ),
        ],
      ),
    ),
  );

  Widget _buildingHero() => _ImageHero(
    asset: 'assets/branding/owner-building-hub-v1.webp',
    height: 132,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Text(
          widget.buildingName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: HD.bodyBold(size: 18, color: const Color(0xff132238)),
        ),
        if (widget.address.trim().isNotEmpty) ...[
          const SizedBox(height: 3),
          Text(
            widget.address,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: HD.body(size: 11.5, color: HD.inkMuted),
          ),
        ],
        const SizedBox(height: 8),
        Wrap(
          spacing: 7,
          children: [
            _smallChip('Tòa nhà', const Color(0xff078a59)),
            _smallChip('Đang hoạt động', const Color(0xff078a59)),
            InkWell(
              onTap: () => _push(
                BuildingDetailScreen(
                  buildingId: widget.buildingId,
                  buildingName: widget.buildingName,
                  hostId: widget.hostId,
                ),
              ),
              borderRadius: BorderRadius.circular(999),
              child: _smallChip('Chỉnh sửa', HD.accent),
            ),
          ],
        ),
      ],
    ),
  );

  Widget _overviewMetrics(List<RoomModel> rooms) {
    final used = rooms.where((r) => r.dangThue).length;
    return Row(
      children: [
        Expanded(
          child: _MetricCard(
            icon: Icons.apartment_rounded,
            color: const Color(0xff246be8),
            value: '${rooms.length}',
            label: 'Tổng số phòng',
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _MetricCard(
            icon: Icons.bed_rounded,
            color: const Color(0xff078a59),
            value: '$used',
            label: 'Đang khai thác',
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _MetricCard(
            icon: Icons.bar_chart_rounded,
            color: const Color(0xff078a59),
            value: _money(_summary?.doanhThuThang),
            label: 'Doanh thu tháng',
          ),
        ),
      ],
    );
  }

  Widget _mixCard(List<RoomModel> rooms) {
    int count(String type) => rooms.where((r) => r.loai.contains(type)).length;
    final items = [
      (
        Icons.home_rounded,
        'Dài hạn',
        count('dai_han'),
        const Color(0xff078a59),
      ),
      (
        Icons.bed_rounded,
        'Ngắn hạn',
        count('ngan_han'),
        const Color(0xffc75b0a),
      ),
      (
        Icons.hub_rounded,
        'Linh hoạt',
        rooms
            .where(
              (r) => r.loai.contains('dai_han') && r.loai.contains('ngan_han'),
            )
            .length,
        const Color(0xff7046c7),
      ),
      (
        Icons.build_rounded,
        'Đang bảo trì',
        rooms.where((r) => r.tinhTrangHien == 'bao_tri').length,
        HD.accent,
      ),
    ];
    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Cơ cấu khai thác phòng', style: HD.bodyBold(size: 13.5)),
          const SizedBox(height: 12),
          Row(
            children: [
              for (var i = 0; i < items.length; i++) ...[
                if (i > 0) const SizedBox(width: 7),
                Expanded(
                  child: _MiniMetric(
                    icon: items[i].$1,
                    label: items[i].$2,
                    value: '${items[i].$3}',
                    color: items[i].$4,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _attentionCard(List<RoomModel> rooms) {
    final now = DateTime.now();
    final soon = rooms.where((r) {
      final end = DateTime.tryParse(r.hopDongDen ?? '');
      return end != null &&
          !end.isBefore(now) &&
          end.difference(now).inDays <= 30;
    }).length;
    final debt = _longBlock(_summary)?.phongNo ?? 0;
    final maintenance = rooms.where((r) => r.tinhTrangHien == 'bao_tri').length;
    return _Panel(
      color: const Color(0xfffff6f6),
      border: const Color(0xffffd9dd),
      child: Column(
        children: [
          _rowTitle(
            'Việc cần xử lý',
            action: 'Xem tất cả',
            onTap: () => _openLong(rooms),
          ),
          const SizedBox(height: 8),
          _infoRow(
            Icons.description_outlined,
            '$soon hợp đồng sắp hết hạn (≤ 30 ngày)',
            HD.accent,
          ),
          _infoRow(
            Icons.payments_outlined,
            '$debt phòng còn khoản chưa thu',
            const Color(0xffdf8a00),
          ),
          _infoRow(
            Icons.build_outlined,
            '$maintenance phòng đang bảo trì',
            const Color(0xff7d52d9),
          ),
        ],
      ),
    );
  }
}

class OwnerLongTermManagementScreen extends StatelessWidget {
  const OwnerLongTermManagementScreen({
    super.key,
    required this.buildingId,
    required this.buildingName,
    required this.rooms,
    required this.summary,
    required this.roomProvider,
    this.hostId,
  });

  final int buildingId;
  final String buildingName;
  final int? hostId;
  final List<RoomModel> rooms;
  final TongQuanChuNha? summary;
  final RoomProvider roomProvider;

  List<RoomModel> get _longRooms => [
    for (final room in rooms)
      if (room.loai.contains('dai_han')) room,
  ];

  void _push(BuildContext context, Widget screen) =>
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));

  @override
  Widget build(BuildContext context) {
    final long = _longRooms;
    final occupied = long.where((r) => r.dangThue).length;
    final vacant = long.where((r) => r.tinhTrangHien == 'trong').length;
    final block = _longBlock(summary);
    final expiring = long.where((r) {
      final end = DateTime.tryParse(r.hopDongDen ?? '');
      return end != null &&
          end.difference(DateTime.now()).inDays.between(0, 30);
    }).length;
    final debtRooms = block?.phongNo ?? 0;
    final debtInvoices = block?.hoaDonNo ?? 0;
    final debtMoney = block?.tienNo ?? 0;
    // "Khách sắp trả phòng" hẹp hơn "hợp đồng sắp hết hạn" (30 ngày): chỉ
    // những phòng phải bàn giao trong TUẦN tới. Hai thẻ dùng chung một mốc thì
    // chúng luôn bằng nhau và một trong hai thành thừa.
    final leaving = long.where((r) {
      final end = DateTime.tryParse(r.hopDongDen ?? '');
      return end != null && end.difference(DateTime.now()).inDays.between(0, 7);
    }).length;
    final upcoming = _longUpcoming(long);

    void openRooms() => _push(
      context,
      OwnerLongTermRoomsScreen(
        buildingName: buildingName,
        rooms: long,
        roomProvider: roomProvider,
      ),
    );

    void openSettings() => _push(
      context,
      BuildingDetailScreen(
        buildingId: buildingId,
        buildingName: buildingName,
        hostId: hostId,
      ),
    );

    return Scaffold(
      backgroundColor: const Color(0xfff7f9fc),
      appBar: _appBar(context, title: buildingName),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          _ImageHero(
            asset: 'assets/branding/owner-long-term-v1.webp',
            height: 132,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Quản lý cho thuê dài hạn',
                  style: HD.bodyBold(size: 17, color: const Color(0xff087f55)),
                ),
                const SizedBox(height: 6),
                Text(
                  'Tối ưu vận hành, gia tăng giá trị\ntài sản của bạn',
                  style: HD.body(size: 12, color: const Color(0xff53655f)),
                ),
                const SizedBox(height: 10),
                Text(
                  buildingName.toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: HD
                      .bodyBold(size: 9, color: const Color(0xff65756f))
                      .copyWith(letterSpacing: 2.2),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _LongSectionHeader(title: 'Tổng quan', action: 'Hôm nay'),
          const SizedBox(height: 10),
          _twoByTwo([
            _LongOverviewCard(
              icon: Icons.person_pin_circle_rounded,
              color: const Color(0xff078a59),
              value: '$occupied',
              label: 'Phòng đang ở',
              onTap: openRooms,
            ),
            _LongOverviewCard(
              icon: Icons.home_work_outlined,
              color: const Color(0xff246be8),
              value: '$vacant',
              label: 'Phòng trống',
              onTap: openRooms,
            ),
            _LongOverviewCard(
              icon: Icons.credit_card_rounded,
              color: const Color(0xffdf8a00),
              value: debtMoney > 0 ? _money(debtMoney) : '0',
              // Ô rộng ~150px: "Chưa thu · 1 phòng" bị cắt thành "1 phò…".
              label: 'Chưa thu',
              onTap: () => _push(context, const InvoiceListScreen()),
            ),
            _LongOverviewCard(
              icon: Icons.bar_chart_rounded,
              color: const Color(0xff078a59),
              value: _money(summary?.doanhThuThang),
              label: 'Doanh thu tháng',
              onTap: () => _push(context, const ReportsHomeScreen()),
            ),
          ]),
          const SizedBox(height: 18),
          _LongSectionHeader(
            title: 'Cần chú ý',
            action: 'Xem tất cả',
            actionColor: const Color(0xff078a59),
            onTap: openRooms,
          ),
          const SizedBox(height: 9),
          _LongAttentionPanel(
            items: [
              _LongAttentionItem(
                icon: Icons.description_rounded,
                color: HD.accent,
                title: '$expiring HĐ sắp hết hạn',
                subtitle: expiring == 0
                    ? 'Không có hợp đồng nào đến hạn trong 30 ngày'
                    : 'Cần gia hạn để tránh gián đoạn',
                onTap: () => _push(context, const KhachThueScreen()),
              ),
              _LongAttentionItem(
                icon: Icons.receipt_long_rounded,
                color: const Color(0xffdf8a00),
                title: '$debtInvoices hóa đơn chưa thanh toán',
                subtitle: debtInvoices == 0
                    ? 'Không còn khoản nào chờ thu'
                    : 'Tổng tiền ${_money(debtMoney)} · $debtRooms phòng',
                onTap: () => _push(context, const InvoiceListScreen()),
              ),
              _LongAttentionItem(
                icon: Icons.person_rounded,
                color: const Color(0xff246be8),
                title: '$leaving khách sắp trả phòng',
                subtitle: leaving == 0
                    ? 'Không có phòng nào phải bàn giao tuần này'
                    : 'Dự kiến trong 7 ngày tới',
                onTap: openRooms,
              ),
            ],
          ),
          const SizedBox(height: 18),
          _sectionTitle('Quản lý'),
          const SizedBox(height: 10),
          _LongActionGrid(
            items: [
              _LongAction(
                icon: Icons.people_alt_rounded,
                title: 'Khách hàng',
                subtitle: 'Quản lý khách thuê',
                color: const Color(0xff078a59),
                badge: occupied == 0 ? null : '$occupied',
                onTap: () => _push(
                  context,
                  KhachHangToaScreen(
                    buildingId: buildingId,
                    buildingName: buildingName,
                  ),
                ),
              ),
              _LongAction(
                icon: Icons.home_rounded,
                title: 'Phòng',
                subtitle: 'Danh sách phòng',
                color: const Color(0xff246be8),
                badge: long.isEmpty ? null : '${long.length}',
                onTap: openRooms,
              ),
              _LongAction(
                icon: Icons.description_rounded,
                title: 'Hợp đồng',
                subtitle: 'Quản lý hợp đồng',
                color: const Color(0xff9b2bd1),
                badge: expiring == 0 ? null : '$expiring',
                onTap: () => _push(
                  context,
                  HopDongToaScreen(
                    buildingId: buildingId,
                    buildingName: buildingName,
                  ),
                ),
              ),
              _LongAction(
                icon: Icons.receipt_long_rounded,
                title: 'Hóa đơn',
                subtitle: 'Tạo và quản lý',
                color: const Color(0xffdf8a00),
                badge: debtInvoices == 0 ? null : '$debtInvoices',
                onTap: () => _push(
                  context,
                  HoaDonToaScreen(
                    buildingId: buildingId,
                    buildingName: buildingName,
                  ),
                ),
              ),
              _LongAction(
                icon: Icons.bar_chart_rounded,
                title: 'Doanh thu',
                subtitle: 'Thống kê theo tháng',
                color: const Color(0xff078a59),
                badge: 'T${DateTime.now().month}',
                onTap: () => _push(
                  context,
                  DoanhThuToaScreen(
                    buildingId: buildingId,
                    buildingName: buildingName,
                  ),
                ),
              ),
              _LongAction(
                icon: Icons.settings_rounded,
                title: 'Cài đặt',
                subtitle: 'Tùy chỉnh hệ thống',
                color: const Color(0xff667085),
                onTap: openSettings,
              ),
            ],
          ),
          const SizedBox(height: 18),
          _LongSectionHeader(
            title: 'Sắp tới',
            action: 'Xem tất cả',
            actionColor: const Color(0xff078a59),
            onTap: () => _push(context, const HostAppointmentsScreen()),
          ),
          const SizedBox(height: 9),
          _LongUpcomingPanel(
            items: upcoming.take(3).toList(),
            onTap: () => _push(context, const KhachThueScreen()),
          ),
          const SizedBox(height: 18),
          _sectionTitle('Công cụ vận hành'),
          const SizedBox(height: 9),
          _LongToolStrip(
            items: [
              _LongTool(
                Icons.event_available_rounded,
                'Lịch xem',
                const Color(0xff246be8),
                () => _push(context, const HostAppointmentsScreen()),
              ),
              _LongTool(
                Icons.water_drop_rounded,
                'Điện nước',
                const Color(0xff246be8),
                () => _push(
                  context,
                  DienNuocDaiHanScreen(
                    toa: [(id: buildingId, ten: buildingName)],
                    buildingId: buildingId,
                  ),
                ),
              ),
              _LongTool(
                Icons.payments_outlined,
                'Công nợ',
                const Color(0xffdf8a00),
                () => _push(context, const InvoiceListScreen()),
              ),
              _LongTool(
                Icons.event_note_rounded,
                'Nhắc việc',
                const Color(0xff7d52d9),
                () => _push(context, const HostAppointmentsScreen()),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Một mốc trên dòng thời gian "Sắp tới" của toà.
class _LongEvent {
  const _LongEvent({
    required this.date,
    required this.label,
    required this.color,
  });

  final DateTime date;
  final String label;
  final Color color;
}

/// Ba loại mốc chủ nhà phải nhớ, trộn chung một dòng thời gian và xếp theo
/// ngày: THU TIỀN (ngày phải thu của hợp đồng), HỢP ĐỒNG HẾT HẠN, KHÁCH MỚI
/// VÀO. Chỉ liệt kê hạn hợp đồng là bỏ mất việc đến sớm nhất và hay quên nhất
/// — ngày thu tiền hằng tháng.
List<_LongEvent> _longUpcoming(List<RoomModel> rooms, {DateTime? now}) {
  final today = now ?? DateTime.now();
  final moc = DateTime(today.year, today.month, today.day);
  final ra = <_LongEvent>[];
  for (final room in rooms) {
    void them(String? iso, String label, Color color) {
      final d = DateTime.tryParse(iso ?? '');
      if (d == null || d.isBefore(moc)) return;
      ra.add(_LongEvent(date: d, label: label, color: color));
    }

    them(
      room.dongTienNgay,
      'Thu tiền ${room.code}',
      const Color(0xff078a59),
    );
    them(
      room.hopDongDen,
      'HĐ ${room.code} hết hạn',
      const Color(0xffdf8a00),
    );
    if (room.tinhTrangHien == 'sap_vao') {
      them(
        room.hopDongTu,
        'Khách mới vào ${room.code}',
        const Color(0xff246be8),
      );
    }
  }
  ra.sort((a, b) => a.date.compareTo(b.date));
  return ra;
}

class _LongSectionHeader extends StatelessWidget {
  const _LongSectionHeader({
    required this.title,
    this.action,
    this.actionColor = HD.inkMuted,
    this.onTap,
  });

  final String title;
  final String? action;
  final Color actionColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(child: Text(title, style: HD.sectionTitle())),
      if (action != null)
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 5),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  action!,
                  style: HD.bodyBold(size: 11.5, color: actionColor),
                ),
                if (onTap != null) ...[
                  const SizedBox(width: 2),
                  Icon(
                    Icons.chevron_right_rounded,
                    size: 18,
                    color: actionColor,
                  ),
                ],
              ],
            ),
          ),
        ),
    ],
  );
}

class _LongOverviewCard extends StatelessWidget {
  const _LongOverviewCard({
    required this.icon,
    required this.color,
    required this.value,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final String value;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.white,
    borderRadius: BorderRadius.circular(15),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(15),
      child: Container(
        height: 82,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: const Color(0xffe0e6ee)),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: color.withValues(alpha: .11),
                borderRadius: BorderRadius.circular(13),
              ),
              child: Icon(icon, size: 22, color: color),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: HD.bodyBold(size: 17),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: HD.body(size: 10.5, color: HD.inkMuted),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              size: 18,
              color: HD.inkMuted,
            ),
          ],
        ),
      ),
    ),
  );
}

class _LongAttentionItem {
  const _LongAttentionItem({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
}

class _LongAttentionPanel extends StatelessWidget {
  const _LongAttentionPanel({required this.items});
  final List<_LongAttentionItem> items;

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.white,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
      side: const BorderSide(color: Color(0xffe0e6ee)),
    ),
    clipBehavior: Clip.antiAlias,
    child: Column(
      children: [
        for (var i = 0; i < items.length; i++) ...[
          if (i > 0) const Divider(height: 1, indent: 58, endIndent: 12),
          ListTile(
            onTap: items[i].onTap,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12),
            leading: Container(
              width: 39,
              height: 39,
              decoration: BoxDecoration(
                color: items[i].color.withValues(alpha: .11),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(items[i].icon, size: 20, color: items[i].color),
            ),
            title: Text(items[i].title, style: HD.bodyBold(size: 12.5)),
            subtitle: Text(
              items[i].subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: HD.body(size: 10.5, color: HD.inkMuted),
            ),
            trailing: const Icon(
              Icons.chevron_right_rounded,
              size: 20,
              color: HD.inkMuted,
            ),
          ),
        ],
      ],
    ),
  );
}

class _LongAction {
  const _LongAction({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
    this.badge,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;
  final String? badge;
}

class _LongActionGrid extends StatelessWidget {
  const _LongActionGrid({required this.items});
  final List<_LongAction> items;

  @override
  Widget build(BuildContext context) => GridView.builder(
    shrinkWrap: true,
    physics: const NeverScrollableScrollPhysics(),
    itemCount: items.length,
    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
      crossAxisCount: 3,
      crossAxisSpacing: 8,
      mainAxisSpacing: 8,
      childAspectRatio: .76,
    ),
    itemBuilder: (_, index) {
      final item = items[index];
      return Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        child: InkWell(
          onTap: item.onTap,
          borderRadius: BorderRadius.circular(15),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 11),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(15),
              border: Border.all(color: const Color(0xffe0e6ee)),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      width: 47,
                      height: 47,
                      decoration: BoxDecoration(
                        color: item.color.withValues(alpha: .11),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(item.icon, size: 24, color: item.color),
                    ),
                    if (item.badge != null)
                      Positioned(
                        right: -12,
                        top: -8,
                        child: Container(
                          constraints: const BoxConstraints(minWidth: 25),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xffffe3e6),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            item.badge!,
                            textAlign: TextAlign.center,
                            style: HD.bodyBold(size: 9.5, color: HD.accent),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 9),
                Text(
                  item.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: HD.bodyBold(size: 12),
                ),
                const SizedBox(height: 3),
                Text(
                  item.subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: HD.body(size: 9.5, color: HD.inkMuted),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}

class _LongUpcomingPanel extends StatelessWidget {
  const _LongUpcomingPanel({required this.items, required this.onTap});

  final List<_LongEvent> items;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return _Panel(
        child: Row(
          children: [
            const Icon(Icons.event_available_rounded, color: Color(0xff078a59)),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Chưa có mốc thu tiền hay hợp đồng nào sắp tới.',
                style: HD.body(size: 11.5, color: HD.inkMuted),
              ),
            ),
          ],
        ),
      );
    }
    return Container(
      padding: const EdgeInsets.fromLTRB(13, 7, 10, 7),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xffe0e6ee)),
      ),
      child: Column(
        children: [
          for (var i = 0; i < items.length; i++) ...[
            InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(10),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 9),
                child: Row(
                  children: [
                    Container(
                      width: 9,
                      height: 9,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: items[i].color,
                      ),
                    ),
                    const SizedBox(width: 12),
                    SizedBox(
                      width: 48,
                      child: Text(
                        _shortDateVi(items[i].date),
                        style: HD.bodyBold(size: 11.5),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        items[i].label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: HD.body(size: 11.5),
                      ),
                    ),
                    const Icon(
                      Icons.chevron_right_rounded,
                      size: 19,
                      color: HD.inkMuted,
                    ),
                  ],
                ),
              ),
            ),
            if (i < items.length - 1)
              const Divider(height: 1, indent: 21, endIndent: 14),
          ],
        ],
      ),
    );
  }
}

class _LongTool {
  const _LongTool(this.icon, this.label, this.color, this.onTap);
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
}

class _LongToolStrip extends StatelessWidget {
  const _LongToolStrip({required this.items});
  final List<_LongTool> items;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      for (var i = 0; i < items.length; i++) ...[
        if (i > 0) const SizedBox(width: 7),
        Expanded(
          child: Material(
            color: Colors.white,
            borderRadius: BorderRadius.circular(13),
            child: InkWell(
              onTap: items[i].onTap,
              borderRadius: BorderRadius.circular(13),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  vertical: 11,
                  horizontal: 4,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(13),
                  border: Border.all(color: const Color(0xffe0e6ee)),
                ),
                child: Column(
                  children: [
                    Icon(items[i].icon, size: 20, color: items[i].color),
                    const SizedBox(height: 5),
                    Text(
                      items[i].label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: HD.bodyBold(size: 9.5),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    ],
  );
}

class OwnerShortTermManagementScreen extends StatelessWidget {
  const OwnerShortTermManagementScreen({
    super.key,
    required this.buildingId,
    required this.buildingName,
    required this.rooms,
    required this.summary,
  });

  final int buildingId;
  final String buildingName;
  final List<RoomModel> rooms;
  final TongQuanChuNha? summary;

  void _push(BuildContext context, Widget screen) =>
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));

  @override
  Widget build(BuildContext context) {
    final short = [
      for (final r in rooms)
        if (r.loai.contains('ngan_han')) r,
    ];
    final block = _shortBlock(summary);
    final occupied = block?.dangSuDung ?? short.where((r) => r.dangThue).length;
    final vacant =
        block?.trong ?? short.where((r) => r.tinhTrangHien == 'trong').length;
    final maintenance = short.where((r) => r.tinhTrangHien == 'bao_tri').length;
    return Scaffold(
      backgroundColor: const Color(0xfff7f9fc),
      appBar: _appBar(context, title: buildingName),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          _ImageHero(
            asset: 'assets/branding/owner-short-term-v1.webp',
            child: _bannerCopy(
              icon: Icons.nightlight_round,
              title: 'Quản lý cho thuê ngắn hạn',
              subtitle: 'Booking, check-in/check-out\nvà tối ưu công suất',
              color: const Color(0xffc75b0a),
            ),
          ),
          const SizedBox(height: 16),
          _sectionTitle('Tổng quan'),
          const SizedBox(height: 10),
          _twoByTwo([
            _MetricCard(
              icon: Icons.hotel_rounded,
              color: const Color(0xff7d52d9),
              value: '${short.length}',
              label: 'Phòng ngắn hạn',
            ),
            _MetricCard(
              icon: Icons.login_rounded,
              color: const Color(0xff078a59),
              value: '$occupied',
              label: 'Khách đang lưu trú',
            ),
            _MetricCard(
              icon: Icons.meeting_room_outlined,
              color: const Color(0xff246be8),
              value: '$vacant',
              label: 'Phòng đang trống',
            ),
            _MetricCard(
              icon: Icons.donut_large_rounded,
              color: const Color(0xffc75b0a),
              value: '${block?.tyLe ?? 0}%',
              label: 'Công suất hiện tại',
            ),
          ]),
          const SizedBox(height: 12),
          _Panel(
            color: const Color(0xfffff8f3),
            border: const Color(0xffffe2cd),
            child: Column(
              children: [
                _rowTitle(
                  'Hoạt động hôm nay',
                  action: 'Xem booking',
                  onTap: () => _push(
                    context,
                    const ShortStayBookingsScreen(
                      operations: true,
                      operationsRole: ShortStayOperationsRole.owner,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                _infoRow(
                  Icons.bed_rounded,
                  '$occupied phòng đang có khách',
                  const Color(0xff078a59),
                ),
                _infoRow(
                  Icons.meeting_room_outlined,
                  '$vacant phòng sẵn sàng nhận khách',
                  const Color(0xff246be8),
                ),
                _infoRow(
                  Icons.cleaning_services_rounded,
                  '$maintenance phòng cần xử lý/bảo trì',
                  const Color(0xff7d52d9),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          _sectionTitle('Chức năng quản lý'),
          const SizedBox(height: 10),
          _MenuPanel(
            items: [
              _MenuItem(
                Icons.calendar_month_rounded,
                'Lịch phòng',
                'Lịch trống và giá phòng theo ngày',
                HD.accent,
                () => _push(context, LichNganHanScreen(buildingId: buildingId)),
              ),
              _MenuItem(
                Icons.category_rounded,
                'Danh sách loại phòng',
                'Quản lý loại phòng và tiện nghi',
                const Color(0xffc75b0a),
                () => _push(
                  context,
                  LoaiPhongScreen(buildingId: buildingId, tenToa: buildingName),
                ),
              ),
              _MenuItem(
                Icons.event_note_rounded,
                'Lịch booking',
                'Danh sách booking và trạng thái',
                const Color(0xff246be8),
                () => _push(
                  context,
                  const ShortStayBookingsScreen(
                    operations: true,
                    operationsRole: ShortStayOperationsRole.owner,
                  ),
                ),
              ),
              _MenuItem(
                Icons.login_rounded,
                'Check-in / Check-out',
                'Xác nhận khách nhận và trả phòng',
                const Color(0xff078a59),
                () => _push(
                  context,
                  const ShortStayBookingsScreen(
                    operations: true,
                    operationsRole: ShortStayOperationsRole.owner,
                  ),
                ),
              ),
              _MenuItem(
                Icons.people_alt_rounded,
                'Khách lưu trú',
                'Danh sách khách đang ở theo booking',
                const Color(0xff078a59),
                () => _push(
                  context,
                  const ShortStayBookingsScreen(
                    operations: true,
                    operationsRole: ShortStayOperationsRole.owner,
                  ),
                ),
              ),
              _MenuItem(
                Icons.payments_rounded,
                'Đặt cọc & hoàn cọc',
                'Theo dõi thanh toán và hoàn cọc booking',
                const Color(0xffdf8a00),
                () => _push(
                  context,
                  const ShortStayBookingsScreen(
                    operations: true,
                    operationsRole: ShortStayOperationsRole.owner,
                  ),
                ),
              ),
              _MenuItem(
                Icons.bar_chart_rounded,
                'Doanh thu ngắn hạn',
                'Doanh thu, công suất và hiệu quả khai thác',
                const Color(0xff078a59),
                () => _push(context, const ReportsHomeScreen()),
              ),
              _MenuItem(
                Icons.reviews_rounded,
                'Đánh giá & phản hồi',
                'Theo dõi phản hồi sau kỳ lưu trú',
                HD.accent,
                () => _push(
                  context,
                  const ShortStayBookingsScreen(
                    operations: true,
                    operationsRole: ShortStayOperationsRole.owner,
                  ),
                ),
              ),
              _MenuItem(
                Icons.settings_rounded,
                'Cài đặt',
                'Cấu hình loại phòng, giá và tồn kho',
                const Color(0xff667085),
                () => _push(context, const ShortStayRoomsScreen()),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Danh sách dài hạn luôn lọc từ cùng sổ [RoomModel]. Phòng hybrid xuất hiện
/// ở đây vì nó có kênh `dai_han`; không có bản sao "phòng dài hạn" riêng.
class OwnerLongTermRoomsScreen extends StatefulWidget {
  const OwnerLongTermRoomsScreen({
    super.key,
    required this.buildingName,
    required this.rooms,
    required this.roomProvider,
  });

  final String buildingName;
  final List<RoomModel> rooms;
  final RoomProvider roomProvider;

  @override
  State<OwnerLongTermRoomsScreen> createState() =>
      _OwnerLongTermRoomsScreenState();
}

class _OwnerLongTermRoomsScreenState extends State<OwnerLongTermRoomsScreen> {
  final _search = TextEditingController();
  String _filter = 'all';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  List<RoomModel> get _visible {
    final query = _search.text.trim().toLowerCase();
    return widget.rooms.where((room) {
      if (!room.loai.contains('dai_han')) return false;
      if (query.isNotEmpty &&
          !room.code.toLowerCase().contains(query) &&
          !(room.khachThue ?? '').toLowerCase().contains(query)) {
        return false;
      }
      return switch (_filter) {
        'occupied' => room.tinhTrangHien == 'dang_o',
        'leaving' => room.tinhTrangHien == 'sap_tra',
        'vacant' => room.tinhTrangHien == 'trong',
        'maintenance' => room.tinhTrangHien == 'bao_tri',
        _ => true,
      };
    }).toList();
  }

  void _open(RoomModel room) => Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => ChangeNotifierProvider.value(
        value: widget.roomProvider,
        child: RoomDetailScreen(roomId: room.id),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final allLong = widget.rooms.where((r) => r.loai.contains('dai_han'));
    return Scaffold(
      backgroundColor: const Color(0xfff7f9fc),
      appBar: _appBar(
        context,
        title: 'Phòng dài hạn',
        trailing: IconButton(
          tooltip: 'Thông báo',
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const NotificationsScreen()),
          ),
          icon: const Icon(Icons.notifications_none_rounded),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
        children: [
          _BuildingSelector(name: widget.buildingName),
          const SizedBox(height: 10),
          TextField(
            controller: _search,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: 'Tìm kiếm phòng, người thuê...',
              prefixIcon: const Icon(Icons.search_rounded),
              filled: true,
              fillColor: Colors.white,
              contentPadding: EdgeInsets.zero,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: Color(0xffe2e8ef)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: Color(0xffe2e8ef)),
              ),
            ),
          ),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _FilterChip(
                  label: 'Tất cả (${allLong.length})',
                  value: 'all',
                  selected: _filter,
                  onTap: _setFilter,
                ),
                _FilterChip(
                  label:
                      'Đang ở (${allLong.where((r) => r.tinhTrangHien == 'dang_o').length})',
                  value: 'occupied',
                  selected: _filter,
                  onTap: _setFilter,
                ),
                _FilterChip(
                  label:
                      'Sắp trả (${allLong.where((r) => r.tinhTrangHien == 'sap_tra').length})',
                  value: 'leaving',
                  selected: _filter,
                  onTap: _setFilter,
                ),
                _FilterChip(
                  label:
                      'Trống (${allLong.where((r) => r.tinhTrangHien == 'trong').length})',
                  value: 'vacant',
                  selected: _filter,
                  onTap: _setFilter,
                ),
                _FilterChip(
                  label:
                      'Bảo trì (${allLong.where((r) => r.tinhTrangHien == 'bao_tri').length})',
                  value: 'maintenance',
                  selected: _filter,
                  onTap: _setFilter,
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          if (_visible.isEmpty)
            _notice('Không có phòng phù hợp bộ lọc.', const Color(0xff667085))
          else
            LayoutBuilder(
              builder: (context, constraints) {
                final compact = constraints.maxWidth < 350;
                return GridView.builder(
                  key: const Key('owner-long-term-room-grid'),
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _visible.length,
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                    childAspectRatio: compact ? .59 : .82,
                  ),
                  itemBuilder: (_, index) {
                    final room = _visible[index];
                    return _LongTermRoomGridCard(
                      room: room,
                      onTap: () => _open(room),
                    );
                  },
                );
              },
            ),
        ],
      ),
    );
  }

  void _setFilter(String value) => setState(() => _filter = value);
}

/// Sổ phòng linh hoạt: chỉ là một phép lọc trên Room Unit có đồng thời hai
/// kênh. Mọi thao tác chi tiết vẫn dùng đúng `room.id` vật lý.
class OwnerFlexibleRoomsScreen extends StatelessWidget {
  const OwnerFlexibleRoomsScreen({
    super.key,
    required this.buildingName,
    required this.rooms,
    required this.roomProvider,
  });

  final String buildingName;
  final List<RoomModel> rooms;
  final RoomProvider roomProvider;

  List<RoomModel> get _hybrid => [
    for (final room in rooms)
      if (room.loai.contains('dai_han') && room.loai.contains('ngan_han')) room,
  ];

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xfff7f9fc),
    appBar: _appBar(
      context,
      title: 'Phòng linh hoạt',
      trailing: IconButton(
        tooltip: 'Thông báo',
        onPressed: () => Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (_) => const NotificationsScreen())),
        icon: const Icon(Icons.notifications_none_rounded),
      ),
    ),
    body: ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
      children: [
        _BuildingSelector(name: buildingName),
        const SizedBox(height: 12),
        _ImageHero(
          asset: 'assets/branding/owner-building-hub-v1.webp',
          child: _bannerCopy(
            icon: Icons.hub_rounded,
            title: 'Kết nối hai cách khai thác',
            subtitle:
                'Nhận booking ngắn hạn cho tới trước ngày khách dài hạn vào ở',
            color: const Color(0xff7046c7),
          ),
        ),
        const SizedBox(height: 14),
        Text('${_hybrid.length} phòng linh hoạt', style: HD.sectionTitle()),
        const SizedBox(height: 9),
        if (_hybrid.isEmpty)
          _Panel(
            color: const Color(0xfff5f0ff),
            border: const Color(0xffe3d8ff),
            child: Text(
              'Chưa có phòng bật đồng thời Dài hạn + Ngắn hạn. Hãy mở cấu hình một phòng vật lý để bật hai kênh.',
              style: HD.body(size: 12, color: HD.inkSoft),
            ),
          )
        else
          for (final room in _hybrid) ...[
            _RoomManagementCard(
              room: room,
              hybrid: true,
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => OwnerFlexibleRoomScreen(
                    buildingName: buildingName,
                    room: room,
                    roomProvider: roomProvider,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 9),
          ],
      ],
    ),
  );
}

class OwnerFlexibleRoomScreen extends StatefulWidget {
  const OwnerFlexibleRoomScreen({
    super.key,
    required this.buildingName,
    required this.room,
    required this.roomProvider,
  });

  final String buildingName;
  final RoomModel room;
  final RoomProvider roomProvider;

  @override
  State<OwnerFlexibleRoomScreen> createState() =>
      _OwnerFlexibleRoomScreenState();
}

class _OwnerFlexibleRoomScreenState extends State<OwnerFlexibleRoomScreen> {
  int _tab = 1;

  @override
  Widget build(BuildContext context) {
    final room = widget.room;
    return Scaffold(
      backgroundColor: const Color(0xfff7f9fc),
      appBar: _appBar(
        context,
        title: 'Phòng linh hoạt',
        trailing: IconButton(
          tooltip: 'Thông báo',
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const NotificationsScreen()),
          ),
          icon: const Icon(Icons.notifications_none_rounded),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
        children: [
          _BuildingSelector(name: widget.buildingName),
          const SizedBox(height: 10),
          _Panel(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _RoomThumbnail(room: room, width: 92, height: 78),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              room.code,
                              style: HD.bodyBold(size: 18),
                            ),
                          ),
                          _smallChip('Linh hoạt', const Color(0xff7046c7)),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Dài hạn + Ngắn hạn',
                        style: HD.bodyBold(
                          size: 12,
                          color: const Color(0xff30405b),
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        '${room.loaiPhong ?? 'Chưa gán loại phòng'} · ${room.areaM2?.toStringAsFixed(0) ?? '—'}m² · ${room.capacity} khách',
                        style: HD.body(size: 11, color: HD.inkMuted),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          _SegmentTabs(
            labels: const ['Tổng quan', 'Lịch phòng', 'Cấu hình'],
            selected: _tab,
            onChanged: (value) => setState(() => _tab = value),
          ),
          const SizedBox(height: 12),
          if (_tab == 0) _overview(room),
          if (_tab == 1) _calendar(room),
          if (_tab == 2) _configuration(room),
        ],
      ),
    );
  }

  Widget _overview(RoomModel room) => Column(
    children: [
      _Panel(
        child: Column(
          children: [
            _infoRow(
              Icons.home_rounded,
              'Dài hạn thuê chính xác phòng ${room.code}',
              const Color(0xff078a59),
            ),
            _infoRow(
              Icons.hotel_rounded,
              'Ngắn hạn bán theo loại ${room.loaiPhong ?? 'chưa gán'}',
              const Color(0xffc75b0a),
            ),
            _infoRow(
              Icons.payments_outlined,
              'Giá dài hạn ${_formatVnd(room.giaKenh ?? room.basePrice)}',
              const Color(0xff7046c7),
            ),
          ],
        ),
      ),
      const SizedBox(height: 10),
      _ruleCard(),
    ],
  );

  Widget _calendar(RoomModel room) => Column(
    children: [
      _Panel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _rowTitle('Lịch khai thác phòng'),
            const SizedBox(height: 10),
            _CalendarStrip(),
            const SizedBox(height: 14),
            _TimelineLegend(
              color: const Color(0xfff28a20),
              title: 'Booking ngắn hạn',
              subtitle:
                  'Giữ theo tồn kho của loại phòng; gán phòng gần check-in',
            ),
            const SizedBox(height: 8),
            _TimelineLegend(
              color: const Color(0xff078a59),
              title: 'Hợp đồng dài hạn',
              subtitle: room.dangThue
                  ? 'Phòng đang có khách dài hạn'
                  : 'Chưa có ngày bắt đầu dài hạn được chốt',
            ),
          ],
        ),
      ),
      const SizedBox(height: 10),
      _ruleCard(),
    ],
  );

  Widget _configuration(RoomModel room) => Column(
    children: [
      _Panel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Chế độ khai thác', style: HD.bodyBold(size: 14)),
            const SizedBox(height: 10),
            _ModeState(
              icon: Icons.home_rounded,
              title: 'Dài hạn',
              description: 'Thuê chính xác phòng ${room.code}',
              color: const Color(0xff078a59),
            ),
            const SizedBox(height: 8),
            _ModeState(
              icon: Icons.nightlight_round,
              title: 'Ngắn hạn',
              description:
                  'Đóng góp tồn kho cho ${room.loaiPhong ?? 'loại phòng chưa gán'}',
              color: const Color(0xffc75b0a),
            ),
          ],
        ),
      ),
      const SizedBox(height: 12),
      SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => ChangeNotifierProvider.value(
                value: widget.roomProvider,
                child: RoomDetailScreen(roomId: room.id),
              ),
            ),
          ),
          icon: const Icon(Icons.settings_outlined),
          label: const Text('Mở hồ sơ và cấu hình phòng'),
        ),
      ),
    ],
  );

  Widget _ruleCard() => _Panel(
    color: const Color(0xfff4edff),
    border: const Color(0xffe3d7ff),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.lightbulb_rounded, color: Color(0xff7046c7)),
            const SizedBox(width: 8),
            Text(
              'Quy tắc vận hành linh hoạt',
              style: HD.bodyBold(size: 13.5, color: const Color(0xff7046c7)),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          'Phòng vẫn nhận booking ngắn hạn cho tới trước ngày khách dài hạn vào ở. Khi chốt ngày vào, hệ thống chỉ cho phép nếu loại phòng vẫn đủ tồn kho phục vụ mọi booking đã xác nhận.',
          style: HD.body(size: 11.5, color: HD.inkSoft),
        ),
      ],
    ),
  );
}

class _BuildingSelector extends StatelessWidget {
  const _BuildingSelector({required this.name});
  final String name;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(13),
      border: Border.all(color: const Color(0xffe2e8ef)),
    ),
    child: Row(
      children: [
        const Icon(Icons.search_rounded, size: 19, color: HD.inkMuted),
        const SizedBox(width: 9),
        Expanded(
          child: Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: HD.bodyBold(size: 12.5),
          ),
        ),
        const Icon(Icons.keyboard_arrow_down_rounded, color: HD.inkMuted),
      ],
    ),
  );
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.value,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final String value;
  final String selected;
  final ValueChanged<String> onTap;

  @override
  Widget build(BuildContext context) {
    final active = value == selected;
    return Padding(
      padding: const EdgeInsets.only(right: 7),
      child: ChoiceChip(
        label: Text(label),
        selected: active,
        onSelected: (_) => onTap(value),
        showCheckmark: false,
        backgroundColor: Colors.white,
        selectedColor: const Color(0xff078a59),
        side: BorderSide(
          color: active ? const Color(0xff078a59) : const Color(0xffe2e8ef),
        ),
        labelStyle: HD.bodyBold(
          size: 10.5,
          color: active ? Colors.white : HD.inkSoft,
        ),
      ),
    );
  }
}

class _RoomManagementCard extends StatelessWidget {
  const _RoomManagementCard({
    required this.room,
    required this.onTap,
    this.hybrid = false,
  });
  final RoomModel room;
  final VoidCallback onTap;
  final bool hybrid;

  @override
  Widget build(BuildContext context) {
    final state = _roomState(room);
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(15),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(15),
        child: Container(
          padding: const EdgeInsets.all(11),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: const Color(0xffe2e8ef)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _RoomThumbnail(room: room),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(room.code, style: HD.bodyBold(size: 15)),
                        ),
                        _smallChip(
                          hybrid ? 'Linh hoạt' : state.$1,
                          hybrid ? const Color(0xff7046c7) : state.$2,
                        ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Text(
                      room.khachThue ??
                          (hybrid
                              ? '${room.loaiPhong ?? 'Chưa gán loại'} · Dài hạn + Ngắn hạn'
                              : 'Chưa có khách thuê'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: HD.body(size: 11, color: HD.inkMuted),
                    ),
                    if (room.hopDongDen != null) ...[
                      const SizedBox(height: 3),
                      Text(
                        'Hợp đồng đến ${room.hopDongDen}',
                        style: HD.body(size: 10.5, color: HD.inkMuted),
                      ),
                    ],
                    const SizedBox(height: 5),
                    Text(
                      _formatVnd(room.giaKenh ?? room.basePrice),
                      style: HD.bodyBold(size: 12.5),
                    ),
                  ],
                ),
              ),
              const Padding(
                padding: EdgeInsets.only(top: 28),
                child: Icon(
                  Icons.chevron_right_rounded,
                  size: 20,
                  color: HD.inkMuted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LongTermRoomGridCard extends StatelessWidget {
  const _LongTermRoomGridCard({required this.room, required this.onTap});

  final RoomModel room;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final state = _roomState(room);
    final end = DateTime.tryParse(room.hopDongDen ?? '');
    final today = DateUtils.dateOnly(DateTime.now());
    final daysLeft = end == null
        ? null
        : DateUtils.dateOnly(end).difference(today).inDays;
    final dueColor = switch (daysLeft) {
      null => HD.inkMuted,
      <= 0 => HD.accent,
      <= 7 => const Color(0xffef7d00),
      _ => const Color(0xff078a59),
    };

    return Material(
      key: Key('owner-long-room-${room.id}'),
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xffdfe5ec)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 48,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    _RoomThumbnail(
                      room: room,
                      width: double.infinity,
                      height: double.infinity,
                      radius: 0,
                    ),
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: state.$2.withValues(alpha: .92),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          state.$1,
                          style: HD.bodyBold(size: 10.5, color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                flex: 52,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(11, 9, 9, 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              room.code,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: HD.bodyBold(size: 15.5),
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
                        _formatVnd(room.giaKenh ?? room.basePrice),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: HD.bodyBold(size: 12.5),
                      ),
                      const SizedBox(height: 11),
                      _GridInfoRow(
                        icon: Icons.person_outline_rounded,
                        text: room.khachThue ?? 'Chưa có người ở',
                        avatarText: room.khachThue,
                      ),
                      const SizedBox(height: 6),
                      _GridInfoRow(
                        icon: Icons.calendar_month_outlined,
                        text: end == null
                            ? 'HĐ đến: --'
                            : 'HĐ đến: ${_dateVi(end)}',
                      ),
                      const SizedBox(height: 6),
                      _GridInfoRow(
                        icon: Icons.monetization_on_outlined,
                        text: daysLeft == null
                            ? 'Chưa có kỳ hợp đồng'
                            : daysLeft < 0
                            ? 'Hợp đồng đã quá hạn ${-daysLeft} ngày'
                            : 'Còn $daysLeft ngày tới hạn hợp đồng',
                        color: dueColor,
                        bold: daysLeft != null,
                      ),
                    ],
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

class _GridInfoRow extends StatelessWidget {
  const _GridInfoRow({
    required this.icon,
    required this.text,
    this.avatarText,
    this.color = HD.inkMuted,
    this.bold = false,
  });

  final IconData icon;
  final String text;
  final String? avatarText;
  final Color color;
  final bool bold;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      if (avatarText != null)
        CircleAvatar(
          radius: 10,
          backgroundColor: const Color(0xffe9edf3),
          child: Text(
            avatarText!.trim().isEmpty
                ? '•'
                : avatarText!.trim().substring(0, 1).toUpperCase(),
            style: HD.bodyBold(size: 8.5, color: HD.inkSoft),
          ),
        )
      else
        Icon(icon, size: 17, color: color),
      const SizedBox(width: 7),
      Expanded(
        child: Text(
          text,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: bold
              ? HD.bodyBold(size: 10, color: color)
              : HD.body(size: 10, color: color),
        ),
      ),
    ],
  );
}

class _RoomThumbnail extends StatelessWidget {
  const _RoomThumbnail({
    this.room,
    this.width = 84,
    this.height = 72,
    this.radius = 11,
  });
  final RoomModel? room;
  final double width;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final url = room?.images.firstOrNull;
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: SizedBox(
        width: width,
        height: height,
        child: url != null && url.startsWith('http')
            ? Image.network(
                url,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => _fallback(),
              )
            : _fallback(),
      ),
    );
  }

  Widget _fallback() => Image.asset(
    'assets/branding/owner-long-term-v1.webp',
    fit: BoxFit.cover,
    alignment: Alignment.centerRight,
  );
}

class _SegmentTabs extends StatelessWidget {
  const _SegmentTabs({
    required this.labels,
    required this.selected,
    required this.onChanged,
  });
  final List<String> labels;
  final int selected;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(4),
    decoration: BoxDecoration(
      color: const Color(0xffeef1f6),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Row(
      children: [
        for (var i = 0; i < labels.length; i++)
          Expanded(
            child: InkWell(
              onTap: () => onChanged(i),
              borderRadius: BorderRadius.circular(9),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                padding: const EdgeInsets.symmetric(vertical: 9),
                decoration: BoxDecoration(
                  color: selected == i ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Text(
                  labels[i],
                  textAlign: TextAlign.center,
                  style: HD.bodyBold(
                    size: 11,
                    color: selected == i
                        ? const Color(0xff078a59)
                        : HD.inkMuted,
                  ),
                ),
              ),
            ),
          ),
      ],
    ),
  );
}

class _CalendarStrip extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    return Column(
      children: [
        Row(
          children: [
            const Icon(Icons.chevron_left_rounded, size: 19),
            Expanded(
              child: Text(
                'Tháng ${now.month}/${now.year}',
                textAlign: TextAlign.center,
                style: HD.bodyBold(size: 12.5),
              ),
            ),
            const Icon(Icons.chevron_right_rounded, size: 19),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            for (var i = 0; i < 7; i++)
              Expanded(
                child: Column(
                  children: [
                    Text(
                      const ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN'][i],
                      style: HD.caption(),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${now.add(Duration(days: i)).day}',
                      style: HD.bodyBold(
                        size: 11.5,
                        color: i == 0 ? HD.accent : HD.ink,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _TimelineLegend extends StatelessWidget {
  const _TimelineLegend({
    required this.color,
    required this.title,
    required this.subtitle,
  });
  final Color color;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(11),
    decoration: BoxDecoration(
      color: color.withValues(alpha: .08),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Row(
      children: [
        Container(
          width: 9,
          height: 42,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(99),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: HD.bodyBold(size: 12, color: color)),
              const SizedBox(height: 3),
              Text(subtitle, style: HD.body(size: 10.5, color: HD.inkMuted)),
            ],
          ),
        ),
      ],
    ),
  );
}

class _ModeState extends StatelessWidget {
  const _ModeState({
    required this.icon,
    required this.title,
    required this.description,
    required this.color,
  });
  final IconData icon;
  final String title;
  final String description;
  final Color color;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: color.withValues(alpha: .1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: color, size: 21),
      ),
      const SizedBox(width: 10),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: HD.bodyBold(size: 12.5)),
            const SizedBox(height: 2),
            Text(description, style: HD.body(size: 10.5, color: HD.inkMuted)),
          ],
        ),
      ),
      const Icon(Icons.check_circle_rounded, color: Color(0xff078a59)),
    ],
  );
}

(String, Color) _roomState(RoomModel room) => switch (room.tinhTrangHien) {
  'dang_o' => ('Đang ở', const Color(0xff078a59)),
  'sap_tra' => ('Sắp trả', const Color(0xffc75b0a)),
  'bao_tri' => ('Bảo trì', HD.accent),
  _ => ('Trống', const Color(0xff667085)),
};

String _formatVnd(double value) {
  final raw = value.round().toString();
  final reversed = raw.split('').reversed.toList();
  final chunks = <String>[];
  for (var i = 0; i < reversed.length; i += 3) {
    chunks.add(
      reversed.sublist(i, (i + 3).clamp(0, reversed.length)).reversed.join(),
    );
  }
  return '${chunks.reversed.join('.')}đ/tháng';
}

String _dateVi(DateTime value) =>
    '${value.day.toString().padLeft(2, '0')}/'
    '${value.month.toString().padLeft(2, '0')}/${value.year}';

String _shortDateVi(DateTime value) =>
    '${value.day.toString().padLeft(2, '0')}/'
    '${value.month.toString().padLeft(2, '0')}';

extension on int {
  bool between(int min, int max) => this >= min && this <= max;
}

KhoiThue? _longBlock(TongQuanChuNha? summary) {
  if (summary == null) return null;
  for (final item in summary.daiHan) {
    return item;
  }
  return null;
}

KhoiNganHan? _shortBlock(TongQuanChuNha? summary) {
  if (summary == null) return null;
  for (final item in summary.nganHan) {
    return item;
  }
  return null;
}

PreferredSizeWidget _appBar(
  BuildContext context, {
  required String title,
  Widget? trailing,
}) => AppBar(
  backgroundColor: Colors.white,
  surfaceTintColor: Colors.transparent,
  elevation: 0,
  leading: Navigator.of(context).canPop() ? const BackButton() : null,
  title: Text(title, style: HD.bodyBold(size: 19)),
  actions: trailing == null ? null : [trailing],
);

Widget _sectionTitle(String title) => Text(title, style: HD.bodyBold(size: 17));

Widget _bannerCopy({
  required IconData icon,
  required String title,
  required String subtitle,
  required Color color,
}) => Row(
  crossAxisAlignment: CrossAxisAlignment.start,
  children: [
    Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .86),
        borderRadius: BorderRadius.circular(13),
      ),
      child: Icon(icon, color: color, size: 24),
    ),
    const SizedBox(width: 10),
    Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: HD.bodyBold(size: 15, color: color)),
          const SizedBox(height: 4),
          Text(subtitle, style: HD.body(size: 11.5, color: HD.inkMuted)),
        ],
      ),
    ),
  ],
);

class _ImageHero extends StatelessWidget {
  const _ImageHero({
    required this.asset,
    required this.child,
    this.height = 118,
  });
  final String asset;
  final Widget child;
  final double height;

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(18),
    child: SizedBox(
      height: height,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(asset, fit: BoxFit.cover),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.white.withValues(alpha: .97),
                  Colors.white.withValues(alpha: .64),
                  Colors.transparent,
                ],
                stops: const [0, .48, .78],
              ),
            ),
          ),
          Padding(padding: const EdgeInsets.all(14), child: child),
        ],
      ),
    ),
  );
}

class _Panel extends StatelessWidget {
  const _Panel({
    required this.child,
    this.color = Colors.white,
    this.border = const Color(0xffe5e9f0),
  });
  final Widget child;
  final Color color;
  final Color border;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: border),
    ),
    child: child,
  );
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.icon,
    required this.color,
    required this.value,
    required this.label,
  });
  final IconData icon;
  final Color color;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) => Container(
    constraints: const BoxConstraints(minHeight: 82),
    padding: const EdgeInsets.all(11),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(15),
      border: Border.all(color: const Color(0xffe5e9f0)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Row(
          children: [
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: color.withValues(alpha: .11),
                borderRadius: BorderRadius.circular(9),
              ),
              child: Icon(icon, size: 17, color: color),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: HD.bodyBold(size: 15),
              ),
            ),
          ],
        ),
        const SizedBox(height: 5),
        Text(
          label,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: HD.body(size: 10.5, color: HD.inkMuted),
        ),
      ],
    ),
  );
}

class _MiniMetric extends StatelessWidget {
  const _MiniMetric({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    constraints: const BoxConstraints(minHeight: 92),
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
    decoration: BoxDecoration(
      color: color.withValues(alpha: .07),
      borderRadius: BorderRadius.circular(13),
    ),
    child: Column(
      children: [
        Icon(icon, size: 20, color: color),
        const SizedBox(height: 6),
        Text(value, style: HD.bodyBold(size: 16)),
        const SizedBox(height: 2),
        Text(
          label,
          maxLines: 2,
          textAlign: TextAlign.center,
          style: HD.body(size: 9.5, color: HD.inkMuted),
        ),
      ],
    ),
  );
}

Widget _twoByTwo(List<Widget> cards) => Column(
  children: [
    for (var row = 0; row < cards.length; row += 2) ...[
      if (row > 0) const SizedBox(height: 8),
      Row(
        children: [
          Expanded(child: cards[row]),
          const SizedBox(width: 8),
          Expanded(child: cards[row + 1]),
        ],
      ),
    ],
  ],
);

class _MenuItem {
  const _MenuItem(this.icon, this.title, this.subtitle, this.color, this.onTap);
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;
}

class _MenuPanel extends StatelessWidget {
  const _MenuPanel({required this.items});
  final List<_MenuItem> items;

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.white,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
      side: const BorderSide(color: Color(0xffe5e9f0)),
    ),
    clipBehavior: Clip.antiAlias,
    child: Column(
      children: [
        for (var i = 0; i < items.length; i++) ...[
          if (i > 0) const Divider(height: 1, indent: 58),
          ListTile(
            onTap: items[i].onTap,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 2,
            ),
            leading: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: items[i].color.withValues(alpha: .1),
                borderRadius: BorderRadius.circular(11),
              ),
              child: Icon(items[i].icon, size: 19, color: items[i].color),
            ),
            title: Text(items[i].title, style: HD.bodyBold(size: 13)),
            subtitle: Text(
              items[i].subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: HD.body(size: 10.5, color: HD.inkMuted),
            ),
            trailing: const Icon(
              Icons.chevron_right_rounded,
              size: 20,
              color: HD.inkMuted,
            ),
          ),
        ],
      ],
    ),
  );
}

Widget _rowTitle(String title, {String? action, VoidCallback? onTap}) => Row(
  children: [
    Expanded(child: Text(title, style: HD.bodyBold(size: 13.5))),
    if (action != null)
      TextButton(
        onPressed: onTap,
        style: TextButton.styleFrom(
          visualDensity: VisualDensity.compact,
          padding: const EdgeInsets.symmetric(horizontal: 6),
        ),
        child: Text(action, style: HD.bodyBold(size: 10.5, color: HD.accent)),
      ),
  ],
);

Widget _infoRow(IconData icon, String text, Color color) => Padding(
  padding: const EdgeInsets.symmetric(vertical: 5),
  child: Row(
    children: [
      Icon(icon, size: 17, color: color),
      const SizedBox(width: 9),
      Expanded(
        child: Text(text, style: HD.body(size: 11.5, color: HD.inkSoft)),
      ),
      const Icon(Icons.chevron_right_rounded, size: 17, color: HD.inkMuted),
    ],
  ),
);

Widget _smallChip(String text, Color color) => Container(
  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
  decoration: BoxDecoration(
    color: color.withValues(alpha: .1),
    borderRadius: BorderRadius.circular(999),
  ),
  child: Text(text, style: HD.bodyBold(size: 9.5, color: color)),
);

Widget _notice(String text, Color color) => Container(
  padding: const EdgeInsets.all(12),
  decoration: BoxDecoration(
    color: color.withValues(alpha: .1),
    borderRadius: BorderRadius.circular(12),
  ),
  child: Row(
    children: [
      Icon(Icons.info_outline, size: 18, color: color),
      const SizedBox(width: 8),
      Expanded(child: Text(text, style: HD.body(size: 11.5))),
    ],
  ),
);

Widget _modeCard({
  required Key key,
  required String title,
  required String subtitle,
  required IconData icon,
  required Color tint,
  required Color color,
  required VoidCallback onTap,
}) => Material(
  key: key,
  color: tint,
  borderRadius: BorderRadius.circular(16),
  child: InkWell(
    borderRadius: BorderRadius.circular(16),
    onTap: onTap,
    child: Padding(
      padding: const EdgeInsets.all(13),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: .72),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(icon, size: 20, color: color),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 2,
                  style: HD.bodyBold(size: 12.5, color: color),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  maxLines: 3,
                  style: HD.body(size: 9.5, color: HD.inkMuted),
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right_rounded, size: 18, color: color),
        ],
      ),
    ),
  ),
);

String _money(double? value) {
  if (value == null) return '—';
  if (value >= 1000000) {
    final number = value / 1000000;
    return '${number.toStringAsFixed(number == number.roundToDouble() ? 0 : 1)} tr';
  }
  if (value >= 1000) return '${(value / 1000).round()}k';
  return value.round().toString();
}
