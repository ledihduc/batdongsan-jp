import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import 'package:house_booking/core/config/api_config.dart';
import 'package:house_booking/core/widgets/ds.dart';
import 'package:house_booking/data/services/dat_phong_api.dart';
import 'package:house_booking/data/services/quan_ly_api.dart';
import 'package:house_booking/features/guest/booking/phieu_dat_phong_screen.dart';
import 'package:house_booking/features/guest/lich_xem/chi_tiet_lich_xem_screen.dart';
import 'package:house_booking/features/guest/lich_xem/trang_thai_xem.dart';
import 'package:house_booking/features/guest/lich_xem/widgets/lich_xem_ui.dart';
import 'package:house_booking/features/guest/quan_ly/phong_dang_thue_screen.dart';
import 'package:house_booking/features/guest/quan_ly/xac_nhan_chot_thue_screen.dart';

/// Trang "Hoạt động" của KHÁCH HÀNG — đúng mockup 03/10/2026:
///
///   Hoạt động [lọc][tìm] → Ngắn hạn | Dài hạn →
///   Dài hạn: Đang thuê (n) · Lịch xem phòng sắp tới (n) · Lịch sử
///            [Lịch xem phòng | Đã thuê | Đã kết thúc]
///   Ngắn hạn: Đang ở (n) · Đặt phòng sắp tới (n) · Lịch sử.
///
/// Một nguồn dữ liệu duy nhất: `GET /api/quan-ly?goc=cua_toi` (server đã chia
/// nhóm dang_dat · da_dat · dang_o · lich_su và loại thuê `kenh`). Trang này
/// chỉ chia cột theo mockup, không tự suy trạng thái.
class KhachHoatDongView extends StatefulWidget {
  const KhachHoatDongView({
    super.key,
    this.api = const QuanLyApi(),
    this.onTimNha,
  });

  final QuanLyApi api;
  final VoidCallback? onTimNha;

  @override
  State<KhachHoatDongView> createState() => _KhachHoatDongViewState();
}

/// Lọc lịch sử theo thời gian (nút phễu ở đầu trang).
enum _KhoangThoiGian {
  tatCa('Tất cả', null),
  thang('30 ngày qua', 30),
  quy('3 tháng qua', 90),
  nam('12 tháng qua', 365);

  const _KhoangThoiGian(this.nhan, this.soNgay);
  final String nhan;
  final int? soNgay;
}

class _KhachHoatDongViewState extends State<KhachHoatDongView> {
  TongHopQuanLy? _d;
  Object? _loi;
  bool _dangTai = false;

  bool _daiHan = true;
  int _tabLichSu = 0;
  bool _dangTim = false;
  String _tuKhoa = '';
  _KhoangThoiGian _khoang = _KhoangThoiGian.tatCa;
  final _oTim = TextEditingController();

  @override
  void initState() {
    super.initState();
    _nap();
  }

  @override
  void dispose() {
    _oTim.dispose();
    super.dispose();
  }

  Future<void> _nap() async {
    if (_dangTai) return;
    setState(() {
      _dangTai = true;
      _loi = null;
    });
    try {
      final d = await widget.api.tongHop(GocQuanLy.cuaToi);
      if (mounted) setState(() => _d = d);
    } catch (e) {
      if (mounted) setState(() => _loi = e);
    } finally {
      if (mounted) setState(() => _dangTai = false);
    }
  }

  // ── Chia cột theo mockup ─────────────────────────────────────────────────
  List<MucQuanLy> get _tatCa => _d?.danhSach ?? const [];

  bool _khop(MucQuanLy m) {
    final q = _tuKhoa.trim().toLowerCase();
    if (q.isEmpty) return true;
    return '${m.tieuDe} ${m.diaChi} ${m.ma}'.toLowerCase().contains(q);
  }

  bool _trongKhoang(MucQuanLy m) {
    final n = _khoang.soNgay;
    if (n == null) return true;
    final moc = m.ketThuc ?? m.batDau;
    if (moc == null) return true;
    return moc.isAfter(DateTime.now().subtract(Duration(days: n)));
  }

  /// Lịch xem / hẹn chốt là việc của thuê DÀI HẠN; đơn lưu trú là NGẮN HẠN.
  bool _laNganHan(MucQuanLy m) =>
      m.laDatPhong || (m.laThueDaiHan && m.kenh == 'ngan_han');

  List<MucQuanLy> _loc(bool Function(MucQuanLy) dk) =>
      _tatCa.where((m) => dk(m) && _khop(m)).toList();

  List<MucQuanLy> get _dangThue => _loc(
    (m) => m.laThueDaiHan && !_laNganHan(m) && m.nhom != NhomQuanLy.lichSu,
  );
  List<MucQuanLy> get _lichXemSapToi => _loc(
    (m) =>
        (m.laLichHen || m.laDeNghiThue) &&
        (m.nhom == NhomQuanLy.dangDat || m.nhom == NhomQuanLy.daDat),
  );
  List<MucQuanLy> _lichSuDaiHan(int tab) => _loc(
    (m) =>
        m.nhom == NhomQuanLy.lichSu &&
        _trongKhoang(m) &&
        switch (tab) {
          0 => m.laLichHen,
          1 => m.laThueDaiHan && !_laNganHan(m),
          _ => m.laDeNghiThue,
        },
  );

  List<MucQuanLy> get _dangONganHan =>
      _loc((m) => _laNganHan(m) && m.nhom == NhomQuanLy.dangO);
  List<MucQuanLy> get _datPhongSapToi => _loc(
    (m) =>
        m.laDatPhong &&
        (m.nhom == NhomQuanLy.dangDat || m.nhom == NhomQuanLy.daDat),
  );
  List<MucQuanLy> get _lichSuNganHan => _loc(
    (m) => _laNganHan(m) && m.nhom == NhomQuanLy.lichSu && _trongKhoang(m),
  );

  // ── Điều hướng ───────────────────────────────────────────────────────────
  Future<void> _moMuc(MucQuanLy m) async {
    final Widget? man = switch (m.loai) {
      'dat_phong' => PhieuDatPhongScreen(
        reservationId: m.id,
        api: const DatPhongApi(),
      ),
      'xem_nha' || 'hen_chot' => ChiTietLichXemScreen(
        appointmentId: m.id,
        onTimNha: widget.onTimNha,
      ),
      // Hợp đồng đã kết thúc không còn "hồ sơ phòng đang thuê" để mở —
      // tóm tắt tại chỗ thay vì đưa người dùng vào màn báo lỗi.
      'thue_dai_han' when m.nhom == NhomQuanLy.lichSu => null,
      'thue_dai_han' => PhongDangThueScreen(contractId: m.id),
      'de_nghi_thue' => XacNhanChotThueScreen(dealId: m.id),
      _ => null,
    };
    if (man == null) {
      if (m.laThueDaiHan) await _tomTatHopDongCu(m);
      return;
    }
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => man));
    if (mounted) _nap();
  }

  Future<void> _tomTatHopDongCu(MucQuanLy m) => showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (_) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_tenHienThi(m), style: HD.bodyBold(size: 17)),
            const SizedBox(height: 8),
            _DongIcon(icon: Icons.location_on_outlined, chu: _diaChiNgan(m)),
            const SizedBox(height: 6),
            _DongIcon(icon: Icons.event_outlined, chu: _khoangNgay(m)),
            const SizedBox(height: 12),
            const _Nhan(chu: 'Đã kết thúc', mau: HD.inkMuted, nen: HD.paper),
          ],
        ),
      ),
    ),
  );

  Future<void> _moTatCa(String tieuDe, List<MucQuanLy> ds, _KieuThe kieu) =>
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) =>
              _DanhSachDayDu(tieuDe: tieuDe, ds: ds, kieu: kieu, onMo: _moMuc),
        ),
      );

  Future<void> _chonKhoang() async {
    final chon = await showModalBottomSheet<_KhoangThoiGian>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Text('Lọc lịch sử', style: HD.bodyBold(size: 17)),
            ),
            for (final k in _KhoangThoiGian.values)
              ListTile(
                key: Key('loc-${k.name}'),
                title: Text(k.nhan),
                trailing: k == _khoang
                    ? const Icon(Icons.check_rounded, color: HD.accent)
                    : null,
                onTap: () => Navigator.of(ctx).pop(k),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (chon != null && mounted) setState(() => _khoang = chon);
  }

  // ── Vẽ ───────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          color: HD.accent,
          onRefresh: _nap,
          child: ListView(
            key: const Key('khach-hoat-dong'),
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
            children: [
              _dauTrang(),
              if (_dangTim) ...[const SizedBox(height: 10), _oTimKiem()],
              const SizedBox(height: 14),
              _chonKenh(),
              const SizedBox(height: 18),
              if (_d == null && _dangTai)
                const Padding(
                  padding: EdgeInsets.only(top: 60),
                  child: Center(
                    child: CircularProgressIndicator(color: HD.accent),
                  ),
                )
              else if (_d == null && _loi != null)
                _baoLoi()
              else if (_daiHan)
                ..._noiDungDaiHan()
              else
                ..._noiDungNganHan(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _dauTrang() => Row(
    children: [
      Expanded(
        child: Text(
          'Hoạt động',
          style: HD
              .bodyBold(size: 30, color: HD.ink)
              .copyWith(letterSpacing: -0.5),
        ),
      ),
      _NutTron(
        key: const Key('khach-hoat-dong-loc'),
        tooltip: 'Lọc',
        icon: Icons.filter_alt_outlined,
        nen: HD.accentTint,
        mau: HD.accent,
        dauCham: _khoang != _KhoangThoiGian.tatCa,
        onTap: _chonKhoang,
      ),
      const SizedBox(width: 12),
      _NutTron(
        key: const Key('khach-hoat-dong-tim'),
        tooltip: 'Tìm kiếm',
        icon: _dangTim ? Icons.close_rounded : Icons.search_rounded,
        nen: HD.accent,
        mau: Colors.white,
        onTap: () => setState(() {
          _dangTim = !_dangTim;
          if (!_dangTim) {
            _tuKhoa = '';
            _oTim.clear();
          }
        }),
      ),
    ],
  );

  Widget _oTimKiem() => TextField(
    key: const Key('khach-hoat-dong-o-tim'),
    controller: _oTim,
    autofocus: true,
    onChanged: (v) => setState(() => _tuKhoa = v),
    decoration: InputDecoration(
      hintText: 'Tìm theo tên phòng, địa chỉ…',
      prefixIcon: const Icon(Icons.search_rounded),
      isDense: true,
      filled: true,
      fillColor: HD.paper,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
    ),
  );

  Widget _chonKenh() => Container(
    height: 50,
    padding: const EdgeInsets.all(3),
    decoration: BoxDecoration(
      color: const Color(0xFFF2F3F5),
      borderRadius: BorderRadius.circular(14),
    ),
    child: Row(
      children: [
        for (final (nhan, laDai) in const [
          ('Ngắn hạn', false),
          ('Dài hạn', true),
        ])
          Expanded(
            child: GestureDetector(
              key: Key('khach-kenh-${laDai ? 'dai' : 'ngan'}'),
              onTap: () => setState(() => _daiHan = laDai),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: _daiHan == laDai ? HD.accent : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  nhan,
                  style: HD.bodyBold(
                    size: 17,
                    color: _daiHan == laDai ? Colors.white : HD.inkSoft,
                  ),
                ),
              ),
            ),
          ),
      ],
    ),
  );

  Widget _baoLoi() => Padding(
    padding: const EdgeInsets.only(top: 40),
    child: Column(
      children: [
        const Icon(Icons.cloud_off_rounded, size: 40, color: HD.inkMuted),
        const SizedBox(height: 10),
        Text('Chưa tải được hoạt động.', style: HD.body(color: HD.inkMuted)),
        const SizedBox(height: 10),
        OutlinedButton(
          key: const Key('khach-hoat-dong-thu-lai'),
          onPressed: _nap,
          child: const Text('Thử lại'),
        ),
      ],
    ),
  );

  List<Widget> _noiDungDaiHan() {
    final dangThue = _dangThue;
    final lichXem = _lichXemSapToi;
    final lichSu = _lichSuDaiHan(_tabLichSu);
    return [
      _TieuDeMuc(
        chu: 'Đang thuê (${dangThue.length})',
        onXemThem: dangThue.length > 2
            ? () => _moTatCa('Đang thuê', dangThue, _KieuThe.dangThue)
            : null,
      ),
      const SizedBox(height: 10),
      if (dangThue.isEmpty)
        _Rong(
          chu: 'Bạn chưa thuê phòng nào.',
          nut: widget.onTimNha == null ? null : 'Tìm nhà',
          onNut: widget.onTimNha,
        )
      else
        for (final m in dangThue.take(2))
          _TheDangThue(m: m, onTap: () => _moMuc(m)),
      const SizedBox(height: 14),
      _TieuDeMuc(
        chu: 'Lịch xem phòng sắp tới (${lichXem.length})',
        onXemThem: lichXem.length > 2
            ? () =>
                  _moTatCa('Lịch xem phòng sắp tới', lichXem, _KieuThe.lichXem)
            : null,
      ),
      const SizedBox(height: 10),
      if (lichXem.isEmpty)
        const _Rong(chu: 'Chưa có lịch xem phòng nào sắp tới.')
      else
        for (final m in lichXem.take(2))
          _TheLichXem(m: m, onTap: () => _moMuc(m)),
      const SizedBox(height: 18),
      Text('Lịch sử', style: HD.bodyBold(size: 22, color: HD.ink)),
      const SizedBox(height: 10),
      _KhungLichSu(
        tabs: const ['Lịch xem phòng', 'Đã thuê', 'Đã kết thúc'],
        tab: _tabLichSu,
        onTab: (i) => setState(() => _tabLichSu = i),
        ds: lichSu,
        rong: const [
          'Chưa có lịch xem nào đã qua.',
          'Chưa có phòng nào đã thuê xong.',
          'Chưa có yêu cầu thuê nào đã kết thúc.',
        ][_tabLichSu],
        onMo: _moMuc,
      ),
    ];
  }

  List<Widget> _noiDungNganHan() {
    final dangO = _dangONganHan;
    final sapToi = _datPhongSapToi;
    final lichSu = _lichSuNganHan;
    return [
      _TieuDeMuc(
        chu: 'Đang ở (${dangO.length})',
        onXemThem: dangO.length > 2
            ? () => _moTatCa('Đang ở', dangO, _KieuThe.dangThue)
            : null,
      ),
      const SizedBox(height: 10),
      if (dangO.isEmpty)
        _Rong(
          chu: 'Bạn chưa có phòng ngắn hạn nào đang ở.',
          nut: widget.onTimNha == null ? null : 'Đặt phòng',
          onNut: widget.onTimNha,
        )
      else
        for (final m in dangO.take(2))
          _TheDangThue(m: m, onTap: () => _moMuc(m), nhan: 'Đang ở'),
      const SizedBox(height: 14),
      _TieuDeMuc(
        chu: 'Đặt phòng sắp tới (${sapToi.length})',
        onXemThem: sapToi.length > 2
            ? () => _moTatCa('Đặt phòng sắp tới', sapToi, _KieuThe.lichXem)
            : null,
      ),
      const SizedBox(height: 10),
      if (sapToi.isEmpty)
        const _Rong(chu: 'Chưa có đặt phòng nào sắp tới.')
      else
        for (final m in sapToi.take(2))
          _TheLichXem(m: m, onTap: () => _moMuc(m)),
      const SizedBox(height: 18),
      Text('Lịch sử', style: HD.bodyBold(size: 22, color: HD.ink)),
      const SizedBox(height: 10),
      _KhungLichSu(
        tabs: const [],
        tab: 0,
        onTab: (_) {},
        ds: lichSu,
        rong: 'Chưa có lượt lưu trú nào đã qua.',
        onMo: _moMuc,
      ),
    ];
  }
}

// ── Định dạng dùng chung ─────────────────────────────────────────────────────
String _hai(int n) => n.toString().padLeft(2, '0');
String _ngay(DateTime d) => '${_hai(d.day)}/${_hai(d.month)}/${d.year}';
String _gio(DateTime d) => '${_hai(d.hour)}:${_hai(d.minute)}';

/// "Phòng 305 · Vạn Phúc Residence" → "Phòng 305 – Vạn Phúc Residence".
String _tenHienThi(MucQuanLy m) => m.tieuDe.replaceAll(' · ', ' – ');

/// Địa chỉ đầy đủ → "Quận 7, TP.HCM" (hai vế cuối), như mockup.
String _diaChiNgan(MucQuanLy m) {
  final ve = m.diaChi
      .split(',')
      .map((s) => s.trim())
      .where((s) => s.isNotEmpty)
      .toList();
  if (ve.length <= 2) return ve.join(', ');
  return ve.sublist(ve.length - 2).join(', ');
}

String _khoangNgay(MucQuanLy m) {
  final a = m.batDau, b = m.ketThuc;
  if (a == null && b == null) return m.dong;
  return '${a == null ? '?' : _ngay(a)} – ${b == null ? '?' : _ngay(b)}';
}

/// "Còn 10 tháng" / "Còn 12 ngày" / "Quá hạn".
String? _conLai(MucQuanLy m) {
  final het = m.ketThuc;
  if (het == null) return null;
  final now = DateTime.now();
  final ngay = het.difference(DateTime(now.year, now.month, now.day)).inDays;
  if (ngay < 0) return 'Quá hạn';
  if (ngay < 31) return 'Còn $ngay ngày';
  var thang = (het.year - now.year) * 12 + het.month - now.month;
  if (het.day < now.day) thang -= 1;
  return 'Còn ${thang < 1 ? 1 : thang} tháng';
}

/// Huy hiệu trạng thái của lịch xem / đặt phòng — theo nhóm server đã chia.
(String, Color, Color) _trangThai(MucQuanLy m) {
  if (m.nhom == NhomQuanLy.daDat) {
    return ('Đã xác nhận', HD.positive, HD.positiveTint);
  }
  return ('Chờ xác nhận', const Color(0xFFC77C00), HD.warningTint);
}

/// Trạng thái lịch xem của khách. Server cũ chưa gửi `trang_thai` thô → suy
/// từ nhóm để không tô nhầm "Đã hủy".
BuocXem _buocHen(MucQuanLy m) => buocXemCua(
  m.trangThai.isNotEmpty
      ? m.trangThai
      : switch (m.nhom) {
          NhomQuanLy.dangDat => 'pending',
          NhomQuanLy.daDat => 'approved',
          _ => 'completed',
        },
  ketQua: m.ketQua,
  luc: m.batDau,
);

/// Dòng phụ của một mục lịch sử: "Đã xem 20/09/2024", "01/09/2024 – …".
String _dongLichSu(MucQuanLy m) {
  if (m.laThueDaiHan) return _khoangNgay(m);
  if (m.laLichHen) {
    final moc = m.batDau;
    final buoc = _buocHen(m);
    return moc == null ? buoc.chu : '${buoc.chu} · ${_ngay(moc)}';
  }
  final nhan = m.dong.split(' · ').first.trim();
  final moc = m.batDau;
  if (moc == null) return nhan;
  return '${nhan.isEmpty ? 'Ngày' : nhan} ${_ngay(moc)}';
}

enum _KieuThe { dangThue, lichXem }

// ── Thành phần ───────────────────────────────────────────────────────────────
class _NutTron extends StatelessWidget {
  const _NutTron({
    super.key,
    required this.tooltip,
    required this.icon,
    required this.nen,
    required this.mau,
    required this.onTap,
    this.dauCham = false,
  });

  final String tooltip;
  final IconData icon;
  final Color nen;
  final Color mau;
  final VoidCallback onTap;
  final bool dauCham;

  @override
  Widget build(BuildContext context) => Tooltip(
    message: tooltip,
    child: Material(
      color: nen,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 48,
          height: 48,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Icon(icon, color: mau, size: 26),
              if (dauCham)
                Positioned(
                  right: 11,
                  top: 11,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: HD.accent,
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

class _TieuDeMuc extends StatelessWidget {
  const _TieuDeMuc({required this.chu, this.onXemThem});

  final String chu;
  final VoidCallback? onXemThem;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: Text(chu, style: HD.bodyBold(size: 21, color: HD.ink)),
      ),
      if (onXemThem != null)
        InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onXemThem,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Xem thêm', style: HD.body(size: 15, color: HD.accent)),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: HD.accent,
                  size: 22,
                ),
              ],
            ),
          ),
        ),
    ],
  );
}

class _KhungThe extends StatelessWidget {
  const _KhungThe({required this.child, required this.onTap});

  final Widget child;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: DecoratedBox(
      // Nền TRẮNG đặc như mockup; Material trong suốt chỉ để có hiệu ứng chạm.
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF0F1F4)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0F000000),
            blurRadius: 14,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(padding: const EdgeInsets.all(10), child: child),
        ),
      ),
    ),
  );
}

class _Anh extends StatelessWidget {
  const _Anh({
    required this.url,
    this.rong = 120,
    this.cao = 92,
    this.tiLe = 0.31,
    this.nhan,
  });

  final String? url;
  final double rong;
  final double tiLe;
  final double cao;
  final Widget? nhan;

  @override
  Widget build(BuildContext context) {
    const nen = ColoredBox(
      color: HD.paperSunken,
      child: Center(
        child: Icon(Icons.bed_outlined, color: HD.inkMuted, size: 30),
      ),
    );
    final u = url;
    // Ảnh co theo bề ngang máy: màn 360px vẫn đủ chỗ cho chữ bên phải.
    final w = math.min(rong, MediaQuery.sizeOf(context).width * tiLe);
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        width: w,
        height: cao,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (u == null || u.isEmpty)
              nen
            else
              CachedNetworkImage(
                imageUrl: u.startsWith('http') ? u : '${ApiConfig.baseUrl}$u',
                fit: BoxFit.cover,
                memCacheWidth: 320,
                placeholder: (_, _) => nen,
                errorWidget: (_, _, _) => nen,
              ),
            if (nhan != null) Positioned(left: 8, bottom: 8, child: nhan!),
          ],
        ),
      ),
    );
  }
}

class _Nhan extends StatelessWidget {
  const _Nhan({
    required this.chu,
    required this.mau,
    required this.nen,
    this.icon,
  });

  final String chu;
  final Color mau;
  final Color nen;
  final IconData? icon;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
      color: nen,
      borderRadius: BorderRadius.circular(HD.rPill),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[
          Icon(icon, size: 15, color: mau),
          const SizedBox(width: 5),
        ],
        Text(chu, style: HD.bodyBold(size: 12.5, color: mau)),
      ],
    ),
  );
}

class _DongIcon extends StatelessWidget {
  const _DongIcon({required this.icon, required this.chu, this.cuoi});

  final IconData icon;
  final String chu;
  final String? cuoi;

  @override
  Widget build(BuildContext context) {
    final kieu = HD.body(size: 13, color: HD.inkMuted);
    final kieuCuoi = HD.body(size: 12.5, color: HD.inkMuted);
    Widget dong(String text) => Row(
      children: [
        Icon(icon, size: 16, color: HD.inkMuted),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: kieu,
          ),
        ),
      ],
    );
    final c = cuoi;
    if (c == null) return dong(chu);
    // Mockup đặt "Còn 10 tháng" cùng dòng với ngày. Màn hẹp không đủ chỗ thì
    // cho nó xuống dòng (canh phải) thay vì cắt mất ngày tháng.
    return LayoutBuilder(
      builder: (context, box) {
        double rong(String t, TextStyle st) => (TextPainter(
          text: TextSpan(text: t, style: st),
          textDirection: TextDirection.ltr,
          textScaler: MediaQuery.textScalerOf(context),
          maxLines: 1,
        )..layout()).width;
        final can = 22 + rong(chu, kieu) + 10 + rong(c, kieuCuoi);
        if (can <= box.maxWidth) {
          return Row(
            children: [
              Icon(icon, size: 16, color: HD.inkMuted),
              const SizedBox(width: 6),
              Expanded(child: Text(chu, maxLines: 1, style: kieu)),
              Text(c, style: kieuCuoi),
            ],
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(icon, size: 16, color: HD.inkMuted),
                const SizedBox(width: 6),
                Expanded(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(chu, maxLines: 1, style: kieu),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 3),
            Text(c, textAlign: TextAlign.right, style: kieuCuoi),
          ],
        );
      },
    );
  }
}

/// Thẻ "Đang thuê": ảnh + nhãn xanh, tên, địa chỉ, khoảng ngày + "Còn N tháng".
class _TheDangThue extends StatelessWidget {
  const _TheDangThue({
    required this.m,
    required this.onTap,
    this.nhan = 'Đang thuê',
  });

  final MucQuanLy m;
  final VoidCallback onTap;
  final String nhan;

  @override
  Widget build(BuildContext context) => _KhungThe(
    onTap: onTap,
    child: Row(
      key: Key('khach-dang-thue-${m.id}'),
      children: [
        _Anh(
          url: m.anh,
          nhan: _Nhan(chu: nhan, mau: HD.positive, nen: HD.positiveTint),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _tenHienThi(m),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: HD.bodyBold(size: 15, color: HD.ink),
              ),
              const SizedBox(height: 7),
              _DongIcon(icon: Icons.location_on_outlined, chu: _diaChiNgan(m)),
              const SizedBox(height: 6),
              _DongIcon(
                icon: Icons.calendar_month_outlined,
                chu: _khoangNgay(m),
                cuoi: _conLai(m),
              ),
            ],
          ),
        ),
        const Icon(Icons.chevron_right_rounded, color: HD.inkSoft),
      ],
    ),
  );
}

/// Thẻ "Lịch xem phòng sắp tới" (và đặt phòng sắp tới ở tab Ngắn hạn).
class _TheLichXem extends StatelessWidget {
  const _TheLichXem({required this.m, required this.onTap});

  final MucQuanLy m;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    if (m.laLichHen) return _TheHenXem(m: m, onTap: onTap);
    final (chu, mau, nen) = _trangThai(m);
    final moc = m.batDau;
    final loai = m.laDatPhong
        ? 'Đặt phòng'
        : m.laDeNghiThue
        ? 'Chốt thuê'
        : 'Lịch xem';
    return _KhungThe(
      onTap: onTap,
      child: Row(
        key: Key('khach-lich-xem-${m.loai}-${m.id}'),
        children: [
          _Anh(url: m.anh, rong: 104, cao: 96, tiLe: 0.26),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: _Nhan(
                          chu: loai,
                          mau: HD.accent,
                          nen: HD.accentTint,
                          icon: Icons.event_note_outlined,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerRight,
                        child: _Nhan(chu: chu, mau: mau, nen: nen),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 7),
                Text(
                  _tenHienThi(m),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: HD.bodyBold(size: 15, color: HD.ink),
                ),
                const SizedBox(height: 6),
                _DongIcon(
                  icon: Icons.location_on_outlined,
                  chu: _diaChiNgan(m),
                ),
                const SizedBox(height: 5),
                _DongIcon(
                  icon: Icons.calendar_month_outlined,
                  chu: moc == null
                      ? m.dong
                      : '${_ngay(moc)}   •   ${_gio(moc)}',
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded, color: HD.inkSoft),
        ],
      ),
    );
  }
}

/// Thẻ lịch xem phòng (mockup "Luồng lịch xem phòng sắp tới", 04/10/2026):
/// nhãn trạng thái · tên phòng · ⏰ ngày • giờ · địa chỉ · "Sale: `tên`".
class _TheHenXem extends StatelessWidget {
  const _TheHenXem({required this.m, required this.onTap});

  final MucQuanLy m;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final moc = m.batDau;
    final buoc = _buocHen(m);
    return _KhungThe(
      onTap: onTap,
      child: Row(
        key: Key('khach-lich-xem-${m.loai}-${m.id}'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Anh(url: m.anh, rong: 104, cao: 104, tiLe: 0.26),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: NhanBuocXem(buoc),
                ),
                const SizedBox(height: 7),
                Text(
                  _tenHienThi(m),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: HD.bodyBold(size: 15, color: HD.ink),
                ),
                const SizedBox(height: 6),
                _DongIcon(
                  icon: Icons.access_time_rounded,
                  chu: moc == null
                      ? m.dong
                      : '${_ngay(moc)}   •   ${_gio(moc)}',
                ),
                const SizedBox(height: 5),
                _DongIcon(
                  icon: Icons.location_on_outlined,
                  chu: _diaChiNgan(m),
                ),
                if (buoc == BuocXem.daChot) ...[
                  const SizedBox(height: 6),
                  Text(
                    'Xem tại mục Đang thuê',
                    style: HD.bodyBold(size: 12.5, color: BuocXem.daChot.mau),
                  ),
                ] else if ((m.saleTen ?? '').isNotEmpty) ...[
                  const SizedBox(height: 7),
                  Row(
                    children: [
                      AnhDaiDien(ten: m.saleTen!, anh: m.saleAnh, co: 22),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Sale: ${m.saleTen}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: HD.body(size: 12.5, color: HD.inkSoft),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const Padding(
            padding: EdgeInsets.only(top: 40),
            child: Icon(Icons.chevron_right_rounded, color: HD.inkSoft),
          ),
        ],
      ),
    );
  }
}

/// Khối "Lịch sử": dải tab + danh sách dòng có ảnh nhỏ, ngăn bằng vạch mảnh.
class _KhungLichSu extends StatelessWidget {
  const _KhungLichSu({
    required this.tabs,
    required this.tab,
    required this.onTab,
    required this.ds,
    required this.rong,
    required this.onMo,
  });

  final List<String> tabs;
  final int tab;
  final ValueChanged<int> onTab;
  final List<MucQuanLy> ds;
  final String rong;
  final ValueChanged<MucQuanLy> onMo;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(6),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: const Color(0xFFF0F1F4)),
      boxShadow: const [
        BoxShadow(
          color: Color(0x0D000000),
          blurRadius: 12,
          offset: Offset(0, 3),
        ),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (tabs.isNotEmpty)
          Row(
            children: [
              for (var i = 0; i < tabs.length; i++) ...[
                if (i > 0) const SizedBox(width: 6),
                Expanded(
                  child: GestureDetector(
                    key: Key('khach-lich-su-tab-$i'),
                    onTap: () => onTab(i),
                    child: Container(
                      height: 40,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: i == tab ? HD.accent : const Color(0xFFF2F3F5),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          tabs[i],
                          maxLines: 1,
                          style: HD
                              .body(
                                size: 13.5,
                                color: i == tab ? Colors.white : HD.inkSoft,
                              )
                              .copyWith(
                                fontWeight: i == tab
                                    ? FontWeight.w600
                                    : FontWeight.w500,
                              ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        if (ds.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 22),
            child: Text(
              rong,
              textAlign: TextAlign.center,
              style: HD.body(size: 13, color: HD.inkMuted),
            ),
          )
        else
          for (var i = 0; i < ds.length; i++) ...[
            if (i > 0)
              const Divider(
                height: 1,
                indent: 8,
                endIndent: 8,
                color: Color(0xFFF0F1F4),
              ),
            _DongLichSu(m: ds[i], onTap: () => onMo(ds[i])),
          ],
      ],
    ),
  );
}

class _DongLichSu extends StatelessWidget {
  const _DongLichSu({required this.m, required this.onTap});

  final MucQuanLy m;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    key: Key('khach-lich-su-${m.loai}-${m.id}'),
    borderRadius: BorderRadius.circular(12),
    onTap: onTap,
    child: Padding(
      padding: const EdgeInsets.fromLTRB(4, 10, 2, 10),
      child: Row(
        children: [
          _Anh(url: m.anh, rong: 84, cao: 62, tiLe: 0.22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _tenHienThi(m),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: HD.bodyBold(size: 14.5, color: HD.ink),
                ),
                const SizedBox(height: 3),
                Text(
                  _dongLichSu(m),
                  style: HD.body(size: 12.5, color: HD.inkMuted),
                ),
                const SizedBox(height: 3),
                _DongIcon(
                  icon: Icons.location_on_outlined,
                  chu: _diaChiNgan(m),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded, color: HD.inkSoft),
        ],
      ),
    ),
  );
}

class _Rong extends StatelessWidget {
  const _Rong({required this.chu, this.nut, this.onNut});

  final String chu;
  final String? nut;
  final VoidCallback? onNut;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 14),
    margin: const EdgeInsets.only(bottom: 10),
    decoration: BoxDecoration(
      color: const Color(0xFFF7F8FA),
      borderRadius: BorderRadius.circular(16),
    ),
    child: Row(
      children: [
        Expanded(
          child: Text(chu, style: HD.body(size: 13.5, color: HD.inkMuted)),
        ),
        if (nut != null && onNut != null)
          TextButton(
            onPressed: onNut,
            style: TextButton.styleFrom(foregroundColor: HD.accent),
            child: Text(nut!),
          ),
      ],
    ),
  );
}

/// Màn "Xem thêm": toàn bộ một khối, cùng kiểu thẻ.
class _DanhSachDayDu extends StatelessWidget {
  const _DanhSachDayDu({
    required this.tieuDe,
    required this.ds,
    required this.kieu,
    required this.onMo,
  });

  final String tieuDe;
  final List<MucQuanLy> ds;
  final _KieuThe kieu;
  final ValueChanged<MucQuanLy> onMo;

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.white,
    appBar: AppBar(
      title: Text(tieuDe),
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.white,
    ),
    body: ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        for (final m in ds)
          kieu == _KieuThe.dangThue
              ? _TheDangThue(m: m, onTap: () => onMo(m))
              : _TheLichXem(m: m, onTap: () => onMo(m)),
      ],
    ),
  );
}
