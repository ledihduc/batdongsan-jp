import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:house_booking/core/widgets/ds.dart';
import 'package:house_booking/data/services/lich_phong_api.dart';
import 'package:house_booking/features/host/property/providers/building_provider.dart';

/// LỊCH PHÒNG TRỐNG — chủ nhà nhìn phòng nào bận đến bao giờ.
///
/// Vì sao màn này tồn tại: trước đây phòng chỉ có một cờ `vacant | occupied`.
/// Cờ đó trả lời được "hôm nay có ai ở không" và **không** trả lời được câu chủ
/// nhà thật sự bị hỏi khi nhấc máy — "trống từ ngày nào?". Nên họ phải mở hợp
/// đồng ra dò tay, hoặc trả lời bừa rồi hẹn lại.
///
/// Nguồn: `GET /api/host/buildings/{id}/lich-phong` (bảng `room_chiem_dung`,
/// gộp hợp đồng dài hạn + đơn đặt đêm + khoảng tự chặn vào MỘT dòng thời gian).
class LichPhongScreen extends StatefulWidget {
  const LichPhongScreen({super.key, this.api, this.buildingId});

  /// Chỉ để test bơm API giả.
  final LichPhongApi? api;

  /// Mở thẳng lịch của MỘT dự án (từ màn dự án). Bỏ trống thì tự lấy danh sách
  /// dự án của người dùng và cho chọn.
  final int? buildingId;

  @override
  State<LichPhongScreen> createState() => _LichPhongScreenState();
}

class _LichPhongScreenState extends State<LichPhongScreen> {
  LichPhongApi get _api => widget.api ?? const LichPhongApi();

  int? _toaId;
  List<PhongCoLich> _phong = const [];
  bool _dangTai = true;
  String? _loi;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _khoiDong());
  }

  Future<void> _khoiDong() async {
    if (widget.buildingId != null) {
      setState(() => _toaId = widget.buildingId);
      await _nap();
      return;
    }
    final bp = Provider.of<BuildingProvider>(context, listen: false);
    if (bp.buildings.isEmpty) await bp.fetchBuildings();
    if (!mounted) return;
    final ds = bp.buildings;
    if (ds.isEmpty) {
      setState(() => _dangTai = false);
      return;
    }
    setState(() => _toaId = ds.first.id);
    await _nap();
  }

  Future<void> _nap() async {
    final id = _toaId;
    if (id == null) return;
    setState(() {
      _dangTai = true;
      _loi = null;
    });
    try {
      final ds = await _api.cuaToa(id);
      if (mounted) setState(() => _phong = ds);
    } catch (_) {
      // Nói rõ HỎNG, không hiện danh sách rỗng: rỗng nghĩa là "mọi phòng đều
      // trống" — một câu trả lời sai mà chủ nhà sẽ tin và đem đi hứa với khách.
      if (mounted) setState(() => _loi = 'Không tải được lịch phòng.');
    } finally {
      if (mounted) setState(() => _dangTai = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Chỉ chạm provider khi thật sự cần chọn dự án — mở từ màn dự án thì đã
    // biết mở cái nào rồi.
    final toa = widget.buildingId != null
        ? const <dynamic>[]
        : Provider.of<BuildingProvider>(context).buildings;
    return Scaffold(
      backgroundColor: HD.paper,
      appBar: const DsAppBar(
        eyebrow: 'Quản lý',
        title: 'Lịch phòng trống',
      ),
      body: RefreshIndicator(
        onRefresh: _nap,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(HD.s16, HD.s12, HD.s16, HD.s24),
          children: [
            if (toa.length > 1) _chonToa(toa),
            if (_dangTai)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 48),
                child: Center(
                  child: CircularProgressIndicator(color: HD.accent),
                ),
              )
            else if (_loi != null)
              _thongBao(Icons.cloud_off_outlined, _loi!, 'Thử lại', _nap)
            else if (toa.isEmpty && widget.buildingId == null)
              _thongBao(
                Icons.apartment_outlined,
                'Bạn chưa quản lý dự án nào.',
                null,
                null,
              )
            else if (_phong.isEmpty)
              _thongBao(
                Icons.meeting_room_outlined,
                'Dự án này chưa có phòng nào.',
                null,
                null,
              )
            else ...[
              _tomTat(),
              const SizedBox(height: HD.s12),
              ..._phong.map(_hangPhong),
            ],
          ],
        ),
      ),
    );
  }

  Widget _chonToa(List<dynamic> toa) => Padding(
    padding: const EdgeInsets.only(bottom: HD.s12),
    child: DropdownButtonFormField<int>(
      initialValue: _toaId,
      decoration: const InputDecoration(
        labelText: 'Dự án',
        border: OutlineInputBorder(),
        isDense: true,
      ),
      items: [
        for (final b in toa)
          DropdownMenuItem<int>(value: b.id as int, child: Text('${b.name}')),
      ],
      onChanged: (v) {
        if (v == null) return;
        setState(() => _toaId = v);
        _nap();
      },
    ),
  );

  Widget _tomTat() {
    final trong = _phong.where((p) => p.trongCaKy).length;
    return Container(
      padding: const EdgeInsets.all(HD.s12),
      decoration: BoxDecoration(
        color: HD.accentTint,
        borderRadius: BorderRadius.circular(HD.r12),
      ),
      child: Row(
        children: [
          const Icon(Icons.event_available_outlined, color: HD.accent),
          const SizedBox(width: HD.s12),
          Expanded(
            child: Text(
              '$trong/${_phong.length} phòng trống suốt 90 ngày tới',
              style: HD.bodyBold(size: 14),
            ),
          ),
        ],
      ),
    );
  }

  Widget _hangPhong(PhongCoLich p) {
    final ngayTrong = p.trongTuNgay;
    return Padding(
      padding: const EdgeInsets.only(bottom: HD.s8),
      child: Material(
        color: HD.paperRaised,
        borderRadius: BorderRadius.circular(HD.r12),
        child: InkWell(
          onTap: () => _moChiTiet(p),
          borderRadius: BorderRadius.circular(HD.r12),
          child: Container(
            padding: const EdgeInsets.all(HD.s12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(HD.r12),
              border: Border.all(color: HD.hairline),
            ),
            child: Row(
              children: [
                Container(
                  width: 10,
                  height: 40,
                  decoration: BoxDecoration(
                    color: p.trongCaKy ? HD.positive : HD.warning,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(width: HD.s12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(p.ma, style: HD.bodyBold(size: 15)),
                      const SizedBox(height: 2),
                      Text(
                        p.trongCaKy
                            ? 'Trống'
                            : 'Bận đến ${_ngay(ngayTrong!)} · '
                                  '${p.khoang.length} khoảng',
                        style: HD.body(size: 12.5, color: HD.inkSoft),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, color: HD.inkMuted),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _thongBao(
    IconData icon,
    String chu,
    String? nhanNut,
    VoidCallback? onTap,
  ) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 40),
    child: Column(
      children: [
        Icon(icon, size: 40, color: HD.inkMuted),
        const SizedBox(height: HD.s12),
        Text(chu, style: HD.body(color: HD.inkSoft), textAlign: TextAlign.center),
        if (nhanNut != null && onTap != null) ...[
          const SizedBox(height: HD.s12),
          TextButton(onPressed: onTap, child: Text(nhanNut)),
        ],
      ],
    ),
  );

  Future<void> _moChiTiet(PhongCoLich p) async {
    final doi = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _SheetPhong(phong: p, api: _api),
    );
    if (doi == true) await _nap();
  }

  static String _ngay(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}';
}

/// Chi tiết một phòng: các khoảng đang bận + nút tự chặn.
class _SheetPhong extends StatefulWidget {
  const _SheetPhong({required this.phong, required this.api});

  final PhongCoLich phong;
  final LichPhongApi api;

  @override
  State<_SheetPhong> createState() => _SheetPhongState();
}

class _SheetPhongState extends State<_SheetPhong> {
  bool _dangGui = false;
  String? _loi;

  @override
  Widget build(BuildContext context) {
    final p = widget.phong;
    return Material(
      color: HD.paper,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(HD.r12)),
      clipBehavior: Clip.antiAlias,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(HD.s16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Phòng ${p.ma}', style: HD.bodyBold(size: 17)),
              const SizedBox(height: HD.s12),
              if (p.khoang.isEmpty)
                Text(
                  'Trống suốt khoảng đang xem.',
                  style: HD.body(color: HD.inkSoft),
                )
              else
                ...p.khoang.map(_dongKhoang),
              if (_loi != null) ...[
                const SizedBox(height: HD.s8),
                Text(_loi!, style: HD.body(size: 12.5, color: HD.negative)),
              ],
              const SizedBox(height: HD.s12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _dangGui ? null : _chan,
                  icon: const Icon(Icons.block_outlined, size: 18),
                  label: const Text('Tự chặn một khoảng'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _dongKhoang(KhoangBan k) => Padding(
    padding: const EdgeInsets.only(bottom: HD.s8),
    child: Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${_ngay(k.tuNgay)} → ${_ngay(k.denNgay)} · ${k.soNgay} ngày',
                style: HD.bodyBold(size: 13.5),
              ),
              Text(k.nhanNguon, style: HD.body(size: 12, color: HD.inkSoft)),
            ],
          ),
        ),
        // Khoảng do hợp đồng/đơn đặt sinh ra KHÔNG xoá được ở đây — xoá thẳng
        // là lịch nói một đằng, sổ sách một nẻo.
        if (k.goDuoc)
          IconButton(
            tooltip: 'Bỏ chặn',
            onPressed: _dangGui ? null : () => _boChan(k),
            icon: const Icon(Icons.delete_outline, color: HD.inkMuted),
          ),
      ],
    ),
  );

  Future<void> _boChan(KhoangBan k) async {
    setState(() {
      _dangGui = true;
      _loi = null;
    });
    try {
      await widget.api.boChan(k.id);
      if (mounted) Navigator.pop(context, true);
    } catch (_) {
      if (mounted) setState(() => _loi = 'Không bỏ chặn được. Thử lại.');
    } finally {
      if (mounted) setState(() => _dangGui = false);
    }
  }

  Future<void> _chan() async {
    final khoang = await showDateRangePicker(
      context: context,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 730)),
      helpText: 'Chặn phòng từ ngày → đến ngày trả',
    );
    if (khoang == null || !mounted) return;
    setState(() {
      _dangGui = true;
      _loi = null;
    });
    try {
      await widget.api.chan(
        widget.phong.roomId,
        tuNgay: khoang.start,
        // Người chọn "đến ngày X" hiểu là ngày cuối CÒN chặn; backend tính
        // `den_ngay` là ngày TRẢ (không tính). Lệch một ngày ở đây là phòng
        // mở bán đúng hôm còn đang sửa.
        denNgay: khoang.end.add(const Duration(days: 1)),
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() => _loi = 'Khoảng này đã có lịch khác. Chọn khoảng trống.');
      }
    } finally {
      if (mounted) setState(() => _dangGui = false);
    }
  }

  static String _ngay(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
}
