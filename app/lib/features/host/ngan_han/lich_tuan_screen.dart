import 'package:flutter/material.dart';

import 'package:house_booking/core/theme/design_tokens.dart';
import 'package:house_booking/core/utils/formatters.dart';
import 'package:house_booking/data/services/api_client.dart';
import 'package:house_booking/data/services/ca_thue_api.dart';
import 'package:house_booking/data/services/lich_tuan_api.dart';
import 'package:house_booking/features/host/ngan_han/ca_thue/chi_tiet_ca_thue_screen.dart';
import 'package:house_booking/features/host/ngan_han/lich_ngan_han_screen.dart';

/// SƠ ĐỒ PHÒNG × NGÀY — bốn tuần liền (12/09/2026).
///
/// Lịch theo GIỜ trả lời "lúc này phòng nào trống"; sơ đồ này trả lời câu của
/// người bán phòng: **tháng tới còn khe nào, ngày nào ế**. Mỗi phòng một hàng,
/// mỗi ngày một cột, ca thuê là một thanh bắc qua đúng số ngày nó chiếm.
///
/// Cột đầu luôn là THỨ HAI nên bốn tuần thẳng hàng thứ — nhìn dọc xuống là
/// thấy ngay cuối tuần nào kín, cuối tuần nào trống.
///
/// Cột tên phòng GHIM cố định khi cuộn ngang: cuộn tới ngày 20 mà không biết
/// hàng nào là phòng nào thì cả sơ đồ vô dụng.
class LichTuanScreen extends StatefulWidget {
  const LichTuanScreen({
    super.key,
    required this.buildingId,
    this.api = const LichTuanApi(),
    this.caThueApi = const CaThueApi(),
    this.tuNgayBanDau,
    this.soTuan = 4,
  });

  final int buildingId;
  final LichTuanApi api;
  final CaThueApi caThueApi;

  /// 'YYYY-MM-DD' — chỉ để test ghim mốc; bình thường là tuần chứa hôm nay.
  final String? tuNgayBanDau;
  final int soTuan;

  @override
  State<LichTuanScreen> createState() => _LichTuanScreenState();
}

/// Bề rộng một cột ngày. 44 vừa đủ chỗ cho "T2" + số ngày ở cỡ chữ đọc được,
/// và 7 cột = 308 nên một tuần trọn vẹn luôn nằm trong màn hình điện thoại.
const double _rongNgay = 44;
const double _rongCotPhong = 104;
const double _caoHang = 54;

/// Bề rộng tối thiểu của một khối. Ca 4 tiếng chỉ chiếm 7px ở tỉ lệ ngày —
/// nhỏ hơn đầu ngón tay thì không bấm được.
const double _rongToiThieu = 22;
const double _caoDauNgay = 52;

class _LichTuanScreenState extends State<LichTuanScreen> {
  final _ngang = ScrollController();

  LichTuan? _lich;
  String? _tuNgay;
  bool _dangTai = false;
  String? _loi;

  @override
  void initState() {
    super.initState();
    _tuNgay = widget.tuNgayBanDau;
    WidgetsBinding.instance.addPostFrameCallback((_) => _nap());
  }

  @override
  void dispose() {
    _ngang.dispose();
    super.dispose();
  }

  Future<void> _nap() async {
    setState(() {
      _dangTai = true;
      _loi = null;
    });
    try {
      final l = await widget.api.lay(
        widget.buildingId,
        tuNgay: _tuNgay,
        soTuan: widget.soTuan,
      );
      if (!mounted) return;
      setState(() {
        _lich = l;
        _tuNgay = _iso(l.tuNgay);
      });
      _cuonToiHomNay(l);
    } catch (e) {
      if (mounted) {
        setState(
          () => _loi = e is ApiException ? e.message : 'Không tải được sơ đồ phòng',
        );
      }
    } finally {
      if (mounted) setState(() => _dangTai = false);
    }
  }

  /// Mở ra là thấy tuần hiện tại, không phải mùng 1 của bốn tuần trước.
  void _cuonToiHomNay(LichTuan l) {
    final i = l.ngay.indexWhere((n) => n.homNay);
    if (i < 0) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_ngang.hasClients) return;
      final x = (i - 1) * _rongNgay;
      _ngang.jumpTo(x.clamp(0, _ngang.position.maxScrollExtent));
    });
  }

  void _doiKy(int huong) {
    final l = _lich;
    if (l == null) return;
    setState(
      () => _tuNgay = _iso(l.tuNgay.add(Duration(days: 7 * l.soTuan * huong))),
    );
    _nap();
  }

  Future<void> _moCa(KhoiTuan m) async {
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
                        padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
                        children: [
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

  // ── Thanh trên ────────────────────────────────────────────────────────────

  Widget _thanhTren(LichTuan? l) => Container(
    color: Colors.white,
    padding: const EdgeInsets.fromLTRB(4, 4, 8, 8),
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
                    'Sơ đồ phòng ${l?.soTuan ?? widget.soTuan} tuần',
                    style: HD.bodyBold(size: 15.5),
                  ),
                  Text(
                    l == null
                        ? '...'
                        : '${l.toaTen} · ${l.phong.length} phòng',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: HD.body(size: 11.5, color: HD.inkMuted),
                  ),
                ],
              ),
            ),
            IconButton(
              key: const Key('lich-tuan-sang-ngay'),
              tooltip: 'Lịch theo giờ hôm nay',
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => LichNganHanScreen(buildingId: widget.buildingId),
                ),
              ),
              icon: const Icon(Icons.schedule, size: 20),
            ),
          ],
        ),
        Row(
          children: [
            IconButton(
              key: const Key('lich-tuan-lui'),
              onPressed: _dangTai ? null : () => _doiKy(-1),
              icon: const Icon(Icons.chevron_left),
            ),
            Expanded(
              child: Center(
                child: Text(
                  l == null
                      ? ''
                      : '${_ngayNgan(l.tuNgay)} – ${_ngayNgan(l.denNgay)}',
                  key: const Key('lich-tuan-khoang'),
                  style: HD.bodyBold(size: 13),
                ),
              ),
            ),
            IconButton(
              key: const Key('lich-tuan-toi'),
              onPressed: _dangTai ? null : () => _doiKy(1),
              icon: const Icon(Icons.chevron_right),
            ),
          ],
        ),
      ],
    ),
  );

  // ── KPI ───────────────────────────────────────────────────────────────────

  Widget _kpi(LichTuan l) => Row(
    children: [
      Expanded(
        child: _OKpi(
          so: '${l.kpi.luotDat}',
          nhan: 'Lượt đặt',
          phu: '${l.soTuan} tuần',
          mau: HD.accent,
        ),
      ),
      const SizedBox(width: HD.s8),
      Expanded(
        child: _OKpi(
          so: '${l.kpi.demBan}',
          nhan: 'Đêm bán',
          phu: '${l.kpi.soPhong} phòng',
          mau: HD.positive,
        ),
      ),
      const SizedBox(width: HD.s8),
      Expanded(
        child: _OKpi(
          so: '${l.kpi.congSuat.toStringAsFixed(0)}%',
          nhan: 'Công suất',
          phu: 'cả kỳ',
          mau: HD.pinStayShort,
        ),
      ),
      if (l.xemTaiChinh) ...[
        const SizedBox(width: HD.s8),
        Expanded(
          child: _OKpi(
            so: PriceFormat.compact(l.kpi.doanhThu),
            nhan: 'Doanh thu',
            phu: 'các ca',
            mau: HD.svcIndigo,
          ),
        ),
      ],
    ],
  );

  // ── Sơ đồ ─────────────────────────────────────────────────────────────────

  Widget _soDo(LichTuan l) {
    final rong = l.soNgay * _rongNgay;
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: HD.hairline.withValues(alpha: 0.8)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Cột tên phòng — GHIM, không cuộn theo.
          SizedBox(
            width: _rongCotPhong,
            child: Column(
              children: [
                Container(
                  height: _caoDauNgay,
                  alignment: Alignment.centerLeft,
                  padding: const EdgeInsets.only(left: 10),
                  decoration: const BoxDecoration(
                    border: Border(
                      bottom: BorderSide(color: HD.hairline, width: 0.6),
                    ),
                  ),
                  child: Text(
                    'Phòng',
                    style: HD.bodyBold(size: 11, color: HD.inkMuted),
                  ),
                ),
                for (final p in l.phong) _oTenPhong(p),
              ],
            ),
          ),
          Container(width: 0.6, height: _caoDauNgay + _caoHang * l.phong.length, color: HD.hairlineStrong),
          Expanded(
            child: SingleChildScrollView(
              controller: _ngang,
              scrollDirection: Axis.horizontal,
              child: SizedBox(
                width: rong,
                child: Column(
                  children: [
                    _dauNgay(l),
                    for (final p in l.phong) _hang(l, p),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _oTenPhong(HangPhongTuan p) => Container(
    height: _caoHang,
    padding: const EdgeInsets.symmetric(horizontal: 10),
    alignment: Alignment.centerLeft,
    decoration: const BoxDecoration(
      border: Border(bottom: BorderSide(color: HD.hairline, width: 0.4)),
    ),
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          p.ma,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: HD.bodyBold(size: 12),
        ),
        Text(
          p.hang ?? '${p.sucChua ?? 2} khách',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: HD.body(size: 9.5, color: HD.inkMuted),
        ),
      ],
    ),
  );

  Widget _dauNgay(LichTuan l) => Container(
    height: _caoDauNgay,
    decoration: const BoxDecoration(
      border: Border(bottom: BorderSide(color: HD.hairline, width: 0.6)),
    ),
    child: Row(
      children: [
        for (final n in l.ngay)
          Container(
            width: _rongNgay,
            decoration: BoxDecoration(
              color: n.homNay
                  ? HD.accentTint
                  : (n.cuoiTuan ? HD.paper.withValues(alpha: 0.7) : null),
              border: Border(
                left: BorderSide(
                  // Vạch đậm mở đầu mỗi tuần — bốn tuần đọc thành bốn khối.
                  color: n.thu == 1 ? HD.hairlineStrong : HD.hairline,
                  width: n.thu == 1 ? 1.2 : 0.4,
                ),
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  _thu(n.thu),
                  style: HD.body(
                    size: 9.5,
                    color: n.homNay ? HD.accent : HD.inkMuted,
                  ),
                ),
                Text(
                  '${n.ngay.day}',
                  style: HD.bodyBold(
                    size: 12.5,
                    color: n.homNay ? HD.accent : HD.ink,
                  ),
                ),
                const SizedBox(height: 2),
                // Thanh công suất ngày: nhìn dọc là ra ngày trũng.
                Container(
                  width: 22,
                  height: 3,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(9),
                    color: HD.paperSunken,
                  ),
                  child: FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: (n.congSuat / 100).clamp(0.0, 1.0),
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(9),
                        color: n.congSuat >= 80
                            ? HD.negative
                            : (n.congSuat > 0 ? HD.positive : Colors.transparent),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    ),
  );

  Widget _hang(LichTuan l, HangPhongTuan p) {
    final lan = _xepLan(p.muc);
    final soLan = lan.isEmpty ? 1 : lan.values.reduce((a, b) => a > b ? a : b) + 1;
    return SizedBox(
      height: _caoHang,
      child: Stack(
        children: [
          Row(
            children: [
              for (final n in l.ngay)
                Container(
                  width: _rongNgay,
                  height: _caoHang,
                  decoration: BoxDecoration(
                    color: n.homNay
                        ? HD.accentTint.withValues(alpha: 0.45)
                        : (n.cuoiTuan ? HD.paper.withValues(alpha: 0.5) : null),
                    border: Border(
                      left: BorderSide(
                        color: n.thu == 1 ? HD.hairlineStrong : HD.hairline,
                        width: n.thu == 1 ? 1.2 : 0.4,
                      ),
                      bottom: const BorderSide(color: HD.hairline, width: 0.4),
                    ),
                  ),
                ),
            ],
          ),
          for (final m in p.muc) _khoi(m, lan[m] ?? 0, soLan),
        ],
      ),
    );
  }

  /// Xếp LÀN cho các khối chồng chỗ nhau.
  ///
  /// Ca 4 tiếng, một tiếng dọn phòng rồi ca qua đêm — ba khối rơi vào CÙNG một
  /// ngày. Vẽ đè lên nhau thì thành một cục đỏ không đọc được (đã thấy khi chạy
  /// thật), nên xếp xuống làn dưới: mỗi làn một thanh mỏng, vẫn bấm được từng
  /// cái. Đây là bài toán tô màu khoảng quen thuộc, làm tham lam theo mép trái.
  Map<KhoiTuan, int> _xepLan(List<KhoiTuan> ds) {
    final ra = <KhoiTuan, int>{};
    final metPhai = <double>[];
    for (final m in [...ds]..sort((a, b) => a.cot.compareTo(b.cot))) {
      final trai = m.cot * _rongNgay;
      final phai = trai + _rongVe(m);
      var i = 0;
      while (i < metPhai.length && metPhai[i] > trai + 0.5) {
        i++;
      }
      if (i == metPhai.length) {
        metPhai.add(phai);
      } else {
        metPhai[i] = phai;
      }
      ra[m] = i;
    }
    return ra;
  }

  double _rongVe(KhoiTuan m) =>
      (m.soCot * _rongNgay).clamp(_rongToiThieu, 40000.0);

  Widget _khoi(KhoiTuan m, int lan, int soLan) {
    final trai = m.cot * _rongNgay;
    final rong = _rongVe(m);
    final caoLan = (_caoHang - 8) / soLan;
    final (mau, nen) = m.laChan
        ? (HD.svcBlue, HD.svcBlue.withValues(alpha: 0.14))
        : switch (m.trangThai) {
            'checked_in' => (HD.positive, HD.positiveTint),
            'approved' => (HD.accent, HD.accentTint),
            _ => (HD.svcAmber, HD.warningTint),
          };
    final nhan = m.laChan ? (m.ghiChu ?? 'Dọn phòng') : (m.ten ?? m.nhanKieu);
    return Positioned(
      left: trai,
      top: 4 + lan * caoLan,
      width: rong,
      height: caoLan - 2,
      child: GestureDetector(
        key: ValueKey('o-${m.loai}-${m.id}'),
        onTap: () => _moCa(m),
        child: Tooltip(
          message: m.laChan
              ? (m.ghiChu ?? 'Khoá phòng')
              : '${m.ten ?? 'Ca thuê'} · ${m.nhanKieu}'
                    '${m.tong == null ? '' : ' · ${PriceFormat.full(m.tong!)}'}',
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 5),
            decoration: BoxDecoration(
              color: nen,
              borderRadius: BorderRadius.horizontal(
                left: Radius.circular(m.tranTruoc ? 0 : 8),
                right: Radius.circular(m.tranSau ? 0 : 8),
              ),
              border: Border.all(color: mau.withValues(alpha: 0.55)),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (rong >= 56 && caoLan >= 16)
                  Text(
                    nhan,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: HD.bodyBold(size: 9.5, color: mau),
                  ),
                if (rong >= 110 && caoLan >= 26 && m.tu != null)
                  Text(
                    '${_gio(m.tu!)}${m.den == null ? '' : '–${_gio(m.den!)}'}',
                    maxLines: 1,
                    overflow: TextOverflow.clip,
                    style: HD.body(size: 8.5, color: HD.inkSoft),
                  ),
                if (rong < 56 || caoLan < 16)
                  Center(
                    child: Container(
                      width: 5,
                      height: 5,
                      decoration: BoxDecoration(
                        color: mau,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _chuThich() => Wrap(
    spacing: HD.s12,
    runSpacing: 6,
    children: [
      for (final (mau, chu) in [
        (HD.positive, 'Đang ở'),
        (HD.accent, 'Sắp đến'),
        (HD.svcAmber, 'Chờ duyệt'),
        (HD.svcBlue, 'Dọn / khoá'),
      ])
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 9,
              height: 9,
              decoration: BoxDecoration(color: mau, shape: BoxShape.circle),
            ),
            const SizedBox(width: 5),
            Text(chu, style: HD.body(size: 11, color: HD.inkMuted)),
          ],
        ),
    ],
  );
}

class _OKpi extends StatelessWidget {
  const _OKpi({
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
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: HD.hairline.withValues(alpha: 0.8)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(so, style: HD.bodyBold(size: 17, color: mau)),
        Text(nhan, style: HD.body(size: 10.5, color: HD.inkSoft)),
        Text(phu, style: HD.body(size: 9.5, color: HD.inkMuted)),
      ],
    ),
  );
}

String _hai(int n) => n.toString().padLeft(2, '0');

String _iso(DateTime d) => '${d.year}-${_hai(d.month)}-${_hai(d.day)}';

String _gio(DateTime d) => '${_hai(d.hour)}:${_hai(d.minute)}';

String _ngayNgan(DateTime d) => '${d.day}/${d.month}';

String _thu(int t) =>
    const ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN'][(t - 1).clamp(0, 6)];
