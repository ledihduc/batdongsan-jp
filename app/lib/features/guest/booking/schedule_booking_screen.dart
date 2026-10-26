import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'package:house_booking/core/config/api_config.dart';
import 'package:house_booking/core/theme/design_tokens.dart';
import 'package:house_booking/core/utils/formatters.dart';
import 'package:house_booking/data/services/api_client.dart';
import 'package:house_booking/data/services/lich_xem_api.dart';
import 'package:house_booking/features/auth/guest_gate.dart';
import 'package:house_booking/features/guest/booking/phieu_hen_xem_screen.dart';
import 'package:house_booking/providers/auth_provider.dart';

/// ĐẶT LỊCH XEM NHÀ (thuê dài hạn) — dựng theo mockup "Schedule Viewing"
/// (15/09/2026).
///
///     căn đang xem → 1 chọn ngày → 2 khung giờ → 3 hình thức xem
///     → 4 thông tin khách → sale đón → [Xác nhận đặt lịch xem]
///
/// Neo được vào TIN hoặc PHÒNG (phòng trong dự án có thể chưa gắn tin nào) —
/// giữ nguyên hai tham số cũ để mọi chỗ đang mở màn này không phải sửa.
///
/// Không vẽ thứ không có thật: nút gọi sale chỉ có ở PHIẾU HẸN (sau khi đặt,
/// lúc đó mới lộ SĐT thật); không hứa "xe điện đón sảnh" khi không ai chạy xe.
class ScheduleBookingScreen extends StatefulWidget {
  const ScheduleBookingScreen({
    super.key,
    this.houseId,
    this.roomId,
    this.tenPhong,
    this.api = const LichXemApi(),
    this.homNay,
  }) : assert(houseId != null || roomId != null, 'Cần tin hoặc phòng');

  final int? houseId;
  final int? roomId;

  /// Tên hiển thị khi đặt theo phòng ("Phòng P01 · Toà Hoa Sữa") — dùng tạm
  /// trong lúc chờ thông tin căn tải về.
  final String? tenPhong;

  final LichXemApi api;

  /// Chỉ để test ghim "hôm nay".
  final DateTime? homNay;

  @override
  State<ScheduleBookingScreen> createState() => _ScheduleBookingScreenState();
}

/// Số ngày trên dải chọn ngày. Hai tuần: đủ để hẹn cuối tuần sau, và backend
/// không nhận đặt quá xa mà chủ nhà chưa chắc còn phòng.
const int _soNgay = 14;

class _ScheduleBookingScreenState extends State<ScheduleBookingScreen> {
  final _ten = TextEditingController();
  final _sdt = TextEditingController();
  final _yeuCau = TextEditingController();

  ThongTinDatLich? _tt;
  String? _loiTai;

  late DateTime _ngay;
  List<KhungGio> _khung = const [];
  bool _dangTaiKhung = false;
  final List<GioDeXuat> _gioDaChon = [];

  String _hinhThuc = 'truc_tiep';
  int _soNguoi = 1;
  bool _dangGui = false;

  DateTime get _homNay {
    final n = widget.homNay ?? DateTime.now();
    return DateTime(n.year, n.month, n.day);
  }

  @override
  void initState() {
    super.initState();
    _ngay = _homNay;
    final u = Provider.of<AuthProvider>(context, listen: false).currentUser;
    if (u != null) {
      _ten.text = u.name;
      _sdt.text = u.phone;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _napThongTin();
      _napKhung();
    });
  }

  @override
  void dispose() {
    _ten.dispose();
    _sdt.dispose();
    _yeuCau.dispose();
    super.dispose();
  }

  String get _ngayIso =>
      '${_ngay.year}-${_hai(_ngay.month)}-${_hai(_ngay.day)}';

  Future<void> _napThongTin() async {
    try {
      final t = await widget.api.thongTinDat(
        houseId: widget.houseId,
        roomId: widget.roomId,
      );
      if (mounted) setState(() => _tt = t);
    } catch (e) {
      if (mounted) {
        setState(
          () => _loiTai = e is ApiException
              ? e.message
              : 'Không tải được căn này',
        );
      }
    }
  }

  Future<void> _napKhung() async {
    setState(() => _dangTaiKhung = true);
    try {
      final ds = await widget.api.khungGio(
        _ngayIso,
        houseId: widget.houseId,
        roomId: widget.roomId,
      );
      if (!mounted) return;
      setState(() {
        _khung = ds;
        // Khung đang chọn vừa bị người khác đặt → bỏ chọn, không gửi mù.
        _gioDaChon.removeWhere(
          (selected) =>
              selected.ngay == _ngayIso &&
              !ds.any((slot) => slot.gio == selected.gio && !slot.daCo),
        );
      });
    } catch (_) {
      if (mounted) setState(() => _khung = const []);
    } finally {
      if (mounted) setState(() => _dangTaiKhung = false);
    }
  }

  void _chonNgay(DateTime d) {
    if (d == _ngay) return;
    setState(() {
      _ngay = d;
    });
    _napKhung();
  }

  Future<void> _moLich() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _ngay,
      firstDate: _homNay,
      lastDate: _homNay.add(const Duration(days: 60)),
    );
    if (d != null) _chonNgay(DateTime(d.year, d.month, d.day));
  }

  void _bao(String s) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s)));
  }

  String? get _thieu {
    if (_gioDaChon.isEmpty) return 'Chọn ít nhất một khung giờ xem nhà';
    if (_ten.text.trim().length < 2) return 'Nhập họ tên người đi xem';
    final so = _sdt.text.replaceAll(RegExp(r'\D'), '');
    if (so.length < 9 || so.length > 11) return 'Số điện thoại chưa đúng';
    return null;
  }

  Future<void> _xacNhan() async {
    final thieu = _thieu;
    if (thieu != null) {
      _bao(thieu);
      return;
    }
    if (!GuestGate.requireAuth(
      context,
      message: 'Đăng nhập để đặt lịch xem nhà',
    )) {
      return;
    }
    setState(() => _dangGui = true);
    try {
      final p = await widget.api.datLich(
        houseId: widget.houseId,
        roomId: widget.roomId,
        ngay: _gioDaChon.first.ngay,
        gio: _gioDaChon.first.gio,
        hinhThuc: _hinhThuc,
        soNguoi: _soNguoi,
        tenKhach: _ten.text.trim(),
        sdtKhach: _sdt.text.trim(),
        loiNhan: [
          'Khung giờ khách có thể xem (ưu tiên theo thứ tự):',
          for (var i = 0; i < _gioDaChon.length; i++)
            '${i + 1}. ${_moTaKhung(_gioDaChon[i])}',
          if (_yeuCau.text.trim().isNotEmpty) '',
          if (_yeuCau.text.trim().isNotEmpty)
            'Lời nhắn: ${_yeuCau.text.trim()}',
        ].join(" / "),
      );
      if (!mounted) return;
      await Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => PhieuHenXemScreen(phieuBanDau: p, api: widget.api),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      _bao(e is ApiException ? e.message : 'Không gửi được lịch hẹn');
      // 409 = khung giờ vừa có người khác đặt → tải lại cho khách chọn khung khác.
      if (e is ApiException && e.statusCode == 409) await _napKhung();
    } finally {
      if (mounted) setState(() => _dangGui = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tt = _tt;
    return Scaffold(
      backgroundColor: const Color(0xFFFAF8FF),
      appBar: AppBar(
        backgroundColor: Colors.white.withValues(alpha: 0.92),
        surfaceTintColor: Colors.transparent,
        elevation: 0.5,
        centerTitle: true,
        leading: IconButton(
          onPressed: () => Navigator.maybePop(context),
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
        ),
        title: Text('Đặt lịch xem nhà', style: HD.bodyBold(size: 16)),
      ),
      body: tt == null
          ? Center(
              child: _loiTai == null
                  ? const CircularProgressIndicator(color: HD.accent)
                  : Text(_loiTai!, style: HD.body(color: HD.inkMuted)),
            )
          : ListView(
              padding: const EdgeInsets.only(bottom: 24),
              children: [
                _dai(tt),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _theCan(tt.tin),
                      const SizedBox(height: 20),
                      _buocNgay(),
                      const SizedBox(height: 20),
                      _buocGio(tt),
                      const SizedBox(height: 20),
                      _buocHinhThuc(),
                      const SizedBox(height: 20),
                      _buocKhach(tt),
                      if (tt.sale != null) ...[
                        const SizedBox(height: 20),
                        TheSaleDon(sale: tt.sale!),
                      ],
                    ],
                  ),
                ),
              ],
            ),
      bottomNavigationBar: tt == null ? null : _thanhDuoi(),
    );
  }

  // ── Dải phụ đề ────────────────────────────────────────────────────────────

  Widget _dai(ThongTinDatLich tt) => Container(
    color: const Color(0xFFF2F3FF),
    padding: const EdgeInsets.fromLTRB(16, 6, 16, 8),
    child: Row(
      children: [
        const Icon(Icons.verified_user_outlined, size: 16, color: HD.positive),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            tt.sale == null
                ? 'Miễn phí xem phòng 100%'
                : 'Miễn phí xem phòng 100% cùng sale ${tt.sale!.ten}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: HD.bodyBold(size: 12, color: HD.positive),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: const Color(0xFFDAE2FD),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            '0Đ PHÍ XEM',
            style: HD.bodyBold(size: 10, color: HD.inkSoft),
          ),
        ),
      ],
    ),
  );

  // ── Thẻ căn ───────────────────────────────────────────────────────────────

  Widget _theCan(TomTatCan t) =>
      TheCanMini(tin: t, tenDuPhong: widget.tenPhong);

  // ── Bước 1: ngày ──────────────────────────────────────────────────────────

  Widget _buocNgay() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Row(
        children: [
          const _SoBuoc(1),
          const SizedBox(width: 8),
          Expanded(
            child: Text('Chọn ngày xem nhà', style: HD.bodyBold(size: 17)),
          ),
          InkWell(
            key: const Key('lich-xem-mo-lich'),
            onTap: _moLich,
            child: Row(
              children: [
                const Icon(Icons.calendar_month, size: 16, color: HD.accent),
                const SizedBox(width: 3),
                Text(
                  'Tháng ${_hai(_ngay.month)}',
                  style: HD.bodyBold(size: 12, color: HD.accent),
                ),
              ],
            ),
          ),
        ],
      ),
      const SizedBox(height: 10),
      SizedBox(
        height: 86,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: _soNgay,
          separatorBuilder: (_, _) => const SizedBox(width: 8),
          itemBuilder: (_, i) {
            final d = _homNay.add(Duration(days: i));
            final chon = d == _ngay;
            final nhanTren = i == 0
                ? 'Hôm nay'
                : i == 1
                ? 'Ngày mai'
                : _thuNgan(d.weekday);
            final mauThu = d.weekday == 7
                ? HD.accent
                : (d.weekday == 6 ? HD.svcAmber : HD.inkMuted);
            return InkWell(
              key: Key('lich-xem-ngay-${d.day}'),
              onTap: () => _chonNgay(d),
              borderRadius: BorderRadius.circular(16),
              child: Container(
                width: 68,
                decoration: BoxDecoration(
                  color: chon ? HD.accent : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: chon ? 0.14 : 0.05),
                      blurRadius: chon ? 8 : 3,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      nhanTren,
                      style: HD.bodyBold(
                        size: 10,
                        color: chon
                            ? Colors.white.withValues(alpha: 0.9)
                            : (i < 2 ? HD.inkMuted : mauThu),
                      ),
                    ),
                    Text(
                      '${d.day}',
                      style: HD.bodyBold(
                        size: 22,
                        color: chon ? Colors.white : HD.ink,
                      ),
                    ),
                    Text(
                      i < 2 ? _thuDai(d.weekday) : 'Tháng ${d.month}',
                      style: HD.body(
                        size: 10,
                        color: chon
                            ? Colors.white.withValues(alpha: 0.9)
                            : HD.inkMuted,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    ],
  );

  // ── Bước 2: khung giờ ─────────────────────────────────────────────────────

  Widget _buocGio(ThongTinDatLich tt) {
    final sang = _khung.where((k) => k.gioBatDau < 12).toList();
    final chieu = _khung
        .where((k) => k.gioBatDau >= 12 && k.gioBatDau < 18)
        .toList();
    final toi = _khung.where((k) => k.gioBatDau >= 18).toList();
    return _The(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const _SoBuoc(2),
              const SizedBox(width: 8),
              Expanded(
                child: Text('Khung giờ tiếp đón', style: HD.bodyBold(size: 17)),
              ),
              if (tt.sale != null)
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: HD.positive,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Sale trực sẵn',
                      style: HD.bodyBold(size: 11, color: HD.positive),
                    ),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Chọn các khung giờ phù hợp. Sale sẽ liên hệ chủ nhà để chốt.',
            style: HD.body(size: 12, color: HD.inkMuted),
          ),
          if (_gioDaChon.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              'Khung gi\u1edd b\u1ea1n \u0111\u00e3 ch\u1ecdn (${_gioDaChon.length})',
              style: HD.bodyBold(size: 13, color: HD.ink),
            ),
            const SizedBox(height: 8),
            for (final slot in _gioDaChon)
              Container(
                margin: const EdgeInsets.only(bottom: 6),
                decoration: BoxDecoration(
                  color: HD.accentTint,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: ListTile(
                  dense: true,
                  leading: const Icon(Icons.event, color: HD.accent, size: 18),
                  title: Text(_moTaKhung(slot), style: HD.bodyBold(size: 12)),
                  trailing: IconButton(
                    tooltip: 'B\u1ecf ch\u1ecdn',
                    onPressed: () => setState(() => _gioDaChon.remove(slot)),
                    icon: const Icon(Icons.close, size: 18, color: HD.accent),
                  ),
                ),
              ),
          ],
          if (_dangTaiKhung)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          else if (_khung.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: Text(
                'Ngày ${_ngay.day}/${_ngay.month} không còn khung giờ nhận xem. '
                'Chọn ngày khác nhé.',
                key: const Key('lich-xem-het-khung'),
                style: HD.body(size: 13, color: HD.inkMuted),
              ),
            )
          else ...[
            if (sang.isNotEmpty)
              _nhomGio('Buổi sáng', Icons.wb_sunny_outlined, HD.svcAmber, sang),
            if (chieu.isNotEmpty)
              _nhomGio(
                'Buổi chiều',
                Icons.wb_cloudy_outlined,
                HD.svcOrange,
                chieu,
              ),
            if (toi.isNotEmpty)
              _nhomGio('Buổi tối', Icons.bedtime_outlined, HD.inkSoft, toi),
          ],
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF2F3FF),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.info_outline, size: 18, color: HD.accent),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Chuyên viên sẽ gọi xác nhận, chuẩn bị chìa khoá/thẻ từ và '
                    'đón bạn tại sảnh đúng giờ hẹn.',
                    style: HD.body(size: 12, color: HD.inkSoft),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _nhomGio(String ten, IconData icon, Color mau, List<KhungGio> ds) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(icon, size: 15, color: mau),
                const SizedBox(width: 4),
                Text(ten, style: HD.bodyBold(size: 11, color: HD.inkMuted)),
              ],
            ),
            const SizedBox(height: 6),
            GridView.count(
              crossAxisCount: 3,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              childAspectRatio: 2.6,
              children: [for (final k in ds) _oGio(k)],
            ),
          ],
        ),
      );

  Widget _oGio(KhungGio k) {
    final chon = _gioDaChon.any(
      (slot) => slot.ngay == _ngayIso && slot.gio == k.gio,
    );
    if (k.daCo) {
      return Container(
        key: Key('lich-xem-gio-${k.batDau}'),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: const Color(0xFFEAEDFF),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          k.batDau,
          style: HD
              .body(size: 13, color: HD.inkMuted.withValues(alpha: 0.45))
              .copyWith(decoration: TextDecoration.lineThrough),
        ),
      );
    }
    return InkWell(
      key: Key('lich-xem-gio-${k.batDau}'),
      onTap: () {
        setState(() {
          if (chon) {
            _gioDaChon.removeWhere(
              (slot) => slot.ngay == _ngayIso && slot.gio == k.gio,
            );
          } else {
            _gioDaChon.add(GioDeXuat(ngay: _ngayIso, gio: k.gio));
          }
        });
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: chon ? HD.accent : const Color(0xFFF2F3FF),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (chon) ...[
              const Icon(Icons.check, size: 14, color: Colors.white),
              const SizedBox(width: 2),
            ],
            Text(
              k.batDau,
              style: HD.bodyBold(size: 13, color: chon ? Colors.white : HD.ink),
            ),
          ],
        ),
      ),
    );
  }

  // ── Bước 3: hình thức ─────────────────────────────────────────────────────

  Widget _buocHinhThuc() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Row(
        children: [
          const _SoBuoc(3),
          const SizedBox(width: 8),
          Text('Hình thức xem nhà', style: HD.bodyBold(size: 17)),
        ],
      ),
      const SizedBox(height: 10),
      _luaChon(
        ma: 'truc_tiep',
        tieuDe: 'Xem trực tiếp tại căn hộ',
        nhan: 'Ưu tiên',
        moTa:
            'Chuyên viên đón tận nơi, xem thực tế không gian, nội thất, độ cách '
            'âm và chỗ để xe.',
      ),
      const SizedBox(height: 12),
      _luaChon(
        ma: 'video',
        tieuDe: 'Xem qua video call',
        nhan: 'Tiện lợi',
        moTa:
            'Sale gọi video Zalo, dẫn bạn đi từng phòng, mở tủ, xem ánh sáng '
            'ban công mà không cần đến tận nơi.',
      ),
    ],
  );

  Widget _luaChon({
    required String ma,
    required String tieuDe,
    required String nhan,
    required String moTa,
  }) {
    final chon = _hinhThuc == ma;
    return InkWell(
      key: Key('lich-xem-hinh-thuc-$ma'),
      onTap: () => setState(() => _hinhThuc = ma),
      borderRadius: BorderRadius.circular(24),
      child: Opacity(
        opacity: chon ? 1 : 0.82,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: chon
                  ? HD.accent.withValues(alpha: 0.5)
                  : Colors.transparent,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 4,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 24,
                height: 24,
                margin: const EdgeInsets.only(top: 2),
                decoration: BoxDecoration(
                  color: chon ? HD.accent : const Color(0xFFEAEDFF),
                  shape: BoxShape.circle,
                ),
                child: chon
                    ? const Icon(Icons.check, size: 16, color: Colors.white)
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            tieuDe,
                            style: HD.bodyBold(size: 15, color: HD.ink),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: chon
                                ? HD.accentSoft
                                : const Color(0xFFEAEDFF),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            nhan,
                            style: HD.bodyBold(
                              size: 10,
                              color: chon ? HD.accentDeep : HD.inkMuted,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(moTa, style: HD.body(size: 12, color: HD.inkSoft)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Bước 4: thông tin khách ───────────────────────────────────────────────

  Widget _buocKhach(ThongTinDatLich tt) => _The(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const _SoBuoc(4),
            const SizedBox(width: 8),
            Text('Thông tin khách hẹn', style: HD.bodyBold(size: 17)),
          ],
        ),
        const SizedBox(height: 12),
        _nhan('Họ và tên người đi xem'),
        _o(
          khoa: const Key('lich-xem-ten'),
          c: _ten,
          icon: Icons.badge_outlined,
          goiY: 'Nguyễn Văn A',
        ),
        const SizedBox(height: 12),
        _nhan('Số điện thoại (nhận tin Zalo)'),
        _o(
          khoa: const Key('lich-xem-sdt'),
          c: _sdt,
          icon: Icons.phone_iphone,
          mauIcon: HD.positive,
          goiY: '09xx xxx xxx',
          kieu: TextInputType.phone,
          dinhDang: [FilteringTextInputFormatter.allow(RegExp(r'[0-9 +.]'))],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Số người cùng đi xem',
                    style: HD.bodyBold(size: 12.5, color: HD.ink),
                  ),
                  Text(
                    'Để sale biết đón mấy người',
                    style: HD.body(size: 11.5, color: HD.inkMuted),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                color: const Color(0xFFF2F3FF),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  _nutDem(
                    const Key('lich-xem-bot-nguoi'),
                    Icons.remove,
                    _soNguoi > 1 ? () => setState(() => _soNguoi--) : null,
                  ),
                  SizedBox(
                    width: 34,
                    child: Text(
                      '$_soNguoi',
                      key: const Key('lich-xem-so-nguoi'),
                      textAlign: TextAlign.center,
                      style: HD.bodyBold(size: 16),
                    ),
                  ),
                  _nutDem(
                    const Key('lich-xem-them-nguoi'),
                    Icons.add,
                    _soNguoi < tt.soNguoiToiDa
                        ? () => setState(() => _soNguoi++)
                        : null,
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _nhan('Yêu cầu đặc biệt cho căn hộ này'),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xFFF2F3FF),
            borderRadius: BorderRadius.circular(16),
          ),
          child: TextField(
            key: const Key('lich-xem-yeu-cau'),
            controller: _yeuCau,
            maxLines: 2,
            style: HD.body(size: 14),
            decoration: InputDecoration(
              border: InputBorder.none,
              // Theme app vẽ viền ô nhập; ô này đã có nền bo góc riêng.
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              filled: false,
              hintText:
                  'Ví dụ: muốn xem chỗ đỗ ô tô, hỏi chính sách cọc 1 tháng…',
              hintStyle: HD.body(size: 13, color: HD.inkMuted),
            ),
          ),
        ),
      ],
    ),
  );

  Widget _nhan(String s) => Padding(
    padding: const EdgeInsets.only(bottom: 4),
    child: Text(s, style: HD.bodyBold(size: 12.5, color: HD.ink)),
  );

  Widget _o({
    required Key khoa,
    required TextEditingController c,
    required IconData icon,
    required String goiY,
    Color mauIcon = HD.inkMuted,
    TextInputType? kieu,
    List<TextInputFormatter>? dinhDang,
  }) => Container(
    height: 48,
    padding: const EdgeInsets.symmetric(horizontal: 12),
    decoration: BoxDecoration(
      color: const Color(0xFFF2F3FF),
      borderRadius: BorderRadius.circular(16),
    ),
    child: Row(
      children: [
        Icon(icon, size: 20, color: mauIcon),
        const SizedBox(width: 8),
        Expanded(
          child: TextField(
            key: khoa,
            controller: c,
            keyboardType: kieu,
            inputFormatters: dinhDang,
            style: HD.bodyBold(size: 14),
            decoration: InputDecoration(
              border: InputBorder.none,
              // Theme app vẽ viền ô nhập; ô này đã có nền bo góc riêng.
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              filled: false,
              isDense: true,
              hintText: goiY,
              hintStyle: HD.body(size: 14, color: HD.inkMuted),
            ),
          ),
        ),
      ],
    ),
  );

  Widget _nutDem(Key khoa, IconData icon, VoidCallback? onTap) => InkWell(
    key: khoa,
    onTap: onTap,
    borderRadius: BorderRadius.circular(12),
    child: Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(
        icon,
        size: 16,
        color: onTap == null ? HD.hairlineStrong : HD.ink,
      ),
    ),
  );

  // ── Thanh dưới ────────────────────────────────────────────────────────────

  Widget _thanhDuoi() => Container(
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: 0.96),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.08),
          blurRadius: 24,
          offset: const Offset(0, -8),
        ),
      ],
    ),
    child: SafeArea(
      top: false,
      minimum: const EdgeInsets.fromLTRB(16, 10, 16, 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.verified, size: 14, color: HD.positive),
              const SizedBox(width: 4),
              Text(
                'Bảo mật thông tin • Sale gọi xác nhận lịch hẹn',
                style: HD.body(size: 11, color: HD.inkMuted),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 52,
            width: double.infinity,
            child: FilledButton.icon(
              key: const Key('lich-xem-xac-nhan'),
              onPressed: _dangGui ? null : _xacNhan,
              icon: _dangGui
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.calendar_today, size: 20),
              label: Text(
                'Gửi yêu cầu xem nhà',
                style: HD.bodyBold(size: 16, color: Colors.white),
              ),
              style: FilledButton.styleFrom(
                backgroundColor: HD.accent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

// ── Mảnh dùng chung với phiếu hẹn ────────────────────────────────────────────

String _hai(int n) => n.toString().padLeft(2, '0');

String _thuNgan(int w) =>
    const ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN'][(w - 1).clamp(0, 6)];

String _thuDai(int w) => const [
  'Thứ 2',
  'Thứ 3',
  'Thứ 4',
  'Thứ 5',
  'Thứ 6',
  'Thứ 7',
  'Chủ nhật',
][(w - 1).clamp(0, 6)];

String _moTaKhung(GioDeXuat slot) {
  final date = DateTime.tryParse(slot.ngay);
  if (date == null) return slot.ngay + " · " + slot.gio;
  return _thuDai(date.weekday) +
      ", " +
      date.day.toString() +
      "/" +
      date.month.toString() +
      " · " +
      slot.gio.replaceAll("-", "–");
}

String anhDayDu(String url) =>
    url.startsWith('http') ? url : '${ApiConfig.baseUrl}$url';

class _SoBuoc extends StatelessWidget {
  const _SoBuoc(this.so);

  final int so;

  @override
  Widget build(BuildContext context) => Container(
    width: 24,
    height: 24,
    alignment: Alignment.center,
    decoration: const BoxDecoration(
      color: HD.accentDeep,
      shape: BoxShape.circle,
    ),
    child: Text('$so', style: HD.bodyBold(size: 11, color: Colors.white)),
  );
}

class _The extends StatelessWidget {
  const _The({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(24),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.05),
          blurRadius: 4,
          offset: const Offset(0, 1),
        ),
      ],
    ),
    child: child,
  );
}

/// Thẻ căn thu gọn — ảnh + diện tích, tên, địa chỉ, giá. Dùng ở cả hai màn.
class TheCanMini extends StatelessWidget {
  const TheCanMini({
    super.key,
    required this.tin,
    this.tenDuPhong,
    this.nhanPhai = 'Sẵn sàng xem',
    this.nen = Colors.white,
  });

  final TomTatCan tin;
  final String? tenDuPhong;
  final String? nhanPhai;
  final Color nen;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: nen,
      borderRadius: BorderRadius.circular(24),
      boxShadow: nen == Colors.white
          ? [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 4,
                offset: const Offset(0, 1),
              ),
            ]
          : null,
    ),
    child: Row(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: SizedBox(
            width: 80,
            height: 80,
            child: Stack(
              fit: StackFit.expand,
              children: [
                tin.anh == null
                    ? Container(
                        color: const Color(0xFFEAEDFF),
                        child: const Icon(
                          Icons.apartment,
                          color: HD.inkMuted,
                          size: 30,
                        ),
                      )
                    : CachedNetworkImage(
                        imageUrl: anhDayDu(tin.anh!),
                        fit: BoxFit.cover,
                        errorWidget: (_, _, _) =>
                            Container(color: const Color(0xFFEAEDFF)),
                      ),
                if (tin.dienTich != null)
                  Positioned(
                    right: 4,
                    bottom: 4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 5,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF283044).withValues(alpha: 0.8),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '${tin.dienTich!.toStringAsFixed(0)} m²',
                        style: HD.bodyBold(size: 9, color: Colors.white),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                tin.tieuDe.isEmpty ? (tenDuPhong ?? '') : tin.tieuDe,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: HD.bodyBold(size: 15, color: HD.ink),
              ),
              if (tin.diaChi.isNotEmpty)
                Row(
                  children: [
                    const Icon(Icons.location_on, size: 14, color: HD.accent),
                    const SizedBox(width: 2),
                    Expanded(
                      child: Text(
                        tin.diaChi,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: HD.body(size: 12, color: HD.inkMuted),
                      ),
                    ),
                  ],
                ),
              const SizedBox(height: 6),
              Row(
                children: [
                  if (tin.gia != null)
                    Expanded(
                      child: Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(
                              text: PriceFormat.full(tin.gia!),
                              style: HD.bodyBold(size: 17, color: HD.accent),
                            ),
                            if (tin.donVi.isNotEmpty)
                              TextSpan(
                                text: '/${tin.donVi}',
                                style: HD.body(size: 11, color: HD.inkMuted),
                              ),
                          ],
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    )
                  else
                    const Spacer(),
                  if (nhanPhai != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: HD.positiveTint,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: const BoxDecoration(
                              color: HD.positive,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            nhanPhai!,
                            style: HD.bodyBold(size: 10, color: HD.positive),
                          ),
                        ],
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
}

Widget _chuCaiDau(String ten) => Container(
  color: HD.accentTint,
  alignment: Alignment.center,
  child: Text(
    ten.trim().isEmpty ? '?' : ten.trim()[0].toUpperCase(),
    style: HD.bodyBold(size: 20, color: HD.accent),
  ),
);

/// Thẻ sale sẽ đón khách. [nutLienHe] chỉ bật trên PHIẾU HẸN (có SĐT thật).
///
/// Dùng chung cho đặt phòng ngắn hạn: [thanhTich] thay dòng "lượt xem nhà",
/// [camKet] thay dòng cam kết cuối thẻ.
class TheSaleDon extends StatelessWidget {
  const TheSaleDon({
    super.key,
    required this.sale,
    this.tieuDe = 'CHUYÊN VIÊN PHỤ TRÁCH CĂN HỘ',
    this.nutLienHe,
    this.thanhTich,
    this.camKet = 'Cam kết 0đ phí xem nhà',
  });

  final SalePhuTrach sale;
  final String tieuDe;
  final Widget? nutLienHe;
  final String? thanhTich;
  final String camKet;

  @override
  Widget build(BuildContext context) => _The(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                tieuDe,
                style: HD.bodyBold(size: 10.5, color: HD.inkMuted),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: HD.positiveTint,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                'Đồng hành cùng bạn',
                style: HD.bodyBold(size: 10, color: HD.positive),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: SizedBox(
                width: 56,
                height: 56,
                child: sale.anh == null
                    ? _chuCaiDau(sale.ten)
                    : CachedNetworkImage(
                        imageUrl: anhDayDu(sale.anh!),
                        fit: BoxFit.cover,
                        // Ảnh hỏng/đã xoá vẫn phải ra chữ cái đầu, không để
                        // một ô hồng trống trông như app lỗi.
                        placeholder: (_, _) => _chuCaiDau(sale.ten),
                        errorWidget: (_, _, _) => _chuCaiDau(sale.ten),
                      ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          sale.ten,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: HD.bodyBold(size: 16, color: HD.ink),
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(Icons.verified, size: 18, color: HD.accent),
                    ],
                  ),
                  if (thanhTich != null)
                    Text(
                      thanhTich!,
                      style: HD.body(size: 12, color: HD.inkMuted),
                    )
                  else if (sale.soLanXemXong > 0)
                    Text(
                      '${sale.soLanXemXong} lượt xem nhà thành công',
                      style: HD.body(size: 12, color: HD.inkMuted),
                    ),
                  if (sale.khuVuc.isNotEmpty)
                    Text(
                      'Phụ trách khu vực ${sale.khuVuc}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: HD.body(size: 12, color: HD.inkMuted),
                    ),
                  if (!sale.sdtDaChe && sale.sdt.isNotEmpty)
                    Text(
                      sale.sdt,
                      style: HD.bodyBold(size: 12.5, color: HD.accent),
                    ),
                ],
              ),
            ),
          ],
        ),
        if (nutLienHe != null) ...[
          const SizedBox(height: 12),
          nutLienHe!,
        ] else ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFF2F3FF),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(Icons.loyalty_outlined, size: 18, color: HD.accent),
                const SizedBox(width: 6),
                Expanded(child: Text(camKet, style: HD.bodyBold(size: 11))),
              ],
            ),
          ),
        ],
      ],
    ),
  );
}
