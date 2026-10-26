import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:house_booking/core/config/api_config.dart';
import 'package:house_booking/core/widgets/ds.dart';
import 'package:house_booking/data/models/building_model.dart';
import 'package:house_booking/data/models/room_model.dart';
import 'package:house_booking/data/repositories/api_building_repository.dart';
import 'package:house_booking/data/repositories/api_room_repository.dart';
import 'package:house_booking/data/services/ho_so_phong_api.dart';
import 'package:house_booking/features/host/dien_nuoc/chup_cong_to_sheet.dart';
import 'package:house_booking/features/host/property/providers/contract_provider.dart';
import 'package:house_booking/features/host/property/screens/ho_so_phong_screen.dart';

enum StayWorkspaceRole { owner, sale }

/// Sổ phòng đang ở dành riêng cho luồng dài hạn. Màn này chỉ là nội dung của
/// tab Quản lý/Hoạt động; tuyệt đối không dựng lại bottom navigation của app.
class LongTermStayWorkspaceScreen extends StatefulWidget {
  const LongTermStayWorkspaceScreen({
    super.key,
    required this.role,
    this.buildingRepository,
    this.roomRepository,
  });

  final StayWorkspaceRole role;
  final ApiBuildingRepository? buildingRepository;
  final ApiRoomRepository? roomRepository;

  @override
  State<LongTermStayWorkspaceScreen> createState() =>
      _LongTermStayWorkspaceScreenState();
}

class _LongTermStayWorkspaceScreenState
    extends State<LongTermStayWorkspaceScreen> {
  late final ApiBuildingRepository _buildings =
      widget.buildingRepository ?? ApiBuildingRepository();
  late final ApiRoomRepository _rooms =
      widget.roomRepository ?? ApiRoomRepository();
  List<({BuildingModel building, RoomModel room})> _items = const [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final buildings = await _buildings.fetchBuildings();
      final roomLists = await Future.wait([
        for (final building in buildings) _rooms.fetchRooms(building.id),
      ]);
      final items = <({BuildingModel building, RoomModel room})>[];
      for (var i = 0; i < buildings.length; i++) {
        for (final room in roomLists[i]) {
          if (room.dangThue) items.add((building: buildings[i], room: room));
        }
      }
      items.sort((a, b) => a.room.code.compareTo(b.room.code));
      if (mounted) setState(() => _items = items);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Chưa tải được danh sách phòng đang ở.');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _open(({BuildingModel building, RoomModel room}) item) {
    if (widget.role == StayWorkspaceRole.sale) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) =>
              SaleStayRoomScreen(room: item.room, building: item.building),
        ),
      );
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChangeNotifierProvider(
          create: (_) => ContractProvider(),
          builder: (context, _) => HoSoPhongScreen(
            room: item.room,
            contractProvider: context.read<ContractProvider>(),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final sale = widget.role == StayWorkspaceRole.sale;
    return Scaffold(
      backgroundColor: const Color(0xfff7f9fc),
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        titleSpacing: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              sale ? 'Phòng đang ở được phân công' : 'Phòng đang ở',
              style: HD.bodyBold(size: 17),
            ),
            Text(
              sale
                  ? 'Theo dõi và hỗ trợ khách thuê'
                  : 'Quản lý hợp đồng, chỉ số và hóa đơn',
              style: HD.body(size: 10.5, color: HD.inkMuted),
            ),
          ],
        ),
        actions: [
          IconButton(onPressed: _load, icon: const Icon(Icons.refresh_rounded)),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 28),
          children: [
            _WorkspaceIntro(role: widget.role, count: _items.length),
            const SizedBox(height: 14),
            if (_loading)
              const Padding(
                padding: EdgeInsets.only(top: 80),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_error != null)
              _EmptyPanel(
                icon: Icons.cloud_off_outlined,
                title: _error!,
                detail: 'Chạm làm mới để thử lại.',
              )
            else if (_items.isEmpty)
              _EmptyPanel(
                icon: Icons.meeting_room_outlined,
                title: sale
                    ? 'Chưa có phòng đang ở được phân công'
                    : 'Chưa có phòng đang ở',
                detail: sale
                    ? 'Phòng do Chủ nhà phân công sẽ xuất hiện tại đây.'
                    : 'Khi hợp đồng bắt đầu, phòng sẽ xuất hiện trong sổ này.',
              )
            else ...[
              Row(
                children: [
                  Expanded(
                    child: Text(
                      sale ? 'Phòng của tôi' : 'Danh sách phòng đang ở',
                      style: HD.bodyBold(size: 16),
                    ),
                  ),
                  _StatusPill(
                    '${_items.length} phòng',
                    const Color(0xffe8f8ef),
                    const Color(0xff087b4d),
                  ),
                ],
              ),
              const SizedBox(height: 9),
              for (final item in _items) ...[
                _OccupiedRoomCard(
                  item: item,
                  role: widget.role,
                  onTap: () => _open(item),
                ),
                const SizedBox(height: 10),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

class _WorkspaceIntro extends StatelessWidget {
  const _WorkspaceIntro({required this.role, required this.count});
  final StayWorkspaceRole role;
  final int count;

  @override
  Widget build(BuildContext context) {
    final sale = role == StayWorkspaceRole.sale;
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xffed1b2f), Color(0xffff4b5d)],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: .18),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              sale ? Icons.support_agent_rounded : Icons.home_work_rounded,
              color: Colors.white,
              size: 29,
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  sale ? 'Đồng hành cùng Chủ nhà' : 'Chủ động quản lý',
                  style: HD.bodyBold(size: 17, color: Colors.white),
                ),
                const SizedBox(height: 3),
                Text(
                  sale
                      ? 'Theo dõi $count phòng, hỗ trợ chỉ số và sự cố'
                      : '$count phòng có khách · quản lý dòng tiền rõ ràng',
                  style: HD.body(size: 12, color: Colors.white),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _OccupiedRoomCard extends StatelessWidget {
  const _OccupiedRoomCard({
    required this.item,
    required this.role,
    required this.onTap,
  });
  final ({BuildingModel building, RoomModel room}) item;
  final StayWorkspaceRole role;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final room = item.room;
    final image = room.images.firstOrNull ?? item.building.anhBia;
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(11),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xffe5e9f0)),
          ),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(11),
                child: SizedBox(
                  width: 82,
                  height: 82,
                  child: image == null
                      ? Container(
                          color: const Color(0xffffedef),
                          child: const Icon(
                            Icons.apartment_rounded,
                            color: HD.accent,
                            size: 36,
                          ),
                        )
                      : CachedNetworkImage(
                          imageUrl: _absolute(image),
                          fit: BoxFit.cover,
                          errorWidget: (_, _, _) => const ColoredBox(
                            color: Color(0xffffedef),
                            child: Icon(
                              Icons.apartment_rounded,
                              color: HD.accent,
                            ),
                          ),
                        ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(room.code, style: HD.bodyBold(size: 16)),
                        ),
                        _StatusPill(
                          room.tinhTrangHien == 'sap_tra'
                              ? 'Sắp trả'
                              : 'Đang ở',
                          room.tinhTrangHien == 'sap_tra'
                              ? const Color(0xfffff3e0)
                              : const Color(0xffe8f8ef),
                          room.tinhTrangHien == 'sap_tra'
                              ? const Color(0xffd97706)
                              : const Color(0xff087b4d),
                        ),
                      ],
                    ),
                    Text(
                      item.building.name,
                      style: HD.body(size: 12.5, color: HD.inkMuted),
                    ),
                    if (role == StayWorkspaceRole.owner &&
                        room.khachThue != null)
                      Text(room.khachThue!, style: HD.bodyBold(size: 12.5)),
                    const SizedBox(height: 5),
                    Text(
                      '${_money(room.giaKenh ?? room.basePrice)}đ/tháng',
                      style: HD.bodyBold(size: 14, color: HD.accent),
                    ),
                    if (room.hopDongDen != null)
                      Text(
                        'Hết hạn: ${_date(room.hopDongDen!)}',
                        style: HD.caption(color: HD.inkMuted),
                      ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: HD.inkMuted),
            ],
          ),
        ),
      ),
    );
  }
}

/// Chi tiết phòng dành cho Sale: cùng cấu trúc thẻ ảnh/tabs trong mockup,
/// nhưng không bao giờ cung cấp thao tác sửa tài khoản nhận tiền hay duyệt thu.
class SaleStayRoomScreen extends StatefulWidget {
  const SaleStayRoomScreen({
    super.key,
    required this.room,
    required this.building,
    this.api = const HoSoPhongApi(),
  });
  final RoomModel room;
  final BuildingModel building;
  final HoSoPhongApi api;

  @override
  State<SaleStayRoomScreen> createState() => _SaleStayRoomScreenState();
}

class _SaleStayRoomScreenState extends State<SaleStayRoomScreen> {
  HoSoPhong? _profile;
  bool _loading = true;
  String? _error;
  int _tab = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final value = await widget.api.lay(widget.room.id);
      if (mounted) setState(() => _profile = value);
    } catch (_) {
      if (mounted) setState(() => _error = 'Chưa tải được hồ sơ phòng.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _meters() => Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => SaleMeterCaptureScreen(
        room: widget.room,
        building: widget.building,
        meter: _profile?.dienNuoc,
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final profile = _profile;
    final room = profile?.room ?? widget.room;
    return Scaffold(
      backgroundColor: const Color(0xfff7f9fc),
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        titleSpacing: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'Chi tiết phòng ${room.code}',
                  style: HD.bodyBold(size: 16),
                ),
                const SizedBox(width: 7),
                const _StatusPill(
                  'Đang ở',
                  Color(0xffe8f8ef),
                  Color(0xff087b4d),
                ),
              ],
            ),
            Text(
              widget.building.name,
              style: HD.body(size: 10.5, color: HD.inkMuted),
            ),
          ],
        ),
        actions: [
          IconButton(onPressed: _load, icon: const Icon(Icons.refresh_rounded)),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(child: Text(_error!))
          : ListView(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 28),
              children: [
                _SaleRoomHero(room: room),
                const SizedBox(height: 10),
                Row(
                  children: [
                    _RoomFact(
                      Icons.crop_square_rounded,
                      '${_number(room.areaM2)} m²',
                      'Diện tích',
                    ),
                    _RoomFact(
                      Icons.layers_outlined,
                      room.tang ?? '—',
                      'Vị trí',
                    ),
                    _RoomFact(
                      Icons.explore_outlined,
                      RoomModel.nhanHuong[room.huong] ?? '—',
                      'Hướng',
                    ),
                  ],
                ),
                const SizedBox(height: 11),
                _Tabs(index: _tab, onChanged: (v) => setState(() => _tab = v)),
                const SizedBox(height: 11),
                if (_tab == 0)
                  _overview(profile)
                else if (_tab == 1)
                  _metersPanel(profile)
                else if (_tab == 2)
                  _invoices(profile)
                else
                  _support(profile),
              ],
            ),
    );
  }

  Widget _overview(HoSoPhong? p) => Column(
    children: [
      _RolePanel(
        title: 'Khách thuê hiện tại',
        icon: Icons.person_rounded,
        children: [
          if (p?.hopDong?.khach case final tenant?) ...[
            _Line('Họ tên', tenant.ten),
            _Line('Điện thoại', tenant.sdt.isEmpty ? 'Chưa có' : tenant.sdt),
          ] else
            Text(
              'Thông tin cá nhân được Chủ nhà bảo vệ.',
              style: HD.body(size: 12.5, color: HD.inkMuted),
            ),
        ],
      ),
      const SizedBox(height: 10),
      _RolePanel(
        title: 'Chủ nhà',
        icon: Icons.home_work_rounded,
        children: [
          _Line('Tòa nhà', widget.building.name),
          _Line(
            'Địa chỉ',
            widget.building.address.isEmpty
                ? 'Chưa cập nhật'
                : widget.building.address,
          ),
        ],
      ),
      const SizedBox(height: 10),
      _RedOutlineButton(
        icon: Icons.camera_alt_outlined,
        text: 'Chụp số điện / số nước',
        onTap: _meters,
      ),
    ],
  );

  Widget _metersPanel(HoSoPhong? p) {
    final m = p?.dienNuoc;
    return Column(
      children: [
        _RolePanel(
          title: 'Chỉ số tháng ${m?.thang ?? 'này'}',
          icon: Icons.speed_rounded,
          children: [
            _Line(
              'Điện',
              '${_number(m?.dienMoi)} kWh',
              note: 'Cũ ${_number(m?.dienCu)} · dùng ${_number(m?.dienDung)}',
            ),
            _Line(
              'Nước',
              '${_number(m?.nuocMoi)} m³',
              note: 'Cũ ${_number(m?.nuocCu)} · dùng ${_number(m?.nuocDung)}',
            ),
            _Line('Trạng thái', _meterStatus(m?.trangThai)),
          ],
        ),
        const SizedBox(height: 10),
        _RedButton(
          icon: Icons.send_rounded,
          text: 'Chụp và gửi Chủ nhà duyệt',
          onTap: _meters,
        ),
        const SizedBox(height: 10),
        _Notice(
          'Sale hỗ trợ ghi nhận và gửi chỉ số. Chủ nhà là người duyệt cuối và tạo hóa đơn.',
        ),
      ],
    );
  }

  Widget _invoices(HoSoPhong? p) => Column(
    children: [
      _RolePanel(
        title: 'Theo dõi hóa đơn',
        icon: Icons.receipt_long_rounded,
        children: [
          if (p?.hoaDon.isEmpty ?? true)
            Text(
              'Chưa có hóa đơn.',
              style: HD.body(size: 12.5, color: HD.inkMuted),
            )
          else
            for (final bill in p!.hoaDon) _InvoiceLine(bill: bill),
        ],
      ),
      const SizedBox(height: 10),
      _Notice(
        'Chu kỳ, ngày chốt và hạn thanh toán do Chủ nhà cấu hình. Sale chỉ theo dõi, không xác nhận thu tiền.',
      ),
    ],
  );

  Widget _support(HoSoPhong? p) => _RolePanel(
    title: 'Lịch sử hỗ trợ / báo cáo',
    icon: Icons.support_agent_rounded,
    children: [
      if (p?.suaChua.isEmpty ?? true)
        Text(
          'Chưa có yêu cầu hỗ trợ.',
          style: HD.body(size: 12.5, color: HD.inkMuted),
        )
      else
        for (final item in p!.suaChua)
          _TimelineItem(
            title: item.tieuDe,
            date: _date(item.ngay),
            done: !item.dangXuLy,
          ),
      if ((p?.hoaDon ?? const []).isNotEmpty)
        for (final bill in p!.hoaDon.take(3))
          _TimelineItem(
            title: 'Hóa đơn kỳ ${bill.ky}',
            date: _date(bill.hanDong),
            done: bill.trangThai == 'paid',
          ),
    ],
  );
}

class SaleMeterCaptureScreen extends StatefulWidget {
  const SaleMeterCaptureScreen({
    super.key,
    required this.room,
    required this.building,
    required this.meter,
  });

  final RoomModel room;
  final BuildingModel building;
  final DienNuocPhong? meter;

  @override
  State<SaleMeterCaptureScreen> createState() => _SaleMeterCaptureScreenState();
}

class _SaleMeterCaptureScreenState extends State<SaleMeterCaptureScreen> {
  String _type = 'dien';

  Future<void> _capture() async {
    final meter = widget.meter;
    final electricity = _type == 'dien';
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => ChupCongToSheet(
        roomId: widget.room.id,
        maPhong: widget.room.code,
        loai: _type,
        chiSoCu: electricity ? meter?.dienCu : meter?.nuocCu,
        chiSoDangGhi: electricity ? meter?.dienMoi : meter?.nuocMoi,
        nguonDangGhi: 'Chỉ số đang ghi',
      ),
    );
    if (saved == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đã gửi ảnh và chỉ số cho Chủ nhà.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final meter = widget.meter;
    final electricity = _type == 'dien';
    final oldValue = electricity ? meter?.dienCu : meter?.nuocCu;
    final currentValue = electricity ? meter?.dienMoi : meter?.nuocMoi;
    final unit = electricity ? 'kWh' : 'm³';
    return Scaffold(
      backgroundColor: const Color(0xfff7f9fc),
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        titleSpacing: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Chụp số điện / số nước', style: HD.bodyBold(size: 16)),
            Text(
              '${widget.room.code} · ${widget.building.name}',
              style: HD.body(size: 10.5, color: HD.inkMuted),
            ),
          ],
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 28),
        children: [
          _Notice(
            'Chụp ảnh công tơ rõ đủ ánh sáng để Chủ nhà đối chiếu. Ảnh sẽ được đóng dấu ngày giờ và vị trí.',
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: const Color(0xffedf1f6),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                _meterType('dien', Icons.bolt_rounded, 'Số điện'),
                _meterType('nuoc', Icons.water_drop_rounded, 'Số nước'),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _RolePanel(
            title: electricity ? 'Ảnh công tơ điện *' : 'Ảnh đồng hồ nước *',
            icon: Icons.camera_alt_rounded,
            children: [
              Container(
                height: 178,
                decoration: BoxDecoration(
                  color: const Color(0xfffff3ea),
                  borderRadius: BorderRadius.circular(13),
                  border: Border.all(color: const Color(0xffffd5b2)),
                ),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        electricity
                            ? Icons.electric_meter_outlined
                            : Icons.water_damage_outlined,
                        size: 48,
                        color: electricity
                            ? const Color(0xffff7a00)
                            : const Color(0xff2474e5),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Chụp ảnh hoặc chọn camera',
                        style: HD.bodyBold(size: 13),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              _Line('Chỉ số tháng trước', '${_number(oldValue)} $unit'),
              _Line('Chỉ số đang ghi', '${_number(currentValue)} $unit'),
              _Line('Ngày ghi chỉ số', _date(meter?.ngayChot ?? 'Chưa ghi')),
            ],
          ),
          const SizedBox(height: 12),
          _Notice(
            'Sale chỉ ghi nhận và gửi hồ sơ. Chủ nhà duyệt số cuối cùng, cấu hình đơn giá và tạo hóa đơn.',
          ),
          const SizedBox(height: 12),
          _RedButton(
            icon: Icons.send_rounded,
            text: 'Chụp ảnh và gửi Chủ nhà duyệt',
            onTap: _capture,
          ),
        ],
      ),
    );
  }

  Widget _meterType(String value, IconData icon, String label) => Expanded(
    child: InkWell(
      onTap: () => setState(() => _type = value),
      borderRadius: BorderRadius.circular(9),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 11),
        decoration: BoxDecoration(
          color: _type == value ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(9),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 20,
              color: _type == value ? HD.accent : HD.inkMuted,
            ),
            const SizedBox(width: 7),
            Text(
              label,
              style: HD.bodyBold(
                size: 13,
                color: _type == value ? HD.accent : HD.inkMuted,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _SaleRoomHero extends StatelessWidget {
  const _SaleRoomHero({required this.room});
  final RoomModel room;
  @override
  Widget build(BuildContext context) {
    final image = room.images.firstOrNull;
    return ClipRRect(
      borderRadius: BorderRadius.circular(15),
      child: Stack(
        alignment: Alignment.bottomLeft,
        children: [
          SizedBox(
            width: double.infinity,
            height: 190,
            child: image == null
                ? const ColoredBox(
                    color: Color(0xffffedef),
                    child: Icon(
                      Icons.home_work_rounded,
                      size: 62,
                      color: HD.accent,
                    ),
                  )
                : CachedNetworkImage(
                    imageUrl: _absolute(image),
                    fit: BoxFit.cover,
                  ),
          ),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(14, 35, 14, 13),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.transparent, Color(0xcc000000)],
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  room.loaiPhong ?? 'Phòng ${room.code}',
                  style: HD.bodyBold(size: 14, color: Colors.white),
                ),
                Text(
                  '${_money(room.giaKenh ?? room.basePrice)}đ/tháng',
                  style: HD.bodyBold(size: 22, color: Colors.white),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RoomFact extends StatelessWidget {
  const _RoomFact(this.icon, this.value, this.label);
  final IconData icon;
  final String value;
  final String label;
  @override
  Widget build(BuildContext context) => Expanded(
    child: Container(
      margin: const EdgeInsets.symmetric(horizontal: 3),
      padding: const EdgeInsets.symmetric(vertical: 11),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xffe6eaf0)),
      ),
      child: Column(
        children: [
          Icon(icon, color: HD.accent, size: 21),
          const SizedBox(height: 4),
          Text(value, style: HD.bodyBold(size: 12)),
          Text(label, style: HD.caption(color: HD.inkMuted)),
        ],
      ),
    ),
  );
}

class _Tabs extends StatelessWidget {
  const _Tabs({required this.index, required this.onChanged});
  final int index;
  final ValueChanged<int> onChanged;
  static const labels = ['Tổng quan', 'Điện nước', 'Hóa đơn', 'Hỗ trợ'];
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(4),
    decoration: BoxDecoration(
      color: const Color(0xffedf1f6),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Row(
      children: [
        for (var i = 0; i < labels.length; i++)
          Expanded(
            child: InkWell(
              onTap: () => onChanged(i),
              borderRadius: BorderRadius.circular(9),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 2),
                decoration: BoxDecoration(
                  color: i == index ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Text(
                  labels[i],
                  textAlign: TextAlign.center,
                  style: HD.bodyBold(
                    size: 10.5,
                    color: i == index ? HD.accent : HD.inkMuted,
                  ),
                ),
              ),
            ),
          ),
      ],
    ),
  );
}

class _RolePanel extends StatelessWidget {
  const _RolePanel({
    required this.title,
    required this.icon,
    required this.children,
  });
  final String title;
  final IconData icon;
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: const Color(0xffe5e9f0)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: HD.accent, size: 21),
            const SizedBox(width: 8),
            Text(title, style: HD.bodyBold(size: 15)),
          ],
        ),
        const Divider(height: 20),
        ...children,
      ],
    ),
  );
}

class _Line extends StatelessWidget {
  const _Line(this.label, this.value, {this.note});
  final String label;
  final String value;
  final String? note;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 7),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(label, style: HD.body(size: 12.5, color: HD.inkMuted)),
        ),
        const SizedBox(width: 12),
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                value,
                textAlign: TextAlign.right,
                style: HD.bodyBold(size: 12.5),
              ),
              if (note != null)
                Text(
                  note!,
                  textAlign: TextAlign.right,
                  style: HD.caption(color: HD.inkMuted),
                ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _InvoiceLine extends StatelessWidget {
  const _InvoiceLine({required this.bill});
  final HoaDonGanNhat bill;
  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 8),
    padding: const EdgeInsets.all(11),
    decoration: BoxDecoration(
      color: const Color(0xfffafbfc),
      borderRadius: BorderRadius.circular(10),
    ),
    child: Row(
      children: [
        const Icon(Icons.receipt_rounded, color: HD.accent),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Kỳ ${bill.ky}', style: HD.bodyBold(size: 13)),
              Text(
                'Hạn ${_date(bill.hanDong)}',
                style: HD.caption(color: HD.inkMuted),
              ),
            ],
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text('${_money(bill.tong)}đ', style: HD.bodyBold(size: 13)),
            _StatusPill(
              _invoiceStatus(bill.trangThai),
              bill.trangThai == 'paid'
                  ? const Color(0xffe8f8ef)
                  : const Color(0xfffff1e6),
              bill.trangThai == 'paid'
                  ? const Color(0xff087b4d)
                  : const Color(0xffd66b00),
            ),
          ],
        ),
      ],
    ),
  );
}

class _TimelineItem extends StatelessWidget {
  const _TimelineItem({
    required this.title,
    required this.date,
    required this.done,
  });
  final String title;
  final String date;
  final bool done;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: done ? const Color(0xff13a268) : HD.accent,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(child: Text(title, style: HD.bodyBold(size: 12.5))),
        Text(date, style: HD.caption(color: HD.inkMuted)),
      ],
    ),
  );
}

class _Notice extends StatelessWidget {
  const _Notice(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: const Color(0xfffff6e9),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(
          Icons.info_outline_rounded,
          color: Color(0xffe78300),
          size: 20,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: HD.body(size: 11.5, color: const Color(0xff8a5700)),
          ),
        ),
      ],
    ),
  );
}

class _RedButton extends StatelessWidget {
  const _RedButton({
    required this.icon,
    required this.text,
    required this.onTap,
  });
  final IconData icon;
  final String text;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => SizedBox(
    width: double.infinity,
    child: FilledButton.icon(
      onPressed: onTap,
      style: FilledButton.styleFrom(
        backgroundColor: HD.accent,
        padding: const EdgeInsets.symmetric(vertical: 14),
      ),
      icon: Icon(icon),
      label: Text(text),
    ),
  );
}

class _RedOutlineButton extends StatelessWidget {
  const _RedOutlineButton({
    required this.icon,
    required this.text,
    required this.onTap,
  });
  final IconData icon;
  final String text;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => SizedBox(
    width: double.infinity,
    child: OutlinedButton.icon(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        foregroundColor: HD.accent,
        side: const BorderSide(color: HD.accent),
        padding: const EdgeInsets.symmetric(vertical: 13),
      ),
      icon: Icon(icon),
      label: Text(text),
    ),
  );
}

class _StatusPill extends StatelessWidget {
  const _StatusPill(this.text, this.background, this.foreground);
  final String text;
  final Color background;
  final Color foreground;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: background,
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(text, style: HD.bodyBold(size: 10.5, color: foreground)),
  );
}

class _EmptyPanel extends StatelessWidget {
  const _EmptyPanel({
    required this.icon,
    required this.title,
    required this.detail,
  });
  final IconData icon;
  final String title;
  final String detail;
  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(top: 30),
    padding: const EdgeInsets.all(26),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: const Color(0xffe5e9f0)),
    ),
    child: Column(
      children: [
        Icon(icon, size: 44, color: HD.inkMuted),
        const SizedBox(height: 12),
        Text(title, textAlign: TextAlign.center, style: HD.bodyBold(size: 16)),
        const SizedBox(height: 5),
        Text(
          detail,
          textAlign: TextAlign.center,
          style: HD.body(size: 12.5, color: HD.inkMuted),
        ),
      ],
    ),
  );
}

String _absolute(String value) =>
    value.startsWith('http') ? value : '${ApiConfig.baseUrl}$value';
String _money(double value) => value
    .toStringAsFixed(0)
    .replaceAllMapped(RegExp(r'(?=(\d{3})+(?!\d))'), (_) => '.');
String _date(String value) => value.length >= 10
    ? '${value.substring(8, 10)}/${value.substring(5, 7)}/${value.substring(0, 4)}'
    : value;
String _number(num? value) => value == null
    ? '—'
    : (value % 1 == 0 ? value.toInt().toString() : value.toStringAsFixed(1));
String _meterStatus(String? value) => switch (value) {
  'da_duyet' => 'Đã duyệt',
  'cho_duyet' => 'Chờ Chủ nhà duyệt',
  'thieu_anh' => 'Thiếu ảnh',
  'can_chup_lai' => 'Cần chụp lại',
  _ => 'Chưa gửi',
};
String _invoiceStatus(String value) => switch (value) {
  'paid' => 'Đã thanh toán',
  'overdue' => 'Quá hạn',
  'sent' => 'Chưa thanh toán',
  _ => 'Bản nháp',
};
