import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'package:house_booking/core/theme/design_tokens.dart';
import 'package:house_booking/core/utils/formatters.dart';
import 'package:house_booking/data/services/api_client.dart';
import 'package:house_booking/data/services/dat_phong_api.dart';
import 'package:house_booking/data/services/lich_xem_api.dart' show TomTatCan;
import 'package:house_booking/data/services/short_stay_api.dart' show stayNow;
import 'package:house_booking/features/auth/guest_gate.dart';
import 'package:house_booking/features/chat/chat_screen.dart';
import 'package:house_booking/features/guest/booking/phieu_dat_phong_screen.dart';
import 'package:house_booking/features/guest/booking/schedule_booking_screen.dart'
    show TheCanMini, TheSaleDon;
import 'package:house_booking/providers/auth_provider.dart';

/// Tham số mở màn đặt phòng — giữ nguyên cho mọi chỗ đang mở màn này (tin đăng,
/// trang toà của sale, tìm phòng ngắn hạn, route `/dat-phong/:id`).
class RoomBookingArgs {
  const RoomBookingArgs({
    required this.roomId,
    required this.roomCode,
    required this.buildingName,
    required this.price,
    required this.saleName,
    this.mode,
    this.start,
    this.end,
    this.houseId,
    this.theoHang = false,
  });
  final int roomId;

  /// true = tin bán theo HẠNG PHÒNG (backend 0130): màn này hỏi giá, lịch bận
  /// và đặt qua `/api/short-stays/tin/{houseId}/…`, SERVER bốc phòng lúc chốt.
  /// [roomId] khi đó chỉ là chỗ giữ và KHÔNG được gửi đi — app không biết
  /// phòng nào vừa có người giữ, còn lễ tân vẫn đổi phòng trước giờ nhận.
  final bool theoHang;

  /// Tin đăng dẫn khách tới đây (rỗng khi vào từ trang toà của sale).
  final int? houseId;
  final String roomCode, buildingName, saleName;
  final double
  price; // Kept for old callers; authoritative quote comes from API.
  final String? mode;
  final DateTime? start, end;
}

/// ĐẶT PHÒNG NGẮN HẠN — cùng khuôn màn "Đặt lịch xem nhà" dài hạn (16/09/2026).
///
///     phòng → 1 hình thức (giờ / qua đêm / ngày) → 2 ngày nhận → 3 giờ nhận
///     + thời lượng → 4 người nhận phòng → sale phụ trách → giá → [Đặt phòng]
///
/// Khác dài hạn ở chỗ cốt lõi: KHÔNG hẹn đi xem — khách ĐẶT LUÔN. Muốn hỏi thêm
/// thì nhắn SALE (không có đường liên hệ thẳng chủ nhà — luật 14/09/2026).
///
/// Giờ đã có người được gạch ngay trên lưới, lấy từ `lich-ban` — không để khách
/// chọn xong, điền xong rồi mới nghe "phòng vừa có lịch". Giá luôn lấy từ server
/// (`quote`), app chỉ tính giờ trả để hiển thị, cùng luật `gio_tra` của server.
class RoomBookingScreen extends StatefulWidget {
  const RoomBookingScreen({
    required this.args,
    super.key,
    this.api = const DatPhongApi(),
    this.homNay,
    this.doiGioCho,
  });
  final RoomBookingArgs args;
  final DatPhongApi api;

  /// Có phiếu = CHẾ ĐỘ ĐỔI GIỜ cho đơn này: dùng lại lưới giờ, bỏ bước người nhận
  /// và thẻ sale, báo giá qua `doi-gio/bao-gia` (bỏ qua chính đơn khi xét trùng),
  /// xác nhận xong trả phiếu mới về màn gọi.
  final PhieuDatPhong? doiGioCho;

  /// Chỉ để test ghim "bây giờ" (giờ VN).
  final DateTime? homNay;

  @override
  State<RoomBookingScreen> createState() => _RoomBookingScreenState();
}

/// Dải ngày nhận phòng.
const int _soNgay = 14;

/// Giờ nhận phòng mở cho từng hình thức. Qua đêm nhận buổi tối; theo ngày nhận
/// từ trưa — đúng thói quen khách sạn, và khớp giờ trả 12:00 của server.
const Map<String, List<int>> _gioMo = {
  'theo_gio': [7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22],
  'qua_dem': [17, 18, 19, 20, 21, 22, 23],
  'theo_ngay': [12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22],
};

const Map<String, String> _moTaGoi = {
  'theo_gio': 'Nghỉ ngơi vài tiếng — trả phòng chẵn giờ',
  'qua_dem': 'Nhận buổi tối, trả phòng 12:00 trưa hôm sau',
  'theo_ngay': 'Ở nhiều ngày, trả phòng 12:00 trưa ngày cuối',
};

const Map<String, IconData> _iconGoi = {
  'theo_gio': Icons.schedule,
  'qua_dem': Icons.nights_stay_outlined,
  'theo_ngay': Icons.calendar_month_outlined,
};

class _RoomBookingScreenState extends State<RoomBookingScreen> {
  final _ten = TextEditingController();
  final _sdt = TextEditingController();
  final _ghiChu = TextEditingController();

  ThongTinDatPhong? _tt;
  String? _loiTai;
  List<KhoangBan> _ban = const [];

  String _hinhThuc = 'theo_gio';
  late DateTime _ngay;
  int? _gio;
  int _soGio = 2;
  int _soDem = 1;
  int _soKhach = 1;

  BaoGiaPhong? _baoGia;
  String? _loiBaoGia;
  bool _dangBaoGia = false;
  int _phien = 0;
  bool _dangDat = false;

  /// "Bây giờ" theo giờ VN, bỏ giây.
  DateTime get _bayGio {
    final n = widget.homNay ?? stayNow();
    return DateTime(n.year, n.month, n.day, n.hour, n.minute);
  }

  DateTime get _homNay => DateTime(_bayGio.year, _bayGio.month, _bayGio.day);

  @override
  void initState() {
    super.initState();
    _ngay = _homNay;
    _hinhThuc = widget.args.mode ?? 'theo_gio';
    final s = widget.args.start;
    if (s != null) {
      _ngay = DateTime(s.year, s.month, s.day);
      _gio = s.hour;
    }
    final cu = widget.doiGioCho;
    if (cu != null && cu.nhan != null) {
      _hinhThuc = cu.hinhThuc;
      _ngay = DateTime(cu.nhan!.year, cu.nhan!.month, cu.nhan!.day);
      _gio = cu.nhan!.hour;
      if (cu.hinhThuc == 'theo_gio' && cu.soLuong > 0) _soGio = cu.soLuong;
      if (cu.hinhThuc == 'theo_ngay' && cu.soLuong > 0) _soDem = cu.soLuong;
      if (cu.soKhach != null) _soKhach = cu.soKhach!;
    }
    final u = Provider.of<AuthProvider>(context, listen: false).currentUser;
    if (u != null) {
      _ten.text = u.name;
      _sdt.text = u.phone;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _nap());
  }

  @override
  void dispose() {
    _ten.dispose();
    _sdt.dispose();
    _ghiChu.dispose();
    super.dispose();
  }

  Future<void> _nap() async {
    try {
      final tt = widget.args.theoHang
          ? await widget.api.thongTinDatTheoTin(widget.args.houseId!)
          : await widget.api.thongTinDat(
              widget.args.roomId,
              houseId: widget.args.houseId,
            );
      if (!mounted) return;
      setState(() {
        _tt = tt;
        if (tt.goiCua(_hinhThuc) == null && tt.goi.isNotEmpty) {
          _hinhThuc = tt.goi.first.hinhThuc;
        }
        final sucChua = tt.phong.sucChua;
        if (widget.doiGioCho == null && sucChua != null && sucChua >= 2) {
          _soKhach = 2;
        }
      });
      await _napBan();
    } catch (e) {
      if (mounted) {
        setState(
          () => _loiTai = e is ApiException
              ? e.message
              : 'Không tải được phòng này',
        );
      }
    }
  }

  Future<void> _napBan() async {
    try {
      final ban = widget.args.theoHang
          ? await widget.api.lichBanTheoTin(
              widget.args.houseId!,
              _homNay,
              soNgay: 31,
            )
          : await widget.api.lichBan(widget.args.roomId, _homNay, soNgay: 31);
      if (!mounted) return;
      final cu = widget.doiGioCho;
      // Đổi giờ: khoảng của CHÍNH đơn này không phải "bận" — kéo 2h thành 3h
      // không được tự đụng mình. Server gộp khoảng liền nhau nên phải cắt ra.
      setState(
        () => _ban = cu?.nhan == null || cu?.tra == null
            ? ban
            : truKhoang(ban, cu!.nhan!, cu.tra!),
      );
    } catch (_) {
      // Không tải được lịch bận vẫn đặt được — server là chốt chặn cuối.
    }
    if (_gio != null && !_trong(_ngay, _gio!)) {
      setState(() => _gio = null);
    }
    _xemGia();
  }

  // ── Tính giờ ─────────────────────────────────────────────────────────────

  DateTime _lucNhan(DateTime ngay, int gio) =>
      DateTime(ngay.year, ngay.month, ngay.day, gio);

  /// Giờ trả — cùng luật `short_stay_service.gio_tra` của server.
  DateTime _tra(DateTime nhan) {
    final gioTra = _tt?.gioTra ?? 12;
    switch (_hinhThuc) {
      case 'theo_gio':
        return nhan.add(Duration(hours: _soGio));
      // Cộng NGÀY LỊCH qua hàm tạo, không cộng 24 giờ: máy ở múi giờ có đổi giờ
      // mùa hè sẽ lệch một tiếng.
      case 'qua_dem':
        final them = nhan.hour >= gioTra ? 1 : 0;
        return DateTime(nhan.year, nhan.month, nhan.day + them, gioTra);
      default:
        return DateTime(nhan.year, nhan.month, nhan.day + _soDem, gioTra);
    }
  }

  bool _trong(DateTime ngay, int gio) {
    final a = _lucNhan(ngay, gio);
    if (!a.isAfter(_bayGio)) return false;
    final b = _tra(a);
    return !_ban.any((k) => k.chong(a, b));
  }

  bool _ngayConGio(DateTime ngay) =>
      (_gioMo[_hinhThuc] ?? const []).any((g) => _trong(ngay, g));

  // ── Giá ───────────────────────────────────────────────────────────────────

  Future<void> _xemGia() async {
    final gio = _gio;
    final phien = ++_phien;
    if (gio == null || _tt == null) {
      setState(() {
        _baoGia = null;
        _loiBaoGia = null;
        _dangBaoGia = false;
      });
      return;
    }
    setState(() {
      _dangBaoGia = true;
      _loiBaoGia = null;
    });
    final nhan = _lucNhan(_ngay, gio);
    try {
      final cu = widget.doiGioCho;
      final BaoGiaPhong bg;
      if (cu != null) {
        bg = await widget.api.baoGiaDoiGio(cu.id, _hinhThuc, nhan, _tra(nhan));
      } else if (widget.args.theoHang) {
        bg = await widget.api.baoGiaTheoTin(
          widget.args.houseId!,
          _hinhThuc,
          nhan,
          _tra(nhan),
        );
      } else {
        bg = await widget.api.baoGia(
          widget.args.roomId,
          _hinhThuc,
          nhan,
          _tra(nhan),
        );
      }
      if (mounted && phien == _phien) setState(() => _baoGia = bg);
    } catch (e) {
      if (mounted && phien == _phien) {
        setState(() {
          _baoGia = null;
          _loiBaoGia = e is ApiException ? e.message : 'Không lấy được giá';
        });
      }
    } finally {
      if (mounted && phien == _phien) setState(() => _dangBaoGia = false);
    }
  }

  void _doi(VoidCallback thayDoi) {
    setState(() {
      thayDoi();
      // Giờ đang chọn không còn hợp với ngày / thời lượng mới → bỏ, không gửi mù.
      if (_gio != null && !_trong(_ngay, _gio!)) _gio = null;
      if (_gio != null && !(_gioMo[_hinhThuc] ?? const []).contains(_gio)) {
        _gio = null;
      }
    });
    _xemGia();
  }

  // ── Đặt ───────────────────────────────────────────────────────────────────

  void _bao(String s) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s)));
  }

  String? get _thieu {
    if (_gio == null) return 'Chọn giờ nhận phòng';
    if (_baoGia == null) return _loiBaoGia ?? 'Đang kiểm tra giá phòng…';
    if (_ten.text.trim().length < 2) return 'Nhập họ tên người nhận phòng';
    final so = _sdt.text.replaceAll(RegExp(r'\D'), '');
    if (so.length < 9 || so.length > 11) return 'Số điện thoại chưa đúng';
    return null;
  }

  /// Chế độ đổi giờ: chọn đúng giờ đang có thì không có gì để đổi.
  bool get _trungGioCu {
    final cu = widget.doiGioCho;
    final gio = _gio;
    if (cu == null || gio == null || cu.nhan == null) return false;
    final nhan = _lucNhan(_ngay, gio);
    return cu.hinhThuc == _hinhThuc && cu.nhan == nhan && cu.tra == _tra(nhan);
  }

  Future<void> _xacNhanDoiGio() async {
    final cu = widget.doiGioCho!;
    if (_gio == null) {
      _bao('Chọn giờ nhận phòng mới');
      return;
    }
    if (_trungGioCu) {
      _bao('Đây là giờ bạn đang đặt — chọn giờ khác');
      return;
    }
    final bg = _baoGia;
    if (bg == null) {
      _bao(_loiBaoGia ?? 'Đang kiểm tra giá phòng…');
      return;
    }
    setState(() => _dangDat = true);
    try {
      final moi = await widget.api.doiGio(cu.id, bg);
      if (!mounted) return;
      Navigator.of(context).pop(moi);
    } catch (e) {
      if (!mounted) return;
      _bao(e is ApiException ? e.message : 'Không đổi được giờ, thử lại nhé');
      if (e is ApiException && e.statusCode == 409) await _napBan();
    } finally {
      if (mounted) setState(() => _dangDat = false);
    }
  }

  Future<void> _dat() async {
    if (widget.doiGioCho != null) {
      await _xacNhanDoiGio();
      return;
    }
    final thieu = _thieu;
    if (thieu != null) {
      _bao(thieu);
      return;
    }
    if (!GuestGate.requireAuth(context, message: 'Đăng nhập để đặt phòng')) {
      return;
    }
    setState(() => _dangDat = true);
    try {
      final id = widget.args.theoHang
          ? await widget.api.datTheoTin(
              houseId: widget.args.houseId!,
              baoGia: _baoGia!,
              ten: _ten.text.trim(),
              sdt: _sdt.text.trim(),
              soKhach: _soKhach,
              ghiChu: _ghiChu.text.trim(),
            )
          : await widget.api.datPhong(
              baoGia: _baoGia!,
              ten: _ten.text.trim(),
              sdt: _sdt.text.trim(),
              soKhach: _soKhach,
              ghiChu: _ghiChu.text.trim(),
              houseId: widget.args.houseId,
            );
      final phieu = await widget.api.phieu(id);
      if (!mounted) return;
      await Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) =>
              PhieuDatPhongScreen(phieuBanDau: phieu, api: widget.api),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      _bao(e is ApiException ? e.message : 'Không đặt được phòng, thử lại nhé');
      // 409 = vừa có người giữ giờ này / giá vừa đổi → tải lại lịch và giá.
      if (e is ApiException && e.statusCode == 409) await _napBan();
    } finally {
      if (mounted) setState(() => _dangDat = false);
    }
  }

  void _nhanSale() {
    final sale = _tt?.sale;
    if (sale == null) return;
    if (!GuestGate.requireAuth(context, message: 'Đăng nhập để nhắn sale')) {
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ChatScreen(
          peerId: sale.id,
          peerName: sale.ten,
          peerAvatar: sale.anh ?? '',
          houseId: _tt?.phong.houseId,
        ),
      ),
    );
  }

  // ── Giao diện ────────────────────────────────────────────────────────────

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
        title: Text(
          widget.doiGioCho == null ? 'Đặt phòng' : 'Đổi giờ đặt phòng',
          style: HD.bodyBold(size: 16),
        ),
      ),
      body: tt == null
          ? Center(
              child: _loiTai == null
                  ? const CircularProgressIndicator(color: HD.accent)
                  : Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        _loiTai!,
                        textAlign: TextAlign.center,
                        style: HD.body(color: HD.inkMuted),
                      ),
                    ),
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
                      _thePhong(tt),
                      if (tt.datTheoHang) ...[
                        const SizedBox(height: 12),
                        _theHang(tt),
                      ],
                      if (!tt.nhanDat) ...[
                        const SizedBox(height: 12),
                        _canhBao(
                          'Phòng này chưa có sale phụ trách nên chưa nhận đặt '
                          'trực tuyến.',
                        ),
                      ],
                      const SizedBox(height: 20),
                      _buocGoi(tt),
                      const SizedBox(height: 20),
                      _buocNgay(),
                      const SizedBox(height: 20),
                      _buocGio(tt),
                      if (widget.doiGioCho == null) ...[
                        const SizedBox(height: 20),
                        _buocKhach(tt),
                      ],
                      if (tt.sale != null && widget.doiGioCho == null) ...[
                        const SizedBox(height: 20),
                        TheSaleDon(
                          sale: tt.sale!,
                          tieuDe: 'SALE PHỤ TRÁCH PHÒNG',
                          thanhTich: tt.soDonXong > 0
                              ? '${tt.soDonXong} lượt khách đã ở'
                              : null,
                          nutLienHe: _nutNhanSale(),
                        ),
                      ],
                      const SizedBox(height: 20),
                      _theGia(tt),
                    ],
                  ),
                ),
              ],
            ),
      bottomNavigationBar: tt == null ? null : _thanhDuoi(tt),
    );
  }

  Widget _dai(ThongTinDatPhong tt) => Container(
    color: const Color(0xFFF2F3FF),
    padding: const EdgeInsets.fromLTRB(16, 6, 16, 8),
    child: Row(
      children: [
        const Icon(Icons.bolt, size: 16, color: HD.positive),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            widget.doiGioCho == null
                ? 'Đặt ngay · không cần đi xem phòng'
                : 'Đổi giờ xong, đơn chờ sale xác nhận lại',
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
            'TRẢ TIỀN TẠI QUẦY',
            style: HD.bodyBold(size: 10, color: HD.inkSoft),
          ),
        ),
      ],
    ),
  );

  Widget _thePhong(ThongTinDatPhong tt) {
    final p = tt.phong;
    final goi = tt.goiCua(_hinhThuc);
    // Đặt theo HẠNG thì KHÔNG hiện mã phòng: phòng chỉ là phòng đại diện,
    // lễ tân gán số thật lúc nhận — in "P.203" lên đây là hứa một con số
    // app không giữ được.
    final theoHang = tt.datTheoHang;
    return TheCanMini(
      tin: TomTatCan(
        tieuDe: theoHang ? (tt.tenHang.isEmpty ? p.hang : tt.tenHang)
            : '${p.hang} · ${p.ma}',
        anh: p.anh,
        dienTich: p.dienTich,
        diaChi: [p.toa, p.diaChi].where((x) => x.isNotEmpty).join(' · '),
        gia: goi?.donGia ?? tt.giaThapNhat,
        donVi: goi?.donVi ?? '',
      ),
      nhanPhai: tt.nhanDat
          ? (p.sucChua == null ? 'Nhận đặt' : 'Tối đa ${p.sucChua} khách')
          : null,
    );
  }

  /// Hạng đang đặt: còn mấy phòng + lời nhắc lễ tân mới gán số phòng.
  Widget _theHang(ThongTinDatPhong tt) {
    final so = tt.soPhongCuaHang;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: HD.hairline),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.meeting_room_outlined, size: 18, color: HD.accent),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  so > 0 ? 'Hạng phòng · $so phòng cùng loại' : 'Hạng phòng',
                  style: HD.bodyBold(size: 13),
                ),
                const SizedBox(height: 2),
                Text(
                  tt.conTrongBayGio
                      ? 'Bạn đặt hạng phòng — số phòng cụ thể được xếp khi '
                            'nhận phòng.'
                      : 'Hạng này đang kín trong hôm nay — chọn ngày khác thì '
                            'vẫn đặt được.',
                  style: HD.body(size: 12, color: HD.inkMuted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _canhBao(String s) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: HD.warningTint,
      borderRadius: BorderRadius.circular(16),
    ),
    child: Row(
      children: [
        const Icon(Icons.info_outline, color: HD.svcAmber, size: 18),
        const SizedBox(width: 8),
        Expanded(
          child: Text(s, style: HD.body(size: 13, color: HD.ink)),
        ),
      ],
    ),
  );

  // ── Bước 1: hình thức ────────────────────────────────────────────────────

  Widget _buocGoi(ThongTinDatPhong tt) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _tieuDeBuoc(1, 'Hình thức lưu trú'),
      const SizedBox(height: 10),
      for (final g in tt.goi) ...[_theGoi(g), const SizedBox(height: 10)],
    ],
  );

  Widget _theGoi(GoiLuuTru g) {
    final chon = g.hinhThuc == _hinhThuc;
    return InkWell(
      key: Key('dat-phong-goi-${g.hinhThuc}'),
      onTap: () => _doi(() => _hinhThuc = g.hinhThuc),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: chon ? HD.accent.withValues(alpha: 0.5) : Colors.transparent,
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
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: chon ? HD.accent : const Color(0xFFEAEDFF),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                _iconGoi[g.hinhThuc] ?? Icons.bed_outlined,
                size: 22,
                color: chon ? Colors.white : HD.inkSoft,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(g.nhan, style: HD.bodyBold(size: 15, color: HD.ink)),
                  const SizedBox(height: 2),
                  Text(
                    _moTaGoi[g.hinhThuc] ?? g.quyTac,
                    style: HD.body(size: 12, color: HD.inkSoft),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: PriceFormat.full(g.donGia),
                    style: HD.bodyBold(size: 15, color: HD.accent),
                  ),
                  TextSpan(
                    text: '/${g.donVi}',
                    style: HD.body(size: 11, color: HD.inkMuted),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Bước 2: ngày nhận ────────────────────────────────────────────────────

  Widget _buocNgay() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _tieuDeBuoc(
        2,
        'Ngày nhận phòng',
        phai: Text(
          'Tháng ${_hai(_ngay.month)}',
          style: HD.bodyBold(size: 12, color: HD.accent),
        ),
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
            final kin = !_ngayConGio(d);
            final tren = i == 0
                ? 'Hôm nay'
                : i == 1
                ? 'Ngày mai'
                : _thuNgan(d.weekday);
            return InkWell(
              key: Key('dat-phong-ngay-${d.day}'),
              onTap: () => _doi(() => _ngay = d),
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
                      tren,
                      style: HD.bodyBold(
                        size: 10,
                        color: chon
                            ? Colors.white.withValues(alpha: 0.9)
                            : HD.inkMuted,
                      ),
                    ),
                    Text(
                      '${d.day}',
                      style: HD.bodyBold(
                        size: 22,
                        color: chon
                            ? Colors.white
                            : (kin ? HD.hairlineStrong : HD.ink),
                      ),
                    ),
                    Text(
                      kin ? 'Kín phòng' : 'Tháng ${d.month}',
                      style: HD.body(
                        size: 10,
                        color: chon
                            ? Colors.white.withValues(alpha: 0.9)
                            : (kin ? HD.accent : HD.inkMuted),
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

  // ── Bước 3: giờ nhận + thời lượng ────────────────────────────────────────

  Widget _buocGio(ThongTinDatPhong tt) {
    final ds = _gioMo[_hinhThuc] ?? const <int>[];
    final sang = ds.where((g) => g < 12).toList();
    final chieu = ds.where((g) => g >= 12 && g < 18).toList();
    final toi = ds.where((g) => g >= 18).toList();
    final gio = _gio;
    return _The(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _tieuDeBuoc(3, 'Giờ nhận phòng'),
          const SizedBox(height: 10),
          if (!_ngayConGio(_ngay))
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Text(
                'Ngày ${_ngay.day}/${_ngay.month} không còn giờ trống cho '
                '${tt.goiCua(_hinhThuc)?.nhan.toLowerCase() ?? 'hình thức này'}. '
                'Chọn ngày khác nhé.',
                key: const Key('dat-phong-het-gio'),
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
          if (_hinhThuc != 'qua_dem') ...[
            const SizedBox(height: 6),
            _demThoiLuong(),
          ],
          const SizedBox(height: 12),
          Container(
            key: const Key('dat-phong-tom-tat-gio'),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF2F3FF),
              borderRadius: BorderRadius.circular(16),
            ),
            child: gio == null
                ? Row(
                    children: [
                      const Icon(
                        Icons.info_outline,
                        size: 18,
                        color: HD.accent,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Giờ đã có khách được gạch sẵn — chọn giờ còn trống.',
                          style: HD.body(size: 12, color: HD.inkSoft),
                        ),
                      ),
                    ],
                  )
                : Row(
                    children: [
                      Expanded(
                        child: _moc(
                          'NHẬN PHÒNG',
                          _lucNhan(_ngay, gio),
                          Icons.login,
                        ),
                      ),
                      const Icon(
                        Icons.arrow_forward,
                        size: 16,
                        color: HD.inkMuted,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _moc(
                          'TRẢ PHÒNG',
                          _tra(_lucNhan(_ngay, gio)),
                          Icons.logout,
                        ),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _moc(String nhan, DateTime t, IconData icon) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          Icon(icon, size: 13, color: HD.inkMuted),
          const SizedBox(width: 4),
          Text(nhan, style: HD.bodyBold(size: 10, color: HD.inkMuted)),
        ],
      ),
      const SizedBox(height: 2),
      Text(
        '${_hai(t.hour)}:${_hai(t.minute)}',
        style: HD.bodyBold(size: 18, color: HD.ink),
      ),
      Text(
        '${_thuNgan(t.weekday)}, ${_hai(t.day)}/${_hai(t.month)}',
        style: HD.body(size: 11, color: HD.accent),
      ),
    ],
  );

  Widget _nhomGio(String ten, IconData icon, Color mau, List<int> ds) =>
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
              crossAxisCount: 4,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              childAspectRatio: 2.1,
              children: [for (final g in ds) _oGio(g)],
            ),
          ],
        ),
      );

  Widget _oGio(int g) {
    final nhan = '${_hai(g)}:00';
    if (!_trong(_ngay, g)) {
      return Container(
        key: Key('dat-phong-gio-$nhan'),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: const Color(0xFFEAEDFF),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          nhan,
          style: HD
              .body(size: 13, color: HD.inkMuted.withValues(alpha: 0.45))
              .copyWith(decoration: TextDecoration.lineThrough),
        ),
      );
    }
    final chon = g == _gio;
    return InkWell(
      key: Key('dat-phong-gio-$nhan'),
      onTap: () => _doi(() => _gio = g),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: chon ? HD.accent : const Color(0xFFF2F3FF),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          nhan,
          style: HD.bodyBold(size: 13, color: chon ? Colors.white : HD.ink),
        ),
      ),
    );
  }

  Widget _demThoiLuong() {
    final theoGio = _hinhThuc == 'theo_gio';
    final so = theoGio ? _soGio : _soDem;
    final toiDa = theoGio ? 24 : 30;
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                theoGio ? 'Số giờ ở' : 'Số đêm ở',
                style: HD.bodyBold(size: 12.5, color: HD.ink),
              ),
              Text(
                theoGio ? 'Từ 1 đến 24 giờ' : 'Từ 1 đến 30 đêm',
                style: HD.body(size: 11.5, color: HD.inkMuted),
              ),
            ],
          ),
        ),
        _dem(
          khoaBot: 'dat-phong-bot-thoi-luong',
          khoaThem: 'dat-phong-them-thoi-luong',
          khoaSo: 'dat-phong-thoi-luong',
          so: so,
          nhan: theoGio ? '$so giờ' : '$so đêm',
          onBot: so > 1
              ? () => _doi(() => theoGio ? _soGio-- : _soDem--)
              : null,
          onThem: so < toiDa
              ? () => _doi(() => theoGio ? _soGio++ : _soDem++)
              : null,
        ),
      ],
    );
  }

  // ── Bước 4: người nhận phòng ─────────────────────────────────────────────

  Widget _buocKhach(ThongTinDatPhong tt) {
    final toiDa = tt.phong.sucChua ?? 10;
    return _The(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _tieuDeBuoc(4, 'Người nhận phòng'),
          const SizedBox(height: 12),
          _nhan('Họ và tên (như trên CCCD)'),
          _o(
            khoa: const Key('dat-phong-ten'),
            c: _ten,
            icon: Icons.badge_outlined,
            goiY: 'Nguyễn Văn A',
          ),
          const SizedBox(height: 12),
          _nhan('Số điện thoại (sale gọi xác nhận)'),
          _o(
            khoa: const Key('dat-phong-sdt'),
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
                      'Số khách ở',
                      style: HD.bodyBold(size: 12.5, color: HD.ink),
                    ),
                    Text(
                      'Phòng này tối đa $toiDa khách',
                      style: HD.body(size: 11.5, color: HD.inkMuted),
                    ),
                  ],
                ),
              ),
              _dem(
                khoaBot: 'dat-phong-bot-khach',
                khoaThem: 'dat-phong-them-khach',
                khoaSo: 'dat-phong-so-khach',
                so: _soKhach,
                nhan: '$_soKhach',
                onBot: _soKhach > 1 ? () => setState(() => _soKhach--) : null,
                onThem: _soKhach < toiDa
                    ? () => setState(() => _soKhach++)
                    : null,
              ),
            ],
          ),
          const SizedBox(height: 12),
          _nhan('Yêu cầu thêm'),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFF2F3FF),
              borderRadius: BorderRadius.circular(16),
            ),
            child: TextField(
              key: const Key('dat-phong-ghi-chu'),
              controller: _ghiChu,
              maxLines: 2,
              maxLength: 300,
              style: HD.body(size: 14),
              decoration: InputDecoration(
                border: InputBorder.none,
                // Theme app vẽ viền ô nhập; ô này đã có nền bo góc riêng.
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                filled: false,
                counterText: '',
                hintText:
                    'Ví dụ: nhận phòng muộn, cần thêm gối, phòng tầng cao…',
                hintStyle: HD.body(size: 13, color: HD.inkMuted),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _nutNhanSale() => SizedBox(
    height: 44,
    child: OutlinedButton.icon(
      key: const Key('dat-phong-nhan-sale'),
      onPressed: _nhanSale,
      icon: const Icon(Icons.chat_bubble_outline, size: 18),
      label: const Text('Cần hỏi trước? Nhắn sale'),
      style: OutlinedButton.styleFrom(
        foregroundColor: HD.accent,
        side: const BorderSide(color: HD.accent),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        textStyle: HD.bodyBold(size: 13),
      ),
    ),
  );

  // ── Giá ───────────────────────────────────────────────────────────────────

  Widget _theGia(ThongTinDatPhong tt) {
    final bg = _baoGia;
    final goi = tt.goiCua(_hinhThuc);
    return _The(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(
                Icons.receipt_long_outlined,
                size: 18,
                color: HD.accent,
              ),
              const SizedBox(width: 6),
              Text('Chi tiết giá', style: HD.bodyBold(size: 16)),
            ],
          ),
          const SizedBox(height: 10),
          if (_gio == null)
            Text(
              'Chọn giờ nhận phòng để xem tổng tiền.',
              style: HD.body(size: 13, color: HD.inkMuted),
            )
          else if (_dangBaoGia)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          else if (bg == null)
            Text(
              _loiBaoGia ?? 'Không lấy được giá',
              key: const Key('dat-phong-loi-gia'),
              style: HD.body(size: 13, color: HD.accent),
            )
          else ...[
            _dongGia(
              '${PriceFormat.full(bg.donGia)} × ${bg.soLuong} ${bg.donVi}',
              PriceFormat.full(bg.donGia * bg.soLuong),
            ),
            _dongGia(
              'Phụ phí',
              bg.phuPhi == 0 ? 'Miễn phí' : PriceFormat.full(bg.phuPhi),
            ),
            const Divider(height: 18),
            Row(
              children: [
                Expanded(
                  child: Text('Tổng cộng', style: HD.bodyBold(size: 15)),
                ),
                Text(
                  PriceFormat.full(bg.tong),
                  key: const Key('dat-phong-tong'),
                  style: HD.bodyBold(size: 20, color: HD.accent),
                ),
              ],
            ),
          ],
          const SizedBox(height: 10),
          if (bg?.huyMienPhiDen != null)
            _dongChinhSach(
              Icons.event_available_outlined,
              'Huỷ miễn phí đến ${_hai(bg!.huyMienPhiDen!.hour)}:'
              '${_hai(bg.huyMienPhiDen!.minute)} · '
              '${_thuNgan(bg.huyMienPhiDen!.weekday)} '
              '${_hai(bg.huyMienPhiDen!.day)}/${_hai(bg.huyMienPhiDen!.month)}',
            )
          else if (goi != null && goi.huyTruocGio > 0)
            _dongChinhSach(
              Icons.event_available_outlined,
              'Huỷ miễn phí trước giờ nhận phòng ${goi.huyTruocGio} giờ',
            ),
          for (final s in tt.chinhSach.take(2))
            _dongChinhSach(Icons.check_circle_outline, s),
        ],
      ),
    );
  }

  Widget _dongGia(String trai, String phai) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(
      children: [
        Expanded(
          child: Text(trai, style: HD.body(size: 13, color: HD.inkSoft)),
        ),
        Text(phai, style: HD.bodyBold(size: 13, color: HD.ink)),
      ],
    ),
  );

  Widget _dongChinhSach(IconData icon, String s) => Padding(
    padding: const EdgeInsets.only(top: 4),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 15, color: HD.positive),
        const SizedBox(width: 6),
        Expanded(
          child: Text(s, style: HD.body(size: 12, color: HD.inkSoft)),
        ),
      ],
    ),
  );

  // ── Thanh dưới ────────────────────────────────────────────────────────────

  Widget _thanhDuoi(ThongTinDatPhong tt) {
    final bg = _baoGia;
    final duoc = (tt.nhanDat || widget.doiGioCho != null) && !_dangDat;
    return Container(
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
        child: Row(
          children: [
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    bg == null
                        ? 'Chưa chọn giờ'
                        : '${tt.goiCua(_hinhThuc)?.nhan ?? ''} · ${bg.soLuong} ${bg.donVi}',
                    style: HD.body(size: 11.5, color: HD.inkMuted),
                  ),
                  Text(
                    bg == null ? '—' : PriceFormat.full(bg.tong),
                    style: HD.bodyBold(size: 20, color: HD.ink),
                  ),
                ],
              ),
            ),
            SizedBox(
              height: 52,
              child: FilledButton.icon(
                key: const Key('dat-phong-xac-nhan'),
                onPressed: duoc ? _dat : null,
                icon: _dangDat
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.bed_outlined, size: 20),
                label: Text(
                  widget.doiGioCho != null
                      ? (_trungGioCu ? 'Giờ hiện tại' : 'Xác nhận đổi giờ')
                      : (tt.nhanDat ? 'Đặt phòng ngay' : 'Chưa nhận đặt'),
                  style: HD.bodyBold(size: 16, color: Colors.white),
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: HD.accent,
                  padding: const EdgeInsets.symmetric(horizontal: 22),
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

  // ── Mảnh nhỏ ──────────────────────────────────────────────────────────────

  Widget _tieuDeBuoc(int so, String ten, {Widget? phai}) => Row(
    children: [
      Container(
        width: 24,
        height: 24,
        alignment: Alignment.center,
        decoration: const BoxDecoration(
          color: HD.accentDeep,
          shape: BoxShape.circle,
        ),
        child: Text('$so', style: HD.bodyBold(size: 11, color: Colors.white)),
      ),
      const SizedBox(width: 8),
      Expanded(child: Text(ten, style: HD.bodyBold(size: 17))),
      if (phai != null) phai,
    ],
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

  Widget _dem({
    required String khoaBot,
    required String khoaThem,
    required String khoaSo,
    required int so,
    required String nhan,
    VoidCallback? onBot,
    VoidCallback? onThem,
  }) => Container(
    padding: const EdgeInsets.all(5),
    decoration: BoxDecoration(
      color: const Color(0xFFF2F3FF),
      borderRadius: BorderRadius.circular(16),
    ),
    child: Row(
      children: [
        _nutDem(Key(khoaBot), Icons.remove, onBot),
        SizedBox(
          width: 58,
          child: Text(
            nhan,
            key: Key(khoaSo),
            textAlign: TextAlign.center,
            style: HD.bodyBold(size: 15),
          ),
        ),
        _nutDem(Key(khoaThem), Icons.add, onThem),
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
}

String _hai(int n) => n.toString().padLeft(2, '0');

String _thuNgan(int w) =>
    const ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN'][(w - 1).clamp(0, 6)];

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

/// Cắt khoảng [a, b) ra khỏi danh sách khoảng bận (khoảng của chính đơn đang đổi).
List<KhoangBan> truKhoang(List<KhoangBan> ds, DateTime a, DateTime b) => [
  for (final k in ds) ...[
    if (!k.chong(a, b))
      k
    else ...[
      if (k.tu.isBefore(a)) KhoangBan(k.tu, a),
      if (b.isBefore(k.den)) KhoangBan(b, k.den),
    ],
  ],
];
