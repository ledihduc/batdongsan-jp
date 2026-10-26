import 'package:flutter/material.dart';

import 'package:house_booking/core/theme/design_tokens.dart';
import 'package:house_booking/core/utils/formatters.dart';
import 'package:house_booking/data/services/api_client.dart';
import 'package:house_booking/data/services/ca_thue_api.dart';
import 'package:house_booking/data/services/lich_gio_api.dart';
import 'package:house_booking/features/host/ngan_han/ca_thue/chi_tiet_ca_thue_screen.dart';
import 'package:house_booking/features/host/ngan_han/lich_tuan_screen.dart';
import 'package:house_booking/features/host/ngan_han/so_do_gio.dart';

/// SƠ ĐỒ GIỜ CỦA MỘT PHÒNG — 4 tuần liền (12/09/2026).
///
///     hàng = NGÀY · cột = GIỜ (00:00 → 24:00) · khối = ca thuê / khoá dọn
///
/// Vì sao không dùng lịch phòng × ngày cho việc này: lưu trú theo giờ bán được
/// ba bốn ca một ngày, nên ô "ngày" chỉ có hai màu bận/trống là nói dối —
/// phòng có ca 15:00–19:00 trông như đã kín trong khi cả buổi sáng vẫn trống.
/// Trải ra trục giờ thì khe trống hiện nguyên hình.
///
/// Ca qua đêm bị cắt làm hai khúc ở hai hàng, có mũi nhọn ở mép để biết là nó
/// còn kéo dài — chứ không vẽ tràn ra ngoài lưới.
class LichGioScreen extends StatefulWidget {
  const LichGioScreen({
    super.key,
    required this.roomId,
    this.api = const LichGioApi(),
    this.caThueApi = const CaThueApi(),
    this.tuNgayBanDau,
    this.soTuan = 4,
  });

  final int roomId;
  final LichGioApi api;
  final CaThueApi caThueApi;

  /// 'YYYY-MM-DD' — chỉ để test ghim mốc; bình thường là tuần chứa hôm nay.
  final String? tuNgayBanDau;
  final int soTuan;

  @override
  State<LichGioScreen> createState() => _LichGioScreenState();
}

class _LichGioScreenState extends State<LichGioScreen> {
  LichGio? _lich;
  int? _roomId;
  String? _tuNgay;
  bool _dangTai = false;
  String? _loi;

  @override
  void initState() {
    super.initState();
    _roomId = widget.roomId;
    _tuNgay = widget.tuNgayBanDau;
    WidgetsBinding.instance.addPostFrameCallback((_) => _nap());
  }

  Future<void> _nap() async {
    setState(() {
      _dangTai = true;
      _loi = null;
    });
    try {
      final l = await widget.api.lay(
        _roomId ?? widget.roomId,
        tuNgay: _tuNgay,
        soTuan: widget.soTuan,
      );
      if (!mounted) return;
      setState(() {
        _lich = l;
        _tuNgay = _iso(l.tuNgay);
        _roomId = l.phongId;
      });
    } catch (e) {
      if (mounted) {
        setState(
          () => _loi = e is ApiException ? e.message : 'Không tải được lịch giờ',
        );
      }
    } finally {
      if (mounted) setState(() => _dangTai = false);
    }
  }

  void _doiKy(int huong) {
    final l = _lich;
    if (l == null) return;
    setState(
      () => _tuNgay = _iso(l.tuNgay.add(Duration(days: 7 * l.soTuan * huong))),
    );
    _nap();
  }

  void _doiPhong(int id) {
    setState(() => _roomId = id);
    _nap();
  }

  Future<void> _moCa(KhoiGio m) async {
    if (m.laChan) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ChiTietCaThueScreen(
          reservationId: m.id,
          api: widget.caThueApi,
        ),
      ),
    );
    if (mounted) await _nap();
  }

  @override
  Widget build(BuildContext context) {
    final l = _lich;
    return Scaffold(
      backgroundColor: HD.paper,
      body: SafeArea(
        child: Column(
          children: [
            _thanhTren(l),
            Expanded(
              child: l == null
                  ? Center(
                      child: _dangTai
                          ? const CircularProgressIndicator()
                          : Text(
                              _loi ?? 'Không có dữ liệu',
                              style: HD.body(color: HD.inkMuted),
                            ),
                    )
                  : RefreshIndicator(
                      onRefresh: _nap,
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(12, 10, 12, 24),
                        children: [
                          if (l.cacPhong.length > 1) _chonPhong(l),
                          _kpi(l),
                          const SizedBox(height: HD.s12),
                          _soDo(l),
                          const SizedBox(height: HD.s12),
                          _chuThich(),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _thanhTren(LichGio? l) => Container(
    color: Colors.white,
    padding: const EdgeInsets.fromLTRB(4, 4, 8, 6),
    child: Column(
      children: [
        Row(
          children: [
            IconButton(
              onPressed: () => Navigator.maybePop(context),
              icon: const Icon(Icons.arrow_back, size: 20),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l == null
                        ? 'Lịch giờ'
                        : 'Lịch giờ · Phòng ${l.phongMa}',
                    style: HD.bodyBold(size: 15.5),
                  ),
                  Text(
                    '${l?.soTuan ?? widget.soTuan} tuần liền · mỗi hàng một ngày',
                    style: HD.body(size: 11, color: HD.inkMuted),
                  ),
                ],
              ),
            ),
            IconButton(
              key: const Key('lich-gio-sang-so-do'),
              tooltip: 'Sơ đồ cả toà theo ngày',
              onPressed: l == null
                  ? null
                  : () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) =>
                            LichTuanScreen(buildingId: l.buildingId),
                      ),
                    ),
              icon: const Icon(Icons.grid_view, size: 19),
            ),
          ],
        ),
        Row(
          children: [
            IconButton(
              key: const Key('lich-gio-lui'),
              onPressed: _dangTai ? null : () => _doiKy(-1),
              icon: const Icon(Icons.chevron_left),
            ),
            Expanded(
              child: Center(
                child: Text(
                  l == null ? '' : '${_ngayNgan(l.tuNgay)} – ${_ngayNgan(l.denNgay)}',
                  key: const Key('lich-gio-khoang'),
                  style: HD.bodyBold(size: 13),
                ),
              ),
            ),
            IconButton(
              key: const Key('lich-gio-toi'),
              onPressed: _dangTai ? null : () => _doiKy(1),
              icon: const Icon(Icons.chevron_right),
            ),
          ],
        ),
      ],
    ),
  );

  Widget _chonPhong(LichGio l) => SizedBox(
    height: 36,
    child: ListView(
      scrollDirection: Axis.horizontal,
      children: [
        for (final p in l.cacPhong)
          Padding(
            padding: const EdgeInsets.only(right: 6),
            child: ChoiceChip(
              key: Key('lich-gio-phong-${p.id}'),
              selected: p.id == l.phongId,
              onSelected: (_) => _doiPhong(p.id),
              label: Text(p.ma, style: HD.body(size: 11.5)),
              selectedColor: HD.accentSoft,
              visualDensity: VisualDensity.compact,
            ),
          ),
      ],
    ),
  );

  Widget _kpi(LichGio l) => Padding(
    padding: const EdgeInsets.only(top: HD.s8),
    child: Row(
      children: [
        Expanded(
          child: _OKpiGio(
            so: '${l.kpi.luotDat}',
            nhan: 'Lượt đặt',
            phu: '${l.soTuan} tuần',
            mau: HD.accent,
          ),
        ),
        const SizedBox(width: HD.s8),
        Expanded(
          child: _OKpiGio(
            so: '${l.kpi.gioBan.toStringAsFixed(0)}h',
            nhan: 'Giờ bán',
            phu: '${l.kpi.soNgay} ngày',
            mau: HD.positive,
          ),
        ),
        const SizedBox(width: HD.s8),
        Expanded(
          child: _OKpiGio(
            so: '${l.kpi.congSuat.toStringAsFixed(0)}%',
            nhan: 'Lấp giờ',
            phu: 'cả kỳ',
            mau: HD.pinStayShort,
          ),
        ),
        if (l.xemTaiChinh) ...[
          const SizedBox(width: HD.s8),
          Expanded(
            child: _OKpiGio(
              so: PriceFormat.compact(l.kpi.doanhThu),
              nhan: 'Doanh thu',
              phu: 'các ca',
              mau: HD.svcIndigo,
            ),
          ),
        ],
      ],
    ),
  );

  Widget _soDo(LichGio l) => SoDoGio(
    ngay: l.ngay,
    bayGio: l.bayGio,
    onTap: _moCa,
  );

  Widget _chuThich() => const ChuThichSoDo();
}

class _OKpiGio extends StatelessWidget {
  const _OKpiGio({
    required this.so,
    required this.nhan,
    required this.phu,
    required this.mau,
  });

  final String so;
  final String nhan;
  final String phu;
  final Color mau;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 9),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: HD.hairline.withValues(alpha: 0.8)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(so, style: HD.bodyBold(size: 16, color: mau)),
        Text(nhan, style: HD.body(size: 10, color: HD.inkSoft)),
        Text(phu, style: HD.body(size: 9, color: HD.inkMuted)),
      ],
    ),
  );
}

String _hai(int n) => n.toString().padLeft(2, '0');

String _iso(DateTime d) => '${d.year}-${_hai(d.month)}-${_hai(d.day)}';

String _ngayNgan(DateTime d) => '${d.day}/${d.month}';

