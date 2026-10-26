import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:house_booking/data/models/building_model.dart';
import 'package:house_booking/data/models/room_model.dart';
import 'package:house_booking/features/guest/broker/broker_profile_screen.dart';
import 'package:house_booking/features/host/ngan_han/lich_ngan_han_screen.dart';
import 'package:house_booking/features/host/ngan_han/loai_phong_screen.dart';
import 'package:house_booking/features/host/dashboard/host_dashboard_tokens.dart';
import 'package:house_booking/features/host/dien_nuoc/dien_nuoc_dai_han_screen.dart'
    show anhTuyetDoi;
import 'package:house_booking/features/host/property/providers/building_provider.dart';
import 'package:house_booking/features/host/property/providers/room_provider.dart';
import 'package:house_booking/features/host/property/screens/room_detail_screen.dart';
import 'package:house_booking/features/host/property/screens/room_form_screen.dart';
import 'package:house_booking/features/host/property/widgets/hop_thoai_gia_toa.dart';
import 'package:house_booking/features/host/property/widgets/hop_thoai_ma_toa.dart';
import 'package:house_booking/features/host/property/widgets/room_grid_card.dart';
import 'package:house_booking/features/notifications/notifications_screen.dart';
import 'package:house_booking/providers/auth_provider.dart';
import 'package:house_booking/providers/notification_provider.dart';

/// QUẢN LÍ PHÒNG — sổ phòng của một toà, dựng theo mockup "Quản lí phòng - An
/// Cư Garden" (11/09/2026): thẻ toà + đổi toà · chip loại hình · bốn thẻ số ·
/// tìm / bộ lọc / sắp xếp · lưới hoặc danh sách phòng · nút + thêm phòng. Thanh
/// điều hướng dưới là của app, không vẽ ở đây. Route: không (push từ Trang chủ,
/// danh sách toà, dự án của sale). Provider: [RoomProvider] (tự dựng),
/// [BuildingProvider] (toàn app — địa chỉ, ảnh bìa, đổi toà). API:
/// `GET /api/host/buildings/{id}/rooms` — mỗi phòng kèm `tinh_trang`, `loai`,
/// khách + hạn hợp đồng (backend `so_phong.py`, cùng luật "đang thuê" với
/// Trang chủ chủ nhà).
///
/// Mockup không có chỗ cho hai lối cũ "Giá điện nước mặc định" và "Mời sale
/// phụ trách" — cả hai nằm trong menu mở từ TÊN TOÀ (mũi tên ▾). Bỏ hẳn là chủ
/// nhà mất đường khai giá toà và mất mã mời sale.
class BuildingDetailScreen extends StatefulWidget {
  final int buildingId;
  final String buildingName;

  /// Ai đang đứng tên toà. Cần để biết có được MỜI SALE hay không — chỉ người
  /// đứng tên mới mời được, và màn này cũng mở từ trang dự án của sale.
  ///
  /// `null` = chưa biết → ẩn nút, không đoán. Đoán sai thì nút hiện ra rồi bấm
  /// vào nhận 404, tệ hơn là không có nút.
  final int? hostId;

  /// Chỉ để test bơm provider có sẵn dữ liệu. Màn này tự dựng và tự nạp phòng
  /// từ mạng, nên không bơm được thì test chỉ thấy vòng quay tải mãi.
  final RoomProvider? roomProvider;

  const BuildingDetailScreen({
    super.key,
    required this.buildingId,
    required this.buildingName,
    this.hostId,
    this.roomProvider,
  });

  @override
  State<BuildingDetailScreen> createState() => _BuildingDetailScreenState();
}

class _BuildingDetailScreenState extends State<BuildingDetailScreen> {
  late final RoomProvider _roomProvider;
  bool get _tuDung => widget.roomProvider == null;

  // "Đổi tòa nhà" đổi ngay tại màn — không chồng thêm một màn nữa lên ngăn xếp.
  late int _toaId = widget.buildingId;
  late String _tenToa = widget.buildingName;
  late int? _chuToaId = widget.hostId;

  String _loai = 'tat_ca';
  String _tinhTrang = 'tat_ca';
  String _sapXep = 'ma';
  bool _dangDanhSach = false;
  final _tim = TextEditingController();

  static const _cacLoai = [
    ('tat_ca', 'Tất cả', Icons.grid_view_rounded),
    ('ngan_han', 'Ngắn hạn', Icons.schedule),
    ('dai_han', 'Dài hạn', Icons.calendar_today_outlined),
    ('kinh_doanh', 'Kinh doanh', Icons.storefront_outlined),
    ('khach_san', 'Khách sạn', Icons.apartment_outlined),
  ];

  static const _cacTinhTrang = [
    ('tat_ca', 'Mọi tình trạng'),
    ('dang_o', 'Đang ở'),
    ('sap_tra', 'Sắp trả'),
    ('trong', 'Trống'),
    ('bao_tri', 'Bảo trì'),
  ];

  static const _cacSapXep = [
    ('ma', 'Mã phòng A → Z'),
    ('gia_tang', 'Giá thấp → cao'),
    ('gia_giam', 'Giá cao → thấp'),
    ('het_han', 'Hợp đồng sắp hết trước'),
  ];

  @override
  void initState() {
    super.initState();
    _roomProvider = widget.roomProvider ?? RoomProvider();
    _tim.addListener(() => setState(() {}));
    if (_tuDung) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _roomProvider.fetchRooms(_toaId);
        // Mở từ Trang chủ thì danh sách toà có thể chưa nạp — cần nó cho địa
        // chỉ, ảnh bìa và "Đổi tòa nhà".
        final bp = Provider.of<BuildingProvider?>(context, listen: false);
        if (bp != null && bp.buildings.isEmpty && !bp.isLoading) {
          bp.fetchBuildings();
        }
      });
    }
  }

  @override
  void dispose() {
    _tim.dispose();
    // Chỉ huỷ cái do màn này TỰ dựng. Huỷ cái người khác bơm vào là làm hỏng
    // đối tượng họ còn đang dùng.
    if (_tuDung) _roomProvider.dispose();
    super.dispose();
  }

  // ── Hành động ─────────────────────────────────────────────────────────────

  /// Toà có phòng nào đang chạy kênh ngắn hạn không — lối vào "Loại phòng"
  /// chỉ có nghĩa với mô hình bán theo hạng.
  static bool _coNganHan(List<RoomModel> phong) =>
      phong.any((r) => r.loai.contains('ngan_han'));

  Future<void> _moLichNganHan() => Navigator.push(
    context,
    MaterialPageRoute(builder: (_) => LichNganHanScreen(buildingId: _toaId)),
  );

  Future<void> _moLoaiPhong() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => LoaiPhongScreen(buildingId: _toaId, tenToa: _tenToa),
      ),
    );
    if (mounted) _roomProvider.fetchRooms(_toaId);
  }

  Future<void> _openCreate() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChangeNotifierProvider.value(
          value: _roomProvider,
          child: RoomFormScreen(buildingId: _toaId),
        ),
      ),
    );
    _roomProvider.fetchRooms(_toaId);
  }

  void _openRoom(int roomId) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChangeNotifierProvider.value(
          value: _roomProvider,
          child: RoomDetailScreen(roomId: roomId),
        ),
      ),
    );
  }

  Future<void> _suaPhong(RoomModel room) async {
    final ok = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => ChangeNotifierProvider.value(
          value: _roomProvider,
          child: RoomFormScreen(buildingId: room.buildingId, phong: room),
        ),
      ),
    );
    if (ok == true && mounted) _roomProvider.fetchRooms(_toaId);
  }

  /// Hỏi lại bằng CHÍNH MÃ PHÒNG — "Bạn có chắc không?" thì ai cũng bấm Đồng ý.
  Future<void> _xoaPhong(RoomModel room) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Xoá phòng ${room.code}?'),
        content: Text(
          'Phòng và các kênh đang rao của nó sẽ mất hẳn. Không khôi phục được.',
          style: HD.body(size: 13, color: HD.inkSoft),
        ),
        actions: [
          // Pop bằng context CỦA HỘP THOẠI: màn này nằm trong Navigator lồng
          // theo tab, pop bằng context màn là hộp thoại treo lại.
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Không'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Xoá phòng'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final loi = await _roomProvider.deleteRoom(room.id);
    if (!mounted || loi == null) return;
    // Nguyên văn câu server: "Phòng đã có hợp đồng, không xoá được." nói rõ
    // phải làm gì hơn bất cứ câu chung chung nào.
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(loi)));
  }

  /// Chỉ người ĐỨNG TÊN toà mới mời sale được — endpoint cũng hẹp đúng thế,
  /// nên hiện nút cho người khác chỉ để họ bấm vào và nhận 404.
  bool get _laChuToa {
    final me = Provider.of<AuthProvider>(context, listen: false).currentUser?.id;
    return me != null && _chuToaId != null && me == _chuToaId;
  }

  /// Giá điện/nước/dịch vụ mặc định cho cả toà — nơi khai MỘT lần thay vì gõ
  /// lại ở từng phòng, và thay vì gõ lại mỗi tháng lúc chốt hoá đơn.
  Future<void> _giaToa(BuildingProvider bp) async {
    final toa = _timToa(bp);
    await showDialog<bool>(
      context: context,
      builder: (_) => ChangeNotifierProvider<BuildingProvider>.value(
        value: bp,
        child: HopThoaiGiaToa(
          buildingId: _toaId,
          giaDien: toa?.giaDien,
          giaNuoc: toa?.giaNuoc,
          phiDichVu: toa?.phiDichVu,
        ),
      ),
    );
    // Giá toà đổi → giá HIỆU LỰC của mọi phòng chưa khai riêng đổi theo, mà số
    // đó do server tính. Nạp lại chứ không sửa tại chỗ.
    if (mounted) _roomProvider.fetchRooms(_toaId);
  }

  Future<void> _moiSale() => showDialog<void>(
    context: context,
    builder: (_) => HopThoaiMaMoiSale(buildingId: _toaId, tenToa: _tenToa),
  );

  void _doiToa(BuildingModel b) {
    if (b.id == _toaId) return;
    _tim.clear();
    setState(() {
      _toaId = b.id;
      _tenToa = b.name;
      _chuToaId = b.hostId;
      _loai = 'tat_ca';
      _tinhTrang = 'tat_ca';
    });
    _roomProvider.fetchRooms(b.id);
  }

  void _boLoc() {
    _tim.clear();
    setState(() {
      _loai = 'tat_ca';
      _tinhTrang = 'tat_ca';
    });
  }

  BuildingModel? _timToa(BuildingProvider? bp) {
    for (final b in bp?.buildings ?? const <BuildingModel>[]) {
      if (b.id == _toaId) return b;
    }
    return null;
  }

  // ── Dựng ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final bp = context.watch<BuildingProvider?>();
    return ChangeNotifierProvider.value(
      value: _roomProvider,
      child: Scaffold(
        backgroundColor: HD.paperRaised,
        floatingActionButton: FloatingActionButton(
          heroTag: null,
          tooltip: 'Thêm phòng',
          onPressed: _openCreate,
          backgroundColor: HD.accent,
          foregroundColor: HD.paperRaised,
          shape: const CircleBorder(),
          child: const Icon(Icons.add, size: 28),
        ),
        body: SafeArea(
          bottom: false,
          child: Consumer<RoomProvider>(
            builder: (_, p, _) => RefreshIndicator(
              color: HD.accent,
              onRefresh: () => _roomProvider.fetchRooms(_toaId),
              child: _noiDung(p, bp),
            ),
          ),
        ),
      ),
    );
  }

  Widget _noiDung(RoomProvider p, BuildingProvider? bp) {
    final toa = _timToa(bp);
    final theoLoai = _loai == 'tat_ca'
        ? p.rooms
        : [
            for (final r in p.rooms)
              if (r.loai.contains(_loai)) r,
          ];
    final hien = _locVaXep(theoLoai);
    final caoThe =
        146 * MediaQuery.textScalerOf(context).scale(1).clamp(1.0, 1.6).toDouble();
    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        const SliverPadding(
          padding: EdgeInsets.fromLTRB(HD.s16, HD.s8, HD.s16, 0),
          sliver: SliverToBoxAdapter(child: _DauTrang()),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(HD.s16, HD.s12, HD.s16, 0),
          sliver: SliverToBoxAdapter(
            child: _TheToa(
              ten: _tenToa,
              diaChi: _diaChi(toa, p.rooms.length),
              anh: toa?.anhBia ?? _anhPhongDau(p.rooms),
              cacToa: bp?.buildings ?? const [],
              toaId: _toaId,
              onDoiToa: _doiToa,
              menu: [
                // Phòng ngắn hạn bán theo HẠNG (khách chọn "Studio VIP", không
                // chọn số phòng) nên toà có phòng ngắn hạn cần lối vào quản lý
                // hạng ngay cạnh sổ phòng.
                if (_coNganHan(p.rooms)) ...[
                  (
                    Icons.grid_view_outlined,
                    'Lịch phòng theo giờ',
                    _moLichNganHan,
                  ),
                  (
                    Icons.category_outlined,
                    'Loại phòng (hạng)',
                    _moLoaiPhong,
                  ),
                ],
                if (bp != null)
                  (
                    Icons.bolt_outlined,
                    'Giá điện nước mặc định',
                    () => _giaToa(bp),
                  ),
                if (_laChuToa)
                  (
                    Icons.person_add_alt_1_outlined,
                    'Mời sale phụ trách',
                    _moiSale,
                  ),
                (
                  Icons.refresh,
                  'Tải lại danh sách phòng',
                  () => _roomProvider.fetchRooms(_toaId),
                ),
              ],
            ),
          ),
        ),
        if (p.isLoading && p.rooms.isNotEmpty)
          const SliverPadding(
            padding: EdgeInsets.fromLTRB(HD.s16, HD.s8, HD.s16, 0),
            sliver: SliverToBoxAdapter(
              child: LinearProgressIndicator(minHeight: 2, color: HD.accent),
            ),
          ),
        SliverPadding(
          padding: const EdgeInsets.only(top: HD.s16),
          sliver: SliverToBoxAdapter(child: _chipLoai()),
        ),
        if (p.isLoading && p.rooms.isEmpty)
          const SliverFillRemaining(
            hasScrollBody: false,
            child: Center(
              child: CircularProgressIndicator(color: HD.accent, strokeWidth: 2),
            ),
          )
        else if (p.error != null && p.rooms.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: _Rong(
              chu: p.error!,
              nut: 'Thử lại',
              onNut: () => _roomProvider.fetchRooms(_toaId),
            ),
          )
        else ...[
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(HD.s16, HD.s16, HD.s16, 0),
            sliver: SliverToBoxAdapter(child: _BonThe(phong: theoLoai)),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(HD.s16, HD.s16, HD.s16, 0),
            sliver: SliverToBoxAdapter(child: _timLocSapXep()),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(HD.s16, HD.s16, HD.s16, HD.s12),
            sliver: SliverToBoxAdapter(child: _tieuDeDanhSach()),
          ),
          if (p.rooms.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: _Rong(
                key: const ValueKey('so-phong-trong'),
                chu: 'Toà này chưa có phòng nào.',
                nut: 'Thêm phòng đầu tiên',
                onNut: _openCreate,
              ),
            )
          else if (hien.isEmpty)
            SliverToBoxAdapter(
              child: _Rong(
                chu: 'Không có phòng nào khớp bộ lọc.',
                nut: 'Bỏ lọc',
                onNut: _boLoc,
              ),
            )
          else if (_dangDanhSach)
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(HD.s16, 0, HD.s16, 96),
              sliver: SliverList.separated(
                itemCount: hien.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (_, i) => _the(hien[i], danhSach: true),
              ),
            )
          else
            SliverPadding(
              // Chừa chỗ dưới cùng cho nút + nổi, không che thẻ cuối.
              padding: const EdgeInsets.fromLTRB(HD.s16, 0, HD.s16, 96),
              sliver: SliverGrid(
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                  mainAxisExtent: caoThe,
                ),
                delegate: SliverChildBuilderDelegate(
                  (_, i) => _the(hien[i]),
                  childCount: hien.length,
                ),
              ),
            ),
        ],
      ],
    );
  }

  Widget _the(RoomModel r, {bool danhSach = false}) => RoomGridCard(
    key: ValueKey('phong-${r.id}'),
    room: r,
    dangDanhSach: danhSach,
    onTap: () => _openRoom(r.id),
    menu: PopupMenuButton<String>(
      key: ValueKey('menu-phong-${r.id}'),
      tooltip: 'Tùy chọn phòng ${r.code}',
      onSelected: (v) {
        if (v == 'xem') _openRoom(r.id);
        if (v == 'sua') _suaPhong(r);
        if (v == 'xoa') _xoaPhong(r);
      },
      itemBuilder: (_) => [
        const PopupMenuItem(value: 'xem', child: Text('Xem chi tiết')),
        const PopupMenuItem(value: 'sua', child: Text('Sửa phòng')),
        PopupMenuItem(
          value: 'xoa',
          child: Text('Xoá phòng', style: HD.body(color: HD.negative)),
        ),
      ],
      child: const Padding(
        padding: EdgeInsets.all(4),
        child: Icon(Icons.more_vert, size: 16, color: HD.inkMuted),
      ),
    ),
  );

  Widget _chipLoai() => SingleChildScrollView(
    scrollDirection: Axis.horizontal,
    padding: const EdgeInsets.symmetric(horizontal: HD.s16),
    child: Row(
      children: [
        for (final (k, nhan, icon) in _cacLoai) ...[
          if (k != 'tat_ca') const SizedBox(width: HD.s8),
          _Chip(
            key: ValueKey('loai-$k'),
            nhan: nhan,
            icon: icon,
            chon: _loai == k,
            onTap: () => setState(() => _loai = k),
          ),
        ],
      ],
    ),
  );

  Widget _timLocSapXep() {
    final vien = OutlineInputBorder(
      borderRadius: BorderRadius.circular(HD.r12),
      borderSide: BorderSide(color: HD.hairline.withValues(alpha: 0.8)),
    );
    return Row(
      children: [
        Expanded(
          child: TextField(
            key: const ValueKey('tim-phong'),
            controller: _tim,
            style: HD.body(size: 12),
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              isDense: true,
              hintText: 'Tìm phòng (VD: P101, tên khách...)',
              hintMaxLines: 1,
              hintStyle: HD.body(size: 12, color: HD.inkMuted),
              prefixIcon: const Icon(Icons.search, size: 17, color: HD.inkMuted),
              prefixIconConstraints: const BoxConstraints(
                minWidth: 34,
                minHeight: 34,
              ),
              suffixIcon: _tim.text.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'Xoá tìm kiếm',
                      onPressed: _tim.clear,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                        minWidth: 32,
                        minHeight: 32,
                      ),
                      icon: const Icon(Icons.close, size: 16),
                    ),
              filled: true,
              fillColor: HD.paper.withValues(alpha: 0.55),
              contentPadding: const EdgeInsets.symmetric(
                vertical: 10,
                horizontal: 10,
              ),
              border: vien,
              enabledBorder: vien,
              focusedBorder: vien.copyWith(
                borderSide: const BorderSide(color: HD.accent),
              ),
            ),
          ),
        ),
        const SizedBox(width: HD.s8),
        PopupMenuButton<String>(
          key: const ValueKey('bo-loc'),
          tooltip: 'Bộ lọc',
          position: PopupMenuPosition.under,
          onSelected: (v) => setState(() => _tinhTrang = v),
          itemBuilder: (_) => [
            for (final (k, nhan) in _cacTinhTrang)
              CheckedPopupMenuItem(
                value: k,
                checked: _tinhTrang == k,
                child: Text(nhan),
              ),
          ],
          child: _NutVien(
            icon: Icons.filter_alt_outlined,
            nhan: 'Bộ lọc',
            bat: _tinhTrang != 'tat_ca',
          ),
        ),
        const SizedBox(width: HD.s8),
        PopupMenuButton<String>(
          key: const ValueKey('sap-xep'),
          tooltip: 'Sắp xếp',
          position: PopupMenuPosition.under,
          onSelected: (v) => setState(() => _sapXep = v),
          itemBuilder: (_) => [
            for (final (k, nhan) in _cacSapXep)
              CheckedPopupMenuItem(
                value: k,
                checked: _sapXep == k,
                child: Text(nhan),
              ),
          ],
          child: _NutVien(
            icon: Icons.sort,
            nhan: 'Sắp xếp',
            bat: _sapXep != 'ma',
          ),
        ),
      ],
    );
  }

  Widget _tieuDeDanhSach() => Row(
    children: [
      Text('Danh sách phòng', style: HD.bodyBold(size: 16)),
      const SizedBox(width: HD.s8),
      Expanded(
        child: Align(
          alignment: Alignment.centerRight,
          // Điện thoại 360px: tiêu đề + hai nút chế độ dài hơn một dòng một
          // chút → thu nhỏ cụm nút thay vì tràn.
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: HD.paperSunken.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(HD.r8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _NutCheDo(
                    key: const ValueKey('che-do-luoi'),
                    icon: Icons.grid_view_rounded,
                    nhan: 'Dạng lưới',
                    chon: !_dangDanhSach,
                    onTap: () => setState(() => _dangDanhSach = false),
                  ),
                  _NutCheDo(
                    key: const ValueKey('che-do-danh-sach'),
                    icon: Icons.format_list_bulleted,
                    nhan: 'Dạng danh sách',
                    chon: _dangDanhSach,
                    onTap: () => setState(() => _dangDanhSach = true),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ],
  );

  List<RoomModel> _locVaXep(List<RoomModel> ds) {
    final tu = _khongDau(_tim.text.trim());
    final ra = [
      for (final r in ds)
        if ((_tinhTrang == 'tat_ca' || r.tinhTrangHien == _tinhTrang) &&
            (tu.isEmpty ||
                _khongDau(r.code).contains(tu) ||
                _khongDau(r.khachThue ?? '').contains(tu)))
          r,
    ];
    double gia(RoomModel r) => r.giaKenh ?? r.basePrice;
    switch (_sapXep) {
      case 'gia_tang':
        ra.sort((a, b) {
          final c = gia(a).compareTo(gia(b));
          return c != 0 ? c : _soSanhMa(a.code, b.code);
        });
      case 'gia_giam':
        ra.sort((a, b) {
          final c = gia(b).compareTo(gia(a));
          return c != 0 ? c : _soSanhMa(a.code, b.code);
        });
      case 'het_han':
        ra.sort((a, b) {
          final x = a.hopDongDen;
          final y = b.hopDongDen;
          if (x != null && y != null && x != y) return x.compareTo(y);
          if (x != null && y == null) return -1;
          if (x == null && y != null) return 1;
          return _soSanhMa(a.code, b.code);
        });
      default:
        ra.sort((a, b) => _soSanhMa(a.code, b.code));
    }
    return ra;
  }

  String _diaChi(BuildingModel? toa, int soPhong) {
    final phan = <String>[];
    for (final x in [toa?.address, toa?.ward, toa?.district, toa?.city]) {
      final s = x?.trim() ?? '';
      if (s.isNotEmpty && !phan.contains(s)) phan.add(s);
    }
    return phan.isEmpty ? '$soPhong phòng' : phan.join(' · ');
  }

  String? _anhPhongDau(List<RoomModel> ds) {
    for (final r in ds) {
      if (r.images.isNotEmpty) return r.images.first;
    }
    return null;
  }
}

// ── Tiện ích ─────────────────────────────────────────────────────────────────

String? _phanTram(int n, int tong) {
  if (tong == 0) return null;
  final r = (n / tong * 1000).round() / 10;
  return '${r == r.roundToDouble() ? r.toStringAsFixed(0) : r.toStringAsFixed(1)}%';
}

/// "P2" đứng trước "P10" — so chữ thuần thì P10 < P2, sai với cách người ta
/// đánh số phòng.
int _soSanhMa(String a, String b) {
  final re = RegExp(r'\d+|\D+');
  final xa = re.allMatches(a.toLowerCase()).map((m) => m.group(0)!).toList();
  final xb = re.allMatches(b.toLowerCase()).map((m) => m.group(0)!).toList();
  for (var i = 0; i < xa.length && i < xb.length; i++) {
    final na = int.tryParse(xa[i]);
    final nb = int.tryParse(xb[i]);
    final c = na != null && nb != null ? na.compareTo(nb) : xa[i].compareTo(xb[i]);
    if (c != 0) return c;
  }
  return xa.length.compareTo(xb.length);
}

const _coDau =
    'àáạảãâầấậẩẫăằắặẳẵèéẹẻẽêềếệểễìíịỉĩòóọỏõôồốộổỗơờớợởỡùúụủũưừứựửữỳýỵỷỹđ';
const _boDau =
    'aaaaaaaaaaaaaaaaaeeeeeeeeeeeiiiiiooooooooooooooooouuuuuuuuuuuyyyyyd';

/// Gõ "nguyen" vẫn ra "Nguyễn" — chủ nhà tìm tên khách trên điện thoại hiếm
/// khi gõ đủ dấu.
String _khongDau(String s) {
  final ra = StringBuffer();
  for (final ch in s.toLowerCase().split('')) {
    final i = _coDau.indexOf(ch);
    ra.write(i < 0 ? ch : _boDau[i]);
  }
  return ra.toString();
}

// ── Thành phần ───────────────────────────────────────────────────────────────

class _DauTrang extends StatelessWidget {
  const _DauTrang();

  @override
  Widget build(BuildContext context) {
    final nav = Navigator.of(context);
    final chuaDoc = (context.watch<NotificationProvider?>()?.unread ?? 0) > 0;
    return Row(
      children: [
        if (nav.canPop()) ...[
          SizedBox(
            width: 32,
            height: 32,
            child: IconButton(
              tooltip: 'Quay lại',
              padding: EdgeInsets.zero,
              onPressed: () => nav.maybePop(),
              icon: const Icon(Icons.chevron_left, size: 26, color: HD.ink),
            ),
          ),
          const SizedBox(width: HD.s8),
        ],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Quản lí phòng',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: HD.bodyBold(size: 20),
              ),
              Text(
                'Quản lý chi tiết các phòng trong tòa nhà',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: HD.body(size: 12, color: HD.inkMuted),
              ),
            ],
          ),
        ),
        const SizedBox(width: HD.s8),
        _NutChuong(
          coChuaDoc: chuaDoc,
          onTap: () => nav.push(
            MaterialPageRoute<void>(builder: (_) => const NotificationsScreen()),
          ),
        ),
        const SizedBox(width: 10),
        const _AnhDaiDien(),
      ],
    );
  }
}

class _NutChuong extends StatelessWidget {
  const _NutChuong({required this.coChuaDoc, required this.onTap});

  final bool coChuaDoc;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Tooltip(
    message: 'Thông báo',
    child: Stack(
      clipBehavior: Clip.none,
      children: [
        Material(
          color: Colors.transparent,
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onTap,
            child: const SizedBox(
              width: 36,
              height: 36,
              child: Icon(Icons.notifications_none, size: 22, color: HD.inkSoft),
            ),
          ),
        ),
        if (coChuaDoc)
          Positioned(
            top: 6,
            right: 7,
            child: Container(
              key: const ValueKey('cham-thong-bao'),
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: HD.accent,
                shape: BoxShape.circle,
                border: Border.all(color: HD.paperRaised, width: 2),
              ),
            ),
          ),
      ],
    ),
  );
}

class _AnhDaiDien extends StatelessWidget {
  const _AnhDaiDien();

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().currentUser;
    final url = user?.avatarPath ?? '';
    final anh = Container(
      width: 32,
      height: 32,
      decoration: const BoxDecoration(
        color: HD.paperSunken,
        shape: BoxShape.circle,
      ),
      clipBehavior: Clip.antiAlias,
      child: url.isEmpty
          ? const Icon(Icons.person, size: 18, color: HD.inkMuted)
          : CachedNetworkImage(
              imageUrl: anhTuyetDoi(url),
              fit: BoxFit.cover,
              errorWidget: (_, _, _) =>
                  const Icon(Icons.person, size: 18, color: HD.inkMuted),
            ),
    );
    final uid = user?.id;
    if (uid == null) return anh;
    return PopupMenuButton<String>(
      tooltip: 'Tài khoản',
      position: PopupMenuPosition.under,
      onSelected: (_) => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => BrokerProfileScreen(
            userId: uid,
            name: user?.name,
            avatarPath: user?.avatarPath,
            laChuTrang: true,
          ),
        ),
      ),
      itemBuilder: (_) => const [
        PopupMenuItem(
          value: 'trang_ca_nhan',
          child: ListTile(
            leading: Icon(Icons.person_outline),
            title: Text('Trang cá nhân của tôi'),
          ),
        ),
      ],
      child: anh,
    );
  }
}

class _TheToa extends StatelessWidget {
  const _TheToa({
    required this.ten,
    required this.diaChi,
    required this.anh,
    required this.cacToa,
    required this.toaId,
    required this.onDoiToa,
    required this.menu,
  });

  final String ten;
  final String diaChi;
  final String? anh;
  final List<BuildingModel> cacToa;
  final int toaId;
  final ValueChanged<BuildingModel> onDoiToa;
  final List<(IconData, String, VoidCallback)> menu;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: HD.paperRaised,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: HD.hairline.withValues(alpha: 0.5)),
      boxShadow: HD.sunkenShadow,
    ),
    child: Padding(
      padding: const EdgeInsets.all(HD.s12),
      child: Row(
        children: [
          _anh(),
          const SizedBox(width: HD.s12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                PopupMenuButton<VoidCallback>(
                  key: const ValueKey('menu-toa'),
                  tooltip: 'Tùy chọn tòa nhà',
                  position: PopupMenuPosition.under,
                  onSelected: (lam) => lam(),
                  itemBuilder: (_) => [
                    for (final (icon, nhan, lam) in menu)
                      PopupMenuItem(
                        value: lam,
                        child: ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(icon, size: 20),
                          title: Text(nhan),
                        ),
                      ),
                  ],
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: Text(
                          ten,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: HD.bodyBold(size: 15),
                        ),
                      ),
                      const SizedBox(width: 2),
                      const Icon(
                        Icons.keyboard_arrow_down,
                        size: 18,
                        color: HD.inkSoft,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  diaChi,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: HD.body(size: 11.5, color: HD.inkMuted),
                ),
              ],
            ),
          ),
          // Một toà thì không có gì để đổi — không vẽ nút rỗng.
          if (cacToa.length > 1) ...[
            const SizedBox(width: HD.s8),
            PopupMenuButton<int>(
              key: const ValueKey('doi-toa'),
              tooltip: 'Đổi tòa nhà',
              position: PopupMenuPosition.under,
              onSelected: (id) {
                for (final b in cacToa) {
                  if (b.id == id) onDoiToa(b);
                }
              },
              itemBuilder: (_) => [
                for (final b in cacToa)
                  CheckedPopupMenuItem(
                    value: b.id,
                    checked: b.id == toaId,
                    child: Text(
                      b.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: HD.accentTint,
                  borderRadius: BorderRadius.circular(HD.r8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.apartment, size: 13, color: HD.accent),
                    const SizedBox(width: 6),
                    Text(
                      'Đổi tòa nhà',
                      style: HD.bodyBold(size: 12, color: HD.accent),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    ),
  );

  Widget _anh() {
    const thay = ColoredBox(
      color: HD.accentTint,
      child: Icon(Icons.apartment, color: HD.accent, size: 24),
    );
    final url = anh ?? '';
    return ClipRRect(
      borderRadius: BorderRadius.circular(HD.r12),
      child: SizedBox(
        width: 48,
        height: 48,
        child: url.isEmpty
            ? thay
            : CachedNetworkImage(
                imageUrl: anhTuyetDoi(url),
                fit: BoxFit.cover,
                errorWidget: (_, _, _) => thay,
              ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    super.key,
    required this.nhan,
    required this.icon,
    required this.chon,
    required this.onTap,
  });

  final String nhan;
  final IconData icon;
  final bool chon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final mau = chon ? HD.paperRaised : HD.inkSoft;
    return Material(
      color: chon ? HD.accent : HD.paperSunken.withValues(alpha: 0.6),
      borderRadius: BorderRadius.circular(HD.r12),
      child: InkWell(
        borderRadius: BorderRadius.circular(HD.r12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 14, color: mau),
              const SizedBox(width: 6),
              Text(nhan, style: HD.bodyBold(size: 12, color: mau)),
            ],
          ),
        ),
      ),
    );
  }
}

class _BonThe extends StatelessWidget {
  const _BonThe({required this.phong});

  /// Phòng SAU chip loại hình — chip nằm ngay trên bốn thẻ, bấm "Ngắn hạn" mà
  /// số không đổi là thẻ nói sai.
  final List<RoomModel> phong;

  @override
  Widget build(BuildContext context) {
    final tong = phong.length;
    final thue = phong.where((r) => r.dangThue).length;
    final trong = phong.where((r) => r.tinhTrangHien == 'trong').length;
    final baoTri = phong.where((r) => r.tinhTrangHien == 'bao_tri').length;
    final vang = mauTinhTrang('bao_tri').$2;
    final List<(Key, IconData, Color, int, String, String?, Color)> the = [
      (const ValueKey('the-tong'), Icons.king_bed_outlined, HD.accent, tong, 'Tổng phòng', null, HD.inkMuted),
      (const ValueKey('the-thue'), Icons.group_outlined, HD.positive, thue, 'Đang thuê', _phanTram(thue, tong), HD.positive),
      (const ValueKey('the-trong'), Icons.bed_outlined, HD.inkMuted, trong, 'Phòng trống', _phanTram(trong, tong), HD.inkMuted),
      (const ValueKey('the-bao-tri'), Icons.build_outlined, vang, baoTri, 'Bảo trì', _phanTram(baoTri, tong), vang),
    ];
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < the.length; i++) ...[
            if (i > 0) const SizedBox(width: HD.s8),
            Expanded(
              child: _TheSo(
                key: the[i].$1,
                icon: the[i].$2,
                mau: the[i].$3,
                so: the[i].$4,
                nhan: the[i].$5,
                phu: the[i].$6,
                mauPhu: the[i].$7,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _TheSo extends StatelessWidget {
  const _TheSo({
    super.key,
    required this.icon,
    required this.mau,
    required this.so,
    required this.nhan,
    required this.phu,
    required this.mauPhu,
  });

  final IconData icon;
  final Color mau;
  final int so;
  final String nhan;
  final String? phu;
  final Color mauPhu;

  @override
  Widget build(BuildContext context) => Container(
    constraints: const BoxConstraints(minHeight: 105),
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(
      color: HD.paper.withValues(alpha: 0.55),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: HD.hairline.withValues(alpha: 0.4)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: mau.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(HD.r8),
          ),
          child: Icon(icon, size: 14, color: mau),
        ),
        const SizedBox(height: HD.s8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text('$so', style: HD.bodyBold(size: 18)),
            ),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                nhan,
                maxLines: 1,
                style: HD.body(size: 11, color: HD.inkMuted),
              ),
            ),
            if (phu != null)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  phu!,
                  maxLines: 1,
                  style: HD.bodyBold(size: 10, color: mauPhu),
                ),
              ),
          ],
        ),
      ],
    ),
  );
}

class _NutVien extends StatelessWidget {
  const _NutVien({required this.icon, required this.nhan, required this.bat});

  final IconData icon;
  final String nhan;

  /// Đang có lọc / sắp xếp khác mặc định → tô đỏ, để người dùng biết vì sao
  /// danh sách vắng hơn thường.
  final bool bat;

  @override
  Widget build(BuildContext context) {
    final mau = bat ? HD.accent : HD.ink;
    return Container(
      height: 38,
      padding: const EdgeInsets.symmetric(horizontal: HD.s12),
      decoration: BoxDecoration(
        color: bat ? HD.accentTint : HD.paperRaised,
        borderRadius: BorderRadius.circular(HD.r12),
        border: Border.all(
          color: bat
              ? HD.accent.withValues(alpha: 0.5)
              : HD.hairline.withValues(alpha: 0.8),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: bat ? HD.accent : HD.inkSoft),
          const SizedBox(width: 6),
          Text(
            nhan,
            style: HD.body(size: 12, color: mau).copyWith(fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }
}

class _NutCheDo extends StatelessWidget {
  const _NutCheDo({
    super.key,
    required this.icon,
    required this.nhan,
    required this.chon,
    required this.onTap,
  });

  final IconData icon;
  final String nhan;
  final bool chon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final mau = chon ? HD.accent : HD.inkMuted;
    return Material(
      color: chon ? HD.paperRaised : Colors.transparent,
      borderRadius: BorderRadius.circular(6),
      elevation: chon ? 0.5 : 0,
      child: InkWell(
        borderRadius: BorderRadius.circular(6),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 12, color: mau),
              const SizedBox(width: 4),
              Text(
                nhan,
                style: HD.body(size: 11, color: mau).copyWith(fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Rong extends StatelessWidget {
  const _Rong({
    super.key,
    required this.chu,
    required this.nut,
    required this.onNut,
  });

  final String chu;
  final String nut;
  final VoidCallback onNut;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: HD.s20, vertical: HD.s32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            chu,
            textAlign: TextAlign.center,
            style: HD.body(size: 13, color: HD.inkMuted),
          ),
          const SizedBox(height: HD.s12),
          OutlinedButton(onPressed: onNut, child: Text(nut)),
        ],
      ),
    ),
  );
}
