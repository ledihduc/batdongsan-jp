import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:house_booking/data/models/room_model.dart';
import 'package:house_booking/features/host/dashboard/host_dashboard_tokens.dart';
import 'package:house_booking/features/host/billing/providers/meter_reading_provider.dart';
import 'package:house_booking/features/host/billing/screens/meter_reading_screen.dart';
import 'package:house_booking/features/host/property/providers/room_provider.dart';
import 'package:house_booking/features/host/property/screens/room_form_screen.dart';
import 'package:house_booking/features/host/property/providers/contract_provider.dart';
import 'package:house_booking/features/host/property/widgets/maintenance_date_picker.dart';
import 'package:house_booking/features/host/property/screens/contract_form_screen.dart';
import 'package:house_booking/l10n/app_localizations.dart';
import 'package:house_booking/data/services/kenh_khai_thac_api.dart';
import 'package:house_booking/data/services/ho_so_phong_api.dart';
import 'package:house_booking/features/host/ngan_han/ho_so_phong_ngan_han_screen.dart';
import 'package:house_booking/features/host/property/screens/ho_so_phong_screen.dart';

import 'room_detail_editorial_widgets.dart';


/// Room detail — editorial dossier on a single room. Status stamp,
/// fact-sheet rows, contract history as classified listings.
class RoomDetailScreen extends StatefulWidget {
  final int roomId;

  /// API hồ sơ phòng — chỉ để test bơm bản giả.
  final HoSoPhongApi hoSoApi;

  const RoomDetailScreen({
    super.key,
    required this.roomId,
    this.hoSoApi = const HoSoPhongApi(),
  });

  @override
  State<RoomDetailScreen> createState() => _RoomDetailScreenState();
}

class _RoomDetailScreenState extends State<RoomDetailScreen> {
  late final ContractProvider _contractProvider;

  @override
  void initState() {
    super.initState();
    _contractProvider = ContractProvider();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _contractProvider.fetchContracts(roomId: widget.roomId);
    });
  }

  @override
  void dispose() {
    _contractProvider.dispose();
    super.dispose();
  }

  RoomModel? _findRoom(RoomProvider p) {
    try {
      return p.rooms.firstWhere((r) => r.id == widget.roomId);
    } catch (_) {
      return null;
    }
  }

  /// Sửa phòng. Tới trước hôm nay chủ nhà KHÔNG sửa được gì sau khi tạo —
  /// `ApiRoomRepository.updateRoom` có sẵn nhưng provider thiếu hàm và không
  /// màn nào gọi. Sai mã phòng, sai giá điện, thiếu một món đồ, đều phải sống
  /// chung với nó.
  Future<void> _moSua(RoomProvider p, RoomModel room) async {
    final ok = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => ChangeNotifierProvider.value(
          value: p,
          child: RoomFormScreen(buildingId: room.buildingId, phong: room),
        ),
      ),
    );
    if (ok == true && mounted) p.fetchRooms(room.buildingId);
  }

  /// Xoá phòng khỏi sổ. Hỏi lại bằng CHÍNH MÃ PHÒNG trong câu hỏi — "Bạn có
  /// chắc không?" thì ai cũng bấm Đồng ý.
  Future<void> _xoa(RoomProvider p, RoomModel room) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Xoá phòng ${room.code}?'),
        content: Text(
          'Phòng và các kênh đang rao của nó sẽ mất hẳn. Không khôi phục được.',
          style: HD.body(size: 13, color: HD.inkSoft),
        ),
        actions: [
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
    final loi = await p.deleteRoom(room.id);
    if (!mounted) return;
    if (loi == null) {
      // Phòng không còn thì màn chi tiết của nó cũng không còn nghĩa gì.
      Navigator.pop(context, true);
    } else {
      // Hiện NGUYÊN VĂN câu server trả về: "Phòng đã có hợp đồng, không xoá
      // được." nói rõ phải làm gì hơn bất cứ câu chung chung nào.
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(loi)));
    }
  }

  /// Nhập chỉ số điện nước CỦA ĐÚNG PHÒNG NÀY.
  ///
  /// `MeterReadingScreen` vốn đã nhận `roomId`, nhưng **không nơi nào truyền**
  /// — lối vào duy nhất là nút chung ở trang chủ nhà, và ở đó nó từ chối tạo
  /// vì không biết phòng nào. Tức là nhập chỉ số theo phòng là UI chết. Đây là
  /// lối vào còn thiếu.
  Future<void> _moChiSo(RoomModel room) async {
    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChangeNotifierProvider(
          create: (_) => MeterReadingProvider(),
          child: MeterReadingScreen(roomId: room.id, roomCode: room.code),
        ),
      ),
    );
  }

  Future<void> _showMaintenanceDialog(RoomProvider p) async {
    final l = AppLocalizations.of(context);
    String? start;
    String? end;

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => EditorialDialog(
        eyebrow: l.hRoomDetMaintEyebrow,
        title: l.hRoomDetMaintTitle,
        body: MaintenanceDatePicker(
          onChanged: (dates) {
            start = dates.$1;
            end = dates.$2;
          },
        ),
        confirmLabel: l.hRoomDetConfirm,
      ),
    );

    if (ok != true || start == null) return;
    if (!mounted) return;

    final result = await p.setMaintenance(
      widget.roomId,
      maintenanceStart: start!,
      maintenanceEnd: end,
    );

    if (!mounted) return;
    _toast(result != null
        ? l.hRoomDetMaintSetFrom(start!)
        : (p.error ?? l.hRoomDetFailed));
  }

  Future<void> _endMaintenance(RoomProvider p) async {
    final l = AppLocalizations.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => EditorialDialog(
        eyebrow: l.hRoomDetEndMaintEyebrow,
        title: l.hRoomDetEndMaintTitle,
        body: Text(
          l.hRoomDetEndMaintBody,
          style: HD.body(size: 13, color: HD.inkMuted),
        ),
        confirmLabel: l.hRoomDetEnd,
      ),
    );
    if (ok != true || !mounted) return;
    final result = await p.endMaintenance(widget.roomId);
    if (!mounted) return;
    _toast(result != null ? l.hRoomDetMaintEnded : l.hRoomDetFailed);
  }

  Future<void> _duplicate(RoomProvider p, RoomModel room) async {
    final l = AppLocalizations.of(context);
    final result = await p.duplicateRoom(room.id);
    if (!mounted) return;
    _toast(result != null ? l.hRoomDetDuplicated(result.code) : l.hRoomDetFailed);
  }

  Future<void> _openCreateContract(RoomModel room) async {
    double? monthlyRent;
    try {
      final channels = await const KenhKhaiThacApi().cuaPhong(room.id);
      for (final channel in channels) {
        if (channel.kenh == 'dai_han' && channel.gia > 0) {
          monthlyRent = channel.gia;
          break;
        }
        if (channel.kenh == 'mat_bang' && channel.gia > 0) {
          monthlyRent = channel.donVi == 'm2_thang' && room.areaM2 != null
              ? channel.gia * room.areaM2!
              : channel.gia;
        }
      }
    } catch (_) {
      // Không chặn việc tạo hợp đồng nếu kênh chưa có hoặc tải giá thất bại.
    }
    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: _contractProvider),
          ],
          child: ContractFormScreen(
            roomId: room.id,
            initialMonthlyRent: monthlyRent,
          ),
        ),
      ),
    );
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: HD.ink,
        content: Text(message, style: HD.body(color: HD.paperRaised, size: 13)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return ChangeNotifierProvider.value(
      value: _contractProvider,
      child: Consumer<RoomProvider>(
        builder: (_, roomProvider, _) {
          final room = _findRoom(roomProvider);
          if (room == null) {
            return Scaffold(
              backgroundColor: HD.paper,
              appBar: _editorialAppBar(context, 'Phòng'),
              body: Center(
                child: Text(l.hRoomDetNotFound,
                    style: HD.body(color: HD.inkMuted)),
              ),
            );
          }

          // Phòng thuê tháng (dài hạn / mặt bằng) mở HỒ SƠ PHÒNG theo mockup
          // 11/09. Ngắn hạn chưa có thiết kế riêng — giữ màn cũ bên dưới.
          if (laPhongThueThang(room)) {
            return HoSoPhongScreen(
              room: room,
              contractProvider: _contractProvider,
              api: widget.hoSoApi,
              onSua: () => _moSua(roomProvider, room),
              onXoa: () => _xoa(roomProvider, room),
              onNhanBan: () => _duplicate(roomProvider, room),
              onBaoTri: () => _showMaintenanceDialog(roomProvider),
              onKetThucBaoTri: () => _endMaintenance(roomProvider),
              onChiSo: () => _moChiSo(room),
              onTaoHopDong: () => _openCreateContract(room),
            );
          }

          // Phòng THUẦN ngắn hạn có màn riêng (mockup "P201", 12/09): câu hỏi
          // của nó là "ai đang trong phòng, còn mấy phút, ca sau là ai", không
          // phải hợp đồng và hoá đơn tháng.
          return HoSoPhongNganHanScreen(
            roomId: room.id,
            onSua: () => _moSua(roomProvider, room),
            onXoa: () => _xoa(roomProvider, room),
            onNhanBan: () => _duplicate(roomProvider, room),
            onBaoTri: room.isMaintenance
                ? null
                : () => _showMaintenanceDialog(roomProvider),
            onKetThucBaoTri:
                room.isMaintenance ? () => _endMaintenance(roomProvider) : null,
            onChiSo: () => _moChiSo(room),
          );
        },
      ),
    );
  }
}

/// Phòng này mở Hồ sơ phòng (thuê tháng) hay màn chi tiết cũ (ngắn hạn)?
///
/// Chỉ phòng đang chạy THUẦN ngắn hạn giữ màn cũ. Phòng chưa bật kênh nào cũng
/// vào hồ sơ: phòng mới khai mặc định là thuê tháng, và hồ sơ là nơi tạo hợp
/// đồng đầu tiên cho nó.
bool laPhongThueThang(RoomModel r) =>
    !(r.loai.contains('ngan_han') &&
        !r.loai.contains('dai_han') &&
        !r.loai.contains('kinh_doanh'));

PreferredSizeWidget _editorialAppBar(BuildContext context, String _,
    {Widget? trailing}) {
  final l = AppLocalizations.of(context);
  return AppBar(
    backgroundColor: HD.paper,
    surfaceTintColor: HD.paper,
    elevation: 0,
    scrolledUnderElevation: 0,
    foregroundColor: HD.ink,
    iconTheme: const IconThemeData(color: HD.ink, size: 20),
    shape: const Border(bottom: BorderSide(color: HD.hairline)),
    titleSpacing: 0,
    title: Text(
      l.hRoomDetHeader,
      style: HD.eyebrow(color: HD.ink).copyWith(letterSpacing: 1.6),
    ),
    actions: [?trailing, const SizedBox(width: HD.s8)],
  );
}

