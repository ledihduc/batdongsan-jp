import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:house_booking/core/utils/bo_dau.dart';
import 'package:house_booking/core/widgets/ds.dart';
import 'package:house_booking/data/services/dat_phong_api.dart';
import 'package:house_booking/data/services/lich_xem_api.dart';
import 'package:house_booking/data/services/quan_ly_api.dart';
import 'package:house_booking/features/auth/guest_gate.dart';
import 'package:house_booking/features/guest/booking/phieu_dat_phong_screen.dart';
import 'package:house_booking/features/guest/booking/phieu_hen_xem_screen.dart';
import 'package:house_booking/features/guest/quan_ly/lich_xem_nha_screen.dart';
import 'package:house_booking/features/guest/quan_ly/hop_dong_khach_sheet.dart';
import 'package:house_booking/features/guest/quan_ly/lich_sap_toi_screen.dart';
import 'package:house_booking/features/guest/quan_ly/phong_dang_thue_screen.dart';
import 'package:house_booking/features/guest/quan_ly/xac_nhan_chot_thue_screen.dart';
import 'package:house_booking/features/guest/quan_ly/widgets/lich_sap_toi.dart';
import 'package:house_booking/features/guest/quan_ly/widgets/quan_ly_header.dart';
import 'package:house_booking/features/guest/quan_ly/widgets/the_dem_quan_ly.dart';
import 'package:house_booking/features/guest/quan_ly/widgets/the_muc_quan_ly.dart';
import 'package:house_booking/features/host/appointments/host_appointments_screen.dart';
import 'package:house_booking/features/host/ngan_han/ca_thue/chi_tiet_ca_thue_screen.dart';
import 'package:house_booking/features/notifications/notifications_screen.dart';
import 'package:house_booking/providers/auth_provider.dart';
import 'package:house_booking/providers/notification_provider.dart';

/// "QUẢN LÝ" — tab thứ tư của tài khoản sale/khách, thay cho "Đã đặt"
/// (18/09/2026). Route: tab trong `GuestShell`. API: `GET /api/quan-ly`.
///
///     [đầu đỏ: chào · logo "Quản lý" · chuông]
///     [ Của tôi | Khách thuê ]          ← hai góc nhìn, cùng một khung
///     Đã đặt · Đang đặt · Đang ở · Sắp tới   ← bấm = lọc danh sách / mở lịch
///     Lịch sắp tới (3 mốc gần nhất · Xem tất cả)
///     Danh sách quản lý  [tìm kiếm]  Tất cả · Đã đặt · Đang đặt · Đang ở · Lịch sử
///
/// Bấm một mục mở ĐÚNG màn của góc nhìn đó — không dùng chung:
///   * Của tôi → phiếu đặt phòng / phiếu hẹn của KHÁCH (có đổi giờ, sửa, huỷ),
///     phòng đang thuê → [PhongDangThueScreen] (gửi chỉ số điện nước).
///   * Khách thuê → màn PHÍA BÁN: ca thuê ([ChiTietCaThueScreen] — duyệt, nhận,
///     trả phòng), lịch hẹn ([HostAppointmentsScreen] — xác nhận, bận·đổi giờ,
///     hẹn chốt), hợp đồng → [HopDongKhachSheet] (tóm tắt).
///   Phiếu của khách mở bằng tài khoản sale sẽ bày nút "Huỷ lịch" của khách —
///   bấm là gọi nhầm endpoint. Nên hai góc đi hai đường.
///
/// "Lịch sử" không có trong ảnh mẫu nhưng được giữ làm chip cuối: trang Đã đặt
/// cũ có tab Lịch sử, bỏ đi là người dùng mất đường xem lại đơn đã xong.
class QuanLyScreen extends StatefulWidget {
  const QuanLyScreen({
    super.key,
    this.api = const QuanLyApi(),
    this.moMuc,
    this.bayGio,
    this.cheDoSale = false,
    this.cheDoKhachThue = false,
  });

  final QuanLyApi api;

  /// Chỉ để test: thay việc điều hướng thật khi bấm một mục (màn thật gọi API
  /// thật, test không có mạng).
  final Future<void> Function(GocQuanLy goc, MucQuanLy m)? moMuc;

  /// Chỉ để test ghim "hôm nay" ở lịch.
  final DateTime? bayGio;

  /// Sale chỉ quản lý hành trình khách hàng trên các tin mình phụ trách.
  /// Không hiển thị góc "Của tôi" và không dùng giao diện vận hành của chủ nhà.
  final bool cheDoSale;

  /// Màn hành trình thuê dành riêng cho khách; chủ nhà/sale dùng workspace khác.
  final bool cheDoKhachThue;

  @override
  State<QuanLyScreen> createState() => _QuanLyScreenState();
}

const _nhanLoc = <String, String>{
  'tat_ca': 'Tất cả',
  NhomQuanLy.daDat: 'Đã đặt',
  NhomQuanLy.dangDat: 'Đang đặt',
  NhomQuanLy.dangO: 'Đang ở',
  NhomQuanLy.lichSu: 'Lịch sử',
};

class _QuanLyScreenState extends State<QuanLyScreen> {
  late GocQuanLy _goc;

  /// Mỗi góc nhớ dữ liệu riêng: đổi qua lại không phải tải lại từ đầu, và
  /// không bao giờ vẽ dữ liệu góc này dưới nhãn của góc kia.
  final Map<GocQuanLy, TongHopQuanLy> _duLieu = {};
  final Set<GocQuanLy> _dangTai = {};
  final Map<GocQuanLy, String> _loi = {};

  String _loc = 'tat_ca';
  final _tim = TextEditingController();
  final _cuon = ScrollController();
  final _moDanhSach = GlobalKey();

  /// Tài khoản mà dữ liệu đang giữ thuộc về. Tab này sống suốt phiên trong
  /// shell: đăng xuất rồi đăng nhập tài khoản KHÁC trên cùng máy mà không xoá
  /// cache là người sau nhìn thấy đơn, lịch hẹn, tên khách của người trước.
  int? _uid;

  @override
  void initState() {
    super.initState();
    _goc = widget.cheDoSale ? GocQuanLy.khachThue : GocQuanLy.cuaToi;
  }

  /// Đổi tài khoản (kể cả từ "chưa đăng nhập" sang đăng nhập): bỏ sạch dữ liệu
  /// cũ rồi tải lại. Gọi sau khung hình — không `setState` giữa lúc build.
  void _theoTaiKhoan(int? uid) {
    if (uid == _uid) return;
    _uid = uid;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || uid != _uid) return;
      setState(() {
        _duLieu.clear();
        _loi.clear();
        _goc = widget.cheDoSale ? GocQuanLy.khachThue : GocQuanLy.cuaToi;
        _loc = 'tat_ca';
        _tim.clear();
      });
      if (uid != null) _nap(_goc);
    });
  }

  @override
  void dispose() {
    _tim.dispose();
    _cuon.dispose();
    super.dispose();
  }

  Future<void> _nap(GocQuanLy goc) async {
    final uid = _uid;
    setState(() {
      _dangTai.add(goc);
      _loi.remove(goc);
    });
    try {
      final d = await widget.api.tongHop(goc);
      // Kết quả về muộn của tài khoản CŨ (đổi tài khoản giữa chừng) thì vứt.
      if (!mounted || uid != _uid) return;
      setState(() => _duLieu[goc] = d);
    } catch (_) {
      if (!mounted || uid != _uid) return;
      setState(() => _loi[goc] = 'Chưa tải được. Kéo xuống để thử lại.');
    } finally {
      if (mounted) setState(() => _dangTai.remove(goc));
    }
  }

  void _doiGoc(GocQuanLy g) {
    setState(() {
      _goc = g;
      // Bộ lọc + từ khoá của góc kia không có nghĩa ở góc này.
      _loc = 'tat_ca';
      _tim.clear();
    });
    if (!_duLieu.containsKey(g)) _nap(g);
  }

  // ── Điều hướng ─────────────────────────────────────────────────────────────

  Future<void> _mo(MucQuanLy m) async {
    final goc = _goc;
    if (widget.moMuc != null) {
      await widget.moMuc!(goc, m);
    } else if (goc == GocQuanLy.khachThue && m.laThueDaiHan) {
      // Bảng tóm tắt, KHÔNG phải [PhongDangThueScreen]: màn đó tải hợp đồng
      // CỦA CHÍNH người đang xem (`/api/guest/dang-thue`), nên sale / chủ nhà
      // mở vào là luôn ra "Hợp đồng này không còn hiệu lực" (lỗi đã lọt ra,
      // gỡ 19/09/2026). Có màn hợp đồng phía bên cho thuê thì trỏ sang đó.
      await showModalBottomSheet<void>(
        context: context,
        builder: (_) => HopDongKhachSheet(m: m),
      );
      return; // chỉ xem, không có gì thay đổi để tải lại
    } else {
      final Widget? man = switch ((goc, m.loai)) {
        (GocQuanLy.cuaToi, 'dat_phong') => PhieuDatPhongScreen(
          reservationId: m.id,
          api: const DatPhongApi(),
        ),
        (GocQuanLy.cuaToi, 'xem_nha' || 'hen_chot') => PhieuHenXemScreen(
          appointmentId: m.id,
          api: const LichXemApi(),
        ),
        (GocQuanLy.cuaToi, 'thue_dai_han') => PhongDangThueScreen(
          contractId: m.id,
        ),
        (GocQuanLy.cuaToi, 'de_nghi_thue') => XacNhanChotThueScreen(
          dealId: m.id,
        ),
        (GocQuanLy.khachThue, 'dat_phong') => ChiTietCaThueScreen(
          reservationId: m.id,
        ),
        (GocQuanLy.khachThue, 'xem_nha' || 'hen_chot') =>
          const HostAppointmentsScreen(),
        _ => null,
      };
      if (man == null) return;
      await Navigator.push(context, MaterialPageRoute(builder: (_) => man));
    }
    // Trong màn đích người dùng có thể đã duyệt / huỷ / đổi giờ.
    if (mounted) _nap(goc);
  }

  void _moSuKien(SuKienQuanLy e) {
    final m = _duLieu[_goc]?.mucCua(e);
    if (m != null) _mo(m);
  }

  void _moLich() {
    final d = _duLieu[_goc];
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (ctx) => LichSapToiScreen(
          lich: d?.lich ?? const [],
          goc: _goc,
          bayGio: widget.bayGio,
          onChon: (e) {
            Navigator.pop(ctx);
            _moSuKien(e);
          },
        ),
      ),
    );
  }

  void _chonThe(String khoa) {
    if (khoa == kTheSapToi) {
      _moLich();
      return;
    }
    // Bấm lại đúng thẻ đang lọc thì bỏ lọc — không thì phải tìm chip "Tất cả".
    setState(() => _loc = _loc == khoa ? 'tat_ca' : khoa);
    final ctx = _moDanhSach.currentContext;
    if (ctx != null) {
      Scrollable.ensureVisible(
        ctx,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  // ── Lọc ────────────────────────────────────────────────────────────────────

  List<MucQuanLy> _locDanhSach(List<MucQuanLy> ds) {
    final tu = boDau(_tim.text.trim());
    return [
      for (final m in ds)
        if ((_loc == 'tat_ca' ? m.nhom != NhomQuanLy.lichSu : m.nhom == _loc) &&
            (tu.isEmpty ||
                boDau(
                  '${m.tieuDe} ${m.diaChi} ${m.khach ?? ''} ${m.ma} ${kieuKenh(m.kenh)?.$1 ?? ''}',
                ).contains(tu)))
          m,
    ];
  }

  // ── Dựng ───────────────────────────────────────────────────────────────────

  int _soChuaDoc(BuildContext context) {
    // Màn vẫn phải dựng được khi cây không có NotificationProvider (widget test,
    // màn nhúng) — thiếu chấm đỏ còn hơn vỡ màn.
    try {
      return context.watch<NotificationProvider>().unread;
    } on ProviderNotFoundException {
      return 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().currentUser;
    _theoTaiKhoan(user?.id);
    // Chưa đăng nhập: API trả 401, nên hiện lời mời thay cho "Chưa tải được /
    // Thử lại" — bấm Thử lại bao nhiêu cũng không bao giờ tải được.
    if (user == null) {
      return const GuestTabPlaceholder(
        title: 'Quản lý',
        icon: Icons.assignment_outlined,
        message:
            'Đăng nhập để theo dõi đơn đặt phòng, lịch hẹn xem nhà, phòng '
            'bạn đang thuê — và việc của khách trên tin bạn phụ trách.',
      );
    }
    final d = _duLieu[_goc];
    final dangTai = _dangTai.contains(_goc);
    final loi = _loi[_goc];

    return Scaffold(
      backgroundColor: HD.paper,
      body: RefreshIndicator(
        onRefresh: () => _nap(_goc),
        child: ListView(
          controller: _cuon,
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.zero,
          children: [
            if (widget.cheDoSale)
              SaleQuanLyHeader(
                ten: user.name,
                anhDaiDien: user.avatarPath,
                soChuaDoc: _soChuaDoc(context),
                onThongBao: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const NotificationsScreen(),
                  ),
                ),
              )
            else
              QuanLyHeader(
                goc: _goc,
                onDoiGoc: _doiGoc,
                ten: user.name,
                anhDaiDien: user.avatarPath,
                soChuaDoc: _soChuaDoc(context),
                onThongBao: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const NotificationsScreen(),
                  ),
                ),
              ),
            if (widget.cheDoKhachThue)
              ..._khachLanding(d)
            else ...[
              const SizedBox(height: HD.s16),
              if (d == null && dangTai)
                const Padding(
                  padding: EdgeInsets.only(top: HD.s40),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (d == null)
                _loiTai(loi)
              else ...[
                if (loi != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      HD.s16,
                      0,
                      HD.s16,
                      HD.s8,
                    ),
                    child: Text(
                      loi,
                      style: HD.body(size: 13, color: HD.negative),
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: HD.s16),
                  child: TheDemQuanLy(
                    dem: d.dem,
                    dangChon: _loc == 'tat_ca' ? null : _loc,
                    onChon: _chonThe,
                  ),
                ),
                const SizedBox(height: HD.s16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: HD.s16),
                  child: KhoiLichSapToi(
                    lich: d.lich,
                    onChon: _moSuKien,
                    onXemTatCa: _moLich,
                    loiRong: _goc == GocQuanLy.cuaToi
                        ? 'Chưa có lịch nào sắp tới.'
                        : 'Chưa có khách nào hẹn sắp tới.',
                  ),
                ),
                const SizedBox(height: HD.s20),
                _dauDanhSach(),
                const SizedBox(height: HD.s12),
                _chipLoc(),
                const SizedBox(height: HD.s12),
                _danhSach(d),
                const SizedBox(height: HD.s32),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Widget _loiTai(String? loi) => Padding(
    padding: const EdgeInsets.all(HD.s32),
    child: Column(
      children: [
        Text(
          loi ?? 'Chưa tải được.',
          textAlign: TextAlign.center,
          style: HD.body(size: 14, color: HD.inkMuted),
        ),
        const SizedBox(height: HD.s12),
        OutlinedButton(
          onPressed: () => _nap(_goc),
          child: const Text('Thử lại'),
        ),
      ],
    ),
  );

  List<Widget> _khachLanding(TongHopQuanLy? d) {
    if (d == null && _dangTai.contains(_goc)) {
      return const [
        SizedBox(height: 120),
        Center(child: CircularProgressIndicator()),
      ];
    }
    if (d == null) return [_loiTai(_loi[_goc])];
    final chot = d.danhSach.where((m) => m.laDeNghiThue).toList();
    final thue = d.danhSach.where((m) => m.laThueDaiHan).toList();
    final viec = d.danhSach.where((m) => m.canXuLy).take(3).toList();
    final demLich = d.dem.dangDat + d.dem.daDat;
    void moLich() => Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => LichXemNhaScreen(api: widget.api)),
    );
    return [
      Padding(
        padding: const EdgeInsets.fromLTRB(HD.s16, HD.s8, HD.s16, 0),
        child: Row(
          children: [
            Expanded(
              child: Text(
                'Quản lý của tôi',
                style: HD.bodyBold(size: 23, color: HD.ink),
              ),
            ),
            IconButton(
              tooltip: 'Làm mới',
              onPressed: () => _nap(_goc),
              icon: const Icon(Icons.refresh_rounded, color: HD.accent),
            ),
          ],
        ),
      ),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: HD.s16),
        child: Text(
          'Theo dõi lịch xem, hồ sơ thuê và các khoản cần thanh toán.',
          style: HD.body(size: 14, color: HD.inkMuted),
        ),
      ),
      const SizedBox(height: HD.s16),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: HD.s16),
        child: Column(
          children: [
            _khachMuc(
              Icons.calendar_month_rounded,
              'Lịch xem nhà',
              'Theo dõi lịch hẹn và chọn giờ phù hợp',
              demLich,
              const Color(0xffffeeee),
              moLich,
            ),
            const SizedBox(height: 10),
            _khachMuc(
              Icons.handshake_outlined,
              'Đang chốt thuê',
              'Hoàn tất cọc và hồ sơ thuê',
              chot.length,
              const Color(0xfffff5df),
              () => chot.isEmpty
                  ? _moThongBao('Chưa có hồ sơ chốt thuê đang chờ.')
                  : _mo(chot.first),
            ),
            const SizedBox(height: 10),
            _khachMuc(
              Icons.home_work_outlined,
              'Nhà đang thuê',
              'Hợp đồng, điện nước và sự cố',
              thue.length,
              const Color(0xffeaf3ff),
              () => thue.isEmpty
                  ? _moThongBao('Chưa có hợp đồng thuê đang hiệu lực.')
                  : _mo(thue.first),
            ),
            const SizedBox(height: 10),
            _khachMuc(
              Icons.receipt_long_outlined,
              'Hóa đơn',
              'Xem khoản thuê và chi phí đến hạn',
              thue.length,
              const Color(0xffedf8f0),
              () => thue.isEmpty
                  ? _moThongBao('Hóa đơn sẽ hiện khi có hợp đồng thuê.')
                  : _mo(thue.first),
            ),
          ],
        ),
      ),
      const SizedBox(height: 20),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: HD.s16),
        child: Row(
          children: [
            Expanded(
              child: Text(
                'Việc cần làm hôm nay',
                style: HD.bodyBold(size: 19, color: HD.ink),
              ),
            ),
            TextButton(onPressed: moLich, child: const Text('Xem lịch')),
          ],
        ),
      ),
      if (viec.isEmpty)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: HD.s16),
          child: _khachEmpty('Chưa có việc cần xử lý.'),
        )
      else
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: HD.s16),
          child: Column(children: [for (final m in viec) _khachViec(m)]),
        ),
      const SizedBox(height: 20),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: HD.s16),
        child: Text(
          'Lối vào nhanh',
          style: HD.bodyBold(size: 19, color: HD.ink),
        ),
      ),
      const SizedBox(height: 10),
      Padding(
        padding: const EdgeInsets.fromLTRB(HD.s16, 0, HD.s16, HD.s32),
        child: Row(
          children: [
            _khachNhanh(Icons.event_note_rounded, 'Lịch xem', moLich),
            const SizedBox(width: 9),
            _khachNhanh(
              Icons.home_work_outlined,
              'Nhà đang thuê',
              () => thue.isEmpty
                  ? _moThongBao('Chưa có nhà đang thuê.')
                  : _mo(thue.first),
            ),
            const SizedBox(width: 9),
            _khachNhanh(
              Icons.receipt_long_outlined,
              'Hóa đơn',
              () => thue.isEmpty
                  ? _moThongBao('Hóa đơn sẽ hiện khi có hợp đồng.')
                  : _mo(thue.first),
            ),
          ],
        ),
      ),
    ];
  }

  void _moThongBao(String text) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

  Widget _khachMuc(
    IconData icon,
    String title,
    String subtitle,
    int count,
    Color tint,
    VoidCallback onTap,
  ) => Material(
    color: Colors.white,
    borderRadius: BorderRadius.circular(18),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        constraints: const BoxConstraints(minHeight: 84),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: HD.hairline),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: tint,
                borderRadius: BorderRadius.circular(15),
              ),
              child: Icon(icon, color: HD.accent, size: 25),
            ),
            const SizedBox(width: 12),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(title, style: HD.bodyBold(size: 16, color: HD.ink)),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: HD.body(size: 12, color: HD.inkMuted),
                  ),
                ],
              ),
            ),
            if (count > 0)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: HD.accentTint,
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Text(
                  '$count',
                  style: HD.bodyBold(size: 13, color: HD.accent),
                ),
              ),
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right_rounded, color: HD.inkMuted),
          ],
        ),
      ),
    ),
  );

  Widget _khachNhanh(IconData icon, String label, VoidCallback onTap) =>
      Expanded(
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            constraints: const BoxConstraints(minHeight: 94),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: HD.hairline),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: HD.accent, size: 26),
                const SizedBox(height: 7),
                Text(
                  label,
                  maxLines: 2,
                  textAlign: TextAlign.center,
                  style: HD.body(size: 11, color: HD.ink),
                ),
              ],
            ),
          ),
        ),
      );

  Widget _khachViec(MucQuanLy m) => Card(
    margin: const EdgeInsets.only(bottom: 9),
    color: Colors.white,
    elevation: 0,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
      side: const BorderSide(color: HD.hairline),
    ),
    child: ListTile(
      minLeadingWidth: 42,
      leading: const CircleAvatar(
        backgroundColor: Color(0xffffeeee),
        child: Icon(Icons.notifications_active_outlined, color: HD.accent),
      ),
      title: Text(
        m.tieuDe,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: HD.bodyBold(size: 15, color: HD.ink),
      ),
      subtitle: Text(
        m.dong.isEmpty ? m.diaChi : m.dong,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: HD.body(size: 12, color: HD.inkMuted),
      ),
      trailing: const Icon(Icons.chevron_right_rounded),
      onTap: () => _mo(m),
    ),
  );

  Widget _khachEmpty(String text) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: HD.hairline),
    ),
    child: Row(
      children: [
        const Icon(Icons.check_circle_outline, color: HD.positive),
        const SizedBox(width: 10),
        Expanded(
          child: Text(text, style: HD.body(size: 13, color: HD.inkMuted)),
        ),
      ],
    ),
  );

  Widget _dauDanhSach() => Padding(
    key: _moDanhSach,
    padding: const EdgeInsets.symmetric(horizontal: HD.s16),
    child: Row(
      children: [
        Text(
          widget.cheDoSale ? 'Khách đang theo dõi' : 'Danh sách quản lý',
          style: const TextStyle(
            fontSize: 19,
            fontWeight: FontWeight.w800,
            color: HD.ink,
          ),
        ),
        const SizedBox(width: HD.s12),
        Expanded(
          child: SizedBox(
            height: 42,
            child: TextField(
              key: const Key('quan-ly-tim'),
              controller: _tim,
              onChanged: (_) => setState(() {}),
              textInputAction: TextInputAction.search,
              style: const TextStyle(fontSize: 14),
              decoration: InputDecoration(
                hintText: widget.cheDoSale
                    ? 'Tìm khách, mã phòng...'
                    : 'Tìm kiếm bất động sản...',
                hintStyle: const TextStyle(fontSize: 12.5, color: HD.inkMuted),
                // Thu gọn vùng icon: mặc định 48px ăn mất chỗ khiến gợi ý bị cắt
                // thành "Tìm kiếm bất động sả…" trên màn điện thoại.
                prefixIcon: const Icon(
                  Icons.search,
                  size: 19,
                  color: HD.inkMuted,
                ),
                // `minHeight` phải giữ: icon mặc định (48×48) là thứ đang đỡ chiều
                // cao ô. Chỉ đặt `minWidth` thì ô co về đúng một dòng chữ và dạt
                // lên trên, lệch hẳn với tiêu đề bên cạnh (ảnh chụp 18/09/2026).
                prefixIconConstraints: const BoxConstraints(
                  minWidth: 36,
                  minHeight: 42,
                ),
                suffixIcon: _tim.text.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Xoá',
                        icon: const Icon(Icons.close, size: 18),
                        onPressed: () => setState(_tim.clear),
                      ),
                isDense: true,
                filled: true,
                fillColor: HD.paperRaised,
                contentPadding: EdgeInsets.zero,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(HD.rPill),
                  borderSide: const BorderSide(color: HD.hairline),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(HD.rPill),
                  borderSide: const BorderSide(color: HD.hairline),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(HD.rPill),
                  borderSide: const BorderSide(color: HD.accent),
                ),
              ),
            ),
          ),
        ),
      ],
    ),
  );

  Widget _chipLoc() => SingleChildScrollView(
    scrollDirection: Axis.horizontal,
    padding: const EdgeInsets.symmetric(horizontal: HD.s16),
    child: Row(
      children: [
        for (final e in _nhanLoc.entries) ...[
          Padding(
            padding: const EdgeInsets.only(right: HD.s8),
            child: ChoiceChip(
              key: Key('loc-${e.key}'),
              label: Text(e.value),
              selected: _loc == e.key,
              onSelected: (_) => setState(() => _loc = e.key),
              showCheckmark: false,
              selectedColor: HD.accent,
              backgroundColor: HD.paperSunken,
              side: BorderSide.none,
              shape: const StadiumBorder(),
              padding: const EdgeInsets.symmetric(
                horizontal: HD.s12,
                vertical: 6,
              ),
              labelStyle: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: _loc == e.key ? Colors.white : HD.inkSoft,
              ),
            ),
          ),
        ],
      ],
    ),
  );

  Widget _danhSach(TongHopQuanLy d) {
    final ds = _locDanhSach(d.danhSach);
    if (ds.isNotEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: HD.s16),
        child: Column(
          children: [
            for (final m in ds) TheMucQuanLy(m: m, onTap: () => _mo(m)),
          ],
        ),
      );
    }
    // Nói ĐÚNG hoàn cảnh. Bản đầu gộp mọi ca "rỗng sau khi lọc" vào một câu
    // "Chọn 'Tất cả' để xem lại…" — kể cả khi đang ở "Tất cả" mà chỉ còn lịch
    // sử (ảnh chụp thật 18/09/2026: sale có 2 đơn đã xong, 0 việc đang mở).
    final tu = _tim.text.trim();
    final coLichSu = d.danhSach.any((m) => m.nhom == NhomQuanLy.lichSu);
    final (String tieuDe, String mo, bool moiLichSu) = switch (true) {
      _ when tu.isNotEmpty => (
        'Không có mục nào',
        'Không có mục nào khớp "$tu".',
        false,
      ),
      _ when _loc != 'tat_ca' => (
        'Không có mục nào',
        'Chọn "Tất cả" để xem lại toàn bộ việc đang mở.',
        false,
      ),
      _ when coLichSu => (
        'Không có việc nào đang mở',
        'Các đơn và lịch đã xong vẫn xem lại được ở mục Lịch sử.',
        true,
      ),
      _ when _goc == GocQuanLy.cuaToi => (
        'Chưa có gì để quản lý',
        'Đặt phòng hoặc hẹn xem nhà từ trang tin đăng — đơn, lịch hẹn và '
            'phòng bạn đang thuê sẽ hiện ở đây.',
        false,
      ),
      _ => (
        widget.cheDoSale ? 'Chưa có khách cần theo dõi' : 'Chưa có khách nào',
        widget.cheDoSale
            ? 'Lịch xem và yêu cầu từ khách trên các tin bạn phụ trách sẽ '
                  'hiện ở đây. Quyết định thuê và hợp đồng do chủ nhà xử lý.'
            : 'Khi khách hẹn xem hoặc đặt phòng trên tin / phòng bạn phụ '
                  'trách, mọi việc cần xác nhận sẽ hiện ở đây.',
        false,
      ),
    };
    return Padding(
      padding: const EdgeInsets.fromLTRB(HD.s32, HD.s24, HD.s32, 0),
      child: Column(
        children: [
          const Icon(Icons.inbox_outlined, size: 40, color: HD.inkMuted),
          const SizedBox(height: HD.s8),
          Text(tieuDe, style: HD.bodyBold(size: 15)),
          const SizedBox(height: HD.s4),
          Text(
            mo,
            textAlign: TextAlign.center,
            style: HD.body(size: 13, color: HD.inkMuted),
          ),
          if (moiLichSu) ...[
            const SizedBox(height: HD.s8),
            TextButton(
              key: const Key('quan-ly-xem-lich-su'),
              onPressed: () => setState(() => _loc = NhomQuanLy.lichSu),
              child: const Text('Xem lịch sử'),
            ),
          ],
        ],
      ),
    );
  }
}
